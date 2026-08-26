#!/usr/bin/env bash
set -euo pipefail
# Safe example only: install into a dedicated folder and never edit the user's shell.qml.
dest="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/ryotunes"
mkdir -p "$dest"
cp "$(dirname "$0")/RyotunesBarWidget.qml" "$dest/"
printf 'Installed optional widget to %s\nImport it from your Ryoku/Quickshell bar config as RyotunesBarWidget {}.\n' "$dest"
