#!/bin/bash

set -euo pipefail
export MISE_QUIET=1

repo=gardnmi/boomux
target=x86_64-unknown-linux-gnu
minimum_tag="v$(jq -r .minimum_boomux compatibility.json)"
latest_tag=$(gh release view --repo "$repo" --json tagName --jq .tagName)
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

for tag in "$minimum_tag" "$latest_tag"; do
  [[ -f $temp_dir/$tag.checked ]] && continue
  version=${tag#v}
  archive="boomux-v${version}-${target}.tar.gz"
  release_dir="$temp_dir/$tag"
  mkdir "$release_dir"
  gh release download "$tag" --repo "$repo" --dir "$release_dir" \
    --pattern "$archive" --pattern "$archive.sha256"
  (cd "$release_dir" && sha256sum --check "$archive.sha256")
  tar -xzf "$release_dir/$archive" -C "$release_dir"
  bun scripts/check-boomux-capabilities.js \
    "$release_dir/boomux-v${version}-${target}/boomux"
  touch "$temp_dir/$tag.checked"
done
