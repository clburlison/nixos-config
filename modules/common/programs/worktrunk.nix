{
  _class = "homeManager";

  # Ensure the worktrunk worktree root exists.
  home.file."dev/worktrees/.keep".text = "";

  xdg.configFile."worktrunk/config.toml" = {
    force = true;
    text = ''
      worktree-path = "~/dev/worktrees/{{ repo }}/{{ branch | sanitize }}"

      [commit.generation]
      command = "MAX_THINKING_TOKENS=0 claude -p --no-session-persistence --model=haiku --tools=''' --safe-mode --setting-sources='user' --system-prompt='''"
    '';
  };
}
