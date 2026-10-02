; Построение nametable заглавного экрана ($D16A-$D254).

TitleScoreTileBias     = $30
TitleScoreFirstDisplayedDigitOffset = $01
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
TitleCopyrightColumn   = $0B
TitleCopyrightRow      = $18

; Очищает основную nametable $2000: отключает рендеринг/NMI, обнуляет shadow,
; напрямую загружает 1 KiB и снова включает NMI. Выбирает фоновую палитру 3.
; Вход: NMI включён, иначе DisableRenderingForBulkUpdate не завершится; текущая
; PPU queue корректна. Начальный Wait исполняет ровно один обычный NMI: flush
; очереди, OAM/input/audio/palette и frame counters обновляются до очистки.
; Выход: A=EnabledNmiPpuCtrlValue, X=Y=0, ScratchPtr=$0800,
; NametablePpuOffset=ShadowToPrimaryNametableOffset, BackgroundPaletteIndex=3,
; PpuBufferPos=0, N=1/Z=0/C=1/V=0. VerticalScroll/NametableBits сохраняются.
; Полностью очищает shadow и VRAM $2000..$23FF, меняет PPU address/control/mask.
; NMI включён, но palette 3 и обычный PPU_MASK будут применены только следующим
; NMI; до него mask остаётся BulkUpdatePpuMaskValue=$06 и rendering выключен.
; PPU address latch после polling PPU_STATUS ожидает high write.
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
; Вход: NMI включён, GameVariant допустим для DrawVariantTitleData,
; DigitBlankMode=0, score records содержат семь digits0..9 и $FF. Любое
; MenuSelection!=0 включает P2. Первый NMI внутри Disable очищает старую queue;
; далее каждый batch начинается при PpuBufferPos=0, и NMI не должен прерывать
; его построение.
;
; Размеры batch с учётом addr/terminator, но без следующего lookahead:
;   score без P2: 21..29 bytes; с P2: 31..43 bytes;
;   три menu lines: 11+12+15=38 bytes; copyright: 9+3=12 bytes.
; Все максимумы оставляют lookahead в 128-byte PpuUpdateBuffer. Два явных
; WaitForNextFrame исполняют score и menu batch; вместе с Disable процедура
; обслуживает ровно три NMI и трижды обновляет OAM/input/audio/frame counters.
; Побочно меняет A/X/Y, ScratchPtr/AuxPtr, collision/raster scratch $00-$03,
; $47/$48 и $56-$5F, внутренний PPU read buffer/address во время чтения CHR,
; NametablePpuOffset=ShadowToNametable2800Offset,
; RasterStringX/Y, TileTranslationOffset=0, score-format scratch, shadow, PPU и
; update buffer. QueueTileAtCoordinates отражает labels/menu/copyright в shadow,
; но QueueTranslatedTileString не отражает score digits.
;
; Выход: A=$FF, X=PpuBufferPos=12, Y=9, N=0/Z=1/C=1/V=0;
; ScratchPtr=CreditsCopyrightText, AuxPtr=$070B, PpuTileRowBits=0,
; RasterStringX=$BC, RasterStringY=$56, TileTranslationOffset=0;
; NametablePpuOffset=$24. NMI/rendering включены последним NMI. Pending queue
; равна [$2B,$0B, девять copyright tiles, $FF] и исполнится следующим NMI.
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
; Первая кадровая порция: подписи и шесть младших цифр P1/high score, а при
; MenuSelection!=0 также P2. Первая из семи цифр каждой record намеренно
; пропущена: даже ненулевая цифра миллионов на title не отображается.
; SelectVisibleDigits возвращает ScratchPtr на видимую часть suffix.
        lda     #>PlayerOneScorePrefix
        sta     ScratchPtrHi
        lda     #<PlayerOneScorePrefix
        sta     ScratchPtrLo
        ldx     #TitlePlayer1LabelColumn
        ldy     #TitleScoreRow
        jsr     QueueTileAtCoordinates
        ldy     #(Player1Score+TitleScoreFirstDisplayedDigitOffset)
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
        ldy     #(HighScore+TitleScoreFirstDisplayedDigitOffset)
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
        ldy     #(Player2Score+TitleScoreFirstDisplayedDigitOffset)
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
        ldx     #TitleCopyrightColumn
        ldy     #TitleCopyrightRow
        jsr     QueueTileAtCoordinates
        rts
