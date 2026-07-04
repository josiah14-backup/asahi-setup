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
--     your Spotify password -- plus spotify-player, a Rust TUI you can
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

-- | Shared recipe for Wayland pieces (tofi, currently) that have no Fedora
-- package and build cleanly with a plain `meson setup build && ninja
-- -C build && sudo ninja -C build install`. Assumes build dependencies are
-- already installed.
buildFromSourceViaMeson :: Turtle.FilePath -> Text -> Text -> Text -> Line -> IO ()
buildFromSourceViaMeson binName repoUrl cloneDirName foundPrefix foundErrText =
  which binName
    >>= \case
      Just loc -> echoWhichLocation loc foundPrefix foundErrText
      Nothing ->
        shells ("git clone " <> repoUrl <> " " <> cloneDirName) empty
          >> cd (unpack cloneDirName)
          >> shell "meson setup build" empty
          >>= \case
            ExitFailure _ ->
              cd ".." >> die ("ERROR: Could not configure build for " <> cloneDirName)
            ExitSuccess ->
              shell "ninja -C build" empty
                >>= \case
                  ExitFailure _ ->
                    cd ".." >> die ("ERROR: Could not build " <> cloneDirName)
                  ExitSuccess ->
                    shell "sudo ninja -C build install" empty
                      >>= \case
                        ExitFailure _ ->
                          cd ".." >> die ("ERROR: Could not install " <> cloneDirName)
                        ExitSuccess ->
                          cd ".." >> rmtree (unpack cloneDirName)

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
installPyenv :: IO ()
installPyenv = do
  pyenvRoot <- fmap (</> ".pyenv") home
  pyenvInstalled <- testpath pyenvRoot
  if pyenvInstalled
    then echo "pyenv already installed."
    else do
      shells
        "sudo dnf install -y make gcc zlib-devel bzip2 bzip2-devel \
        \readline-devel sqlite sqlite-devel openssl-devel tk-devel \
        \libffi-devel xz-devel ncurses-devel"
        empty
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
  which "bw"
    >>= \case
      Just bwLoc ->
        echoWhichLocation
          bwLoc
          "Bitwarden CLI already installed at "
          "Bitwarden CLI already installed."
      Nothing -> shells "sudo npm install -g @bitwarden/cli" empty

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
-- receiver, plus spotify-player (a Rust TUI) for local browsing/search
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
  which "spotify-player"
    >>= \case
      Just playerLoc ->
        echoWhichLocation
          playerLoc
          "spotify-player already installed at "
          "spotify-player already installed."
      Nothing ->
        shells "$HOME/.cargo/bin/cargo install spotify_player --locked" empty

-- | No dnf/Flathub package (there's a third-party COPR,
-- chrisbouchard/neovide-nightly, but it's unvetted and not confirmed to
-- build for aarch64, and there's an open but unmerged Flathub PR). Built
-- via cargo instead, same pattern as librespot/spotify-player above.
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

-- | tofi has no Fedora package; build deps are installed alongside
-- waybar's in `main` (a plain meson/ninja build).
installTofi :: IO ()
installTofi =
  buildFromSourceViaMeson
    "tofi"
    "https://github.com/philj56/tofi"
    "tofi"
    "tofi already installed at "
    "tofi already installed."

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
        shell "sudo dnf install -y hyprland xdg-desktop-portal-hyprland" empty
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
    \hyprland xdg-desktop-portal-hyprland"
    empty

writeHyprlandConfig :: IO ()
writeHyprlandConfig = do
  curdir <- pwd
  homeDir <- home
  let configDir = homeDir </> ".config/hypr"
      configPath = configDir </> "hyprland.conf"
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
      echo "Wrote ~/.config/hypr/hyprland.conf (master layout, xmonad-mapped keybinds, waybar, tofi launcher)."

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
  installRustLang
  installJuliaup
  installSpotifyConnectReceiver
  installNeovide
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
  installPyenv
  installOhMyZshPlugins
  installPowerline
  copyDotFilesToHome
  -- tpm's install_plugins script reads the @plugin lines out of the
  -- deployed ~/.tmux.conf, so this has to run after copyDotFilesToHome,
  -- not before.
  installTmuxPluginManager
  writeKxkbrcKeyRemaps
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
  -- tofi's build deps, plus waybar and brightnessctl for the Hyprland
  -- session below (brightnessctl specifically because hypr/hyprland.conf's
  -- brightness keys need it -- xmonad.hs's `xbacklight` doesn't work under
  -- a native Wayland compositor).
  shells
    "sudo dnf install -y meson ninja-build wayland-devel \
    \wayland-protocols-devel scdoc freetype-devel cairo-devel \
    \pango-devel libxkbcommon-devel harfbuzz-devel waybar brightnessctl"
    empty
  installTofi
  installHyprland
  writeWaybarConfig
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
