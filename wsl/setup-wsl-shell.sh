#!/usr/bin/env bash
set -Eeuo pipefail

# Ubuntu WSL shell bootstrap
# Installs and configures:
# - zsh
# - fzf
# - ripgrep
# - fd (via fd-find)
# - bat (via bat package)
# - zsh-autosuggestions
# - zsh-syntax-highlighting
# - Starship prompt
# - useful aliases/history/completion
# - SDKMAN integration if already installed
# - Rust/Cargo integration if already installed
#
# Run this script as your normal user, NOT with sudo.

readonly MARKER_START="# >>> wsl-dev managed block >>>"
readonly MARKER_END="# <<< wsl-dev managed block <<<"

log() {
  printf '\n\033[1;34m[INFO]\033[0m %s\n' "$*"
}

ok() {
  printf '\033[1;32m[ OK ]\033[0m %s\n' "$*"
}

warn() {
  printf '\033[1;33m[WARN]\033[0m %s\n' "$*"
}

die() {
  printf '\033[1;31m[FAIL]\033[0m %s\n' "$*" >&2
  exit 1
}

if [[ "${EUID}" -eq 0 ]]; then
  die "Do not run this script with sudo. Run it as your normal WSL user."
fi

if [[ ! -r /etc/os-release ]]; then
  die "/etc/os-release was not found."
fi

# shellcheck disable=SC1091
source /etc/os-release

if [[ "${ID:-}" != "ubuntu" ]]; then
  warn "This script is designed for Ubuntu. Detected: ${PRETTY_NAME:-unknown}"
fi

if ! grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
  warn "WSL was not detected. The script can still run, but it is intended for Ubuntu on WSL."
fi

log "Installing terminal and development utilities"

sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt install -y \
  zsh \
  git \
  curl \
  wget \
  ca-certificates \
  unzip \
  zip \
  build-essential \
  fzf \
  ripgrep \
  fd-find \
  bat \
  tree \
  htop \
  jq \
  less \
  nano \
  zsh-autosuggestions \
  zsh-syntax-highlighting

mkdir -p "$HOME/.local/bin" "$HOME/projects" "$HOME/.config"

# Ubuntu/Debian use fdfind and batcat as the executable names.
if command -v fdfind >/dev/null 2>&1; then
  ln -sfn "$(command -v fdfind)" "$HOME/.local/bin/fd"
fi

if command -v batcat >/dev/null 2>&1; then
  ln -sfn "$(command -v batcat)" "$HOME/.local/bin/bat"
fi

log "Installing Starship into ~/.local/bin"

if [[ ! -x "$HOME/.local/bin/starship" ]]; then
  curl -sS https://starship.rs/install.sh \
    | sh -s -- -y -b "$HOME/.local/bin"
else
  ok "Starship is already installed."
fi

ZSHRC="$HOME/.zshrc"

if [[ -f "$ZSHRC" ]]; then
  backup="$HOME/.zshrc.backup.$(date +%Y%m%d-%H%M%S)"
  cp "$ZSHRC" "$backup"
  ok "Existing .zshrc backed up to: $backup"
else
  touch "$ZSHRC"
fi

log "Updating managed block in ~/.zshrc"

tmp_file="$(mktemp)"
awk -v start="$MARKER_START" -v end="$MARKER_END" '
  $0 == start { skipping=1; next }
  $0 == end   { skipping=0; next }
  !skipping   { print }
' "$ZSHRC" > "$tmp_file"

cat >> "$tmp_file" <<'ZSHRC_BLOCK'

# >>> wsl-dev managed block >>>

# ---------------------------------------------------------------------------
# PATH
# ---------------------------------------------------------------------------
export PATH="$HOME/.local/bin:$PATH"

# ---------------------------------------------------------------------------
# Editor
# ---------------------------------------------------------------------------
if command -v nvim >/dev/null 2>&1; then
  export EDITOR=nvim
  export VISUAL=nvim
else
  export EDITOR=nano
  export VISUAL=nano
fi

# ---------------------------------------------------------------------------
# History
# ---------------------------------------------------------------------------
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000

setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY

# ---------------------------------------------------------------------------
# Completion
# ---------------------------------------------------------------------------
autoload -Uz compinit
compinit

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

setopt AUTO_MENU
setopt COMPLETE_IN_WORD

# ---------------------------------------------------------------------------
# Navigation/options
# ---------------------------------------------------------------------------
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt INTERACTIVE_COMMENTS

# ---------------------------------------------------------------------------
# Key bindings
# ---------------------------------------------------------------------------
bindkey -e

bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' forward-word

bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char

autoload -Uz up-line-or-beginning-search
autoload -Uz down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search

bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search

# ---------------------------------------------------------------------------
# fzf
# ---------------------------------------------------------------------------
for fzf_keys in \
  /usr/share/doc/fzf/examples/key-bindings.zsh \
  /usr/share/fzf/key-bindings.zsh
do
  [[ -f "$fzf_keys" ]] && source "$fzf_keys" && break
done

for fzf_completion in \
  /usr/share/doc/fzf/examples/completion.zsh \
  /usr/share/fzf/completion.zsh
do
  [[ -f "$fzf_completion" ]] && source "$fzf_completion" && break
done

if command -v fd >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
fi

export FZF_DEFAULT_OPTS='
  --height=45%
  --layout=reverse
  --border
  --info=inline
'

export FZF_CTRL_T_OPTS="
  --preview 'bat --color=always --style=numbers --line-range=:500 {} 2>/dev/null'
"

export FZF_ALT_C_OPTS="
  --preview 'tree -C {} | head -200'
"

# ---------------------------------------------------------------------------
# Aliases
# ---------------------------------------------------------------------------
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

alias home='cd ~'
alias proj='cd ~/projects'

alias c='clear'

alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'

alias grep='grep --color=auto'
alias tree='tree -C'

alias g='git'
alias gs='git status'
alias ga='git add'
alias gaa='git add --all'
alias gc='git commit'
alias gcm='git commit -m'
alias gp='git push'
alias gpl='git pull'
alias gb='git branch'
alias gco='git checkout'
alias gsw='git switch'
alias gd='git diff'
alias gl='git log --oneline --graph --decorate --all'

alias ports='ss -tulpn'
alias df='df -h'
alias du='du -h'
alias reload='source ~/.zshrc'

zshrc() {
  "${EDITOR:-nano}" "$HOME/.zshrc"
}

# ---------------------------------------------------------------------------
# SDKMAN - loaded only when already installed
# ---------------------------------------------------------------------------
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"

# ---------------------------------------------------------------------------
# Rust - loaded only when rustup/cargo already exists
# ---------------------------------------------------------------------------
[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

# ---------------------------------------------------------------------------
# Zsh plugins installed from Ubuntu packages
# Syntax highlighting should stay near the end of .zshrc.
# ---------------------------------------------------------------------------
[[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] \
  && source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh

[[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] \
  && source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# ---------------------------------------------------------------------------
# Starship prompt
# ---------------------------------------------------------------------------
command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"

# <<< wsl-dev managed block <<<
ZSHRC_BLOCK

mv "$tmp_file" "$ZSHRC"

STARSHIP_CONFIG="$HOME/.config/starship.toml"

if [[ ! -f "$STARSHIP_CONFIG" ]]; then
  log "Creating Starship config"

  cat > "$STARSHIP_CONFIG" <<'STARSHIP'
add_newline = false

format = """
$directory\
$git_branch\
$git_status\
$java\
$nodejs\
$rust\
$docker_context\
$cmd_duration\
$line_break\
$character"""

[directory]
style = "bold blue"
truncation_length = 4
truncate_to_repo = false

[git_branch]
symbol = " "
style = "bold purple"

[git_status]
style = "bold red"

[java]
symbol = " "
style = "red"

[nodejs]
symbol = " "
style = "green"

[rust]
symbol = " "
style = "red"

[docker_context]
symbol = " "
style = "blue"

[cmd_duration]
min_time = 1000
format = " took [$duration](bold yellow)"

[character]
success_symbol = "[❯](bold green)"
error_symbol = "[❯](bold red)"
STARSHIP

else
  ok "Existing Starship config preserved: $STARSHIP_CONFIG"
fi

ZSH_PATH="$(command -v zsh)"

if [[ "${SHELL:-}" != "$ZSH_PATH" ]]; then
  log "Changing default shell to zsh"
  chsh -s "$ZSH_PATH"
else
  ok "zsh is already the default shell."
fi

log "Verifying installed tools"

printf '\n'
printf '  zsh      : %s\n' "$(zsh --version 2>/dev/null || echo missing)"
printf '  git      : %s\n' "$(git --version 2>/dev/null || echo missing)"
printf '  fzf      : %s\n' "$(fzf --version 2>/dev/null || echo missing)"
printf '  rg       : %s\n' "$(rg --version 2>/dev/null | head -1 || echo missing)"
printf '  fd       : %s\n' "$("$HOME/.local/bin/fd" --version 2>/dev/null || echo missing)"
printf '  bat      : %s\n' "$("$HOME/.local/bin/bat" --version 2>/dev/null || echo missing)"
printf '  starship : %s\n' "$("$HOME/.local/bin/starship" --version 2>/dev/null | head -1 || echo missing)"

cat <<'DONE'

Setup complete.

Useful shortcuts after opening a new zsh session:
  Ctrl+R     Search command history with fzf
  Ctrl+T     Find files with fzf
  Alt+C      Find directories with fzf
  Up/Down    Search history using the current command prefix

Useful commands:
  proj       cd ~/projects
  gs         git status
  gl         compact Git graph
  ports      show listening ports
  reload     reload ~/.zshrc
  zshrc      edit ~/.zshrc

If this is WSL, either:
  1. close the current terminal and open it again, or
  2. from Windows run: wsl --shutdown

Then open WezTerm/WSL again.

Note:
  Starship icons expect a Nerd Font in your Windows terminal (for example
  JetBrainsMono Nerd Font configured in WezTerm).
DONE
