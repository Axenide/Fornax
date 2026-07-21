{
  description = "Fornax: Axenide's terminal environment, installed via home-manager.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    nix4nvchad = {
      url = "github:nix-community/nix4nvchad";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agent-skills.url = "github:Kyure-A/agent-skills-nix";

    adk-skill = {
      url = "github:dewitt/adk-skill";
      flake = false;
    };

    opentui = {
      url = "github:anomalyco/opentui";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    nix4nvchad,
    agent-skills,
    adk-skill,
    opentui,
    ...
  }: let
    systems = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    forAllSystems = nixpkgs.lib.genAttrs systems;

    nvchadFor = system: let
      pkgs = import nixpkgs {inherit system;};
      termCfg = import ./lib {lib = pkgs.lib;};
    in
      (nix4nvchad.packages.${system}.default.override (termCfg.nvchadConfig pkgs // {
        starterRepo = self + "/nvim/nvchad-starter";
      })).overrideAttrs (_: {
        dontWrapQtApps = true;
      });
  in {
    packages = forAllSystems (system: {
      nvchad = nvchadFor system;
      default = nvchadFor system;
    });

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
      ...
    }: let
      termCfg = import ./lib {inherit lib;};
      wrappers = import ./lib/wrappers.nix {inherit pkgs lib;};

      opencodeXdg = pkgs.runCommand "axenide-opencode-xdg" {} ''
        mkdir -p $out/opencode
        cp -rL ${./opencode/opencode.json} $out/opencode/opencode.json
        cp -rL ${./opencode/AGENTS.md} $out/opencode/AGENTS.md
        chmod -R u+w $out
      '';

      opencodePkg = wrappers.mkOpencodeWrapper pkgs opencodeXdg;

      nvchadPkg = self.packages.${pkgs.system}.nvchad;

      bunVersion = "1.3.14";
      bunSrcs = {
        x86_64-linux = pkgs.fetchurl {
          url = "https://github.com/oven-sh/bun/releases/download/bun-v${bunVersion}/bun-linux-x64.zip";
          sha256 = "951ee2aee855f08595aeec6225226a298d3fea83a3dcd6465c09cbccdf7e848f";
        };
        aarch64-linux = pkgs.fetchurl {
          url = "https://github.com/oven-sh/bun/releases/download/bun-v${bunVersion}/bun-linux-aarch64.zip";
          sha256 = "a27ffb63a8310375836e0d6f668ae17fa8d8d18b88c37c821c65331973a19a3b";
        };
      };
      bunSrc = bunSrcs.${pkgs.stdenv.hostPlatform.system} or (throw "fornax: bun: unsupported system ${pkgs.stdenv.hostPlatform.system}");
      bunPkg = pkgs.stdenvNoCC.mkDerivation {
        pname = "bun";
        version = bunVersion;
        src = bunSrc;
        nativeBuildInputs = [pkgs.unzip];
        installPhase = ''
          mkdir -p $out/bin
          bunPath=$(find . -type f -name bun | head -n1)
          install -m755 "$bunPath" $out/bin/bun
        '';
      };
    in {
      imports = [agent-skills.homeManagerModules.default];

      options.programs.fornax = {
        enable = lib.mkEnableOption "Fornax: Axenide's terminal environment";
      };

      config = lib.mkIf config.programs.fornax.enable {
        programs.agent-skills = {
          enable = true;
          sources = {
            local.path = ./skills;
            adk = {
              path = adk-skill;
              subdir = "skill";
            };
            opentui = {
              path = opentui;
              subdir = "packages/web/src/content";
            };
          };
          skills.enableAll = ["local"];
          skills.enable = ["adk" "opentui"];
          targets.opencode.enable = true;
        };

        home.packages = termCfg.extraPackages pkgs ++ [bunPkg nvchadPkg opencodePkg];

        programs.fish.enable = true;

        xdg.configFile = {
          "btop/btop.conf".source = termCfg.configPaths.btop;
          "fish/config.fish".source = lib.mkForce termCfg.configPaths.fish.config;
          "fish/aliases.fish".source = lib.mkForce termCfg.configPaths.fish.aliases;
          "fish/env.fish".source = lib.mkForce termCfg.configPaths.fish.env;
          "fish/ffmpeg.fish".source = lib.mkForce termCfg.configPaths.fish.ffmpeg;
          "fish/fish_plugins".source = lib.mkForce termCfg.configPaths.fish.plugins;
          "fish/functions/restore-secrets.fish".source = lib.mkForce termCfg.configPaths.fish.restoreSecrets;
          "fish/functions/clean-secrets.fish".source = lib.mkForce termCfg.configPaths.fish.cleanSecrets;
          "fish/functions/shred-secrets.fish".source = lib.mkForce termCfg.configPaths.fish.shredSecrets;
          "fish/conf.d/fish_frozen_theme.fish".source = lib.mkForce termCfg.configPaths.fish.fish_frozen_theme;
        };

        programs.tmux = {
          enable = true;
          shell = "${pkgs.fish}/bin/fish";
          terminal = "tmux-256color";
          mouse = true;
          baseIndex = 1;
          keyMode = "vi";
          extraConfig =
            builtins.readFile termCfg.configPaths.tmux
            + "\n"
            + builtins.readFile termCfg.configPaths.tmuxMinimal
            + "\nset-option -g renumber-windows on\n";
          plugins = termCfg.tmuxPlugins pkgs;
        };

        home.activation.refreshTmux = lib.hm.dag.entryAfter ["linkGeneration"] ''
          if ${pkgs.tmux}/bin/tmux info >/dev/null 2>&1; then
            ${pkgs.tmux}/bin/tmux set-option -g default-shell ${pkgs.fish}/bin/fish
            ${pkgs.tmux}/bin/tmux setenv -g SHELL ${pkgs.fish}/bin/fish
            ${pkgs.tmux}/bin/tmux source-file "$HOME/.config/tmux/tmux.conf" >/dev/null 2>&1 || true
          fi
        '';

        home.activation.syncOpencodeConfig = lib.hm.dag.entryAfter ["linkGeneration"] ''
          mkdir -p "$HOME/.config/opencode"
          chmod -R u+w "$HOME/.config/opencode" 2>/dev/null || true
          rm -rf "$HOME/.config/opencode/opencode.json" "$HOME/.config/opencode/AGENTS.md"
          cp -rL ${opencodeXdg}/opencode/. "$HOME/.config/opencode/"
          chmod -R u+w "$HOME/.config/opencode"
        '';

        home.activation.setupNpm = lib.hm.dag.entryAfter ["linkGeneration"] ''
          mkdir -p "$HOME/.cache/npm/global"
          rm -f "$HOME/.npmrc"
          cat > "$HOME/.npmrc" << EOF
prefix=$HOME/.cache/npm/global
global-prefix=$HOME/.cache/npm/global
EOF
        '';

        home.activation.installNvChad = lib.hm.dag.entryAfter ["linkGeneration"] ''
          if [ -d "$HOME/.config/nvim" ] && [ ! -L "$HOME/.config/nvim" ]; then
            mv "$HOME/.config/nvim" "$HOME/.config/nvim_$(date +%Y_%m_%d_%H_%M_%S).bak"
          fi
          mkdir -p "$HOME/.config/nvim"
          cp -rL ${nvchadPkg}/config/. "$HOME/.config/nvim/"
          find "$HOME/.config/nvim" -type d -exec chmod 755 {} \;
          find "$HOME/.config/nvim" -type f -exec chmod 664 {} \;
        '';
      };
    };
  };
}
