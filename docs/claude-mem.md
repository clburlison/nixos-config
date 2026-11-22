# Shared AI-agent memory

Where this fits in the setup order: [docs/README.md](README.md).

`modules/common/programs/claude-mem.nix` enables claude-mem **15.6.0** for Claude Code,
and Codex. `packages/claude-mem.nix` packages the published npm
bundles and a packaging-maintained runtime dependency lock. Nothing invokes the
upstream installer during Home Manager activation.

## Apply and use

1. Make new files known to Git before using the repository's normal flake-based
   `task switch`. Review/apply the configuration yourself; no activation is
   performed by the package tests.
2. Restart your terminals/agents. Run `claude-mem restart` after this upgrade:
   an already-running SQLite-only worker keeps its old environment until restarted, even at the same version.
3. Claude Code must already be signed in. Memory compression for **both
   agents** uses the pinned, unwrapped Claude CLI and consumes your Claude plan.
   If necessary, run `claude auth login` yourself. No credentials enter Nix.
4. In Codex, use `/hooks` to review and trust the added hook definitions. A Nix
   generation changing their commands can require fresh approval. No approval
   state is generated or bypassed.
5. Check `claude-mem status` and the local viewer at
   `http://127.0.0.1:37777`. Then verify that an ordinary session's observations
   are available in a later session; connectivity alone does not prove capture.

Claude loads the Nix plugin through Home Manager's `--plugin-dir` wrapper.
Codex's wrapper supplies inline hook and MCP `--config` overrides, leaving your
existing `~/.codex/config.toml`, `hooks.json`, trust records, and login writable.
Existing file-based hooks still run. The wrapper takes precedence for the seven
inline hook event keys it supplies; don't separately configure those same
claude-mem hooks or install its native Codex plugin.

Claude receives upstream plugin skills; Codex additionally receives
`mem-search` and `smart-explore` without replacing its other skills.

## Hosted server

Hooks on every host send to the hosted server on ai-hub
(`docs/ai-hub.md` step 13): `home.sessionVariables` set
`CLAUDE_MEM_RUNTIME=server`, the server URL (tailnet name), and the project
ID. The server stores memory in Postgres and generates observations itself,
so the local SQLite worker below is only the fallback.

Session variables only reach agents started from a login shell. Agents
launched by a launchd/systemd service (e.g. T3 Code) and the worker they spawn
fall back to `~/.claude-mem/settings.json`, so activation also merges those
three keys there and stops a running worker when they change. Local routing
shows as `ENQUEUED | sessionDbId=...` in `~/.claude-mem/logs`.

### Per host: the API key

The key is `op://Agents/claude-mem-rw/credential`
(`memories:read,memories:write`). Nix supplies it on every host from the
Agents vault through `op-agents`, so set the op-agents token first
(`docs/op-agents.md`); no hand edits to `settings.json`.

1. Hooks: activation writes `CLAUDE_MEM_SERVER_API_KEY` into
   `~/.claude-mem/settings.json` (mode 0600) with the other server keys, and
   pins the legacy `CLAUDE_MEM_SERVER_BETA_*` fallbacks to match (beta key
   empty). Darwin reads op-agents' keychain cache, or 1Password directly on
   a first activation; ai-hub reads `/run/op-agents/claude-mem-api-key`.
   If the key can't be read, activation warns and keeps the current one. A
   host without a key keeps the local SQLite worker.

2. MCP server, for search and memory tools in Claude Code: Nix manages it
   (`programs.claude-code.mcpServers.claude-mem` in
   `modules/common/programs/claude-mem.nix`), at the host's server URL plus
   `/v1/mcp`. Its `headersHelper` reads the key at each connect, from the
   same source. Activation removes an old hand-added user-scope `claude-mem`
   entry.

3. Approve the Codex hooks ("Apply and use" step 4).

To rotate the key, see "API keys" in `docs/ai-hub.md`, then run
`op-agents-load` (Darwin) and `task home` on every host.

### Reaching the server

Hosts on the home LAN use the LAN name `ai-hub.home.clb.ai`, so they
need no Tailscale. clb-work roams: its local failover proxy
(`hosts/clb-work/hub-proxy.nix`) tries the LAN name, then the tailnet name.
Away from home it still needs Tailscale: upstream says not to expose the
server to the internet.

Existing SQLite memory is not migrated: the server has no import path.

The memory viewer for the server is
<http://ai-hub.mermaid-agama.ts.net:37878> (tailnet only; `docs/ai-hub.md`,
"Viewer"). The local viewer on `127.0.0.1:37777` shows only the local
worker.

## Runtime policy and limitations

- One lazily started worker is shared by the two agents, not two services.
  The packaged worker-script override prevents mutable marketplace caches from
  superseding the Nix runtime. No launchd/systemd service is added.
- State remains writable in `~/.claude-mem` (or `CLAUDE_MEM_DATA_DIR`), including
  SQLite/WAL, settings, logs, and process markers. Use one consistent directory
  and worker port for all clients.
- **Local vector search is enabled:** SQLite remains the authoritative memory
  store; Chroma indexes embeddings in `~/.claude-mem/chroma`. The bridge
  (`chroma-mcp` 0.2.6), Chroma 1.5.9, Python 3.13 dependency closure, and
  `all-MiniLM-L6-v2` ONNX/tokenizer assets are Nix-owned. The worker launches the
  packaged bridge directly, not `uvx`; no Python packages or models are fetched
  on first use. Nix also supplies the CA bundle used by the macOS certificate
  helper instead of provisioning certifi through uvx. Embeddings run locally
  without an API key.
- The bridge exposes the default local ONNX embedder, not upstream's optional
  hosted/image embedding providers. A missing packaged model is an error, not a
  reason to download to a user cache. Chroma telemetry is disabled.
- All 25 supported smart-file grammar libraries are compiled at build time.
  A narrow, asserted patch directs MCP lookup to their store directory instead
  of compiling inside your home. The Nix Tree-sitter CLI (currently 0.26.11)
  replaces the npm package's downloaded 0.26.9 executable; grammar libraries and
  queries use the same Nix CLI. The npm native Node bindings are unused.
- The wrappers bind Node/Bun/tool paths, `CLAUDE_MEM_PROVIDER=claude`, and the raw
  Claude executable. Telemetry defaults off (`CLAUDE_MEM_TELEMETRY=false`,
  overridable in the inherited environment). Settings otherwise remain writable.
- Do not run `npx claude-mem install/update/repair` or install a second marketplace
  copy alongside this configuration. Updates are through Nix. The exposed
  `claude-mem` is the **hook launcher**, not npm's installer CLI;
  `claude-mem --version` prints launcher protocol **3**, not package semver.
- Back up the data directory before upgrades. Database migrations are not
  reversed by rolling back the Nix generation.
- `CLAUDE_MEM_BACKUP_ENABLED=true` makes the worker snapshot SQLite to
  `~/.claude-mem/backups` (every 24h, keep 7; tune with
  `CLAUDE_MEM_BACKUP_INTERVAL_HOURS` / `CLAUDE_MEM_BACKUP_RETAIN_COUNT`).
  Chroma is a rebuildable index and is not included.

## Package verification (no system activation)

```sh
package=$(nix build --no-link --print-out-paths 'path:.#darwinConfigurations.clb-mini.pkgs.claude-mem')
python3 packages/claude-mem/runtime-smoke.py "$package"
```

`path:.` includes new, untracked implementation files during development. The
package build checks hook metadata, TOML overlays, grammar linking, and launcher
protocol. The smoke test uses an isolated
HOME/port, preserves sample Codex files, starts/stops only its own worker, and
checks MCP, SQLite save/recall, semantic recall with no keyword overlap, smart
parsing, and rejection of a newer mutable cache. The Chroma package check denies
Python socket connections while computing real 384-dimensional embeddings,
testing semantic ranking, and reopening a persistent collection. These tests
make no external model/login calls and do not replace real host capture and
provider-authentication tests.

Verified on `aarch64-darwin`; the package and standalone Home Manager module
also evaluate for `x86_64-linux`, but have not been built/run there. The existing
WSL host cannot currently evaluate because this checkout lacks `nixos.nix`;
that unrelated host issue is not changed here.

## Updating

Use the package task from the repository root:

```sh
task packages:update-claude-mem                       # latest npm release
task packages:update-claude-mem -- 15.6.0             # specific release
task packages:update-claude-mem -- 15.6.0 --dry-run   # validate without replacing files
```

The updater verifies registry SHA-512 integrity, checks the actual bundle/hook
adaptations in staging, merges root/plugin runtime manifests, regenerates the
lock with lifecycle scripts disabled, computes the archive and `npmDepsHash`
hashes using the locked nixpkgs tooling, and formats the package. Files are only
replaced after validation succeeds; concurrent edits are not overwritten.

This deliberately refuses releases whose bundle patches, dependency policies,
or Chroma pins need manual adaptation. Review upstream migration notes and
adapter changes, then update `prepare.py`/checks and Python packaging as needed.
The updater does not build or activate a system, change the flake lock, or update
Chroma/model pins automatically. Run the individual package build and runtime
smoke test above before applying. This reuses published bundles, not a claim of
reproducing those bundles from Git.

The Python/model package is `packages/claude-mem/chroma.nix`. Its dependency
closure follows the main nixpkgs lock, including its protobuf, so cached
binaries are reused (upstream's `protobuf<7` cap is intentionally not enforced;
the Chroma self-test covers it) and MCP SDK 1.6.0 is pinned as required by the
bridge. Version assertions enforce Chroma 1.5.9, ONNX Runtime >=1.20, and
Pydantic <2.14. Recheck those constraints, the model archive hash, and semantic
tests when updating nixpkgs.
Do not downgrade an existing Chroma store to an older engine: its schema/data
compatibility is separate from Nix package rollback.
