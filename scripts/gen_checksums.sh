#!/usr/bin/env bash

set -euo pipefail

REPO="alexiob/tantivy_ex"
OUT_FILE="checksum-Elixir.TantivyEx.Native.exs"
TMP_DIR=$(mktemp -d)
VERSION="0.4.1"

# Fetch all release assets from GitHub API
assets=$(gh release view v$VERSION --json assets --jq '.assets[] | select(.name | test("\\.tar\\.gz$")) | .browser_download_url + " \"" + .name + "\" => \"" + .digest + "\","')

(echo "%{$assets}")  > "$OUT_FILE"
