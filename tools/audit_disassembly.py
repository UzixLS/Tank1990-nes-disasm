#!/usr/bin/env python3
"""Проверка разметки PRG и статических переходов по debug-информации ca65/ld65."""

import argparse
import json
import re
from pathlib import Path

MNEMONICS = set("""adc and asl bcc bcs beq bit bmi bne bpl brk bvc bvs clc cld cli
clv cmp cpx cpy dec dex dey eor inc inx iny jmp jsr lda ldx ldy lsr nop ora pha
php pla plp rol ror rti rts sbc sec sed sei sta stx sty tax tay tsx txa txs tya""".split())
BRANCHES = {0x10, 0x30, 0x50, 0x70, 0x90, 0xB0, 0xD0, 0xF0}
HANDLER_TABLES = {
    "MenuSelectionHandlers": 3,
    "TankLogicHandlers": 16,
    "TankDrawHandlers": 16,
    "ProjectileLogicHandlers": 5,
    "ProjectileDrawHandlers": 5,
    "PowerUpEffectHandlers": 8,
    "BaseDestructionFrameHandlers": 6,
    "AudioCommandHandlers": 18,
}


def read_debug(path):
    records = {}
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        kind, fields = line.split("\t", 1)
        record = dict(re.findall(r'(\w+)=("[^"]*"|[^,]+)', fields))
        records.setdefault(kind, []).append(record)
    return records


def audit(rom, debug, root):
    records = read_debug(debug)
    segments = {row["id"]: row for row in records["seg"]}
    spans = {row["id"]: row for row in records["span"]}
    files = {row["id"]: row["name"].strip('"') for row in records["file"]}
    symbols = {row["name"].strip('"'): int(row["val"], 0)
               for row in records["sym"] if "val" in row}
    coverage = set()
    for span in spans.values():
        segment = segments[span["seg"]]
        base = int(segment["start"], 0)
        if base < 0x8000:
            continue
        start = base + int(span["start"])
        coverage.update(range(start, start + int(span["size"])))
    if coverage != set(range(0x8000, 0x10000)):
        raise ValueError("PRG должен быть целиком размечен, без неявного linker fill")

    sources = {}
    code = {}
    for line in records["line"]:
        if "span" not in line:
            continue
        name = files[line["file"]]
        if name not in sources:
            sources[name] = (root / name).read_text(encoding="utf-8").splitlines()
        source = sources[name][int(line["line"]) - 1].partition(";")[0]
        source = source.split(":", 1)[-1].strip().split()
        if not source or source[0].lower() not in MNEMONICS:
            continue
        for span_id in line["span"].split("+"):
            span = spans[span_id]
            address = int(segments[span["seg"]]["start"], 0) + int(span["start"])
            code[address] = int(span["size"])

    anchors = 0
    for name, address in symbols.items():
        if re.fullmatch(r"L[0-9A-F]{4}", name):
            if int(name[1:], 16) != address:
                raise ValueError(f"сдвинута адресная метка {name}: ${address:04X}")
            anchors += 1

    def read(address, size):
        return rom[address - 0x8000 + 16:address - 0x8000 + 16 + size]

    def word(address):
        return int.from_bytes(read(address, 2), "little")

    # Два документированных входа с перекрытием инструкций.
    for address, data in {0xDA1C: b"\xc0\x0a", 0xEC87: b"\x2c\xa2\x02"}.items():
        if read(address, len(data)) != data:
            raise ValueError(f"изменён overlap по ${address:04X}")
        code[address] = len(data)

    transfers = 0
    indirect = []
    for address, size in sorted(code.items()):
        opcode = read(address, 1)[0]
        targets = []
        if opcode in BRANCHES:
            displacement = int.from_bytes(read(address + 1, 1), "little", signed=True)
            targets.append((address + 2 + displacement) & 0xFFFF)
            transfers += 1
        elif opcode in (0x20, 0x4C):
            targets.append(word(address + 1))
            transfers += 1
        elif opcode == 0x6C:
            indirect.append(f"${address:04X}")
        inline_dispatch = opcode == 0x20 and word(address + 1) == symbols["DispatchAudioCommand"]
        if opcode not in (0x00, 0x40, 0x60, 0x4C, 0x6C) and not inline_dispatch:
            # Усечённый НЕИСПОЛЬЗУЕМЫЙ прототип не имеет RTS перед $FF.
            if address + size != 0xBFC0:
                targets.append(address + size)
        for target in targets:
            if target not in code:
                raise ValueError(f"переход/продолжение ${address:04X} -> данные ${target:04X}")

    vectors = {name: word(address) for name, address in
               (("NMI", 0xFFFA), ("RESET", 0xFFFC), ("IRQ", 0xFFFE))}
    for target in vectors.values():
        if target not in code:
            raise ValueError(f"вектор указывает на данные ${target:04X}")
    for name, count in HANDLER_TABLES.items():
        for index in range(count):
            target = word(symbols[name] + index * 2)
            if target not in code:
                raise ValueError(f"{name}[{index}] -> данные ${target:04X}")
    return {
        "prg_bytes_covered": len(coverage),
        "instruction_starts_including_overlaps": len(code),
        "address_labels_checked": anchors,
        "direct_transfers_checked": transfers,
        "handler_pointers_checked": sum(HANDLER_TABLES.values()),
        "indirect_jump_sites": indirect,
        "vectors": {name: f"${address:04X}" for name, address in vectors.items()},
        "overlapping_instructions": {"$DA1C": "CPY #$0A", "$EC87": "BIT $02A2"},
        "inline_dispatch": "$EBE3 JSR consumes return address; $EBE6 is a pointer table",
        "truncated_unused_prototype": "$BFBB-$BFBF falls into $FF at $BFC0",
        "scope": "Static boundaries and transfers; not proof of all dynamic paths or comments.",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rom", type=Path)
    parser.add_argument("debug", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    result = audit(args.rom.read_bytes(), args.debug, Path(__file__).resolve().parents[1])
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"OK: PRG coverage, {result['direct_transfers_checked']} transfers, "
          f"{result['handler_pointers_checked']} handler pointers")


if __name__ == "__main__":
    main()
