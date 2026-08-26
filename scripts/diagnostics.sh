#!/usr/bin/env bash
set -u

# Intentionally excludes usernames, home paths, hostnames, account data, cookies, URLs and app logs.
line() { printf '%-22s %s\n' "$1" "$2"; }

printf '%s\n' 'Ryotunes diagnostics (sanitized)'
printf '%s\n' '--------------------------------'
line 'Ryotunes package:' "$(pacman -Q ryotunes-v2.2 2>/dev/null | awk '{print $2}' || pacman -Q ryotunes 2>/dev/null | awk '{print $2}' || printf 'source/unpackaged')"
line 'Kernel:' "$(uname -sr 2>/dev/null || printf 'unknown')"
line 'Architecture:' "$(uname -m 2>/dev/null || printf 'unknown')"
line 'Session:' "${XDG_SESSION_TYPE:-unknown}"
line 'Desktop:' "${XDG_CURRENT_DESKTOP:-unknown}"
line 'Wayland display:' "${WAYLAND_DISPLAY:+present}"
line 'WebKitGTK:' "$(pkg-config --modversion webkit2gtk-4.1 2>/dev/null || printf 'unknown')"
line 'mpv:' "$(mpv --version 2>/dev/null | head -n 1 | sed 's/^mpv //')"
line 'Rust:' "$(rustc --version 2>/dev/null || printf 'not installed')"
line 'Node:' "$(node --version 2>/dev/null || printf 'not installed')"
line 'pnpm:' "$(pnpm --version 2>/dev/null || printf 'not installed')"
line 'Hyprland:' "$(hyprctl version -j 2>/dev/null | sed -n 's/.*"tag":"\([^"]*\)".*/\1/p' | head -n 1 || true)"
line 'GPU classes:' "$(lspci 2>/dev/null | grep -Ei 'VGA|3D controller' | sed -E 's/^[0-9a-f:.]+ //' | paste -sd ';' - || printf 'unknown')"

find_ryotunes_pid() {
  local expected='/usr/lib/ryotunes-v2.2/ryotunes' p exe
  for p in /proc/[0-9]*; do
    [[ -e "$p/exe" ]] || continue
    exe="$(readlink -f "$p/exe" 2>/dev/null || true)"
    [[ "$exe" == "$expected" ]] && { basename "$p"; return 0; }
  done
  return 1
}

ryo_pid="$(find_ryotunes_pid || true)"
if [[ -n "$ryo_pid" ]]; then
  line 'Ryotunes running:' "yes (pid $ryo_pid)"
else
  line 'Ryotunes running:' 'no'
fi

printf '\n%s\n' 'Dependency status'
for p in webkit2gtk-4.1 libappindicator-gtk3 mpv openssl librsvg xdg-utils; do
  if pacman -Q "$p" >/dev/null 2>&1; then printf '  [ok] %s\n' "$p"; else printf '  [!!] %s missing\n' "$p"; fi
done

printf '\n%s\n' 'This report does not include Ryotunes logs, account details, cookies, tokens, local file paths, or network endpoints.'
