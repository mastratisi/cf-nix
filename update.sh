#!/usr/bin/env bash
# Rewrite release.json and package-lock.json from the npm registry (dist-tag "latest").
set -euo pipefail
cd "$(dirname "$0")"

latest=$(curl -fsS https://registry.npmjs.org/cf/latest)
version=$(jq -r .version <<<"$latest")

if [[ -f release.json && $(jq -r .version release.json) == "$version" ]]; then
  echo "up to date: $version"
  exit 0
fi

# The tarball has no lockfile: resolve one from its runtime dependencies
# (devDependencies are build-time only; the compiled dist/ is already bundled).
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
jq 'del(.devDependencies)' <<<"$latest" > "$work/package.json"
(cd "$work" && npm install --package-lock-only --ignore-scripts --no-audit --no-fund >/dev/null)
cp "$work/package-lock.json" package-lock.json
npm_deps_hash=$(prefetch-npm-deps package-lock.json)

# npm's dist.integrity is already an SRI hash (sha512-...), which fetchurl accepts.
jq --arg deps "$npm_deps_hash" \
  '{version, url: .dist.tarball, hash: .dist.integrity, npmDepsHash: $deps}' <<<"$latest" > release.json
echo "updated to $version"
