# AGENTS.md

Fornax is a personal Nix flake that installs a terminal dev environment: fish, tmux, NvChad, lazygit, lazysql, yazi, starship, zoxide, fastfetch, ffmpeg, cava, bitwarden-cli, btop, git/gh, plus the opencode CLI config bundle (opencode.json, AGENTS.md, skills). Install is via the `homeManagerModules.default` output — there is no `nix run` / `nix profile` path. Targets `x86_64-linux` and `aarch64-linux` only.

Global agent rules (commit style, branch safety, comments policy, language) live in `opencode/AGENTS.md` and are inherited automatically through `opencode/opencode.json` (`"instructions": ["./AGENTS.md"]`). Do not duplicate them here.

## Build & Run

- `nix flake show` — list outputs (`packages`, `homeManagerModules`, `devShells`).
- `nix develop` — dev shell with the formatters/linters from `toolingPackages` (stylua, alejandra, shfmt, black, isort, pyright, gopls, nixd, nodejs, prettier, …). Use this when editing the flake itself. The same set is also exposed inside the home-manager install — no hooks run them, invoke manually.
- End-user install: home-manager only. Add fornax to flake inputs, import `fornax.homeManagerModules.default`, set `programs.fornax.enable = true`. Full snippet in `README.md`.

## Layout

- `flake.nix` — outputs. `homeManagerModules.default` wires fish, tmux, NvChad, the opencode wrapper, the `xdg.configFile` symlinks, bun, and the four activation hooks (`refreshTmux`, `syncOpencodeConfig`, `setupNpm`, `installNvChad`). Also pins `bun` and the `opentui` skill source.
- `lib/default.nix` — pure config: `configPaths`, `extraPackages`, `toolingPackages`, `tmuxPlugins`, `nvchadConfig`, `secretsFile`.
- `lib/wrappers.nix` — only `mkOpencodeWrapper`. Builds the `opencode` binary (a `writeShellApplication` running `npx -y opencode-ai@latest`) with `nodejs` + `mcp-nixos` on the runtime path. Installed at `~/.nix-profile/bin/opencode` via `home.packages`.
- `fish/` — config files (`config.fish`, `aliases.fish`, `env.fish`, `ffmpeg.fish`, `conf.d/`). `fish/functions/` holds the secrets helpers. `fish_plugins` only declares `jorgebucaran/fisher` (the plugin manager; no plugins installed by fornax).
- `tmux/tmux.conf` + `tmux/minimal.conf` — concatenated at build time into `programs.tmux.extraConfig`.
- `nvim/nvchad-starter/` — vendored NvChad v2.5 starter, locally customized. Theme: `wallsync` (`lua/chadrc.lua`).
- `btop/btop.conf` — symlinked to `~/.config/btop/btop.conf` by `xdg.configFile`.
- `opencode/` — OpenCode CLI config bundle (config, global rules, own `.gitignore`).
- `skills/` — local OpenCode skills, materialized to `~/.config/opencode/skills/` on every switch. Current entries: `bubbletea-go-tui-builder`, `rust-gtk4-expert`. The `opentui` skill is pinned inside `flake.nix` (not under `skills/`) and copied into the bundle from there.
- Root `.gitignore` only ignores `result` / `result-*` (Nix build symlinks). Don't add generated Nix store paths to commits.

## Flake Inputs

- `nixpkgs` (`nixpkgs-unstable`) — package source.
- `nix4nvchad` (`github:nix-community/nix4nvchad`) — used internally to build `packages.<system>.nvchad`. Consumers do not need to declare it.

## Flake Outputs

Three outputs, all system-conditional on `["x86_64-linux" "aarch64-linux"]`:

- `packages.<system>.nvchad` (default) — pre-built NvChad derivation (`nix4nvchad.packages.${system}.default` overridden with fornax's starter repo + `dontWrapQtApps`). Power users can install standalone, but the home-manager module is the recommended entrypoint.
- `homeManagerModules.default` — the normal entrypoint. Pulls `nvchad` from `self.packages.<pkgs.system>.nvchad`, so consumers do not need to declare `nix4nvchad`.
- `devShells.default` — exposes `termCfg.toolingPackages pkgs` via `pkgs.mkShell`.

## Activation Hooks

All four are `entryAfter ["linkGeneration"]` so they run after symlinks are in place:

- `refreshTmux` — non-destructive: if a tmux server is alive, updates `default-shell` + global `SHELL` to the new fish and re-sources `~/.config/tmux/tmux.conf`. Existing panes are left untouched.
- `syncOpencodeConfig` — overwrites `~/.config/opencode/{opencode.json, AGENTS.md, skills/}` from the fornax derivation on every switch. The repo is the source of truth; local edits there are wiped. Anything else under `~/.config/opencode/` is left alone.
- `setupNpm` — replaces `~/.npmrc` with one pinning `prefix` and `global-prefix` to `~/.cache/npm/global`. Required for `npm i -g` under Nix's read-only `nodejs`.
- `installNvChad` — destructive: if `~/.config/nvim` exists as a real directory, it is renamed to `~/.config/nvim_<timestamp>.bak`; then the NvChad config from the freshly built `nvchadPkg` is copied in. Don't rely on pre-existing nvim config surviving a `home-manager switch`.

## Adding a Tool / Function / Skill

**Tool** (CLI binary added to the home environment):
1. Add the nixpkgs package to `extraPackages` in `lib/default.nix` — wired into `home.packages` by `flake.nix`.
2. If it's dev tooling that should also be available inside nvim, add it to `toolingPackages` in `lib/default.nix`. `toolingPackages` is reused by `extraPackages` and `nvchadConfig.extraPackages`.

**Fish function** under `fish/functions/*.fish`:
1. Register the path in `configPaths.fish.<name>` (`lib/default.nix`).
2. Add the matching `xdg.configFile` entry (in `flake.nix`'s `homeManagerModules.default`).

Missing either silently drops the function from the install.

**Skill** for OpenCode:
1. Drop a directory under `skills/<name>/` with a `SKILL.md` (frontmatter `name` must match the directory name). It auto-flows into `~/.config/opencode/skills/` on every switch via `syncOpencodeConfig`.
2. The `opentui` skill is pinned inside `flake.nix` via `fetchFromGitHub` — no `skills/` entry needed; `syncOpencodeConfig` copies it from `${opentuiSkillSrc}`. Bump `rev` and `hash` together when updating.

## Secrets Workflow

`fish/functions/{restore,clean,shred}-secrets.fish`. Storage path: `~/.local/share/secrets/fish.fish` (chmod 600 after restore).

- `restore-secrets` — `bw login` if needed → `bw unlock --raw` (exported as `BW_SESSION`) → `bw sync` → `bw get notes fish-secrets`.
- `clean-secrets` — `rm` + `rmdir`.
- `shred-secrets` — `shred -u -v -z -n 3` + `rmdir`.

All three are fish functions symlinked by home-manager and callable from any fish shell.

## Neovim

NvChad v2.5 (`nvim/nvchad-starter/init.lua` pins `branch = "v2.5"`). Format Lua with stylua per `nvim/nvchad-starter/.stylua.toml`: column 120, 2-space indent, `Unix` line endings, double quotes preferred, `call_parentheses = "None"`. Theme: `wallsync` (set in `lua/chadrc.lua`); the generated theme file is written by the WallSync plugin to `~/.local/share/nvim/lazy/base46/lua/base46/themes/wallsync.lua`.

> Don't edit `fish/conf.d/fish_frozen_theme.fish`. It is auto-generated by fish 4.3's `fish_config` migration and will be overwritten. To override theme variables, delete it and add `set --global fish_color_*` lines to `config.fish` instead (see the header comment in the file).

## tmux

- Prefix is `C-Space`, not the default `C-b` (`tmux/tmux.conf`).
- `vim-tmux-navigator` (C-hjkl) is loaded conditionally on both `$TMUX_PLUGIN_DIR/share/tmux-plugins/...` (nixpkgs layout) and `~/.tmux/plugins/...` (Home Manager flat layout). Do not collapse those two `if-shell` checks; commit `1068e9b` was a fix for this exact path.
- Plugins via `tmuxPlugins` in `lib/default.nix`: `sensible`, `yank`, `vim-tmux-navigator`.
- `allow-passthrough on` is required for yazi.

## OpenCode Sub-bundle

`opencode/opencode.json` enables remote MCP servers `context7`, `deepwiki`, `gitmcp`, `excalidraw`, plus a local `nixos` server backed by `mcp-nixos` from nixpkgs. `permission: "allow"` (all tool calls auto-approved — be careful), `lsp: true`, `instructions: ["./AGENTS.md"]` (loads the global rules file into every OpenCode session).

Materialization:
- The derivation `${opencodeXdg}/opencode/` (built inside `homeManagerModules.default`) combines `opencode/opencode.json`, `opencode/AGENTS.md`, the local `skills/`, and the pinned `opentui` skill.
- The `syncOpencodeConfig` hook overwrites `~/.config/opencode/` from that derivation on every switch.
- The `opencode` binary (`lib/wrappers.nix`) is a `writeShellApplication` that runs `npx -y opencode-ai@latest` with `nodejs` + `mcp-nixos` on the runtime path. Installed at `~/.nix-profile/bin/opencode` via `home.packages`. When `$0` is in `/nix/store/...` it points `OPENCODE_CONFIG` straight at the store derivation; otherwise it points at the user-level copy managed by the `syncOpencodeConfig` hook.

## Verify After Edits

There is no CI, no test suite, and no pre-commit hook. The only correctness loop is Nix evaluation:

- `nix flake check --no-build` — type/eval check across all outputs (preferred; cheap).
- `home-manager build` in a consumer config that imports this module — the real instantiation test.
- After Lua edits, run `stylua --check <changed>` (config at `nvim/nvchad-starter/.stylua.toml`).
- After fish/tmux config edits, do a `home-manager switch` and visually smoke-test (the `refreshTmux` hook will keep your panes alive).

## Bumping the Pinned Bun

Bun is pinned in `flake.nix` via `fetchurl` against the official GitHub release zip. To bump:

1. Change `bunVersion` in `flake.nix`.
2. Regenerate both `sha256`:
   ```
   nix-prefetch-url --type sha256 https://github.com/oven-sh/bun/releases/download/bun-v${VER}/bun-linux-x64.zip
   nix-prefetch-url --type sha256 https://github.com/oven-sh/bun/releases/download/bun-v${VER}/bun-linux-aarch64.zip
   ```

## Updating the Consumer Lock

The `installNvChad` hook copies `${nvchadPkg}/config/.` from a freshly built `nvchadPkg` derivation. That derivation's content is determined by `self + "/nvim/nvchad-starter"` and therefore by the **git HEAD of this repo at build time** in the consumer flake.

If the consumer pins fornax via `flake.lock` (typical: `github:Axenide/Fornax`), pushing a new commit here is **not** enough — the consumer's lock still points at the previous revision, so `home-manager switch` will keep building from the old `nvchad-starter` (and silently reuse the cached store path). After pushing a commit to this repo, in the consumer config:

```
nix flake update fornax    # bumps the rev in flake.lock
home-manager switch        # rebuilds nvchadPkg with the new starter
```

Symptom of skipping this: `~/.config/nvim/` after `home-manager switch` looks like the previous switch's content even though you just changed files in this repo.

## Known Non-portable Bits

User-specific paths that will fail on a fresh machine. Do not "fix" them for portability unless asked.

- `fish/config.fish` — `conda-on` hardcodes `/home/adriano/.local/share/miniforge3/bin/conda`.
- `fish/aliases.fish` — `anifetch` references `~/.adrien.gif`.
- `fish/config.fish` — assumes `~/.cache/.bun/bin`, `~/.bun/bin`, and `~/.local/share/go/bin` exist on PATH.
