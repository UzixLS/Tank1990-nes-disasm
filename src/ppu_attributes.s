; Адресация shadow и обновление attribute table ($D5FB-$D688).

PpuTileRowBits           = $00
PpuAttributeRowOffset    = $00
PpuAttributePreserveMask = $01
PpuAttributePaletteBits  = $02

ShadowNametableBasePage       = $04
AttributeQuadrantSelectorBit  = $02
AttributeTopLeftPreserveMask  = $FC
AttributeTopRightPreserveMask = $F3
AttributeBottomLeftPreserveMask  = $CF
AttributeBottomRightPreserveMask = $3F
AttributeRowOffsetMask        = $F8

AttributePpuAddressHigh = $23
AttributeTableBaseAddressLo = $C0
AttributeQueueTerminator = $FF

; Преобразует координаты тайла X=0..31, Y=0..31 в адрес shadow nametable:
;   A = $04 + Y / 8, Y = X + (Y & 7) * 32.
; Выходная пара A:Y тем самым адресует
; NametableShadow[input Y*32+input X]. Выход: PpuTileRowBits=
; (input Y & 7)*32; X сохранён. Меняет A/Y, scratch $00 и flags. Использует один байт
; стека, но возвращает SP к исходному; shadow и PPU не меняет.
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
        ora     #ShadowNametableBasePage
        rts

; Обновляет двухбитовую палитру 16x16-квадранта, содержащего тайл X/Y,
; и добавляет команду [$23, $C0+index, value, $FF] в PPU-очередь.
; Вход: X/Y=0..31 — координаты 8x8-тайла; RenderAttributes=0..3;
; в буфере есть место для четырёх байтов команды и следующего lookahead,
; который FlushPpuUpdateBuffer допишет по новой PpuBufferPos.
; Выход: A=$FF, X=PpuBufferPos=old PpuBufferPos+4,
; Y=index=$08*(input Y/4)+input X/4.
; Меняет scratch $00-$02, один байт NametableAttributes, PpuBufferPos,
; четыре байта PpuUpdateBuffer и flags. RenderAttributes, ScratchPtr,
; tile-часть NametableShadow и PPU registers не меняет.
QueueAttributeByteForTile:
LD612:  jsr     UpdateAttributeShadow
        ldx     PpuBufferPos
        lda     #AttributePpuAddressHigh
        sta     PpuUpdateBuffer,x
        inx
        tya
        clc
        adc     #AttributeTableBaseAddressLo
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

; Заменяет два бита RenderAttributes в нужном 16x16-квадранте attribute byte,
; сохраняя остальные три палитры. Вход: X/Y=0..31 — координаты 8x8-тайла;
; RenderAttributes=0..3. Выход: Y=index=$08*(input Y/4)+input X/4,
; A=новый и уже записанный NametableAttributes[index]; X и RenderAttributes
; сохранены. Меняет scratch $00-$02, один attribute byte и flags;
; PPU queue/registers, ScratchPtr и tile-часть NametableShadow не меняет.
UpdateAttributeShadow:
LD635:  lda     RenderAttributes
        jsr     ExpandPaletteBits
        jsr     ExpandPaletteBits
        jsr     ExpandPaletteBits
        sta     PpuAttributePaletteBits
        tya
        and     #AttributeQuadrantSelectorBit
        bne     SelectBottomAttributeQuadrant
        txa
        and     #AttributeQuadrantSelectorBit
        beq     SelectTopLeftAttributeQuadrant
        lda     #AttributeTopRightPreserveMask
        jmp     ApplyAttributeQuadrant

SelectTopLeftAttributeQuadrant:
LD651:  lda     #AttributeTopLeftPreserveMask
        jmp     ApplyAttributeQuadrant

SelectBottomAttributeQuadrant:
LD656:  txa
        and     #AttributeQuadrantSelectorBit
        beq     SelectBottomLeftAttributeQuadrant
        lda     #AttributeBottomRightPreserveMask
        jmp     ApplyAttributeQuadrant

SelectBottomLeftAttributeQuadrant:
LD660:  lda     #AttributeBottomLeftPreserveMask
ApplyAttributeQuadrant:
LD662:  sta     PpuAttributePreserveMask
        tya
        asl     a
        and     #AttributeRowOffsetMask
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

; Один 8-битный шаг A=(A*4)|RenderAttributes. При RenderAttributes=0..3
; три последовательных вызова, начиная с A=RenderAttributes, размножают пару
; битов по всем четырём квадрантам. Выход: A — результат; X/Y,
; RenderAttributes и RAM сохранены; flags изменены.
ExpandPaletteBits:
LD684:  asl     a
        asl     a
        ora     RenderAttributes
        rts
