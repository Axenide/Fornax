{lib}: let
  inherit (builtins) readFile;
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
    };
    nvimStarter = ./. + "/../nvim/nvchad-starter";
  };

  secretsFile = "$HOME/.local/share/secrets/fish.fish";

  mergedTmuxConf = pkgs: pkgs.runCommand "axenide-tmux.conf" {} ''
    cat ${./../tmux/tmux.conf} ${./../tmux/minimal.conf} > $out
  '';

  fishXdgRoot = pkgs: pkgs.runCommand "axenide-fish-xdg" {} ''
    mkdir -p $out/fish/functions
    ln -s ${./../fish/config.fish} $out/fish/config.fish
    ln -s ${./../fish/aliases.fish} $out/fish/aliases.fish
    ln -s ${./../fish/env.fish} $out/fish/env.fish
    ln -s ${./../fish/ffmpeg.fish} $out/fish/ffmpeg.fish
    ln -s ${./../fish/fish_plugins} $out/fish/fish_plugins
    ln -s ${./../fish/functions/restore-secrets.fish} $out/fish/functions/restore-secrets.fish
  '';

  extraPackages = pkgs: [
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
  ];

  tmuxPlugins = pkgs: with pkgs.tmuxPlugins; [
    sensible
    yank
    vim-tmux-navigator
  ];

  nvchadConfig = pkgs: {
    lazy-lock = readFile (./. + "/../nvim/nvchad-starter/lazy-lock.json");
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
}
