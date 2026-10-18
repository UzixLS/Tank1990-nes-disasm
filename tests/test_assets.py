import csv
import tempfile
import unittest
from pathlib import Path

from tools.chr import encode_chr, read_bmp
from tools.levels import read_level
from tools.metatiles import read_metatiles
from tools.palettes import read_palette
from tools.audit_disassembly import audit
from tools.audit_levels import LEVEL_SETS, catalog, export_hidden, geometry
from tools.stage_probe import StageProbe


ROOT = Path(__file__).resolve().parents[1]
ROM = (ROOT / "Tank 1990 (Ch).nes").read_bytes()


class AssetRoundTripTest(unittest.TestCase):
    def test_hidden_export_keeps_source_bytes_and_addresses(self):
        records = catalog(ROM, ROOT / "assets/levels")
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            self.assertEqual(export_hidden(ROM, records, output), 71)
            with (output / "index.csv").open(encoding="utf-8", newline="") as stream:
                index = list(csv.DictReader(stream))
            self.assertEqual(len(index), 71)
            self.assertEqual(index[0]["asset"], "tank/002.map")
            self.assertEqual(index[-1]["cpu_address"], "$A800")
            for row in index:
                offset = int(row["file_offset"], 0)
                self.assertEqual(read_level(output / row["hidden_export"]), ROM[offset:offset + 91])

    def test_disassembly_rejects_jump_into_level_data(self):
        changed = bytearray(ROM)
        # Первый JSR сохранённого кода PRG0 направлен внутрь ClassicLevels.
        offset = 16 + 0xA553 - 0x8000
        self.assertEqual(changed[offset], 0x20)
        changed[offset + 1:offset + 3] = b"\x30\xf0"
        with self.assertRaisesRegex(ValueError, "A553.*F030"):
            audit(changed, ROOT / "build/tank1990.dbg", ROOT)

    def test_complete_level_catalog_and_hidden_maps(self):
        records = catalog(ROM, ROOT / "assets/levels")
        self.assertEqual(len(records), 142)
        hidden = [row["asset"] for row in records
                  if not row["runtime_record"] and not row["same_geometry_as_classic"]]
        self.assertEqual(hidden, ["tank/002.map"] +
                         [f"tank/{i:03}.map" for i in range(37, 101)] +
                         [f"extra/{i:03}.map" for i in range(1, 6)] + ["unused/001.map"])
        maps = [read_level(ROOT / "assets/levels" / row["asset"]) for row in records]
        self.assertEqual(len(set(map(geometry, maps))), 107)

    def test_machine_code_selects_every_stage_and_variant(self):
        for variant in list(range(7)) + list(range(0x80, 0x87)):
            selector = variant & 15
            base = 0xF030 + (selector % 3) * 12 * 91 if selector < 6 else 0xF030
            count = 12 if selector < 6 else 36
            descriptor = ROM[0x643B + selector * 3:0x643E + selector * 3]
            self.assertEqual(descriptor, base.to_bytes(2, "little") + bytes([count]))
            for stage in range(1, 256):
                with self.subTest(variant=variant, stage=stage):
                    wraps, index = divmod(stage - 1, count)
                    expected = base + (2 * wraps) % 6 + index * 91
                    self.assertEqual(StageProbe(ROM, variant, stage).run(select_only=True), expected)
        demo = StageProbe(ROM, variant=0x8F, stage=255, attract=True)
        self.assertEqual(demo.run(select_only=True), 0xF030 + 31 * 91)
        self.assertEqual(demo.memory[0x85], 32)

    def test_machine_code_decodes_all_maps_and_shifted_windows(self):
        addresses = {base + index * 91 for _, base, count in LEVEL_SETS for index in range(count)}
        addresses.update(0xF030 + index * 91 + shift for index in range(36) for shift in (2, 4))
        for address in sorted(addresses):
            with self.subTest(address=hex(address)):
                probe = StageProbe(ROM, pointer=address)
                probe.run()
                offset = address - 0x8000 + 16
                packed = ROM[offset:offset + 91]
                self.assertEqual(bytes(tile for tile, _, _ in probe.tiles), geometry(packed))
                self.assertEqual([(x, y) for _, x, y in probe.tiles],
                                 [(16 * x, 16 * y) for y in range(1, 14) for x in range(1, 14)])
                self.assertEqual(probe.frames, 13)
                self.assertEqual(probe.memory[0x5A], 182)

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

    def test_unused_level_matches_rom(self):
        data = read_level(ROOT / "assets/levels/unused/001.map")
        self.assertEqual(data, ROM[0x2810:0x286B])

    def test_classic_levels_match_rom(self):
        data = b"".join(read_level(ROOT / f"assets/levels/classic/{index:03}.map") for index in range(1, 37))
        self.assertEqual(data, ROM[0x7040:0x7D0C])

    def test_palettes_match_rom(self):
        sprites = read_palette(ROOT / "assets/palettes/sprites.pal")
        background = read_palette(ROOT / "assets/palettes/background.pal")
        self.assertEqual(sprites, ROM[0x5565:0x5575])
        self.assertEqual(background, ROM[0x5575:0x5605])

    def test_metatiles_match_rom(self):
        data = read_metatiles(ROOT / "assets/metatiles/background.tsa")
        self.assertEqual(data, ROM[0x5ACB:0x5B1B])


if __name__ == "__main__":
    unittest.main()
