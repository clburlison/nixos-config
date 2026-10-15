import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import layouts


ORIGIN = {
  "pane_id": "w1:p1", "tab_id": "w1:t1", "workspace_id": "w1",
  "cwd": "/repo", "foreground_cwd": "/repo/worktree",
}
OTHER = dict(ORIGIN, pane_id="w1:p2", label="right")
IDLE = {
  "shell_pid": 100,
  "foreground_processes": [{"pid": 100, "name": "fish"}],
}


class FakeApi:
  def __init__(self):
    self.calls = []
    self.panes = [ORIGIN, OTHER, dict(ORIGIN, tab_id="w1:t2", pane_id="w1:p3")]
    self.infos = {ORIGIN["pane_id"]: IDLE, OTHER["pane_id"]: dict(
      IDLE, shell_pid=200, foreground_processes=[{"pid": 200, "name": "zsh"}])}

  def __call__(self, method, **params):
    self.calls.append((method, params))
    if method == "pane.get":
      return {"pane": ORIGIN}
    if method == "pane.list":
      return {"panes": self.panes}
    if method == "pane.process_info":
      return {"process_info": self.infos[params["pane_id"]]}
    if method == "layout.apply":
      root = copy.deepcopy(params["root"])
      for index, node in enumerate(layouts.pane_nodes(root)):
        node["pane_id"] = f"w1:new{index}"
      return {"layout": {"root": root, "tab_id": "w1:new-tab"}}
    return {}


class LayoutTests(unittest.TestCase):
  def setUp(self):
    self.api = FakeApi()
    self.presets = layouts.load_layouts()
    self.layout = self.presets["two-columns"]
    self.processes = {100: (1, "fish"), 200: (1, "zsh")}

  def apply(self, replace=True):
    with patch.object(layouts, "process_snapshot", return_value=self.processes):
      layouts.apply_layout(self.api, ORIGIN["pane_id"], self.layout, replace)

  def test_new_tab_leaves_busy_original_untouched_and_inherits_cwd(self):
    self.api.infos.clear()
    self.apply(replace=False)
    self.assertEqual([call[0] for call in self.api.calls],
                     ["pane.get", "layout.apply", "tab.focus"])
    self.assertEqual(self.api.calls[-1], ("tab.focus", {"tab_id": "w1:new-tab"}))
    params = self.api.calls[-2][1]
    self.assertEqual(params["workspace_id"], "w1")
    self.assertNotIn("tab_id", params)
    self.assertTrue(params["focus"])
    self.assertEqual([node["cwd"] for node in layouts.pane_nodes(params["root"])],
                     ["/repo/worktree", "/repo/worktree"])

  def test_replace_checks_all_panes_in_original_tab_only(self):
    self.apply()
    checked = [params["pane_id"] for method, params in self.api.calls
               if method == "pane.process_info"]
    self.assertEqual(checked, ["w1:p1", "w1:p2"])
    params = self.api.calls[-1][1]
    self.assertEqual(params["tab_id"], "w1:t1")
    self.assertNotIn("workspace_id", params)

  def test_login_and_nix_wrapped_shells_are_considered_idle(self):
    for name in ("-fish", "-zsh", ".fish-wrapped", "-.bash-wrapped"):
      with self.subTest(name=name):
        self.processes[100] = (1, name)
        self.apply()

  def assert_cancelled(self, message):
    with self.assertRaisesRegex(layouts.LayoutError, message):
      self.apply()
    self.assertNotIn("layout.apply", [method for method, _ in self.api.calls])

  def test_busy_unfocused_pane_cancels_without_mutation(self):
    self.api.infos["w1:p2"] = dict(
      IDLE, shell_pid=200, foreground_processes=[{"pid": 201, "name": "rails"}])
    self.assert_cancelled("running foreground command")

  def test_background_job_cancels_without_mutation(self):
    self.processes[201] = (200, "sleep")
    self.assert_cancelled("running processes: sleep")

  def test_zombie_children_do_not_block_idle_shell(self):
    snapshot = "100 1 Ss+ -fish\n101 100 Z+ <defunct>\n"
    with patch.object(layouts.subprocess, "run", return_value=
                      subprocess.CompletedProcess([], 0, snapshot)):
      layouts.require_idle(self.api, [ORIGIN])

  def test_stopped_children_still_block_replacement(self):
    snapshot = "100 1 Ss+ -fish\n101 100 T sleep\n"
    with patch.object(layouts.subprocess, "run", return_value=
                      subprocess.CompletedProcess([], 0, snapshot)):
      with self.assertRaisesRegex(layouts.LayoutError, "sleep.*101"):
        layouts.require_idle(self.api, [ORIGIN])

  def test_foreground_error_identifies_pane_process_and_pid(self):
    self.api.infos["w1:p2"] = dict(
      IDLE, shell_pid=200, foreground_processes=[{"pid": 201, "name": "rails"}])
    with patch.object(layouts, "process_snapshot", return_value=self.processes):
      with self.assertRaisesRegex(layouts.LayoutError, r"right \(w1:p2\).*rails.*201"):
        layouts.require_idle(self.api, [OTHER])

  def test_command_execed_over_shell_is_not_considered_idle(self):
    self.processes[100] = (1, "nvim")
    self.assert_cancelled("not an idle shell")

  def test_missing_process_information_cancels(self):
    for info in ({}, dict(IDLE, foreground_processes=[])):
      with self.subTest(info=info):
        self.api.infos["w1:p1"] = info
        self.assert_cancelled("cannot be checked|no foreground process information")

  def test_missing_origin_cancels(self):
    self.api.panes = [OTHER]
    self.assert_cancelled("original tab changed")

  def test_process_inspection_failure_prevents_replacement(self):
    with patch.object(layouts, "process_snapshot", side_effect=OSError("ps failed")):
      with self.assertRaises(OSError):
        layouts.apply_layout(self.api, ORIGIN["pane_id"], self.layout, True)
    self.assertNotIn("layout.apply", [method for method, _ in self.api.calls])

  def test_ruby_starts_commands_in_corresponding_created_shells(self):
    self.layout = self.presets["ruby-dev"]
    with patch.object(layouts.subprocess, "run") as run:
      self.apply(replace=False)
    commands = [call.args[0][-2:] for call in run.call_args_list]
    self.assertEqual(commands, [["w1:new0", "npm run start"],
                                ["w1:new1", "bin/rails s"],
                                ["w1:new2", "bundle exec sidekiq -c 6"]])
    self.assertTrue(all("run" not in node
                        for node in layouts.pane_nodes(self.api.calls[-2][1]["root"])))
    self.assertIn("run", self.presets["ruby-dev"]["root"]["first"])

  def test_relative_pane_cwd_resolves_from_active_directory(self):
    self.layout["root"]["first"]["cwd"] = "server"
    self.apply(replace=False)
    self.assertEqual(self.api.calls[-2][1]["root"]["first"]["cwd"],
                     "/repo/worktree/server")

  def test_popup_captures_original_pane_without_creating_a_tiled_pane(self):
    with patch.dict(layouts.os.environ, {"HERDR_PANE_ID": "w1:p1"}):
      layouts.open_picker(self.api)
    method, params = self.api.calls[-1]
    self.assertEqual(method, "plugin.pane.open")
    self.assertEqual(params["entrypoint"], "picker")
    self.assertEqual(params["env"], {"HERDR_LAYOUTS_ORIGIN_PANE_ID": "w1:p1"})
    self.assertEqual(params["cwd"], "/repo/worktree")

  def test_picker_enter_alt_enter_and_escape(self):
    for key, replace in (("enter", False), ("alt-enter", True)):
      with self.subTest(key=key), patch.object(layouts.subprocess, "run") as run:
        run.return_value = subprocess.CompletedProcess([], 0, f"{key}\ntwo-columns\tTwo columns\n")
        self.assertEqual(layouts.select_layout(self.presets), (self.layout, replace))
        self.assertIn("--expect=enter,alt-enter", run.call_args.args[0])
        self.assertEqual(run.call_args.kwargs["env"]["FZF_DEFAULT_OPTS"], "")
    with patch.object(layouts.subprocess, "run") as run:
      run.return_value = subprocess.CompletedProcess([], 130, "")
      self.assertIsNone(layouts.select_layout(self.presets))

  def test_escape_exits_without_any_api_requests(self):
    with patch.object(layouts, "Api", return_value=self.api), \
         patch.object(layouts, "select_layout", return_value=None), \
         patch.object(sys, "argv", ["layouts.py", "pick"]):
      self.assertEqual(layouts.main(), 0)
    self.assertEqual(self.api.calls, [])

  def test_busy_replacement_reports_notification_without_confirmation(self):
    self.api.infos["w1:p2"] = dict(
      IDLE, shell_pid=200, foreground_processes=[{"pid": 201, "name": "rails"}])
    with patch.object(layouts, "Api", return_value=self.api), \
         patch.object(layouts, "select_layout", return_value=(self.layout, True)), \
         patch.object(layouts, "process_snapshot", return_value=self.processes), \
         patch.dict(layouts.os.environ, {"HERDR_LAYOUTS_ORIGIN_PANE_ID": "w1:p1"}), \
         patch.object(sys, "argv", ["layouts.py", "pick"]), \
         patch.object(sys, "stderr"):
      self.assertEqual(layouts.main(), 1)
    self.assertNotIn("layout.apply", [method for method, _ in self.api.calls])
    method, params = self.api.calls[-1]
    self.assertEqual(method, "notification.show")
    self.assertIn("running foreground command", params["body"])

  def test_user_layout_overrides_bundled_file(self):
    with tempfile.TemporaryDirectory() as directory:
      config = Path(directory)
      (config / "layouts").mkdir()
      self.layout["name"] = "Custom shells"
      (config / "layouts/two-columns.json").write_text(json.dumps(self.layout))
      loaded = layouts.load_layouts(config_dir=config)
      self.assertEqual(loaded["two-columns"]["name"], "Custom shells")
      self.assertIn("ruby-dev", loaded)

  def test_missing_or_blank_picker_name_is_rejected(self):
    for name in (None, "", "   "):
      with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
        config = Path(directory)
        (config / "layouts").mkdir()
        preset = copy.deepcopy(self.layout)
        if name is None:
          preset.pop("name")
        else:
          preset["name"] = name
        (config / "layouts/two-columns.json").write_text(json.dumps(preset))
        with self.assertRaisesRegex(layouts.LayoutError, "name must be a nonempty"):
          layouts.load_layouts(config_dir=config)

  def test_optional_tab_label_controls_custom_naming(self):
    for replace in (False, True):
      for label in (None, "", "   ", "custom"):
        with self.subTest(label=label, replace=replace):
          if label is None:
            self.layout.pop("tab_label", None)
          else:
            self.layout["tab_label"] = label
          api = FakeApi()
          with patch.object(layouts, "process_snapshot", return_value=self.processes):
            layouts.apply_layout(api, ORIGIN["pane_id"], self.layout, replace)
          params = next(params for method, params in api.calls if method == "layout.apply")
          if label == "custom":
            self.assertEqual(params["tab_label"], "custom")
          else:
            self.assertNotIn("tab_label", params)

  def test_invalid_layout_is_rejected_before_opening_picker(self):
    for node in ({"type": "pane", "run": "one\ntwo"},
                 {"type": "pane", "command": ["sleep", "10"]},
                 {"type": "split", "direction": "right", "ratio": 0},
                 {"type": "pane", "env": {"BAD=KEY": "value"}}):
      with self.subTest(node=node), self.assertRaises(layouts.LayoutError):
        layouts.validate_node(node)

  def test_pane_labels_can_be_omitted_or_blank(self):
    for label in (None, "", "   ", "custom"):
      with self.subTest(label=label):
        node = {"type": "pane"}
        if label is not None:
          node["label"] = label
        layouts.validate_node(node)
        preset = {"name": "Test layout", "root": node}
        api = FakeApi()
        layouts.apply_layout(api, ORIGIN["pane_id"], preset, False)
        root = next(params["root"] for method, params in api.calls if method == "layout.apply")
        if label == "custom":
          self.assertEqual(root["label"], "custom")
        else:
          self.assertNotIn("label", root)


if __name__ == "__main__":
  unittest.main()
