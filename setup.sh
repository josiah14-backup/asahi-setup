#!/usr/bin/env bash

# This script's only job is to bootstrap a bare-metal Fedora Asahi Remix
# install to the point where it can compile and run the actual installer,
# app/Main.hs (via `stack build && stack exec asahi-setup-exe`, or the
# equivalent cabal commands). Everything else lives in Main.hs.

set -e

install_ghc_build_deps() {
  echo "    Installing C toolchain GHCup needs to build/link GHC..."

  # GHCup installs a precompiled GHC bindist when one is available for the
  # requested version/architecture, but falls back to compiling GHC from
  # source when it isn't (which is common for aarch64 with
  # BOOTSTRAP_HASKELL_GHC_VERSION=latest, since aarch64 bindists lag behind
  # x86_64 ones). Either path still needs a C compiler on PATH to configure
  # and link GHC's runtime system, so install it unconditionally up front
  # rather than let the bootstrap fail partway through.
  sudo dnf install -y \
    gcc gcc-c++ make autoconf automake perl xz bzip2-devel \
    ncurses-compat-libs gmp-devel libffi-devel

  echo "    C toolchain installed successfully."
}

install_haskell_toolchain() {
  if which ghcup &>/dev/null; then
    echo "    GHCup is already installed."
    return
  fi

  echo "    Installing GHCup, GHC, cabal, stack, and HLS..."
  BOOTSTRAP_HASKELL_NONINTERACTIVE=1 \
  BOOTSTRAP_HASKELL_GHC_VERSION=latest \
  BOOTSTRAP_HASKELL_CABAL_VERSION=latest \
  BOOTSTRAP_HASKELL_INSTALL_STACK=1 \
  BOOTSTRAP_HASKELL_INSTALL_HLS=1 \
  BOOTSTRAP_HASKELL_ADJUST_BASHRC=P \
    sh -s -- -y < <(curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org)

  echo "    Haskell toolchain installed successfully."
}

install_project_build_deps() {
  echo "    Installing native libraries asahi-setup's own dependencies need..."

  # The `zlib` Haskell package -- a transitive dependency pulled in via
  # turtle -- links against the system libz at build time. Fedora's zlib
  # is provided by zlib-ng in compat mode, packaged as
  # zlib-ng-compat-devel rather than zlib-devel.
  sudo dnf install -y zlib-ng-compat-devel

  echo "    Native libraries installed successfully."
}

install_ghc_build_deps
install_haskell_toolchain
install_project_build_deps
