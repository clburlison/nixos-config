# Setup guide

The order of operations for setting everything up from scratch. srv-devbox is
the hub: it holds the Claude and Codex logins (CLIProxyAPI) and the shared
memory server (claude-mem). Every Mac is a client of it. So set up
1Password first, then srv-devbox, then each Mac.

Each step links to the section that does it. Do them in order; a step
assumes the ones before it.

## 0. 1Password and GitHub (once)

Needs a computer with 1Password and `op` signed in as you
([agent-git.md](agent-git.md#before-you-start-sign-in-to-op)).

1. Create the `Agents` vault and the `git-agent` SSH key, and add the key to
   GitHub: [agent-git.md](agent-git.md#one-time-setup), steps 1 and 2.
2. Create the `agents` service account and save its token in your Private
   vault: [op-agents.md](op-agents.md#one-time-setup).
3. Create the Agents items srv-devbox reads: every srv-devbox row of
   [Agents vault items](op-agents.md#agents-vault-items). Generate the values
   as each one's section says ([CLIProxyAPI keys](srv-devbox.md#keys),
   [Keeper password](srv-devbox.md#12-cpa-usage-keeper), OpenRouter at
   <https://openrouter.ai/keys>). The claude-mem keys don't exist yet: create
   `claude-mem-viewer` with a placeholder `credential` and replace it in
   srv-devbox step 13.

## 1. srv-devbox

All in [srv-devbox.md](srv-devbox.md):

| Step | What |
| --- | --- |
| [1](srv-devbox.md#1-create-the-proxmox-vm), [2](srv-devbox.md#2-partition-and-mount) | Create the VM, partition and mount |
| [3](srv-devbox.md#3-generate-and-push-the-hardware-file-required) | Generate the hardware file and push it from a machine with GitHub access |
| [4](srv-devbox.md#4-install) | Install and reboot |
| [5](srv-devbox.md#5-ssh-in-and-clone), [6](srv-devbox.md#6-bootstrap-home-manager) | SSH in with a forwarded agent, clone, bootstrap Home Manager |
| [7](srv-devbox.md#7-op-agents-token) | Encrypt the op-agents token to the host ([op-agents.md](op-agents.md#nixos-host)); the services start |
| [8](srv-devbox.md#8-agent-git) | Check agent-git, switch the clone to SSH |
| [9](srv-devbox.md#9-tailscale) | Join the tailnet, disable key expiry |
| [10](srv-devbox.md#10-t3-code-server) | T3 Code server |
| [11](srv-devbox.md#11-cliproxyapi-hub) | CLIProxyAPI hub: sign in the Claude and Codex accounts |
| [12](srv-devbox.md#12-cpa-usage-keeper) | CPA Usage Keeper dashboard |
| [13](srv-devbox.md#13-claude-mem-hosted-server) | claude-mem server: create the host and viewer keys, save them in 1Password |

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
| [srv-devbox.md](srv-devbox.md) | The NixOS hub: install, Tailscale, T3 Code, CLIProxyAPI, CPA Usage Keeper, claude-mem server |
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
| Rotate the claude-mem host or viewer key | [srv-devbox.md](srv-devbox.md#api-keys) |
| Add a Claude or Codex account to the hub | [srv-devbox.md](srv-devbox.md#account-logins) |
| Upgrade the claude-mem server | [srv-devbox.md](srv-devbox.md#upgrading) |
| Update the claude-mem plugin | [claude-mem.md](claude-mem.md#updating) |
