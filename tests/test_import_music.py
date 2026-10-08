"""Import boundaries: originals, renames, duplicate protection and recoverable replacement."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("import_music", ROOT / "tools/import_music.py")
music = importlib.util.module_from_spec(spec)
spec.loader.exec_module(music)


class MusicImportTests(unittest.TestCase):
    def setUp(self):
        parent = ROOT / ".godot/qa"
        parent.mkdir(parents=True, exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=parent)
        self.folder = Path(self.temp.name)
        self.inbox = self.folder / "source/inbox"
        self.inbox.mkdir(parents=True)

    def tearDown(self):
        self.temp.cleanup()

    def test_external_original_is_preserved_and_repeated_import_is_safe(self):
        source = self.folder / "Briarfen-Battle_v1_Intense.M4A"
        source.write_bytes(b"approved music")
        target = music.ingest(source, self.inbox)
        self.assertEqual(target.name, "briarfen_battle_v01_intense.m4a")
        self.assertEqual(source.read_bytes(), target.read_bytes())
        self.assertEqual(music.ingest(source, self.inbox), target)
        self.assertFalse((self.inbox.parent / "archive").exists())

    def test_inbox_rename_moves_metadata_without_changing_audio(self):
        source = self.inbox / "briarfen-boss-mirebell_v1.m4a"
        source.write_bytes(b"boss music")
        source.with_suffix(".delivery.json").write_text('{"original_filename":"uploaded-name"}')
        digest = music.pipeline.sha(source)
        target = music.ingest(source, self.inbox)
        self.assertEqual(target.name, "briarfen_boss_mirebell_v01.m4a")
        self.assertFalse(source.exists())
        self.assertEqual(music.pipeline.sha(target), digest)
        self.assertIn("uploaded-name", target.with_suffix(".delivery.json").read_text())

    def test_replacement_requires_flag_and_archives_audio_and_metadata(self):
        target = self.inbox / "global_title_v01.wav"
        target.write_bytes(b"previous audio")
        metadata = target.with_suffix(".delivery.json")
        metadata.write_text("previous provenance")
        old_hash = music.pipeline.sha(target)
        source = self.folder / target.name
        source.write_bytes(b"replacement audio")
        with self.assertRaisesRegex(ValueError, "--replace"):
            music.ingest(source, self.inbox)
        self.assertEqual(target.read_bytes(), b"previous audio")
        music.ingest(source, self.inbox, replace=True)
        archive = self.inbox.parent / "archive" / target.stem / old_hash[:12]
        self.assertEqual((archive / target.name).read_bytes(), b"previous audio")
        self.assertEqual((archive / metadata.name).read_text(), "previous provenance")
        self.assertEqual(target.read_bytes(), source.read_bytes())

    def test_duplicate_formats_and_unknown_cues_are_rejected_before_copy(self):
        (self.inbox / "briarfen_battle_v01_intense.wav").write_bytes(b"existing")
        source = self.folder / "briarfen_battle_v1_intense.m4a"
        source.write_bytes(b"different format")
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            music.ingest(source, self.inbox, replace=True)
        self.assertFalse((self.inbox / "briarfen_battle_v01_intense.m4a").exists())
        with self.assertRaisesRegex(ValueError, "Unknown cue"):
            music.canonical_name("unknown_song_v1.wav")
        self.assertEqual(music.canonical_name("global title_v003_calm.FLAC"), "global_title_v03_calm.flac")


if __name__ == "__main__":
    unittest.main()
