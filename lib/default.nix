{lib}: let
  inherit (builtins) readFile pathExists;
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

  fishUserConfig = pkgs: pkgs.runCommand "axenide-fish-user-config" {} ''
    mkdir -p $out
    ln -s ${./../fish/config.fish} $out/config.fish
    ln -s ${./../fish/aliases.fish} $out/aliases.fish
    ln -s ${./../fish/env.fish} $out/env.fish
    ln -s ${./../fish/ffmpeg.fish} $out/ffmpeg.fish
    ln -s ${./../fish/fish_plugins} $out/fish_plugins
  '';

  fishXdgRoot = pkgs: pkgs.runCommand "axenide-fish-xdg" {} ''
    mkdir -p $out
    ln -s ${(fishUserConfig pkgs)} $out/fish
  '';

  extraPackages = pkgs: [
    pkgs.fish
    pkgs.tmux
    pkgs.neovim
    pkgs.thefuck
    pkgs.starship
    pkgs.zoxide
    pkgs.neofetch
    pkgs.ffmpeg
    pkgs.lazygit
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
