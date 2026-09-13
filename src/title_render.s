; Построение nametable заглавного экрана ($D16A-$D254).

PrimaryNametableOffset = $1C        ; shadow $04xx -> PPU $20xx
TitleNametableOffset   = $24        ; shadow $04xx -> PPU $28xx
TitleBackgroundPalette = $03
TitleScoreTileBias     = $30

; Очищает основную nametable $2000: отключает рендеринг/NMI, обнуляет shadow,
; напрямую загружает 1 KiB и снова включает NMI. Выбирает фоновую палитру 3.
; Входов/регистровых результатов нет. Меняет A/X/Y, ScratchPtr,
; NametablePpuOffset=PrimaryNametableOffset, BackgroundPaletteIndex,
; весь nametable shadow и PPU address/data/control state; NMI включён на выходе.
ClearPrimaryNametableScreen:
LD16A:  jsr     DisableRenderingForBulkUpdate
        lda     #TitleBackgroundPalette
        sta     BackgroundPaletteIndex
        lda     #PrimaryNametableOffset
        sta     NametablePpuOffset
        jsr     ClearNametableBuffer
        jsr     UploadNametableBuffer
        jsr     EnableNmiAfterVblank
        rts
; Один раз строит статическую nametable заглавного экрана в $2800.
; При отключённом рендеринге очищает shadow, добавляет крупный логотип через
; DrawVariantTitleData и крупную строку из CHR через RasterizeTileStringToShadow,
; затем напрямую загружает весь 1 KiB.
; После включения NMI ставит в очередь подписи рекорда, игроков и трёх пунктов
; меню; MenuSelection определяет наличие строки второго игрока.
; Побочно меняет A/X/Y, ScratchPtr/AuxPtr, NametablePpuOffset=TitleNametableOffset,
; RasterStringX/Y, TileTranslationOffset=0, score-format scratch, shadow, PPU и
; update buffer. Последняя строка copyright остаётся в очереди до следующего NMI.
BuildTitleNametable:
LD17F:  jsr     DisableRenderingForBulkUpdate
        lda     #TitleNametableOffset
        sta     NametablePpuOffset
        jsr     ClearNametableBuffer
        ldx     #$1A
        stx     RasterStringX
        ldy     #$2E
        sty     RasterStringY
        jsr     DrawVariantTitleData
; Восемь исполняемых NOP сохраняют исходную задержку/layout после расширенного
; обработчика заголовка; отдельных entry points внутри последовательности нет.
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
        lda     #TitleScoreTileBias
        sta     TileTranslationOffset
        lda     #>PlayerOneScorePrefix
        sta     ScratchPtrHi
        lda     #<PlayerOneScorePrefix
        sta     ScratchPtrLo
        ldx     #$02
        ldy     #$03
        jsr     QueueTileAtCoordinates
        ldy     #(Player1Score+1)
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
        ldy     #(HighScore+1)
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
        ldy     #(Player2Score+1)
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
