"""Real media preparation boundaries; run with python -m unittest discover -s tests -p test_*.py."""
import importlib.util
import json
import math
from pathlib import Path
import shutil
import struct
import tempfile
import unittest
from unittest.mock import patch
import wave

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("prepare_music", ROOT / "tools/prepare_music.py")
music = importlib.util.module_from_spec(spec)
spec.loader.exec_module(music)


class MusicPreparationTests(unittest.TestCase):
    def setUp(self):
        parent = ROOT / ".godot/qa"
        parent.mkdir(parents=True, exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=parent)
        self.folder = Path(self.temp.name)

    def tearDown(self):
        self.temp.cleanup()

    def test_future_tones_versions_removals_and_duplicate_identity(self):
        for name in ["briarfen-battle_v1.wav", "briarfen_battle_v3_intense.m4a", "global_title_v2_calm.flac"]:
            (self.folder / name).touch()
        records = music.discover(self.folder)
        self.assertEqual({record[4] for record in records},
                         {"briarfen_battle_v01", "briarfen_battle_v03_intense", "global_title_v02_calm"})
        (self.folder / "briarfen-battle_v1.wav").unlink()
        self.assertEqual(len(music.discover(self.folder)), 2)
        (self.folder / "global-title_v02_calm.mp3").touch()
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            music.discover(self.folder)

    def test_unrecognized_files_do_not_silently_join_a_playlist(self):
        (self.folder / "mystery_v1.wav").touch()
        with self.assertRaisesRegex(ValueError, "Unknown cue"):
            music.discover(self.folder)

    def test_zero_version_is_rejected_by_preparation_as_well_as_import(self):
        (self.folder / "global_title_v0.wav").touch()
        with self.assertRaisesRegex(ValueError, "positive"):
            music.discover(self.folder)

    def test_delivery_ledger_adds_tones_and_retires_removed_versions(self):
        source = self.folder / "global_title_v3_calm.flac"
        source.touch()
        record = {"id": "global_title_v03_calm", "cue_id": "global_title", "version": 3, "tone": "calm",
                  "source_file": source.relative_to(ROOT).as_posix(), "source_sha256": "first",
                  "runtime_file": "prepared.ogg", "approved_by": "Adrian", "approval_note": "User authorized",
                  "usage_status": "user_authorized", "source_duration_seconds": 30, "sample_rate_hz": 48000}
        runtime = self.folder / "music"
        runtime.mkdir()
        catalog = runtime / "catalog.json"
        catalog.write_text(json.dumps({"tracks": [{"cue_id": "global_title"}], "candidates": []}), encoding="utf-8")
        with patch.object(music, "MUSIC", runtime):
            music.update_delivery_records([record])
            data = json.loads(catalog.read_text(encoding="utf-8"))
            self.assertEqual(data["tracks"][0]["runtime_playlist"], [record["id"]])
            self.assertIn(record["id"], data["tracks"][0]["candidate_delivery_ids"])
            metadata = source.with_suffix(".delivery.json")
            previous = json.loads(metadata.read_text(encoding="utf-8"))
            previous["prompt"] = "Belongs to the previous song"
            metadata.write_text(json.dumps(previous), encoding="utf-8")
            music.update_delivery_records([{**record, "source_sha256": "replacement"}])
            self.assertNotIn("prompt", json.loads(metadata.read_text(encoding="utf-8")))
            music.update_delivery_records([])
            removed = json.loads(catalog.read_text(encoding="utf-8"))
            self.assertEqual(removed["tracks"][0]["runtime_playlist"], [])
            self.assertFalse(removed["candidates"][0]["active_playlist"])

    @unittest.skipUnless(shutil.which("ffmpeg") and shutil.which("ffprobe"), "FFmpeg required")
    def test_real_decode_trim_cache_and_replacement_preserve_original(self):
        source = self.folder / "briarfen_battle_v99.wav"

        def write_tone(frequency):
            with wave.open(str(source), "wb") as output:
                output.setparams((1, 2, 22050, 0, "NONE", "not compressed"))
                samples = []
                for index in range(int(6.5 * 22050)):
                    seconds = index / 22050
                    sample = 5000 * math.sin(2 * math.pi * frequency * seconds) if 0.5 <= seconds < 5.5 else 0
                    samples.append(struct.pack("<h", int(sample)))
                output.writeframes(b"".join(samples))

        write_tone(220)
        digest = music.sha(source)
        item = music.discover(self.folder)[0]
        with patch.object(music, "MUSIC", self.folder / "runtime"):
            prepared = music.prepare(item, shutil.which("ffmpeg"), shutil.which("ffprobe"), {})
            self.assertEqual(music.sha(source), digest)
            self.assertEqual(prepared["sample_rate_hz"], 22050, "do not upsample native content")
            self.assertAlmostEqual(prepared["duration_seconds"], 5.1, delta=0.1)
            with patch.object(music, "run", side_effect=AssertionError("unchanged files should be cached")):
                cached = music.prepare(item, "unused", "unused", {item[4]: prepared})
            self.assertEqual(cached, prepared)
            legacy = {key: value for key, value in prepared.items() if key not in ("source_channels", "source_codec")}
            upgraded = music.prepare(item, "must-not-encode", shutil.which("ffprobe"), {item[4]: legacy})
            self.assertEqual(upgraded["source_channels"], 1)
            self.assertEqual(upgraded["source_codec"], "pcm_s16le")
            self.assertEqual(upgraded["runtime_sha256"], prepared["runtime_sha256"], "metadata repair does not reencode audio")
            write_tone(330)
            replaced = music.prepare(item, shutil.which("ffmpeg"), shutil.which("ffprobe"), {item[4]: prepared})
            self.assertNotEqual(replaced["runtime_file"], prepared["runtime_file"])
            self.assertEqual(music.sha(source), replaced["source_sha256"])
