import { expect, test } from 'claude-code/testing'

const text = (n: any): string =>
  n == null || typeof n !== 'object' ? (typeof n === 'string' || typeof n === 'number' ? String(n) : '')
  : Array.isArray(n) ? n.map(text).join('') : text(n.props?.children ?? n.children)

const setup = async ($: any, on: any) => {
  on('session.model', async () => ({ value: 'claude-opus-5-5' }))
  on('session.usage', async ($: any, e: any) => ({ value: { context: { window: 200_000, ...(e.breakdown ? { breakdown: { skills: { totalSkills: 36 } } } : {}) }, rateLimits: [] } }))
  on('tool.list', async () => ({ value: [{ name: 'mcp__srv-a__x', description: '', mcp: true }, { name: 'mcp__srv-a__y', description: '', mcp: true }, { name: 'mcp__srv-b__z', description: '', mcp: true }, { name: 'Bash', description: '', mcp: false }] }))
  on('session.start', async ($: any, e: any) => e)
  on('ui.render', async ($: any, e: any) => ({ type: 'Text', props: {}, children: [e.props.hint] }))
  on('session.measure', async ($: any, e: any) => ({ changed: e.changed }))
  on('session.cwd', async () => ({ value: '/nowhere' }))
  on('env.get', async () => ({ value: undefined }))
  on('fs.read', async () => { throw new Error('missing') })
  on('clock.now', async () => ({ value: Date.parse('2026-10-28T12:00:00Z') }))
  on('clock.every', async () => ({ value: undefined }))
  await $.session.start({ cwd: '/', source: 'startup' }).catch((err: any) => console.log('start', err.message))
  return $.ui.mount({ plugin: 'context-status', surface: 'terminal', component: 'PromptHint', props: { isDraft: false, isWorking: false, hint: '? for shortcuts' } })
}

test('measure redraws context under the default hint', async ($, on) => {
  const m = await setup($, on)
  await $.session.measure({ context: { tokens: 50_000, window: 200_000, percent: 25 }, rateLimits: [{ kind: 'five_hour', percentUsed: 23, resetsAt: '2026-10-28T14:45:00Z' }, { kind: 'seven_day', percentUsed: 75 }], changed: ['context', 'rateLimits'] })
  const tree = await m.drawn()
  const after = text(tree)
  expect(after).toContain('25%')
  expect(after).toContain('? for shortcuts')
  expect(after).toContain('5h: ')
  expect(after).toContain('2h45m')
  expect(after).toContain('7d: ')
  expect(after).toContain('\uec47 2')
  expect(after).toContain('\u{f0bc2} 36')
  expect(JSON.stringify(tree)).toContain('#d4b483')
})
