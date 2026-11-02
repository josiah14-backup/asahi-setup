#!/usr/bin/env elvish

use re
use str

fn step {|message|
  echo
  echo '==> '$message
}

fn checked-version {|label value|
  if (not (re:match '^v?[0-9]+([.][0-9]+)+([-+][0-9A-Za-z.-]+)?$' $value)) {
    fail 'Invalid '$label' version from upstream: '$value
  }
  put $value
}

fn assert-version {|label want got|
  if (not-eq $want $got) {
    fail $label' update failed: expected '$want', got '$got
  }
}

fn main {
  step 'Caching sudo credentials'
  sudo -v

  step 'Updating Rust'
  ~/.cargo/bin/rustup update stable

  step 'Updating global npm tools'
  sudo npm install -g @bitwarden/cli@latest bash-language-server@latest fish-lsp@latest opencode-ai@latest pyright@latest

  step 'Updating Cargo tools'
  var spotify-latest = (checked-version spotify_player (curl -A asahi-setup-updater -fsSL https://crates.io/api/v1/crates/spotify_player | jq -r '.crate.max_stable_version'))
  var spotify-current = (spotify_player --version | awk '{print $2}')

  if (not-eq $spotify-current $spotify-latest) {
    ~/.cargo/bin/cargo install spotify_player --version $spotify-latest --locked --force
    assert-version spotify_player $spotify-latest (spotify_player --version | awk '{print $2}')
  } else {
    echo 'spotify_player is current at '$spotify-current
  }


  var rtk-tag = (checked-version rtk (curl -A asahi-setup-updater -fsSL https://api.github.com/repos/rtk-ai/rtk/releases/latest | jq -r .tag_name))
  var rtk-latest = (echo $rtk-tag | sed 's/^v//')
  var rtk-current = (rtk --version | awk '{print $2}')

  if (not-eq $rtk-current $rtk-latest) {
    ~/.cargo/bin/cargo install --git https://github.com/rtk-ai/rtk --tag $rtk-tag --locked --force rtk
    assert-version rtk $rtk-latest (rtk --version | awk '{print $2}')
  } else {
    echo 'rtk is current at '$rtk-current
  }


  step 'Updating the Nix profile and Racket packages'
  nix profile upgrade --all
  raco pkg update --auto racket-langserver

  step 'Updating pyenv and Aider’s Python'
  git -C ~/.pyenv pull --ff-only
  var aider-python = (checked-version Python (curl -A asahi-setup-updater -fsSL https://www.python.org/ftp/python/ | sed -n 's/.*href="\(3\.12\.[0-9][0-9]*\)\/".*/\1/p' | sort -V | tail -1))
  ~/.pyenv/bin/pyenv install -s $aider-python
  var aider-python-path = ~/.pyenv/versions/$aider-python/bin/python
  var current-aider-python = (pipx list --json | jq -r '.venvs["aider-chat"].metadata.source_interpreter.__Path__ // ""')
  if (not-eq $current-aider-python $aider-python-path) {
    pipx reinstall --python $aider-python-path aider-chat
  } else {
    echo 'Aider already uses Python '$aider-python
  }

  step 'Updating Headroom and its OpenCode plugin'
  var headroom-latest = (checked-version Headroom (curl -A asahi-setup-updater -fsSL https://pypi.org/pypi/headroom-ai/json | jq -r .info.version))
  var headroom-current = (pipx list --json | jq -r '.venvs["headroom-ai"].metadata.main_package.package_version // ""')

  if (not-eq $headroom-current $headroom-latest) {
    git -C ~/.local/share/headroom-src fetch --tags origin
    git -C ~/.local/share/headroom-src checkout --detach v$headroom-latest
    npm --prefix ~/.local/share/headroom-src/plugins/opencode install
    npm --prefix ~/.local/share/headroom-src/plugins/opencode run build
    pipx install --force 'headroom-ai[proxy,code,html,reports,spreadsheet,otel]=='$headroom-latest
    assert-version Headroom $headroom-latest (pipx list --json | jq -r '.venvs["headroom-ai"].metadata.main_package.package_version')
  } else {
    echo 'Headroom is current at '$headroom-current
  }

  headroom install apply --providers manual --target codex --target opencode --scope provider


  step 'Updating shell and tmux Git checkouts'
  git -C ~/.oh-my-zsh pull --ff-only
  git -C ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting pull --ff-only
  git -C ~/.tmux/plugins/tmux-powerline remote set-url origin https://github.com/erikw/tmux-powerline.git
  git -C ~/.tmux/plugins/tmux-powerline pull --ff-only

  step 'Updating Doom Emacs'
  ~/.config/emacs/bin/doom upgrade --aot --force

  step 'Updating Neovim plugins and its tracked lockfile'
  nvim --headless '+Lazy! sync' +qa
  cp ~/.config/nvim/lazy-lock.json ~/Development/personal/asahi-setup/nvim/lazy-lock.json

  step 'Updating Mason tools except zls'
  # zls must remain aligned with Fedora's Zig; Zig and zls are both 0.16.0 now.
  var mason-packages = [
    bash-language-server codelldb fish-lsp json-lsp lua-language-server
    nil pyright ruff rust-analyzer shellcheck shfmt statix stylua taplo
  ]
  var mason-updates = []
  for package $mason-packages {
    var receipt = ~/.local/share/nvim/mason/packages/$package/mason-receipt.json
    var current = (jq -r '.source.id // ""' $receipt)
    var latest = (curl -A asahi-setup-updater -fsSL https://raw.githubusercontent.com/mason-org/mason-registry/main/packages/$package/package.yaml | sed -n '0,/^  id: /s/^  id: //p')
    if (eq $latest '') {
      fail 'Could not determine the current Mason source for '$package
    }
    if (not-eq $current $latest) {
      set mason-updates = [(all $mason-updates) $package]
    }
  }
  if (> (count $mason-updates) 0) {
    var mason-command = 'MasonInstall --force '(str:join ' ' $mason-updates)
    nvim --headless -c $mason-command -c qall
  } else {
    echo 'Mason tools are current; zls intentionally remains untouched'
  }

  step 'Updating standalone Kind and Slacky installs'
  var kind-tag = (checked-version Kind (curl -A asahi-setup-updater -fsSL https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | jq -r .tag_name))
  var slacky-tag = (checked-version Slacky (curl -A asahi-setup-updater -fsSL https://api.github.com/repos/andirsun/Slacky/releases/latest | jq -r .tag_name))
  var slacky-version = (echo $slacky-tag | sed 's/^v//')
  var temp-dir = (mktemp -d /tmp/update-asahi-tools.XXXXXX)

  var kind-current = (kind version | awk '{print $2}')
  if (not-eq $kind-current $kind-tag) {
    curl -A asahi-setup-updater -fL https://github.com/kubernetes-sigs/kind/releases/download/$kind-tag/kind-linux-arm64 -o $temp-dir/kind
    sudo install -m 0755 $temp-dir/kind /usr/local/bin/kind
    assert-version Kind $kind-tag (kind version | awk '{print $2}')
  } else {
    echo 'Kind is current at '$kind-current
  }

  var slacky-current = (rpm -q --qf '%{VERSION}' slacky)
  if (not-eq $slacky-current $slacky-version) {
    var slacky-rpm = slacky-$slacky-version.aarch64.rpm
    curl -A asahi-setup-updater -fL https://github.com/andirsun/Slacky/releases/download/$slacky-tag/$slacky-rpm -o $temp-dir/$slacky-rpm
    sudo dnf install -y $temp-dir/$slacky-rpm
    assert-version Slacky $slacky-version (rpm -q --qf '%{VERSION}' slacky)
  } else {
    echo 'Slacky is current at '$slacky-current
  }
  rm -r $temp-dir

  echo
  echo 'Updates complete.'
  echo 'Skipped intentionally: Emacs 31, Nerd Fonts, Julia installation, and zls.'
  echo 'Repository version pins and stack.yaml are not rewritten automatically.'
}

main
