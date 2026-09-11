; Построение nametable заглавного экрана ($D16A-$D254).

; Очищает основную nametable $2000: отключает рендеринг/NMI, обнуляет shadow,
; напрямую загружает 1 KiB и снова включает NMI. Выбирает фоновую палитру 3.
; Меняет A/X/Y, ScratchPtr, NametablePpuOffset, BackgroundPaletteIndex,
; shadow и PPU.
ClearPrimaryNametableScreen:
LD16A:  jsr     DisableRenderingForBulkUpdate
        lda     #$03
        sta     BackgroundPaletteIndex
        lda     #$1C
        sta     NametablePpuOffset
        jsr     ClearNametableBuffer
        jsr     UploadNametableBuffer
        jsr     EnableNmiAfterVblank
        rts
; Один раз строит статическую nametable заглавного экрана в $2400.
; При отключённом рендеринге очищает shadow, добавляет крупный логотип через
; внешний LE3D8 и крупную строку из CHR через LD8D2, затем загружает весь 1 KiB.
; После включения NMI ставит в очередь подписи рекорда, игроков и трёх пунктов
; меню; MenuSelection определяет наличие строки второго игрока.
; Побочно меняет A/X/Y, ScratchPtr/AuxPtr, NametablePpuOffset, $56/$57,
; TileTranslationOffset, shadow, PPU и очередь.
BuildTitleNametable:
LD17F:  jsr     DisableRenderingForBulkUpdate
        lda     #$24
        sta     NametablePpuOffset
        jsr     ClearNametableBuffer
        ldx     #$1A
        stx     RasterStringX
        ldy     #$2E
        sty     RasterStringY
        jsr     DrawVariantTitleData
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        ldx     #$3C
        stx     RasterStringX
        ldy     #$56
        sty     RasterStringY
        lda     #>EditionYearText
        sta     AuxPtrHi
        lda     #<EditionYearText
        sta     AuxPtrLo
        jsr     RasterizeTileStringToShadow
        jsr     UploadNametableBuffer
        jsr     EnableNmiAfterVblank
        lda     #$30
        sta     TileTranslationOffset
        lda     #>PlayerOneScorePrefix
        sta     ScratchPtrHi
        lda     #<PlayerOneScorePrefix
        sta     ScratchPtrLo
        ldx     #$02
        ldy     #$03
        jsr     QueueTileAtCoordinates
        ldy     #$16
        ldx     #$04
        jsr     SelectVisibleDigits
        ldy     #$03
        jsr     QueueTranslatedTileString
        lda     #>HighScoreCompactPrefix
        sta     ScratchPtrHi
        lda     #<HighScoreCompactPrefix
        sta     ScratchPtrLo
        ldx     #$0B
        ldy     #$03
        jsr     QueueTileAtCoordinates
        ldy     #$3E
        ldx     #$0E
        jsr     SelectVisibleDigits
        ldy     #$03
        jsr     QueueTranslatedTileString
        lda     MenuSelection
        beq     QueueTitleMenuText
        lda     #>PlayerTwoScorePrefix
        sta     ScratchPtrHi
        lda     #<PlayerTwoScorePrefix
        sta     ScratchPtrLo
        ldx     #$15
        ldy     #$03
        jsr     QueueTileAtCoordinates
        ldy     #$1E
        ldx     #$17
        jsr     SelectVisibleDigits
        ldy     #$03
        jsr     QueueTranslatedTileString
QueueTitleMenuText:
LD20E:  lda     #$00
        sta     TileTranslationOffset
        jsr     WaitForNextFrame
        lda     #>OnePlayerMenuText
        sta     ScratchPtrHi
        lda     #<OnePlayerMenuText
        sta     ScratchPtrLo
        ldx     #$0B
        ldy     #$11
        jsr     QueueTileAtCoordinates
        lda     #>TwoPlayersMenuText
        sta     ScratchPtrHi
        lda     #<TwoPlayersMenuText
        sta     ScratchPtrLo
        ldx     #$0B
        ldy     #$13
        jsr     QueueTileAtCoordinates
        lda     #>ConstructionMenuText
        sta     ScratchPtrHi
        lda     #<ConstructionMenuText
        sta     ScratchPtrLo
        ldx     #$0B
        ldy     #$15
        jsr     QueueTileAtCoordinates
        jsr     WaitForNextFrame
        lda     #>CreditsCopyrightText
        sta     ScratchPtrHi
        lda     #<CreditsCopyrightText
        sta     ScratchPtrLo
        ldx     #$0B
        ldy     #$18
        jsr     QueueTileAtCoordinates
        rts
