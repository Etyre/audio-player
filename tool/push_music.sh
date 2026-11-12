#!/usr/bin/env bash
# Copy audio files from this Mac into one of the app's playlists.
#
#   tool/push_music.sh "<playlist name>" file-or-folder...        # onto the iPhone, over Wi-Fi or cable
#   tool/push_music.sh --sim "<playlist name>" file-or-folder...  # into the booted iOS simulator
#
# A playlist is just a folder in the app's Documents/Playlists, so this is all
# "adding to a playlist" means. The app picks the files up the next time it
# comes to the foreground. Works on the phone because the app is signed with
# a development certificate (devicectl may write into its data container).
# The app must already be installed. Files already in the playlist are sent
# again and overwritten.
set -euo pipefail

SIM=0
if [ "${1:-}" = "--sim" ]; then SIM=1; shift; fi
[ $# -ge 2 ] || { sed -n '2,6p' "$0" >&2; exit 1; }
PLAYLIST="$1"; shift
BUNDLE="com.elityre.audioPlayer"

FILES=()
for src in "$@"; do
  if [ -d "$src" ]; then
    while IFS= read -r -d '' f; do FILES+=("$f"); done \
      < <(find "$src" -maxdepth 1 -type f \( -iname '*.mp3' -o -iname '*.m4a' -o -iname '*.aac' -o -iname '*.wav' -o -iname '*.flac' \) -print0)
  else
    FILES+=("$src")
  fi
done
[ ${#FILES[@]} -gt 0 ] || { echo "No audio files found." >&2; exit 1; }

if [ $SIM = 1 ]; then
  DEST="$(xcrun simctl get_app_container booted "$BUNDLE" data)/Documents/Playlists/$PLAYLIST"
  mkdir -p "$DEST"
  cp -v "${FILES[@]}" "$DEST/"
  exit 0
fi

# Device: $AUDIO_PLAYER_DEVICE_ID, else the first physical iPhone devicectl knows.
DEVICE="${AUDIO_PLAYER_DEVICE_ID:-$(xcrun devicectl list devices 2>/dev/null | awk '/physical/ && /iPhone/ {for(i=1;i<=NF;i++) if ($i ~ /^[0-9A-F]{8}-[0-9A-F]{16}$/) {print $i; exit}}')}"
[ -n "$DEVICE" ] || { echo "No iPhone found in 'xcrun devicectl list devices'." >&2; exit 1; }

for f in "${FILES[@]}"; do
  echo "-> $PLAYLIST/$(basename "$f")"
  xcrun devicectl device copy to --device "$DEVICE" \
    --domain-type appDataContainer --domain-identifier "$BUNDLE" \
    --source "$f" --destination "Documents/Playlists/$PLAYLIST/$(basename "$f")" >/dev/null
done
echo "Copied ${#FILES[@]} file(s) into \"$PLAYLIST\"."
