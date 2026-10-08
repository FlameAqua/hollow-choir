#!/usr/bin/env python3
"""Import music, normalize names and rebuild playlists. Python 3.11+, FFmpeg/FFprobe required.

  python tools/import_music.py "C:/Music/briarfen-battle_v1_intense.m4a" "C:/Music/global_title_v3.wav"
  python tools/import_music.py briarfen_battle_v01_intense.m4a

Accepts external paths or inbox filenames. External originals are copied; files already in the
inbox are renamed in place. Spaces/dashes become underscores and versions become v01, v02, etc.
Use --replace to replace different existing audio (the prior audio/metadata is archived first).
Open Godot afterwards to import prepared resources, or pass --godot PATH to do that now.
"""
import argparse
from pathlib import Path
import re
import shutil
import subprocess
import sys
import uuid

sys.path.insert(0, str(Path(__file__).resolve().parent))
import prepare_music as pipeline


def canonical_name(filename):
    source = Path(filename)
    if source.suffix.lower() not in pipeline.FORMATS:
        raise ValueError(f"Unsupported audio format: {source.name}")
    stem = re.sub(r"[-\s]+", "_", source.stem.strip().lower())
    stem = re.sub(r"_+", "_", stem)
    match = pipeline.NAME.fullmatch(stem)
    if not match:
        raise ValueError(f"Use <cue>_v<number>[_<tone>]: {source.name}")
    cue, version, tone = match.groups()
    if cue not in pipeline.CUES or int(version) < 1:
        raise ValueError(f"Unknown cue/version in {source.name}. Cues: {', '.join(pipeline.CUES)}")
    stem = f"{cue}_v{int(version):02d}" + (f"_{tone}" if tone and tone != "base" else "")
    return stem + source.suffix.lower()


def resolve_input(value):
    source = Path(value).expanduser()
    if not source.is_file():
        source = pipeline.INBOX / value
    if not source.is_file():
        raise ValueError(f"Audio file not found: {value}")
    return source.resolve()


def check_destination(source, inbox, replace=False):
    target = inbox / canonical_name(source.name)
    if target.exists() and source != target.resolve():
        if source.parent == inbox.resolve():
            raise ValueError(f"Both inbox names exist: {source.name} and {target.name}; resolve the duplicate first")
        if pipeline.sha(source) != pipeline.sha(target) and not replace:
            raise ValueError(f"{target.name} already contains different audio; use --replace to archive and replace it")
    for other in inbox.iterdir():
        if other.is_file() and other.suffix.lower() in pipeline.FORMATS and other.resolve() != source:
            if canonical_name(other.name).rsplit('.', 1)[0] == target.stem and other != target:
                raise ValueError(f"Duplicate version/tone would remain: {other.name} and {target.name}")
    return target


def ingest(source, inbox, replace=False):
    source = Path(source).resolve()
    inbox = Path(inbox).resolve()
    inbox.mkdir(parents=True, exist_ok=True)
    target = check_destination(source, inbox, replace)
    digest = pipeline.sha(source)
    if target.exists() and pipeline.sha(target) == digest:
        return target
    if target.exists():
        old_hash = pipeline.sha(target)
        archive = inbox.parent / "archive" / target.stem / old_hash[:12]
        archive.mkdir(parents=True, exist_ok=True)
        shutil.copy2(target, archive / target.name)
        metadata = target.with_suffix(".delivery.json")
        if metadata.exists():
            shutil.copy2(metadata, archive / metadata.name)
    if source.parent == inbox:
        metadata = source.with_suffix(".delivery.json")
        source.rename(target)
        if metadata.exists():
            metadata.replace(target.with_suffix(".delivery.json"))
    else:
        incoming = target.with_name(target.name + ".incoming")
        shutil.copy2(source, incoming)
        if pipeline.sha(incoming) != digest:
            raise RuntimeError(f"Copy verification failed: {source.name}")
        incoming.replace(target)
    if pipeline.sha(target) != digest:
        raise RuntimeError(f"Import verification failed: {target.name}")
    return target


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("files", nargs="+", help="audio paths or names already in the inbox")
    parser.add_argument("--replace", action="store_true", help="archive and replace different existing audio")
    parser.add_argument("--ffmpeg", default=shutil.which("ffmpeg"))
    parser.add_argument("--ffprobe", default=shutil.which("ffprobe"))
    parser.add_argument("--godot", help="optional Godot executable to import prepared Resources")
    args = parser.parse_args()
    try:
        if not args.ffmpeg or not args.ffprobe:
            raise ValueError("FFmpeg and FFprobe are required (or pass --ffmpeg/--ffprobe paths)")
        sources = [resolve_input(value) for value in args.files]
        targets = [check_destination(source, pipeline.INBOX, args.replace) for source in sources]
        if len({target.stem for target in targets}) != len(targets):
            raise ValueError("The arguments contain duplicate cue/version/tone identities")
        for source in sources:
            target = ingest(source, pipeline.INBOX, args.replace)
            print(f"Imported: {target.relative_to(pipeline.ROOT).as_posix()}")
        pipeline.prepare_all(args.ffmpeg, args.ffprobe)
        if args.godot:
            home = pipeline.ROOT / ".godot/qa" / ("music-import-" + uuid.uuid4().hex[:8])
            subprocess.run([sys.executable, str(pipeline.ROOT / "tools/qa_godot.py"), "--home", str(home),
                            "--godot", args.godot, "--headless", "--editor", "--import"], check=True)
        else:
            print("Playlists rebuilt. Open Godot to import the prepared audio.")
    except (ValueError, RuntimeError, OSError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Music import failed: {error}\n")


if __name__ == "__main__":
    main()
