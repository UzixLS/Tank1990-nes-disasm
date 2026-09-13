; Отрисовка TSA-метатайла в shadow и PPU-очередь ($D80B-$D85D).

MetatileIndex = $00
MetatileTileX = $47
MetatileTileY = $48
MetatileTileCount = $04

; Рисует TSA-блок 2x2 тайла и обновляет его атрибут палитры.
; Вход: A -- индекс метатайла 0..15, X/Y -- пиксельные координаты. Процедура
; сама выравнивает полученные тайловые координаты на ячейку 16x16 пикселей.
; Пишет четыре тайла в shadow и четыре PPU-команды, а также одну команду атрибута.
; Меняет A/X/Y, ScratchPtr, MetatileIndex/MetatileTileX/Y, RenderAttributes,
; прочую scratch-RAM $01-$03, attribute shadow и PPU-очередь.
; Выход: A=$FF, X=4*MetatileIndex+MetatileTileCount, Y=0; ScratchPtr указывает
; нижний правый shadow tile. PPU registers не трогает; capacity очереди не проверяет.
DrawMetatile:  pha
        sta     MetatileIndex
        jsr     PixelToTileCoordinates
        stx     MetatileTileX
        sty     MetatileTileY
        ldy     MetatileIndex
        lda     MetatilePalettes,y
        sta     RenderAttributes
        ldy     MetatileTileY
        jsr     QueueAttributeByteForTile
        lda     MetatileTileY
        and     #$FE
        tay
        lda     MetatileTileX
        and     #$FE
        tax
        jsr     TileCoordinatesToShadowPointer
        pla
        asl     a
        asl     a
        tax
        lda     MetatileTiles,x
        inx
        jsr     StoreAndQueueShadowTile
        lda     #$01
        jsr     AddAToPointer
        lda     MetatileTiles,x
        inx
        jsr     StoreAndQueueShadowTile
        lda     #$1F
        jsr     AddAToPointer
        lda     MetatileTiles,x
        inx
        jsr     StoreAndQueueShadowTile
        lda     #$01
        jsr     AddAToPointer
        lda     MetatileTiles,x
        inx
        jsr     StoreAndQueueShadowTile
        rts
