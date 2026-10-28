import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import { exact, modelName, percent } from './format'

const fill = atom({ plugin: 'context-status', key: 'context' } as const, null)
const model = atom({ plugin: 'context-status', key: 'model' } as const, null)

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const { context } = await $.session.usage()
    await update($, fill, () => context)
    const sync = async () => {
      const id = await $.session.model()
      if ((await read($, model)) !== id) {
        await update($, model, () => id)
      }
    }
    await sync()
    // classic.PostModelSwitch is bypassed for user-tier plugins, so poll instead
    $.clock.every(1000, sync)

    return next(e)
  })

  on('session.measure', async ($, e, next) => {
    if (e.changed.includes('context')) {
      await update($, fill, () => e.context)
    }

    return next(e)
  })

  on('ui.render', { component: 'PromptHint' }, async ($, e, next) => {
    const context = await read($, fill)
    const id = await read($, model)
    const hint = await next(e)

    if (context === null) {
      return hint
    }

    const { Box, Text } = $.ui.resolve(e)
    const label = `${id === null ? '' : `${modelName(id)} | `}${percent(context)}`

    return (
      <Box key="context" flexDirection="column">
        {hint}
        <Box>
          <Text dimColor>{label}</Text>
          <Box display="none" hover={{ display: 'flex' }}>
            <Text dimColor> ({exact(context)})</Text>
          </Box>
        </Box>
      </Box>
    )
  })
}
