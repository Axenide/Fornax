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
    };
    nvimStarter = ./. + "/../nvim/nvchad-starter";
  };

  mergedTmuxConf = pkgs: pkgs.runCommand "axenide-tmux.conf" {} ''
    cat ${./../tmux/tmux.conf} ${./../tmux/minimal.conf} > $out
  '';

  fishXdgRoot = pkgs: pkgs.runCommand "axenide-fish-xdg" {} ''
    mkdir -p $out/fish
    ln -s ${./../fish/config.fish} $out/fish/config.fish
    ln -s ${./../fish/aliases.fish} $out/fish/aliases.fish
    ln -s ${./../fish/env.fish} $out/fish/env.fish
    ln -s ${./../fish/ffmpeg.fish} $out/fish/ffmpeg.fish
    ln -s ${./../fish/fish_plugins} $out/fish/fish_plugins
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
