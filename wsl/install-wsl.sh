#!/usr/bin/env bash
# Nitro terminal setup - WSL (Ubuntu) side.
# Run inside Ubuntu as your normal user (not root):
#   bash /mnt/c/Users/<you>/nitro-terminal-setup/wsl/install-wsl.sh
# Installs tmux, sesh, Neovim + LazyVim, Starship, modern CLI tools (incl. btop, yazi, gh) and the oh-my-pi
# coding agent (omp) via Homebrew and Bun,
# then copies the configs. Safe to re-run: replaced configs are backed up.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED="$HERE/../shared"
STAMP="$(date +%Y%m%d-%H%M%S)"
BREW=/home/linuxbrew/.linuxbrew/bin/brew

say()  { printf '\n==> %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }

backup() {
  if [[ -e "$1" || -L "$1" ]]; then
    mv "$1" "$1.bak-$STAMP"
    echo "  backed up $1"
  fi
}

install_config() { # <source> <destination>
  mkdir -p "$(dirname "$2")"
  if [[ -f "$2" ]] && cmp -s "$1" "$2"; then
    echo "  [skip] $2 unchanged"
    return
  fi
  backup "$2"
  # tr strips CRs in case the folder went through a Windows editor or git autocrlf.
  tr -d '\r' < "$1" > "$2"
  echo "  wrote $2"
}

[[ $EUID -ne 0 ]] || { echo "Run as your normal user, not root." >&2; exit 1; }
[[ -n "${WSL_DISTRO_NAME:-}" ]] || warn "This doesn't look like WSL; continuing anyway."

say "apt prerequisites"
sudo apt-get update
sudo apt-get install -y build-essential procps curl file git unzip ncurses-term

say "Homebrew"
if [[ ! -x $BREW ]]; then
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  echo "  [skip] already installed"
fi
eval "$($BREW shellenv)"

say "Packages: tmux, sesh, Neovim, Starship, eza, bat, fzf, ripgrep, fd, zoxide, lazygit, btop, yazi, gh"
brew install tmux sesh neovim starship eza bat fzf ripgrep fd zoxide lazygit btop yazi gh

say "AI coding agent: oh-my-pi (omp)"
export PATH="$HOME/.bun/bin:$PATH"
# Ignore a Windows-side omp that leaks in through /mnt/c on the PATH.
OMP_PATH="$(command -v omp || true)"
if [[ -n $OMP_PATH && $OMP_PATH != /mnt/* ]]; then
  echo "  [skip] omp already installed at $OMP_PATH"
else
  brew install oven-sh/bun/bun
  bun install --global @oh-my-pi/pi-coding-agent
  omp --version || warn "omp installed but did not start; check bun --version (needs 1.4.4+)."
fi

say "Starship"
install_config "$SHARED/starship.toml" "$HOME/.config/starship.toml"

say "tmux + Catppuccin"
install_config "$HERE/tmux.conf" "$HOME/.config/tmux/tmux.conf"
CATPPUCCIN_TMUX="$HOME/.config/tmux/plugins/catppuccin/tmux"
if [[ ! -d $CATPPUCCIN_TMUX ]]; then
  git clone --depth 1 --branch v2.1.3 https://github.com/catppuccin/tmux.git "$CATPPUCCIN_TMUX" \
    || git clone --depth 1 https://github.com/catppuccin/tmux.git "$CATPPUCCIN_TMUX"
else
  echo "  [skip] catppuccin/tmux already cloned"
fi

say "Neovim + LazyVim"
if [[ -f $HOME/.config/nvim/lazyvim.json || -f $HOME/.config/nvim/lua/config/lazy.lua ]]; then
  echo "  [skip] LazyVim already set up"
else
  backup "$HOME/.config/nvim"
  backup "$HOME/.local/share/nvim"
  backup "$HOME/.local/state/nvim"
  backup "$HOME/.cache/nvim"
  git clone --depth 1 https://github.com/LazyVim/starter "$HOME/.config/nvim"
  rm -rf "$HOME/.config/nvim/.git"
fi
install_config "$HERE/nvim/lua/plugins/colorscheme.lua" "$HOME/.config/nvim/lua/plugins/colorscheme.lua"
echo "  installing Neovim plugins (first run takes a minute)"
nvim --headless "+Lazy! sync" +qa || warn "LazyVim sync failed; it will retry when you open nvim."

say "btop + Catppuccin"
BTOP_DIR="$HOME/.config/btop"
mkdir -p "$BTOP_DIR/themes"
if [[ -s $BTOP_DIR/themes/catppuccin_mocha.theme ]]; then
  echo "  [skip] Catppuccin Mocha theme already downloaded"
else
  curl -fsSL -o "$BTOP_DIR/themes/catppuccin_mocha.theme" \
    https://raw.githubusercontent.com/catppuccin/btop/1.0.0/themes/catppuccin_mocha.theme \
    && echo "  downloaded catppuccin_mocha.theme" || warn "could not download the btop Catppuccin theme"
fi
# btop rewrites btop.conf on exit and keeps the values it finds, so set just this one line.
if [[ ! -f $BTOP_DIR/btop.conf ]]; then
  printf 'color_theme = "catppuccin_mocha"\n' > "$BTOP_DIR/btop.conf"
  echo "  wrote $BTOP_DIR/btop.conf"
elif grep -qx 'color_theme = "catppuccin_mocha"' "$BTOP_DIR/btop.conf"; then
  echo "  [skip] btop already uses catppuccin_mocha"
else
  cp "$BTOP_DIR/btop.conf" "$BTOP_DIR/btop.conf.bak-$STAMP"
  if grep -q '^color_theme' "$BTOP_DIR/btop.conf"; then
    sed -i 's/^color_theme.*/color_theme = "catppuccin_mocha"/' "$BTOP_DIR/btop.conf"
  else
    printf 'color_theme = "catppuccin_mocha"\n' >> "$BTOP_DIR/btop.conf"
  fi
  echo "  set color_theme in $BTOP_DIR/btop.conf (backup: btop.conf.bak-$STAMP)"
fi

say "yazi + Catppuccin"
if [[ -d $HOME/.config/yazi/flavors/catppuccin-mocha.yazi ]]; then
  echo "  [skip] catppuccin-mocha flavor already installed"
else
  ya pkg add yazi-rs/flavors:catppuccin-mocha || warn "could not add the yazi Catppuccin flavor; re-run later"
fi
install_config "$HERE/yazi/theme.toml" "$HOME/.config/yazi/theme.toml"

say "bash"
install_config "$HERE/bashrc-nitro.sh" "$HOME/.config/bash/nitro.sh"
SOURCE_LINE='[ -f "$HOME/.config/bash/nitro.sh" ] && . "$HOME/.config/bash/nitro.sh"'
if ! grep -qxF "$SOURCE_LINE" "$HOME/.bashrc"; then
  printf '\n# nitro-terminal-setup\n%s\n' "$SOURCE_LINE" >> "$HOME/.bashrc"
  echo "  added source line to ~/.bashrc"
else
  echo "  [skip] ~/.bashrc already sources it"
fi

say "Done"
cat <<'EOF'
Open a new Ubuntu tab (or run: exec bash), then try:
  tmux             start tmux (prefix is Ctrl+a)
  Ctrl+a T         sesh session picker inside tmux
  Alt+s            sesh session picker outside tmux
  nvim             Neovim with LazyVim
  omp              oh-my-pi coding agent (first run asks you to log in / pick a provider)
  Ctrl+a a         omp in a split next to the current pane
  y                yazi file manager (quitting with q leaves you in the folder you were in)
  btop             system monitor (shows the WSL VM, not Windows apps)
  gh auth login    sign the GitHub CLI in once
  z <dir>          jump with zoxide;  Ctrl+r history search;  Ctrl+t file search
EOF
