# claude-mem: declarative host adapters

Research checked 2026-10-16. Source inspection only; no packages installed/run, no Nix evaluation/build or host sessions. The user-provided `claude-mem-nix.md` was read and left unchanged. claude-mem commit **`26e839a343616cda19b9ef391469c2dd81b49ca1` exists and declares 13.40.0**. This verifies source identity, not equivalence of published npm bundles to that commit. [1]

Adapter-detail companion to the main review, `docs/research/claude-mem-nix-review.md`. The coordinating session additionally reports locked-version Nix evaluation: primary `nodejs_24` **24.21.0**, overlaid unstable Bun **1.4.2**, Claude **2.1.293**, Codex **0.161.0**, Tree-sitter **0.26.11**, and OpenCode **2.0.31**. These evaluations were supplied to this research session, not independently rerun here.

## Conclusion

**Separate packaging from registration.** The note's full offline dependency-closure concerns are legitimate, but host registration can be much smaller: one packaged runtime/plugin tree, thin host-specific configuration, and one shared worker. Do not rewrite the memory adapters or introduce a generic agent-config framework just to register this plugin.

Two material simplifications missing from the note:

- Locked Home Manager already provides Claude's `plugins` wrapper and Codex's freeform TOML settings, including a documented inline-hook seam. [2][3][9]
- The upstream MCP server **already auto-starts the worker**. OpenCode's adapter explicitly expects this and retries capture POSTs while MCP starts it. A dedicated service is optional, not required for OpenCode-only operation when MCP is configured and starts successfully. [10][11]

## Actual repository and locked modules

Unlike the note's original AWS checkout, this is the Nix configuration repository. Local [`flake.lock`](../../flake.lock) locks Home Manager release-26.05 at `e5fcd298a00f08b6e8390baf04aa8edb62203070`; root nixpkgs resolves to `nixpkgs_2` (`774debe7a0d1b496e35677ad955a1011c6ff74f3`), not the separate `nixpkgs` node used by the skill input. [`flake.nix`](../../flake.nix) overlays Claude/Codex from unstable `8edc0c72e3a38faf5434e40d1f19431125fe4b30`; their source versions are **Claude 2.1.293 and Codex 0.161.0**. OpenCode is separately pinned to **V2.0.31**, commit `22728d67461260d56bb9796b9b8f36e1de47202e`. These are configuration/source facts, not a check of active PATH binaries. [4]

| Locked Home Manager seam | What it actually does |
| --- | --- |
| `programs.claude-code.plugins = [ pluginRoot ];` | Accepts paths/packages and wraps Claude with `--plugin-dir` for each. No marketplace activation script required. `mcpServers` builds another small plugin; avoid registering the same MCP server twice. [2] |
| `programs.claude-code.settings.hooks` | Registers direct lifecycle hooks in settings. In contrast, `programs.claude-code.hooks` only writes executable script files under `hooks/`; it does **not** register their events. [2] |
| `programs.codex.settings` | Freeform TOML: can express native marketplace/plugin config, `mcp_servers`, or inline `hooks`. No dedicated Codex plugin/hooks option at this lock. `skills` is already available. [3] |
| `programs.opencode.settings` | Freeform JSON can emit native V2 `plugins` and `mcp.servers`. No dedicated plugin-file option; use `xdg.configFile` for local JS discovery. **Keep `enableMcpIntegration = false`: the locked shared-MCP transformer emits the old direct `mcp.<name>` shape and `enabled`, not V2 `mcp.servers.<name>`/`disabled`.** Do not use this module's `tui` option for V2 terminal settings; it writes `tui.json`, not V2 `cli.json`. [5][6] |

[`home-manager.nix`](../../home-manager.nix) currently installs the host packages directly and links `~/.config/opencode/opencode.jsonc` to the dotfiles checkout. Migrating to `programs.opencode.settings` would add `opencode.json` alongside that existing JSONC owner; consolidate ownership deliberately rather than assuming a merged Nix option preserves the linked document. Existing agent-skills integration already manages shared skills, so inspect conflicts before adding another skills distributor. No configuration changes are proposed here.

## Claude Code: prefer the native directory plugin

Use the locked HM `plugins` option with the **plugin directory**, not the repository root (`plugin/.claude-plugin/plugin.json`, `plugin/hooks/hooks.json`, and `plugin/.mcp.json` live together). This preserves upstream hook discovery, skills, namespacing and MCP without an imperative marketplace install. HM already implements the wrapper the note proposes writing manually. [2][7]

The packaged variant should remove the `Setup` version-check/provisioning hook and startup `ensure-launcher.cjs` hook, while retaining actual handlers. Bind executable/root resolution to the packaged launcher and runtimes, and replace MCP's cache-searching Node snippet with an absolute packaged MCP wrapper. At this pin the real events are `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `Stop`, and `SessionEnd`; preserve matchers, timeouts and exec-form `args`. Merely listing `claude-mem` in `home.packages` is insufficient if it exposes the npm installer rather than the hook launcher. [1][7]

Direct settings hooks remain an alternative, but then separately distribute skills and MCP and omit the native plugin to avoid duplicate capture. They are not inherently simpler than HM's existing directory-plugin support.

## Codex: native registration is expressible; direct hooks are smaller

### Native plugin registration at the repo's Codex 0.161.0

The **versioned** Codex schema accepts `marketplaces.<name>.source_type = "local"`, `source`, and `plugins.<plugin-id>.enabled`. Its loader resolves local marketplaces directly from `source`; its CLI tests verify these exact emitted fields. Thus this registration shape is verified, rather than an invented registry file: [8]

```nix
programs.codex.settings = {
  marketplaces.claude-mem-local = {
    source_type = "local";
    source = "${claudeMem}/share/claude-mem";
  };
  plugins."claude-mem@claude-mem-local".enabled = true;
  features.hooks = true;
};
```

**Illustrative and not evaluated:** `claudeMem` must be a real package retaining `.agents/plugins/marketplace.json` and `plugin/` relative layout. The upstream catalog names `claude-mem-local` and points to `./plugin`; its Codex manifest registers `./skills/`, `./.mcp.json`, and `./hooks/codex-hooks.json`. Upstream installer requires marketplace support `>=0.128.0`; this is not a guarantee of every later host/provider capability. [7][12]

**Registration is not cache-free execution.** Official docs say local plugins are installed into a writable cache, and configured plugins may be refreshed even when disabled. claude-mem's hook-root resolver rejects explicit roots lacking `node_modules` and otherwise searches Claude caches. Patch hook commands/MCP to the Nix-owned runtime instead of assuming Codex's copied root has its dependencies. Native registration is now concrete; exact cache materialization and generation upgrades remain untested. [7][9][12]

### Direct-hook alternative

Codex officially supports both `hooks.json` and inline `[hooks]` in active config layers. Consequently **`programs.codex.settings.hooks` can own this directly**, avoiding even a separate hand-written `home.file` option. Generate from the pinned six-event Codex JSON, replace only path-discovery commands with packaged wrappers, and keep `CLAUDE_MEM_CODEX_HOOK=1`, stdin, timeouts, matchers and disable flags. Events are `SessionStart`/context, `UserPromptSubmit`/session-init, `PreToolUse`/file-context, `PostToolUse`/observation, `Stop`/summarize, and `PostCompact`/post-compact. Register MCP in `settings.mcp_servers`; distribute skills through the existing owner. [3][7][9]

Pick **one** delivery mode. All matching hook sources run; higher-precedence hooks do not replace lower ones. Native plugin plus direct hooks causes duplicate work. Non-managed hook definitions require `/hooks` review/trust, tied to their hashes; do not manufacture trust or bypass it as part of HM activation. The observer provider is independent of this registration. [9]

## OpenCode V2 only

At the claude-mem pin the default export includes V2 `id`/`setup`. Its V2 implementation registers tool execution, prompt, context and compaction hooks, transforms tools, subscribes to V2 session events and returns cleanup. **Use this adapter, not a hand-written shell-hook translation.** Its presence is source-verified, not an end-to-end compatibility test against V2.0.31. [13]

Smallest seam: link the packaged bundle to `~/.config/opencode/plugins/claude-mem.js` with `xdg.configFile`, and declare:

```nix
programs.opencode.settings.mcp.servers.claude-mem = {
  type = "local";
  command = [ "${claudeMem}/bin/claude-mem-mcp" ];
};
```

The wrapper name/layout is a **proposed package interface**, not an upstream executable. V2 documents global `.js`/`.ts` plugin discovery and stdio local servers under `mcp.servers`, with executable and argv in `command`. MCP provides retrieval and bootstrapping; the plugin provides capture/context. Configure both. [6][10][11][14]

**Documentation uncertainty:** the fetched V2 build guide illustrates configured local plugin *directories*, whereas the linked V2 configure guide also shows configured file paths (`../shared/plugin.ts`). Therefore the original note's categorical “configured paths must be directories” is not established by the current docs. Discovered JS is explicitly documented and avoids relying on that disagreement. No V1 setup is recommended. [6][14]

## Shared worker: choose one lifecycle owner

**Simplest initial design:** retain upstream lazy worker management. MCP startup calls `ensureWorkerConnection()` → shared `ensureWorkerStarted()`. OpenCode capture retries connection-refused POSTs for approximately 10 seconds while that starts; retries are bounded and can still drop early capture on slow/failed boot. Claude startup also calls `start`. These do not imply one independent worker per host; the shared spawn gate/health checks coordinate the common worker. Keep host/port/data directory consistent across all wrappers. [10][11][15]

**If explicit supervision is wanted:** the concrete worker foreground entry is `bun <pluginRoot>/scripts/worker-service.cjs --daemon`; despite its name, this branch creates/runs `WorkerService` in the current process. `start` instead ensures/spawns a daemon and exits, so it is not the appropriate foreground `ExecStart`/`ProgramArguments` target. Set **`CLAUDE_MEM_WORKER_AUTOSTART=false`** in the shared runtime policy: the shared spawner then probes health/readiness but does not launch, kill, reclaim or clean its PID file. This is an existing external-management seam. [15][16]

A service is not turnkey even with that flag: inspect/patch worker self-replacement on restart, idle exit, duplicate-success exit and shutdown semantics before enabling aggressive restart policies. The foreground worker also exits if Claude settings explicitly disable `claude-mem@thedotmack`, a cross-host coupling worth testing for Codex/OpenCode-only use. Do not run three separately supervised workers against one data directory/port. [16]

## Existing community tooling: useful but not a runtime solution

**`srid/nix-agent-wire` is real.** At inspected commit `69e550ac2a922b72f781c165d68a3f549582dc45`, its README advertises Claude/OpenCode autowiring of skills, agents, commands, settings and MCP, not Codex or claude-mem packaging. Its OpenCode module delegates to shared MCP integration (the problematic transformer at this HM lock) and has no claude-mem runtime/service seam. It is configuration organization, not a substitute for the package or verified V2 adapter. No reason was established to add it for this task. [17]

**`dryvist/nix-claude-code` is also real.** Inspected revision `e3030c2fc3a3612d71ce1cf865773526d0f3f27b` provides its own `programs.claude` ecosystem. Its [plugin module](https://github.com/dryvist/nix-claude-code/blob/e3030c2fc3a3612d71ce1cf865773526d0f3f27b/modules/plugins.nix) uses activation-time stable directory symlinks for flake-owned marketplaces, explicitly addressing marketplace-link churn and mutable Claude cache behavior. Its [README](https://github.com/dryvist/nix-claude-code/blob/e3030c2fc3a3612d71ce1cf865773526d0f3f27b/README.md) advertises composable plugins/hooks/MCP and optional marketplace-refresh/latest-installer features. Useful prior art for a larger Claude marketplace policy; not evidence that claude-mem's runtime closure or Codex/OpenCode adapters are solved. For this isolated integration, native HM `programs.claude-code.plugins` is the smaller seam and avoids adopting another settings owner or refresh policy. No blanket compatibility or reproducibility claim is inferred from the README.

## Implementation boundary and remaining gates

Recommended boundary: **one package exporting stable plugin-root/MCP/launcher paths; one small HM module composing existing host options; writable state outside the store.** Choose native Claude, native or direct Codex, and the upstream V2 JS adapter. Choose lazy startup first unless explicit supervision is an actual requirement.

This reduces registration complexity, **not** the note's full-offline packaging workload: npm's `claude-mem` bin is the installer; the worker still requires Bun and runtime dependency/native assets. Community autowiring cannot make an incomplete package complete. [1]

Unverified: source-to-npm equivalence, package closure, immutable plugin execution, Codex cache refresh across generations, host hook trust/hash behavior with store-path changes, real capture/retrieval and worker restart coordination. Moving host docs were checked today; versioned sources support the concrete HM/Codex claims above. No claim of successful deployment is made.

## Primary sources

[1]: https://github.com/thedotmack/claude-mem/blob/26e839a343616cda19b9ef391469c2dd81b49ca1/package.json
[2]: https://github.com/nix-community/home-manager/blob/e5fcd298a00f08b6e8390baf04aa8edb62203070/modules/programs/claude-code.nix
[3]: https://github.com/nix-community/home-manager/blob/e5fcd298a00f08b6e8390baf04aa8edb62203070/modules/programs/codex.nix
[4]: https://github.com/NixOS/nixpkgs/tree/8edc0c72e3a38faf5434e40d1f19431125fe4b30/pkgs/by-name
[5]: https://github.com/nix-community/home-manager/blob/e5fcd298a00f08b6e8390baf04aa8edb62203070/modules/programs/opencode.nix
[6]: https://opencode.ai/v2/docs/build/plugins
[7]: https://github.com/thedotmack/claude-mem/tree/26e839a343616cda19b9ef391469c2dd81b49ca1/plugin
[8]: https://github.com/openai/codex/blob/rust-v0.161.0/codex-rs/core/config.schema.json
[9]: https://developers.openai.com/codex/hooks/
[10]: https://github.com/thedotmack/claude-mem/blob/26e839a343616cda19b9ef391469c2dd81b49ca1/src/servers/mcp-server.ts
[11]: https://github.com/thedotmack/claude-mem/blob/26e839a343616cda19b9ef391469c2dd81b49ca1/src/integrations/opencode-plugin/worker-retry.ts
[12]: https://github.com/thedotmack/claude-mem/blob/26e839a343616cda19b9ef391469c2dd81b49ca1/src/services/integrations/CodexCliInstaller.ts
[13]: https://github.com/thedotmack/claude-mem/tree/26e839a343616cda19b9ef391469c2dd81b49ca1/src/integrations/opencode-plugin
[14]: https://opencode.ai/v2/docs/plugins
[15]: https://github.com/thedotmack/claude-mem/blob/26e839a343616cda19b9ef391469c2dd81b49ca1/src/services/worker-spawner.ts
[16]: https://github.com/thedotmack/claude-mem/blob/26e839a343616cda19b9ef391469c2dd81b49ca1/src/services/worker-service.ts
[17]: https://github.com/srid/nix-agent-wire/tree/69e550ac2a922b72f781c165d68a3f549582dc45

Additional exact references: [Codex local-source resolution](https://github.com/openai/codex/blob/rust-v0.161.0/codex-rs/core-plugins/src/installed_marketplaces.rs), [Codex CLI registration test](https://github.com/openai/codex/blob/rust-v0.161.0/codex-rs/cli/tests/marketplace_add.rs), [Codex plugin/cache docs](https://developers.openai.com/plugins/build/plugins), [OpenCode V2 MCP shape](https://opencode.ai/v2/docs/mcp-servers), [Claude package manifest](https://github.com/NixOS/nixpkgs/blob/8edc0c72e3a38faf5434e40d1f19431125fe4b30/pkgs/by-name/cl/claude-code/manifest.zst.json), [Codex package version](https://github.com/NixOS/nixpkgs/blob/8edc0c72e3a38faf5434e40d1f19431125fe4b30/pkgs/by-name/co/codex/package.nix).
