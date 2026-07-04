# asahi-setup

A single Haskell program that provisions a fresh **Fedora Asahi Remix**
install (Apple Silicon) from bare metal to a fully configured daily
driver: packages, dev toolchains, dotfiles, an alternate Hyprland
session mapped to my old xmonad keybindings, and a handful of
Plasma/system tweaks that aren't exposed anywhere in a GUI.

It's a from-scratch port of `pop-os-setup` (my old Pop!_OS/xmonad
machine's equivalent, a separate repo), not a fork of it: `apt` becomes
`dnf`/COPR, GNOME-only packages are dropped, Debian-specific hardware
packages that don't apply to Apple Silicon (`nvidia-*`, `system76-*`,
Intel VA-API) are removed outright, and Hyprland fills the "alternate
tiling WM alongside the stock DE" role xmonad used to.

## Quick start

```sh
git clone <this repo> asahi-setup && cd asahi-setup
./setup.sh                          # bootstraps GHCup/stack + build deps
stack build
stack exec asahi-setup-exe          # does the actual provisioning
```

`setup.sh` only exists to get a bare machine to the point where it can
compile `app/Main.hs` — installing the C toolchain GHCup needs, then
GHCup itself (GHC + cabal + stack + HLS), then the native libraries
(`zlib-ng-compat-devel`, etc.) this project's own dependencies link
against. Everything else lives in `Main.hs`, which is safe to re-run:
each step checks whether its target is already installed/present before
doing anything.

## What it sets up

- **Language toolchains**: GHCup (GHC/cabal/stack/HLS), rustup, juliaup,
  pyenv, Node 24 (via Fedora's `nodejs24-npm-bin` package), Oh My Zsh +
  a handful of its plugins.
- **Editors**: Emacs built from Fedora's own spec (already
  native-compiled — confirmed rather than assumed), with a generated
  `~/.config/emacs/init.el`; Neovide.
- **Containers/Kubernetes**: Docker CE, kubectl, Helm, kompose, kind,
  k3d, Terraform.
- **Shell environment**: `.zshrc`/`.bashrc`/`.tmux.conf`/etc. deployed
  from this repo, tmux's plugin manager (tpm) installed and its declared
  plugins (`tmux-sensible`, `tmux-powerline`) fetched, and a single
  shared `ssh-agent` cached across shells instead of one per terminal/tmux
  pane.
- **Hyprland**, as an alternate Wayland session alongside the stock KDE
  Plasma one: installed via the `solopasha/hyprland` COPR (with a
  same-machine aquamarine rebuild fallback if the prebuilt package's
  `libdisplay-info` soname doesn't match Fedora's), configured via
  `hypr/hyprland.conf` — a deliberate, keybind-by-keybind mapping of my
  actual `pop-os-setup/.xmonad/xmonad.hs` onto Hyprland's dispatchers
  (master layout, not dwindle), with the gaps documented inline where
  Hyprland has no real equivalent (no Xinerama-style workspace swap
  between monitors, no sub-layout tabbing, etc.). Waybar
  (`waybar/config.jsonc`/`style.css`) and the `tofi` launcher are
  installed and configured alongside it.
- **KDE Plasma tweaks that don't survive a fresh install otherwise**:
  `caps:swapescape,ctrl:ralt_rctrl` set both in `~/.config/kxkbrc` *and*
  system-wide via `localectl set-x11-keymap` (KWin's Wayland session
  actually reads the latter at login, not the former — kxkbrc alone
  silently does nothing here), GTK theming engines so GTK apps don't
  look out of place under Breeze.
- **Browsers/apps**, including the least-bad available option for
  anything without an official aarch64 Linux build yet (Signal, Discord,
  Slack, Spotify — see `Main.hs`'s header comment for exactly what's
  installed for each and why, since none of these are the vendor's own
  official client).
- **Everything else `dnf`/Flathub cover normally**: the usual pile of
  CLI tools, Steam (via the Asahi project's own COPR, since upstream
  Steam is x86_64-only and needs Asahi's box64 wrapper), ProtonVPN
  (official CLI via dnf + official GUI via Flathub, since the dnf GUI
  package is GNOME-only), and so on.

## What it deliberately does NOT automate

A handful of things have no clean automation path and are left as manual
steps, documented at the top of `app/Main.hs`:

- Miniconda3 (same reason as upstream: no non-interactive installer)
- rkhunter (interactive TUI setup wizard)
- The Mirage Matrix client (manual Flatpak download)
- i2p (interactive Java GUI installer)
- Full desktop theming beyond installing the GTK-under-Breeze engines
- `tlp`/`tlp-rdw` (hard-conflicts with Fedora's default `tuned`/`tuned-ppd`
  power daemon — swapping them is a real behavior change this script
  won't make unasked; the exact commands are in `Main.hs` if you want
  that instead)
- Session and Nyxt (no package, no comparably-vetted alternative found)

## Repo layout

```
app/Main.hs          the entire installer/configurator
setup.sh             bare-metal bootstrap (GHCup + build deps only)
.zshrc, .bashrc, .tmux.conf, .gitconfig, ...   dotfiles, deployed verbatim
hypr/hyprland.conf   Hyprland config (xmonad-mapped keybinds)
waybar/              Waybar config + stylesheet
plasma/kxkbrc        KDE keyboard-remap config
emacs/init.el        Emacs config, deployed to ~/.config/emacs/
librespot/           systemd user unit for librespot (Spotify Connect receiver)
```

## License

BSD-3-Clause — see `LICENSE`.
