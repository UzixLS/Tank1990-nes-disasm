#!/usr/bin/env python3
"""Преобразование упакованных карт Tank 1990 в редактируемый текст."""

import argparse
from pathlib import Path

LEVEL_SIZE = 91
ROWS = 13
NIBBLES_PER_ROW = 14


def decode_level(data):
    if len(data) != LEVEL_SIZE:
        raise ValueError("карта должна занимать 91 байт")
    nibbles = []
    for value in data:
        nibbles.extend((value >> 4, value & 0x0F))
    return [nibbles[row * NIBBLES_PER_ROW:(row + 1) * NIBBLES_PER_ROW] for row in range(ROWS)]


def encode_level(rows):
    if len(rows) != ROWS or any(len(row) != NIBBLES_PER_ROW for row in rows):
        raise ValueError("ожидается 13 строк по 14 значений")
    values = [value for row in rows for value in row]
    if any(not 0 <= value <= 0x0F for value in values):
        raise ValueError("элементы карты должны быть hex-значениями 0..F")
    return bytes(values[index] << 4 | values[index + 1] for index in range(0, len(values), 2))


def write_level(path, data):
    lines = [
        "# 13x13 TSA-блоков; последнее значение каждой строки — сохраняемый padding.",
        *(
            " ".join(f"{value:X}" for value in row[:13]) + f"  | {row[13]:X}"
            for row in decode_level(data)
        ),
    ]
    Path(path).write_text("\n".join(lines) + "\n", encoding="utf-8")


def read_level(path):
    rows = []
    for line_number, line in enumerate(Path(path).read_text(encoding="utf-8").splitlines(), 1):
        line = line.partition("#")[0].replace("|", " ").strip()
        if not line:
            continue
        try:
            row = [int(value, 16) for value in line.split()]
        except ValueError as error:
            raise ValueError(f"{path}:{line_number}: неверное hex-значение") from error
        rows.append(row)
    return encode_level(rows)


def decode_set(source, offset, count, output):
    data = Path(source).read_bytes()
    end = offset + count * LEVEL_SIZE
    if offset < 0 or end > len(data):
        raise ValueError("набор карт выходит за пределы входного файла")
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    for index in range(count):
        start = offset + index * LEVEL_SIZE
        write_level(output / f"{index + 1:03}.map", data[start:start + LEVEL_SIZE])


def encode_set(source, count, output):
    source = Path(source)
    paths = [source / f"{index:03}.map" for index in range(1, count + 1)]
    missing = [str(path) for path in paths if not path.is_file()]
    if missing:
        raise ValueError(f"отсутствует карта {missing[0]}")
    Path(output).write_bytes(b"".join(read_level(path) for path in paths))


def main():
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    decode = subparsers.add_parser("decode")
    decode.add_argument("source")
    decode.add_argument("offset", type=lambda value: int(value, 0))
    decode.add_argument("count", type=int)
    decode.add_argument("output")

    encode = subparsers.add_parser("encode")
    encode.add_argument("source")
    encode.add_argument("count", type=int)
    encode.add_argument("output")

    args = parser.parse_args()
    if args.command == "decode":
        decode_set(args.source, args.offset, args.count, args.output)
    else:
        encode_set(args.source, args.count, args.output)


if __name__ == "__main__":
    main()
