#!/usr/bin/env python3
"""Преобразование NES CHR pattern table <-> 8-bit indexed BMP."""

import argparse
import struct
from pathlib import Path

WIDTH = HEIGHT = 128
PALETTE = ((0, 0, 0), (85, 85, 85), (170, 170, 170), (255, 255, 255))


def decode_chr(data):
    if len(data) != 4096:
        raise ValueError("pattern table должна занимать ровно 4096 байт")
    pixels = bytearray(WIDTH * HEIGHT)
    for tile in range(256):
        tx, ty = tile % 16 * 8, tile // 16 * 8
        base = tile * 16
        for y in range(8):
            lo, hi = data[base + y], data[base + y + 8]
            for x in range(8):
                bit = 7 - x
                pixels[(ty + y) * WIDTH + tx + x] = ((hi >> bit) & 1) * 2 + ((lo >> bit) & 1)
    return pixels


def encode_chr(pixels):
    if len(pixels) != WIDTH * HEIGHT or any(pixel > 3 for pixel in pixels):
        raise ValueError("BMP должен содержать 128x128 пикселей с индексами 0..3")
    data = bytearray(4096)
    for tile in range(256):
        tx, ty = tile % 16 * 8, tile // 16 * 8
        base = tile * 16
        for y in range(8):
            lo = hi = 0
            for x in range(8):
                pixel = pixels[(ty + y) * WIDTH + tx + x]
                bit = 7 - x
                lo |= (pixel & 1) << bit
                hi |= ((pixel >> 1) & 1) << bit
            data[base + y] = lo
            data[base + y + 8] = hi
    return bytes(data)


def write_bmp(path, pixels):
    stride = (WIDTH + 3) & ~3
    image_size = stride * HEIGHT
    pixel_offset = 14 + 40 + 256 * 4
    header = struct.pack("<2sIHHI", b"BM", pixel_offset + image_size, 0, 0, pixel_offset)
    dib = struct.pack("<IiiHHIIiiII", 40, WIDTH, HEIGHT, 1, 8, 0, image_size, 2835, 2835, 256, 4)
    palette = bytearray(256 * 4)
    for index, (red, green, blue) in enumerate(PALETTE):
        struct.pack_into("<BBBB", palette, index * 4, blue, green, red, 0)
    rows = bytearray()
    for y in range(HEIGHT - 1, -1, -1):
        rows.extend(pixels[y * WIDTH:(y + 1) * WIDTH])
        rows.extend(b"\0" * (stride - WIDTH))
    Path(path).write_bytes(header + dib + palette + rows)


def read_bmp(path):
    data = Path(path).read_bytes()
    if len(data) < 1078 or data[:2] != b"BM":
        raise ValueError("неподдерживаемый BMP")
    pixel_offset = struct.unpack_from("<I", data, 10)[0]
    dib_size, width, height, planes, bpp, compression = struct.unpack_from("<IiiHHI", data, 14)
    if dib_size < 40 or width != WIDTH or abs(height) != HEIGHT:
        raise ValueError("ожидается BMP размером 128x128")
    if planes != 1 or bpp != 8 or compression != 0:
        raise ValueError("ожидается несжатый 8-bit indexed BMP")
    stride = (WIDTH + 3) & ~3
    if len(data) < pixel_offset + stride * HEIGHT:
        raise ValueError("BMP обрезан")
    pixels = bytearray(WIDTH * HEIGHT)
    for output_y in range(HEIGHT):
        input_y = HEIGHT - 1 - output_y if height > 0 else output_y
        start = pixel_offset + input_y * stride
        pixels[output_y * WIDTH:(output_y + 1) * WIDTH] = data[start:start + WIDTH]
    if any(pixel > 3 for pixel in pixels):
        raise ValueError("допустимы только индексы палитры 0..3")
    return pixels


def main():
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    decode = subparsers.add_parser("decode")
    decode.add_argument("input")
    decode.add_argument("output")
    encode = subparsers.add_parser("encode")
    encode.add_argument("input")
    encode.add_argument("output")
    args = parser.parse_args()

    if args.command == "decode":
        write_bmp(args.output, decode_chr(Path(args.input).read_bytes()))
    else:
        Path(args.output).write_bytes(encode_chr(read_bmp(args.input)))


if __name__ == "__main__":
    main()
