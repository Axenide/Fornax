{
  description = "Fornax: Axenide's terminal environment, installed via home-manager.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    nix4nvchad = {
      url = "github:nix-community/nix4nvchad";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nix4nvchad,
    ...
  }: let
    systems = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    devShells = forAllSystems (system: let
      pkgs = import nixpkgs {inherit system;};
      lib = pkgs.lib;
      termCfg = import ./lib {inherit lib;};
    in {
      default = pkgs.mkShell {
        packages = termCfg.toolingPackages pkgs;
      };
    });

    homeManagerModules.default = {
      pkgs,
      lib,
      config,
      nix4nvchad,
      ...
    }: let
      termCfg = import ./lib {inherit lib;};
      wrappers = import ./lib/wrappers.nix {inherit pkgs lib;};

      opentuiSkillSrc = pkgs.fetchFromGitHub {
        owner = "anomalyco";
        repo = "opentui";
        rev = "71b129abdc0854ba5153486b5f29356488223006";
        hash = "sha256-OLA7eNjQZPVsRufIZPrMYIQedcA16IEkHzChm+gXBIA=";
      };

      opencodeXdg = pkgs.runCommand "axenide-opencode-xdg" {} ''
        mkdir -p $out/opencode
        cp -rL ${./opencode/opencode.json} $out/opencode/opencode.json
        cp -rL ${./opencode/AGENTS.md} $out/opencode/AGENTS.md
        mkdir -p $out/opencode/skills
        cp -rL ${./skills}/. $out/opencode/skills/
        cp -rL ${opentuiSkillSrc}/packages/web/src/content $out/opencode/skills/opentui
        chmod -R u+w $out
      '';

      opencodePkg = wrappers.mkOpencodeWrapper pkgs opencodeXdg;
    in {
      imports = lib.mkIf config.programs.fornax.enable [
        (import "${nix4nvchad}/nix/module.nix" {
          starterRepo = self + "/nvim/nvchad-starter";
        })
      ];

      options.programs.fornax = {
        enable = lib.mkEnableOption "Fornax: Axenide's terminal environment";
      };

      config = lib.mkIf config.programs.fornax.enable {
        programs.nvchad =
          (termCfg.nvchadConfig pkgs)
          // {
            enable = true;
          };

        home.packages = termCfg.extraPackages pkgs ++ [opencodePkg];

        programs.fish.enable = true;

        xdg.configFile = {
          "btop/btop.conf".source = termCfg.configPaths.btop;
          "fish/config.fish".source = termCfg.configPaths.fish.config;
          "fish/aliases.fish".source = termCfg.configPaths.fish.aliases;
          "fish/env.fish".source = termCfg.configPaths.fish.env;
          "fish/ffmpeg.fish".source = termCfg.configPaths.fish.ffmpeg;
          "fish/fish_plugins".source = termCfg.configPaths.fish.plugins;
          "fish/functions/restore-secrets.fish".source = termCfg.configPaths.fish.restoreSecrets;
          "fish/functions/clean-secrets.fish".source = termCfg.configPaths.fish.cleanSecrets;
          "fish/functions/shred-secrets.fish".source = termCfg.configPaths.fish.shredSecrets;
          "fish/conf.d/fish_frozen_theme.fish".source = termCfg.configPaths.fish.fish_frozen_theme;
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
          extraConfig =
            builtins.readFile termCfg.configPaths.tmux
            + "\n"
            + builtins.readFile termCfg.configPaths.tmuxMinimal;
          plugins = termCfg.tmuxPlugins pkgs;
        };

        home.activation.refreshTmux = config.lib.hm.dag.entryAfter ["linkGeneration"] ''
          if ${pkgs.tmux}/bin/tmux info >/dev/null 2>&1; then
            ${pkgs.tmux}/bin/tmux set-option -g default-shell ${pkgs.fish}/bin/fish
            ${pkgs.tmux}/bin/tmux setenv -g SHELL ${pkgs.fish}/bin/fish
            ${pkgs.tmux}/bin/tmux source-file "$HOME/.config/tmux/tmux.conf" >/dev/null 2>&1 || true
          fi
        '';

        home.activation.syncOpencodeConfig = config.lib.hm.dag.entryAfter ["linkGeneration"] ''
          mkdir -p "$HOME/.config/opencode"
          rm -rf "$HOME/.config/opencode/opencode.json" "$HOME/.config/opencode/AGENTS.md" "$HOME/.config/opencode/skills"
          cp -rL ${opencodeXdg}/opencode/. "$HOME/.config/opencode/"
          chmod -R u+w "$HOME/.config/opencode"
        '';
      };
    };
  };
}
