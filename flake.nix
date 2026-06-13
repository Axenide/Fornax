{
  description = "Fornax: Axenide's alchemical furnace.";

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
  in {
    packages = forAllSystems (system: let
      pkgs = import nixpkgs {inherit system;};
      lib = pkgs.lib;
      termCfg = import ./lib {inherit lib;};
      wrappers = import ./lib/wrappers.nix {inherit pkgs lib;};

      nvchadPkg = (nix4nvchad.packages.${system}.default.override (termCfg.nvchadConfig pkgs)).overrideAttrs (_: {
        dontWrapQtApps = true;
      });

      tmuxPkg = wrappers.mkTmuxWrapper pkgs;
      fishPkg = wrappers.mkFishWrapper pkgs;
      nvimPkg = pkgs.symlinkJoin {
        name = "axenide-nvim";
        paths = [nvchadPkg];
      };
      restoreSecretsPkg = wrappers.mkRestoreSecretsWrapper pkgs {
        restore-secrets = termCfg.configPaths.fish.restoreSecrets;
        fishWrapper = fishPkg;
      };
      cleanSecretsPkg = wrappers.mkCleanSecretsWrapper pkgs {
        clean-secrets = termCfg.configPaths.fish.cleanSecrets;
        fishWrapper = fishPkg;
      };
      shredSecretsPkg = wrappers.mkShredSecretsWrapper pkgs {
        shred-secrets = termCfg.configPaths.fish.shredSecrets;
        fishWrapper = fishPkg;
      };

      fornaxPkg = pkgs.writeShellScriptBin "fornax" ''
        # Attach to an existing fornax session, or start a new one.
        # The bundle's PATH (set up by `nix run` / `nix develop`) is
        # inherited by the shell inside tmux, so fish, nvim, lazygit,
        # yazi, bw, etc. are all available without a profile install.
        if ${tmuxPkg}/bin/tmux has-session -t fornax 2>/dev/null; then
          exec ${tmuxPkg}/bin/tmux attach-session -t fornax
        else
          exec ${tmuxPkg}/bin/tmux new-session -A -s fornax -c "$PWD"
        fi
      '';

      passthrough = {
        starship = pkgs.starship;
        zoxide = pkgs.zoxide;
        fastfetch = pkgs.fastfetch;
        ffmpeg = pkgs.ffmpeg;
        lazygit = pkgs.lazygit;
        cava = pkgs.cava;
        bw = pkgs.bitwarden-cli;
        yazi = pkgs.yazi;
        git = pkgs.git;
      };

      defaultBundle = pkgs.symlinkJoin {
        name = "fornax";
        paths =
          [
            tmuxPkg
            fishPkg
            nvimPkg
            restoreSecretsPkg
            cleanSecretsPkg
            shredSecretsPkg
            fornaxPkg
          ]
          ++ builtins.attrValues passthrough
          ++ (termCfg.toolingPackages pkgs);
      };
    in
      {
        default = defaultBundle;
        fornax = fornaxPkg;
        tmux = tmuxPkg;
        fish = fishPkg;
        nvim = nvimPkg;
        nvchad = nvchadPkg;
        restore-secrets = restoreSecretsPkg;
        clean-secrets = cleanSecretsPkg;
        shred-secrets = shredSecretsPkg;
      }
      // builtins.mapAttrs (_: p: p) {
        inherit (passthrough) starship zoxide fastfetch ffmpeg lazygit cava bw yazi git;
      });

    apps = forAllSystems (system: let
      pkgs = import nixpkgs {inherit system;};
      lib = pkgs.lib;
      termCfg = import ./lib {inherit lib;};
      wrappers = import ./lib/wrappers.nix {inherit pkgs lib;};
      fishPkg = wrappers.mkFishWrapper pkgs;
    in {
      default = {
        type = "app";
        program = "${self.packages.${system}.fornax}/bin/fornax";
      };
      fornax = {
        type = "app";
        program = "${self.packages.${system}.fornax}/bin/fornax";
      };
      tmux = {
        type = "app";
        program = "${wrappers.mkTmuxWrapper pkgs}/bin/tmux";
      };
      fish = {
        type = "app";
        program = "${fishPkg}/bin/fish";
      };
      nvim = {
        type = "app";
        program = "${self.packages.${system}.nvim}/bin/nvim";
      };
      restore-secrets = {
        type = "app";
        program = "${self.packages.${system}.restore-secrets}/bin/restore-secrets";
      };
      clean-secrets = {
        type = "app";
        program = "${self.packages.${system}.clean-secrets}/bin/clean-secrets";
      };
      shred-secrets = {
        type = "app";
        program = "${self.packages.${system}.shred-secrets}/bin/shred-secrets";
      };
    });

    devShells = forAllSystems (system: let
      pkgs = import nixpkgs {inherit system;};
    in {
      default = pkgs.mkShell {
        packages = [self.packages.${system}.default];
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
    in {
      options.programs.fornax = {
        enable = lib.mkEnableOption "Fornax: Axenide's terminal environment";
      };

      config = lib.mkIf config.programs.fornax.enable {
        imports = [nix4nvchad.homeManagerModules.default];

        programs.nvchad =
          (termCfg.nvchadConfig pkgs)
          // {
            enable = true;
          };

        home.packages = termCfg.extraPackages pkgs;

        programs.fish.enable = true;

        xdg.configFile = {
          "fish/config.fish".source = termCfg.configPaths.fish.config;
          "fish/aliases.fish".source = termCfg.configPaths.fish.aliases;
          "fish/env.fish".source = termCfg.configPaths.fish.env;
          "fish/ffmpeg.fish".source = termCfg.configPaths.fish.ffmpeg;
          "fish/fish_plugins".source = termCfg.configPaths.fish.plugins;
          "fish/functions/restore-secrets.fish".source = termCfg.configPaths.fish.restoreSecrets;
          "fish/functions/clean-secrets.fish".source = termCfg.configPaths.fish.cleanSecrets;
          "fish/functions/shred-secrets.fish".source = termCfg.configPaths.fish.shredSecrets;
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
      };
    };
  };
}
