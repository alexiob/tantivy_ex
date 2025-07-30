#!/usr/bin/env bash

set -euo pipefail

REPO="alexiob/tantivy_ex"
OUT_FILE="checksum-Elixir.TantivyEx.Native.exs"
TMP_DIR=$(mktemp -d)
VERSION="0.4.1"

# Fetch all release assets from GitHub API
assets=$(gh release view v$VERSION --json assets --jq '.assets[] | select(.name | test("\\.tar\\.gz$")) | .browser_download_url + " \"" + .name + "\" => \"" + .digest + "\","')

(echo "%{$assets}")  > "$OUT_FILE"
# declare -A checksums

# # Download each asset and compute its sha256
# while read -r url name; do
#   echo "Processing $name"
#   curl -sL "$url" -o "$TMP_DIR/$name"
#   sha=$(shasum -a 256 "$TMP_DIR/$name" | awk '{print $1}')
#   checksums["$name"]="sha256:$sha"
# done <<< "$assets"

# # Generate the Elixir map
# {
#   echo "%{"
#   for name in "${!checksums[@]}"; do
#     echo "  \"$name\" => \"${checksums[$name]}\","
#   done
#   echo "}"
# } > "$OUT_FILE"

# echo "Checksums written to $OUT_FILE"