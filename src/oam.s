; Построение shadow OAM ($DA2B-$DAAE).
; Файл включается из ppu.s в исходной позиции, чтобы сохранять адреса ROM.

OamSavedX = $47
OamSavedY = $48
OamPairX  = $54
OamPairY  = $55

OamEntrySize         = $04
OamHiddenY           = $F0
OamHardwareYBias     = $08
OamTerrainProbeXBias = $03

; Добавляет один 8x8-спрайт в OamShadow через OamBufferPos и OamBufferStep.
; Вход: X/Y -- экранные X и базовый Y, OamTile -- tile,
; RenderAttributes -- attributes, SpriteBehindTerrainMask -- добавочные
; attributes для тайла $22 в shadow под спрайтом. В OAM пишутся
; (Y-8, tile, attributes, X). Побочно меняет OamSavedX/Y, ScratchPtr,
; TerrainSubcellMask и OamBufferPos; для shadow-тайла $22 также
; RenderAttributes. Выход: A=новый OamBufferPos, X=старый OamBufferPos,
; Y=0. OamTile сохраняется; PPU queue/registers не меняет. Проверки выхода
; OamBufferPos за пределы shadow нет.
EmitOamSprite:
LDA2B:  txa
        sta     OamSavedX
        clc
        adc     #OamTerrainProbeXBias
        tax
        tya
        sec
        sbc     #OamHardwareYBias
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
; эффекты как у EmitOamSprite; по выходу OamTile содержит выбранный tile.
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
; вызовом; дважды применяются все побочные эффекты EmitOamSprite. По выходу
; OamTile=base+2, OamBufferPos продвинут на две записи.
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
        sbc     #OamHardwareYBias
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
; Вход: OamBufferStep равен +4 или -4, позиции выровнены по OamEntrySize.
; Выход: OamBufferPos=OamEntrySize, OamBufferStep=-OamBufferStep;
; A=OamHiddenY, X=OamEntrySize, Y сохранён. Меняет только Y-байты
; неиспользованных OAM entries; аппаратный OAM/PPU не трогает.
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
        lda     #OamHiddenY
        sta     OamShadow,x
        cpx     #OamEntrySize
        bne     HideNextUnusedOamEntry
        stx     OamBufferPos
        rts
