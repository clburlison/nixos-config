# Herdr Layout Picker

An `fzf` popup for creating a layout in a new tab or replacing an idle tab.
Self-contained plugin, usable outside this Nix repository.

## Controls

- **Prefix+l** opens the picker (configured in this repository).
- Type to fuzzy-search layouts.
- **Enter** creates and switches to a new tab in the original workspace.
- **Alt+Enter** replaces the original tab if every pane is an idle shell.
- **Escape** cancels.

Successful selections need no second prompt. If an error or cancellation occurs,
the popup shows the reason and stays open until **Enter** is pressed. Busy-pane
errors include the pane name/ID and process names/PIDs; a Herdr notification is
also sent. Foreground commands, background jobs (including stopped jobs), and
unavailable process information all prevent replacement. Exited zombie processes
are ignored. The check is point-in-time, immediately
before applying the layout; Herdr does not provide an atomic check-and-replace API.

All panes inherit the original focused pane's working directory unless overridden
in the layout. Commands run inside normal interactive shells, preserving shell
initialization such as mise and direnv. Shells remain usable after commands exit.

## Install

Requires Herdr **0.9.3+**, Python **3.9+**, `fzf`, and `ps` on macOS or Linux.
This repository supplies dependencies and registers the plugin via Home Manager.

For standalone use, install the dependencies, then:

```sh
herdr plugin link /absolute/path/to/herdr-layouts
```

Bind the action in Herdr's `config.toml`:

```toml
[[keys.command]]
key = "prefix+l"
type = "plugin_action"
command = "layouts.open"
description = "layouts: open picker"
```

Reload via Herdr's global menu, **reload config**, to refresh client keybindings
and server config.

## Layouts

Bundled presets:

- **Glim development**: three equal columns running npm, Rails, and Sidekiq.
- **Two columns**: two idle shells.
- **Triple split**: two top columns (75/25) above a full-width bottom pane (25% height).

Add JSON files under `layouts/` in the plugin, or under
`$(herdr plugin config-dir layouts)/layouts/` for user-local presets. A user file
with the same filename overrides a bundled preset. Filenames must not contain
whitespace. Layouts are reloaded whenever the picker opens.

```json
{
  "name": "Editor and shell",
  "tab_label": "edit",
  "root": {
    "type": "split",
    "direction": "right",
    "ratio": 0.7,
    "first": { "type": "pane", "label": "editor", "run": "nvim" },
    "second": { "type": "pane", "label": "shell" }
  }
}
```

Splits use `right` or `down`; `ratio` is the fraction allocated to `first`.
Nest splits for arbitrary arrangements, up to 24 panes and 16 levels.

`name` is required and supplies the display text in the layout picker.
All tab and pane labels are optional and may be blank (including whitespace-only):

- `tab_label`: custom tab name. If omitted or blank, the plugin does not rename
  the tab: new tabs use Herdr's automatic naming, and replacing an existing tab
  preserves its naming.
- Pane `label`: custom pane name. If omitted or blank, the plugin leaves the pane
  unnamed so Herdr can handle its naming. Replacing a layout creates new panes;
  names from the old panes are not carried over.

Pane fields:

- `label`: optional pane name; omitted or blank uses Herdr's naming.
- `run`: optional single-line shell command.
- `cwd`: optional absolute path, `~/...`, or path relative to the original cwd.
- `env`: optional string-to-string environment variables.

The tree uses Herdr's native layout format with `run` as an extension. The plugin
creates the shell layout through `layout.apply`, then dispatches commands through
`herdr pane run`. Herdr builds replacement panes before closing the old tab and
rolls back pane-creation failures. A command-dispatch failure is reported, leaving
the created layout available for inspection.

## Verification

From this repository's root:

```sh
python3 -B -m unittest discover -s plugins/herdr-layouts/tests -v
```

Include integration tests against temporary headless Herdr servers:

```sh
HERDR_LAYOUTS_INTEGRATION=1 python3 -B -m unittest discover -s plugins/herdr-layouts/tests -v
```

These use isolated config/socket directories and do not touch an existing session.
