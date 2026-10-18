#!/usr/bin/env python3
"""Сверка всех записей карт с ROM и отдельный экспорт скрытых карт без дубликатов."""

import argparse
import csv
import hashlib
import json
from pathlib import Path

try:
    from .levels import LEVEL_SIZE, decode_level, read_level, write_level
    from .rom import EXPECTED_SHA256
except ImportError:
    from levels import LEVEL_SIZE, decode_level, read_level, write_level
    from rom import EXPECTED_SHA256

# Физические серии, включая записи вне таблиц указателей.
LEVEL_SETS = (("extra", 0x8000, 105),
              ("unused", 0xA800, 1), ("classic", 0xF030, 36))


def geometry(data):
    """169 индексов TSA; padding не участвует в сравнении карт."""
    return bytes(value for row in decode_level(data) for value in row[:13])


def catalog(rom, assets):
    if hashlib.sha256(rom).hexdigest() != EXPECTED_SHA256:
        raise ValueError("аудит рассчитан на исходный Tank 1990 (Ch).nes")
    classic = [rom[0x7040 + i * LEVEL_SIZE:0x7040 + (i + 1) * LEVEL_SIZE]
               for i in range(36)]
    result = []
    for name, base, count in LEVEL_SETS:
        directory = assets / name
        expected = {f"{index:03}.map" for index in range(1, count + 1)}
        if {path.name for path in directory.glob("*.map")} != expected:
            raise ValueError(f"{directory}: ожидалось ровно {count} карт без пропусков")
        for index in range(count):
            address = base + index * LEVEL_SIZE
            offset = address - 0x8000 + 16
            data = rom[offset:offset + LEVEL_SIZE]
            asset = f"{name}/{index + 1:03}.map"
            if read_level(assets / asset) != data:
                raise ValueError(f"{asset}: отличается от ROM по ${address:04X}")
            matches = [i + 1 for i, other in enumerate(classic) if geometry(data) == geometry(other)]
            result.append({
                "asset": asset, "cpu_address": f"${address:04X}",
                "file_offset": f"0x{offset:04X}", "size": LEVEL_SIZE,
                "sha256": hashlib.sha256(data).hexdigest(),
                "runtime_record": name == "classic", "same_geometry_as_classic": matches,
                "hidden_export": None,
            })
    return result


def export_hidden(rom, records, output):
    output.mkdir(parents=True, exist_ok=True)
    seen = set()
    hidden = []
    for record in records:
        if record["runtime_record"] or record["same_geometry_as_classic"]:
            continue
        offset = int(record["file_offset"], 0)
        data = rom[offset:offset + LEVEL_SIZE]
        key = geometry(data)
        if key in seen:
            continue
        seen.add(key)
        name = f"{len(hidden) + 1:03}.map"
        record["hidden_export"] = name
        write_level(output / name, data)
        hidden.append({key: record[key] for key in
                       ("hidden_export", "asset", "cpu_address", "file_offset", "sha256")})
    with (output / "index.csv").open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=("hidden_export", "asset", "cpu_address",
                                                  "file_offset", "sha256"))
        writer.writeheader()
        writer.writerows(hidden)
    return len(hidden)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rom", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    rom = args.rom.read_bytes()
    records = catalog(rom, Path(__file__).resolve().parents[1] / "assets/levels")
    count = export_hidden(rom, records, args.output / "hidden-levels")
    report = {"records": len(records), "hidden_unique": count, "levels": records}
    (args.output / "level-audit.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"OK: {len(records)} records match ROM; {count} hidden maps -> {args.output / 'hidden-levels'}")


if __name__ == "__main__":
    main()
