#!/usr/bin/env python3
"""Make a set of audio files equally loud, writing MP3 copies to a folder.

    tool/normalize.py OUT_DIR file-or-folder... [--target -20] [--measure]

Each file's overall loudness is measured (EBU R128 integrated loudness, the
measure streaming services use) and one fixed gain is applied to the whole
file to bring it to --target LUFS. Nothing is compressed: quiet and loud
passages inside a recording keep their relation, only the recordings are
matched to each other. The gain is reduced if it would push the true peak
above -1 dBFS, and the script says so. Tags and embedded cover art are
kept. Originals are never modified.
--measure only prints the measurements. Needs ffmpeg. Files whose output
already exists are skipped, so rerunning after adding one file is cheap.
"""
import argparse, json, pathlib, subprocess, sys
from concurrent.futures import ThreadPoolExecutor

AUDIO = {".mp3", ".m4a", ".aac", ".wav", ".flac"}
PEAK_CEILING = -1.0


def measure(path):
    err = subprocess.run(
        ["ffmpeg", "-nostats", "-hide_banner", "-i", str(path), "-vn",
         "-af", "loudnorm=print_format=json", "-f", "null", "-"],
        capture_output=True, text=True).stderr
    j = json.loads(err[err.rindex("{"):err.rindex("}") + 1])
    return float(j["input_i"]), float(j["input_tp"])


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("out_dir", type=pathlib.Path)
    ap.add_argument("sources", nargs="+", type=pathlib.Path)
    ap.add_argument("--target", type=float, default=-20.0, help="LUFS (default -20)")
    ap.add_argument("--measure", action="store_true")
    a = ap.parse_args()

    files = []
    for s in a.sources:
        files += sorted(f for f in s.iterdir() if f.suffix.lower() in AUDIO) if s.is_dir() else [s]
    if not files:
        sys.exit("No audio files found.")
    with ThreadPoolExecutor() as pool:
        measured = list(pool.map(measure, files))

    a.out_dir.mkdir(parents=True, exist_ok=True)
    jobs = []
    for f, (loud, peak) in zip(files, measured):
        gain = a.target - loud
        capped = peak + gain > PEAK_CEILING
        if capped:
            gain = PEAK_CEILING - peak
        print(f"{loud:6.1f} LUFS  peak {peak:6.1f} dBFS  gain {gain:+5.1f} dB"
              f"{'  (limited by peak, ends at %.1f LUFS)' % (loud + gain) if capped else ''}  {f.name}")
        out = a.out_dir / (f.stem + ".mp3")
        if not a.measure and not out.exists():
            # "0:v?" carries embedded cover art across untouched, when there is any.
            jobs.append(["ffmpeg", "-v", "error", "-y", "-i", str(f),
                         "-map", "0:a:0", "-map", "0:v?", "-c:v", "copy", "-id3v2_version", "3",
                         "-af", f"volume={gain:.2f}dB", "-c:a", "libmp3lame", "-b:a", "160k", str(out)])
    with ThreadPoolExecutor() as pool:
        for r in pool.map(lambda j: subprocess.run(j), jobs):
            if r.returncode:
                sys.exit("ffmpeg failed")
    if jobs:
        print(f"Wrote {len(jobs)} file(s) to {a.out_dir}")


if __name__ == "__main__":
    main()
