# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH=/home/josiah/.oh-my-zsh

# Set name of the theme to load. Optionally, if you set this to "random"
# it'll load a random theme each time that oh-my-zsh is loaded.
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
ZSH_THEME="avit"

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion. Case
# sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

export EDITOR=vim

export FULLNAME="Josiah Berkebile"

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git fasd python history-substring-search colored-man-pages colorize command-not-found globalias common-aliases compleat vi-mode zsh-navigation-tools zsh-autosuggestions zsh-syntax-highlighting nix-zsh-completions nix-shell)

# zsh-autosuggestions' own default (fg=8, bright black) is invisible
# under Solarized Dark: bright0 (ANSI color 8) is set to the same value
# as the terminal background (002b36) in both konsole/SolarizedDark.colorscheme
# and foot/foot.ini -- that's Solarized's own convention for "blend
# with background", not a mistake, but it means anything relying on
# color 8 for visible-but-subtle text needs a different color instead.
# fg=10 is bright2 (base01, 586e75) -- Solarized's own "secondary
# content" color, muted but clearly visible against the background.
export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=10'

source $ZSH/oh-my-zsh.sh

prompt_nix_shell_setup

bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# ssh
# export SSH_KEY_PATH="~/.ssh/rsa_id"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
#

export LIBRARY_PATH="/usr/lib/gcc/x86_64-linux-gnu/9"
export RUST_SRC_PATH=$HOME/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/lib/rustlib/src/rust/library
export PYENV_ROOT="$HOME/.pyenv"

# typeset -U path deduplicates $path (zsh's array mirror of $PATH) on every
# source, so re-sourcing this file never appends duplicate entries.
typeset -U path
path=(
  $HOME/.local/bin
  $HOME/.rd/bin
  $HOME/.cargo/bin
  $HOME/.poetry/bin
  $PYENV_ROOT/bin
  $HOME/miniconda3/bin
  $HOME/.local/app-img
  $HOME/.radicle/bin
  $HOME/.rvm/bin
  $HOME/.krew/bin
  $HOME/.local/share/coursier/bin
  $HOME/.conscript/bin
  $HOME/.nix-profile/bin
  $HOME/.nix-profile/sbin
  $HOME/.cabal/bin
  $HOME/programs/intellij/bin
  /usr/lib/jvm/java-8-oracle/bin
  /usr/lib/jvm/java-8-oracle/db/bin
  /usr/lib/jvm/java-8-oracle/jre/bin
  /usr/lib/jvm/java-8-openjdk-amd64/bin
  /usr/share/maven/bin
  $HOME/.local/share/racket/8.2/bin
  /usr/local/sbin
  /usr/local/bin
  /usr/sbin
  /usr/bin
  /sbin
  /bin
  /usr/games
  /usr/local/games
  /snap/bin
  $path
)

set -o vi

alias j='z'
alias jj='zz'
alias zshrc='v ~/.zshrc'
alias lpgp="lpass show --password -c"
alias screeps-dir=$HOME/.config/Screeps/scripts/screeps.com/tutorial-1
alias ipyvi="ipython --TerminalInteractiveShell.editing_mode=vi"

export HISTCONTROL=ignoreboth

# FaradAI settings
export FARADAI_MEMORY=16g
export FARADAI_CPUS=8
export FARADAI_PIDS=1024
export FARADAI_TRUST_SSH_AGENT=1
export FARADAI_MOUNT_NIX_STORE=1

. $HOME/miniconda3/etc/profile.d/conda.sh
eval "$(pyenv init -)"
eval $(thefuck --alias)
source <(kompose completion zsh)

if [ -e $HOME/.nix-profile/etc/profile.d/nix.sh ]; then
  . $HOME/.nix-profile/etc/profile.d/nix.sh
fi

if [ -e $HOME/.guix-profile/etc/profile ]; then
  GUIX_PROFILE="$HOME/.guix-profile"
  . "$GUIX_PROFILE/etc/profile"
  unset GUIX_PROFILE
fi

# oh-my-zsh's compinit runs with -i (ignore insecure directories) by default --
# confirmed directly against lib/compfix.zsh/oh-my-zsh.sh: this already
# silently skips loading completions only from flagged paths, leaving
# everything else intact; the printed warning changes nothing on its own.
# /usr/share/zsh/site-functions/_guix (a symlink into Guix's own profile,
# owned by the guix-daemon system account -- not root, not this user, which
# is exactly what the check flags, regardless of permission bits) gets
# skipped as a result. Loading it manually here, after compinit has already
# run, sidesteps that one audit gate entirely -- confirmed live -- without
# touching ZSH_DISABLE_COMPFIX, which would trade this one skipped file for
# loading *every* insecure completion unconditionally instead.
if [ -e /var/guix/profiles/per-user/root/current-guix/share/zsh/site-functions/_guix ]; then
  fpath+=(/var/guix/profiles/per-user/root/current-guix/share/zsh/site-functions)
  autoload -Uz _guix
  compdef _guix guix
fi

# Mirrors what guix-install.sh's own bash prompt customization already
# added to .bashrc (a "[env]" suffix while inside a live `guix shell`) --
# zsh wasn't touched by that installer, so this adds the equivalent here.
# This only needs to run once at .zshrc load time, not on every prompt
# render: `guix shell` spawns a fresh sub-shell that re-sources .zshrc,
# the same reason the .bashrc version works as a one-time check too.
# Appended to RPROMPT rather than hacking the left PROMPT string --
# avit (this theme) already builds RPROMPT up from contextual segments
# (git status, vi-mode), so this fits the same pattern instead of a
# one-off insertion. Swap "(guix-shell)" for "(guix)" below if you'd
# rather have the shorter form.
if [ -n "$GUIX_ENVIRONMENT" ]; then
  RPROMPT="%{$fg[green]%}(guix-shell)%{$reset_color%} ${RPROMPT}"
fi

# The next line updates PATH for the Google Cloud SDK.
if [ -f "$HOME/Downloads/google-cloud-sdk/path.zsh.inc" ]; then
  . "$HOME/Downloads/google-cloud-sdk/path.zsh.inc"
fi

# The next line enables shell command completion for gcloud.
if [ -f "$HOME/Downloads/google-cloud-sdk/completion.zsh.inc" ]; then
  . "$HOME/Downloads/google-cloud-sdk/completion.zsh.inc"
fi

### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
export PATH="/home/josiah/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)

# Checking $SSH_AUTH_SOCK alone respawns a new ssh-agent in every tmux
# pane: panes are spawned fresh by the tmux server, not as children of
# whatever pane last exported it, so each new pane sees it unset. Cache
# the agent's env in a file and only start a new one if the cached PID
# isn't actually a live ssh-agent process, so every shell/pane reuses the
# same agent instead.
SSH_ENV="$HOME/.ssh/agent-environment"
[ -f "$SSH_ENV" ] && . "$SSH_ENV" > /dev/null
if [ -z "$SSH_AGENT_PID" ] || ! ps -p "$SSH_AGENT_PID" -o comm= 2>/dev/null | grep -q '^ssh-agent$'; then
  ssh-agent -s | sed '/^echo /d' > "$SSH_ENV"
  chmod 600 "$SSH_ENV"
  . "$SSH_ENV" > /dev/null
fi

[ -f "/home/josiah/.ghcup/env" ] && . "/home/josiah/.ghcup/env" # ghcup-env