import tempfile
import unittest
from pathlib import Path

from tools.levels import decode_level, encode_level, read_level, write_level


class LevelTest(unittest.TestCase):
    def test_binary_round_trip(self):
        data = bytes((index * 29) & 0xFF for index in range(91))
        self.assertEqual(encode_level(decode_level(data)), data)

    def test_text_round_trip(self):
        data = bytes((index * 17) & 0xFF for index in range(91))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "level.map"
            write_level(path, data)
            self.assertEqual(read_level(path), data)


if __name__ == "__main__":
    unittest.main()
