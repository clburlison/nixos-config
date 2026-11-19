# Setup guide

The order of operations for setting everything up from scratch. ai-hub is
the hub: it holds the Claude and Codex logins (CLIProxyAPI) and the shared
memory server (claude-mem). Every Mac is a client of it. So set up
1Password first, then ai-hub, then each Mac.

Each step links to the section that does it. Do them in order; a step
assumes the ones before it.

## 0. 1Password and GitHub (once)

Needs a computer with 1Password and `op` signed in as you
([agent-git.md](agent-git.md#before-you-start-sign-in-to-op)).

1. Create the `Agents` vault and the `git-agent` SSH key, and add the key to
   GitHub: [agent-git.md](agent-git.md#one-time-setup), steps 1 and 2.
2. Create the `agents` service account and save its token in your Private
   vault: [op-agents.md](op-agents.md#one-time-setup).
3. Create the Agents items ai-hub reads: every ai-hub row of
   [Agents vault items](op-agents.md#agents-vault-items). Generate the values
   as each one's section says ([CLIProxyAPI keys](ai-hub.md#keys),
   [Keeper password](ai-hub.md#12-cpa-usage-keeper), OpenRouter at
   <https://openrouter.ai/keys>). The claude-mem keys don't exist yet: create
   `claude-mem-viewer` with a placeholder `credential` and replace it in
   ai-hub step 13.

## 1. ai-hub

All in [ai-hub.md](ai-hub.md):

| Step | What |
| --- | --- |
| [1](ai-hub.md#1-create-the-proxmox-vm), [2](ai-hub.md#2-partition-and-mount) | Create the VM, partition and mount |
| [3](ai-hub.md#3-generate-and-push-the-hardware-file-required) | Generate the hardware file and push it from a machine with GitHub access |
| [4](ai-hub.md#4-install) | Install and reboot |
| [5](ai-hub.md#5-ssh-in-and-clone), [6](ai-hub.md#6-bootstrap-home-manager) | SSH in with a forwarded agent, clone, bootstrap Home Manager |
| [7](ai-hub.md#7-op-agents-token) | Encrypt the op-agents token to the host ([op-agents.md](op-agents.md#nixos-host)); the services start |
| [8](ai-hub.md#8-agent-git) | Check agent-git, switch the clone to SSH |
| [9](ai-hub.md#9-tailscale) | Join the tailnet, disable key expiry |
| [10](ai-hub.md#10-t3-code-server) | T3 Code server |
| [11](ai-hub.md#11-cliproxyapi-hub) | CLIProxyAPI hub: sign in the Claude and Codex accounts |
| [12](ai-hub.md#12-cpa-usage-keeper) | CPA Usage Keeper dashboard |
| [13](ai-hub.md#13-claude-mem-hosted-server) | claude-mem server: create the host and viewer keys, save them in 1Password |
| [14](ai-hub.md#14-ai-usage-analytics) | AI usage analytics (nothing to do) |
| [15](ai-hub.md#15-obot-mcp-gateway) | Obot MCP gateway: Tailscale policy, auth key, owner login, OAuth apps, vMCPs, per-host keys (`MCP hub token <host>`) |

## 2. Each Mac

| Step | What |
| --- | --- |
| [Install](macos.md#1-install) | Install Nix, apply the configuration |
| [op-agents token](op-agents.md#mac) | Store the token in the keychain; agent-git and the CLIProxyAPI client follow from it |
| [agent-git](agent-git.md#4-apply-and-set-the-token) | `agent-git-check`, switch the clone to SSH |
| [claude-mem](claude-mem.md#hosted-server) | Server key in settings and the MCP header; approve Codex hooks |
| [Git overrides](gitconfig.md) (optional) | Work email under a directory |

## Guides

| Guide | Covers |
| --- | --- |
| [ai-hub.md](ai-hub.md) | The NixOS hub: install, Tailscale, T3 Code, CLIProxyAPI, CPA Usage Keeper, claude-mem server, Obot MCP gateway |
| [macos.md](macos.md) | Installing a Mac |
| [op-agents.md](op-agents.md) | The one secret per host, the Agents vault items, rotating secrets |
| [agent-git.md](agent-git.md) | Commit signing and GitHub SSH while 1Password is locked |
| [claude-mem.md](claude-mem.md) | Shared agent memory on each host: plugin, server connection, updates |
| [gitconfig.md](gitconfig.md) | Private Git overrides |
| [research/](research/) | Background notes, not instructions |

## Day-to-day

| Task | Where |
| --- | --- |
| Rotate a secret in the Agents vault | [op-agents.md](op-agents.md#operations) |
| Rotate the service account token | [op-agents.md](op-agents.md#operations) |
| Rotate the claude-mem host or viewer key | [ai-hub.md](ai-hub.md#api-keys) |
| Add a Claude or Codex account to the hub | [ai-hub.md](ai-hub.md#account-logins) |
| Upgrade the claude-mem server | [ai-hub.md](ai-hub.md#upgrading) |
| Update the claude-mem plugin | [claude-mem.md](claude-mem.md#updating) |
