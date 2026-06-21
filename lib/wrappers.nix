{pkgs, lib}: let
  cfg = import ./default.nix {inherit lib;};
  bundleTmuxPlugins = pkgs.symlinkJoin {
    name = "axenide-tmux-plugins-bundle";
    paths = cfg.tmuxPlugins pkgs;
  };
  mkFishWrapper = pkgs:
    pkgs.writeShellScriptBin "fish" ''
      ${cfg.fishLinkToHome pkgs}
      exec ${pkgs.fish}/bin/fish "$@"
    '';
in {
  inherit bundleTmuxPlugins mkFishWrapper;

  mkTmuxWrapper = pkgs:
    pkgs.writeShellScriptBin "tmux" ''
      export TMUX_PLUGIN_DIR="${bundleTmuxPlugins}"
      export SHELL="${mkFishWrapper pkgs}/bin/fish"
      exec ${pkgs.tmux}/bin/tmux -f ${cfg.mergedTmuxConf pkgs} "$@"
    '';

  mkRestoreSecretsWrapper = pkgs: {
    restore-secrets,
    fishWrapper,
  }:
    pkgs.writeShellScriptBin "restore-secrets" ''
      ${(import ./default.nix {inherit lib;}).fishLinkToHome pkgs}
      exec ${fishWrapper}/bin/fish -c "source ${restore-secrets}; restore-secrets"
    '';

  mkCleanSecretsWrapper = pkgs: {
    clean-secrets,
    fishWrapper,
  }:
    pkgs.writeShellScriptBin "clean-secrets" ''
      exec ${fishWrapper}/bin/fish -c "source ${clean-secrets}; clean-secrets"
    '';

  mkShredSecretsWrapper = pkgs: {
    shred-secrets,
    fishWrapper,
  }:
    pkgs.writeShellScriptBin "shred-secrets" ''
      exec ${fishWrapper}/bin/fish -c "source ${shred-secrets}; shred-secrets"
    '';

  mkOpencodeWrapper = pkgs: opencodeXdg:
    pkgs.writeShellApplication {
      name = "opencode";
      runtimeInputs = [pkgs.nodejs pkgs.mcp-nixos];
      text = ''
        case "$0" in
          /nix/store/*)
            : "''${OPENCODE_CONFIG:=${opencodeXdg}/opencode/opencode.json}"
            : "''${OPENCODE_CONFIG_DIR:=${opencodeXdg}/opencode}"
            export OPENCODE_CONFIG OPENCODE_CONFIG_DIR
            ;;
          *)
            if [ ! -e "$HOME/.config/opencode/opencode.json" ]; then
              mkdir -p "$HOME/.config/opencode"
              cp -rL ${opencodeXdg}/opencode/opencode.json "$HOME/.config/opencode/opencode.json"
              cp -rL ${opencodeXdg}/opencode/AGENTS.md "$HOME/.config/opencode/AGENTS.md"
              chmod u+w "$HOME/.config/opencode/opencode.json" "$HOME/.config/opencode/AGENTS.md"
            fi
            if [ -d "${opencodeXdg}/opencode/skills" ]; then
              for skill_dir in "${opencodeXdg}/opencode/skills/"*/; do
                [ -d "$skill_dir" ] || continue
                skill_name=$(basename "$skill_dir")
                if [ ! -e "$HOME/.config/opencode/skills/$skill_name/SKILL.md" ]; then
                  mkdir -p "$HOME/.config/opencode/skills/$skill_name"
                  cp -rL "$skill_dir/." "$HOME/.config/opencode/skills/$skill_name/"
                  chmod -R u+w "$HOME/.config/opencode/skills/$skill_name"
                fi
              done
            fi
            ;;
        esac
        exec npx -y opencode-ai@latest "$@"
      '';
    };

  mkBtopWrapper = pkgs:
    pkgs.writeShellScriptBin "btop" ''
      exec ${pkgs.btop}/bin/btop --config ${cfg.configPaths.btop} "$@"
    '';
}
