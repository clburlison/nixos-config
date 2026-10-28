import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { Limit } from '../types'
import { branchOf, cacheHit, exact, level, modelName, resetIn, shortPath } from './format'
import type { Level } from './format'

const fill = atom({ plugin: 'context-status', key: 'context' } as const, null)
const model = atom({ plugin: 'context-status', key: 'model' } as const, null)
const cache = atom({ plugin: 'context-status', key: 'cache' } as const, null)
const limits = atom({ plugin: 'context-status', key: 'limits' } as const, [])
const cwd = atom({ plugin: 'context-status', key: 'cwd' } as const, null)
const branch = atom({ plugin: 'context-status', key: 'branch' } as const, null)
const now = atom({ plugin: 'context-status', key: 'now' } as const, 0)
const mcp = atom({ plugin: 'context-status', key: 'mcp' } as const, null)
const skills = atom({ plugin: 'context-status', key: 'skills' } as const, null)

// Nerd Font glyphs
const ICON = {
  model: '\uec82', // nf-cod-claude
  folder: '\uea83', // nf-cod-folder
  branch: '\uec6f', // nf-cod-git_branch
  context: '\uee9c', // nf-fa-brain
  cache: '\uf49b', // nf-oct-cache
  clock: '\uf43a', // nf-oct-clock
  calendar: '\uf455', // nf-oct-calendar
  mcp: '\uec47', // nf-cod-mcp
  skills: '\u{f0bc2}', // nf-md-script_text
}

// Muted palette
const COLOR: Record<string, string> & Record<Level, string> = {
  model: '#b4a7d6',
  path: '#8aa4c8',
  branch: '#9cb89a',
  cache: '#8fb8b8',
  mcp: '#c4a7c7',
  skills: '#b8a98f',
  sep: '#5c6370',
  dim: '#7f848e',
  ok: '#9cb89a',
  warn: '#d4b483',
  crit: '#c98a8a',
}

const same = (a: unknown, b: unknown) => JSON.stringify(a) === JSON.stringify(b)

// Walks up from dir to the nearest .git (a directory, or a worktree's file)
const findBranch = async ($: EngineInterface, dir: string): Promise<string | null> => {
  for (let d = dir; d !== ''; d = d.slice(0, d.lastIndexOf('/'))) {
    const head = await $.fs.read(`${d}/.git/HEAD`).catch(() => null)
    if (typeof head === 'string') {
      return branchOf(head)
    }

    const link = await $.fs.read(`${d}/.git`).catch(() => null)
    const gitdir = typeof link === 'string' ? /^gitdir: (.+)$/m.exec(link)?.[1] : undefined
    if (gitdir !== undefined) {
      const path = gitdir.startsWith('/') ? gitdir : `${d}/${gitdir}`
      const text = await $.fs.read(`${path}/HEAD`).catch(() => null)

      return typeof text === 'string' ? branchOf(text) : null
    }
  }

  return null
}

// Connected MCP servers (from their tools) and skills the session has
const countExtras = async ($: EngineInterface) => {
  const tools = await $.tool.list()
  const servers = new Set(tools.filter(t => t.mcp).map(t => t.name.split('__')[1]))
  const usage = await $.session.usage({ breakdown: 'summary' })
  const total = usage.context.breakdown?.skills?.totalSkills ?? 0

  if ((await read($, mcp)) !== servers.size) await update($, mcp, () => servers.size)
  if ((await read($, skills)) !== total) await update($, skills, () => total)
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const { context, rateLimits } = await $.session.usage()
    await update($, fill, () => context)
    await update($, limits, () => rateLimits)

    const home = await $.env.get('HOME')
    // classic.PostModelSwitch is bypassed for user-tier plugins, so poll instead
    const sync = async () => {
      const id = await $.session.model()
      const dir = await $.session.cwd()
      const path = shortPath(dir, home)
      const ref = await findBranch($, dir)
      const minute = Math.floor((await $.clock.now()) / 60_000) * 60_000

      if ((await read($, model)) !== id) await update($, model, () => id)
      if ((await read($, cwd)) !== path) await update($, cwd, () => path)
      if ((await read($, branch)) !== ref) await update($, branch, () => ref)
      if ((await read($, now)) !== minute) await update($, now, () => minute)
    }
    await sync()
    $.clock.every(1000, sync)
    await countExtras($).catch(() => {})
    $.clock.every(15_000, () => countExtras($).catch(() => {}))

    return next(e)
  })

  on('session.measure', async ($, e, next) => {
    if (e.changed.includes('context')) {
      await update($, fill, () => e.context)
    }
    if (e.changed.includes('rateLimits') && !same(await read($, limits), e.rateLimits)) {
      await update($, limits, () => e.rateLimits)
    }

    return next(e)
  })

  on('turn.complete', async ($, e, next) => {
    const hit = e.usage === undefined ? null : cacheHit(e.usage)
    if (hit !== null) {
      await update($, cache, () => hit)
    }
    await countExtras($).catch(() => {})

    return next(e)
  })

  on('ui.render', { component: 'PromptHint' }, async ($, e, next) => {
    const hint = await next(e)
    const context = await read($, fill)

    if (context === null) {
      return hint
    }

    const id = await read($, model)
    const path = await read($, cwd)
    const ref = await read($, branch)
    const hit = await read($, cache)
    const windows = await read($, limits)
    const minute = await read($, now)
    const servers = await read($, mcp)
    const skillCount = await read($, skills)
    const { Box, Text } = $.ui.resolve(e)

    const pct = Math.round(context.percent ?? 0)
    const five = windows.find((l: Limit) => l.kind === 'five_hour')
    const seven = windows.find((l: Limit) => l.kind === 'seven_day')
    const reset = five?.resetsAt === undefined ? '' : resetIn(five.resetsAt, minute)

    const top = [
      id === null ? null : (
        <Text key="model" color={COLOR.model}>
          {ICON.model} {modelName(id)}
        </Text>
      ),
      path === null ? null : (
        <Text key="path" color={COLOR.path}>
          {ICON.folder} {path}
        </Text>
      ),
      ref === null ? null : (
        <Text key="branch" color={COLOR.branch}>
          {ICON.branch} {ref}
        </Text>
      ),
    ].filter(x => x !== null)

    const bottom = [
      <Box key="context">
        <Text color={COLOR[level(pct)]}>
          {ICON.context} context: {pct}%
        </Text>
        <Box display="none" hover={{ display: 'flex' }}>
          <Text color={COLOR.dim}> ({exact(context)})</Text>
        </Box>
        {hit === null ? null : (
          <Text color={COLOR.cache}>
            {'  '}
            {ICON.cache} {hit}%
          </Text>
        )}
      </Box>,
      five === undefined ? null : (
        <Box key="five">
          <Text color={COLOR[level(five.percentUsed)]}>
            {ICON.clock} 5h: {Math.round(five.percentUsed)}%
          </Text>
          {reset === '' ? null : <Text color={COLOR.dim}> {reset}</Text>}
        </Box>
      ),
      seven === undefined ? null : (
        <Text key="seven" color={COLOR[level(seven.percentUsed)]}>
          {ICON.calendar} 7d: {Math.round(seven.percentUsed)}%
        </Text>
      ),
      servers === null ? null : (
        <Text key="mcp" color={COLOR.mcp}>
          {ICON.mcp} {servers}
        </Text>
      ),
      skillCount === null ? null : (
        <Text key="skills" color={COLOR.skills}>
          {ICON.skills} {skillCount}
        </Text>
      ),
    ].filter(x => x !== null)

    const row = (items: unknown[], name: string) =>
      items.flatMap((item, i) =>
        i === 0 ? [item] : [<Text key={`${name}-sep-${i}`} color={COLOR.sep}> │ </Text>, item],
      )

    return (
      <Box key="status" flexDirection="column">
        {hint}
        {top.length === 0 ? null : <Box key="top">{row(top, 'top')}</Box>}
        <Box key="bottom">{row(bottom, 'bottom')}</Box>
      </Box>
    )
  })
}
