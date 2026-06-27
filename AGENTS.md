# AGENTS.md

Fornax is a personal Nix flake that bundles a terminal dev environment (tmux, fish, nvim/NvChad, lazygit, lazysql, yazi, starship, zoxide, fastfetch, ffmpeg, cava, bitwarden-cli, btop, git) and exposes them as `packages`, `apps`, `devShells`, and a `homeManagerModules.default`. Targets `x86_64-linux` and `aarch64-linux` only.

Global agent rules (commit style, branch safety, comments policy, language) live in `opencode/AGENTS.md` and are inherited automatically through `opencode/opencode.json` (`"instructions": ["./AGENTS.md"]`). Do not duplicate them here.

## Build & Run

- `nix flake show` — list all outputs.
- `nix build .#default` — build the full `fornax` bundle.
- `nix run .#fornax` — attach to (or start) a tmux session named `fornax` in `$PWD`. The bundle's `PATH` is inherited, so all tools work without `nix profile install`.
- `nix run .#<name>` also works for: `tmux`, `fish`, `nvim`, `opencode`, `restore-secrets`, `clean-secrets`, `shred-secrets`.
- `nix develop` — shell with the full bundle on `PATH`.
- For end-user install, `README.md` describes `nix profile add` and home-manager usage; this repo's only consumer is `flake.nix:191` `homeManagerModules.default` (enabled with `programs.fornax.enable = true`).

## Layout

- `flake.nix` — all outputs. `passthrough` (`flake.nix:91`) is the source of truth for which binaries the bundle exposes; `defaultBundle` (`flake.nix:106`) joins wrappers + passthrough + `termCfg.toolingPackages`.
- `lib/default.nix` — pure config: `configPaths`, `extraPackages`, `toolingPackages`, `tmuxPlugins`, `nvchadConfig`, `fishXdgRoot`, `fishLinkToHome`, `mergedTmuxConf`.
- `lib/wrappers.nix` — shell wrappers that wrap nixpkgs binaries with config injection (`tmux`, `fish`, `*-secrets`, `opencode`, `btop`).
- `fish/` — fish config files; `fish/functions/` holds the secrets helpers. `fish_plugins` only declares `jorgebucaran/fisher` (fisherman plugin manager, not actual plugins).
- `tmux/tmux.conf` + `tmux/minimal.conf` — concatenated at build time by `mergedTmuxConf` (`lib/default.nix:57`).
- `nvim/nvchad-starter/` — vendored NvChad v2.5 starter, locally customized. Theme: `chadwal`.
- `opencode/` — OpenCode CLI config bundle (config, global rules, own `.gitignore` for `node_modules`, lockfiles, `antigravity-*`).
- `skills/` — local OpenCode skills, copied into the bundle (`flake.nix:72`) and installed by `agent-skills-nix` in the home-manager module (`flake.nix:252-270`). Current entries: `bubbletea-go-tui-builder`, `rust-gtk4-expert`.
- Root `.gitignore` only ignores `result` / `result-*` (Nix build symlinks). Don't add generated Nix store paths to commits.

## Flake Inputs

`flake.nix:4` declares three:

- `nixpkgs` (`nixpkgs-unstable`) — the package source.
- `nix4nvchad` (`github:nix-community/nix4nvchad`) — used by both the bundle and the home-manager module to materialize the NvChad derivation.
- `agent-skills-nix` (`github:Kyure-A/agent-skills-nix`) — used only by `homeManagerModules.default` (`flake.nix:211`) to install `skills/` and the opentui skill into `~/.config/opencode/skills/`.

## Adding a Tool

1. Add the nixpkgs package to `passthrough` in `flake.nix:91` — it auto-exposes on `PATH` and as a package/app.
2. If it needs a wrapper with config injection, add a `mkXxxWrapper` in `lib/wrappers.nix`, wire it in `flake.nix`, and append it to `defaultBundle` paths (`flake.nix:106`).
3. If it's dev tooling that should also be available inside nvim, add it to `toolingPackages` in `lib/default.nix:15` (used by both the bundle and `nvchadConfig.extraPackages`).
4. If it's home-manager-only, add to `extraPackages` in `lib/default.nix:77`; it is wired into `home.packages` by `flake.nix:220`.

When adding a new `fish/functions/*.fish`, register it in:

1. `fishXdgRoot` symlinks (`lib/default.nix:3-13`) — needed for the bundle's fish wrapper to see it.
2. `configPaths.fish.<name>` (`lib/default.nix:41-51`) — needed for wrappers that `source` it directly.
3. The matching `xdg.configFile` entry (`flake.nix:224-233`) — needed for the home-manager install.
4. `fishLinkToHome` (`lib/default.nix:63-75`) — **only** if it should be callable interactively from a fish shell. Currently only `restore-secrets` is wired here; `clean-secrets` and `shred-secrets` are deliberately wrappers-only (call them via `nix run .#clean-secrets`, not from inside fish).

Missing one of the first three silently drops the function from the bundle or the home-manager install.

## Adding a Skill

1. Drop the skill directory under `skills/<name>/` with a `SKILL.md` (frontmatter `name` must match the directory name) — it auto-flows into the bundle via `flake.nix:72` (`opencodeXdg` `cp -rL ${./skills}/.`).
2. Add the skill name to the whitelist at `flake.nix:260-264` (`agent-skills.skills.enable`) or it won't be installed by `agent-skills-nix` into `~/.config/opencode/skills/`. The opentui skill is special: it's fetched from GitHub at `flake.nix:60` and wired in as a separate source at `flake.nix:252-256`, so it doesn't need a `skills/` entry.
3. The `opencode` wrapper (`lib/wrappers.nix:47`) also copies any missing `skills/<name>/SKILL.md` from `opencodeXdg` into `~/.config/opencode/skills/` on first run, so non-home-manager users still get the skill via `nix run .#opencode`.

## Secrets Workflow

`fish/functions/{restore,clean,shred}-secrets.fish` + matching `mk*Wrapper` in `lib/wrappers.nix`. Storage path: `~/.local/share/secrets/fish.fish` (chmod 600 after restore).

- `restore-secrets` — `bw login` if needed → `bw unlock --raw` (exported as `BW_SESSION`) → `bw sync` → `bw get notes fish-secrets`.
- `clean-secrets` — `rm` + `rmdir`.
- `shred-secrets` — `shred -u -v -z -n 3` + `rmdir`.

## Neovim

NvChad v2.5 (`nvim/nvchad-starter/init.lua:27`). Format with stylua per `nvim/nvchad-starter/.stylua.toml`: column 120, 2-space indent, `Unix` line endings, double quotes preferred, `call_parentheses = "None"`. Theme: `chadwal` (`lua/chadrc.lua:5`).

## tmux

- Prefix is `C-Space` (`tmux/tmux.conf:20`), not the default `C-b`.
- `vim-tmux-navigator` (C-hjkl) is loaded conditionally on both `$TMUX_PLUGIN_DIR/share/tmux-plugins/...` (nixpkgs layout) and `~/.tmux/plugins/...` (Home Manager flat layout) — `tmux/tmux.conf:43-46`. Do not collapse those two `if-shell` checks; commit `1068e9b` was a fix for this exact path.
- Plugins via `tmuxPlugins` in `lib/default.nix:98`: `sensible`, `yank`, `vim-tmux-navigator`.
- `allow-passthrough on` is required for yazi.

## OpenCode Sub-bundle

`opencode/opencode.json` enables remote MCP servers `context7`, `deepwiki`, `gitmcp`, `excalidraw`, plus a local `nixos` server backed by `mcp-nixos` from nixpkgs. `permission: "allow"` (all tool calls auto-approved — be careful), `lsp: true`, `instructions: ["./AGENTS.md"]` (loads the global rules file into every OpenCode session).

The bundle version is assembled at `flake.nix:67` (`opencodeXdg`) by combining `opencode/opencode.json`, `opencode/AGENTS.md`, the local `skills/`, and the opentui skill source. The opentui skill is pinned to a specific commit at `flake.nix:60` via `fetchFromGitHub` — bump `rev` and `hash` together when updating.

The `opencode` app (`lib/wrappers.nix:47`) is a `writeShellApplication` that runs `npx -y opencode-ai@latest` with `nodejs` + `mcp-nixos` on the runtime path — it is not a static binary, so it must be invoked through `nix run .#opencode` (or via the bundle's `PATH`). On first non-store run it copies `opencode.json`, `AGENTS.md`, and any missing skills into `~/.config/opencode/` (see `lib/wrappers.nix:58-75`).

The home-manager install uses a different path: `agent-skills-nix` copies `skills/` and the opentui skill (via the `opentuiSkillPath` argument the user must pass — see `flake.nix:197`, `flake.nix:252-270`).

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
- `lib/wrappers.nix:78` — `opencode` wrapper pins `opencode-ai@latest`; the version is determined at runtime by `npx`, not pinned in the flake.
