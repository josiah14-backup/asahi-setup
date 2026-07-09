-- Fedora Asahi Remix (KDE Plasma) equivalent of pop-os-setup/app/Main.hs,
-- ported from apt to dnf. GNOME-only packages are skipped; where a genuine
-- Plasma equivalent exists it is substituted instead. Hardware-specific
-- Debian packages that don't apply to Apple Silicon (nvidia-*, system76-*,
-- Intel VA-API drivers) are dropped outright rather than translated.
--
-- Things this script does NOT automate, and why:
--
-- Miniconda3 still can't be automated, for the same reason as upstream:
-- https://docs.conda.io/en/latest/miniconda.html#linux-installers
-- On aarch64, grab the "Linux ARM64 (aarch64)" installer -- Anaconda's own
-- naming for it varies, but it's the same one AWS Graviton2 users install
-- (confirmed working on this exact machine).
--
-- rkhunter's installer is an interactive TUI wizard, so (as upstream)
-- install it by hand if you want it: `sudo dnf install -y rkhunter`, then
-- follow the prompts.
--
-- installHaskellToolchain's ghcup bootstrap (BOOTSTRAP_HASKELL_INSTALL_HLS=1)
-- fetches ghcup's precompiled aarch64 HLS binary, which was confirmed live
-- on this exact machine to crash on startup with "GHC ABIs don't match!" --
-- ghcup's aarch64 HLS bindist for 2.14.0.0 was built in ghcup's own CI
-- against a GHC 9.10.3 snapshot with different exact library hashes than
-- the GHC 9.10.3 ghcup separately installs locally, despite matching
-- version numbers (a known class of gotcha on the newer, less mature
-- aarch64 Haskell toolchain, consistent with other ARM64-specific issues
-- already hit throughout this file). The real fix, confirmed to actually
-- resolve it, is building HLS from source against the exact local GHC:
-- `ghcup compile hls --version 2.14.0.0 --ghc 9.10.3` -- but that's a
-- genuine 20-40+ minute compile, a poor fit for baking unconditionally
-- into every provisioning run (including machines where the prebuilt
-- binary works fine, e.g. x86_64), and it may simply be fixed upstream by
-- the time ghcup ships a later HLS/GHC pairing. Run that command by hand
-- if `lsp-haskell`/Doom's `(haskell +lsp)` crashes with the same error.
--
-- widevine-installer (the dnf package, installed below) only lays down
-- the dnf/Firefox/Chromium config plumbing -- the actual Widevine CDM
-- binary (needed for DRM-gated content like Spotify's/Netflix's web
-- players to play at all) is fetched and adapted from a ChromeOS image
-- by a separate `sudo widevine-installer` run, which is deliberately
-- interactive (prompts twice: once for you to read the proprietary
-- license, once after showing the exact CDM version about to be
-- installed) and not something this script pipes answers into on your
-- behalf. Run it by hand once after provisioning; a browser restart
-- (not a full re-login) is enough afterward for Firefox/Chromium to
-- pick it up.
--
-- The Mirage Matrix client still requires a manual download:
-- https://github.com/mirukana/mirage/blob/master/docs/INSTALL.md#flatpak
--
-- System theming is still out of scope beyond installing the Plasma-side
-- GTK theming engines (breeze-gtk, kde-gtk-config, Kvantum) so GTK apps
-- don't look totally out of place under Breeze -- curating an actual theme
-- is still left to you.
--
-- Rancher Desktop has no Linux ARM64 build at all (x86_64/AMD-V only), so
-- it's dropped rather than translated. Docker CE + kubectl + kind + helm +
-- kompose below cover the same container/Kubernetes workflow natively on
-- aarch64, so nothing is lost. The GPG/pass/sysctl steps upstream needed
-- purely for Rancher Desktop's rootless port-80 binding are gone too.
--
-- ProtonVPN's official GUI app is GNOME-only by its own dnf packaging
-- (the Fedora package is literally named proton-vpn-gnome-desktop), so
-- this installs the official ProtonVPN CLI via dnf instead (package
-- proton-vpn-cli), which is a first-party, desktop-agnostic replacement.
-- The official GUI app is ALSO installed separately via Flathub
-- (com.protonvpn.www, a genuine aarch64 build with no GNOME-specific
-- packaging constraint), so you get both the CLI and the GUI.
--
-- Ice SSB (peppermintos/ice) only ships Debian packaging (a debian/
-- directory built with debuild); there's no Fedora/RPM build path and the
-- project has no other build system. It's a plain Python 3 + GTK3 script
-- with no compiled artifacts, so this installs its files directly to the
-- same paths the .deb would have used, instead of faking a debuild.
--
-- Steam only works on this hardware via the Asahi project's own COPR,
-- which wraps the (still x86_64-only) upstream Steam client with box64
-- for translation. Fedora Asahi Remix already enables that COPR by
-- default. A Flathub Steam install would NOT work here: Flathub only
-- publishes an x86_64 build with no such translation layer.
--
-- As of this writing (mid-2026), none of Signal, Discord, Slack, Zoom, or
-- Spotify have an official aarch64 Linux build via dnf OR Flathub. Rather
-- than skip them outright, this installs the least-bad available
-- alternative for each (all explicitly chosen, not silently picked):
--   * Signal: no aarch64 build on Flathub yet either (upstream Electron
--     only just landed aarch64 support in v8.15), so this adds
--     signalflatpak.github.io -- a third-party (NOT Flathub, NOT
--     Signal's own infra) Flatpak remote that publishes precompiled
--     aarch64 builds -- and installs org.signal.Signal from it. You are
--     trusting that remote's own signing key.
--   * Discord: installed via so.libdb.dissent (Dissent), a real Flathub
--     app with a genuine aarch64 build. It's a from-scratch Go/GTK4
--     reimplementation, not the official client: text chat only (no
--     voice/video), and its own README warns that using an unofficial
--     client risks an account ban under Discord's ToS.
--   * Slack: no dnf/Flathub package; installed from the aarch64 RPM
--     andirsun/Slacky publishes directly on GitHub -- an Electron wrapper
--     around Slack's own web client rather than a reimplemented private
--     protocol, so likely lower ToS risk than Dissent, but still an
--     early-stage (v0.0.10), unofficial, third-party project.
--   * Spotify: no Linux ARM64 client exists at all, official or
--     otherwise. Installed via cargo: librespot (a mature, actively
--     maintained open-source Spotify Connect implementation) as the
--     actual audio receiver in credential-free "zeroconf" mode -- you
--     "Connect to a device" from Spotify's own app elsewhere and pick
--     "Librespot (Asahi)" from the list, so this script never handles
--     your Spotify password -- plus spotify_player, a Rust TUI you can
--     separately log into (official Web API OAuth) for local
--     browsing/search and Connect-device control.
--   * Zoom: still just the official web/PWA client (Zoom's own
--     documented recommendation for ARM Linux), since there's no
--     automatable install step for "click Install App in your browser."
--
-- Session and Nyxt are still skipped outright: no dnf/Flathub package,
-- and no comparably-vetted alternative turned up for either.
--
-- i2p has no Fedora package, and upstream only ships an interactive Java
-- GUI installer, so install it by hand from https://geti2p.net if wanted.
--
-- tlp/tlp-rdw aren't installed either: they hard-conflict with Fedora's
-- default tuned/tuned-ppd power daemon, so installing them means
-- removing tuned first -- a real power-management behavior change this
-- script isn't making unasked. See the comment right after `dnfInstall
-- "steam"` in `main` for the exact commands if you want tlp instead of
-- tuned.
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE LambdaCase #-}

module Main where

import qualified Data.Foldable as F (fold)
import Data.Maybe (fromMaybe)
import Data.Text (isInfixOf, pack, replace, strip, unpack)
import Turtle
import Turtle.Format (format, fp)
import Turtle.Line (textToLine, textToLines)

echoText :: Text -> IO ()
echoText text = fmap F.fold $ mapM echo $ textToLines text

echoWhichLocation :: Turtle.FilePath -> Text -> Line -> IO ()
echoWhichLocation loc prefixText errorText =
  echo $ fromMaybe errorText $ textToLine (prefixText <> format fp loc)

-- | dnf's answer to the original's `aptInstall`: skip installing if the
-- binary is already on PATH, otherwise `sudo dnf install -y`.
dnfInstall :: Turtle.FilePath -> Text -> Text -> Line -> IO ()
dnfInstall binName packageName foundPrefix foundErrText =
  which binName
    >>= \case
      Nothing ->
        shell ("sudo dnf install -y " <> packageName) empty
          >>= \case
            ExitSuccess -> return ()
            ExitFailure _ ->
              die ("ERROR: Could not install " <> pack binName)
      Just loc -> echoWhichLocation loc foundPrefix foundErrText

-- | npm's answer to dnfInstall: skip installing if the binary is already
-- on PATH, otherwise `sudo npm install -g`. Used for CLI tools with no
-- Fedora package and no Flathub app; npm itself is expected to already be
-- installed by the time any of these run.
npmInstall :: Turtle.FilePath -> Text -> Text -> Line -> IO ()
npmInstall binName packageName foundPrefix foundErrText =
  which binName
    >>= \case
      Just loc -> echoWhichLocation loc foundPrefix foundErrText
      Nothing -> shells ("sudo npm install -g " <> packageName) empty

flatpakInstall :: Text -> IO ()
flatpakInstall applicationId =
  shellStrictWithErr ("flatpak info " <> applicationId) empty
    >>= \case
      (ExitSuccess, stdOutText, stdErrText) ->
        echoText (stdOutText <> stdErrText)
      (ExitFailure _, stdOutText, stdErrText) ->
        shell ("flatpak install --user -y " <> applicationId) empty
          >>= \case
            ExitSuccess -> echoText (stdOutText <> stdErrText)
            ExitFailure _ ->
              echoText (stdOutText <> stdErrText)
                >> die ("ERROR: Could not install " <> applicationId)

-- | Same as flatpakInstall, but from an explicitly named remote rather
-- than whichever remote flatpak resolves it from automatically -- for
-- apps (like Signal, below) that only exist on a non-Flathub remote.
flatpakInstallFromRemote :: Text -> Text -> IO ()
flatpakInstallFromRemote remoteName applicationId =
  shellStrictWithErr ("flatpak info " <> applicationId) empty
    >>= \case
      (ExitSuccess, stdOutText, stdErrText) ->
        echoText (stdOutText <> stdErrText)
      (ExitFailure _, stdOutText, stdErrText) ->
        shell ("flatpak install --user -y " <> remoteName <> " " <> applicationId) empty
          >>= \case
            ExitSuccess -> echoText (stdOutText <> stdErrText)
            ExitFailure _ ->
              echoText (stdOutText <> stdErrText)
                >> die ("ERROR: Could not install " <> applicationId <> " from " <> remoteName)

-- | dnf5's replacement for `dnf config-manager --add-repo`, used for the
-- handful of vendors (Docker, HashiCorp, sbt) that ship their own repo
-- file rather than being packaged in Fedora directly.
addDnfRepoFile :: Text -> IO ()
addDnfRepoFile repoFileUrl =
  shell ("sudo dnf config-manager addrepo --from-repofile=" <> repoFileUrl) empty
    >>= \case
      ExitSuccess -> return ()
      ExitFailure _ -> die ("ERROR: Could not add repo file " <> repoFileUrl)

-- GHCup's bootstrap is distro-agnostic and already supports Fedora/aarch64
-- directly, so this is unchanged from upstream. Note it needs a C compiler
-- on PATH first (see the build-essential dnf install in `main` below) --
-- BOOTSTRAP_HASKELL_GHC_VERSION=latest has no aarch64 bindist as of this
-- writing, so GHCup falls back to compiling GHC from source, which still
-- needs gcc to configure/link the result.
installHaskellToolchain :: IO ()
installHaskellToolchain =
  which "ghcup"
    >>= \case
      Just ghcupLoc ->
        echoWhichLocation
          ghcupLoc
          "GHCup already installed at "
          "GHCup already installed."
      Nothing -> do
        ghcupInstallSuccessful <-
          shellStrictWithErr "BOOTSTRAP_HASKELL_NONINTERACTIVE=1 BOOTSTRAP_HASKELL_GHC_VERSION=latest BOOTSTRAP_HASKELL_CABAL_VERSION=latest BOOTSTRAP_HASKELL_INSTALL_STACK=1 BOOTSTRAP_HASKELL_INSTALL_HLS=1 BOOTSTRAP_HASKELL_ADJUST_BASHRC=P sh -s -- -y" $
            inshell
              "curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org"
              empty
        case ghcupInstallSuccessful of
          (ExitSuccess, stdOutText, stdErrText) ->
            echoText (stdOutText <> stdErrText) >> echo "GHCup Installed."
          (ExitFailure _, stdOutText, stdErrText) ->
            echoText (stdOutText <> stdErrText)
              >> die ("ERROR: Could not install GHCup")

-- | Fedora's `rustup` package installs the bootstrapper as `rustup-init`,
-- not `rustup` -- the real `rustup`/`cargo`/`rustc` only appear on PATH
-- after `rustup-init` has been run once to lay down a default toolchain
-- under ~/.cargo and ~/.rustup.
installRustLang :: IO ()
installRustLang =
  which "rustup"
    >>= \case
      Just rustupLoc ->
        echoWhichLocation
          rustupLoc
          "Rustup already installed at "
          "Rustup already installed."
      Nothing ->
        dnfInstall
          "rustup-init"
          "rustup"
          "rustup-init already installed at "
          "rustup-init already installed."
          >> shell "rustup-init -y" empty
          >>= \case
            ExitSuccess -> echo "Rust toolchain installed via rustup."
            ExitFailure _ -> die "ERROR: Could not bootstrap the Rust toolchain via rustup-init"

-- | No Fedora package for Julia at all (not even via a COPR at time of
-- writing), so this uses juliaup, the official installer/version-manager,
-- the same distro-agnostic curl-to-shell pattern as installHaskellToolchain
-- and installOhMyZsh below.
installJuliaup :: IO ()
installJuliaup =
  which "juliaup"
    >>= \case
      Just juliaupLoc ->
        echoWhichLocation
          juliaupLoc
          "juliaup already installed at "
          "juliaup already installed."
      Nothing ->
        shellStrictWithErr "sh -s -- --yes" (inshell "curl -fsSL https://install.julialang.org" empty)
          >>= \case
            (ExitSuccess, stdOutText, stdErrText) ->
              echoText (stdOutText <> stdErrText) >> echo "Julia (via juliaup) installed."
            (ExitFailure _, stdOutText, stdErrText) ->
              echoText (stdOutText <> stdErrText)
                >> die "ERROR: Could not install Julia via juliaup"

installOhMyZsh :: IO ()
installOhMyZsh =
  (home >>= testpath . flip (</>) ".oh-my-zsh")
    >>= ( \case
            True -> echo "Oh My Zsh already installed."
            False ->
              shell
                "sh -c \"$(\
                \curl -fsSL \
                \https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh\
                \)\""
                empty
                >>= ( \case
                          ExitSuccess ->
                            shell "sudo usermod --shell $(which zsh) $(whoami)" empty
                              >> echo "Oh My Zsh Install Successful"
                          ExitFailure _ -> echo "Oh My Zsh Install Failed."
                    )
        )

installOhMyZshPlugins :: IO ()
installOhMyZshPlugins = do
  zshCustomPluginsDir <- fmap (</> ".oh-my-zsh/custom/plugins") home

  zshAutosuggestionsInstalled <-
    testpath
      ( zshCustomPluginsDir </> "zsh-autosuggestions" )
  if not zshAutosuggestionsInstalled then
    shells
      "git clone https://github.com/zsh-users/zsh-autosuggestions \
      \ ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
      empty
  else
    echo "Zsh-Autosuggestions already installed"

  zshSyntaxHighlightingInstalled <-
    testpath
      ( zshCustomPluginsDir </> "zsh-syntax-highlighting" )
  if not zshSyntaxHighlightingInstalled then
    shells
      "git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
      \ ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
      empty
  else
    echo "Zsh-Syntax-Highlighting already installed."

  nixZshCompletionsInstalled <-
    testpath
      ( zshCustomPluginsDir </> "nix-zsh-completions" )
  if not nixZshCompletionsInstalled then
    shells
      "git clone https://github.com/nix-community/nix-zsh-completions.git \
      \ ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/nix-zsh-completions"
      empty
  else
    echo "Nix-Zsh-Completions already installed."

  nixShellInstalled <-
    testpath
      ( zshCustomPluginsDir </> "nix-shell" )
  if not nixShellInstalled then
    shells
      "git clone https://github.com/chisui/zsh-nix-shell.git \
      \ ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/nix-shell"
      empty
  else
    echo "Nix-Shell ZSH plugin already installed."

-- | .zshrc (line ~161) unconditionally runs `eval "$(pyenv init -)"` and
-- ~100-110 puts $PYENV_ROOT/bin on PATH, but neither this repo nor
-- pop-os-setup before it ever actually installed pyenv itself -- those
-- dotfile lines only ever worked on whatever machine originally had
-- pyenv installed by hand. Standard git-clone install (not the
-- pyenv-installer curl script, to match this repo's own git-clone
-- convention for similar tools above), plus the dnf packages pyenv's own
-- wiki lists as required to build Pythons from source later.
--
-- The build-deps dnf install runs unconditionally, outside the
-- pyenv-already-cloned check below -- confirmed directly this matters:
-- on this exact machine, ~/.pyenv already existed (cloned by hand before
-- this script ever ran), so when this used to live inside the
-- clone-only branch, the build deps were silently never installed. Later
-- building a real Python through pyenv (installAiderPython) then
-- succeeded but silently produced an interpreter missing the readline
-- extension (`ModuleNotFoundError: No module named 'readline'`) --
-- confirmed the package (`readline-devel-8.3-4.fc44`) was simply never
-- installed, not a naming/repo problem. dnf installs are already
-- individually idempotent (no-op if present), so running this every time
-- costs nothing when everything's already there.
--
-- tk-devel deliberately dropped from pyenv's usual suggested list:
-- confirmed live it conflicts with tk8-devel (Tk 9 vs Tk 8, mutually
-- exclusive package generations), which is already installed here as a
-- dependency of blt-devel (the plain `dnf install -y blt-devel` call
-- elsewhere in this file, unrelated to Python). tk-devel only enables
-- CPython's optional tkinter module; skipping it
-- just means configure quietly omits _tkinter (same graceful-degradation
-- shape as the readline case above), which nothing here needs -- aider
-- and everything else built through pyenv on this machine are terminal
-- tools, not Tk GUIs.
installPyenv :: IO ()
installPyenv = do
  shells
    "sudo dnf install -y make gcc zlib-devel bzip2 bzip2-devel \
    \readline-devel sqlite sqlite-devel openssl-devel \
    \libffi-devel xz-devel ncurses-devel"
    empty
  pyenvRoot <- fmap (</> ".pyenv") home
  pyenvInstalled <- testpath pyenvRoot
  if pyenvInstalled
    then echo "pyenv already installed."
    else do
      shells "git clone https://github.com/pyenv/pyenv.git ~/.pyenv" empty
      echo "Installed pyenv into ~/.pyenv."

-- | .tmux.conf declares `@plugin 'tmux-sensible'` and `@plugin
-- 'tmux-powerline'` and runs tpm's init script, but tpm itself
-- (~/.tmux/plugins/tpm) was never actually cloned onto this machine, so
-- neither plugin was ever installed or loaded -- the powerline styling
-- never had a chance to render. tpm's own install_plugins script (not
-- the interactive prefix + I keybind, since this runs unattended) reads
-- the @plugin lines already in .tmux.conf and fetches each one.
--
-- install_plugins always runs, even when tpm was already cloned:
-- tpm existing on disk doesn't mean its plugins were ever successfully
-- fetched (its own script is idempotent -- it checks
-- plugin_already_installed per-plugin internally), so gating it behind
-- the tpm-exists check would mean a tpm clone that succeeded while a
-- plugin fetch failed (or was interrupted) could never be retried on a
-- later run.
installTmuxPluginManager :: IO ()
installTmuxPluginManager = do
  tpmDir <- fmap (</> ".tmux/plugins/tpm") home
  tpmInstalled <- testpath tpmDir
  if tpmInstalled
    then echo "tmux plugin manager (tpm) already installed."
    else shells "git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm" empty
  shells "~/.tmux/plugins/tpm/bin/install_plugins" empty
  echo "Fetched .tmux.conf's declared tmux plugins."

installPowerline :: IO ()
installPowerline =
  shellStrictWithErr "pip show powerline-status" empty
    >>= \case
      (ExitSuccess, stdOutText, stdErrText) ->
        echoText (stdOutText <> stdErrText) >> echo "Powerline already installed."
      (ExitFailure _, stdOutText, stdErrText) ->
        echoText (stdOutText <> stdErrText)
          >> shells "pip install powerline-status" empty
          >> shells "git clone https://github.com/powerline/fonts.git" empty
          >> cd "fonts"
          >> shells "sh ./install.sh" empty
          >> cd ".."
          >> rmtree "fonts"

-- | Same shell/git/tmux dotfiles as pop-os-setup, so both machines behave
-- the same way at the shell. Unlike upstream, .xmonad isn't carried over
-- here -- Hyprland (below, via installHyprland) fills that "alternate
-- tiling WM" role instead, configured to match xmonad.hs as closely as
-- its dispatchers allow (see hypr/hyprland.conf). vivarium, the
-- original candidate, turned out to be abandoned upstream since 2023
-- and doesn't build against current wlroots/GCC; river is installed
-- separately, purely as a curiosity for future custom-WM work against
-- its protocol, not as a working xmonad replacement.
copyDotFilesToHome :: IO ()
copyDotFilesToHome = do
  homedir <- home
  curdir <- pwd
  cp (curdir </> ".profile") (homedir </> ".profile")
  cp (curdir </> ".bashrc") (homedir </> ".bashrc")
  cp (curdir </> ".bash_profile") (homedir </> ".bash_profile")
  cp (curdir </> ".zshrc") (homedir </> ".zshrc")
  cp (curdir </> ".zprofile") (homedir </> ".zprofile")
  cp (curdir </> ".tmux.conf") (homedir </> ".tmux.conf")
  cp (curdir </> ".gitconfig") (homedir </> ".gitconfig")

-- | Firefox, Elisa, Kamoso, and NeoChat are each installed twice on this
-- machine -- once as a system package, once via the flatpakInstall list
-- below, both inherited independently from pop-os-setup rather than a
-- deliberate choice for this machine -- and both installs ship a
-- .desktop file under the identical ID (e.g.
-- org.mozilla.firefox.desktop). Since ~/.local/share/flatpak/exports's
-- applications dir sits earlier in XDG_DATA_DIRS than /usr/share, the
-- Flatpak entry silently shadows the system one in any
-- XDG_DATA_DIRS-respecting launcher (confirmed with tofi-drun: only the
-- Flatpak Firefox ever showed up). Rather than drop either install,
-- this copies each system .desktop file under a distinct filename/ID
-- with "(System)" appended to its Name, so both show up as separate,
-- clearly-labelled launcher entries.
writeDisambiguatedSystemDesktopFiles :: IO ()
writeDisambiguatedSystemDesktopFiles = do
  homedir <- home
  let appsDir = homedir </> ".local/share/applications"
  mktree appsDir
  mapM_
    (disambiguateSystemDesktopFile appsDir)
    [ ("org.mozilla.firefox", "Firefox")
    , ("org.kde.elisa", "Elisa")
    , ("org.kde.kamoso", "Kamoso")
    , ("org.kde.neochat", "NeoChat")
    ]

disambiguateSystemDesktopFile :: Turtle.FilePath -> (Text, Text) -> IO ()
disambiguateSystemDesktopFile appsDir (appId, displayName) = do
  let srcPath = "/usr/share/applications/" <> appId <> ".desktop"
      destFileName = replace "." "-" appId <> "-system.desktop"
  srcExists <- testfile (fromText srcPath)
  if not srcExists
    then echoText (appId <> " not installed as a system package, skipping desktop-file override.")
    else do
      shells
        ( "cp "
            <> srcPath
            <> " "
            <> format fp (appsDir </> fromText destFileName)
        )
        empty
      shells
        ( "sed -i '0,/^Name="
            <> displayName
            <> "$/{s/^Name="
            <> displayName
            <> "$/Name="
            <> displayName
            <> " (System)/}' "
            <> format fp (appsDir </> fromText destFileName)
        )
        empty

-- | nvim/lua/plugins/lang-full.lua's Nix support (LazyVim's official
-- nix extra) configures conform.nvim to format via nixfmt -- but Mason
-- has no aarch64 Linux build for it at all (confirmed directly:
-- `:MasonInstall nixfmt` errors "The current platform is unsupported",
-- same gap as clangd), and Fedora doesn't package it either (`dnf list
-- --available nixfmt` finds nothing). Nix itself is already on this
-- machine by the time this runs, so installing nixfmt through it
-- (nixpkgs#nixfmt, the actual official Nix formatter -- confirmed via
-- `nix search nixpkgs "^nixfmt"`, not to be confused with the separate
-- nixfmt-rfc-style/nixfmt-rs/nixfmt-tree variants) is the natural fit,
-- rather than fighting Mason/dnf for a platform build that doesn't
-- exist.
installNixfmt :: IO ()
installNixfmt =
  which "nixfmt"
    >>= \case
      Just loc ->
        echoWhichLocation
          loc
          "nixfmt already installed at "
          "nixfmt already installed."
      Nothing -> shells "nix profile install nixpkgs#nixfmt" empty

-- | Fedora doesn't auto-start/enable docker.service or add you to the
-- docker group the way Debian's postinst scripts do, so both are done
-- explicitly here.
installDocker :: IO ()
installDocker =
  which "docker"
    >>= \case
      Just dockerLoc ->
        echoWhichLocation
          dockerLoc
          "Docker already installed at "
          "Docker already installed."
      Nothing -> do
        addDnfRepoFile "https://download.docker.com/linux/fedora/docker-ce.repo"
        shells
          "sudo dnf install -y docker-ce docker-ce-cli containerd.io \
          \docker-buildx-plugin docker-compose-plugin"
          empty
        shells "sudo systemctl enable --now docker" empty
        shells "sudo usermod -aG docker $(whoami)" empty

-- | Tailscale ships its own repo file rather than being packaged in
-- Fedora directly, same shape as installDocker above. `tailscale up`
-- needs interactive browser auth, so it's deliberately NOT run here --
-- this only echoes that it's still needed by hand. `tailscale set
-- --operator` IS run here though, unlike `up`: it's fully
-- non-interactive (just sudo), and skipping it silently breaks
-- waybar's custom/tailscale module later -- confirmed via a live
-- "Access denied: prefs write access denied" on a plain `tailscale
-- down` while wiring that module up, despite tailscaled.sock's
-- permissive world-writable socket perms (which only cover read-only
-- calls like `status`; up/down do their own authorization on top).
installTailscale :: IO ()
installTailscale =
  which "tailscale"
    >>= \case
      Just tailscaleLoc ->
        echoWhichLocation
          tailscaleLoc
          "Tailscale already installed at "
          "Tailscale already installed."
      Nothing -> do
        addDnfRepoFile "https://pkgs.tailscale.com/stable/fedora/tailscale.repo"
        shells "sudo dnf install -y tailscale" empty
        shells "sudo systemctl enable --now tailscaled" empty
        shells "sudo tailscale set --operator=$(whoami)" empty
        echo "Tailscale installed. Run 'sudo tailscale up' once to authenticate \
             \via browser -- until then waybar's custom/tailscale module will just \
             \show disconnected."

installTerraform :: IO ()
installTerraform =
  which "terraform" >>= \case
    Just terraformLoc ->
      echoWhichLocation
        terraformLoc
        "Terraform already installed at "
        "Terraform already installed."
    Nothing -> do
      addDnfRepoFile "https://rpm.releases.hashicorp.com/fedora/hashicorp.repo"
      shells "sudo dnf install -y terraform" empty

installSbt :: IO ()
installSbt =
  which "sbt"
    >>= \case
      Just sbtLoc ->
        echoWhichLocation
          sbtLoc
          "sbt already installed at "
          "sbt already installed."
      Nothing -> do
        shells
          "curl -L https://www.scala-sbt.org/sbt-rpm.repo \
          \ | sudo tee /etc/yum.repos.d/sbt-rpm.repo"
          empty
        shells "sudo dnf install -y sbt" empty

-- | The official ProtonVPN GUI app is packaged (and named) for GNOME only
-- upstream, so this installs the official ProtonVPN CLI instead, via
-- ProtonVPN's own repo. `rpm -E %fedora` is used rather than parsing
-- /etc/fedora-release, since that file reads "Fedora Asahi Remix release
-- 44 ..." here -- splitting on spaces the way ProtonVPN's own docs suggest
-- would grab "Remix" instead of "44". Note the Fedora package is named
-- proton-vpn-cli (hyphenated), which installs a binary literally called
-- `protonvpn` (no "-cli" suffix) -- confirmed directly against the repo
-- once it's enabled, since neither name is obvious from ProtonVPN's docs.
installProtonVpnCli :: IO ()
installProtonVpnCli =
  which "protonvpn"
    >>= \case
      Just protonvpnLoc ->
        echoWhichLocation
          protonvpnLoc
          "ProtonVPN CLI already installed at "
          "ProtonVPN CLI already installed."
      Nothing -> do
        fedoraVersion <- strip <$> (strict $ inshell "rpm -E %fedora" empty)
        shells
          ( "sudo dnf install -y \
            \ https://repo.protonvpn.com/fedora-"
              <> fedoraVersion
              <> "-stable/protonvpn-stable-release/protonvpn-stable-release-1.0.4-1.noarch.rpm"
          )
          empty
        shells "sudo dnf check-update --refresh" empty
        -- proton-vpn-daemon's %posttrans scriptlet starts a systemd
        -- service that can transiently fail its first start attempt
        -- (confirmed: systemd's own Restart= policy then retries it
        -- successfully) -- but RPM %posttrans scripts run after the
        -- transaction is already committed, so dnf reports the whole
        -- install as failed even though the packages are genuinely
        -- installed. Verify against the actual binary rather than
        -- trusting that exit code, so a real install failure (package
        -- unavailable, network error, etc.) still fails loudly.
        shell "sudo dnf install -y proton-vpn-cli" empty
          >>= \case
            ExitSuccess -> return ()
            ExitFailure _ ->
              which "protonvpn"
                >>= \case
                  Just _ ->
                    echo "proton-vpn-cli is installed (dnf reported a non-fatal posttrans scriptlet hiccup starting its systemd service, but the package and binary are present)."
                  Nothing -> die "ERROR: Could not install proton-vpn-cli"

-- | No dnf/Flathub package for the Bitwarden CLI (distinct from the
-- com.bitwarden.desktop GUI flatpak below, which is a separate app);
-- npm is the officially documented install method on ARM64, and npm is
-- already set up by this point in the script.
installBitwardenCli :: IO ()
installBitwardenCli =
  npmInstall "bw" "@bitwarden/cli" "Bitwarden CLI already installed at " "Bitwarden CLI already installed."

-- | Ice SSB (peppermintos/ice) has no build system beyond Debian's
-- debian/ packaging, and no RPM equivalent exists. It's a plain Python 3
-- + GTK3 script (usr/bin/ice, plus a handful of usr/share assets), so this
-- places those files directly rather than faking a debuild/dpkg step.
installIceSsb :: IO ()
installIceSsb =
  which "ice"
    >>= \case
      Just iceLoc ->
        echoWhichLocation
          iceLoc
          "Ice SSB already installed at "
          "Ice SSB already installed."
      Nothing ->
        shells
          "sudo dnf install -y python3-gobject gtk3 python3-requests python3-beautifulsoup4 \
          \ && git clone https://github.com/peppermintos/ice.git ice-src \
          \ && sudo cp ice-src/usr/bin/ice /usr/local/bin/ice \
          \ && sudo chmod 755 /usr/local/bin/ice \
          \ && sudo cp -r ice-src/usr/share/ice /usr/local/share/ice \
          \ && sudo cp ice-src/usr/share/applications/*.desktop /usr/local/share/applications/ \
          \ && rm -rf ice-src"
          empty

-- | Official Flathub has no aarch64 build of Signal (still x86_64-only
-- as of this writing), so this adds a third-party community Flatpak
-- remote that publishes precompiled aarch64 builds instead of building
-- Signal's Electron app from source. See the header comment for the
-- trust trade-off this involves.
installSignal :: IO ()
installSignal =
  shellStrictWithErr "flatpak info org.signal.Signal" empty
    >>= \case
      (ExitSuccess, stdOutText, stdErrText) ->
        echoText (stdOutText <> stdErrText)
      (ExitFailure _, _, _) ->
        shell
          "flatpak remote-add --user --if-not-exists signal-flatpak \
          \ https://signalflatpak.github.io/signal/signal.flatpakrepo"
          empty
          >>= \case
            ExitSuccess -> flatpakInstallFromRemote "signal-flatpak" "org.signal.Signal"
            ExitFailure _ -> die "ERROR: Could not add the remote 'signal-flatpak'."

-- | No dnf/Flathub package; andirsun/Slacky publishes a native aarch64
-- RPM directly on GitHub (an Electron wrapper around Slack's own web
-- client, not a reimplemented private protocol).
installSlacky :: IO ()
installSlacky =
  which "slacky"
    >>= \case
      Just slackyLoc ->
        echoWhichLocation
          slackyLoc
          "Slacky (unofficial arm64 Slack client) already installed at "
          "Slacky already installed."
      Nothing ->
        shells
          "curl -L https://github.com/andirsun/Slacky/releases/download/v0.0.10/slacky-0.0.10.aarch64.rpm -o slacky.aarch64.rpm \
          \ && sudo dnf install -y ./slacky.aarch64.rpm \
          \ && rm -f ./slacky.aarch64.rpm"
          empty

-- | Spotify has no Linux ARM64 client at all, official or otherwise, so
-- this installs librespot (a mature, actively maintained open-source
-- reimplementation of the Spotify Connect protocol) as the actual audio
-- receiver, plus spotify_player (a Rust TUI) for local browsing/search
-- and Connect-device control. Both build natively for aarch64 via cargo,
-- no emulation involved. librespot.service runs librespot in
-- credential-free "zeroconf" discovery mode -- see librespot/librespot.service
-- in this repo.
--
-- Must run after installRustLang: invokes cargo by its absolute
-- ~/.cargo/bin path rather than relying on PATH, since rustup-init only
-- updates shell rc files for *future* shells, not this already-running
-- process's environment.
installSpotifyConnectReceiver :: IO ()
installSpotifyConnectReceiver = do
  shells "sudo dnf install -y alsa-lib-devel openssl-devel dbus-devel" empty
  which "librespot"
    >>= \case
      Just librespotLoc ->
        echoWhichLocation
          librespotLoc
          "librespot already installed at "
          "librespot already installed."
      Nothing -> do
        shells "$HOME/.cargo/bin/cargo install librespot --locked" empty
        writeLibrespotSystemdService
  -- `cargo install spotify_player` (matching the crate name) is what
  -- actually lands on disk as the binary name -- confirmed directly via
  -- `cargo install --list` -- not "spotify-player" with a hyphen (the
  -- name this used to check for here, which meant `which` could never
  -- find it and this step always re-ran cargo install unnecessarily).
  which "spotify_player"
    >>= \case
      Just playerLoc ->
        echoWhichLocation
          playerLoc
          "spotify_player already installed at "
          "spotify_player already installed."
      Nothing ->
        shells "$HOME/.cargo/bin/cargo install spotify_player --locked" empty
  writeSpotifyPlayerDesktopFile

-- | spotify_player is a TUI with no .desktop file anywhere on the
-- system (confirmed directly) -- fuzzel and any other XDG-compliant
-- launcher only lists apps that have one, so it could never show up
-- there regardless of whether the binary itself was installed
-- correctly. Launches into Konsole, same pattern as hyprland.conf's own
-- `konsole -e tmux attach` binding. Icon is utilities-terminal rather
-- than a "spotify"-named icon: Papirus-Dark inherits from
-- breeze-dark/hicolor, not from the base Papirus theme that actually
-- has spotify app icons, so a "spotify" icon name would silently
-- resolve to nothing (confirmed directly).
writeSpotifyPlayerDesktopFile :: IO ()
writeSpotifyPlayerDesktopFile = do
  curdir <- pwd
  homeDir <- home
  let appsDir = homeDir </> ".local/share/applications"
      desktopPath = appsDir </> "spotify_player.desktop"
  alreadyExists <- testfile desktopPath
  if alreadyExists
    then echo "~/.local/share/applications/spotify_player.desktop already present, leaving it untouched."
    else do
      mktree appsDir
      cp (curdir </> "spotify_player.desktop") desktopPath
      echo "Wrote ~/.local/share/applications/spotify_player.desktop so spotify_player shows up in the launcher."

-- | vifm is a TUI with no .desktop file of its own, same gap
-- spotify_player had -- launches into foot (a lighter terminal than
-- this repo's usual Konsole) rather than the heavier default, by
-- request. Icon=vifm resolves via hicolor (which Papirus-Dark inherits
-- from), confirmed directly rather than assumed the way the earlier
-- spotify_player icon lookup had to fall back to a generic one.
writeVifmDesktopFile :: IO ()
writeVifmDesktopFile = do
  curdir <- pwd
  homeDir <- home
  let appsDir = homeDir </> ".local/share/applications"
      desktopPath = appsDir </> "vifm.desktop"
  alreadyExists <- testfile desktopPath
  if alreadyExists
    then echo "~/.local/share/applications/vifm.desktop already present, leaving it untouched."
    else do
      mktree appsDir
      cp (curdir </> "vifm.desktop") desktopPath
      echo "Wrote ~/.local/share/applications/vifm.desktop so vifm shows up in the launcher."

-- | foot is now the default terminal (hypr/hyprland.conf's mod-shift-Return
-- and mod-e bindings), by request -- Solarized Dark to match, using the
-- same standard 16-ANSI-color mapping as konsole/SolarizedDark.colorscheme.
-- foot's own default foreground/background (839496/002b36) already happen
-- to be Solarized's base0/base03; only the ANSI regular*/bright* colors
-- (foot's stock "starlight" palette) actually needed overriding, confirmed
-- via `man foot.ini`.
writeFootConfig :: IO ()
writeFootConfig = do
  curdir <- pwd
  homeDir <- home
  let configDir = homeDir </> ".config/foot"
      configPath = configDir </> "foot.ini"
  alreadyExists <- testfile configPath
  if alreadyExists
    then echo "~/.config/foot/foot.ini already present, leaving it untouched."
    else do
      mktree configDir
      cp (curdir </> "foot/foot.ini") configPath
      echo "Wrote ~/.config/foot/foot.ini (Solarized Dark, Hack 10pt)."

-- | No dnf/Flathub package (there's a third-party COPR,
-- chrisbouchard/neovide-nightly, but it's unvetted and not confirmed to
-- build for aarch64, and there's an open but unmerged Flathub PR). Built
-- via cargo instead, same pattern as librespot/spotify_player above.
-- Neovide is a genuine native-Wayland GUI for Neovim (built on winit,
-- not XWayland) -- the replacement for upstream's gvim/vim-X11, which is
-- X11-only and was dropped outright rather than translated.
installNeovide :: IO ()
installNeovide = do
  shells "sudo dnf install -y fontconfig-devel" empty
  which "neovide"
    >>= \case
      Just neovideLoc ->
        echoWhichLocation
          neovideLoc
          "Neovide already installed at "
          "Neovide already installed."
      Nothing ->
        shells "$HOME/.cargo/bin/cargo install neovide --locked" empty
  writeNeovideDesktopFile
  writeNeovideConfig

-- | Neovide has no .desktop file of its own, same gap spotify_player
-- and vifm had -- unlike those two (TUIs needing a terminal wrapper),
-- Neovide is a real GUI app, so this launches it directly. Icon=nvim
-- resolves via hicolor's plain nvim.png (which Papirus-Dark inherits
-- from), confirmed directly rather than assumed.
writeNeovideDesktopFile :: IO ()
writeNeovideDesktopFile = do
  curdir <- pwd
  homeDir <- home
  let appsDir = homeDir </> ".local/share/applications"
      desktopPath = appsDir </> "neovide.desktop"
  alreadyExists <- testfile desktopPath
  if alreadyExists
    then echo "~/.local/share/applications/neovide.desktop already present, leaving it untouched."
    else do
      mktree appsDir
      cp (curdir </> "neovide.desktop") desktopPath
      echo "Wrote ~/.local/share/applications/neovide.desktop so Neovide shows up in the launcher."

-- | No ~/.config/nvim at all exists on this machine, so Neovide fell
-- back to its own default font size, which rendered noticeably larger
-- than wanted -- confirmed directly, fixed the same way as the earlier
-- Konsole/qt6ct font fixes, matching the same Hack/10pt Josiah already
-- confirmed there.
writeNeovideConfig :: IO ()
writeNeovideConfig = do
  curdir <- pwd
  homeDir <- home
  let configDir = homeDir </> ".config/neovide"
      configPath = configDir </> "config.toml"
  alreadyExists <- testfile configPath
  if alreadyExists
    then echo "~/.config/neovide/config.toml already present, leaving it untouched."
    else do
      mktree configDir
      cp (curdir </> "neovide/config.toml") configPath
      echo "Wrote ~/.config/neovide/config.toml (Hack Nerd Font, 11pt)."

-- | No dnf/Flathub package for Nerd Fonts at all (checked directly --
-- `dnf list --available "*nerd-fonts*"` returns nothing), so this
-- fetches Hack's own release directly from the nerd-fonts project,
-- same "no clean package, download it" pattern as papirus-folders
-- above. Needed for LazyVim's UI (lualine, neo-tree, bufferline,
-- which-key) to render its icon glyphs at all -- plain Hack (already
-- used everywhere else on this machine) doesn't have them, same class
-- of icon gotcha as waybar's Font Awesome fonts. Installed to
-- ~/.local/share/fonts rather than system-wide, so no sudo needed.
installHackNerdFont :: IO ()
installHackNerdFont = do
  homeDir <- home
  let fontDir = homeDir </> ".local/share/fonts/HackNerdFont"
  alreadyExists <- testdir fontDir
  if alreadyExists
    then echo "~/.local/share/fonts/HackNerdFont already present, leaving it untouched."
    else do
      mktree fontDir
      curdir <- pwd
      cd fontDir
      shells
        "curl -fsSL -o HackNerdFont.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/Hack.zip \
        \&& unzip -oq HackNerdFont.zip \
        \&& rm HackNerdFont.zip"
        empty
      cd curdir
      shells "fc-cache -f" empty
      echo "Installed Hack Nerd Font to ~/.local/share/fonts/HackNerdFont."

-- | A different, separate font pack from Hack Nerd Font above: Doom's
-- `nerd-icons` package (file-type icons in dired/treemacs/dashboard/
-- modeline) specifically wants nerd-fonts' own minimal "Symbols Nerd Font
-- Mono" glyphs-only pack, not a patched programming font -- confirmed
-- live via `doom doctor`, which explicitly names this exact font and
-- suggests either `M-x nerd-icons-install-fonts` (interactive, inside
-- Emacs) or a manual OS-package install. Fetched the same way as
-- installHackNerdFont above (same v3.4.0 release tag, confirmed real
-- asset name via the GitHub releases API: NerdFontsSymbolsOnly.zip)
-- rather than relying on the interactive Emacs command, so this stays
-- scriptable like every other font install in this file.
installSymbolsNerdFont :: IO ()
installSymbolsNerdFont = do
  homeDir <- home
  let fontDir = homeDir </> ".local/share/fonts/SymbolsNerdFont"
  alreadyExists <- testdir fontDir
  if alreadyExists
    then echo "~/.local/share/fonts/SymbolsNerdFont already present, leaving it untouched."
    else do
      mktree fontDir
      curdir <- pwd
      cd fontDir
      shells
        "curl -fsSL -o NerdFontsSymbolsOnly.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/NerdFontsSymbolsOnly.zip \
        \&& unzip -oq NerdFontsSymbolsOnly.zip \
        \&& rm NerdFontsSymbolsOnly.zip"
        empty
      cd curdir
      shells "fc-cache -f" empty
      echo "Installed Symbols Nerd Font to ~/.local/share/fonts/SymbolsNerdFont (Doom's nerd-icons)."

-- | No ~/.config/nvim existed at all on this machine, same starting
-- point as writeNeovideConfig above -- this is LazyVim (the closest
-- real analog to Doom Emacs for Neovim: a curated, lazy-loaded plugin
-- framework rather than a from-scratch config), via its own official
-- starter template. nvim/lua/plugins/colorscheme.lua overrides the
-- default tokyonight theme with Solarized Dark (maxmx03/solarized.nvim,
-- verified directly against its source to use the same canonical hex
-- values as the rest of this machine's theming, not its alternate
-- "selenized" palette).
--
-- Only bootstraps (headless plugin sync) on first install, not on every
-- re-run -- matches the same "already exists, leave untouched" idempotency
-- as the config deployment itself, and re-syncing on every provisioning
-- run would be slow for no benefit once plugins are already installed.
writeNvimConfig :: IO ()
writeNvimConfig = do
  curdir <- pwd
  homeDir <- home
  let configDir = homeDir </> ".config/nvim"
  alreadyExists <- testdir configDir
  if alreadyExists
    then echo "~/.config/nvim already present, leaving it untouched."
    else do
      shells ("cp -r " <> format fp (curdir </> "nvim") <> " " <> format fp configDir) empty
      echo "Wrote ~/.config/nvim (LazyVim, Solarized Dark)."
      shells "nvim --headless \"+Lazy! sync\" +qa" empty
      -- opts.servers/opts.ensure_installed-driven Mason auto-install is
      -- gated behind a BufReadPre/FileType event a bare headless +qa run
      -- never fires, so every LSP/lint tool nvim/lua/plugins/lang-*.lua
      -- and guile.lua need has to be force-installed here explicitly,
      -- same reasoning that already required stylua/shfmt. Nushell's
      -- LSP is just the `nu` binary itself with a flag (see the nushell
      -- dnfInstall below) -- no separate Mason package for it. Neither
      -- clangd nor nixfmt are in this list -- both confirmed directly
      -- that Mason has no aarch64 Linux build for them at all ("The
      -- current platform is unsupported"), so they're installed as a
      -- system package (clang-tools-extra) and via `nix profile`
      -- (installNixfmt) instead, and just need to be on PATH, which
      -- nvim-lspconfig/conform.nvim don't care how they got there. zls
      -- IS available on Mason for aarch64 (confirmed directly against
      -- mason-registry's packages/zls/package.yaml: a real linux_arm64
      -- asset exists), unlike clangd/nixfmt -- added here for that reason.
      shells
        "nvim --headless -c \"MasonInstall stylua shfmt bash-language-server shellcheck rust-analyzer nil pyright taplo json-lsp fish-lsp statix zls\" -c \"sleep 60\" -c \"qa\""
        empty
      echo "Bootstrapped LazyVim's plugins and Mason tools (stylua, shfmt, bash-language-server, shellcheck, rust-analyzer, nil, pyright, taplo, json-lsp, fish-lsp, statix, zls)."

writeLibrespotSystemdService :: IO ()
writeLibrespotSystemdService = do
  curdir <- pwd
  homeDir <- home
  let serviceDir = homeDir </> ".config/systemd/user"
      servicePath = serviceDir </> "librespot.service"
  alreadyExists <- testfile servicePath
  if alreadyExists
    then echo "~/.config/systemd/user/librespot.service already present, leaving it untouched."
    else do
      mktree serviceDir
      cp (curdir </> "librespot/librespot.service") servicePath
      shells "systemctl --user daemon-reload" empty
      shells "systemctl --user enable --now librespot.service" empty
      echo "librespot running as a systemd --user service; pick \"Librespot (Asahi)\" from Spotify Connect elsewhere."

-- | Two xkb key remaps for the Plasma session: caps:swapescape (swap Caps
-- Lock/Escape) and ctrl:ralt_rctrl (Right Alt/Option acts as Right
-- Control). Only written if ~/.config/kxkbrc doesn't exist yet -- if it
-- does, you've likely already customized keyboard layouts through
-- System Settings, and blindly
-- overwriting it could clobber that (this is a plain ini-style file, not
-- something worth hand-rolling a merge for). Note: KDE bug 433265 means
-- XKB options written directly to kxkbrc don't always take effect
-- reliably under Wayland; if this doesn't work after a re-login, set the
-- same options via System Settings > Input Devices > Keyboard > Advanced
-- instead, which goes through the path that's actually known to work.
writeKxkbrcKeyRemaps :: IO ()
writeKxkbrcKeyRemaps = do
  curdir <- pwd
  homeDir <- home
  let kxkbrcPath = homeDir </> ".config/kxkbrc"
  alreadyExists <- testfile kxkbrcPath
  if alreadyExists
    then echo "~/.config/kxkbrc already present, leaving it untouched -- add Options=caps:swapescape,ctrl:ralt_rctrl under [Layout] by hand, or via System Settings, if you still want these remaps."
    else do
      cp (curdir </> "plasma/kxkbrc") kxkbrcPath
      echo "Wrote ~/.config/kxkbrc (caps:swapescape, ctrl:ralt_rctrl). Log out/in for it to take effect; see KDE bug 433265 if it doesn't stick under Wayland."

-- | ~/.config/kxkbrc's Options alone turned out not to be enough on this
-- machine -- confirmed directly: this Plasma Wayland session's KWin
-- composes its keyboard config from localectl's system-wide
-- /etc/X11/xorg.conf.d/00-keyboard.conf at session start, not from the
-- per-user kxkbrc file (localectl status showed X11 Options:
-- terminate:ctrl_alt_bksp only, no sign of kxkbrc's Options at all,
-- and neither `hyprctl`-style live reload nor `qdbus
-- org.kde.KWin.reconfigure` picked up a change here -- only an actual
-- logout/login did, same as the dvorak kb_layout issue in
-- hypr/hyprland.conf). Appends the remaps to whatever X11 Options
-- localectl already reports rather than overwriting them outright, so
-- this doesn't clobber the existing terminate:ctrl_alt_bksp (or whatever
-- else may be set) on a fresh machine's own defaults.
writeSystemX11KeyboardOptions :: IO ()
writeSystemX11KeyboardOptions = do
  (_, currentOptionsLine, _) <-
    shellStrictWithErr "localectl status | grep 'X11 Options:' | sed 's/.*: //'" empty
  let currentOptions = strip currentOptionsLine
      wantedOptions = "caps:swapescape,ctrl:ralt_rctrl"
  if wantedOptions `isInfixOf` currentOptions
    then echo "System-wide X11 keyboard options already include the caps/ctrl remaps."
    else do
      let combinedOptions =
            if currentOptions == ""
              then wantedOptions
              else currentOptions <> "," <> wantedOptions
      shells
        ("sudo localectl set-x11-keymap us pc105 dvorak \"" <> combinedOptions <> "\"")
        empty
      echo "Set system-wide X11 keyboard options (caps:swapescape, ctrl:ralt_rctrl) via localectl -- log out/in for KWin to pick it up (a live reconfigure signal isn't enough)."

-- | Solarized Dark KDE color scheme, applied via `plasma-apply-colorscheme`
-- (a real Plasma tool, no sudo needed) for the Plasma session, and
-- pointed at by qt6ct's own config (below) for the Hyprland session,
-- since qt6ct natively understands the same KDE .colors format --
-- avoiding maintaining two separate palettes for the two sessions.
writePlasmaColorScheme :: IO ()
writePlasmaColorScheme = do
  curdir <- pwd
  homeDir <- home
  let schemesDir = homeDir </> ".local/share/color-schemes"
      schemePath = schemesDir </> "SolarizedDark.colors"
  alreadyExists <- testfile schemePath
  if alreadyExists
    then echo "~/.local/share/color-schemes/SolarizedDark.colors already present, leaving it untouched."
    else do
      mktree schemesDir
      cp (curdir </> "plasma/SolarizedDark.colors") schemePath
      shells "plasma-apply-colorscheme SolarizedDark" empty
      echo "Wrote and applied the SolarizedDark Plasma color scheme."

-- | Qt/KDE apps' default font resolution (Dolphin, System Settings,
-- etc. under a real Plasma session) rendered noticeably larger than
-- wanted -- confirmed directly, fixed the same way as
-- writeQt6ctConfig's [Fonts] section covers the Hyprland-session case.
writePlasmaFont :: IO ()
writePlasmaFont = do
  (_, currentFont, _) <-
    shellStrictWithErr "kreadconfig6 --file kdeglobals --group General --key font" empty
  if strip currentFont == ""
    then do
      shells
        "kwriteconfig6 --file kdeglobals --group General --key font \"Noto Sans,10,-1,5,50,0,0,0,0,0\""
        empty
      echo "Set kdeglobals' General font to Noto Sans, 10pt."
    else echo "kdeglobals already has a General font set, leaving it untouched."

-- | qt6ct is what gives Qt/KDE apps (Dolphin, etc.) a themed palette
-- under Hyprland, where there's no Plasma shell to set one automatically
-- the way there is under a real Plasma session -- QT_QPA_PLATFORMTHEME
-- (set in hypr/hyprland.conf's env block) is what tells Qt apps to ask
-- qt6ct at all. color_scheme_path points at the same .colors file
-- writePlasmaColorScheme deploys, since qt6ct can load KDE's own color
-- scheme format directly -- no need for a second, qt6ct-specific palette.
installQt6ct :: IO ()
installQt6ct =
  dnfInstall
    "qt6ct"
    "qt6ct"
    "qt6ct already installed at "
    "qt6ct already installed."

writeQt6ctConfig :: IO ()
writeQt6ctConfig = do
  homeDir <- home
  let configDir = homeDir </> ".config/qt6ct"
      configPath = configDir </> "qt6ct.conf"
      schemePath = homeDir </> ".local/share/color-schemes/SolarizedDark.colors"
  alreadyExists <- testfile configPath
  if alreadyExists
    then echo "~/.config/qt6ct/qt6ct.conf already present, leaving it untouched."
    else do
      mktree configDir
      schemePathText <- either (const (die "Could not decode home directory path as UTF-8")) return (toText schemePath)
      writeTextFile
        configPath
        ( "[Appearance]\n"
            <> "color_scheme_path="
            <> schemePathText
            <> "\n"
            <> "custom_palette=true\n"
            <> "icon_theme=Papirus-Dark\n"
            <> "standard_dialogs=default\n"
            -- Breeze, not Fusion: qt6ct itself switched its live config to
            -- Breeze at some point after this was first written (confirmed
            -- against the live ~/.config/qt6ct/qt6ct.conf), and Breeze
            -- matches the rest of this repo's KDE/Plasma-integrated look
            -- better than Qt's generic Fusion style.
            <> "style=Breeze\n"
            <> "\n"
            <> "[Fonts]\n"
            -- The trailing ",0,0,0,0,1" fields and weight 400 (not the old
            -- 50) match Qt6's current font-string format, confirmed against
            -- the live file -- qt6ct rewrote both font entries into this
            -- format itself after this template was first written.
            <> "fixed=\"Hack,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1\"\n"
            <> "general=\"Noto Sans,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1\"\n"
        )
      echo "Wrote ~/.config/qt6ct/qt6ct.conf (Solarized Dark, via the same SolarizedDark.colors file Plasma uses)."

-- | Breeze's default folder icons are blue, which clashes visually next
-- to Solarized's own orange accent used everywhere else (hyprland.conf
-- borders, waybar, fuzzel). papirus-icon-theme-dark is a pure data/icon
-- package with no binary of its own, so this calls dnf directly rather
-- than force-fitting the dnfInstall helper's which-based "is it already
-- installed" check onto a package that has nothing to `which`.
installPapirusIconTheme :: IO ()
installPapirusIconTheme =
  shells "sudo dnf install -y papirus-icon-theme-dark" empty

-- | papirus-folders (the tool that recolors Papirus's folder icons) has
-- no Fedora package -- fetched directly from its own GitHub repo and
-- installed to /usr/local/bin, same pattern as kompose/kind/k3d above,
-- so it stays available later if the color ever needs changing again.
installPapirusFolders :: IO ()
installPapirusFolders =
  which "papirus-folders"
    >>= \case
      Just loc ->
        echoWhichLocation
          loc
          "papirus-folders already installed at "
          "papirus-folders already installed."
      Nothing ->
        shells
          "curl -fsSL https://raw.githubusercontent.com/PapirusDevelopmentTeam/papirus-folders/master/papirus-folders -o papirus-folders"
          empty
          >> chmod executable "./papirus-folders"
          >> shells "sudo mv ./papirus-folders /usr/local/bin/papirus-folders" empty

-- | Sets Papirus-Dark's folder color to orange (Solarized's own accent)
-- and makes Papirus-Dark the active icon theme for Qt/KDE apps
-- (kdeglobals, read by a real Plasma session) -- qt6ct's own icon_theme
-- setting (written by writeQt6ctConfig above) covers the Hyprland
-- session, which has no Plasma shell to read kdeglobals from
-- automatically. papirus-folders re-execs itself via sudo internally
-- when it needs to modify the system-wide /usr/share/icons/Papirus-Dark
-- directory, so this doesn't need its own separate privilege escalation
-- for that step.
applyPapirusDarkOrangeTheme :: IO ()
applyPapirusDarkOrangeTheme = do
  (exitCode, currentTarget, _) <-
    shellStrictWithErr "readlink /usr/share/icons/Papirus-Dark/64x64/places/folder.svg" empty
  let alreadyOrange =
        exitCode == ExitSuccess && isInfixOf (pack "folder-orange") (strip currentTarget)
  if alreadyOrange
    then echo "Papirus-Dark folder color already set to orange."
    else do
      shells "sudo papirus-folders -C orange -t Papirus-Dark -u" empty
      echo "Set Papirus-Dark's folder color to orange."
  shells "kwriteconfig6 --file kdeglobals --group Icons --key Theme Papirus-Dark" empty
  echo "Set Papirus-Dark as the active Plasma icon theme."

-- | Konsole ships no loose .colorscheme/.profile files on this system
-- to begin with (its stock Breeze scheme and default profile are Qt
-- resources compiled into the binary, not files on disk -- confirmed
-- directly: nothing under /usr/share, and konsole's own rpm file list
-- has no *.colorscheme or *.profile entries at all), so there's nothing
-- pre-existing here to clobber. Uses the same Solarized Dark palette as
-- plasma/SolarizedDark.colors/waybar/fuzzel/hyprland.conf, mapped onto
-- the standard 16-ANSI-color Solarized terminal convention (see that
-- .colorscheme file's own header comment for the exact mapping).
writeKonsoleSolarizedTheme :: IO ()
writeKonsoleSolarizedTheme = do
  curdir <- pwd
  homeDir <- home
  let konsoleDir = homeDir </> ".local/share/konsole"
      colorSchemePath = konsoleDir </> "SolarizedDark.colorscheme"
      profilePath = konsoleDir </> "Default.profile"
  alreadyExists <- testfile profilePath
  if alreadyExists
    then echo "~/.local/share/konsole/Default.profile already present, leaving it untouched."
    else do
      mktree konsoleDir
      cp (curdir </> "konsole/SolarizedDark.colorscheme") colorSchemePath
      cp (curdir </> "konsole/Default.profile") profilePath
      shells
        "kwriteconfig6 --file konsolerc --group \"Desktop Entry\" --key DefaultProfile Default.profile"
        empty
      echo "Wrote Konsole's Solarized Dark color scheme and set it as the default profile."

-- | There's no packaged Solarized GTK theme in Fedora's repos (checked
-- directly), and GTK has no equivalent to qt6ct's "point at a KDE
-- .colors file" bridge. KDE's own kde-gtk-config normally auto-generates
-- ~/.config/gtk-{3,4}.0/colors.css from the active Plasma color scheme
-- (via its colorreload-gtk-module + kded "gtkconfig" plugin); it wasn't
-- firing in this Hyprland session when this function was first written,
-- which is why this repo carries its own copy of the file at all. It has
-- since started firing on its own (confirmed: the live files are now
-- genuinely Solarized, just expressed as literal hex values under
-- kde-gtk-config's own naming rather than this repo's named
-- @solarized_* aliases) -- gtk/colors.css is now only a fallback default
-- for a fresh machine where kde-gtk-config hasn't generated one yet, kept
-- in sync with the live host's actual values (host is the source of
-- truth here, not this repo).
--
-- Originally used a content-sniffing check (`isInfixOf "solarized_base03"`)
-- to tell "already Solarized" apart from "never configured," on the theory
-- that a file could exist without being the Solarized one this repo
-- wants. That check silently broke the moment kde-gtk-config started
-- generating its own literal-hex version, which contains no such marker
-- string -- read as "not applied" and would have overwritten the live,
-- correctly-Solarized file with this repo's (different) values.
-- Downgraded to the same plain existence check every other write*Config
-- function here already uses: if a file already exists, something put it
-- there on purpose, so leave it alone regardless of content. Each of
-- gtk-3.0/gtk-4.0 is checked and written independently now (previously
-- both were rewritten together whenever either one looked
-- "not customized," which -- combined with the marker-check bug -- was a
-- second way this could have clobbered a file that didn't need touching).
writeGtkColorsCss :: IO ()
writeGtkColorsCss = do
  curdir <- pwd
  homeDir <- home
  writeIfMissing curdir (homeDir </> ".config/gtk-3.0") "~/.config/gtk-3.0/colors.css"
  writeIfMissing curdir (homeDir </> ".config/gtk-4.0") "~/.config/gtk-4.0/colors.css"
  where
    writeIfMissing curdir configDir label = do
      let path = configDir </> "colors.css"
      alreadyExists <- testfile path
      if alreadyExists
        then echo (label <> " already present, leaving it untouched.")
        else do
          mktree configDir
          cp (curdir </> "gtk/colors.css") path
          echo ("Wrote Solarized Dark to " <> label <> ".")

-- | GTK's own icon theme setting is separate from kdeglobals' (used by
-- Qt/KDE apps) -- confirmed directly, it was still breeze-dark despite
-- Papirus-Dark already being set as the Plasma/qt6ct icon theme.
-- Editing settings.ini directly (not writing it wholesale, unlike
-- colors.css above): it has many other pre-existing settings (cursor
-- theme, sound theme, etc.) this repo doesn't otherwise manage, so a
-- targeted sed-style replace is safer than templating the whole file.
setGtkIconTheme :: IO ()
setGtkIconTheme = do
  homeDir <- home
  fixSettingsIni (homeDir </> ".config/gtk-3.0/settings.ini") "~/.config/gtk-3.0/settings.ini"
  fixSettingsIni (homeDir </> ".config/gtk-4.0/settings.ini") "~/.config/gtk-4.0/settings.ini"
  where
    fixSettingsIni path label = do
      exists <- testfile path
      if not exists
        then echo (label <> " doesn't exist, skipping.")
        else do
          contents <- strict (input path)
          if isInfixOf (pack "gtk-icon-theme-name=Papirus-Dark") contents
            then echo (label <> " already uses Papirus-Dark.")
            else do
              shells
                ( "sed -i 's/^gtk-icon-theme-name=.*/gtk-icon-theme-name=Papirus-Dark/' "
                    <> format fp path
                )
                empty
              echo ("Set gtk-icon-theme-name=Papirus-Dark in " <> label)

-- | No Fedora package exists; kompose's GitHub releases publish an
-- aarch64 binary directly (`kompose-linux-arm64`), unlike the amd64 one
-- upstream's own script used.
installKompose :: IO ()
installKompose =
  which "kompose" >>= \case
    Just komposeLoc ->
      echoWhichLocation
        komposeLoc
        "Kompose already installed at "
        "Kompose already installed."
    Nothing ->
      shells
        "curl -L https://github.com/kubernetes/kompose/releases/download/v1.38.0/kompose-linux-arm64 -o kompose"
        empty
        >> chmod executable "./kompose"
        >> shells "sudo mv ./kompose /usr/local/bin/kompose" empty

-- | Fedora's own `kind` package DOES exist and was the original plan
-- here, but its RPM requires "docker-cli or podman-docker" -- and
-- podman-docker hard-conflicts with the docker-ce/docker-ce-cli that
-- installDocker sets up above (confirmed via a live run: dnf's own
-- --allowerasing suggestion would silently swap out the working Docker
-- CE install for Podman to resolve it, which is a much bigger unwanted
-- change than it looks). Direct binary download avoids that risk
-- entirely, same pattern as installKompose above.
installKind :: IO ()
installKind =
  which "kind" >>= \case
    Just kindLoc ->
      echoWhichLocation
        kindLoc
        "KinD already installed at "
        "KinD already installed."
    Nothing ->
      shells
        "curl -L https://github.com/kubernetes-sigs/kind/releases/download/v0.32.0/kind-linux-arm64 -o kind"
        empty
        >> chmod executable "./kind"
        >> shells "sudo mv ./kind /usr/local/bin/kind" empty

-- | No Fedora package; k3d's GitHub releases publish an aarch64 binary
-- directly (`k3d-linux-arm64`), same pattern as kompose/kind above. This
-- is what k3x (in the flatpak list further down) is actually a GUI
-- for -- k3x alone can't do anything without it (confirmed: k3x failed
-- to launch/function on a live run before this was added), since k3x
-- itself just wraps k3d, which in turn runs k3s clusters inside Docker.
installK3d :: IO ()
installK3d =
  which "k3d" >>= \case
    Just k3dLoc ->
      echoWhichLocation
        k3dLoc
        "k3d already installed at "
        "k3d already installed."
    Nothing ->
      shells
        "curl -L https://github.com/k3d-io/k3d/releases/download/v5.9.0/k3d-linux-arm64 -o k3d"
        empty
        >> chmod executable "./k3d"
        >> shells "sudo mv ./k3d /usr/local/bin/k3d" empty

-- | Switched from tofi (built from source, no Fedora package) to fuzzel
-- (a plain dnf package on Fedora 44 aarch64) -- fuzzel is the same
-- lightweight, wlroots-native launcher lineage as tofi but with nicer
-- default rendering (real icon-theme support, smoother fonts) and no
-- meson/ninja build step needed. Unlike tofi, fuzzel already honors the
-- active keyboard layout/remaps for its own shortcuts out of the box, so
-- there's no equivalent to tofi's physical-keybindings gotcha here.
installFuzzel :: IO ()
installFuzzel =
  dnfInstall
    "fuzzel"
    "fuzzel"
    "fuzzel already installed at "
    "fuzzel already installed."

-- | fuzzel's own defaults are already Solarized Light; fuzzel/fuzzel.ini
-- is the Solarized Dark equivalent (Solarized's own documented
-- light/dark role swap of the same accent colors). See that file's own
-- header comment for the exact mapping.
writeFuzzelConfig :: IO ()
writeFuzzelConfig = do
  curdir <- pwd
  homeDir <- home
  let configDir = homeDir </> ".config/fuzzel"
  alreadyExists <- testfile (configDir </> "fuzzel.ini")
  if alreadyExists
    then echo "~/.config/fuzzel/fuzzel.ini already present, leaving it untouched."
    else do
      mktree configDir
      cp (curdir </> "fuzzel/fuzzel.ini") (configDir </> "fuzzel.ini")
      echo "Wrote ~/.config/fuzzel/fuzzel.ini (Solarized Dark)."

-- | Same solopasha/hyprland COPR as installHyprland below -- these close
-- a gap hyprland.conf used to document explicitly ("mod-shift-l screen
-- lock (no lock daemon set up for this session)"): `loginctl
-- lock-session` existed as a command, but nothing was listening for the
-- Lock signal, so it was a silent no-op. hyprlock (the lock screen) and
-- hypridle (its idle-timeout/before-suspend trigger) are both from the
-- same maintainer/ecosystem as Hyprland itself.
installHyprlockAndHypridle :: IO ()
installHyprlockAndHypridle = do
  dnfInstall
    "hyprlock"
    "hyprlock"
    "hyprlock already installed at "
    "hyprlock already installed."
  dnfInstall
    "hypridle"
    "hypridle"
    "hypridle already installed at "
    "hypridle already installed."

-- | Both hyprlock and hypridle read from ~/.config/hypr/ directly (the
-- same directory hyprland.conf itself lives in), not their own
-- subdirectories.
writeHyprlockConfig :: IO ()
writeHyprlockConfig = do
  curdir <- pwd
  homeDir <- home
  let configDir = homeDir </> ".config/hypr"
  alreadyExists <- testfile (configDir </> "hyprlock.conf")
  if alreadyExists
    then echo "~/.config/hypr/hyprlock.conf already present, leaving it untouched."
    else do
      mktree configDir
      cp (curdir </> "hypr/hyprlock.conf") (configDir </> "hyprlock.conf")
      echo "Wrote ~/.config/hypr/hyprlock.conf (Solarized Dark)."

writeHypridleConfig :: IO ()
writeHypridleConfig = do
  curdir <- pwd
  homeDir <- home
  let configDir = homeDir </> ".config/hypr"
  alreadyExists <- testfile (configDir </> "hypridle.conf")
  if alreadyExists
    then echo "~/.config/hypr/hypridle.conf already present, leaving it untouched."
    else do
      mktree configDir
      cp (curdir </> "hypr/hypridle.conf") (configDir </> "hypridle.conf")
      echo "Wrote ~/.config/hypr/hypridle.conf."

-- | Hyprland ships no wallpaper support of its own -- that's explicitly
-- out of compositor scope, delegated to a separate client. hyprpaper is
-- the official daemon from the same maintainer/ecosystem as Hyprland
-- itself, same precedent as hyprlock/hypridle above (chosen over a
-- third-party alternative like swww).
installHyprpaper :: IO ()
installHyprpaper =
  dnfInstall
    "hyprpaper"
    "hyprpaper"
    "hyprpaper already installed at "
    "hyprpaper already installed."

-- | The actual wallpaper (a Wallhaven torii-gate/samurai-sunset piece,
-- picked for its orange/purple palette -- a close match to Solarized
-- Dark's accent colors, see plasma/SolarizedDark.colors) is fetched from
-- Wallhaven's CDN rather than committed to this repo: Wallhaven image
-- IDs are stable/immutable, and a 12MB binary doesn't belong in git
-- history -- same "fetch live instead of vendoring" reasoning as
-- installHackNerdFont above.
installWallpaper :: IO ()
installWallpaper = do
  homeDir <- home
  let picturesDir = homeDir </> "Pictures"
      wallpaperPath = picturesDir </> "torii-samurai-sunset-x62pzo.jpg"
  alreadyExists <- testfile wallpaperPath
  if alreadyExists
    then echo "~/Pictures/torii-samurai-sunset-x62pzo.jpg already present, leaving it untouched."
    else do
      mktree picturesDir
      shells
        ( "curl -fsSL -A Mozilla/5.0 -o "
            <> format fp wallpaperPath
            <> " https://w.wallhaven.cc/full/x6/wallhaven-x62pzo.jpg"
        )
        empty
      echo "Downloaded ~/Pictures/torii-samurai-sunset-x62pzo.jpg (Wallhaven)."

-- | Unlike hyprlock.conf/hypridle.conf above, hyprpaper.conf isn't a
-- static committed dotfile -- it needs the wallpaper's real absolute
-- path baked in, generated here from the actual $HOME rather than
-- hand-hardcoding /home/josiah into a file this repo tracks.
writeHyprpaperConfig :: IO ()
writeHyprpaperConfig = do
  homeDir <- home
  let configDir = homeDir </> ".config/hypr"
      configPath = configDir </> "hyprpaper.conf"
      wallpaperPathText = format fp (homeDir </> "Pictures/torii-samurai-sunset-x62pzo.jpg")
  alreadyExists <- testfile configPath
  if alreadyExists
    then echo "~/.config/hypr/hyprpaper.conf already present, leaving it untouched."
    else do
      mktree configDir
      writeTextFile
        configPath
        ( "preload = "
            <> wallpaperPathText
            <> "\nwallpaper = ,"
            <> wallpaperPathText
            <> "\nsplash = false\n"
        )
      echo "Wrote ~/.config/hypr/hyprpaper.conf."

-- | Hyprland has no Fedora repo package at all (a licensing/policy gap
-- historically, not a technical one), so this uses solopasha/hyprland,
-- a COPR verified to (a) actually exist, (b) explicitly support
-- fedora-44-aarch64 (this exact system), and (c) have recent successful
-- builds for it -- checked directly against the COPR API rather than
-- trusted from a search result, after an earlier plausible-sounding COPR
-- name turned out not to exist at all.
--
-- As of this writing, that COPR's aquamarine 0.9.5-2 build requires
-- libdisplay-info.so.2, but Fedora's own libdisplay-info-0.3.0 now
-- provides libdisplay-info.so.3 -- a build-environment mismatch (the
-- COPR was built against an older libdisplay-info than Fedora currently
-- ships), not a real API incompatibility: confirmed by rebuilding the
-- exact same upstream aquamarine source locally against this system's
-- actual libdisplay-info headers, which links fine and correctly
-- requires .so.3. If the plain install hits this, rebuildAquamarine
-- below does exactly that rebuild-and-retry rather than giving up.
--
-- hyprland.conf (this repo's hypr/hyprland.conf) maps josiah's actual
-- xmonad.hs as closely as Hyprland's dispatchers allow; see that file's
-- own header comment for what maps cleanly and what's a known,
-- accepted gap (no Xinerama-style workspace swapping between monitors).
--
-- Not addressed here: Waybar's Hyprland-workspace module can break
-- across Hyprland version bumps due to IPC changes (a known, cosmetic-
-- only risk -- worst case the workspace widget misbehaves, not a
-- broken system). The COPR offers a version-matched waybar-git build;
-- this script sticks with the plain Fedora waybar already installed
-- above rather than pull in another COPR package with its own
-- conflict surface, and flags this here so it's easy to find if it
-- ever comes up.
installHyprland :: IO ()
installHyprland =
  which "Hyprland"
    >>= \case
      Just hyprlandLoc ->
        echoWhichLocation
          hyprlandLoc
          "Hyprland already installed at "
          "Hyprland already installed."
      Nothing -> do
        shells "sudo dnf copr enable -y solopasha/hyprland" empty
        -- hyprland-qtutils provides Qt-based helper dialogs Hyprland
        -- itself uses (e.g. its own update-available notification).
        -- Without it, Hyprland shows a startup toast warning it's
        -- missing (confirmed directly: seen on this machine before this
        -- was added) -- harmless, but the warning's easy to mistake for
        -- something more serious.
        shell "sudo dnf install -y hyprland xdg-desktop-portal-hyprland hyprland-qtutils" empty
          >>= \case
            ExitSuccess -> return ()
            ExitFailure _ -> rebuildAquamarineThenInstallHyprland
        writeHyprlandConfig

-- | Fallback for the aquamarine/libdisplay-info soname mismatch
-- described in installHyprland's comment above: install the build
-- toolchain, pull the aquamarine SRPM from the same COPR, rebuild it
-- locally against this system's actual libdisplay-info, install the
-- result, then retry the Hyprland install on top of it.
rebuildAquamarineThenInstallHyprland :: IO ()
rebuildAquamarineThenInstallHyprland = do
  echo "Plain Hyprland install failed -- rebuilding aquamarine locally against this system's libdisplay-info and retrying (see installHyprland's comment for why)."
  shells
    "sudo dnf install -y cmake gcc-c++ mesa-libEGL-devel pkgconf-pkg-config \
    \mesa-libgbm-devel hwdata-devel hyprutils-devel hyprwayland-scanner-devel \
    \libdisplay-info-devel libdrm-devel libinput-devel libseat-devel \
    \systemd-devel pixman-devel wayland-devel wayland-protocols-devel rpm-build"
    empty
  shells
    "rm -rf aquamarine-rebuild && mkdir aquamarine-rebuild \
    \&& cd aquamarine-rebuild \
    \&& dnf download --source aquamarine \
    \--repo=copr:copr.fedorainfracloud.org:solopasha:hyprland \
    \&& rpmbuild --rebuild ./*.src.rpm \
    \&& cd .. && rm -rf aquamarine-rebuild"
    empty
  shells
    "sudo dnf install -y \
    \$HOME/rpmbuild/RPMS/aarch64/aquamarine-[0-9]*.rpm \
    \$HOME/rpmbuild/RPMS/aarch64/aquamarine-devel-[0-9]*.rpm \
    \hyprland xdg-desktop-portal-hyprland hyprland-qtutils"
    empty

writeHyprlandConfig :: IO ()
writeHyprlandConfig = do
  curdir <- pwd
  homeDir <- home
  let configDir = homeDir </> ".config/hypr"
      configPath = configDir </> "hyprland.conf"
      scriptsDir = configDir </> "scripts"
  alreadyExists <- testfile configPath
  -- Hyprland itself autogenerates a stock hyprland.conf (marked with its
  -- own "autogenerated = 1" line) the moment the package is installed --
  -- before this function ever runs -- so "the file exists" can't be used
  -- to mean "josiah customized it". Only that marker means stock/safe to
  -- overwrite; anything else existing is treated as a real customization.
  isStockAutogenerated <-
    if not alreadyExists
      then return False
      else isInfixOf (pack "autogenerated = 1") <$> strict (input configPath)
  if alreadyExists && not isStockAutogenerated
    then echo "~/.config/hypr/hyprland.conf already present and customized, leaving it untouched."
    else do
      mktree configDir
      cp (curdir </> "hypr/hyprland.conf") configPath
      echo "Wrote ~/.config/hypr/hyprland.conf (master layout, xmonad-mapped keybinds, waybar, fuzzel launcher)."
  -- Deployed unconditionally, unlike hyprland.conf above: mod-Return and
  -- mod-? in this repo's hyprland.conf call these scripts directly
  -- regardless of whether the config file itself was left untouched, so
  -- they need to exist either way. Copies every script in
  -- hypr/scripts/ via a plain shell glob rather than naming each one,
  -- so adding a new script here doesn't also require a matching
  -- Main.hs edit.
  mktree scriptsDir
  shells
    ( "cp "
        <> format fp (curdir </> "hypr/scripts")
        <> "/*.sh "
        <> format fp scriptsDir
        <> "/ && chmod +x "
        <> format fp scriptsDir
        <> "/*.sh"
    )
    empty

-- | Unlike Hyprland, Waybar never writes anything into ~/.config on its
-- own -- with no user config present it just falls back to reading
-- /etc/xdg/waybar/ at runtime, so a plain existence check (no
-- autogenerated-marker check needed, contrast writeHyprlandConfig above)
-- is enough to tell "josiah customized it" apart from "never configured".
writeWaybarConfig :: IO ()
writeWaybarConfig = do
  curdir <- pwd
  homeDir <- home
  let configDir = homeDir </> ".config/waybar"
  alreadyExists <- testfile (configDir </> "config.jsonc")
  if alreadyExists
    then echo "~/.config/waybar/config.jsonc already present, leaving it untouched."
    else do
      mktree configDir
      cp (curdir </> "waybar/config.jsonc") (configDir </> "config.jsonc")
      cp (curdir </> "waybar/style.css") (configDir </> "style.css")
      echo "Wrote ~/.config/waybar/{config.jsonc,style.css} (hyprland/* modules, slim bar)."

-- | waybar's custom/camera module (hypr/scripts/camera-status.sh) toggles
-- the webcam by rmmod/modprobe-ing apple_isp -- confirmed a clean,
-- self-contained kernel module (lsmod use-count 0, nothing depends on
-- it) rather than being compiled into the kernel image, so this fully
-- removes/restores /dev/video0. A waybar click can't answer an
-- interactive sudo password prompt, so this needs a NOPASSWD rule --
-- scoped to exactly these two commands, nothing else. Validated with
-- `visudo -c` before being installed, since a syntax error in any
-- sudoers file (not just this one) breaks sudo system-wide -- confirmed
-- this is the standard safe way to hand-install a sudoers.d drop-in.
writeCameraToggleSudoers :: IO ()
writeCameraToggleSudoers = do
  let sudoersPath = "/etc/sudoers.d/asahi-camera-toggle" :: Turtle.FilePath
      tmpPath = "/tmp/asahi-camera-toggle" :: Turtle.FilePath
      rule = "josiah ALL=(root) NOPASSWD: /usr/sbin/modprobe apple_isp, /usr/sbin/rmmod apple_isp\n"
  -- `testfile` stats as the invoking user; /etc/sudoers.d is root:root
  -- drwxr-x--- (confirmed directly), so josiah can't even look inside it
  -- and testfile always silently reports "does not exist" regardless of
  -- the real state -- meaning this guard did nothing and the rule was
  -- being reinstalled unconditionally on every run. `sudo test -f`
  -- elevates first, so it actually reflects reality.
  alreadyExists <-
    shell ("sudo test -f " <> format fp sudoersPath) empty
      >>= \case
        ExitSuccess -> return True
        ExitFailure _ -> return False
  if alreadyExists
    then echo "/etc/sudoers.d/asahi-camera-toggle already present, leaving it untouched."
    else do
      writeTextFile tmpPath rule
      shell ("visudo -c -f " <> format fp tmpPath) empty
        >>= \case
          ExitSuccess -> return ()
          ExitFailure _ ->
            die "ERROR: generated sudoers rule for the camera-toggle waybar button failed visudo validation"
      shells
        ( "sudo install -m 0440 -o root -g root "
            <> format fp tmpPath
            <> " "
            <> format fp sudoersPath
        )
        empty
      shells ("rm " <> format fp tmpPath) empty
      echo "Installed a scoped NOPASSWD sudoers rule (modprobe/rmmod apple_isp only) for the waybar camera-toggle button."

-- | Fedora's own `emacs` package already builds with
-- --with-native-compilation=aot (confirmed by reading emacs.spec out of
-- the fc44 SRPM), so a plain dnf install doesn't actually get you
-- anything extra -- the real ask here is a build tuned specifically for
-- this machine's CPU (-mcpu=native, confirmed via a live
-- `gcc -mcpu=native -Q --help=target` to resolve to
-- apple-m2+crc+aes+sha3+fp16 on this exact M2 Max), which only a local
-- build provides.
--
-- Configure flags below are Fedora's own pgtk-variant flags (pure GTK3,
-- native Wayland via GDK, no XWayland dependency), read directly out of
-- emacs.spec rather than guessed, plus CFLAGS="-O2 -mcpu=native" layered
-- on top -- -O2 matches Fedora's own optimization level exactly, so the
-- only actual change from Fedora's own build is the CPU-specific
-- codegen (bumping the -O level wasn't asked for and risks subtle
-- miscompiles in GC-sensitive C code for no requested benefit).
--
-- GC is tuned at runtime instead of at build time -- see emacs/init.el.
-- The experimental MPS/IGC garbage collector only exists on Emacs's
-- unmerged feature/igc branch, not on any tagged release, so it's out
-- of scope here.
--
-- Needs libtree-sitter0.25-devel specifically, NOT the ambiguous
-- libtree-sitter-devel: vanilla (unpatched) Emacs 30.2 needs
-- tree-sitter < 0.26 (Fedora's own spec gates this with
-- `%if v"%{version}" < v"31"` -> `pkgconfig(tree-sitter) < 0.26`, and its
-- changelog notes Fedora's own build needed a dedicated patch to work
-- with tree-sitter 0.26+ -- a patch this vanilla build doesn't have).
-- Plain `libtree-sitter-devel` resolves to whichever of its two
-- available versions (0.25.10 or 0.26.9) dnf picks as "latest", which
-- isn't reliably the older one; libtree-sitter0.25-devel is a
-- separately-named compat package that pins the older ABI on purpose.
-- It Conflicts: libtree-sitter-devel at the RPM level (so the two
-- package names can never coexist) but NOT with the plain
-- `libtree-sitter` *runtime* package, which already ships both the
-- .so.0.25 and .so.0.26 sonames side by side -- confirmed directly
-- against the actual RPM Provides/Conflicts/file lists, not assumed.
-- That matters because neovim's own dnf package requires
-- libtree-sitter >= 0.26.7 -- so Emacs's older build-time tree-sitter
-- ABI and neovim's newer runtime one are both satisfied at once, with
-- no conflict, regardless of which gets installed first.
installEmacsFromSource :: IO ()
installEmacsFromSource =
  which "emacs"
    >>= \case
      Just emacsLoc ->
        echoWhichLocation
          emacsLoc
          "Emacs already installed at "
          "Emacs already installed."
      Nothing -> do
        shells
          "sudo dnf install -y gcc gcc-c++ make autoconf automake pkgconf-pkg-config \
          \texinfo gnutls-devel ncurses-devel gtk3-devel libgccjit-devel \
          \jansson-devel harfbuzz-devel cairo-devel librsvg2-devel \
          \giflib-devel libjpeg-turbo-devel libpng-devel libtiff-devel \
          \libwebp-devel libxml2-devel sqlite-devel dbus-devel \
          \libtree-sitter0.25-devel"
          empty
        shells
          "curl -LO https://ftp.gnu.org/gnu/emacs/emacs-30.2.tar.xz \
          \&& tar xf emacs-30.2.tar.xz \
          \&& cd emacs-30.2 \
          \&& CFLAGS=\"-O2 -mcpu=native\" ./configure \
          \--disable-gc-mark-trace --with-cairo --with-dbus --with-gif \
          \--with-gpm=no --with-harfbuzz --with-jpeg --with-modules \
          \--with-native-compilation=aot --with-pgtk --with-png \
          \--with-rsvg --with-sqlite3 --with-tiff --with-tree-sitter \
          \--with-webp --with-xpm \
          \&& make -j$(nproc) \
          \&& sudo make install \
          \&& cd .. && rm -rf emacs-30.2 emacs-30.2.tar.xz"
          empty
        writeEmacsInitEl

-- | Idempotent copy of this repo's emacs/init.el (just the GC-threshold
-- tuning actually asked for -- see that file's own header comment) to
-- ~/.config/emacs/init.el, same pattern as writeKxkbrcKeyRemaps and
-- writeHyprlandConfig above.
--
-- Currently unreachable on this machine: its only caller,
-- installEmacsFromSource, only invokes it from the branch taken when
-- `which "emacs"` finds nothing, and Emacs is already installed here --
-- so this hasn't run, and won't run again, unless Emacs is uninstalled
-- first. Not dead code to remove, just confirmed dormant (and confirmed
-- harmless if it ever did fire: Doom Emacs's own install backed the
-- original ~/.config/emacs up to ~/.config/emacs.pre-doom-backup/, whose
-- init.el is byte-identical to this repo's emacs/init.el anyway).
writeEmacsInitEl :: IO ()
writeEmacsInitEl = do
  curdir <- pwd
  homeDir <- home
  let configDir = homeDir </> ".config/emacs"
      initPath = configDir </> "init.el"
  alreadyExists <- testfile initPath
  if alreadyExists
    then echo "~/.config/emacs/init.el already present, leaving it untouched."
    else do
      mktree configDir
      cp (curdir </> "emacs/init.el") initPath
      echo "Wrote ~/.config/emacs/init.el (gc-cons-threshold/percentage tuning)."

-- | Copies this repo's doom/ directory to ~/.config/doom, same pattern as
-- writeNvimConfig's `cp -r nvim ~/.config/nvim`.
writeDoomConfig :: IO ()
writeDoomConfig = do
  curdir <- pwd
  homeDir <- home
  let configDir = homeDir </> ".config/doom"
  alreadyExists <- testdir configDir
  if alreadyExists
    then echo "~/.config/doom already present, leaving it untouched."
    else do
      shells ("cp -r " <> format fp (curdir </> "doom") <> " " <> format fp configDir) empty
      echo "Wrote ~/.config/doom (Doom Emacs private config)."

-- | Moves the existing plain (vanilla-init.el-only) ~/.config/emacs aside
-- rather than clobbering it, clones doomemacs/core fresh into ~/.config/emacs
-- (doomemacs/doomemacs redirects there now -- cloning the current canonical
-- name directly), and runs the non-interactive install+sync sequence.
-- Idempotent on the presence of ~/.config/emacs/bin/doom (Doom's own CLI),
-- not on ~/.config/emacs itself, since the latter already exists from
-- installEmacsFromSource.
installDoomEmacs :: IO ()
installDoomEmacs = do
  homeDir <- home
  let emacsDir = homeDir </> ".config/emacs"
      doomBin = emacsDir </> "bin/doom"
      backupDir = homeDir </> ".config/emacs.pre-doom-backup"
  alreadyInstalled <- testfile doomBin
  if alreadyInstalled
    then echo "Doom Emacs already installed at ~/.config/emacs/bin/doom."
    else do
      vanillaEmacsDirExists <- testdir emacsDir
      backupAlreadyExists <- testdir backupDir
      if vanillaEmacsDirExists && not backupAlreadyExists
        then do
          shells ("mv " <> format fp emacsDir <> " " <> format fp backupDir) empty
          echo "Moved existing ~/.config/emacs (vanilla init.el) aside to ~/.config/emacs.pre-doom-backup."
        else return ()
      shells ("git clone https://github.com/doomemacs/core " <> format fp emacsDir) empty
      -- --force (-!) suppresses interactive prompts; DOOMDIR files already
      -- exist from writeDoomConfig above, so the "create dummy files" step
      -- inside `doom install` silently no-ops. `doom install`'s own logic
      -- runs `git submodule update -f --init --recursive` internally,
      -- populating the separate doomemacs/modules submodule -- no
      -- --recurse-submodules needed on the clone itself.
      shells (format fp doomBin <> " install --force --no-hooks") empty
      -- `--aot`: ahead-of-time native-compile packages (explicit ask;
      -- Doom stopped doing this by default a while back). `--env`:
      -- (re)generate the envvar file Doom loads at startup, capturing this
      -- shell's PATH (~/.ghcup/bin, ~/.cargo/bin, raco's bin dir, etc.) so
      -- a Hyprland/fuzzel-launched Emacs still finds these LSP servers --
      -- same PATH-visibility problem this repo already solved for Mason/
      -- nvim and qt6ct. A bare `doom env` is dead in this Doom version
      -- (confirmed directly against bin/doom-env's source, which now
      -- errors and tells you to run `doom sync --env` instead).
      shells (format fp doomBin <> " sync --aot --env") empty
      -- `--gc` is NOT a `doom sync`/`doom install` flag on current Doom --
      -- confirmed directly against bin/doom's own `defcli-obsolete!`
      -- table: `doom purge`/`-p` (what `--gc` used to trigger as part of a
      -- sync on older Doom versions, e.g. the pinned commit docker-emacs's
      -- own Haskell/systems-ide images still build against) was split into
      -- a standalone top-level `doom gc` command as of Doom 2.1.0. Calling
      -- it separately here is the current equivalent of that same intent
      -- (garbage-collect orphaned packages, compact repos).
      shells (format fp doomBin <> " gc") empty
      -- Non-fatal sanity check, deliberately using `shell` (not `shells`):
      -- confirmed the hard way that `shells` DOES check the exit code and
      -- throws Turtle's `ShellFailed` on nonzero (this is `shells`'s whole
      -- purpose -- the earlier comment here claiming it was "intentionally
      -- unchecked" was simply wrong). `doom doctor` is a diagnostic tool
      -- that legitimately exits nonzero on cosmetic/optional warnings (a
      -- missing icon font, an unset optional module dependency, etc.) that
      -- don't mean the install itself failed -- letting it throw here would
      -- abort this entire provisioning script partway through, which is
      -- exactly what happened once already (confirmed live: a `doom doctor`
      -- warning unrelated to Doom's own health -- Doom's own `:lang go`
      -- module doctor.el bug, see packages.el's company-go comment -- took
      -- down the whole run before it ever reached racket-langserver/zig/
      -- zls/sbcl/quicklisp or anything after them).
      shell (format fp doomBin <> " doctor") empty
      echo "Doom Emacs installed, synced (--aot --env), garbage-collected, and doctor-checked."

-- | racket-langserver is a Racket *package* (loaded via `racket -l
-- racket-langserver`, not a standalone `which`-able binary), so idempotency
-- is checked via `raco pkg show`'s exit code rather than this file's usual
-- which-based pattern. Confirmed live: `raco pkg install --dry-run --auto
-- racket-langserver` resolves fine, pulling straight from
-- jeapostrophe/racket-langserver on GitHub plus its dependencies
-- (html-parsing, fixw, profile-flame-graph). Must run after racket itself
-- is installed (see the dnfInstall "racket" call above).
installRacketLangserver :: IO ()
installRacketLangserver =
  shell "raco pkg show racket-langserver" empty
    >>= \case
      ExitSuccess -> echo "racket-langserver already installed."
      ExitFailure _ -> do
        shells "raco pkg install --auto racket-langserver" empty
        echo "Installed racket-langserver (via raco) for Doom's :lang racket +lsp."

-- | Fedora ships a genuine aarch64 zig build (confirmed:
-- zig-0.16.0-1.fc44.aarch64.rpm in the aarch64 updates repo) -- Zig is not
-- absent from distro repos the way it once was. Plain dnf install suffices.
installZig :: IO ()
installZig =
  dnfInstall
    "zig"
    "zig"
    "Zig already installed at "
    "Zig already installed."

-- | zls has no Fedora package (confirmed: packages.fedoraproject.org/pkgs/zls
-- 404s) -- fetched directly from zigtools/zls's own GitHub release, same
-- "no clean package, download it" pattern as installHackNerdFont/
-- papirus-folders. Must run after installZig: reads `zig version` to fetch
-- the exact matching zls release tag, since zls requires an exact version
-- match with zig (confirmed both are on 0.16.0 right now, but the two
-- projects release independently and could drift apart later). Installed
-- to /usr/local/bin (already on every shell's PATH) rather than left to
-- Mason: Mason's own zls copy (used by nvim, see writeNvimConfig) lives
-- under ~/.local/share/nvim/mason/ and is never on the general PATH, so
-- Doom needs its own independent copy -- the duplication is deliberate.
installZls :: IO ()
installZls =
  which "zls"
    >>= \case
      Just zlsLoc ->
        echoWhichLocation zlsLoc "zls already installed at " "zls already installed."
      Nothing -> do
        (_, zigVersionText, _) <- shellStrictWithErr "zig version" empty
        let zigVersion = strip zigVersionText
        shells
          ( "curl -fsSL -o zls.tar.xz https://github.com/zigtools/zls/releases/download/"
              <> zigVersion
              <> "/zls-aarch64-linux.tar.xz \
                 \&& tar xf zls.tar.xz \
                 \&& chmod +x zls \
                 \&& sudo mv zls /usr/local/bin/zls \
                 \&& rm -f zls.tar.xz README.md LICENSE"
          )
          empty
        echo "Installed zls to /usr/local/bin, matching the installed zig version."

-- | Mirrors installNixfmt's exact `nix profile install` pattern -- nil (the
-- Nix LSP nvim already uses via Mason) has no Fedora package at all
-- (confirmed: absent from the aarch64 package listing). Doom's :lang nix
-- +lsp module needs its own system-wide copy for the same PATH-visibility
-- reason as zls above -- Mason's copy is nvim-only.
installNil :: IO ()
installNil =
  which "nil"
    >>= \case
      Just nilLoc -> echoWhichLocation nilLoc "nil already installed at " "nil already installed."
      Nothing -> shells "nix profile install nixpkgs#nil" empty

-- | shellcheck IS a real Fedora aarch64 package (confirmed:
-- ShellCheck-0.11.0-4.fc44.aarch64.rpm) -- Mason's copy (nvim-only) doesn't
-- help Doom's :checkers syntax module, so install it system-wide too.
installShellcheckSystemWide :: IO ()
installShellcheckSystemWide =
  dnfInstall "shellcheck" "ShellCheck" "shellcheck already installed at " "shellcheck already installed."

-- | rust-analyzer IS a real Fedora aarch64 package (confirmed:
-- rust-analyzer-1.94.1-1.fc44.aarch64.rpm) -- same Mason-is-nvim-only
-- reasoning as nil/shellcheck above.
installRustAnalyzerSystemWide :: IO ()
installRustAnalyzerSystemWide =
  dnfInstall "rust-analyzer" "rust-analyzer" "rust-analyzer already installed at " "rust-analyzer already installed."

-- | pyright has NO Fedora package -- confirmed live ("No match for
-- argument: pyright" from a real `dnf install`, contradicting an earlier,
-- wrong research claim that it was a real aarch64 noarch package). Its
-- actual, official distribution channel is npm (Microsoft publishes it
-- there; the PyPI package is a thin wrapper around the same npm-published
-- JS), so this uses the same `sudo npm install -g` pattern as
-- bash-language-server/fish-lsp below -- must run after npm itself is
-- installed, same ordering constraint as those two.
installPyrightSystemWide :: IO ()
installPyrightSystemWide =
  npmInstall "pyright" "pyright" "pyright already installed at " "pyright already installed."

-- | bash-language-server has no Fedora package -- installed via npm, same
-- `sudo npm install -g` pattern as installBitwardenCli. Must run after npm
-- itself is installed (the existing `dnfInstall "npm" "nodejs24-npm-bin"`
-- call).
installBashLanguageServerSystemWide :: IO ()
installBashLanguageServerSystemWide =
  npmInstall "bash-language-server" "bash-language-server" "bash-language-server already installed at " "bash-language-server already installed."

-- | fish-lsp: real, published npm package (confirmed via `npm view
-- fish-lsp bin`, which lists a `fish-lsp` executable) -- needed for
-- doom/lsp-clients.el's hand-rolled Fish LSP wiring, since Doom's `(sh
-- +fish)' flag only adds Fish syntax support, not LSP. Same npm pattern
-- and ordering constraint as bash-language-server above.
installFishLsp :: IO ()
installFishLsp =
  npmInstall "fish-lsp" "fish-lsp" "fish-lsp already installed at " "fish-lsp already installed."

-- | Claude Code has no Fedora package; Anthropic publishes it to npm
-- (@anthropic-ai/claude-code), same `sudo npm install -g` pattern as
-- bitwarden-cli/pyright/bash-language-server/fish-lsp above -- must run
-- after npm itself is installed. Needed on the host itself (not just
-- inside a faradai container) for non-containerized use and for setting up
-- credentials that faradai then mounts in.
installClaudeCode :: IO ()
installClaudeCode =
  npmInstall "claude" "@anthropic-ai/claude-code" "Claude Code already installed at " "Claude Code already installed."

-- | OpenCode has no Fedora package. Confirmed via `npm view opencode-ai`
-- that the published npm package declares `cpu: [arm64, x64]` and ships a
-- real `opencode-linux-arm64` optional binary dependency, so it's known-
-- good on this aarch64 machine. The project (now under anomalyco/opencode,
-- renamed from sst/opencode) also offers a curl installer and a Homebrew
-- tap, but npm fits this script's existing CLI-tool pattern -- same as
-- pyright/bash-language-server/fish-lsp/Claude Code above.
installOpenCodeCli :: IO ()
installOpenCodeCli =
  npmInstall "opencode" "opencode-ai" "OpenCode already installed at " "OpenCode already installed."

-- | aider-chat hard-requires Python <3.13 (`requires_python: <3.13,>=3.10`,
-- confirmed via PyPI's own metadata for 0.86.2, still the latest release
-- as of this writing despite being from 2026-02-12 -- aider pins its own
-- numpy/scipy dependencies to exact versions rather than ranges, an
-- unusually strict policy, so it can't just pick up whatever numpy has
-- wheels for a newer Python; its own pin has to be bumped first). Fedora
-- 44 ships only Python 3.14 system-wide (confirmed: no 3.10/3.11/3.12/3.13
-- package exists at all) -- installing aider against it isn't just a
-- missing-wheel inconvenience, aider's own metadata refuses anything
-- >=3.13 outright. `pipx install aider-chat` under the system Python
-- attempts to satisfy aider's hard-pinned `numpy==1.26.4` (which has no
-- cp313/cp314 wheels, confirmed via PyPI's file listing for that exact
-- version) by building it from source, which then fails on its own
-- (`BackendUnavailable: Cannot import 'setuptools.build_meta'`) --
-- confirmed live, this is not a hypothetical failure mode.
--
-- installAiderPython below builds a dedicated, aider-supported
-- interpreter via pyenv (needs installPyenv to have already run) rather
-- than touching the system Python at all; this then installs aider
-- against that interpreter specifically via `pipx install --python`.
installAiderCli :: IO ()
installAiderCli =
  which "aider"
    >>= \case
      Just loc -> echoWhichLocation loc "aider already installed at " "aider already installed."
      Nothing -> do
        homeDir <- home
        let aiderPython = homeDir </> ".pyenv/versions/3.12.13/bin/python"
        aiderPythonText <-
          either
            (const (die "Could not decode aider's pyenv Python interpreter path as UTF-8"))
            return
            (toText aiderPython)
        shells ("pipx install --python " <> aiderPythonText <> " aider-chat") empty

-- | Builds the dedicated Python interpreter installAiderCli above installs
-- aider-chat against, via pyenv (must run after installPyenv, which only
-- installs the pyenv tool itself, not any Python version through it).
-- 3.12.13 is the newest 3.12.x pyenv currently has a build definition
-- for (confirmed against pyenv's own python-build definitions) -- squarely
-- inside aider's supported <3.13,>=3.10 range, and 3.12 (unlike 3.13/3.14)
-- has real upstream numpy 1.26.4 wheels, so this never needs to build
-- numpy from source either.
installAiderPython :: IO ()
installAiderPython = do
  pyenvRoot <- fmap (</> ".pyenv") home
  -- Checking for the versioned directory alone isn't enough -- confirmed
  -- directly: an interrupted `pyenv install` (this one got killed by an
  -- overly short timeout during a manual test run) leaves that directory
  -- behind with empty bin/lib subdirectories and no actual python
  -- binary, which a plain testpath on the directory would misread as
  -- "already installed" and skip forever. Testing for the interpreter
  -- binary itself is the same fix class as writeGtkColorsCss/
  -- writeCameraToggleSudoers above: check the thing that actually matters,
  -- not a proxy for it.
  let pythonBin = pyenvRoot </> "versions/3.12.13/bin/python"
  pythonInstalled <- testfile pythonBin
  if pythonInstalled
    then echo "Python 3.12.13 (for aider, via pyenv) already installed."
    else do
      shells "PYENV_ROOT=\"$HOME/.pyenv\" \"$HOME/.pyenv/bin/pyenv\" install --force 3.12.13" empty
      echo "Installed Python 3.12.13 via pyenv (aider-chat requires <3.13; Fedora 44's system Python is 3.14)."

-- | taplo (TOML LSP -- needed for doom/lsp-clients.el's hand-rolled TOML
-- LSP wiring, since Doom has no official :lang toml module at all) has no
-- real Fedora package (the aarch64 listing's "taplot-*" hit is an
-- unrelated package, not TOML's taplo) -- installed via cargo (confirmed
-- real crate via `cargo search taplo` -> "taplo-cli"), same pattern as
-- librespot/spotify_player/neovide. Must run after installRustLang (needs
-- ~/.cargo/bin/cargo).
installTaplo :: IO ()
installTaplo =
  which "taplo"
    >>= \case
      Just loc -> echoWhichLocation loc "taplo already installed at " "taplo already installed."
      Nothing -> shells "$HOME/.cargo/bin/cargo install taplo-cli --locked" empty

-- | Only needed so Common Lisp's Sly REPL (Doom's :lang common-lisp module)
-- can actually launch -- the module's *highlighting* works without it.
-- Confirmed real Fedora aarch64 package (sbcl-2.6.5-2.fc44.aarch64.rpm).
installSbcl :: IO ()
installSbcl =
  dnfInstall "sbcl" "sbcl" "SBCL already installed at " "SBCL already installed."

-- | C's LSP support (Doom's (cc +lsp), nvim's clangd in lang-full.lua) both
-- need a real C compiler, not just clangd itself. gcc/make happen to
-- already land on this machine as a side effect of installEmacsFromSource's
-- own build-dependency list, but that's an accidental coupling -- C tooling
-- shouldn't depend on whether Emacs happened to need building from source.
-- Explicit and idempotent (dnfInstall's own `which` check no-ops if
-- installEmacsFromSource already pulled these in).
installCToolchain :: IO ()
installCToolchain = do
  dnfInstall "gcc" "gcc" "gcc already installed at " "gcc already installed."
  dnfInstall "make" "make" "make already installed at " "make already installed."

-- | Doom's `:tools direnv` module (doom/init.el) is enabled but doesn't
-- install the direnv binary itself -- `doom doctor` confirmed this live
-- ("Couldn't find direnv executable"). Real Fedora package.
installDirenv :: IO ()
installDirenv =
  dnfInstall "direnv" "direnv" "direnv already installed at " "direnv already installed."

-- | Quicklisp (Common Lisp's de facto package manager) -- needed for
-- nvim/lua/plugins/common-lisp.lua's Conjure+swank REPL support:
-- `(ql:quickload :swank)` in a plain `sbcl` session requires Quicklisp to
-- already be loadable, confirmed directly against Conjure's own
-- conjure-client-common-lisp-swank.txt doc. `(ql:add-to-init-file)`
-- registers Quicklisp's autoload in ~/.sbclrc so this works in any future
-- `sbcl` session without an extra manual `(load ...)` step -- the standard,
-- documented Quicklisp setup step, not a bespoke addition. NOT needed for
-- Doom's Sly (Doom's :lang common-lisp module, installSbcl above): Sly
-- bundles and loads its own slynk server directly, with no Quicklisp
-- dependency at all. Must run after installSbcl (needs the `sbcl` binary).
installQuicklisp :: IO ()
installQuicklisp = do
  homeDir <- home
  let quicklispDir = homeDir </> "quicklisp"
  alreadyExists <- testdir quicklispDir
  if alreadyExists
    then echo "~/quicklisp already present, leaving it untouched."
    else do
      shells
        "curl -fsSL -o /tmp/quicklisp.lisp https://beta.quicklisp.org/quicklisp.lisp \
        \&& sbcl --non-interactive --load /tmp/quicklisp.lisp \
        \--eval '(quicklisp-quickstart:install)' \
        \--eval '(ql:add-to-init-file)' \
        \&& rm -f /tmp/quicklisp.lisp"
        empty
      echo "Installed Quicklisp to ~/quicklisp and registered its autoload in ~/.sbclrc."

main :: IO ()
main = do
  shell "sudo dnf upgrade --refresh -y" empty
  dnfInstall
    "curl"
    "curl"
    "cURL already installed at "
    "cURL already installed."
  -- dnf-plugins-core is Fedora's equivalent of apt's
  -- software-properties-common (gives us `dnf config-manager`), and the
  -- rest of this batch is what GHCup needs to configure/build GHC, per
  -- https://www.haskell.org/ghcup/install/ 's Fedora prerequisites.
  -- kernel-devel is deliberately NOT here (unlike upstream's
  -- linux-headers-$(uname -r)): GHC is userspace and doesn't need Linux
  -- kernel headers at all, and on this Asahi image kernel-devel hard-
  -- conflicts with the already-installed asahi-platform-metapackage-core
  -- (which pins the Asahi kernel specifically), aborting the whole dnf5
  -- transaction -- confirmed by actually hitting this on a live run.
  -- kernel-headers alone is fine (already satisfied, no conflict).
  shells
    "sudo dnf install -y dnf-plugins-core \
    \gcc gcc-c++ make autoconf automake perl findutils tar \
    \ncurses-devel ncurses-compat-libs gmp-devel libffi-devel \
    \xz xz-devel bzip2-devel glibc-devel python3-tkinter \
    \kernel-headers"
    empty
  dnfInstall
    "ansible"
    "ansible-core"
    "ansible already installed at "
    "ansible already installed."
  -- herbstluftwm (upstream's alternate WM) is deliberately not installed:
  -- it's X11-only, and Hyprland below already fills that "alternate
  -- tiling WM" role as a Wayland-native compositor instead. It also has
  -- no path to even launch here (no Xorg session is configured on this
  -- image), unlike on the original Pop!_OS/X11 desktop it came from.
  -- blt-devel is a library with no binary of its own, so it doesn't fit
  -- the which-based dnfInstall pattern -- same as the KACST fonts and the
  -- mesa VA-API driver below.
  shells "sudo dnf install -y blt-devel" empty
  dnfInstall
    "bluedevil-wizard"
    "bluedevil"
    "bluedevil (Plasma's Bluetooth manager, replacing blueman) already installed at "
    "bluedevil already installed."
  dnfInstall
    "bt-adapter"
    "bluez-tools"
    "bluez-tools already installed at "
    "bluez-tools already installed."
  dnfInstall
    "brctl"
    "bridge-utils"
    "bridge-utils already installed at "
    "bridge-utils already installed."
  dnfInstall
    "bzip2"
    "bzip2"
    "bzip2 already installed at "
    "bzip2 already installed."
  dnfInstall
    "clamscan"
    "clamav"
    "ClamAV already installed at "
    "ClamAV already installed."
  dnfInstall
    "clamd"
    "clamd"
    "ClamAV daemon already installed at "
    "ClamAV daemon already installed."
  dnfInstall
    "cmake"
    "cmake"
    "cmake already installed at "
    "cmake already installed."
  dnfInstall
    "dash"
    "dash"
    "dash already installed at "
    "dash already installed."
  dnfInstall
    "dialog"
    "dialog"
    "dialog already installed at "
    "dialog already installed."
  dnfInstall
    "dmeventd"
    "device-mapper-event"
    "dmeventd already installed at "
    "dmeventd already installed."
  dnfInstall
    "expect"
    "expect"
    "expect already installed at "
    "expect already installed."
  dnfInstall
    "fd"
    "fd-find"
    "fd-find already installed at "
    "fd-find already installed."
  dnfInstall
    "fdisk"
    "util-linux"
    "fdisk already installed at "
    "fdisk already installed."
  dnfInstall
    "gdisk"
    "gdisk"
    "gdisk already installed at "
    "gdisk already installed."
  dnfInstall
    "file"
    "file"
    "file already installed at "
    "file already installed."
  dnfInstall
    "firejail"
    "firejail"
    "firejail already installed at "
    "firejail already installed."
  dnfInstall
    "firetools"
    "firetools"
    "firetools already installed at "
    "firetools already installed."
  -- Fedora splits KACST (Arabic) fonts into many small subpackages rather
  -- than the two bundles upstream's apt install expected (fonts-arabeyes,
  -- fonts-kacst are actually the same font family); kacst-office-fonts is
  -- a reasonable single stand-in for both.
  shells "sudo dnf install -y kacst-office-fonts" empty
  -- wl-clipboard (wl-copy/wl-paste) replaces upstream's xclip, which is
  -- X11-only and doesn't work under either of this system's Wayland
  -- sessions.
  dnfInstall
    "wl-copy"
    "wl-clipboard"
    "wl-clipboard already installed at "
    "wl-clipboard already installed."
  dnfInstall
    "ecryptfs-setup-private"
    "ecryptfs-utils"
    "eCryptFS already installed at "
    "eCryptFS already installed."
  dnfInstall
    "git"
    "git"
    "Git already installed at "
    "Git already installed."
  dnfInstall
    "gh"
    "gh"
    "GitHub CLI already installed at "
    "GitHub CLI already installed."
  -- Plasma's own GTK-consistency stack, replacing gnome-tweaks (System
  -- Settings already covers everything else gnome-tweaks did).
  shells "sudo dnf install -y kde-gtk-config breeze-gtk" empty
  dnfInstall
    "kvantummanager"
    "kvantum"
    "Kvantum already installed at "
    "Kvantum already installed."
  -- Fedora's own gstreamer plugin packages, without pulling in RPM Fusion
  -- (a separate trust decision this script isn't making on your behalf).
  shells
    "sudo dnf install -y gstreamer1-plugins-base gstreamer1-plugins-good \
    \gstreamer1-plugins-bad-free gstreamer1-plugins-ugly-free \
    \gstreamer1-plugin-openh264 gstreamer1-vaapi"
    empty
  dnfInstall
    "gtk-murrine-engine"
    "gtk-murrine-engine"
    "gtk-murrine-engine already installed at "
    "gtk-murrine-engine already installed."
  dnfInstall
    "htop"
    "htop"
    "htop already installed at "
    "htop already installed."
  dnfInstall
    "ibus-setup"
    "ibus-mozc"
    "ibus-mozc already installed at "
    "ibus-mozc already installed."
  installIceSsb
  installSlacky
  dnfInstall
    "jq"
    "jq"
    "jq already installed at "
    "jq already installed."
  dnfInstall
    "kpartx"
    "kpartx"
    "kpartx already installed at "
    "kpartx already installed."
  dnfInstall
    "vim"
    "vim-enhanced"
    "Vim already installed at "
    "Vim already installed."
  -- GVim (vim-X11) is deliberately not installed: it's built against X11
  -- specifically, and terminal Vim above already covers editing under
  -- either Wayland session with no X11/XWayland dependency at all.
  --
  -- neovim itself, found missing while auditing tree-sitter version
  -- constraints for installEmacsFromSource above: installNeovide (further
  -- down in this file) builds Neovide, a GUI frontend that execs the
  -- system `nvim` binary as a subprocess rather than bundling Neovim --
  -- without this, Neovide has nothing to actually run.
  dnfInstall
    "nvim"
    "neovim"
    "Neovim already installed at "
    "Neovim already installed."
  installHaskellToolchain
  dnfInstall
    "lpass"
    "lastpass-cli"
    "LastPass CLI client already installed at "
    "LastPass CLI client already installed."
  dnfInstall
    "lvm2"
    "lvm2"
    "lvm2 already installed at "
    "lvm2 already installed."
  -- egl-utils (eglinfo) replaces upstream's mesa-utils (glxinfo): GLX is
  -- an X11-specific OpenGL extension, so glxinfo can't query anything
  -- meaningful without an X server. eglinfo is the equivalent diagnostic
  -- for the EGL path both Wayland sessions here actually use.
  dnfInstall
    "eglinfo"
    "egl-utils"
    "egl-utils already installed at "
    "egl-utils already installed."
  -- Apple Silicon's GPU driver comes from Asahi's own mesa COPR (already
  -- enabled by default on this image), not from any Intel/AMD/nvidia
  -- driver package -- so this replaces upstream's va-driver-all,
  -- i965-va-driver, intel-media-va-driver-non-free, and all the
  -- nvidia-*/system76-* hardware packages, none of which apply here.
  shells "sudo dnf install -y mesa-va-drivers libva-utils" empty
  -- Google never officially ships a Widevine CDM for aarch64 Linux, so
  -- DRM-gated web playback (Spotify's web player, Netflix, etc.) fails
  -- in every browser here (Firefox, Chromium/Brave, all flatpak aarch64
  -- builds) without it. This is the Asahi Linux project's own package
  -- (https://github.com/AsahiLinux/widevine-installer, in Fedora's repos
  -- directly, no extra COPR), which adapts Google's ChromeOS arm64 CDM
  -- build to run on vanilla ARM64 Linux (including this kernel's 16K
  -- page size) rather than shipping a new CDM. Installing the package
  -- alone isn't enough -- see the `sudo widevine-installer` note in this
  -- file's header comment.
  dnfInstall
    "widevine-installer"
    "widevine-installer"
    "Widevine CDM installer already installed at "
    "Widevine CDM installer already installed."
  dnfInstall
    "most"
    "most"
    "most already installed at "
    "most already installed."
  dnfInstall
    "psql"
    "postgresql-server"
    "postgresql already installed at "
    "postgresql already installed."
  dnfInstall
    "pass"
    "pass"
    "pass already installed at "
    "pass already installed."
  -- cups (upstream: snap), glow and emacs (upstream: snap) all turned up
  -- confirmed-available during research earlier but never actually made
  -- it into this file until now -- a real gap, not a deliberate skip.
  -- cups is a print daemon/service, not a single binary, so it doesn't
  -- fit the which-based dnfInstall pattern -- same reasoning as
  -- blt-devel/kacst-office-fonts above.
  shells "sudo dnf install -y cups" empty
  dnfInstall
    "glow"
    "glow"
    "glow already installed at "
    "glow already installed."
  installEmacsFromSource
  dnfInstall
    "racket"
    "racket"
    "Racket already installed at "
    "Racket already installed."
  writeDoomConfig
  installDoomEmacs
  installRacketLangserver
  installZig
  installZls
  installNil
  installShellcheckSystemWide
  installRustAnalyzerSystemWide
  installCToolchain
  installDirenv
  installSbcl
  installQuicklisp
  dnfInstall
    "rclone"
    "rclone"
    "rclone already installed at "
    "rclone already installed."
  installProtonVpnCli
  dnfInstall
    "sassc"
    "sassc"
    "sassc already installed at "
    "sassc already installed."
  installSbt
  -- grim (+ slurp for region selection) replaces upstream's scrot, which
  -- is X11-only and can't capture anything under a native Wayland
  -- session. Plasma already ships Spectacle for screenshots; grim/slurp
  -- cover the Hyprland session, which has no screenshot tool of its own.
  dnfInstall
    "grim"
    "grim"
    "grim already installed at "
    "grim already installed."
  dnfInstall
    "slurp"
    "slurp"
    "slurp already installed at "
    "slurp already installed."
  dnfInstall
    "smartctl"
    "smartmontools"
    "smartmontools already installed at "
    "smartmontools already installed."
  dnfInstall
    "steam"
    "steam"
    "steam (via the Asahi COPR + box64) already installed at "
    "steam already installed."
  -- tlp/tlp-rdw are deliberately NOT installed: Fedora ships tuned/
  -- tuned-ppd as the default power management daemon, and it hard-
  -- conflicts with tlp (both try to own the same power-profiles-daemon
  -- D-Bus service files, confirmed via a live run failing outright on
  -- that file conflict) -- so installing tlp means removing tuned first,
  -- and that's a real system-behavior change this script isn't making
  -- unasked. If you want tlp instead of tuned, run:
  --   sudo dnf remove -y tuned tuned-ppd && sudo dnf install -y tlp tlp-rdw
  dnfInstall
    "vifm"
    "vifm"
    "Vifm already installed at "
    "Vifm already installed."
  -- foot: a minimal, Wayland-native terminal used just for vifm's
  -- launcher entry (see writeVifmDesktopFile) rather than the heavier
  -- Konsole this repo uses elsewhere -- vifm is a TUI with no launcher
  -- entry of its own otherwise, same gap spotify_player had.
  dnfInstall
    "foot"
    "foot"
    "foot already installed at "
    "foot already installed."
  writeVifmDesktopFile
  writeFootConfig
  dnfInstall
    "sensors"
    "lm_sensors"
    "Hardware Sensors CLI program already installed at "
    "Hardware Sensors CLI program already installed."
  -- wtype replaces upstream's xdotool for typing/key-triggering under
  -- Wayland (works via the wlr virtual-keyboard protocol, which both
  -- KWin and Hyprland support). Note this is a partial replacement, not
  -- a full one: xdotool's window-management side (finding/moving/
  -- resizing/activating arbitrary windows by title, etc.) has no
  -- equivalent under Wayland's security model at all -- that's a real
  -- capability gap, not just a rename.
  dnfInstall
    "wtype"
    "wtype"
    "wtype already installed at "
    "wtype already installed."
  -- screenfetch is dropped outright rather than translated: fastfetch
  -- below is the actively maintained, Wayland-aware replacement, so
  -- keeping both would just be redundant.
  dnfInstall
    "fastfetch"
    "fastfetch"
    "fastfetch already installed at "
    "fastfetch already installed."
  dnfInstall
    "tmux"
    "tmux"
    "Tmux already installed at "
    "Tmux already installed."
  dnfInstall
    "thefuck"
    "thefuck"
    "thefuck already installed at "
    "thefuck already installed."
  dnfInstall "zsh" "zsh" "ZSH already installed at " "ZSH already installed."
  installOhMyZsh
  dnfInstall
    "ag"
    "the_silver_searcher"
    "Silver Searcher already installed at "
    "Silver Searcher already installed."
  dnfInstall
    "rg"
    "ripgrep"
    "Ripgrep already installed at "
    "Ripgrep already installed."
  -- fd, for LazyVim's Telescope file-finder (nvim/ below).
  dnfInstall
    "fd"
    "fd-find"
    "fd already installed at "
    "fd already installed."
  installRustLang
  installJuliaup
  installTaplo
  installSpotifyConnectReceiver
  installNeovide
  installHackNerdFont
  installSymbolsNerdFont
  -- guile30, so LazyVim's Guile Scheme REPL support (Conjure, nvim/
  -- below) has an actual Guile runtime to connect to. Fedora's guile30
  -- package provides the `guile3.0` binary, not a plain `guile` symlink
  -- -- confirmed directly via `dnf repoquery -l guile30` (no plain
  -- "guile" package exists in Fedora's repos at all). Start a REPL by
  -- hand with `guile3.0 --listen=/path/to/socket` before using
  -- <localleader>cc in a .scm buffer.
  dnfInstall
    "guile3.0"
    "guile30"
    "Guile 3.0 already installed at "
    "Guile 3.0 already installed."
  -- fish and nushell: installed as real shells (not just editor
  -- language support) by request, alongside their nvim/ LSP wiring
  -- (fish_lsp, and LazyVim's official nushell extra using `nu --lsp`).
  -- ksh gets the same editor-side LSP support (via bashls) without
  -- being installed as a shell here -- not requested.
  dnfInstall
    "fish"
    "fish"
    "fish already installed at "
    "fish already installed."
  dnfInstall
    "nu"
    "nushell"
    "Nushell already installed at "
    "Nushell already installed."
  -- clangd, for the C-only LSP setup in nvim/lua/plugins/lang-full.lua --
  -- installed as a system package rather than left to Mason, since
  -- Mason's clangd package has no aarch64 Linux build at all (confirmed
  -- directly: `:MasonInstall clangd` errors "The current platform is
  -- unsupported"). clang-tools-extra is Fedora's actual clangd-providing
  -- package (confirmed via `dnf repoquery --whatprovides "*/bin/clangd"`).
  dnfInstall
    "clangd"
    "clang-tools-extra"
    "clangd already installed at "
    "clangd already installed."
  writeNvimConfig
  dnfInstall
    "go"
    "golang"
    "Go already installed at "
    "Go already installed."
  -- nodejs24-npm-bin is Fedora's "unversioned symlinks" subpackage; the
  -- plain nodejs24/nodejs24-npm packages only provide version-suffixed
  -- binaries (node-24, npm-24), which `which "npm"` would never find.
  dnfInstall
    "npm"
    "nodejs24-npm-bin"
    "NPM (via Node 24) already installed at "
    "NPM already installed."
  installBitwardenCli
  installBashLanguageServerSystemWide
  installFishLsp
  installPyrightSystemWide
  installClaudeCode
  installOpenCodeCli
  dnfInstall
    "nc"
    "netcat"
    "netcat already installed at "
    "netcat already installed."
  dnfInstall
    "python3"
    "python3"
    "Python 3 already installed at "
    "Python 3 already installed."
  dnfInstall
    "pip"
    "python3-pip"
    "Pip already installed at "
    "Pip already installed."
  -- Fedora deliberately ships no unversioned `python`, unlike `node`/`npm`
  -- above, so this still needs the explicit alternatives step upstream
  -- also needed (`alternatives` is Fedora's `update-alternatives`).
  shell
    "sudo alternatives --install \
    \ /usr/bin/python python /usr/bin/python3 1"
    empty
  dnfInstall
    "poetry"
    "python3-poetry"
    "Poetry package manager for Python already installed at "
    "Poetry package manager for Python already installed."
  dnfInstall
    "pipx"
    "pipx"
    "pipx already installed at "
    "pipx already installed."
  installPyenv
  installAiderPython
  installAiderCli
  installOhMyZshPlugins
  installPowerline
  copyDotFilesToHome
  -- tpm's install_plugins script reads the @plugin lines out of the
  -- deployed ~/.tmux.conf, so this has to run after copyDotFilesToHome,
  -- not before.
  installTmuxPluginManager
  writeKxkbrcKeyRemaps
  writeSystemX11KeyboardOptions
  writePlasmaColorScheme
  writePlasmaFont
  installQt6ct
  writeQt6ctConfig
  installPapirusIconTheme
  installPapirusFolders
  applyPapirusDarkOrangeTheme
  writeKonsoleSolarizedTheme
  writeGtkColorsCss
  setGtkIconTheme
  nixInstalled <- which "nix-shell"
  case nixInstalled of
    Just nixShellLoc ->
      echoWhichLocation
        nixShellLoc
        "nix-shell found at "
        "nix-shell found."
    Nothing -> do
      shells "sudo dnf install -y nix" empty
      -- Fedora's nix RPM creates /nix/var/nix/daemon-socket with the
      -- generic default_t SELinux context rather than a proper daemon-
      -- socket type, which blocks even root from creating the listening
      -- socket under enforcing SELinux -- a known, longstanding Nix/
      -- Fedora/SELinux interaction (confirmed via a live run, and
      -- reproduced across several open Nix issues going back years).
      -- Relabel it correctly before starting the socket, rather than
      -- working around it by disabling/weakening SELinux anywhere.
      shells
        "sudo semanage fcontext -a -t var_run_t \"/nix/var/nix/daemon-socket(/.*)?\" \
        \&& sudo restorecon -Rv /nix/var/nix/daemon-socket"
        empty
      shells "sudo systemctl enable --now nix-daemon.socket" empty
  installNixfmt
  installDocker
  dnfInstall
    "az"
    "azure-cli"
    "Azure CLI already installed at "
    "Azure CLI already installed."
  dnfInstall
    "kubectl"
    "kubernetes1.36-client"
    "kubectl already installed at "
    "kubectl already installed."
  dnfInstall
    "helm"
    "helm"
    "K8S Helm already installed at "
    "K8S Helm already installed."
  installKompose
  installKind
  installK3d
  installTerraform
  -- waybar and brightnessctl for the Hyprland session below
  -- (brightnessctl specifically because hypr/hyprland.conf's brightness
  -- keys need it -- xmonad.hs's `xbacklight` doesn't work under a
  -- native Wayland compositor).
  shells "sudo dnf install -y waybar brightnessctl" empty
  installFuzzel
  writeFuzzelConfig
  installHyprland
  writeWaybarConfig
  writeCameraToggleSudoers
  installTailscale
  installHyprlockAndHypridle
  writeHyprlockConfig
  writeHypridleConfig
  installHyprpaper
  installWallpaper
  writeHyprpaperConfig
  -- river, just as a curiosity for future window-manager experiments
  -- against its river-window-management-v1 protocol -- not configured
  -- as a usable session (it ships no window management of its own at
  -- all; see the header comment).
  dnfInstall
    "river"
    "river"
    "river already installed at "
    "river already installed."
  shells "sudo dnf autoremove -y" empty
  addFlathubRemoteExitCode <-
    shell
      "sudo flatpak remote-add --if-not-exists flathub \
      \ https://flathub.org/repo/flathub.flatpakrepo"
      empty
  case addFlathubRemoteExitCode of
    ExitSuccess ->
      -- Preferring flatpak over dnf here for standalone end-user apps
      -- (browsers, chat/media clients, creative tools) per your request;
      -- Plasma's own shell components (Dolphin, Konsole, System Settings,
      -- Discover, etc.) already ship with the base image and aren't
      -- touched. cheese/rhythmbox/Fractal are replaced with their Plasma
      -- equivalents (kamoso/elisa/neochat) rather than dropped, since
      -- those are genuine app-level substitutions, not core shell parts.
      flatpakInstall "com.bitwarden.desktop"
        >> flatpakInstall "com.brave.Browser"
        >> flatpakInstall "com.github.inercia.k3x"
        >> flatpakInstall "so.libdb.dissent"
        >> flatpakInstall "com.github.tchx84.Flatseal"
        >> flatpakInstall "com.jetbrains.PyCharm-Professional"
        >> flatpakInstall "com.nextcloud.desktopclient.nextcloud"
        >> flatpakInstall "com.rtosta.zapzap"
        >> flatpakInstall "com.sublimehq.SublimeText"
        >> flatpakInstall "im.fluffychat.Fluffychat"
        >> flatpakInstall "im.riot.Riot"
        >> flatpakInstall "io.github.ungoogled_software.ungoogled_chromium"
        >> flatpakInstall "org.chromium.Chromium"
        >> flatpakInstall "com.github.IsmaelMartinez.teams_for_linux"
        >> flatpakInstall "io.thp.numptyphysics"
        >> flatpakInstall "md.obsidian.Obsidian"
        >> flatpakInstall "net.cozic.joplin_desktop"
        >> flatpakInstall "org.electrum.electrum"
        >> flatpakInstall "org.gimp.GIMP"
        >> flatpakInstall "org.inkscape.Inkscape"
        >> flatpakInstall "org.kde.elisa"
        >> flatpakInstall "org.kde.kamoso"
        >> flatpakInstall "org.kde.neochat"
        >> flatpakInstall "com.protonvpn.www"
        >> flatpakInstall "org.mozilla.firefox"
        >> flatpakInstall "org.musescore.MuseScore"
        >> flatpakInstall "org.qutebrowser.qutebrowser"
        >> flatpakInstall "org.remmina.Remmina"
        >> flatpakInstall "org.telegram.desktop"
        >> flatpakInstall "com.github.xournalpp.xournalpp"
    ExitFailure _ -> die "Could not add the remote 'flathub'."
  writeDisambiguatedSystemDesktopFiles
  -- No aarch64 Flathub build exists for these two, unlike everything
  -- above, so they come from Fedora's own repos instead.
  dnfInstall
    "obs"
    "obs-studio"
    "OBS Studio already installed at "
    "OBS Studio already installed."
  dnfInstall
    "thunderbird"
    "thunderbird"
    "Thunderbird already installed at "
    "Thunderbird already installed."
  installSignal
  echo "DONE"
