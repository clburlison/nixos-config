"""Opt-in integration tests against an isolated headless Herdr server."""

import os
from pathlib import Path
import pty
import select
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import layouts


@unittest.skipUnless(os.environ.get("HERDR_LAYOUTS_INTEGRATION") == "1",
                     "set HERDR_LAYOUTS_INTEGRATION=1 to run an isolated Herdr server")
class IntegrationTests(unittest.TestCase):
  def setUp(self):
    self.directory = tempfile.TemporaryDirectory(prefix="herdr-layouts-")
    self.addCleanup(self.directory.cleanup)
    root = Path(self.directory.name)
    self.bin = root / "bin"
    self.bin.mkdir()
    (self.bin / "python3").symlink_to(sys.executable)
    config = root / ".config/herdr"
    config.mkdir(parents=True)
    (config / "config.toml").write_text(
      'onboarding = false\n[terminal]\ndefault_shell = "/bin/sh"\nshell_mode = "login"\n')
    env = {key: value for key, value in os.environ.items() if not key.startswith("HERDR_")}
    env.update(HOME=str(root), XDG_CONFIG_HOME=str(root / ".config"),
               XDG_STATE_HOME=str(root / ".local/state"), XDG_RUNTIME_DIR=str(root),
               HERDR_SOCKET_PATH=str(root / "herdr.sock"), PATH=f"{self.bin}:{env['PATH']}")
    self.herdr = shutil.which("herdr")
    self.server = subprocess.Popen([self.herdr, "server"], env=env,
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    self.addCleanup(self.stop_server)
    self.environment = patch.dict(os.environ, env, clear=True)
    self.environment.start()
    self.addCleanup(self.environment.stop)
    self.api = layouts.Api()
    self.wait_for(lambda: Path(env["HERDR_SOCKET_PATH"]).exists())
    workspace = self.api("workspace.create", cwd=str(root), label="layout tests", focus=True)
    self.workspace_id = workspace["workspace"]["workspace_id"]
    self.origin = self.api("pane.list", workspace_id=self.workspace_id)["panes"][0]
    self.wait_for(self.origin_idle)
    self.presets = layouts.load_layouts()

  def stop_server(self):
    self.server.terminate()
    try:
      self.server.wait(timeout=5)
    except subprocess.TimeoutExpired:
      self.server.kill()
      self.server.wait()

  def wait_for(self, predicate):
    deadline = time.monotonic() + 8
    while time.monotonic() < deadline:
      if self.server.poll() is not None:
        self.fail(f"Herdr server exited: {self.server.returncode}")
      if predicate():
        return
      time.sleep(0.05)
    self.fail(f"Timed out waiting for Herdr: {self.api('plugin.log.list', plugin_id='layouts')}")

  def origin_idle(self):
    try:
      layouts.require_idle(self.api, [self.origin])
    except layouts.LayoutError:
      return False
    return True

  def panes(self):
    return self.api("pane.list", workspace_id=self.workspace_id)["panes"]

  def test_manifest_links_with_popup_placement(self):
    result = subprocess.run([self.herdr, "plugin", "link", str(layouts.ROOT)],
                            check=True, text=True, capture_output=True)
    self.assertIn('"placement":"popup"', result.stdout)

  def write_picker_result(self, key):
    fzf = self.bin / "fzf"
    fzf.write_text(f'#!{sys.executable}\nimport sys\nsys.stdin.read()\n'
                   f'print({key!r})\nprint("two-columns\\tTwo columns")\n')
    fzf.chmod(0o755)

  def invoke_picker_with_key(self, key):
    # Supply deterministic picker input, but run the real plugin action, popup
    # entrypoint, socket transport, layout application, and process inspection.
    self.write_picker_result(key)
    # Nix's Herdr wrapper prepends its bundled fzf to PATH. Only the test
    # manifest overrides that PATH so the popup uses our deterministic input.
    plugin = Path(self.directory.name) / "plugin"
    shutil.copytree(layouts.ROOT, plugin)
    manifest = plugin / "herdr-plugin.toml"
    manifest.write_text(manifest.read_text().replace(
      "exec python3 ", f'PATH="{self.bin}:$PATH" exec python3 '))
    subprocess.run([self.herdr, "plugin", "link", str(plugin)],
                   check=True, capture_output=True)
    self.api("plugin.action.invoke", action_id="layouts.open")

  def test_popup_enter_creates_new_tab(self):
    self.invoke_picker_with_key("enter")
    self.wait_for(lambda: len(self.panes()) == 3)
    self.assertIn(self.origin["pane_id"], {pane["pane_id"] for pane in self.panes()})
    tabs = self.api("tab.list", workspace_id=self.workspace_id)["tabs"]
    focused = [tab for tab in tabs if tab["focused"]]
    self.assertEqual(len(focused), 1)
    self.assertNotEqual(focused[0]["tab_id"], self.origin["tab_id"])
    self.assertEqual(focused[0]["pane_count"], 2)

  def test_popup_alt_enter_replaces_original_tab(self):
    self.invoke_picker_with_key("alt-enter")
    self.wait_for(lambda: len(self.panes()) == 2)
    self.assertNotIn(self.origin["pane_id"], {pane["pane_id"] for pane in self.panes()})

  def test_native_new_tab_and_idle_replacement(self):
    layouts.apply_layout(self.api, self.origin["pane_id"], self.presets["two-columns"], False)
    self.assertEqual(len(self.panes()), 3)
    self.assertIn(self.origin["pane_id"], {pane["pane_id"] for pane in self.panes()})
    layouts.apply_layout(self.api, self.origin["pane_id"], self.presets["two-columns"], True)
    self.assertEqual(len(self.panes()), 4)
    self.assertNotIn(self.origin["pane_id"], {pane["pane_id"] for pane in self.panes()})

  def test_blank_tab_label_preserves_existing_tab_name(self):
    self.api("tab.rename", tab_id=self.origin["tab_id"], label="keep this name")
    self.wait_for(self.origin_idle)
    layouts.apply_layout(self.api, self.origin["pane_id"], self.presets["two-columns"], True)
    tabs = self.api("tab.list", workspace_id=self.workspace_id)["tabs"]
    self.assertEqual(len(tabs), 1)
    self.assertEqual(tabs[0]["label"], "keep this name")

  def assert_job_blocks_replacement(self, command):
    subprocess.run([self.herdr, "pane", "run", self.origin["pane_id"], command],
                   check=True, capture_output=True)
    self.wait_for(lambda: not self.origin_idle())
    before = {pane["pane_id"] for pane in self.panes()}
    with self.assertRaisesRegex(layouts.LayoutError, "running"):
      layouts.apply_layout(self.api, self.origin["pane_id"], self.presets["two-columns"], True)
    self.assertEqual(before, {pane["pane_id"] for pane in self.panes()})

  def test_foreground_job_blocks_replacement(self):
    self.assert_job_blocks_replacement("sleep 60")

  def test_background_job_blocks_replacement(self):
    self.assert_job_blocks_replacement("sleep 60 &")

  def test_error_screen_waits_for_enter_without_changing_panes(self):
    subprocess.run([self.herdr, "pane", "run", self.origin["pane_id"], "sleep 60"],
                   check=True, capture_output=True)
    self.wait_for(lambda: not self.origin_idle())
    self.write_picker_result("alt-enter")
    before = {pane["pane_id"] for pane in self.panes()}
    master, slave = pty.openpty()
    self.addCleanup(os.close, master)
    try:
      picker = subprocess.Popen(
        [sys.executable, "-B", str(layouts.ROOT / "layouts.py"), "pick"],
        stdin=slave, stdout=slave, stderr=slave,
        env=dict(os.environ, HERDR_LAYOUTS_ORIGIN_PANE_ID=self.origin["pane_id"]),
      )
    finally:
      os.close(slave)

    def stop_picker():
      if picker.poll() is None:
        picker.kill()
      picker.wait()
    self.addCleanup(stop_picker)
    output = b""
    deadline = time.monotonic() + 8
    while b"Press Enter to close this popup..." not in output:
      self.assertIsNone(picker.poll(), output.decode(errors="replace"))
      if time.monotonic() >= deadline:
        self.fail(f"No error acknowledgement prompt: {output!r}")
      if select.select([master], [], [], 0.1)[0]:
        output += os.read(master, 8192)
    self.assertIn(b"sleep (PID ", output)
    self.assertIn(self.origin["pane_id"].encode(), output)
    self.assertIsNone(picker.poll())
    self.assertEqual(before, {pane["pane_id"] for pane in self.panes()})
    os.write(master, b"\n")
    self.assertEqual(picker.wait(timeout=5), 1)
    self.assertEqual(before, {pane["pane_id"] for pane in self.panes()})


if __name__ == "__main__":
  unittest.main()
