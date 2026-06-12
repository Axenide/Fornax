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

  mkFishWrapper = pkgs:
    pkgs.writeShellScriptBin "fish" ''
      export XDG_CONFIG_HOME="${cfg.fishXdgRoot pkgs}"
      export XDG_DATA_HOME="${cfg.fishXdgRoot pkgs}/data"
      exec ${pkgs.fish}/bin/fish --init-command="source ${cfg.fishXdgRoot pkgs}/fish/config.fish" "$@"
    '';

  mkRestoreSecretsWrapper = pkgs: {
    restore-secrets,
    fishWrapper,
  }:
    pkgs.writeShellScriptBin "restore-secrets" ''
      exec ${fishWrapper}/bin/fish -c "source ${restore-secrets}; restore-secrets"
    '';
}
