; Опрос контроллеров ($D689-$D6B2).
; Файл включается из ppu.s в исходной позиции, чтобы сохранять адреса ROM.

PpuControllerBits = $00

; Последовательно читает оба контроллера. Joy1Held/Joy2Held — текущее состояние,
; Joy1Pressed/Joy2Pressed — фронты вновь нажатых кнопок. Биты собираются в
; NES-порядке A..Right через ROR. Меняет A/X/Y, PpuControllerBits и strobe JOY1;
; по выходу X=$FF, Y=0.
ReadControllers:  ldx     #$01
        stx     JOY1
        ldy     #$00
        sty     JOY1
ReadNextController:
LD693:  sty     PpuControllerBits
        ldy     #$08
ReadNextControllerBit:
LD697:  lda     JOY1,x
        and     #$03
        cmp     #$01
        ror     PpuControllerBits
        dey
        bne     ReadNextControllerBit
        lda     Joy1Held,x
        eor     #$FF
        and     PpuControllerBits
        sta     Joy1Pressed,x
        lda     PpuControllerBits
        sta     Joy1Held,x
        dex
        bpl     ReadNextController
        rts
