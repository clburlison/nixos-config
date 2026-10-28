import { expect, test } from 'claude-code/testing'

import { exact, modelName, percent } from './format'

test('percent rounds to a whole number', () => {
  expect(percent({ tokens: 145_000, window: 1_000_000, percent: 14.5 })).toBe('context: 15%')
})

test('percent is 0 before the first response', () => {
  expect(percent({ window: 200_000 })).toBe('context: 0%')
})

test('exact shows K and M', () => {
  expect(exact({ tokens: 145_000, window: 1_000_000 })).toBe('145K / 1M')
  expect(exact({ tokens: 1_250_000, window: 2_000_000 })).toBe('1.3M / 2M')
  expect(exact({ tokens: 44_400, window: 200_000 })).toBe('44K / 200K')
})

test('modelName shortens model ids', () => {
  expect(modelName('claude-opus-5-5')).toBe('Opus 5.5')
  expect(modelName('claude-opus-5-5[1m]')).toBe('Opus 5.5')
  expect(modelName('claude-sonnet-4-5-20250929')).toBe('Sonnet 4.5')
  expect(modelName('claude-haiku-4-5')).toBe('Haiku 4.5')
  expect(modelName('gpt-5')).toBe('gpt-5')
})
