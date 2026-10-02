; Построение nametable заглавного экрана ($D16A-$D254).

TitleScoreTileBias     = $30
TitleLogoRasterX       = $1A
TitleLogoRasterY       = $2E
TitleYearRasterX       = $3C
TitleYearRasterY       = $56
TitleScoreRow          = $03
TitlePlayer1LabelColumn       = $02
TitlePlayer1ScoreFormatColumn = $04
TitleHighScoreLabelColumn     = $0B
TitleHighScoreFormatColumn    = $0E
TitlePlayer2LabelColumn       = $15
TitlePlayer2ScoreFormatColumn = $17
TitleMenuTextColumn    = $0B
TitleOnePlayerRow      = $11
TitleTwoPlayerRow      = $13
TitleConstructionRow   = $15
TitleCopyrightRow      = $18

; Очищает основную nametable $2000: отключает рендеринг/NMI, обнуляет shadow,
; напрямую загружает 1 KiB и снова включает NMI. Выбирает фоновую палитру 3.
; Вход: NMI включён, иначе DisableRenderingForBulkUpdate не завершится.
; Выход: A=EnabledNmiPpuCtrlValue, X=Y=0, ScratchPtr=$0800,
; NametablePpuOffset=ShadowToPrimaryNametableOffset, BackgroundPaletteIndex=3.
; Полностью очищает shadow и VRAM $2000..$23FF, меняет PPU address/control/mask.
; NMI включён, но palette 3 и обычный PPU_MASK будут применены только следующим
; NMI; до него mask остаётся BulkUpdatePpuMaskValue.
ClearPrimaryNametableScreen:
LD16A:  jsr     DisableRenderingForBulkUpdate
        lda     #TitleBackgroundPalette
        sta     BackgroundPaletteIndex
        lda     #ShadowToPrimaryNametableOffset
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
; Вход: NMI включён, DigitBlankMode=0, записи score корректно терминированы.
; Побочно меняет A/X/Y, ScratchPtr/AuxPtr,
; NametablePpuOffset=ShadowToNametable2800Offset,
; RasterStringX/Y, TileTranslationOffset=0, score-format scratch, shadow, PPU и
; update buffer. Два внутренних ожидания последовательно передают score/header
; и три menu lines. Выход: A=$FF, X=PpuBufferPos=12, Y=9, NMI/rendering включены;
; ScratchPtr=CreditsCopyrightText. Последняя строка copyright уже отражена в
; shadow, но её 12-байтная команда остаётся в очереди до следующего NMI.
BuildTitleNametable:
LD17F:  jsr     DisableRenderingForBulkUpdate
        lda     #ShadowToNametable2800Offset
        sta     NametablePpuOffset
        jsr     ClearNametableBuffer
        ldx     #TitleLogoRasterX
        stx     RasterStringX
        ldy     #TitleLogoRasterY
        sty     RasterStringY
        jsr     DrawVariantTitleData
; Восемь исполняемых NOP не меняют состояние и не имеют внутренних entry points.
; Их исходное назначение неизвестно; они сохранены для byte identity и адресов.
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        ldx     #TitleYearRasterX
        stx     RasterStringX
        ldy     #TitleYearRasterY
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
; Первая кадровая порция: подписи и числа P1/high score, а при MenuSelection!=0
; также P2. SelectVisibleDigits возвращает ScratchPtr на видимую часть record.
        lda     #>PlayerOneScorePrefix
        sta     ScratchPtrHi
        lda     #<PlayerOneScorePrefix
        sta     ScratchPtrLo
        ldx     #TitlePlayer1LabelColumn
        ldy     #TitleScoreRow
        jsr     QueueTileAtCoordinates
        ldy     #(Player1Score+1)
        ldx     #TitlePlayer1ScoreFormatColumn
        jsr     SelectVisibleDigits
        ldy     #TitleScoreRow
        jsr     QueueTranslatedTileString
        lda     #>HighScoreCompactPrefix
        sta     ScratchPtrHi
        lda     #<HighScoreCompactPrefix
        sta     ScratchPtrLo
        ldx     #TitleHighScoreLabelColumn
        ldy     #TitleScoreRow
        jsr     QueueTileAtCoordinates
        ldy     #(HighScore+1)
        ldx     #TitleHighScoreFormatColumn
        jsr     SelectVisibleDigits
        ldy     #TitleScoreRow
        jsr     QueueTranslatedTileString
        lda     MenuSelection
        beq     QueueTitleMenuText
; Необязательная правая часть score-row для режима двух игроков.
        lda     #>PlayerTwoScorePrefix
        sta     ScratchPtrHi
        lda     #<PlayerTwoScorePrefix
        sta     ScratchPtrLo
        ldx     #TitlePlayer2LabelColumn
        ldy     #TitleScoreRow
        jsr     QueueTileAtCoordinates
        ldy     #(Player2Score+1)
        ldx     #TitlePlayer2ScoreFormatColumn
        jsr     SelectVisibleDigits
        ldy     #TitleScoreRow
        jsr     QueueTranslatedTileString
QueueTitleMenuText:
LD20E:  lda     #$00
        sta     TileTranslationOffset
        ; Перед построением меню передаёт первую score-порцию через NMI.
        jsr     WaitForNextFrame
        lda     #>OnePlayerMenuText
        sta     ScratchPtrHi
        lda     #<OnePlayerMenuText
        sta     ScratchPtrLo
        ldx     #TitleMenuTextColumn
        ldy     #TitleOnePlayerRow
        jsr     QueueTileAtCoordinates
        lda     #>TwoPlayersMenuText
        sta     ScratchPtrHi
        lda     #<TwoPlayersMenuText
        sta     ScratchPtrLo
        ldx     #TitleMenuTextColumn
        ldy     #TitleTwoPlayerRow
        jsr     QueueTileAtCoordinates
        lda     #>ConstructionMenuText
        sta     ScratchPtrHi
        lda     #<ConstructionMenuText
        sta     ScratchPtrLo
        ldx     #TitleMenuTextColumn
        ldy     #TitleConstructionRow
        jsr     QueueTileAtCoordinates
        ; Перед copyright передаёт три menu lines; copyright останется pending.
        jsr     WaitForNextFrame
        lda     #>CreditsCopyrightText
        sta     ScratchPtrHi
        lda     #<CreditsCopyrightText
        sta     ScratchPtrLo
        ldx     #TitleMenuTextColumn
        ldy     #TitleCopyrightRow
        jsr     QueueTileAtCoordinates
        rts
