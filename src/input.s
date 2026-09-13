; Опрос контроллеров ($D689-$D6B2).
; Файл включается из ppu.s в исходной позиции, чтобы сохранять адреса ROM.

ControllerShiftBits = $00
ControllerBitCount  = $08

; Последовательно читает оба контроллера. Joy1Held/Joy2Held — текущее состояние,
; Joy1Pressed/Joy2Pressed — фронты вновь нажатых кнопок. Биты собираются в
; NES-порядке A..Right через ROR. Меняет A/X/Y, ControllerShiftBits и strobe JOY1;
; по выходу X=$FF, Y=0, A=Joy1Held. Strobe оставляет 0; PPU/APU не меняет.
ReadControllers:  ldx     #$01
        stx     JOY1
        ldy     #$00
        sty     JOY1
ReadNextController:
LD693:  sty     ControllerShiftBits
        ldy     #ControllerBitCount
ReadNextControllerBit:
LD697:  lda     JOY1,x
        and     #$03
        cmp     #$01
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
