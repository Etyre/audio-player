#!/usr/bin/env bash
# Regenerates assets/overlays/pink_noise.wav: 60 s of mono pink noise whose
# last 2 s are crossfaded into its own first 2 s, so the end runs straight
# into the start and the loop has no click. Needs ffmpeg.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p assets/overlays
ffmpeg -v error -y -f lavfi -i "anoisesrc=color=pink:duration=62:sample_rate=44100:seed=7" \
  -filter_complex "[0]atrim=2:62,asetpts=PTS-STARTPTS[body];[0]atrim=0:2,asetpts=PTS-STARTPTS[head];[body][head]acrossfade=d=2:c1=qsin:c2=qsin" \
  -ac 1 -c:a pcm_s16le assets/overlays/pink_noise.wav
ffmpeg -i assets/overlays/pink_noise.wav -af volumedetect -f null - 2>&1 | grep -E "Duration|mean_volume|max_volume"
