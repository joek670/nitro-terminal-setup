# Nitro terminal setup - sourced from ~/.bashrc (~/.config/bash/nitro.sh)

[ -x /home/linuxbrew/.linuxbrew/bin/brew ] && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# Bun global installs (oh-my-pi: omp)
export PATH="$HOME/.bun/bin:$PATH"

export EDITOR=nvim
export VISUAL=nvim
export BAT_THEME="Catppuccin Mocha"

# fzf: fd for file lists, Catppuccin Mocha colours, bat previews for Ctrl+t
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:200 {}'"
export FZF_DEFAULT_OPTS=" \
--height=40% --layout=reverse --border \
--color=bg+:#313244,spinner:#F5E0DC,hl:#F38BA8 \
--color=fg:#CDD6F4,header:#F38BA8,info:#CBA6F7,pointer:#F5E0DC \
--color=marker:#B4BEFE,fg+:#CDD6F4,prompt:#CBA6F7,hl+:#F38BA8 \
--color=selected-bg:#45475A,border:#6C7086,label:#CDD6F4"

# History: bigger, shared across tmux panes
HISTSIZE=50000
HISTFILESIZE=100000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend
PROMPT_COMMAND="history -a${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

# Modern replacements
alias ls='eza --icons --group-directories-first'
alias ll='eza -la --icons --git --group-directories-first'
alias lt='eza --tree --level=2 --icons'
alias cat='bat --paging=never'
alias vim='nvim'
alias lg='lazygit'

# sesh picker outside tmux: Alt+s
sesh-pick() {
  local session
  session=$(sesh list --icons | fzf --ansi --no-sort --border-label ' sesh ' --prompt '> ') || return
  sesh connect "$session"
}
[[ $- == *i* ]] && bind -x '"\es": sesh-pick'

# Shell integrations; keep Starship last
command -v fzf >/dev/null && eval "$(fzf --bash)"
command -v zoxide >/dev/null && eval "$(zoxide init bash)"
command -v starship >/dev/null && eval "$(starship init bash)"
