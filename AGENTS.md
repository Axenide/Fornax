# AGENTS.md

Fornax is a personal Nix flake that bundles a terminal dev environment (tmux, fish, nvim/NvChad, lazygit, yazi, starship, zoxide, fastfetch, ffmpeg, cava, bitwarden-cli) and exposes them as `packages`, `apps`, `devShells`, and a `homeManagerModules.default`. Targets `x86_64-linux` and `aarch64-linux` only.

Global agent rules (commit style, branch safety, comments policy, language) live in `opencode/AGENTS.md` and are inherited automatically through `opencode/opencode.json` (`"instructions": ["./AGENTS.md"]`). Do not duplicate them here.

## Build & Run

- `nix flake show` — list all outputs.
- `nix build .#default` — build the full `fornax` bundle.
- `nix run .#fornax` — attach to (or start) a tmux session named `fornax` in `$PWD`. The bundle's `PATH` is inherited, so all tools work without `nix profile install`.
- `nix run .#<name>` also works for: `tmux`, `fish`, `nvim`, `opencode`, `restore-secrets`, `clean-secrets`, `shred-secrets`.
- `nix develop` — shell with the full bundle on `PATH`.
- For end-user install, the README describes `nix profile add` and home-manager usage; this repo's only consumer is `flake.nix:189` `homeManagerModules.default` (enabled with `programs.fornax.enable = true`).

## Layout

- `flake.nix` — all outputs. `passthrough` (`flake.nix:91`) is the source of truth for which binaries the bundle exposes; `defaultBundle` (`flake.nix:104`) joins wrappers + passthrough + `termCfg.toolingPackages`.
- `lib/default.nix` — pure config: `configPaths`, `extraPackages`, `toolingPackages`, `tmuxPlugins`, `nvchadConfig`, `fishXdgRoot`, `fishLinkToHome`, `mergedTmuxConf`.
- `lib/wrappers.nix` — shell wrappers that wrap nixpkgs binaries with config injection (`tmux`, `fish`, `*-secrets`, `opencode`).
- `fish/` — fish config files; `fish/functions/` holds the secrets helpers. `fish_plugins` only declares `jorgebucaran/fisher` (fisherman plugin manager, not actual plugins).
- `tmux/tmux.conf` + `tmux/minimal.conf` — concatenated at build time by `mergedTmuxConf` (`lib/default.nix:56`).
- `nvim/nvchad-starter/` — vendored NvChad v2.5 starter, locally customized. Theme: `chadwal`.
- `opencode/` — OpenCode CLI config bundle (config, global rules, own `.gitignore` for `node_modules`, lockfiles, `antigravity-*`).
- `skills/` — local OpenCode skills, copied into the bundle and installed by `agent-skills-nix` in the home-manager module. Only `bubbletea-go-tui-builder` today.
- Root `.gitignore` only ignores `result` / `result-*` (Nix build symlinks). Don't add generated Nix store paths to commits.

## Flake Inputs

`flake.nix:4` declares three:

- `nixpkgs` (`nixpkgs-unstable`) — the package source.
- `nix4nvchad` (`github:nix-community/nix4nvchad`) — used by both the bundle and the home-manager module to materialize the NvChad derivation.
- `agent-skills-nix` (`github:Kyure-A/agent-skills-nix`) — used only by `homeManagerModules.default` (`flake.nix:209`) to install `skills/` and the opentui skill into `~/.config/opencode/skills/`.

## Adding a Tool

1. Add the nixpkgs package to `passthrough` in `flake.nix:91` — it auto-exposes on `PATH` and as a package/app.
2. If it needs a wrapper with config injection, add a `mkXxxWrapper` in `lib/wrappers.nix`, wire it in `flake.nix`, and append it to `defaultBundle` paths (`flake.nix:104`).
3. If it's dev tooling that should also be available inside nvim, add it to `toolingPackages` in `lib/default.nix:15` (used by both the bundle and `nvchadConfig.extraPackages`).
4. If it's home-manager-only, add to `extraPackages` in `lib/default.nix:76`; it is wired into `home.packages` by `flake.nix:218`.

When adding a new `fish/functions/*.fish`, register it in **all three** places in `lib/default.nix`: `fishXdgRoot` symlinks, `configPaths.fish.*` paths, and `fishLinkToHome` symlinks — plus the matching `xdg.configFile` entry in `flake.nix:222`. Missing one silently drops the function from the bundle or the home-manager install.

## Secrets Workflow

`fish/functions/{restore,clean,shred}-secrets.fish` + matching `mk*Wrapper` in `lib/wrappers.nix`. Storage path: `~/.local/share/secrets/fish.fish` (chmod 600 after restore).

- `restore-secrets` — `bw login` if needed → `bw unlock --raw` (exported as `BW_SESSION`) → `bw sync` → `bw get notes fish-secrets`.
- `clean-secrets` — `rm` + `rmdir`.
- `shred-secrets` — `shred -u -v -z -n 3` + `rmdir`.

## Neovim

NvChad v2.5 (`nvim/nvchad-starter/init.lua:21`). Format with stylua per `nvim/nvchad-starter/.stylua.toml`: column 120, 2-space indent, `Unix` line endings, double quotes preferred, `call_parentheses = "None"`. Theme: `chadwal`.

## tmux

- Prefix is `C-Space` (`tmux/tmux.conf:20`), not the default `C-b`.
- `vim-tmux-navigator` (C-hjkl) is loaded conditionally on both `$TMUX_PLUGIN_DIR/share/tmux-plugins/...` (nixpkgs layout) and `~/.tmux/plugins/...` (Home Manager flat layout) — `tmux/tmux.conf:43-46`. Do not collapse those two `if-shell` checks; commit `1068e9b` was a fix for this exact path.
- Plugins via `tmuxPlugins` in `lib/default.nix:95`: `sensible`, `yank`, `vim-tmux-navigator`.
- `allow-passthrough on` is required for yazi.

## OpenCode Sub-bundle

`opencode/opencode.json` enables remote MCP servers `context7`, `deepwiki`, `gitmcp`, `excalidraw`, plus a local `nixos` server backed by `mcp-nixos` from nixpkgs. `permission: "allow"` (all tool calls auto-approved — be careful), `lsp: true`, `instructions: ["./AGENTS.md"]` (loads the global rules file into every OpenCode session).

The bundle version is assembled at `flake.nix:67` (`opencodeXdg`) by combining `opencode/opencode.json`, `opencode/AGENTS.md`, the local `skills/`, and the opentui skill source. The opentui skill is pinned to a specific commit at `flake.nix:60` via `fetchFromGitHub` — bump `rev` and `hash` together when updating.

The `opencode` app (`lib/wrappers.nix:49`) is a `writeShellApplication` that runs `npx -y opencode-ai@latest` with `nodejs` + `mcp-nixos` on the runtime path — it is not a static binary, so it must be invoked through `nix run .#opencode` (or via the bundle's `PATH`). On first non-store run it copies `opencode.json`, `AGENTS.md`, and any missing skills into `~/.config/opencode/` (see `lib/wrappers.nix:54`).

The home-manager install uses a different path: `agent-skills-nix` copies `skills/` and the opentui skill (via the `opentuiSkillPath` argument the user must pass — see `flake.nix:249-266`).

## Formatters & Linters in the Bundle

Available on `PATH` once inside the bundle or `nix develop`. No hooks are configured — run manually.

- Nix: `alejandra`.
- Lua: `stylua` (config at `nvim/nvchad-starter/.stylua.toml`).
- Shell: `shfmt`.
- Python: `black`, `isort`, `pyright`, `debugpy`.
- Go: `gopls`.
- JS/TS: `nodejs`, `yarn`, `vscode-langservers-extracted`.
- LSP: `nixd` (Nix), `mcp-nixos` (local MCP server for nixpkgs options).

## Verify After Edits

There is no CI, no test suite, and no pre-commit hook. The only correctness loop is Nix evaluation:

- `nix flake check` — type/eval check across all outputs.
- `nix build .#<package>` — builds the output you touched.
- After Lua edits, run `stylua --check <changed>`.
- After fish/tmux config edits, `nix build .#fish` and `.#tmux` and visually smoke-test.

## Known Non-portable Bits

These are user-specific and will fail on a fresh machine. Do not "fix" them for portability unless asked.

- `fish/config.fish:17-19` — `conda-on` hardcodes `/home/adriano/.local/share/miniforge3/bin/conda`.
- `fish/aliases.fish:1` — `anifetch` references `~/.adrien.gif`.
- `fish/config.fish:7-9` — assumes `~/.cache/.bun/bin` and `~/.local/share/go/bin` exist.
- `lib/wrappers.nix:80` — `opencode` wrapper pins `opencode-ai@latest`; the version is determined at runtime by `npx`, not pinned in the flake.
