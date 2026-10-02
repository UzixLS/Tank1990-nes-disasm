; Отрисовка TSA-метатайла в shadow и PPU-очередь ($D80B-$D85D).

MetatileInputIndex             = $00
MetatileTileX                  = $47
MetatileTileY                  = $48
MetatileDefinitionCount       = $10
MetatileTilesPerDefinition    = $04
MetatileTileCoordinateAlignMask = $FE
MetatileNextColumnShadowDelta = $01
MetatileNextRowFromRightDelta = $1F
MetatileQueueByteCount        = $14
MetatileQueueMaxStartPos      = $6B

; Рисует TSA-блок 2x2 tiles (16x16 px), содержащий входную pixel coordinate.
; Tile origin равен (floor(input X/16)*2, floor(input Y/16)*2): младший bit
; полученных 8x8 tile coordinates отбрасывается, то есть координаты округляются
; вниз, а не к центру клетки. Порядок таблицы и записи: top-left, top-right,
; bottom-left, bottom-right; переходы ScratchPtr между ними равны +1,+$1F,+1.
;
; Вход: A=metatile index 0..MetatileDefinitionCount-1, X/Y=unsigned pixels;
; input Y<=239, иначе rows30/31 перезапишут attribute storage shadow;
; PpuBufferPos<=MetatileQueueMaxStartPos ($6B), и NMI не должен flush-ить
; очередь во время построения. Ограничение X не требуется: весь byte 0..255
; отображается в допустимые tile columns 0..31.
;
; Сначала обновляет attribute shadow и ставит 4-byte команду $23C0..$23FF,
; затем пишет четыре shadow tiles и ставит четыре однотайловые команды. Все пять
; PPU-команд жёстко направлены в primary nametable и игнорируют
; NametablePpuOffset. Всего добавляет MetatileQueueByteCount ($14) bytes;
; лимит учитывает следующий lookahead, записываемый FlushPpuUpdateBuffer.
;
; Выход: A=$FF, X=4*input A+MetatileTilesPerDefinition (4..64), Y=0,
; PpuBufferPos=old+$14; ScratchPtr указывает на lower-right shadow tile;
; RenderAttributes=palette index выбранного определения; N=Z=C=V=0.
; Меняет $00-$02, $47/$48, ScratchPtr, четыре tile bytes и один attribute byte
; shadow, PpuBufferPos и 20 bytes PpuUpdateBuffer. MetatileInputIndex в $00
; живёт только до чтения palette: затем alias переиспользуется PPU/shadow
; адресацией; $47 после первого queued tile также служит ShadowQueueSavedX.
; PPU registers не трогает, capacity кодом не проверяет. Literal tile $FF
; допустим в однотайловой команде StoreAndQueueShadowTile.
DrawMetatile:  pha
        sta     MetatileInputIndex
        jsr     PixelToTileCoordinates
        stx     MetatileTileX
        sty     MetatileTileY
        ldy     MetatileInputIndex
        lda     MetatilePalettes,y
        sta     RenderAttributes
        ldy     MetatileTileY
        jsr     QueueAttributeByteForTile
        lda     MetatileTileY
        and     #MetatileTileCoordinateAlignMask
        tay
        lda     MetatileTileX
        and     #MetatileTileCoordinateAlignMask
        tax
        jsr     TileCoordinatesToShadowPointer
        pla
        asl     a
        asl     a
        tax
        lda     MetatileTiles,x
        inx
        jsr     StoreAndQueueShadowTile
        lda     #MetatileNextColumnShadowDelta
        jsr     AddAToPointer
        lda     MetatileTiles,x
        inx
        jsr     StoreAndQueueShadowTile
        lda     #MetatileNextRowFromRightDelta
        jsr     AddAToPointer
        lda     MetatileTiles,x
        inx
        jsr     StoreAndQueueShadowTile
        lda     #MetatileNextColumnShadowDelta
        jsr     AddAToPointer
        lda     MetatileTiles,x
        inx
        jsr     StoreAndQueueShadowTile
        rts
