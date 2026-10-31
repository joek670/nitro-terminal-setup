#!/usr/bin/env bash
# Checks the WSL side of the Nitro terminal setup. Changes nothing.
#   bash <(curl -fsSL https://raw.githubusercontent.com/joek670/nitro-terminal-setup/main/verify-wsl.sh)
set -uo pipefail

[ -x /home/linuxbrew/.linuxbrew/bin/brew ] && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
export PATH="$HOME/.bun/bin:$PATH"

pass=0; fail=0; warn=0
ok()   { printf '  PASS  %s\n' "$*"; pass=$((pass + 1)); }
bad()  { printf '  FAIL  %s\n' "$*"; fail=$((fail + 1)); }
meh()  { printf '  WARN  %s\n' "$*"; warn=$((warn + 1)); }
head_() { printf '\n== %s\n' "$*"; }

check_cmd() { # <command> <version args...>
  local cmd=$1; shift
  local path
  path=$(command -v "$cmd" 2>/dev/null) || { bad "$cmd not found"; return; }
  if [[ $path == /mnt/* ]]; then
    bad "$cmd only found on the Windows side ($path)"
    return
  fi
  local ver
  ver=$("$cmd" "$@" 2>&1 | head -n 1)
  ok "$cmd  ($ver)"
}

check_file() { # <path> <label>
  if [[ -s $1 ]]; then ok "$2  ($1)"; else bad "$2 missing ($1)"; fi
}

head_ "System"
printf '  INFO  %s, WSL distro: %s\n' "$(. /etc/os-release && echo "$PRETTY_NAME")" "${WSL_DISTRO_NAME:-not WSL}"
[[ -n ${WSL_DISTRO_NAME:-} ]] && ok "running inside WSL" || meh "not running inside WSL"

head_ "Commands"
check_cmd brew --version
check_cmd tmux -V
check_cmd sesh --version
check_cmd nvim --version
check_cmd starship --version
check_cmd eza --version
check_cmd bat --version
check_cmd fzf --version
check_cmd rg --version
check_cmd fd --version
check_cmd zoxide --version
check_cmd lazygit --version
check_cmd git --version
check_cmd omp --version

if command -v nvim >/dev/null; then
  nv=$(nvim --version | head -n 1 | grep -oE '[0-9]+\.[0-9]+' | head -n 1)
  if [[ $(printf '%s\n0.11\n' "$nv" | sort -V | head -n 1) == 0.11 ]]; then
    ok "Neovim $nv is new enough for LazyVim (0.11+)"
  else
    bad "Neovim $nv is too old for LazyVim (needs 0.11+)"
  fi
fi

head_ "Config files"
check_file "$HOME/.config/starship.toml" "Starship config"
check_file "$HOME/.config/tmux/tmux.conf" "tmux config"
check_file "$HOME/.config/tmux/plugins/catppuccin/tmux/catppuccin.tmux" "Catppuccin tmux theme"
check_file "$HOME/.config/bash/nitro.sh" "bash additions"
check_file "$HOME/.config/nvim/init.lua" "LazyVim starter"
check_file "$HOME/.config/nvim/lua/plugins/colorscheme.lua" "LazyVim Catppuccin theme"
if [[ -d $HOME/.local/share/nvim/lazy/LazyVim ]]; then ok "LazyVim plugins downloaded"; else bad "LazyVim plugins not downloaded (open nvim once)"; fi
if grep -qF '.config/bash/nitro.sh' "$HOME/.bashrc" 2>/dev/null; then ok "~/.bashrc loads the additions"; else bad "~/.bashrc does not source ~/.config/bash/nitro.sh"; fi

head_ "Do they actually work"
if command -v starship >/dev/null; then
  if starship print-config >/dev/null 2>&1; then ok "Starship config parses"; else bad "Starship config has errors (run: starship print-config)"; fi
fi

if command -v tmux >/dev/null; then
  out=$(tmux -L nitro-verify -f "$HOME/.config/tmux/tmux.conf" new-session -d -x 200 -y 50 2>&1)
  if [[ $? -eq 0 ]]; then
    prefix=$(tmux -L nitro-verify show -gv prefix 2>/dev/null)
    flavor=$(tmux -L nitro-verify show -gv @catppuccin_flavor 2>/dev/null)
    [[ $prefix == C-a ]] && ok "tmux config loads (prefix Ctrl+a)" || bad "tmux prefix is '$prefix', expected C-a"
    [[ $flavor == mocha ]] && ok "tmux Catppuccin Mocha active" || bad "tmux Catppuccin theme not active"
    tmux -L nitro-verify list-keys -T prefix a 2>/dev/null | grep -q omp && ok "tmux prefix+a opens omp" || bad "tmux prefix+a binding missing"
    tmux -L nitro-verify kill-server 2>/dev/null
  else
    bad "tmux config failed to load: $out"
  fi
fi

if command -v nvim >/dev/null; then
  cs=$(timeout 60 nvim --headless "+lua io.write(vim.g.colors_name or 'none')" +qa 2>/dev/null)
  [[ $cs == catppuccin* ]] && ok "Neovim starts with colorscheme $cs" || meh "Neovim colorscheme is '$cs' (fine if plugins are still installing)"
fi

shell_check=$(bash -ic 'type -t ll; echo "$BAT_THEME"; type -t __zoxide_z; type -t starship_precmd' 2>/dev/null | tr '\n' ' ')
[[ $shell_check == alias*"Catppuccin Mocha"*function*function* ]] && ok "interactive bash: aliases, theme, zoxide, Starship loaded" \
  || bad "interactive bash setup incomplete (got: $shell_check)"

if command -v omp >/dev/null; then
  if timeout 20 omp --help >/dev/null 2>&1; then ok "omp starts"; else bad "omp is installed but 'omp --help' failed"; fi
fi

head_ "Summary"
printf '  %d passed, %d failed, %d warnings\n' "$pass" "$fail" "$warn"
[[ $fail -eq 0 ]] && echo "  WSL side is complete." || echo "  Paste this output to Claude to fix the failures."
