export type ContextFill = { tokens?: number; window: number; percent?: number }
export type Limit = { kind: string; percentUsed: number; resetsAt?: string }

declare module 'claude-code' {
  interface PluginState {
    'context-status': {
      context: ContextFill | null
      model: string | null
      cache: number | null
      limits: Limit[]
      cwd: string | null
      branch: string | null
      now: number
      mcp: number | null
      skills: number | null
    }
  }
}
