# AGENTS.md

Fornax is a personal Nix flake that installs a terminal dev environment (tmux, fish, nvim/NvChad, lazygit, lazysql, yazi, starship, zoxide, fastfetch, ffmpeg, cava, bitwarden-cli, btop, git, plus the opencode CLI with bundled config and skills) **exclusively via the `homeManagerModules.default` module**. There are no `packages` or `apps` outputs — those were dropped; the wrapper-based bundle path was unnecessary. Targets `x86_64-linux` and `aarch64-linux` only.

Global agent rules (commit style, branch safety, comments policy, language) live in `opencode/AGENTS.md` and are inherited automatically through `opencode/opencode.json` (`"instructions": ["./AGENTS.md"]`). Do not duplicate them here.

## Build & Run

- `nix flake show` — list outputs (only `homeManagerModules` and `devShells`).
- `nix develop` — dev shell with formatters/linters (stylua, alejandra, shfmt, black, pyright, gopls, nixd, …). Use this when editing the flake itself.
- End-user install: home-manager only. Add fornax to your flake inputs and import `fornax.homeManagerModules.default`, then set `programs.fornax.enable = true`.

## Layout

- `flake.nix` — outputs. `devShells.default` exposes `termCfg.toolingPackages pkgs`. `homeManagerModules.default` (`flake.nix:48`) wires fish, tmux, NvChad, the opencode wrapper, the `xdg.configFile` symlinks, and the two activation hooks (`refreshTmux`, `syncOpencodeConfig`).
- `lib/default.nix` — pure config: `configPaths`, `extraPackages`, `toolingPackages`, `tmuxPlugins`, `nvchadConfig`, `secretsFile`.
- `lib/wrappers.nix` — only `mkOpencodeWrapper`. Other wrappers (`tmux`, `fish`, `*-secrets`, `btop`, `bundleTmuxPlugins`) were dropped with the bundle path.
- `fish/` — fish config files; `fish/functions/` holds the secrets helpers. `fish_plugins` only declares `jorgebucaran/fisher` (plugin manager, not actual plugins).
- `tmux/tmux.conf` + `tmux/minimal.conf` — concatenated at build time by home-manager's `programs.tmux.extraConfig` (`flake.nix:110`).
- `nvim/nvchad-starter/` — vendored NvChad v2.5 starter, locally customized. Theme: `chadwal`.
- `opencode/` — OpenCode CLI config bundle (config, global rules, own `.gitignore` for `node_modules`, lockfiles, `antigravity-*`).
- `skills/` — local OpenCode skills, copied into `opencodeXdg` (`flake.nix:68`) and materialized to `~/.config/opencode/skills/` on every switch by `syncOpencodeConfig`. Current entries: `bubbletea-go-tui-builder`, `rust-gtk4-expert`.
- Root `.gitignore` only ignores `result` / `result-*` (Nix build symlinks). Don't add generated Nix store paths to commits.

## Flake Inputs

`flake.nix:4` declares two:

- `nixpkgs` (`nixpkgs-unstable`) — package source.
- `nix4nvchad` (`github:nix-community/nix4nvchad`) — used by the home-manager module to materialize the NvChad derivation.

The opentui skill is pinned internally at `flake.nix:33` via `fetchFromGitHub` and used by the module's `opencodeXdg`. Bump `rev` and `hash` together when updating.

## Activation Hooks

Both `entryAfter ["linkGeneration"]` so they run after symlinks are in place:

- `refreshTmux` (`flake.nix:118`) — non-destructive: if a tmux server is alive, updates `default-shell` + global `SHELL` to the new fish and re-sources `~/.config/tmux/tmux.conf`. Existing panes are left untouched.
- `syncOpencodeConfig` (`flake.nix:125`) — overwrites `~/.config/opencode/{opencode.json, AGENTS.md, skills/}` from `${opencodeXdg}/opencode` on every switch. The repo is the source of truth; local edits there are wiped.

## Adding a Tool

1. Add the nixpkgs package to `extraPackages` in `lib/default.nix:43` — wired into `home.packages` by `flake.nix:81`.
2. If it's dev tooling that should also be available inside nvim, add it to `toolingPackages` in `lib/default.nix:4`. `toolingPackages` is reused by `extraPackages` and `nvchadConfig.extraPackages`.

When adding a new `fish/functions/*.fish`, register it in:

1. `configPaths.fish.<name>` (`lib/default.nix:25`).
2. The matching `xdg.configFile` entry (`flake.nix:86`).

Missing either silently drops the function from the install.

## Adding a Skill

1. Drop the skill directory under `skills/<name>/` with a `SKILL.md` (frontmatter `name` must match the directory name). It auto-flows into `~/.config/opencode/skills/` on every switch via the `syncOpencodeConfig` hook.
2. The opentui skill is pinned inside the flake at `flake.nix:33` — no `skills/` entry needed; `syncOpencodeConfig` copies it from `${opentuiSkillSrc}`.

## Secrets Workflow

`fish/functions/{restore,clean,shred}-secrets.fish`. Storage path: `~/.local/share/secrets/fish.fish` (chmod 600 after restore).

- `restore-secrets` — `bw login` if needed → `bw unlock --raw` (exported as `BW_SESSION`) → `bw sync` → `bw get notes fish-secrets`.
- `clean-secrets` — `rm` + `rmdir`.
- `shred-secrets` — `shred -u -v -z -n 3` + `rmdir`.

All three are fish functions symlinked by home-manager (`flake.nix:96-100`) and callable as `restore-secrets`, `clean-secrets`, `shred-secrets` from any fish shell.

## Neovim

NvChad v2.5 (`nvim/nvchad-starter/init.lua:27`). Format with stylua per `nvim/nvchad-starter/.stylua.toml`: column 120, 2-space indent, `Unix` line endings, double quotes preferred, `call_parentheses = "None"`. Theme: `chadwal` (`lua/chadrc.lua:5`).

## tmux

- Prefix is `C-Space` (`tmux/tmux.conf:20`), not the default `C-b`.
- `vim-tmux-navigator` (C-hjkl) is loaded conditionally on both `$TMUX_PLUGIN_DIR/share/tmux-plugins/...` (nixpkgs layout) and `~/.tmux/plugins/...` (Home Manager flat layout) — `tmux/tmux.conf:43-46`. Do not collapse those two `if-shell` checks; commit `1068e9b` was a fix for this exact path.
- Plugins via `tmuxPlugins` in `lib/default.nix:67`: `sensible`, `yank`, `vim-tmux-navigator`.
- `allow-passthrough on` is required for yazi.

## OpenCode Sub-bundle

`opencode/opencode.json` enables remote MCP servers `context7`, `deepwiki`, `gitmcp`, `excalidraw`, plus a local `nixos` server backed by `mcp-nixos` from nixpkgs. `permission: "allow"` (all tool calls auto-approved — be careful), `lsp: true`, `instructions: ["./AGENTS.md"]` (loads the global rules file into every OpenCode session).

Materialization:
- The derivation `${opencodeXdg}/opencode/` (`flake.nix:43`) combines `opencode/opencode.json`, `opencode/AGENTS.md`, the local `skills/`, and the pinned opentui skill.
- The `syncOpencodeConfig` hook overwrites `~/.config/opencode/` from that derivation on every switch.
- The `opencode` binary (`lib/wrappers.nix`) is a `writeShellApplication` that runs `npx -y opencode-ai@latest` with `nodejs` + `mcp-nixos` on the runtime path. Installed at `~/.nix-profile/bin/opencode` via `home.packages`. When `$0` is in `/nix/store/...` it points `OPENCODE_CONFIG` straight at the store derivation; otherwise it points at the user-level copy managed by the hook.

## Formatters & Linters

Available in `nix develop` and inside the home-manager install (via `toolingPackages`). No hooks are configured — run manually.

- Nix: `alejandra`.
- Lua: `stylua` (config at `nvim/nvchad-starter/.stylua.toml`).
- Shell: `shfmt`.
- Python: `black`, `isort`, `pyright`, `debugpy`.
- Go: `gopls`.
- JS/TS: `nodejs`, `yarn`, `vscode-langservers-extracted`.
- LSP: `nixd` (Nix), `mcp-nixos` (local MCP server for nixpkgs options).

## Verify After Edits

There is no CI, no test suite, and no pre-commit hook. The only correctness loop is Nix evaluation:

- `nix flake check --no-build` — type/eval check across all outputs (preferred; cheap).
- `home-manager build` in a consumer config that imports this module — the real instantiation test.
- After Lua edits, run `stylua --check <changed>`.
- After fish/tmux config edits, do a `home-manager switch` and visually smoke-test (the `refreshTmux` hook will keep your panes alive).

## Known Non-portable Bits

These are user-specific and will fail on a fresh machine. Do not "fix" them for portability unless asked.

- `fish/config.fish:17-19` — `conda-on` hardcodes `/home/adriano/.local/share/miniforge3/bin/conda`.
- `fish/aliases.fish:1` — `anifetch` references `~/.adrien.gif`.
- `fish/config.fish:7-9` — assumes `~/.cache/.bun/bin` and `~/.local/share/go/bin` exist.
- `lib/wrappers.nix` — `opencode` wrapper pins `opencode-ai@latest`; the version is determined at runtime by `npx`, not pinned in the flake.
