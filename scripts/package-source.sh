#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="${1:-$root/ryotunes-v2.2.0-final-source.tar.gz}"

cd "$root"
./scripts/release-check.sh

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/ryotunes"

tar \
  --exclude='.git' \
  --exclude='target' \
  --exclude='ui/node_modules' \
  --exclude='ui/build' \
  --exclude='ui/.svelte-kit' \
  --exclude='__pycache__' \
  --exclude='*.pyc' \
  --exclude='packaging/arch/pkg' \
  --exclude='packaging/arch/src' \
  --exclude='packaging/arch/*.pkg.tar.*' \
  --exclude='ryotunes-v*-source.tar.gz' \
  -cf - . | tar -C "$tmp/ryotunes" -xf -

tar -C "$tmp" -czf "$out" ryotunes
printf 'Wrote %s\n' "$out"
