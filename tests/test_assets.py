import unittest
from pathlib import Path

from tools.chr import encode_chr, read_bmp
from tools.levels import read_level


ROOT = Path(__file__).resolve().parents[1]
ROM = (ROOT / "Tank 1990 (Ch).nes").read_bytes()


class AssetRoundTripTest(unittest.TestCase):
    def test_chr_matches_rom(self):
        sprites = encode_chr(read_bmp(ROOT / "assets/chr/sprites.bmp"))
        background = encode_chr(read_bmp(ROOT / "assets/chr/background.bmp"))
        self.assertEqual(sprites, ROM[0x8010:0x9010])
        self.assertEqual(background, ROM[0x9010:0xA010])

    def test_tank_levels_match_rom(self):
        data = b"".join(read_level(ROOT / f"assets/levels/tank/{index:03}.map") for index in range(1, 101))
        self.assertEqual(data, ROM[0x10:0x239C])

    def test_extra_levels_match_rom(self):
        data = b"".join(read_level(ROOT / f"assets/levels/extra/{index:03}.map") for index in range(1, 6))
        self.assertEqual(data, ROM[0x239C:0x2563])

    def test_classic_levels_match_rom(self):
        data = b"".join(read_level(ROOT / f"assets/levels/classic/{index:03}.map") for index in range(1, 37))
        self.assertEqual(data, ROM[0x7040:0x7D0C])


if __name__ == "__main__":
    unittest.main()
