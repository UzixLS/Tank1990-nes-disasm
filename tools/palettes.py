#!/usr/bin/env python3
"""Кодирование текстовых палитр NES."""

import argparse
from pathlib import Path


def read_palette(path):
    values = []
    for line_number, line in enumerate(Path(path).read_text(encoding="utf-8").splitlines(), 1):
        for token in line.partition("#")[0].split():
            try:
                value = int(token, 16)
            except ValueError as error:
                raise ValueError(f"{path}:{line_number}: неверное hex-значение") from error
            if not 0 <= value <= 0x3F:
                raise ValueError(f"{path}:{line_number}: цвет NES должен быть в диапазоне 00..3F")
            values.append(value)
    return bytes(values)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("source")
    parser.add_argument("size", type=int)
    parser.add_argument("output")
    args = parser.parse_args()

    data = read_palette(args.source)
    if len(data) != args.size:
        raise ValueError(f"ожидалось {args.size} байт палитры, получено {len(data)}")
    Path(args.output).write_bytes(data)


if __name__ == "__main__":
    main()
