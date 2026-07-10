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

      nvchadPkg = (nix4nvchad.packages.${pkgs.system}.default.override (termCfg.nvchadConfig pkgs // {
        starterRepo = self + "/nvim/nvchad-starter";
      })).overrideAttrs (_: {
        dontWrapQtApps = true;
      });

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
      options.programs.fornax = {
        enable = lib.mkEnableOption "Fornax: Axenide's terminal environment";
      };

      config = lib.mkIf config.programs.fornax.enable {
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
          rm -rf "$HOME/.config/opencode/opencode.json" "$HOME/.config/opencode/AGENTS.md" "$HOME/.config/opencode/skills"
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

        home.activation.setupFishEnv = lib.hm.dag.entryAfter ["linkGeneration"] ''
          ${pkgs.fish}/bin/fish -c 'set -Ux NPM_CONFIG_PREFIX $HOME/.cache/npm/global'
          ${pkgs.fish}/bin/fish -c 'set -Ux BUN_INSTALL $HOME/.cache/bun'
          ${pkgs.fish}/bin/fish -c 'set -Ux fish_user_paths $HOME/.cache/npm/global/bin $HOME/.cache/bun/bin $HOME/.nix-profile/bin'
          if ${pkgs.tmux}/bin/tmux info >/dev/null 2>&1; then
            ${pkgs.tmux}/bin/tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index}' 2>/dev/null \
              | while IFS= read -r pane; do
                ${pkgs.tmux}/bin/tmux send-keys -t "$pane" 'source ~/.config/fish/env.fish; hash -r' 2>/dev/null || true
              done
          fi
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
