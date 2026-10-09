"""QA launcher isolation; run with python -m unittest discover -s tests -p test_*.py."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("qa_godot", ROOT / "tools/qa_godot.py")
qa = importlib.util.module_from_spec(spec)
spec.loader.exec_module(qa)


class IsolatedEnvironmentTests(unittest.TestCase):
    def test_user_data_and_caches_stay_inside_the_home(self):
        base = {"APPDATA": r"C:\Users\Dev\AppData\Roaming", "LOCALAPPDATA": r"C:\Users\Dev\AppData\Local",
                "XDG_CACHE_HOME": "/home/dev/.cache", "PATH": "unchanged"}
        with tempfile.TemporaryDirectory() as folder:
            home = Path(folder) / "home"
            env = qa.isolated_environment(home, base)
            for key in ["APPDATA", "LOCALAPPDATA", "XDG_DATA_HOME", "XDG_CACHE_HOME", qa.HOME_ENV]:
                self.assertIn(home, [Path(env[key]), *Path(env[key]).parents], key)
            self.assertTrue(Path(env["LOCALAPPDATA"]).is_dir(), "cache folder exists before Godot starts")
            self.assertEqual(env["PATH"], "unchanged")
            self.assertEqual(base["LOCALAPPDATA"], r"C:\Users\Dev\AppData\Local", "the caller's environment is not mutated")


if __name__ == "__main__":
    unittest.main()
