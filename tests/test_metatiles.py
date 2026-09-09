import tempfile
import unittest
from pathlib import Path

from tools.metatiles import read_metatiles


class MetatileTest(unittest.TestCase):
    def test_rejects_wrong_row_count(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "test.tsa"
            path.write_text("0 00 01 02 03\n", encoding="utf-8")
            with self.assertRaises(ValueError):
                read_metatiles(path)


if __name__ == "__main__":
    unittest.main()
