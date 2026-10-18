"""Узкий исполнитель 6502 для проверки байтов LoadAndDrawStage из ROM.

Реализованы только встречающиеся здесь инструкции и флаги N/Z/C (V не читается).
NMI/PPU не эмулируются: WaitForNextFrame считает строки, DrawMetatile записывает
аргументы и портит scratch. Неизвестный opcode или слишком длинный проход — ошибка.
"""

READ_OPS = {
    0xA9: ("lda", "imm"), 0xA5: ("lda", "zp"), 0xBD: ("lda", "absx"),
    0xB1: ("lda", "indy"), 0xA6: ("ldx", "zp"), 0xA4: ("ldy", "zp"),
    0xC9: ("cmp", "imm"), 0xC5: ("cmp", "zp"), 0x29: ("and", "imm"),
    0x69: ("adc", "imm"), 0x65: ("adc", "zp"),
    0xE9: ("sbc", "imm"), 0xE5: ("sbc", "zp"),
}


class StageProbe:
    def __init__(self, rom, variant=0, stage=1, attract=False, pointer=None):
        self.memory = bytearray(0x10000)
        self.memory[0x8000:] = rom[16:0x8010]
        self.memory[0x46] = variant
        self.memory[0x85] = stage
        self.a, self.x, self.y = (0xFF if attract else 0), 0, 0
        self.c, self.z, self.n = False, False, False
        self.pc, self.sp = 0xEF76, 0xFD
        self.push(0x7F)
        self.push(0xFE)  # RTS верхнего уровня вернётся на $7FFF.
        self.tiles = []
        self.frames = 0
        if pointer is not None:
            self.memory[0x11] = pointer & 0xFF
            self.memory[0x12] = pointer >> 8
            self.pc = 0xEFCE

    def push(self, value):
        self.memory[0x100 + self.sp] = value
        self.sp = (self.sp - 1) & 0xFF

    def pop(self):
        self.sp = (self.sp + 1) & 0xFF
        return self.memory[0x100 + self.sp]

    def fetch(self):
        value = self.memory[self.pc]
        self.pc = (self.pc + 1) & 0xFFFF
        return value

    def word(self):
        low = self.fetch()
        return low | self.fetch() << 8

    def nz(self, value):
        value &= 0xFF
        self.z, self.n = value == 0, bool(value & 0x80)
        return value

    def operand(self, mode):
        if mode == "imm":
            return self.fetch()
        if mode == "zp":
            return self.memory[self.fetch()]
        if mode == "absx":
            return self.memory[(self.word() + self.x) & 0xFFFF]
        zp = self.fetch()
        address = self.memory[zp] | self.memory[(zp + 1) & 0xFF] << 8
        return self.memory[(address + self.y) & 0xFFFF]

    def run(self, select_only=False):
        for _ in range(30000):
            if self.pc == 0x7FFF:
                return
            if select_only and self.pc == 0xEFCE:
                return self.memory[0x11] | self.memory[0x12] << 8
            if self.pc == 0xD8F6:  # WaitForNextFrame
                self.frames += 1
                opcode = 0x60
            elif self.pc == 0xD80B:  # DrawMetatile
                self.tiles.append((self.a, self.x, self.y))
                self.memory[0x00] = 0x40
                self.memory[0x11:0x13] = b"\x7b\x07"
                self.x, self.y = 4 * self.a + 4, 0
                opcode = 0x60
            else:
                opcode = self.fetch()
            if opcode in READ_OPS:
                operation, mode = READ_OPS[opcode]
                value = self.operand(mode)
                if operation in ("lda", "ldx", "ldy"):
                    setattr(self, operation[-1], self.nz(value))
                elif operation == "cmp":
                    self.c = self.a >= value
                    self.nz(self.a - value)
                elif operation == "and":
                    self.a = self.nz(self.a & value)
                else:
                    total = self.a + (value if operation == "adc" else value ^ 0xFF) + self.c
                    self.c = total > 0xFF
                    self.a = self.nz(total)
            elif opcode == 0x85:
                self.memory[self.fetch()] = self.a
            elif opcode in (0xE6, 0xC6):
                address = self.fetch()
                self.memory[address] = self.nz(self.memory[address] + (1 if opcode == 0xE6 else -1))
            elif opcode in (0x0A, 0x4A):
                self.c = bool(self.a & (0x80 if opcode == 0x0A else 1))
                self.a = self.nz(self.a << 1 if opcode == 0x0A else self.a >> 1)
            elif opcode in (0x18, 0x38):
                self.c = opcode == 0x38
            elif opcode == 0xAA:
                self.x = self.nz(self.a)
            elif opcode == 0xA8:
                self.y = self.nz(self.a)
            elif opcode == 0xE8:
                self.x = self.nz(self.x + 1)
            elif opcode == 0x48:
                self.push(self.a)
            elif opcode == 0x68:
                self.a = self.nz(self.pop())
            elif opcode == 0x20:
                target = self.word()
                self.push((self.pc - 1) >> 8)
                self.push((self.pc - 1) & 0xFF)
                self.pc = target
            elif opcode == 0x60:
                low = self.pop()
                self.pc = ((low | self.pop() << 8) + 1) & 0xFFFF
            elif opcode == 0x4C:
                self.pc = self.word()
            elif opcode in (0x90, 0xB0, 0xD0, 0xF0):
                offset = self.fetch()
                take = {0x90: not self.c, 0xB0: self.c, 0xD0: not self.z, 0xF0: self.z}[opcode]
                if take:
                    self.pc = (self.pc + (offset if offset < 128 else offset - 256)) & 0xFFFF
            else:
                raise ValueError(f"unsupported opcode ${opcode:02X} at ${(self.pc - 1):04X}")
        raise ValueError("stage loader did not finish")
