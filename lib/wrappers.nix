{pkgs, lib}: let
  cfg = import ./default.nix {inherit lib;};
  bundleTmuxPlugins = pkgs.symlinkJoin {
    name = "axenide-tmux-plugins-bundle";
    paths = cfg.tmuxPlugins pkgs;
  };
in {
  inherit bundleTmuxPlugins;

  mkTmuxWrapper = pkgs:
    pkgs.writeShellScriptBin "tmux" ''
      export TMUX_PLUGIN_DIR="${bundleTmuxPlugins}"
      exec ${pkgs.tmux}/bin/tmux -f ${cfg.mergedTmuxConf pkgs} "$@"
    '';

  mkFishWrapper = pkgs: let
    linkScript = (import ./default.nix {inherit lib;}).fishLinkToHome pkgs;
  in
    pkgs.writeShellScriptBin "fish" ''
      ${linkScript}
      exec ${pkgs.fish}/bin/fish "$@"
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

  mkOpencodeWrapper = pkgs:
    pkgs.writeShellApplication {
      name = "opencode";
      runtimeInputs = [pkgs.nodejs];
      text = ''
        exec npx -y opencode-ai@latest "$@"
      '';
    };
}
