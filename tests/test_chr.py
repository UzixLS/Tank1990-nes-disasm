import tempfile
import unittest
from pathlib import Path

from tools.chr import decode_chr, encode_chr, read_bmp, write_bmp


class ChrTest(unittest.TestCase):
    def test_codec_round_trip(self):
        data = bytes((index * 37) & 0xFF for index in range(4096))
        self.assertEqual(encode_chr(decode_chr(data)), data)

    def test_bmp_round_trip(self):
        pixels = bytearray(index & 3 for index in range(128 * 128))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "tiles.bmp"
            write_bmp(path, pixels)
            self.assertEqual(read_bmp(path), pixels)


if __name__ == "__main__":
    unittest.main()
