import type { ContextFill } from '../types'

const compact = (n: number): string =>
  n >= 1_000_000
    ? `${Number((n / 1_000_000).toFixed(1))}M`
    : `${Math.round(n / 1_000)}K`

export const percent = (context: ContextFill): string =>
  `context: ${Math.round(context.percent ?? 0)}%`

export const exact = (context: ContextFill): string =>
  `${compact(context.tokens ?? 0)} / ${compact(context.window)}`

// claude-opus-5-5[1m] -> Opus 5.5; claude-sonnet-4-5-20250929 -> Sonnet 4.5
export const modelName = (id: string): string => {
  const match = /^claude-([a-z]+)-(\d+(?:-\d+)*?)(?:-\d{8})?(?:\[.*\])?$/.exec(id)

  if (match === null) {
    return id
  }

  const [, family, version] = match

  return `${family[0].toUpperCase()}${family.slice(1)} ${version.replaceAll('-', '.')}`
}

export type Level = 'ok' | 'warn' | 'crit'

export const level = (pct: number): Level => (pct >= 90 ? 'crit' : pct >= 70 ? 'warn' : 'ok')

// 2h45m, 45m, 1d3h; '' once passed
export const resetIn = (resetsAt: string, now: number): string => {
  const mins = Math.ceil((Date.parse(resetsAt) - now) / 60_000)

  if (!(mins > 0)) {
    return ''
  }

  const d = Math.floor(mins / 1440)
  const h = Math.floor((mins % 1440) / 60)
  const m = mins % 60

  return d > 0 ? `${d}d${h}h` : h > 0 ? `${h}h${String(m).padStart(2, '0')}m` : `${m}m`
}

// Cache share of the prompt the last response read
export const cacheHit = (u: {
  input_tokens: number
  cache_read_input_tokens: number
  cache_creation_input_tokens: number
}): number | null => {
  const total = u.input_tokens + u.cache_read_input_tokens + u.cache_creation_input_tokens

  return total === 0 ? null : Math.round((u.cache_read_input_tokens / total) * 100)
}

// ~/dev/me/nixos-config; …/me/nixos-config past max chars
export const shortPath = (cwd: string, home: string | undefined, max = 40): string => {
  const path = home && (cwd === home || cwd.startsWith(`${home}/`)) ? `~${cwd.slice(home.length)}` : cwd

  if (path.length <= max) {
    return path
  }

  const parts = path.split('/')

  return `…/${parts.slice(-2).join('/')}`
}

// .git/HEAD text -> branch, or short sha when detached
export const branchOf = (head: string): string | null => {
  const text = head.trim()
  const ref = /^ref: refs\/heads\/(.+)$/.exec(text)

  return ref ? ref[1] : /^[0-9a-f]{40}$/.test(text) ? text.slice(0, 7) : null
}
