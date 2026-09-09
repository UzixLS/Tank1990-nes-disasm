#!/usr/bin/env python3
"""Кодирование таблицы фоновых метатайлов 2x2."""

import argparse
from pathlib import Path

METATILE_COUNT = 16


def read_metatiles(path):
    rows = []
    for line_number, line in enumerate(Path(path).read_text(encoding="utf-8").splitlines(), 1):
        line = line.partition("#")[0].strip()
        if not line:
            continue
        try:
            row = [int(token, 16) for token in line.split()]
        except ValueError as error:
            raise ValueError(f"{path}:{line_number}: неверное hex-значение") from error
        if len(row) != 5:
            raise ValueError(f"{path}:{line_number}: ожидаются палитра и четыре тайла")
        if not 0 <= row[0] <= 3 or any(not 0 <= value <= 0xFF for value in row[1:]):
            raise ValueError(f"{path}:{line_number}: значение вне допустимого диапазона")
        rows.append(row)
    if len(rows) != METATILE_COUNT:
        raise ValueError(f"ожидалось {METATILE_COUNT} метатайлов, получено {len(rows)}")
    return bytes(row[0] for row in rows) + bytes(value for row in rows for value in row[1:])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("source")
    parser.add_argument("output")
    args = parser.parse_args()
    Path(args.output).write_bytes(read_metatiles(args.source))


if __name__ == "__main__":
    main()
