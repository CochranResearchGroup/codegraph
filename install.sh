#!/bin/sh
#
# CodeGraph standalone installer.
#
# Downloads a self-contained bundle (a vendored Node runtime + the app) from
# GitHub Releases. No Node.js, no build tools, no npm required — ideal for a
# fresh Linux VPS over SSH.
#
#   curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh
#
# Upgrade:   re-run the same command.
# Uninstall: curl -fsSL .../install.sh | sh -s -- --uninstall
#
# Environment:
#   CODEGRAPH_VERSION      release tag to install (default: latest)
#   CODEGRAPH_INSTALL_DIR  bundle location   (default: ~/.codegraph)
#   CODEGRAPH_BIN_DIR      symlink location  (default: ~/.local/bin)
#   CODEGRAPH_DOWNLOAD_BASE release asset base URL
#                            (default: https://github.com/colbymchenry/codegraph/releases/download)
set -eu

REPO="colbymchenry/codegraph"
INSTALL_DIR="${CODEGRAPH_INSTALL_DIR:-$HOME/.codegraph}"
BIN_DIR="${CODEGRAPH_BIN_DIR:-$HOME/.local/bin}"
DOWNLOAD_BASE="${CODEGRAPH_DOWNLOAD_BASE:-https://github.com/$REPO/releases/download}"
DOWNLOAD_BASE="${DOWNLOAD_BASE%/}"

require_safe_install_dir() {
  case "$INSTALL_DIR" in
    ""|"/"|"/."|"."|".."|"$HOME"|"$HOME/"|"/home"|"/home/"|"/usr"|"/usr/"|"/usr/local"|"/usr/local/"|"/opt"|"/opt/"|"/tmp"|"/tmp/")
      echo "codegraph: refusing unsafe CODEGRAPH_INSTALL_DIR='$INSTALL_DIR'." >&2
      echo "codegraph: choose a dedicated directory such as \$HOME/.codegraph." >&2
      exit 1
      ;;
  esac
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    return 1
  fi
}

verify_archive_checksum() {
  asset="$1"
  archive="$2"
  sums_url="$DOWNLOAD_BASE/$version/SHA256SUMS"
  sums_file="$tmp/SHA256SUMS"
  if ! curl -fsSL "$sums_url" -o "$sums_file"; then
    echo "codegraph: warning: checksum file unavailable; proceeding without SHA256 verification." >&2
    return 0
  fi
  expected="$(awk -v asset="$asset" '$2 == asset || $2 == "*" asset { print tolower($1); exit }' "$sums_file")"
  if [ -z "$expected" ]; then
    echo "codegraph: warning: $asset not listed in SHA256SUMS; proceeding without SHA256 verification." >&2
    return 0
  fi
  if ! actual="$(sha256_file "$archive")"; then
    echo "codegraph: warning: no sha256 tool found; proceeding without SHA256 verification." >&2
    return 0
  fi
  if [ "$actual" != "$expected" ]; then
    echo "codegraph: checksum mismatch for $asset" >&2
    echo "codegraph: expected $expected" >&2
    echo "codegraph: actual   $actual" >&2
    exit 1
  fi
  echo "Verified SHA256 for $asset"
}

if [ "${1:-}" = "--uninstall" ]; then
  require_safe_install_dir
  rm -f "$BIN_DIR/codegraph"
  rm -rf "$INSTALL_DIR"
  echo "CodeGraph uninstalled (removed $INSTALL_DIR and $BIN_DIR/codegraph)."
  exit 0
fi

# 1. Detect platform → target triple matching the release archives.
os="$(uname -s)"
arch="$(uname -m)"
case "$os" in
  Darwin) os="darwin" ;;
  Linux)  os="linux" ;;
  *) echo "codegraph: unsupported OS '$os'." >&2; exit 1 ;;
esac
case "$arch" in
  arm64|aarch64) arch="arm64" ;;
  x86_64|amd64)  arch="x64" ;;
  *) echo "codegraph: unsupported architecture '$arch'." >&2; exit 1 ;;
esac
target="${os}-${arch}"

# 2. Resolve the version (latest release unless pinned).
#
# Resolve "latest" from the releases/latest *web* redirect, not the GitHub API:
# the unauthenticated API is rate-limited to 60 requests/hour per IP and returns
# 403 once exhausted — routine on shared/cloud hosts and CI (issue #325). The
# redirect (github.com/<repo>/releases/latest -> .../releases/tag/vX.Y.Z) has no
# such limit. Fall back to the API if the redirect can't be read.
version="${CODEGRAPH_VERSION:-}"
if [ -z "$version" ]; then
  version="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest" \
    | sed -n 's#.*/releases/tag/##p')"
fi
if [ -z "$version" ]; then
  version="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
    | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n1)"
fi
[ -n "$version" ] || { echo "codegraph: could not resolve latest version; set CODEGRAPH_VERSION (e.g. CODEGRAPH_VERSION=v0.9.4)." >&2; exit 1; }
# Release tags are vX.Y.Z; accept a bare X.Y.Z in CODEGRAPH_VERSION too.
case "$version" in v*) ;; *) version="v$version" ;; esac

# 3. Download + extract the bundle.
asset="codegraph-${target}.tar.gz"
url="$DOWNLOAD_BASE/$version/$asset"
echo "Installing CodeGraph $version ($target)..."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "$url" -o "$tmp/cg.tar.gz" || { echo "codegraph: download failed: $url" >&2; exit 1; }
verify_archive_checksum "$asset" "$tmp/cg.tar.gz"

dest="$INSTALL_DIR/versions/$version"
rm -rf "$dest"
mkdir -p "$dest"
# Archives contain a top-level codegraph-<target>/ dir; strip it.
tar -xzf "$tmp/cg.tar.gz" -C "$dest" --strip-components=1

# 4. Symlink the launcher onto PATH and mark the current version.
mkdir -p "$BIN_DIR"
ln -sf "$dest/bin/codegraph" "$BIN_DIR/codegraph"
ln -sfn "$dest" "$INSTALL_DIR/current"

echo "Installed to $dest"
echo "Linked     $BIN_DIR/codegraph"
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *)
    echo ""
    echo "$BIN_DIR is not on your PATH. Add it:"
    echo "  export PATH=\"$BIN_DIR:\$PATH\""
    ;;
esac
echo ""
echo "Done. Run: codegraph --help"
