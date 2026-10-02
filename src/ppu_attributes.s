; Адресация shadow и обновление attribute table ($D5FB-$D688).

PpuTileRowBits           = $00
PpuAttributeRowOffset    = $00
PpuAttributePreserveMask = $01
PpuAttributePaletteBits  = $02

ShadowNametableBasePage       = $04
AttributeQuadrantSelectorBit  = $02
AttributeTileSpan             = $04
AttributeBytesPerRow          = $08
AttributeTopLeftPreserveMask  = $FC
AttributeTopRightPreserveMask = $F3
AttributeBottomLeftPreserveMask  = $CF
AttributeBottomRightPreserveMask = $3F
AttributeRowOffsetMask        = $F8

AttributePpuAddressHigh = $23
AttributeTableBaseAddressLo = $C0
AttributeQueueTerminator = $FF
AttributeQueueMaxStartPos = $7B

; Преобразует координаты тайла X=0..31, Y=0..31 в адрес shadow nametable:
;   A = $04 + Y / 8, Y = X + (Y & 7) * 32.
; OR вместо сложения low byte корректен только при X<32: X занимает bits0..4,
; row offset — bits5..7. Rows 30/31 адресуют attribute storage $07C0-$07FF,
; а не tile-часть; вызывающий должен отличать эти применения.
;
; Выходная пара A:Y адресует NametableShadow[input Y*32+input X];
; PpuTileRowBits=(input Y&7)*32, X сохранён, N=Z=0,
; C=input Y bit2 (carry последнего LSR). Меняет A/Y, scratch $00 и flags,
; V сохраняет. Временно использует один байт стека, но восстанавливает SP;
; shadow и PPU queue/registers не меняет. Формат привязан к базе $0400.
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

; Обновляет двухбитовую palette квадранта 2x2 tiles (16x16 px), содержащего
; tile X/Y, и добавляет [$23,$C0+index,value,$FF]. Attribute byte покрывает
; 4x4 tiles (AttributeTileSpan по каждой оси): bits1..0=top-left,
; 3..2=top-right, 5..4=bottom-left,
; 7..6=bottom-right. index=8*(Y/4)+X/4 адресует $07C0..$07FF/$23C0..$23FF.
; PPU-адрес всегда относится к primary nametable и не учитывает
; NametablePpuOffset.
;
; Вход: X/Y=0..31 — координаты 8x8-тайла; RenderAttributes=0..3;
; PpuBufferPos<=AttributeQueueMaxStartPos ($7B), NMI не flush-ит очередь во
; время построения. Четыре байта
; команды и lookahead, который FlushPpuUpdateBuffer пишет по новому cursor,
; тогда остаются внутри $0180-$01FF. Значение attribute=$FF допустимо: data FF
; и terminator FF образуют экранированный literal по протоколу flush.
; Выход: A=$FF, X=PpuBufferPos=old PpuBufferPos+4,
; Y=index=$08*(input Y/4)+input X/4, N=Z=C=V=0 при валидном buffer position.
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

; Shadow-only ядро предыдущей процедуры. Выбирает квадрант по bit1 X/Y,
; размножает RenderAttributes в четыре пары, затем маской оставляет только пару
; выбранного квадранта и объединяет её с тремя сохранёнными парами.
; Вход: X/Y=0..31, RenderAttributes=0..3. Выход:
; Y=index=$08*(input Y/4)+input X/4, A=новый и уже записанный attribute byte;
; X и RenderAttributes сохранены, N/Z соответствуют A, C=V=0.
; PpuAttributeRowOffset=$08*(input Y/4), PpuAttributePreserveMask содержит
; выбранную маску, PpuAttributePaletteBits — только размещённую palette pair.
; Меняет scratch $00-$02, один attribute byte и flags;
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

; Один 8-битный шаг A=(4*A)|RenderAttributes. При RenderAttributes=0..3 три
; вызова, начиная с A=RenderAttributes, дают байт с четырьмя одинаковыми
; palette pairs. Выход: A=result mod 256, N/Z по нему, C=input A bit6 после
; второго ASL; V сохраняется. X/Y, RenderAttributes, RAM и стек сохранены.
ExpandPaletteBits:
LD684:  asl     a
        asl     a
        ora     RenderAttributes
        rts
