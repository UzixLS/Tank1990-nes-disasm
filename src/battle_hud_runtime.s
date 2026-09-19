; Жизни, подписи, номер этапа и маркеры врагов HUD ($C7C8-$C8CF).

; Две непересекающиеся роли общего loop-байта $5A.
PlayerHudIndex              = $5A
RemainingEnemyMarkerIndex  = $5A
; Scratch сохраняет индекс игрока, пока A превращается в смещение строки 3*index.
PlayerHudIndexScratch       = $00
PlayerHudTileBias          = $6E
PlayerHudColumn            = $1D
PlayerLivesFormatColumn    = $19
PlayerOneHudLabelRow       = $11
PlayerOneLivesIconRow      = $12
PlayerTwoHudLabelRow       = $14
PlayerTwoLivesIconRow      = $15
StageHudColumn             = $1D
StageHudUpperRow           = $17
StageHudLowerRow           = $18
StageHudFormatColumn       = $19
StageHudDigitRow           = $19
EnemyMarkerFirstColumn     = $1D
EnemyMarkerFirstRow        = 3
LastRemainingEnemyMarkerIndex = EnemyCountPerStage - 2
PlayerHudInitialIndex      = PlayerTankCount - 1
DisplayedLivesReserve     = $01
EnemyMarkerColumnMask     = $01
; Перерисовывает HUD жизней. В single-player обходит только P1, в two-player/демо — P2 и P1.
; На экран выводит max(lives-1,0). Меняет PPU-очередь, ScratchPtr,
; PlayerHudIndexScratch/decimal scratch, PlayerHudIndex, TileTranslationOffset и
; DigitBlankMode; портит A/X/Y. Выход: PlayerHudIndex=$FF,
; TileTranslationOffset=DigitBlankMode=0; последний PPU command остаётся в очереди.
UpdateLivesHud:
LC7C8:  lda     #PlayerHudInitialIndex
        sta     PlayerHudIndex
        ; Начальный индекс P1/P2 равен 1 и тем же значением включает blank-mode;
        ; один load намеренно обслуживает две разные роли.
        sta     DigitBlankMode
        lda     #PlayerHudTileBias
        sta     TileTranslationOffset
        lda     #>LivesHudIconText
        sta     ScratchPtrHi
        lda     #<LivesHudIconText
        sta     ScratchPtrLo
        ldx     #PlayerHudColumn
        ldy     #PlayerOneLivesIconRow
        jsr     QueueTileAtCoordinates
        lda     StageSetLength
        cmp     #AttractStageSetMarker
        beq     DrawSecondPlayerLivesIcon
        lda     MenuSelection
        bne     DrawSecondPlayerLivesIcon
        lda     #$00
        sta     PlayerHudIndex
        jmp     DrawNextPlayerLivesCount

DrawSecondPlayerLivesIcon:
LC7F2:  lda     #>LivesHudIconText
        sta     ScratchPtrHi
        lda     #<LivesHudIconText
        sta     ScratchPtrLo
        ldx     #PlayerHudColumn
        ldy     #PlayerTwoLivesIconRow
        jsr     QueueTileAtCoordinates
DrawNextPlayerLivesCount:
LC801:  ldx     PlayerHudIndex
        lda     Player1Lives,x
        sec
        sbc     #DisplayedLivesReserve
        bpl     ConvertPlayerLivesCount
        lda     #$00
ConvertPlayerLivesCount:
LC80C:  jsr     ByteToDisplayDigits
        ldy     #(ScoreIncrementDigits+1)
        ldx     #PlayerLivesFormatColumn
        jsr     SelectVisibleDigits
        lda     PlayerHudIndex
        sta     PlayerHudIndexScratch
        asl     a
        clc
        adc     PlayerHudIndexScratch
        clc
        adc     #PlayerOneLivesIconRow
        tay
        jsr     QueueTranslatedTileString
        dec     PlayerHudIndex
        bpl     DrawNextPlayerLivesCount
        lda     #$00
        sta     TileTranslationOffset
        sta     DigitBlankMode
        rts

; Рисует в HUD заголовки/иконки P1 и, если нужно, P2. Условие P2 совпадает с
; UpdateLivesHud: attract marker либо ненулевой MenuSelection. Портит ScratchPtr,
; A/X/Y и PPU-очередь; player state, shadow nametable и PPU напрямую не меняет.
DrawPlayerHudLabels:
LC830:  lda     #>PlayerOneCompactMarker
        sta     ScratchPtrHi
        lda     #<PlayerOneCompactMarker
        sta     ScratchPtrLo
        ldx     #PlayerHudColumn
        ldy     #PlayerOneHudLabelRow
        jsr     QueueTileAtCoordinates
        lda     StageSetLength
        cmp     #AttractStageSetMarker
        beq     DrawSecondPlayerHudLabel
        lda     MenuSelection
        beq     FinishPlayerHudLabels
DrawSecondPlayerHudLabel:
LC849:  lda     #>PlayerTwoCompactMarker
        sta     ScratchPtrHi
        lda     #<PlayerTwoCompactMarker
        sta     ScratchPtrLo
        ldx     #PlayerHudColumn
        ldy     #PlayerTwoHudLabelRow
        jsr     QueueTileAtCoordinates
FinishPlayerHudLabels:
LC858:  rts

; После vblank выводит в HUD маркер и десятичный StageNumber. Меняет PPU-очередь,
; ScratchPtr, ScoreIncrementDigits, decimal scratch и TileTranslationOffset;
; портит A/X/Y, а WaitForNextFrame также обновляет кадровые счётчики и ввод.
DrawStageNumberHud:
LC859:  jsr     WaitForNextFrame
        lda     #>StageHudUpperTiles
        sta     ScratchPtrHi
        lda     #<StageHudUpperTiles
        sta     ScratchPtrLo
        ldx     #StageHudColumn
        ldy     #StageHudUpperRow
        jsr     QueueTileAtCoordinates
        lda     #>StageHudLowerTiles
        sta     ScratchPtrHi
        lda     #<StageHudLowerTiles
        sta     ScratchPtrLo
        ldx     #StageHudColumn
        ldy     #StageHudLowerRow
        jsr     QueueTileAtCoordinates
        lda     #PlayerHudTileBias
        sta     TileTranslationOffset
        lda     StageNumber
        jsr     ByteToDisplayDigits
        ldy     #(ScoreIncrementDigits+1)
        ldx     #StageHudFormatColumn
        jsr     SelectVisibleDigits
        ldy     #StageHudDigitRow
        jsr     QueueTranslatedTileString
        lda     #$00
        sta     TileTranslationOffset
        rts

; Преобразует индекс A в HUD-координаты:
; X=EnemyMarkerFirstColumn+(A&1), Y=EnemyMarkerFirstRow+(A>>1).
; Выход: A=Y=(вход>>1)+3, X — столбец. RAM не меняет.
EnemyMarkerIndexToHudCoordinates:
LC894:  pha
        and     #EnemyMarkerColumnMask
        clc
        adc     #EnemyMarkerFirstColumn
        tax
        pla
        lsr     a
        clc
        adc     #EnemyMarkerFirstRow
        tay
        rts

; Рисует RemainingEnemyMarkerTiles для индекса A в правой HUD-сетке. Портит A/X/Y, ScratchPtr и PPU-очередь.
DrawRemainingEnemyMarker:
LC8A2:  jsr     EnemyMarkerIndexToHudCoordinates
        lda     #>RemainingEnemyMarkerTiles
        sta     ScratchPtrHi
        lda     #<RemainingEnemyMarkerTiles
        sta     ScratchPtrLo
        jsr     QueueTileAtCoordinates
        rts

; Заменяет один HUD-маркер индекса A строкой BlankTileText. Портит A/X/Y,
; ScratchPtr и PPU-очередь.
ClearRemainingEnemyMarker:
LC8B1:  jsr     EnemyMarkerIndexToHudCoordinates
        lda     #>BlankTileText
        sta     ScratchPtrHi
        lda     #<BlankTileText
        sta     ScratchPtrLo
        jsr     QueueTileAtCoordinates
        rts

; Ставит десять двухтайловых строк с чётными индексами $12..0, тем самым
; заполняя все EnemyCountPerStage=20 позиций сетки.
; Выход: RemainingEnemyMarkerIndex=$FE; портит A/X/Y, ScratchPtr и PPU-очередь.
InitializeRemainingEnemyMarkers:
LC8C0:  lda     #LastRemainingEnemyMarkerIndex
        sta     RemainingEnemyMarkerIndex
DrawNextRemainingEnemyMarker:
LC8C4:  lda     RemainingEnemyMarkerIndex
        jsr     DrawRemainingEnemyMarker
        dec     RemainingEnemyMarkerIndex
        dec     RemainingEnemyMarkerIndex
        bpl     DrawNextRemainingEnemyMarker
        rts
