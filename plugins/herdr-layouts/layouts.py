#!/usr/bin/env python3
"""Herdr popup layout picker. Requires only Python's standard library and fzf."""

import argparse
import copy
import json
import os
from pathlib import Path
import socket
import subprocess
import sys


ROOT = Path(__file__).resolve().parent
SHELLS = {"sh", "bash", "zsh", "fish", "dash", "ksh", "mksh", "nu", "tcsh", "csh"}


class LayoutError(Exception):
  pass


class Api:
  def __call__(self, method, **params):
    path = os.environ.get("HERDR_SOCKET_PATH")
    if not path:
      raise LayoutError("HERDR_SOCKET_PATH is missing; launch through Herdr.")
    request = {"id": "layouts", "method": method, "params": params}
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
      connection.settimeout(15)
      connection.connect(path)
      connection.sendall((json.dumps(request) + "\n").encode())
      with connection.makefile("r") as response:
        data = json.loads(response.readline())
    if "error" in data:
      raise LayoutError(data["error"]["message"])
    return data["result"]


def pane_nodes(node):
  if node["type"] == "pane":
    yield node
  else:
    yield from pane_nodes(node["first"])
    yield from pane_nodes(node["second"])


def validate_node(node, depth=1):
  if not isinstance(node, dict) or depth > 16:
    raise LayoutError("Invalid layout node or more than 16 nesting levels.")
  if node.get("type") == "split":
    ratio = node.get("ratio")
    if (node.get("direction") not in {"right", "down"}
        or type(ratio) not in (int, float) or not 0 < ratio < 1):
      raise LayoutError("Splits need direction right/down and a ratio between 0 and 1.")
    if set(node) - {"type", "direction", "ratio", "first", "second"}:
      raise LayoutError("Unknown split field.")
    validate_node(node.get("first"), depth + 1)
    validate_node(node.get("second"), depth + 1)
  elif node.get("type") == "pane":
    if set(node) - {"type", "label", "cwd", "env", "run"}:
      raise LayoutError("Unknown pane field; use run for shell commands.")
    for key in ("label", "cwd", "run"):
      if key in node and (not isinstance(node[key], str)
                          or (key != "label" and not node[key].strip())
                          or any(char in node[key] for char in "\x00\n\r")):
        requirement = "a" if key == "label" else "a nonempty,"
        raise LayoutError(f"Pane {key} must be {requirement} single-line string.")
    env = node.get("env", {})
    if not isinstance(env, dict) or any(
        not isinstance(key, str) or not key or "=" in key or "\x00" in key
        or not isinstance(value, str) or "\x00" in value
        for key, value in env.items()):
      raise LayoutError("Pane env must contain valid string environment variables.")
  else:
    raise LayoutError("Each layout node needs type pane or split.")


def load_layouts(root=ROOT, config_dir=None):
  paths = {path.stem: path for path in (root / "layouts").glob("*.json")}
  if config_dir:
    paths.update({path.stem: path for path in (Path(config_dir) / "layouts").glob("*.json")})
  layouts = {}
  for identifier, path in sorted(paths.items()):
    try:
      layout = json.loads(path.read_text())
      for key in ("name", "tab_label"):
        value = layout.get(key, "")
        if (not isinstance(value, str)
            or (key == "name" and not value.strip())
            or any(ord(char) < 32 for char in value)):
          requirement = "a nonempty" if key == "name" else "a"
          raise LayoutError(f"{key} must be {requirement} single-line string.")
      if not identifier or any(char.isspace() for char in identifier):
        raise LayoutError("Layout filenames must not contain whitespace.")
      validate_node(layout.get("root"))
      if len(list(pane_nodes(layout["root"]))) > 24:
        raise LayoutError("A layout may contain at most 24 panes.")
    except (ValueError, AttributeError, LayoutError) as error:
      raise LayoutError(f"{path.name}: {error}") from error
    layouts[identifier] = layout
  if not layouts:
    raise LayoutError("No layouts found.")
  return layouts


def select_layout(layouts):
  rows = "".join(f"{key}\t{layout['name']}\n" for key, layout in layouts.items())
  env = dict(os.environ, FZF_DEFAULT_OPTS="", FZF_DEFAULT_OPTS_FILE=os.devnull)
  result = subprocess.run(
    ["fzf", "--layout=reverse", "--border", "--no-multi", "--delimiter=\t",
     "--with-nth=2..", "--prompt=Layout> ",
     "--header=Enter: new tab | Alt+Enter: replace idle tab | Esc: cancel",
     "--expect=enter,alt-enter", "--bind=esc:abort"],
    input=rows, text=True, stdout=subprocess.PIPE, env=env,
  )
  if result.returncode in (1, 130):
    return None
  if result.returncode:
    raise LayoutError(f"fzf failed (exit {result.returncode}).")
  lines = result.stdout.splitlines()
  if len(lines) != 2 or lines[0] not in {"enter", "alt-enter"}:
    raise LayoutError("Unexpected picker result.")
  identifier = lines[1].split("\t", 1)[0]
  if identifier not in layouts:
    raise LayoutError("Unknown layout selected.")
  return layouts[identifier], lines[0] == "alt-enter"


def process_snapshot():
  result = subprocess.run(
    ["ps", "-axo", "pid=,ppid=,comm="], check=True, text=True, stdout=subprocess.PIPE,
  )
  processes = {}
  for line in result.stdout.splitlines():
    pid, parent, command = line.split(None, 2)
    processes[int(pid)] = (int(parent), Path(command).name)
  return processes


def require_idle(api, panes):
  # Check all shell descendants, not just foreground jobs. A background server
  # must also prevent replacement. Unknown/missing process data fails closed.
  infos = [api("pane.process_info", pane_id=pane["pane_id"])["process_info"]
           for pane in panes]
  processes = process_snapshot()
  for pane, info in zip(panes, infos):
    shell_pid = info.get("shell_pid")
    shell = processes.get(shell_pid)
    name = pane.get("label", pane["pane_id"])
    shell_name = shell[1].lstrip("-").removeprefix(".").removesuffix("-wrapped") if shell else ""
    if shell_name not in SHELLS:
      raise LayoutError(f"Cancelled: {name} is not an idle shell (or cannot be checked).")
    foreground = info.get("foreground_processes")
    if (not foreground or any(proc.get("pid") != shell_pid for proc in foreground)):
      raise LayoutError(f"Cancelled: {name} has a running foreground command.")
    children = [command for parent, command in processes.values() if parent == shell_pid]
    if children:
      raise LayoutError(f"Cancelled: {name} has running processes: {', '.join(children)}.")


def apply_layout(api, origin_id, layout, replace):
  origin = api("pane.get", pane_id=origin_id)["pane"]
  cwd = origin.get("foreground_cwd") or origin["cwd"]
  root = copy.deepcopy(layout["root"])
  commands = []
  for node in pane_nodes(root):
    commands.append(node.pop("run", None))
    if not node.get("label", "").strip():
      node.pop("label", None)
    node_cwd = Path(node.get("cwd", cwd)).expanduser()
    node["cwd"] = str(node_cwd if node_cwd.is_absolute() else Path(cwd) / node_cwd)
  params = {"root": root, "focus": True}
  if layout.get("tab_label", "").strip():
    params["tab_label"] = layout["tab_label"].strip()
  if replace:
    panes = api("pane.list", workspace_id=origin["workspace_id"])["panes"]
    panes = [pane for pane in panes if pane["tab_id"] == origin["tab_id"]]
    if not panes or origin_id not in {pane["pane_id"] for pane in panes}:
      raise LayoutError("Cancelled: the original tab changed while the picker was open.")
    require_idle(api, panes)
    params["tab_id"] = origin["tab_id"]
  else:
    params["workspace_id"] = origin["workspace_id"]
  result = api("layout.apply", **params)
  created = list(pane_nodes(result["layout"]["root"]))
  if len(created) != len(commands):
    raise LayoutError("Herdr returned an unexpected number of panes.")
  for node, command in zip(created, commands):
    if command:
      subprocess.run(
        [os.environ.get("HERDR_BIN_PATH", "herdr"), "pane", "run", node["pane_id"], command],
        check=True, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
      )
  if not replace:
    api("tab.focus", tab_id=result["layout"]["tab_id"])


def open_picker(api):
  context = json.loads(os.environ.get("HERDR_PLUGIN_CONTEXT_JSON", "{}"))
  origin_id = os.environ.get("HERDR_PANE_ID") or context.get("focused_pane_id")
  if not origin_id:
    raise LayoutError("No focused pane to open layouts from.")
  origin = api("pane.get", pane_id=origin_id)["pane"]
  api("plugin.pane.open", plugin_id="layouts", entrypoint="picker", focus=True,
      cwd=origin.get("foreground_cwd") or origin["cwd"],
      env={"HERDR_LAYOUTS_ORIGIN_PANE_ID": origin_id})


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument("action", choices=("open", "pick"))
  args = parser.parse_args()
  api = Api()
  try:
    if args.action == "open":
      open_picker(api)
    else:
      layouts = load_layouts(config_dir=os.environ.get("HERDR_PLUGIN_CONFIG_DIR"))
      selection = select_layout(layouts)
      if selection:
        origin_id = os.environ.get("HERDR_LAYOUTS_ORIGIN_PANE_ID")
        if not origin_id:
          raise LayoutError("The popup is missing its original pane.")
        apply_layout(api, origin_id, *selection)
  except (LayoutError, OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
    message = str(error)
    print(f"Layouts: {message}", file=sys.stderr)
    try:
      api("notification.show", title="Layouts", body=message)
    except (LayoutError, OSError, ValueError):
      pass
    return 1
  return 0


if __name__ == "__main__":
  sys.exit(main())
