#!/usr/bin/env python3
"""PNG-представления карт из редактируемых assets; только стандартная библиотека."""

import argparse
import struct
import zlib
from pathlib import Path

try:
    from .chr import read_bmp
    from .levels import decode_level, read_level
    from .metatiles import read_metatiles
    from .palettes import read_palette
except ImportError:
    from chr import read_bmp
    from levels import decode_level, read_level
    from metatiles import read_metatiles
    from palettes import read_palette

# Фиксированное RGB-приближение 64 цветов NES для просмотра на мониторе.
# Это не данные ROM: оттенки на телевизоре/в эмуляторе могут отличаться.
NES_RGB = bytes.fromhex("""
7C7C7C 0000FC 0000BC 4428BC 940084 A80020 A81000 881400
503000 007800 006800 005800 004058 000000 000000 000000
BCBCBC 0078F8 0058F8 6844F8 D800CC D40058 F83800 E45C10
AC7C00 00B800 00A800 00A844 008888 000000 000000 000000
F8F8F8 3CBCFC 6888FC 9878FC F878F8 F85898 F87858 FCA044
F8B800 B8F818 58D854 58F898 00E8D8 787878 000000 000000
FCFCFC A4E4FC B8B8FC D8B8FC F8B8F8 F8A4C0 F0D0B0 FCE0A8
F8D878 D8F878 B8F8B8 B8F8D8 00FCFC F8D8F8 000000 000000
""")
SIZE = 13 * 16


def metatile_pixels(chr_pixels, definitions, palette):
    tiles = []
    for index in range(16):
        pixels = bytearray()
        for y in range(16):
            for x in range(16):
                tile = definitions[16 + index * 4 + (y // 8) * 2 + x // 8]
                pixel = chr_pixels[(tile // 16 * 8 + y % 8) * 128 + tile % 16 * 8 + x % 8]
                # Цвет 0 любой фоновой подпалитры берётся из общего $3F00.
                pixels.append(palette[definitions[index] * 4 + pixel] if pixel else palette[0])
        tiles.append(bytes(pixels))
    return tiles


def render_level(packed, tiles):
    return b"".join(tiles[index][y * 16:(y + 1) * 16]
                    for row in decode_level(packed) for y in range(16) for index in row[:13])


def png_bytes(pixels, scale=2):
    if not 1 <= scale <= 8:
        raise ValueError("масштаб должен быть целым числом 1..8")
    if len(pixels) != SIZE * SIZE or any(pixel >= 64 for pixel in pixels):
        raise ValueError("ожидается поле 208x208 с индексами цветов NES 0..63")

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

    rows = []
    for y in range(SIZE):
        row = b"\0" + b"".join(bytes([pixel]) * scale for pixel in pixels[y * SIZE:(y + 1) * SIZE])
        rows.append(row * scale)
    header = struct.pack(">IIBBBBB", SIZE * scale, SIZE * scale, 8, 3, 0, 0, 0)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"PLTE", NES_RGB) +
            chunk(b"IDAT", zlib.compress(b"".join(rows), 9)) + chunk(b"IEND", b""))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("assets", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--scale", type=int, choices=range(1, 9), default=2)
    args = parser.parse_args()
    paths = sorted((args.assets / "levels").rglob("*.map"))
    if not paths:
        parser.error("в каталоге assets/levels нет .map")
    palette = read_palette(args.assets / "palettes/background.pal")
    if len(palette) < 16:
        parser.error("отсутствует полный набор фоновой палитры 0")
    tiles = metatile_pixels(read_bmp(args.assets / "chr/background.bmp"),
                            read_metatiles(args.assets / "metatiles/background.tsa"), palette[:16])
    for path in paths:
        output = args.output / path.relative_to(args.assets / "levels").with_suffix(".png")
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_bytes(png_bytes(render_level(read_level(path), tiles), args.scale))
    print(f"OK: {len(paths)} PNG, {SIZE * args.scale}x{SIZE * args.scale} -> {args.output}")


if __name__ == "__main__":
    main()
