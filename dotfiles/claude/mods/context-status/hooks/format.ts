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
