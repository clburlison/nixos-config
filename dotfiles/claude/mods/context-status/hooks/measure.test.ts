import { expect, test } from 'claude-code/testing'

const text = (n: any): string =>
  n == null || typeof n !== 'object' ? (typeof n === 'string' || typeof n === 'number' ? String(n) : '')
  : Array.isArray(n) ? n.map(text).join('') : text(n.props?.children ?? n.children)

const setup = async ($: any, on: any) => {
  on('session.model', async () => ({ value: 'claude-opus-5-5' }))
  on('session.usage', async () => ({ value: { context: { window: 200_000 }, rateLimits: [] } }))
  on('session.start', async ($: any, e: any) => e)
  on('ui.render', async ($: any, e: any) => ({ type: 'Text', props: {}, children: [e.props.hint] }))
  on('session.measure', async ($: any, e: any) => ({ changed: e.changed }))
  await $.session.start({ cwd: '/', source: 'startup' }).catch((err: any) => console.log('start', err.message))
  return $.ui.mount({ plugin: 'context-status', surface: 'terminal', component: 'PromptHint', props: { isDraft: false, isWorking: false, hint: '? for shortcuts' } })
}

test('measure redraws context under the default hint', async ($, on) => {
  const m = await setup($, on)
  await $.session.measure({ context: { tokens: 50_000, window: 200_000, percent: 25 }, rateLimits: [], changed: ['context'] })
  const after = JSON.stringify(await m.drawn())
  console.log('after', after)
  expect(after).toContain('25%')
  expect(after).toContain('? for shortcuts')
})
