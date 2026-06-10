{
  pkgs,
    lib,
    config,
    nix4nvchad,
    ...
}@args: let
  cfg = config.programs.axenide-term;
  termConfig = import ../lib {inherit lib;};
in {
  options.programs.axenide-term = {
    enable = lib.mkEnableOption "Axenide's terminal environment";
  };

  config = lib.mkIf cfg.enable {
    imports = [nix4nvchad.homeManagerModules.default];

    programs.nvchad =
      (termConfig.nvchadConfig pkgs)
      // {
        enable = true;
      };

    home.packages = termConfig.extraPackages pkgs;

    programs.fish.enable = true;

    xdg.configFile = {
      "fish/config.fish".source = termConfig.configPaths.fish.config;
      "fish/aliases.fish".source = termConfig.configPaths.fish.aliases;
      "fish/env.fish".source = termConfig.configPaths.fish.env;
      "fish/ffmpeg.fish".source = termConfig.configPaths.fish.ffmpeg;
      "fish/fish_plugins".source = termConfig.configPaths.fish.plugins;
    };

    programs.tmux = {
      enable = true;
      shell = "${pkgs.fish}/bin/fish";
      terminal = "tmux-256color";
      mouse = true;
      baseIndex = 1;
      paneBaseIndex = 1;
      renumberWindows = true;
      keyMode = "vi";
      extraConfig = builtins.readFile termConfig.configPaths.tmux + "\n" + builtins.readFile termConfig.configPaths.tmuxMinimal;
      plugins = termConfig.tmuxPlugins pkgs;
    };
  };
}
