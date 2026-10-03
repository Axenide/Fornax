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

    cliamp = {
      url = "github:bjarneo/cliamp";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    blender-mcp = {
      url = "git+https://projects.blender.org/lab/blender_mcp";
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
    cliamp,
    blender-mcp,
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

    cliampFor = system: let
      pkgs = import nixpkgs {inherit system;};
    in
      (cliamp.packages.${system}.default.override {
        alsa-lib = pkgs.alsa-lib-with-plugins.override {
          plugins = [
            pkgs.alsa-plugins
            pkgs.pipewire
          ];
        };
      });

    blenderMcpFor = system: let
      pkgs = import nixpkgs {inherit system;};
    in
      pkgs.python3Packages.buildPythonApplication {
        pname = "blender-mcp";
        version = "1.0.2";
        pyproject = true;
        src = blender-mcp + "/mcp";
        build-system = [pkgs.python3Packages.setuptools];
        dependencies = with pkgs.python3Packages; [
          mcp
          docutils
          pyyaml
        ];
      };
  in {
    packages = forAllSystems (system: {
      nvchad = nvchadFor system;
      cliamp = cliampFor system;
      blender-mcp = blenderMcpFor system;
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

      opencodeXdg = pkgs.runCommand "axenide-opencode-xdg" {} ''
        mkdir -p $out/opencode
        cp -rL ${./opencode/opencode.json} $out/opencode/opencode.json
        cp -rL ${./opencode/AGENTS.md} $out/opencode/AGENTS.md
        chmod -R u+w $out
      '';

      opencodePkg = pkgs.opencode;

      nvchadPkg = self.packages.${pkgs.stdenv.hostPlatform.system}.nvchad;

      cliampPkg = self.packages.${pkgs.stdenv.hostPlatform.system}.cliamp;

      blenderMcpPkg = self.packages.${pkgs.stdenv.hostPlatform.system}.blender-mcp;

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

        home.packages = termCfg.extraPackages pkgs ++ [bunPkg nvchadPkg opencodePkg cliampPkg blenderMcpPkg];

        home.sessionVariables = {
          TERMINAL = "kitty";
          EDITOR = "nvim";
          NPM_CONFIG_PREFIX = "$HOME/.cache/npm/global";
          BUN_INSTALL = "$HOME/.cache/bun";
        };

        home.sessionPath = [
          "$HOME/.nix-profile/bin"
          "$HOME/.cache/npm/global/bin"
          "$HOME/.cache/bun/bin"
        ];

        programs.fish = {
          enable = true;

          shellInit = ''
            xdg-user-dirs-update
            set -l _secrets_file ~/.local/share/secrets/fish.fish
            if test -e $_secrets_file
              source $_secrets_file
            end
          '';

          interactiveShellInit = ''
            set -U fish_greeting
            zoxide init fish | source

            set --global fish_color_autosuggestion 555 brblack
            set --global fish_color_cancel -r
            set --global fish_color_command blue
            set --global fish_color_comment red
            set --global fish_color_cwd green
            set --global fish_color_cwd_root red
            set --global fish_color_end green
            set --global fish_color_error brred
            set --global fish_color_escape brcyan
            set --global fish_color_history_current --bold
            set --global fish_color_host normal
            set --global fish_color_host_remote yellow
            set --global fish_color_normal normal
            set --global fish_color_operator brcyan
            set --global fish_color_param cyan
            set --global fish_color_quote yellow
            set --global fish_color_redirection cyan --bold
            set --global fish_color_search_match white --background=brblack
            set --global fish_color_selection white --bold --background=brblack
            set --global fish_color_status red
            set --global fish_color_user brgreen
            set --global fish_color_valid_path --underline
            set --global fish_pager_color_completion normal
            set --global fish_pager_color_completion_description B3A06D yellow -i
            set --global fish_pager_color_prefix normal --bold --underline
            set --global fish_pager_color_progress brwhite --background=cyan
            set --global fish_pager_color_selected_background -r
          '';

          shellAliases = {
            anifetch = "kitty +kitten icat -n --place 100x8@0x0 --align left ${./assets/adrien.gif} | fastfetch -c minimal --logo-width 25 --raw -";
            cavax = "TERM=st-256color cava";
          };

          functions = {
            vcompat = "ffmpeg -i $argv[1] -vf \"scale=trunc(iw/2)*2:trunc(ih/2)*2\" -c:v libx264 -profile:v high -level:v 4.2 -pix_fmt yuv420p -movflags +faststart -c:a aac -strict -2 (dirname $argv[1])/(basename -s .mp4 $argv[1])_compat.mp4";

            vcompatlb = ''
              if test (count $argv) -lt 1
                echo "Usage: vcompat archivo.mp4 [tasa_de_bits]"
                return 1
              end

              set input_file $argv[1]
              set output_file (dirname $input_file)/(basename -s .mp4 $input_file)_converted.mp4

              if test (count $argv) -ge 2
                set bitrate $argv[2]"M"
              else
                set bitrate 1"M"
              end

              ffmpeg -i $input_file -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" -c:v libx264 -profile:v high -level:v 4.2 -pix_fmt yuv420p -movflags +faststart -b:v $bitrate -c:a aac -strict -2 $output_file
            '';

            drconv = ''
              if test (count $argv) -lt 1
                echo "Usage: drconv archivo1 archivo2 ..."
                return 1
              end

              for file in $argv
                if test -f $file
                  set output_file (dirname $file)/(basename -s .mp4 $file)_dr.mov
                  ffmpeg -i $file -vcodec mjpeg -q:v 2 -acodec pcm_s16be -q:a 0 -f mov $output_file
                  echo "Processed: $file -> $output_file"
                else
                  echo "Skipping: $file (not a regular file)"
                end
              end
            '';

            restore-secrets = ''
              set -l secrets_dir ~/.local/share/secrets
              set -l secrets_file $secrets_dir/fish.fish

              mkdir -p $secrets_dir

              if not bw login --check >/dev/null 2>&1
                echo "Logging in to Bitwarden..."
                bw login
              end

              echo "Unlocking vault..."
              set -gx BW_SESSION (bw unlock --raw)

              echo "Syncing vault..."
              bw sync

              echo "Downloading secrets..."
              bw get notes fish-secrets > $secrets_file

              chmod 600 $secrets_file

              echo "Secrets restored to $secrets_file"
            '';

            clean-secrets = ''
              set -l secrets_dir ~/.local/share/secrets
              set -l secrets_file $secrets_dir/fish.fish

              if not test -e $secrets_file
                echo "No secrets file at $secrets_file"
                return 0
              end

              rm -f $secrets_file
              rmdir $secrets_dir 2>/dev/null

              echo "Removed $secrets_file"
            '';

            shred-secrets = ''
              set -l secrets_dir ~/.local/share/secrets
              set -l secrets_file $secrets_dir/fish.fish

              if not test -e $secrets_file
                echo "No secrets file at $secrets_file"
                return 0
              end

            shred -u -v -z -n 3 $secrets_file
            rmdir $secrets_dir 2>/dev/null

            echo "Securely shredded $secrets_file"
          '';

          cliamp-setup-lastfm = ''
            set -l api_url "http://ws.audioscrobbler.com/2.0/"

            if not type -q jq
              echo "jq is required"
              return 1
            end

            if not test -e ~/.config/cliamp/config.toml
              echo "Missing ~/.config/cliamp/config.toml"
              return 1
            end

            if cliamp plugins list 2>/dev/null | string match -q --regex "cliamp-lastfm"
              echo "cliamp-lastfm already installed"
            else
              echo "Installing cliamp-lastfm..."
              cliamp plugins install --yes Axenide/cliamp-lastfm; or return 1
            end

            echo "Opening Last.fm API registration..."
            xdg-open "https://www.last.fm/api/account/create" >/dev/null 2>&1; or true
            echo "Register an app (any name, ignore the callback URL) and paste the credentials."
            read -P "API Key: " api_key
            read -P "API Secret: " api_secret
            if test -z "$api_key"; or test -z "$api_secret"
              echo "API credentials cannot be empty"
              return 1
            end

            echo "Requesting auth token..."
            set -l response (curl -s "$api_url?method=auth.getToken&api_key=$api_key&format=json")
            set -l auth_token (echo "$response" | jq -r ".token // empty")
            if test -z "$auth_token"
              echo "Failed to get auth token: $response"
              return 1
            end

            set -l auth_url "https://www.last.fm/api/auth/?api_key=$api_key&token=$auth_token"
            echo "Opening Last.fm authorization page..."
            xdg-open "$auth_url" >/dev/null 2>&1; or echo "Open this URL: $auth_url"
            read -P "Press Enter after clicking ALLOW..."

            set -l sig_str (printf "%s\n" "api_key$api_key" "methodauth.getSession" "token$auth_token" | sort | string join "")
            set -l api_sig (echo -n "$sig_str$api_secret" | md5sum | string split -f1 " ")

            echo "Exchanging token for session key..."
            set -l response (curl -s "$api_url?method=auth.getSession&api_key=$api_key&token=$auth_token&api_sig=$api_sig&format=json")
            set -l session_key (echo "$response" | jq -r ".session.key // empty")
            set -l username (echo "$response" | jq -r ".session.name // empty")
            if test -z "$session_key"
              echo "Failed to get session key: $(echo "$response" | jq -r ".message // \\"Unknown error\\"")"
              return 1
            end

            echo ""
            echo "Setup complete. Add these to your fish-secrets Bitwarden note:"
            echo ""
            echo "set -gx LASTFM_API_KEY $api_key"
            echo "set -gx LASTFM_API_SECRET $api_secret"
            echo "set -gx LASTFM_SESSION_KEY $session_key"
            echo "set -gx LASTFM_USERNAME $username"
            echo ""
            echo "Then run restore-secrets and restart cliamp to start scrobbling."
          '';
          };
        };

        programs.starship = {
          enable = true;
          enableFishIntegration = true;

          settings = {
            add_newline = false;
            command_timeout = 1000;

            format = lib.concatStrings [
              "$directory"
              "$git_branch"
              "$git_state"
              "$git_status"
              "$cmd_duration"
              "$line_break"
              "$character"
            ];

            character = {
              success_symbol = "[»](bold red)";
              error_symbol = "[✖](bold red)";
            };

            directory = {
              read_only = " ";
              format = "[$path]($style) ";
              style = "bold green";
            };

            git_branch = {
              format = "[󰘬 $branch]($style)";
              style = "bold bright-black";
            };

            git_status = {
              format = " [$conflicted$untracked$modified$staged$renamed$deleted$ahead_behind$stashed ]($style)";
              style = "cyan";
              conflicted = "";
              untracked = "";
              modified = "";
              staged = "";
              renamed = "";
              deleted = "";
              stashed = "≡";
            };

            git_state = {
              format = "\\([$state( $progress_current/$progress_total)]($style)\\) ";
              style = "bold bright-black";
            };

            cmd_duration = {
              format = "[󱦟 $duration]($style)";
              style = "yellow";
            };
          };
        };

        xdg.configFile = {
          "btop/btop.conf".source = termCfg.configPaths.btop;
          "cliamp/config.toml".source = termCfg.configPaths.cliamp;
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
