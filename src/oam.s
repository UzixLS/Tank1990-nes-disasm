; Построение shadow OAM ($DA2B-$DAAE).
; Файл включается из ppu.s в исходной позиции, чтобы сохранять адреса ROM.

; Добавляет один 8x8-спрайт в OamShadow через OamBufferPos и OamBufferStep.
; Вход: X/Y -- экранные X и базовый Y, OamTile -- tile,
; RenderAttributes -- attributes, SpriteBehindTerrainMask -- добавочные
; attributes для тайла $22 в shadow под спрайтом. В OAM пишутся
; (Y-8, tile, attributes, X). Побочно меняет OamSavedX/Y, ScratchPtr,
; TerrainSubcellMask и OamBufferPos; для shadow-тайла $22 также
; RenderAttributes. A/X/Y изменены.
EmitOamSprite:
LDA2B:  txa
        sta     OamSavedX
        clc
        adc     #$03
        tax
        tya
        sec
        sbc     #$08
        sta     OamSavedY
        jsr     PixelCoordinatesToShadowPointer
        lda     (ScratchPtrLo),y
        cmp     #$22
        bne     StoreOamEntry
        lda     RenderAttributes
        ora     SpriteBehindTerrainMask
        sta     RenderAttributes
StoreOamEntry:
LDA47:  ldx     OamBufferPos
        lda     OamSavedY
        sta     OamShadow,x
        lda     OamTile
        sta     OamShadow+1,x
        lda     RenderAttributes
        sta     OamShadow+2,x
        lda     OamSavedX
        sta     OamShadow+3,x
        txa
        clc
        adc     OamBufferStep
        sta     OamBufferPos
        rts

; Выбирает тайл OamTile+2*A, сдвигает X на -5 и выводит один спрайт.
; Используется для направленных однотайловых объектов. Входы и побочные
; эффекты как у EmitOamSprite.
EmitDirectionalOamSprite:
LDA64:  asl     a
        clc
        adc     OamTile
        sta     OamTile
        txa
        sec
        sbc     #$05
        tax
        jsr     EmitOamSprite
        rts

; Выбирает двухтайловый кадр OamTile+8*A и выводит два соседних по X спрайта
; с тайлами base и base+2. Вход: A -- кадр, X/Y -- позиция;
; OamTile/RenderAttributes/SpriteBehindTerrainMask как у EmitOamSprite.
; Сохраняет исходные X/Y в OamPairX/Y, но по выходу регистры изменены вторым
; вызовом; дважды применяются все побочные эффекты EmitOamSprite.
EmitTwoTileOamObject:
LDA73:  asl     a
        asl     a
        asl     a
        clc
        adc     OamTile
        sta     OamTile
; Альтернативный вход: OamTile уже содержит tile-base, X/Y -- позицию пары.
EmitTwoTileOamPair:
LDA7B:  stx     OamPairX
        sty     OamPairY
        txa
        sec
        sbc     #$08
        tax
        jsr     EmitOamSprite
        inc     OamTile
        inc     OamTile
        ldx     OamPairX
        ldy     OamPairY
        jsr     EmitOamSprite
        rts

; Завершает OAM-кадр: меняет знак OamBufferStep и пишет Y=$F0 в
; неиспользованные записи между OamBufferPos и слотом 1. Чередование
; направления выдачи OAM-слотов меняет приоритет спрайтов между кадрами.
; Выход: OamBufferPos=4, OamBufferStep=-OamBufferStep; A=$F0, X=4.
FinishAlternatingOamFrame:
LDA93:  ldx     OamBufferPos
        lda     OamBufferStep
        eor     #$FF
        clc
        adc     #$01
        sta     OamBufferStep
HideNextUnusedOamEntry:
LDA9E:  txa
        clc
        adc     OamBufferStep
        tax
        lda     #$F0
        sta     OamShadow,x
        cpx     #$04
        bne     HideNextUnusedOamEntry
        stx     OamBufferPos
        rts
