#!/usr/bin/env python3
"""Prepare Adrian's authorized inbox playlists (requires FFmpeg/FFprobe, Python stdlib only).

Run after adding/replacing/removing inbox music, then let Godot import the generated Resources.
Names: <cue>_v<number>[_<tone>].m4a|wav|flac|mp3|ogg. Hyphens in cue names are accepted.
Sources are never modified. Hash-named exports make replacements explicit and cacheable.
The runtime reads a typed library, never this delivery ledger or the excluded source folder.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent
INBOX = ROOT / "assets/audio/source/inbox"
MUSIC = ROOT / "assets/audio/music"
CUES = {"global_title": "global", "briarfen_battle": "regions/briarfen",
        "briarfen_boss_mirebell": "regions/briarfen"}
NAME = re.compile(r"(.+)_v(\d+)(?:_([a-z][a-z0-9_]*))?$", re.I)
FORMATS = {".m4a", ".wav", ".flac", ".mp3", ".ogg"}


def discover(inbox):
    found = []
    ids = set()
    for source in sorted(inbox.iterdir()):
        if source.suffix.lower() not in FORMATS or not source.is_file():
            continue
        match = NAME.fullmatch(source.stem)
        if not match:
            raise ValueError(f"Music needs <cue>_v<number>[_<tone>]: {source.name}")
        cue, version, tone = match.groups()
        cue, version, tone = cue.lower().replace("-", "_"), int(version), (tone or "base").lower()
        if cue not in CUES:
            raise ValueError(f"Unknown cue {cue}; add its destination to CUES before preparing it")
        if version < 1:
            raise ValueError(f"Version must be positive: {source.name}")
        identity = f"{cue}_v{version:02d}" + (f"_{tone}" if tone != "base" else "")
        if identity in ids:
            raise ValueError(f"Duplicate version/tone: {identity}")
        ids.add(identity)
        found.append((source, cue, version, tone, identity))
    return found


def sha(path):
    with path.open("rb") as handle:
        return hashlib.file_digest(handle, "sha256").hexdigest()


def run(args):
    result = subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if result.returncode:
        raise RuntimeError(result.stderr[-3000:])
    return result


def prepare(item, ffmpeg, ffprobe, cached):
    source, cue, version, tone, identity = item
    digest = sha(source)
    old = cached.get(identity, {})
    if old.get("source_sha256") == digest and old.get("preparation_version") == 1:
        export = ROOT / old["runtime_file"]
        if export.is_file() and sha(export) == old.get("runtime_sha256"):
            if "source_channels" not in old or "source_codec" not in old:
                probe = json.loads(run([ffprobe, "-v", "error", "-select_streams", "a:0", "-show_streams",
                                        "-of", "json", str(source)]).stdout)["streams"][0]
                old = {**old, "source_channels": int(probe["channels"]), "source_codec": probe["codec_name"]}
            return {**old, "source_file": source.relative_to(ROOT).as_posix()}
    probe = json.loads(run([ffprobe, "-v", "error", "-select_streams", "a:0", "-show_streams",
                            "-show_format", "-of", "json", str(source)]).stdout)
    stream = probe["streams"][0]
    rate, channels = int(stream["sample_rate"]), int(stream["channels"])
    if channels not in (1, 2):
        raise ValueError(f"Expected mono/stereo music: {source.name}")
    duration = float(stream.get("duration") or probe["format"]["duration"])
    analysis = run([ffmpeg, "-hide_banner", "-nostdin", "-i", str(source), "-vn", "-af",
                    "silencedetect=n=-50dB:d=0.25,loudnorm=I=-16:TP=-1:LRA=11:print_format=json",
                    "-f", "null", "-"]).stderr
    measurements = json.loads(analysis[analysis.rfind("{"):analysis.rfind("}") + 1])
    intervals, silence_start = [], None
    for line in analysis.splitlines():
        start = re.search(r"silence_start: ([0-9.]+)", line)
        end = re.search(r"silence_end: ([0-9.]+)", line)
        if start:
            silence_start = float(start[1])
        if end and silence_start is not None:
            intervals.append((silence_start, float(end[1])))
            silence_start = None
    if silence_start is not None:
        intervals.append((silence_start, duration))
    begin, end = 0.0, duration
    for left, right in intervals:
        if left <= 0.05:
            begin = max(0.0, right - 0.05)
        if right >= duration - 0.15:
            end = min(duration, left + 0.05)
    if end - begin < 4:
        raise ValueError(f"No usable music after boundary silence measurement: {source.name}")
    gain = min(-16.0 - float(measurements["input_i"]), -1.0 - float(measurements["input_tp"]))
    export = MUSIC / CUES[cue] / f"{identity}_{digest[:12]}.ogg"
    export.parent.mkdir(parents=True, exist_ok=True)
    # Tiny edge ramps suppress discontinuity clicks; musical looping is handled by overlapping
    # independent streaming decks, never by claiming these separate arrangements are stems.
    length = end - begin
    filters = (f"atrim=start={begin:.6f}:end={end:.6f},asetpts=PTS-STARTPTS,volume={gain:.4f}dB,"
               f"afade=t=in:d=0.015,afade=t=out:st={length - 0.015:.6f}:d=0.015")
    run([ffmpeg, "-hide_banner", "-nostdin", "-y", "-i", str(source), "-vn", "-af", filters,
         "-ar", str(rate), "-ac", "2", "-c:a", "libvorbis", "-q:a", "5", str(export)])
    run([ffmpeg, "-v", "error", "-nostdin", "-i", str(export), "-f", "null", "-"])
    if sha(source) != digest:
        raise RuntimeError(f"Source changed during preparation: {source.name}")
    return {"preparation_version": 1, "id": identity, "cue_id": cue, "version": version, "tone": tone,
            "source_file": source.relative_to(ROOT).as_posix(), "source_sha256": digest,
            "runtime_file": export.relative_to(ROOT).as_posix(), "runtime_sha256": sha(export),
            "sample_rate_hz": rate, "channels": 2, "source_channels": channels,
            "source_codec": stream["codec_name"], "source_duration_seconds": duration,
            "trim_start_seconds": begin, "trim_end_seconds": end, "duration_seconds": length,
            "export_gain_db": gain, "playback_gain_db": -12.0, "crossfade_seconds": 3.0,
            "input_lufs": float(measurements["input_i"]), "input_true_peak_dbtp": float(measurements["input_tp"]),
            "approved_by": "Adrian", "approval_note": "User requested all inbox versions in game, 8 October 2026.",
            "usage_status": "user_authorized", "loop_mode": "playlist_crossfade",
            "beat_alignment": "unmeasured", "sync_group": None, "loop_joins_auditioned": 0,
            "decode_check": "passed"}


def write_library(records):
    lines = ['[gd_resource type="Resource" script_class="MusicLibrary" format=3]', '',
             '[ext_resource type="Script" path="res://src/audio/music_library.gd" id="library"]',
             '[ext_resource type="Script" path="res://src/audio/music_playlist.gd" id="playlist"]',
             '[ext_resource type="Script" path="res://src/audio/music_track.gd" id="track"]']
    for index, record in enumerate(records):
        lines.append(f'[ext_resource type="AudioStream" path="res://{record["runtime_file"]}" id="audio{index}"]')
    for index, record in enumerate(records):
        lines += ['', f'[sub_resource type="Resource" id="track{index}"]', 'script = ExtResource("track")',
                  f'id = &"{record["id"]}"', f'version = {record["version"]}', f'tone = &"{record["tone"]}"',
                  f'stream = ExtResource("audio{index}")',
                  f'source_offset_seconds = {record["trim_start_seconds"]:.6f}',
                  'gain_db = -12.0', 'crossfade_seconds = 3.0']
    playlists = []
    for index, cue in enumerate(CUES):
        entries = [f'SubResource("track{i}")' for i, record in enumerate(records) if record["cue_id"] == cue]
        if not entries:
            continue
        playlists.append(f'SubResource("playlist{index}")')
        lines += ['', f'[sub_resource type="Resource" id="playlist{index}"]', 'script = ExtResource("playlist")',
                  f'cue_id = &"{cue}"', 'tracks = Array[ExtResource("track")]([' + ', '.join(entries) + '])']
    lines += ['', '[resource]', 'script = ExtResource("library")',
              'playlists = Array[ExtResource("playlist")]([' + ', '.join(playlists) + '])', '']
    (MUSIC / "runtime_library.tres").write_text('\n'.join(lines), encoding="utf-8")


def update_delivery_records(records):
    catalog_path = MUSIC / "catalog.json"
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    catalog["integration_status"] = "playlist_playback"
    catalog["purpose"] = "Delivery ledger; runtime playlists are separate typed Resources."
    by_id = {record["id"]: record for record in records}
    for record in records:
        source = ROOT / record["source_file"]
        metadata_path = source.with_suffix(".delivery.json")
        metadata = json.loads(metadata_path.read_text(encoding="utf-8")) if metadata_path.exists() else {
            "delivery_version": 2, "delivery_id": record["id"], "original_filename": source.name,
            "intended_cue_id": record["cue_id"], "source_file": record["source_file"]}
        if metadata.get("source_sha256") not in (None, record["source_sha256"]):
            # A replacement is new media: do not attribute the previous song's prompt/measurements.
            metadata = {"delivery_version": 2, "delivery_id": record["id"], "intended_cue_id": record["cue_id"],
                        "notes": "Source replaced in the authorized inbox; previous runtime export retained."}
        metadata.update({key: record[key] for key in ("runtime_file", "approved_by", "approval_note", "usage_status")})
        metadata.update(source_file=record["source_file"], source_sha256=record["source_sha256"],
                        current_filename=source.name, duration_seconds=record["source_duration_seconds"],
                        sample_rate_hz=record["sample_rate_hz"], channels=record.get("source_channels", 2))
        metadata.setdefault("original_filename", source.name)
        if "source_codec" in record:
            metadata["source_codec"] = record["source_codec"]
        metadata["review_status"] = "integrated"
        metadata["runtime_preparation"] = record
        metadata_path.write_text(json.dumps(metadata, indent=2, ensure_ascii=False) + '\n', encoding="utf-8")
    for track in catalog["tracks"]:
        selected = [record for record in records if record["cue_id"] == track["cue_id"]]
        track["runtime_playlist"] = [record["id"] for record in selected]
        history = track.setdefault("candidate_delivery_ids", [])
        history.extend(record["id"] for record in selected if record["id"] not in history)
        if selected:
            track.update(status="integrated", approved_by="Adrian",
                         usage_status="user_authorized",
                         approval_note="All inbox versions authorized as playlist variants, 8 October 2026.")
        elif track.get("status") == "integrated":
            track["status"] = "unassigned"
    candidates = catalog.setdefault("candidates", [])
    known_ids = {candidate["delivery_id"] for candidate in candidates}
    for record in records:
        if record["id"] not in known_ids:
            candidates.append({"delivery_id": record["id"], "cue_id": record["cue_id"],
                               "version": record["version"], "tone": record["tone"],
                               "source_file": record["source_file"], "source_sha256": record["source_sha256"],
                               "metadata_file": str(Path(record["source_file"]).with_suffix(".delivery.json")).replace("\\", "/")})
    for candidate in candidates:
        identity = candidate.get("delivery_id")
        candidate["active_playlist"] = identity in by_id
        if identity in by_id:
            record = by_id[identity]
            candidate.update(runtime_file=record["runtime_file"], review_status="integrated", status="integrated",
                             source_file=record["source_file"], source_sha256=record["source_sha256"],
                             metadata_file=str(Path(record["source_file"]).with_suffix(".delivery.json")).replace("\\", "/"),
                             approved_by="Adrian", usage_status="user_authorized", tone=record["tone"],
                             loop_mode="playlist_crossfade")
        elif candidate.get("status") == "integrated":
            candidate["status"] = "inactive"
    catalog_path.write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + '\n', encoding="utf-8")


def prepare_all(ffmpeg, ffprobe):
    items = discover(INBOX)
    manifest = MUSIC / "prepared_manifest.json"
    previous = json.loads(manifest.read_text(encoding="utf-8"))["tracks"] if manifest.exists() else []
    cached = {record["id"]: record for record in previous}
    with ThreadPoolExecutor(max_workers=2) as executor:
        records = list(executor.map(lambda item: prepare(item, ffmpeg, ffprobe, cached), items))
    # Write only after every source validates; stale exports are retained, but never selected.
    write_library(records)
    update_delivery_records(records)
    manifest.write_text(json.dumps({"manifest_version": 1, "tracks": records}, indent=2) + '\n', encoding="utf-8")
    print(f"Prepared {len(records)} variants across {len(set(r['cue_id'] for r in records))} playlists.")
    for record in records:
        print(f"  {record['id']}: {record['duration_seconds']:.2f}s, {record['export_gain_db']:+.2f} dB export trim")
    return records


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ffmpeg", default=shutil.which("ffmpeg"))
    parser.add_argument("--ffprobe", default=shutil.which("ffprobe"))
    args = parser.parse_args()
    if not args.ffmpeg or not args.ffprobe:
        parser.error("FFmpeg and FFprobe must be installed or supplied with --ffmpeg/--ffprobe")
    prepare_all(args.ffmpeg, args.ffprobe)


if __name__ == "__main__":
    main()
