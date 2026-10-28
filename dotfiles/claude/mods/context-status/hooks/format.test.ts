import { expect, test } from 'claude-code/testing'

import { branchOf, cacheHit, level, resetIn, shortPath } from './format'

test('level thresholds', () => {
  expect(level(10)).toBe('ok')
  expect(level(70)).toBe('warn')
  expect(level(95)).toBe('crit')
})

test('resetIn formats remaining time', () => {
  const now = Date.parse('2026-10-28T12:00:00Z')
  expect(resetIn('2026-10-28T14:45:00Z', now)).toBe('2h45m')
  expect(resetIn('2026-10-28T12:05:00Z', now)).toBe('5m')
  expect(resetIn('2026-10-30T15:00:00Z', now)).toBe('2d3h')
  expect(resetIn('2026-10-28T11:00:00Z', now)).toBe('')
})

test('cacheHit is the cached share of the prompt', () => {
  expect(cacheHit({ input_tokens: 10, cache_read_input_tokens: 80, cache_creation_input_tokens: 10 })).toBe(80)
  expect(cacheHit({ input_tokens: 0, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 })).toBe(null)
})

test('shortPath abbreviates home and long paths', () => {
  expect(shortPath('/Users/me/dev/x', '/Users/me')).toBe('~/dev/x')
  expect(shortPath('/Users/mex', '/Users/me')).toBe('/Users/mex')
  expect(shortPath('/a/very/long/path/that/keeps/going/and/going/forever', undefined)).toBe('…/going/forever')
})

test('branchOf reads HEAD', () => {
  expect(branchOf('ref: refs/heads/feature/auth\n')).toBe('feature/auth')
  expect(branchOf('25f3641aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n')).toBe('25f3641')
})
