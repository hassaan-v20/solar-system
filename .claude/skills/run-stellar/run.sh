#!/usr/bin/env bash
# Launch the Stellar Godot game (game/), auto-healing a stale .godot class cache.
#
# Why this exists: when a branch moves, renames, or deletes script files (and
# branches in this repo lay the scripts out differently), Godot's
# .godot/global_script_class_cache.cfg keeps pointing at the old locations. The
# editor/runtime then throws "hides a global script class" / "Could not find
# script for class ..." and the main scene refuses to load — looks like broken
# code, but it's just a stale cache. .godot/ is gitignored and fully regenerable,
# so the cure is to wipe it and re-import. This script detects the symptom (a
# cached path that no longer exists on disk, or a boot that errors) and does that
# automatically, then launches.
set -euo pipefail

GODOT="${GODOT:-$(command -v godot || command -v godot4 || true)}"
[ -n "$GODOT" ] || { echo "Godot not found. Install: brew install --cask godot" >&2; exit 1; }

ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
GAME="$ROOT/game"
CACHE="$GAME/.godot/global_script_class_cache.cfg"
cd "$GAME"

# Primary signal (cheap, deterministic): a cached class path that no longer
# exists on disk means the file was moved/deleted but the cache wasn't updated.
cache_paths_missing() {
  [ -f "$CACHE" ] || return 1
  grep -oE 'res://[^"]+\.gd' "$CACHE" 2>/dev/null | sort -u | while IFS= read -r res; do
    [ -f "$GAME/${res#res://}" ] || { echo stale; break; }
  done | grep -q stale
}

# Safety net: a headless boot that emits class/parse errors. Catches cases the
# path check can't, e.g. a renamed class_name where the file path is unchanged.
boot_emits_class_errors() {
  "$GODOT" --headless --quit-after 5 2>&1 \
    | grep -qE 'hides a global script class|Could not find script for class|Could not parse global class|Failed to load script'
}

if cache_paths_missing || boot_emits_class_errors; then
  echo "» Stale .godot class cache detected — clearing and re-importing…"
  rm -rf .godot
  "$GODOT" --headless --editor --quit >/dev/null 2>&1 || true
  echo "» Cache rebuilt."
fi

echo "» Launching Stellar…"
exec "$GODOT" --path "$GAME" "$@"
