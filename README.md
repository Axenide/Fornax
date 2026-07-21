# Fornax
*Axenide's alchemical furnace.*

**Fornax** is an opinionated Nix flake containing the tools I use for development:
- tmux
- fish
- starship
- NvChad (nvim)
- lazygit
- lazysql
- zoxide
- yazi
- fastfetch, cava, ffmpeg
- bitwarden-cli
- opencode (CLI + bundled config/skills)

Install is **home-manager only** (via the `fornax.homeManagerModules.default` module). There is no bundle or `nix run` path.

## Install

In your home-manager flake:

```nix
{
  inputs.fornax.url = "github:Axenide/Fornax";

  outputs = { nixpkgs, home-manager, fornax, ... }:
    home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        fornax.homeManagerModules.default
        { programs.fornax.enable = true; }
      ];
    };
}
```

Then `home-manager switch`. On every switch:
- `~/.config/opencode/{opencode.json, AGENTS.md}` is overwritten from the repo (source of truth).
- `~/.config/opencode/skills/` is populated by `agent-skills-nix` from the local `skills/` directory plus the pinned `adk-skill` and `opentui` inputs.
- If a tmux server is alive, `default-shell` + global `SHELL` are updated to the new fish and the config is re-sourced — non-destructive, your panes stay.

## Working on Fornax itself

```bash
nix develop      # stylua, alejandra, shfmt, black, pyright, gopls, nixd, …
```