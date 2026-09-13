; Адресация shadow и обновление attribute table ($D5FB-$D688).

PpuTileRowBits           = $00
PpuAttributeRowOffset    = $00
PpuAttributePreserveMask = $01
PpuAttributePaletteBits  = $02

AttributePpuAddressHigh = $23
AttributeTableAddressLo = $C0
AttributeQueueTerminator = $FF

; Преобразует координаты тайла X=0..31, Y=0..31 в адрес shadow nametable:
;   A = $04 + Y / 8, Y = X + (Y & 7) * 32.
; Меняет A/Y и PpuTileRowBits; X сохраняет.
TileCoordinatesToShadowAddress:
LD5FB:  lda     #$00
        sta     PpuTileRowBits
        tya
        lsr     a
        ror     PpuTileRowBits
        lsr     a
        ror     PpuTileRowBits
        lsr     a
        ror     PpuTileRowBits
        pha
        txa
        ora     PpuTileRowBits
        tay
        pla
        ora     #$04
        rts

; Обновляет атрибут палитры для тайла X/Y и добавляет однобайтовую
; запись $23C0+index в PPU-очередь. Вход: X/Y -- координаты 8x8-тайла,
; RenderAttributes -- палитра 0..3.
; Выход: A=$FF, X=PpuBufferPos после четырёх добавленных байтов, Y — индекс
; attribute table. Меняет attribute scratch, NametableAttributes и PPU queue;
; ScratchPtr, PPU registers и nametable tile shadow не меняет. Capacity буфера
; вызывающий должен обеспечить заранее.
QueueAttributeByteForTile:
LD612:  jsr     UpdateAttributeShadow
        ldx     PpuBufferPos
        lda     #AttributePpuAddressHigh
        sta     PpuUpdateBuffer,x
        inx
        tya
        clc
        adc     #AttributeTableAddressLo
        sta     PpuUpdateBuffer,x
        inx
        lda     NametableAttributes,y
        sta     PpuUpdateBuffer,x
        inx
        lda     #AttributeQueueTerminator
        sta     PpuUpdateBuffer,x
        inx
        stx     PpuBufferPos
        rts

; Вставляет два бита RenderAttributes в нужный квадрант attribute byte.
; Вход: X/Y -- координаты 8x8-тайла, RenderAttributes=0..3.
; Выход: Y — индекс attribute table, A — новый и уже записанный байт; X
; сохраняется. Портит четыре attribute scratch-байта и flags, PPU queue/registers
; не меняет.
UpdateAttributeShadow:
LD635:  lda     RenderAttributes
        jsr     ExpandPaletteBits
        jsr     ExpandPaletteBits
        jsr     ExpandPaletteBits
        sta     PpuAttributePaletteBits
        tya
        and     #$02
        bne     SelectBottomAttributeQuadrant
        txa
        and     #$02
        beq     SelectTopLeftAttributeQuadrant
        lda     #$F3
        jmp     ApplyAttributeQuadrant

SelectTopLeftAttributeQuadrant:
LD651:  lda     #$FC
        jmp     ApplyAttributeQuadrant

SelectBottomAttributeQuadrant:
LD656:  txa
        and     #$02
        beq     SelectBottomLeftAttributeQuadrant
        lda     #$3F
        jmp     ApplyAttributeQuadrant

SelectBottomLeftAttributeQuadrant:
LD660:  lda     #$CF
ApplyAttributeQuadrant:
LD662:  sta     PpuAttributePreserveMask
        tya
        asl     a
        and     #$F8
        sta     PpuAttributeRowOffset
        txa
        lsr     a
        lsr     a
        clc
        adc     PpuAttributeRowOffset
        tay
        lda     PpuAttributePreserveMask
        eor     #$FF
        and     PpuAttributePaletteBits
        sta     PpuAttributePaletteBits
        lda     NametableAttributes,y
        and     PpuAttributePreserveMask
        ora     PpuAttributePaletteBits
        sta     NametableAttributes,y
        rts

; Один шаг A=(A*4)|RenderAttributes. Три вызова размножают двухбитовую палитру
; по всем четырём квадрантам attribute byte. X/Y и RAM сохраняет; меняет A/flags.
ExpandPaletteBits:
LD684:  asl     a
        asl     a
        ora     RenderAttributes
        rts
