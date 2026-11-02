{
  lib,
  inputs,
  ...
}:

let
  mattPocockSkills = {
    # Engineering
    "ask-matt" = false;
    "code-review" = true;
    "codebase-design" = false;
    "diagnosing-bugs" = false;
    "domain-modeling" = true;
    "grill-with-docs" = true;
    "implement" = true;
    "implement-spec" = true;
    "improve-codebase-architecture" = true;
    "pr" = true;
    "prototype" = true;
    "research" = true;
    "retro" = true;
    "setup-matt-pocock-skills" = true;
    "tdd" = true;
    "to-spec" = true;
    "to-tickets" = true;
    "triage" = true;
    "wayfinder" = true;
    "wizard" = false;

    # Productivity
    "grill-me" = true;
    "grilling" = true;
    "handoff" = true;
    "teach" = true;
    "to-questionnaire" = false;
    "wait-what" = true;
    "writing-for-agents" = true;
  };

in
{
  _class = "homeManager";

  imports = [ inputs.agent-skills.homeManagerModules.default ];

  programs.agent-skills = {
    enable = true;
    sources.matt-pocock-engineering = {
      input = "matt-pocock-skills";
      subdir = "skills/engineering";
    };
    sources.matt-pocock-productivity = {
      input = "matt-pocock-skills";
      subdir = "skills/productivity";
    };
    # sources.notion = {
    #   input = "notion-skills";
    #   subdir = "skills";
    # };
    sources.linear-cli = {
      input = "linear-cli-skills";
      subdir = "skills";
    };
    sources.cloudflare-security-audit = {
      input = "cloudflare-security-audit-skills";
      subdir = "skills";
    };
    skills = {
      # Set individual Matt Pocock skills to true as needed.
      enable = lib.attrNames (lib.filterAttrs (_: enabled: enabled) mattPocockSkills);
      enableAll = [
        # "notion"
        "cloudflare-security-audit"
      ];
      # Inject attribution and relationship rules right after the frontmatter so they take priority.
      explicit.linear-cli = {
        from = "linear-cli";
        path = "linear-cli";
        transform =
          { original, dependencies }:
          let
            sep = "\n---\n";
            parts = lib.splitString sep original;
            rule = ''

              > **Required:** Every issue description, comment, or other text you post to Linear must begin with this callout, filled in with your agent name and model version (e.g. `Claude Opus 5.5`, `GPT 6.1 Terra`):

              ```markdown
              > [!NOTE]
              > 🤖 **Posted by <Agent> on behalf of Clayton**
              ```

              > **Required:** Set parent, sub-issue, blocking, and related issues only through Linear's native fields (`--parent`, `linear issue relation add`), and keep descriptions about the work itself. Linear shows these relationships in the issue sidebar, so a description section listing them (e.g. "Prerequisites", "Blocked by", "Sub-issues") is noise.
            '';
          in
          lib.head parts + sep + rule + lib.concatStringsSep sep (lib.tail parts) + dependencies;
      };
    };
    targets = {
      agents.enable = true;
      claude.enable = true;
      codex.enable = true;
      opencode.enable = true;
    };
  };
}
