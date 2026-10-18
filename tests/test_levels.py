import tempfile
import unittest
from pathlib import Path

from tools.levels import decode_level, encode_level, read_level, write_level


class LevelTest(unittest.TestCase):
    def test_nibble_order_row_stride_and_padding(self):
        data = bytes.fromhex("01 23 45 67 89 AB CD") * 13
        self.assertEqual(decode_level(data), [list(range(14)) for _ in range(13)])
        rows = [[13] * 14 for _ in range(13)]
        rows[0][0], rows[12][12], rows[12][13] = 1, 2, 15
        encoded = encode_level(rows)
        self.assertEqual(encoded, b"\x1d" + b"\xdd" * 89 + b"\x2f")

    def test_reject_invalid_dimensions_and_values(self):
        for size in (0, 90, 92):
            with self.assertRaises(ValueError):
                decode_level(bytes(size))
        for rows in ([[0] * 14] * 12, [[0] * 13] * 13,
                     [[16] * 14] * 13, [[-1] * 14] * 13):
            with self.assertRaises(ValueError):
                encode_level(rows)

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
