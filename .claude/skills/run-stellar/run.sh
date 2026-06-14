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

# Brand-new class: a source file declares a `class_name` the cache doesn't list
# yet (added since the cache was last built). The boot check below misses this
# when the new class lives off the main scene's load path — e.g. a raid-only
# class — so it boots clean while a later scene change fails with a blank screen.
# Check source declarations against the cache directly.
class_names_missing() {
  [ -f "$CACHE" ] || return 0
  local cn
  while IFS= read -r cn; do
    [ -n "$cn" ] || continue
    grep -q "\"class\": &\"$cn\"" "$CACHE" || return 0
  done < <(grep -rhoE '^class_name[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' scripts 2>/dev/null | awk '{print $2}')
  return 1
}

# A source asset (texture/audio) with no `.import` sibling hasn't been imported
# yet — e.g. an image just dropped into the project. The windowed runtime can
# only load() already-imported assets, so a fresh texture would fail to load
# until the editor imports it; force a reimport first.
assets_unimported() {
  local f
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    [ -f "$f.import" ] || return 0
  done < <(find . -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \
    -o -iname '*.webp' -o -iname '*.exr' -o -iname '*.hdr' -o -iname '*.ogg' \
    -o -iname '*.wav' -o -iname '*.glb' -o -iname '*.gltf' \) \
    -not -path './.godot/*' -not -path './addons/*' 2>/dev/null)
  return 1
}

# Safety net: a headless boot that emits class/parse errors. Catches cases the
# checks above can't, e.g. a renamed class_name where the file path is unchanged.
boot_emits_class_errors() {
  "$GODOT" --headless --quit-after 5 2>&1 \
    | grep -qE 'hides a global script class|Could not find script for class|Could not parse global class|Failed to load script'
}

if cache_paths_missing || class_names_missing || assets_unimported || boot_emits_class_errors; then
  echo "» Stale .godot class cache detected — clearing and re-importing…"
  rm -rf .godot
  "$GODOT" --headless --editor --quit >/dev/null 2>&1 || true
  echo "» Cache rebuilt."
fi

# Headless/CI runs stay in the foreground so you get the output and exit code.
# A normal (windowed) launch is DETACHED so it never blocks the calling shell:
# a GUI game runs until you quit it, and a foreground `exec` would hang the
# terminal — or the Claude Code turn that started it — until then.
if [[ " $* " == *" --headless "* ]]; then
  echo "» Launching Stellar (headless)…"
  exec "$GODOT" --path "$GAME" "$@"
fi

LOG="${TMPDIR:-/tmp}/stellar-run.log"
echo "» Launching Stellar… (log: $LOG)"
nohup "$GODOT" --path "$GAME" "$@" >"$LOG" 2>&1 &
echo "» Launched (pid $!) — the game runs independently; this shell is free."
