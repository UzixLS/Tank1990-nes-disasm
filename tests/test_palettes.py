import tempfile
import unittest
from pathlib import Path

from tools.palettes import read_palette


class PaletteTest(unittest.TestCase):
    def test_text_format(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "test.pal"
            path.write_text("# comment\n0F 18 27 38\n", encoding="utf-8")
            self.assertEqual(read_palette(path), bytes((0x0F, 0x18, 0x27, 0x38)))

    def test_rejects_invalid_color(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "test.pal"
            path.write_text("40\n", encoding="utf-8")
            with self.assertRaises(ValueError):
                read_palette(path)


if __name__ == "__main__":
    unittest.main()
