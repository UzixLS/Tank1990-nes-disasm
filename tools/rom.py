#!/usr/bin/env python3
"""Проверка и временное извлечение банков iNES ROM."""

import argparse
import hashlib
from pathlib import Path

EXPECTED_SIZE = 40976
EXPECTED_SHA256 = "ec453e7e3cc1d49d11d5860ced7f9e1235e2c7d33927bd6073b631754dc08dbb"


def split_rom(path):
    data = Path(path).read_bytes()
    if len(data) != EXPECTED_SIZE or data[:8] != b"NES\x1a\x02\x01\x00\x00":
        raise ValueError("ожидается Tank 1990 NROM-256: 32 KiB PRG и 8 KiB CHR")
    return {
        "header.bin": data[:16],
        "prg0.bin": data[16:0x4010],
        "prg1.bin": data[0x4010:0x8010],
        "chr0.bin": data[0x8010:0x9010],
        "chr1.bin": data[0x9010:0xA010],
    }


def extract(source, output):
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    for name, data in split_rom(source).items():
        (output / name).write_bytes(data)


def verify(actual, expected):
    actual_data = Path(actual).read_bytes()
    expected_data = Path(expected).read_bytes()
    if actual_data != expected_data:
        common = min(len(actual_data), len(expected_data))
        offset = next((i for i in range(common) if actual_data[i] != expected_data[i]), common)
        raise SystemExit(
            f"ROM различаются: offset=${offset:04X}, "
            f"получено={actual_data[offset:offset + 1].hex() or 'EOF'}, "
            f"ожидалось={expected_data[offset:offset + 1].hex() or 'EOF'}"
        )
    digest = hashlib.sha256(actual_data).hexdigest()
    if digest != EXPECTED_SHA256:
        raise SystemExit(f"неожиданный SHA-256: {digest}")
    print(f"OK: {len(actual_data)} bytes, SHA-256 {digest}")


def main():
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    extract_parser = subparsers.add_parser("extract")
    extract_parser.add_argument("source")
    extract_parser.add_argument("output")

    verify_parser = subparsers.add_parser("verify")
    verify_parser.add_argument("actual")
    verify_parser.add_argument("expected")

    args = parser.parse_args()
    if args.command == "extract":
        extract(args.source, args.output)
    else:
        verify(args.actual, args.expected)


if __name__ == "__main__":
    main()
