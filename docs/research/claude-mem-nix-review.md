# claude-mem: Nix integration review

Checked 2026-10-16 against claude-mem 13.40.0 / [`26e839a`](https://github.com/thedotmack/claude-mem/tree/26e839a343616cda19b9ef391469c2dd81b49ca1). This reviews the user-provided `claude-mem-nix.md`; it does not replace or modify it. No installation, activation, or system build was performed.

## Recommendation

**Use one Nix-owned runtime package and one Home Manager integration module, with three independently enabled host adapters.** Keep the upstream installer out of activation. Derive adapter configuration from the pinned release rather than maintaining a second handwritten implementation of its capture logic.

The original note is broadly sound as a **full offline packaging plan**, but that is a larger goal than declaratively configuring hooks. Separate these milestones:

1. Package the published bundles and required JavaScript runtime dependencies; configure capture, retrieval, skills, and a shared worker declaratively. Start with SQLite-only search if acceptable, explicitly documenting the missing vector-search feature.
2. Package smart-file grammar libraries and the Python/Chroma/model closure, eliminate runtime provisioning, and test offline operation. Do not label milestone 1 a full-feature or download-free installation until its actual runtime paths are tested.

Do not use an activation-time installer as an intermediate architecture unless mutable upstream ownership is an intentional tradeoff. A pinned `npx` invocation pins the installer, not every artifact it subsequently resolves or updates. Upstream installation explicitly installs dependencies, writes host registration/settings, and provisions the launcher. [Installation guide][installation]

## Repo-specific corrections

The note's old repository-boundary warning no longer applies: this checkout is the intended Nix configuration repository.

| Item | Verified here |
|---|---|
| Main nixpkgs | `nixos-26.05`, revision `774debe7a0d1b496e35677ad955a1011c6ff74f3` |
| Home Manager | `release-26.05`, revision `e5fcd298a00f08b6e8390baf04aa8edb62203070` |
| Node | `nodejs_24` evaluates to **24.21.0** |
| Overlaid packages | Bun **1.4.2**, Claude Code **2.1.293**, Codex **0.161.0**, Tree-sitter **0.26.11** |
| OpenCode | Explicit flake pin **2.0.31** |
| Config ownership | `home-manager.nix` links the existing `dotfiles/config/opencode/opencode.jsonc` out of store; do not introduce a competing `opencode.json` |
| Skills | Existing `programs.agent-skills` already targets Claude, Codex, OpenCode, and shared agents; avoid duplicate skill registration |
| Platforms | Active Darwin configurations use `aarch64-darwin`; WSL uses `x86_64-linux` |

Sources: local `flake.nix`, `flake.lock`, `home-manager.nix`; package versions evaluated with `nix eval`, not inferred from channel names. These versions satisfy the upstream declared Node/Bun minimums and installer host floors, **not** an end-to-end compatibility test. Tree-sitter differs from the plugin's exact **0.26.9** pin and must be deliberately matched or tested. [Root manifest][manifest] [Plugin manifest][plugin-manifest]

## Packaging: reuse the layout, not just npm's bin

The repository has four package expressions, but they are not four equivalent npm packaging solutions:

- `packages/codeburn.nix`: useful `buildNpmPackage` precedent, with Node 24 and a locked dependency hash.
- `packages/ntn.nix` and `packages/linear-cli.nix`: useful fixed-output published-artifact precedents, not npm dependency builders.
- `packages/opencode.nix`: host-package adaptation; not a substitute for claude-mem dependency packaging.

**The shortest first route is the npm release archive plus separately locked root/plugin runtime dependencies.** It avoids reproducing esbuild/UI outputs or maintaining all root development dependencies initially. A source build remains a separate upgrade in provenance, not a prerequisite for declarative hooks. The npm manifest's `bin.claude-mem` is the installer; export the hook launcher under that name instead. [Manifest][manifest]

The 13.40.0 archive was downloaded for inspection only. Its SHA-512 matches registry integrity, and its raw `fetchurl` hash is:

```text
https://registry.npmjs.org/claude-mem/-/claude-mem-13.40.0.tgz
sha256-GdtXOmG+QglxRnqf6TyzcaTcsgHVSwU/aey0QSggr8Y=
```

This is a **raw archive hash**, not `fetchzip`'s unpacked/NAR hash. Archive membership confirms the OpenCode bundle, worker, MCP server, launcher bundle, and `plugin/bun.lock`. It does not include installed root/plugin `node_modules` or a root npm lock. This confirms the artifact shortcut, **not a successful Nix package build**. [Registry metadata][registry]

The main nixpkgs pin has `buildNpmPackage`; evaluated `bun2nix` and `fetchBunDeps` attributes are absent. Use the existing npm helper plus maintained locks, or deliberately introduce a separate Bun packaging helper—do not assume Bun's presence supplies one. Preserve the nested plugin layout and use absolute runtime paths. [Pinned npm helper][npm-helper]

## Two opportunities to reduce the patch surface

### Prebuilt grammar directory instead of patching parser lookup

The original note suggests patching grammar lookup to store artifacts. There is a potentially smaller seam: Home Manager can link **only** `~/.claude-mem/tree-sitter-libs` to a package output of prebuilt libraries, while leaving the surrounding data directory writable.

At this pin the parser checks `<data-dir>/tree-sitter-libs/<language>.dylib` on Darwin or `.so` on Linux. It invokes compilation only when the library is absent or older than its packaged grammar sources. A complete store-backed directory with compatible artifacts and verified timestamps could therefore avoid a lookup patch. Package-local `tree-sitter-cli/tree-sitter` can similarly be a store symlink instead of a downloaded npm binary. [Parser][parser] [CLI resolver][tree-bin]

**Untested candidate, not a guarantee:** all supported languages, ABI compatibility, mtime behavior, upgrade relinking, and compiler fallback paths must be checked. Missing or unloadable libraries may still trigger fallback compilation. Do not overwrite an existing user-managed grammar directory automatically. A small explicit source patch may ultimately be clearer than relying on cache semantics.

### Chroma executable adapter instead of mandatory source patch

The note is correct that remote Chroma still needs the Python MCP bridge. However, patching worker source is not the only executable substitution seam. `CLAUDE_MEM_CHROMA_UVX_PATH` influences the child PATH; on Darwin/Linux the command remains the literal `uvx`. A dedicated package directory containing a narrowly scoped `uvx` adapter could dispatch to the packaged `chroma-mcp`, validating/removing the pinned uv-specific prefix while preserving server arguments, `--help`, stdio, signals, and exit status. [Chroma launcher][chroma]

This does **not** eliminate Python/model packaging. Do not point that setting directly at `chroma-mcp` and assume its argument syntax matches uvx, or intercept the user's general-purpose uvx. Prefer a small source patch if its contract is easier to test and maintain than the adapter.

## Ownership choices

- **Host configuration:** one owner per file, merging unrelated hooks/MCP/plugins. The locked Home Manager already provides the following seams; a new generic agent-config framework is unnecessary. See the [host-adapter companion](claude-mem-host-adapters.md) for versioned source citations and examples.
  - Claude: `programs.claude-code.plugins = [ pluginRoot ];` already implements `--plugin-dir`. Use a patched plugin tree preserving actual hooks, skills, and MCP; no custom Claude wrapper or marketplace activation is necessary.
  - Codex: `programs.codex.settings.hooks` supports direct inline hooks, plus `settings.mcp_servers` for retrieval. Native local-marketplace fields are also source-verified at Codex 0.161.0, but its writable cache still complicates store-root execution. Direct hooks are the smaller initial choice.
  - OpenCode V2: auto-discover the upstream JS adapter and configure `mcp.servers`. If migrating to `programs.opencode.settings`, remove the competing out-of-store JSONC owner deliberately. Keep `enableMcpIntegration = false`: the locked shared-MCP conversion emits legacy shapes.
- **Runtime environment:** wrapper/service-owned absolute paths, including the observer CLI. Existing interactive shell setup prepends `~/.bun/bin`, so relying on the user's PATH can silently select a mutable Bun rather than the pinned one. GUI-launched hosts also need the same environment.
- **Settings:** initially keep mutable settings/credentials out of the store and express chosen nonsecret policy through service/wrapper environment overrides. Full store ownership of settings is optional, not a requirement for declarative hooks. Ensure worker and MCP use the same data directory and policy.
- **Worker:** choose one lifecycle owner. **Start with upstream lazy management:** MCP already calls the shared worker starter, and the OpenCode adapter retries capture while it boots. A launchd/systemd service is optional, not a prerequisite for OpenCode-only use. If supervision is needed, the verified foreground branch is `bun <pluginRoot>/scripts/worker-service.cjs --daemon`, with `CLAUDE_MEM_WORKER_AUTOSTART=false` in the shared runtime policy. Despite its name, `--daemon` runs in the current process; `start` launches/ensures a daemon and exits. Check idle exit/self-replacement/restart behavior before enabling aggressive restart policies. [Worker spawner][worker-spawner] [Worker entry][worker-entry]
- **Trust:** Codex hook approval and host authentication remain explicit user actions. Nix reproducibility does not imply permission to bypass them.

Suggested local shape: `packages/claude-mem.nix`, imported `modules/home/claude-mem.nix`, and package-level smoke checks. Follow this repo's existing overlay and imports rather than introducing a new multi-output public flake architecture merely to use it locally. A public reusable module can come later.

## Completion criteria

Do not stop at “MCP connected.” Verify one real capture → persisted observation → later recall cycle for **each** host, including OpenCode-only worker startup. Check exact hook events/arguments against the pinned release, absence of duplicate delivery, clean-HOME behavior, config immutability, shutdown/restart, and generation upgrades. For an offline claim, block dependency downloads and runtime compiler access and exercise every enabled grammar and vector-search path. Back up the database independently of Nix generations.

[installation]: https://docs.claude-mem.ai/installation.md
[manifest]: https://github.com/thedotmack/claude-mem/blob/26e839a343616cda19b9ef391469c2dd81b49ca1/package.json
[plugin-manifest]: https://github.com/thedotmack/claude-mem/blob/26e839a343616cda19b9ef391469c2dd81b49ca1/plugin/package.json
[registry]: https://registry.npmjs.org/claude-mem/13.40.0
[npm-helper]: https://github.com/NixOS/nixpkgs/blob/774debe7a0d1b496e35677ad955a1011c6ff74f3/pkgs/build-support/node/build-npm-package/default.nix
[parser]: https://github.com/thedotmack/claude-mem/blob/26e839a343616cda19b9ef391469c2dd81b49ca1/src/services/smart-file-read/parser.ts#L377-L448
[tree-bin]: https://github.com/thedotmack/claude-mem/blob/26e839a343616cda19b9ef391469c2dd81b49ca1/src/services/smart-file-read/tree-sitter-bin-path.ts
[chroma]: https://github.com/thedotmack/claude-mem/blob/26e839a343616cda19b9ef391469c2dd81b49ca1/src/services/sync/ChromaMcpManager.ts
[worker-spawner]: https://github.com/thedotmack/claude-mem/blob/26e839a343616cda19b9ef391469c2dd81b49ca1/src/services/worker-spawner.ts
[worker-entry]: https://github.com/thedotmack/claude-mem/blob/26e839a343616cda19b9ef391469c2dd81b49ca1/src/services/worker-service.ts
