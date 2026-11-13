#!/usr/bin/env bash
# Regenerates assets/overlays/pink_noise.wav: 60 s of mono, softened pink
# noise that loops without a click. Needs ffmpeg.
#
# Plain pink noise sounded static-y: the hiss lives above roughly 4 kHz. So
# the top is rolled off twice: a gentle 6 dB/octave slope from SOFT_HZ (the
# "softness" knob: lower = darker, towards brown noise) and a steeper cut at
# 6 kHz that removes the hiss itself. A 30 Hz high-pass drops rumble that
# small speakers cannot play anyway. GAIN_DB brings the level back up to
# about where the unfiltered version was (mean about -14 dB) without clipping.
#
# The last 2 s are crossfaded into the first 2 s, after filtering, so the end
# runs straight into the start.
set -euo pipefail
cd "$(dirname "$0")/.."
SOFT_HZ="${SOFT_HZ:-1200}"
GAIN_DB="${GAIN_DB:-4}"
mkdir -p assets/overlays
ffmpeg -v error -y -f lavfi -i "anoisesrc=color=pink:duration=62:sample_rate=44100:seed=7" \
  -filter_complex "[0]highpass=f=30,lowpass=f=${SOFT_HZ}:p=1,lowpass=f=6000,volume=${GAIN_DB}dB,asplit[a][b];[a]atrim=2:62,asetpts=PTS-STARTPTS[body];[b]atrim=0:2,asetpts=PTS-STARTPTS[head];[body][head]acrossfade=d=2:c1=qsin:c2=qsin" \
  -ac 1 -c:a pcm_s16le assets/overlays/pink_noise.wav
ffmpeg -i assets/overlays/pink_noise.wav -af volumedetect -f null - 2>&1 | grep -E "Duration|mean_volume|max_volume"
