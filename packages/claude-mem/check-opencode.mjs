import assert from 'node:assert/strict';
import { pathToFileURL } from 'node:url';

// Exercise the published V2 entrypoint without starting a host, worker, or model.
globalThis.fetch = () => { throw new Error('Unexpected network request during setup'); };
const { default: plugin } = await import(pathToFileURL(
  `${process.argv[2]}/share/claude-mem/dist/opencode-plugin/index.js`,
));
assert.equal(plugin.id, 'claude-mem');
assert.equal(typeof plugin.setup, 'function');
const registered = [];
const disposed = [];
const tools = [];
const hook = async (name) => {
  registered.push(name);
  return { dispose: async () => { disposed.push(name); } };
};
const cleanup = await plugin.setup({
  location: { directory: process.cwd() },
  tool: {
    hook,
    transform: async (transform) => {
      transform({ add: (tool) => { tools.push(tool.name); } });
      return hook('tools');
    },
  },
  session: { hook },
});
assert.deepEqual(registered, ['execute.after', 'prompt', 'context', 'compaction', 'tools']);
assert.deepEqual(tools, ['claude_mem_search', 'claude_mem_timeline', 'claude_mem_get_observations']);
await cleanup();
assert.deepEqual(disposed, registered);
console.log('OpenCode V2 plugin setup/cleanup passed');
