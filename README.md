# Nitro terminal setup

Windows Terminal + PowerShell 7 + WSL2 (Ubuntu), with Starship, a Nerd Font,
tmux + sesh, Neovim + LazyVim, lazygit, btop, yazi, the GitHub CLI, modern CLI tools, the oh-my-pi (`omp`) coding
agent and Catppuccin Mocha everywhere.

## Layout

```
bootstrap.ps1                        One-line download + install (Windows)
verify-windows.ps1, verify-wsl.sh    Read-only checks that everything installed and loads
update-all.ps1                       Update everything; -Register schedules it weekly
install-windows.ps1                  Windows side (run first, as admin)
windows/configure.ps1                PowerShell 7 profile, Starship, Windows Terminal settings
windows/Microsoft.PowerShell_profile.ps1
windows/catppuccin-mocha.json        Windows Terminal colour scheme
shared/starship.toml                 Prompt, used by PowerShell and bash
wsl/install-wsl.sh                   WSL side (run inside Ubuntu)
wsl/tmux.conf                        -> ~/.config/tmux/tmux.conf
wsl/bashrc-nitro.sh                  -> ~/.config/bash/nitro.sh (sourced from ~/.bashrc)
wsl/nvim/lua/plugins/colorscheme.lua -> LazyVim Catppuccin theme
```

## Install

1. Open **PowerShell as Administrator** (Start, type `PowerShell`, right-click,
   *Run as administrator*) and run:
   ```powershell
   irm https://raw.githubusercontent.com/joek670/nitro-terminal-setup/main/bootstrap.ps1 | iex
   ```
   This downloads the repo to `%USERPROFILE%\nitro-terminal-setup` and runs
   `install-windows.ps1`.
2. To re-run later or pass flags, from that folder in an admin PowerShell:
   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass -Force
   .\install-windows.ps1 -SkipWsl
   ```
   Flags: `-SkipWsl`, `-SkipCliTools`, `-SkipAI`. An existing `omp` is detected
   and left alone on both Windows and WSL.
3. Reboot if WSL was just installed.
4. Open **Windows Terminal -> Ubuntu**, create your Linux user, then run the
   command the Windows script printed, e.g.:
   ```bash
   bash /mnt/c/Users/<you>/nitro-terminal-setup/wsl/install-wsl.sh
   ```
5. Open a new tab.

Both scripts can be re-run safely. Packages already installed are skipped, and
any config they replace is kept as `<file>.bak-<timestamp>`.

## Check it worked

Both scripts only read; they print PASS / FAIL / WARN for every piece.

- Windows, in a **new PowerShell 7** tab:
  ```powershell
  irm https://raw.githubusercontent.com/joek670/nitro-terminal-setup/main/verify-windows.ps1 | iex
  ```
- WSL, in a **new Ubuntu** tab:
  ```bash
  bash <(curl -fsSL https://raw.githubusercontent.com/joek670/nitro-terminal-setup/main/verify-wsl.sh)
  ```

## Keep everything up to date

`update-all.ps1` updates, in one go:

- every winget app (`winget upgrade --all`), including Windows Terminal, PowerShell 7 and the CLI tools
- the PSFzf PowerShell module and oh-my-pi on Windows (`omp update`)
- WSL itself (`wsl --update`), Ubuntu packages (`apt full-upgrade`), Homebrew packages
- oh-my-pi in WSL, Neovim plugins (LazyVim sync) and the Catppuccin tmux theme (latest v2.x)

Run it now from an **admin** PowerShell:
```powershell
irm https://raw.githubusercontent.com/joek670/nitro-terminal-setup/main/update-all.ps1 | iex
```

Run it automatically every week (Sunday 12:00, or the next time the laptop is on).
From the repo folder, in an admin PowerShell:
```powershell
cd $env:USERPROFILE\nitro-terminal-setup
.\update-all.ps1 -Register                  # or: -Register -Day Wednesday -At 03:00
.\update-all.ps1 -Unregister                # stop the schedule
```
The task runs a saved copy at `%LOCALAPPDATA%\nitro-terminal-setup\update-all.ps1`, hidden,
and logs to `%LOCALAPPDATA%\nitro-terminal-setup\logs`. Windows itself, drivers and Store
apps keep updating through Windows Update and the Microsoft Store.

## What it changes

| Where | Change |
|---|---|
| winget | Windows Terminal, PowerShell 7, Git, GitHub CLI (gh), Starship, eza, bat, fzf, ripgrep, fd, zoxide, Neovim, lazygit, oh-my-pi, JetBrainsMono Nerd Font |
| PowerShell | `PSFzf` module; profile at `$PROFILE`; execution policy CurrentUser -> RemoteSigned |
| Windows Terminal | Adds Catppuccin Mocha; defaults: that scheme, JetBrainsMono Nerd Font 11, PowerShell 7 as default profile. Comments in `settings.json` are not kept (backup is) |
| `%USERPROFILE%\.wslconfig` | Only if missing: WSL memory capped at half your RAM, gradual memory reclaim |
| WSL | Ubuntu, Homebrew, tmux, sesh, Neovim, Starship, eza, bat, fzf, ripgrep, fd, zoxide, lazygit, btop, yazi, gh, Bun + oh-my-pi; LazyVim starter in `~/.config/nvim` |

## Cheat sheet

| Keys / command | Where | Does |
|---|---|---|
| `Win + \`` | anywhere | Drop-down (Quake) terminal |
| `Ctrl+r` / `Ctrl+t` | both shells | fzf history / file search |
| `z <dir>` / `zi` | both shells | zoxide jump / interactive jump |
| `ll`, `lt` | both shells | eza long list / tree |
| `dev` | PowerShell | Open WSL in your Linux home |
| `Ctrl+a` | tmux | Prefix |
| prefix `\|` / `-` | tmux | Split side-by-side / stacked |
| prefix `h j k l` | tmux | Move between panes |
| prefix `T` / `S` | tmux | sesh picker / last session |
| prefix `a` | tmux | oh-my-pi (`omp`) in a side split |
| `omp` | both | oh-my-pi coding agent |
| `Alt+s` | bash, outside tmux | sesh picker |
| `nvim`, `lg` | both | Neovim (LazyVim in WSL), lazygit |
| `y` | bash | yazi file manager; `q` quits into the folder you were in, `Q` quits without moving |
| `btop` | bash | System monitor. In WSL it shows the Linux VM (Docker, builds), not Windows apps |
| `gh` | both | GitHub CLI; run `gh auth login` once on each side |

## Before gaming

`wsl --shutdown` frees the RAM WSL is holding.

## Undo

- Restore `*.bak-*` files (Windows Terminal `settings.json`, `$PROFILE`, `~/.config/...`).
- Remove the `nitro-terminal-setup` line from `~/.bashrc`.
- `wsl --unregister Ubuntu` removes the Linux install entirely (deletes its files).
- `winget uninstall <id>` for any package.
