{lib}: let
  inherit (builtins) readFile;

  toolingPackages = pkgs: with pkgs; [
    alejandra
    black
    curl
    gnumake
    go
    imagemagick
    isort
    nixd
    mcp-nixos
    nodejs
    prettier
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
    btop = ./. + "/../btop/btop.conf";
    cliamp = ./. + "/../cliamp/config.toml";
  };

  secretsFile = "$HOME/.local/share/secrets/fish.fish";

  extraPackages = pkgs:
    [
      pkgs.fish
      pkgs.tmux
      pkgs.neovim
      pkgs.zoxide
      pkgs.fastfetch
      pkgs.ffmpeg
      pkgs.lazygit
      pkgs.lazysql
      pkgs.cava
      pkgs.bitwarden-cli
      pkgs.yazi
      pkgs.git
      pkgs.gh
      pkgs.btop
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
