; Опрос контроллеров ($D689-$D6B2).
; Файл включается из ppu.s в исходной позиции, чтобы сохранять адреса ROM.

ControllerShiftBits = $00
ControllerBitCount  = $08
ControllerStrobeHigh = $01
LastControllerPortOffset = ControllerStrobeHigh
ControllerSerialValueMask = $03
ControllerPressedThreshold = ControllerStrobeHigh

; Стробирует оба serial controller-а записью 1->0 в $4016, затем читает P2 и P1
; по адресам $4017/$4016. В каждом из восьми чтений после AND #3 любое ненулевое
; значение считается нажатой кнопкой: CMP #1 даёт carry для $01..$03, и этот
; carry переносится ROR-ом в scratch.
; Порядок битов результата: A,B,SELECT,START,Up,Down,Left,Right.
;
; Joy1Held/Joy2Held получают новый полный снимок, Joy1Pressed/Joy2Pressed —
; new & ~old, то есть только фронты 0->1. Выход: A=Joy1Held, X=$FF, Y=0,
; ControllerShiftBits=Joy1Held, N=1/Z=0 от финального DEX; strobe остаётся 0.
; C=0 после восьмого ROR из изначально нулевого scratch, V сохраняется. Меняет
; четыре input-байта и scratch; PPU/APU state не затрагивает.
ReadControllers:  ldx     #LastControllerPortOffset
        ; X=1 одновременно стробирует latch и выбирает сначала порт P2.
        stx     JOY1
        ldy     #$00
        sty     JOY1
ReadNextController:
LD693:  sty     ControllerShiftBits
        ldy     #ControllerBitCount
ReadNextControllerBit:
LD697:  lda     JOY1,x
        and     #ControllerSerialValueMask
        cmp     #ControllerPressedThreshold
        ror     ControllerShiftBits
        dey
        bne     ReadNextControllerBit
        lda     Joy1Held,x
        eor     #$FF
        and     ControllerShiftBits
        sta     Joy1Pressed,x
        lda     ControllerShiftBits
        sta     Joy1Held,x
        dex
        bpl     ReadNextController
        rts
