# Shared AI-agent memory

`modules/home/claude-mem.nix` enables claude-mem **13.40.0** for Claude Code,
Codex, and OpenCode V2. `packages/claude-mem.nix` packages the published npm
bundles and a packaging-maintained runtime dependency lock. Nothing invokes the
upstream installer during Home Manager activation.

## Apply and use

1. Make new files known to Git before using the repository's normal flake-based
   `task switch`. Review/apply the configuration yourself; no activation is
   performed by the package tests.
2. Restart your terminals/agents. Restart OpenCode's background service with
   `opencode service restart` so it reloads the new plugin and MCP configuration.
   Run `claude-mem restart` after this upgrade: an already-running SQLite-only
   worker keeps its old environment until restarted, even at the same version.
3. Claude Code must already be signed in. Memory compression for **all three
   hosts** uses the pinned, unwrapped Claude CLI and consumes your Claude plan.
   If necessary, run `claude auth login` yourself. No credentials enter Nix.
4. In Codex, use `/hooks` to review and trust the added hook definitions. A Nix
   generation changing their commands can require fresh approval. No approval
   state is generated or bypassed.
5. Check `claude-mem status`, OpenCode's `/mcps`, and the local viewer at
   `http://127.0.0.1:37777`. Then verify that an ordinary session's observations
   are available in a later session; connectivity alone does not prove capture.

Claude loads the Nix plugin through Home Manager's `--plugin-dir` wrapper.
Codex's wrapper supplies inline hook and MCP `--config` overrides, leaving your
existing `~/.codex/config.toml`, `hooks.json`, trust records, and login writable.
Existing file-based hooks still run. The wrapper takes precedence for the six
inline hook event keys it supplies; don't separately configure those same
claude-mem hooks or install its native Codex plugin.

OpenCode discovers the upstream V2 JS adapter and connects the MCP server from
the existing JSONC template. Home Manager now renders that template into the
store to substitute an absolute MCP executable path: edit
`dotfiles/config/opencode/opencode.jsonc` and rebuild, not the installed file.
Claude receives upstream plugin skills; Codex/OpenCode additionally receive
`mem-search` and `smart-explore` without replacing their other skills.

## Runtime policy and limitations

- One lazily started worker is shared by the three agents, not three services.
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
  `claude-mem --version` prints launcher protocol **1**, not package semver.
- Back up the data directory before upgrades. Database migrations are not
  reversed by rolling back the Nix generation.

## Package verification (no system activation)

```sh
package=$(nix build --no-link --print-out-paths 'path:.#darwinConfigurations.clb-mini.pkgs.claude-mem')
python3 packages/claude-mem/runtime-smoke.py "$package"
```

`path:.` includes new, untracked implementation files during development. The
package build checks hook metadata, TOML overlays, grammar linking, launcher
protocol, and OpenCode V2 plugin setup/cleanup. The smoke test uses an isolated
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
task packages:update-claude-mem -- 13.40.0             # specific release
task packages:update-claude-mem -- 13.40.0 --dry-run   # validate without replacing files
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
closure follows the main nixpkgs lock, with protobuf 6 selected consistently
and MCP SDK 1.6.0 pinned as required by the bridge. Version assertions enforce
Chroma 1.5.9, ONNX Runtime >=1.20, protobuf <7, and Pydantic <2.14. Recheck those
constraints, the model archive hash, and semantic tests when updating nixpkgs.
Do not downgrade an existing Chroma store to an older engine: its schema/data
compatibility is separate from Nix package rollback.
