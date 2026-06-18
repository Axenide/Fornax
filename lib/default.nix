{lib}: let
  inherit (builtins) readFile;
    fishXdgRoot = pkgs: pkgs.runCommand "axenide-fish-xdg" {} ''
    mkdir -p $out/fish/functions
    ln -s ${./../fish/config.fish} $out/fish/config.fish
    ln -s ${./../fish/aliases.fish} $out/fish/aliases.fish
    ln -s ${./../fish/env.fish} $out/fish/env.fish
    ln -s ${./../fish/ffmpeg.fish} $out/fish/ffmpeg.fish
    ln -s ${./../fish/fish_plugins} $out/fish/fish_plugins
    ln -s ${./../fish/functions/restore-secrets.fish} $out/fish/functions/restore-secrets.fish
    ln -s ${./../fish/functions/clean-secrets.fish} $out/fish/functions/clean-secrets.fish
    ln -s ${./../fish/functions/shred-secrets.fish} $out/fish/functions/shred-secrets.fish
  '';

  toolingPackages = pkgs: with pkgs; [
    alejandra
    black
    gcc
    gnumake
    go
    imagemagick
    isort
    nixd
    mcp-nixos
    nodejs
    python3Packages.debugpy
    pyright
    gopls
    kdePackages.qtdeclarative
    shfmt
    stylua
    tree-sitter
    vscode-langservers-extracted
    yarn
  ];
in {
  configPaths = {
    tmux = ./. + "/../tmux/tmux.conf";
    tmuxMinimal = ./. + "/../tmux/minimal.conf";
    fish = {
      config = ./. + "/../fish/config.fish";
      aliases = ./. + "/../fish/aliases.fish";
      env = ./. + "/../fish/env.fish";
      ffmpeg = ./. + "/../fish/ffmpeg.fish";
      plugins = ./. + "/../fish/fish_plugins";
      functionsDir = ./. + "/../fish/functions";
      restoreSecrets = ./. + "/../fish/functions/restore-secrets.fish";
      cleanSecrets = ./. + "/../fish/functions/clean-secrets.fish";
      shredSecrets = ./. + "/../fish/functions/shred-secrets.fish";
    };
    nvimStarter = ./. + "/../nvim/nvchad-starter";
  };

  secretsFile = "$HOME/.local/share/secrets/fish.fish";

  mergedTmuxConf = pkgs: pkgs.runCommand "axenide-tmux.conf" {} ''
    cat ${./../tmux/tmux.conf} ${./../tmux/minimal.conf} > $out
  '';

  inherit fishXdgRoot;

  fishLinkToHome = pkgs:
    pkgs.writeShellScript "axenide-fish-link-home" ''
      set -e
      export HOME=''${HOME:-$HOME}
      mkdir -p "$HOME/.config/fish/functions"
      ln -sfT "${fishXdgRoot pkgs}/fish/config.fish"     "$HOME/.config/fish/config.fish"
      ln -sfT "${fishXdgRoot pkgs}/fish/aliases.fish"    "$HOME/.config/fish/aliases.fish"
      ln -sfT "${fishXdgRoot pkgs}/fish/env.fish"        "$HOME/.config/fish/env.fish"
      ln -sfT "${fishXdgRoot pkgs}/fish/ffmpeg.fish"     "$HOME/.config/fish/ffmpeg.fish"
      ln -sfT "${fishXdgRoot pkgs}/fish/fish_plugins"    "$HOME/.config/fish/fish_plugins"
      ln -sfT "${fishXdgRoot pkgs}/fish/functions/restore-secrets.fish" \
              "$HOME/.config/fish/functions/restore-secrets.fish"
    '';

  extraPackages = pkgs:
    [
      pkgs.fish
      pkgs.tmux
      pkgs.neovim
      pkgs.starship
      pkgs.zoxide
      pkgs.fastfetch
      pkgs.ffmpeg
      pkgs.lazygit
      pkgs.cava
      pkgs.bitwarden-cli
      pkgs.yazi
      pkgs.git
      pkgs.coreutils
      pkgs.mcp-nixos
    ]
    ++ (toolingPackages pkgs);

  tmuxPlugins = pkgs: with pkgs.tmuxPlugins; [
    sensible
    yank
    vim-tmux-navigator
  ];

  nvchadConfig = pkgs: {
    lazy-lock = readFile (./. + "/../nvim/nvchad-starter/lazy-lock.json");
    extraPackages = toolingPackages pkgs;
  };

  inherit toolingPackages;
}
