{
  description = "Axenide's terminal environment: Neovim (NvChad), tmux and Fish.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    nvchad-starter = {
      url = "path:./nvim/nvchad-starter";
      flake = false;
    };

    nix4nvchad = {
      url = "github:nix-community/nix4nvchad";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nvchad-starter.follows = "nvchad-starter";
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

    nvchadConfig = pkgs: {
      lazy-lock = builtins.readFile ./nvim/nvchad-starter/lazy-lock.json;
      extraPackages = with pkgs; [
        alejandra
        black
        gcc
        git
        gnumake
        go
        imagemagick
        isort
        nixd
        nodejs
        pkgs.python3Packages.debugpy
        pyright
        gopls
        kdePackages.qtdeclarative
        shfmt
        stylua
        tree-sitter
        vscode-langservers-extracted
        yarn
      ];
    };

  in {
    packages = forAllSystems (system: let
      pkgs = import nixpkgs {inherit system;};
    in {
      default = (nix4nvchad.packages.${system}.default.override (nvchadConfig pkgs)).overrideAttrs (old: {
        dontWrapQtApps = true;
      });
      nvchad = self.packages.${system}.default;
    });

    apps = forAllSystems (system: {
      default = {
        type = "app";
        program = "${self.packages.${system}.default}/bin/nvim";
      };
    });

    homeManagerModules.default = {
      pkgs,
      config,
      lib,
      ...
    }: let
      cfg = config.programs.axenide-term;
    in {
      options.programs.axenide-term = {
        enable = lib.mkEnableOption "Axenide's terminal environment";
      };

      config = lib.mkIf cfg.enable {
        imports = [nix4nvchad.homeManagerModules.default];

        programs.nvchad =
          (nvchadConfig pkgs)
          // {
            enable = true;
          };

        home.packages = [pkgs.fish pkgs.tmux pkgs.thefuck pkgs.starship pkgs.zoxide pkgs.neofetch pkgs.ffmpeg];

        programs.fish = {
          enable = true;
        };

        xdg.configFile = {
          "fish/config.fish".source = ./fish/config.fish;
          "fish/aliases.fish".source = ./fish/aliases.fish;
          "fish/env.fish".source = ./fish/env.fish;
          "fish/ffmpeg.fish".source = ./fish/ffmpeg.fish;
          "fish/fish_plugins".source = ./fish/fish_plugins;
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
          extraConfig = builtins.readFile ./tmux/tmux.conf + "\n" + builtins.readFile ./tmux/minimal.conf;
          plugins = with pkgs; [
            tmuxPlugins.sensible
            tmuxPlugins.yank
            tmuxPlugins.vim-tmux-navigator
          ];
        };
      };
    };
  };
}
