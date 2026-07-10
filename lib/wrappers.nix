{pkgs, lib}:
let
  cfg = import ./default.nix {inherit lib;};
in {
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
              echo "opencode: '$HOME/.config/opencode/opencode.json' not found. Run 'home-manager switch' first." >&2
              exit 1
            fi
            : "''${OPENCODE_CONFIG:=$HOME/.config/opencode/opencode.json}"
            : "''${OPENCODE_CONFIG_DIR:=$HOME/.config/opencode}"
            export OPENCODE_CONFIG OPENCODE_CONFIG_DIR
            ;;
        esac
        exec npx -y opencode-ai@latest "$@"
      '';
    };

  mkNpmWrapper = pkgs:
    pkgs.runCommand "npm" {
      meta.priority = 9999;
      meta.mainProgram = "npm";
    } ''
      mkdir -p $out/bin
      cat > $out/bin/npm << 'WRAPPER'
      #!/usr/bin/env bash
      export NPM_CONFIG_PREFIX="$HOME/.local/share/npm-global"
      export NPM_CONFIG_GLOBAL_PREFIX="$HOME/.local/share/npm-global"
      exec ${pkgs.nodejs}/bin/npm "$@"
      WRAPPER
      chmod +x $out/bin/npm
    '';
}
