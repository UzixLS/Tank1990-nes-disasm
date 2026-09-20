; Жизни, подписи, номер этапа и маркеры врагов HUD ($C7C8-$C8CF).
; Все строки ставятся в PPU update buffer и исполняются только последующим NMI.
; QueueTileAtCoordinates также меняет nametable shadow, а
; QueueTranslatedTileString оставляет shadow без изменений.
; Процедуры без собственного WaitForNextFrame должны завершить формирование
; целых команд до того, как следующий NMI начнёт разбирать очередь.

; Две непересекающиеся роли общего loop-байта $5A.
PlayerHudIndex              = $5A
RemainingEnemyMarkerIndex  = $5A
; Scratch сохраняет индекс игрока, пока A превращается в смещение строки 3*index.
PlayerHudRowIndexScratch    = $00
BattleHudDecimalTileBias    = $6E
BattleHudRightColumn        = $1D
BattleHudDigitFieldColumn   = $19
PlayerOneHudLabelRow       = $11
PlayerOneLivesIconRow      = $12
PlayerTwoHudLabelRow       = $14
PlayerTwoLivesIconRow      = $15
StageHudColumn             = $1D
StageHudUpperRow           = $17
StageHudLowerRow           = $18
StageHudDigitRow           = $19
EnemyMarkerGridLeftColumn  = $1D
EnemyMarkerGridTopRow      = 3
LastEnemyMarkerPairStartIndex = EnemyCountPerStage - 2
LastPlayerHudIndex         = PlayerTankCount - 1
DisplayedLivesReserve     = $01
EnemyMarkerGridColumnMask = $01
; Перерисовывает значки и число запасных жизней. P1 выводится всегда; P2 — при
; StageSetLength=AttractStageSetMarker или MenuSelection!=0. Для штатных lives
; 0..$80 число равно max(lives-1,0); $81..$FF также дают 0 из-за знакового BPL.
; В single-player добавляет 8..10 байт команд, с P2 — 16..20; вызывающий
; обеспечивает этот свободный объём и ещё один байт lookahead по конечному
; PpuBufferPos. Однотайловые значки меняют shadow, строки цифр — нет.
; Вход: NametablePpuOffset=ShadowToPrimaryNametableOffset. Выход: A=0,
; X=PpuBufferPos, Y=число цифр P1 (1..3), PlayerHudIndex=$FF,
; TileTranslationOffset=DigitBlankMode=0. Меняет PpuBufferPos/PpuUpdateBuffer,
; ScratchPtr, PlayerHudRowIndexScratch/PpuTileRowBits, ScoreIncrementDigits и
; decimal scratch; PPU registers, lives и прочее игровое состояние сохраняет.
UpdateLivesHud:
LC7C8:  lda     #LastPlayerHudIndex
        sta     PlayerHudIndex
        ; Начальный индекс P1/P2 равен 1 и тем же значением включает blank-mode;
        ; один load намеренно обслуживает две разные роли.
        sta     DigitBlankMode
        lda     #BattleHudDecimalTileBias
        sta     TileTranslationOffset
        lda     #>LivesHudIconText
        sta     ScratchPtrHi
        lda     #<LivesHudIconText
        sta     ScratchPtrLo
        ldx     #BattleHudRightColumn
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
        ldx     #BattleHudRightColumn
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
        ldx     #BattleHudDigitFieldColumn
        jsr     SelectVisibleDigits
        lda     PlayerHudIndex
        sta     PlayerHudRowIndexScratch
        asl     a
        clc
        adc     PlayerHudRowIndexScratch
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

; Ставит двухтайловую метку P1 и, при том же условии, что UpdateLivesHud, метку
; P2. Добавляет соответственно 5 или 10 байт команд; вызывающий обеспечивает
; этот объём и один байт lookahead. Обе метки копируются также в shadow.
; Вход: NametablePpuOffset=ShadowToPrimaryNametableOffset. Выход:
; X=PpuBufferPos, Y=2; A=0 на пути только P1, A=$FF на пути с P2.
; Меняет ScratchPtr, PpuTileRowBits, PpuBufferPos/PpuUpdateBuffer и два либо
; четыре shadow-тайла; player state и PPU registers сохраняет.
DrawPlayerHudLabels:
LC830:  lda     #>PlayerOneCompactMarker
        sta     ScratchPtrHi
        lda     #<PlayerOneCompactMarker
        sta     ScratchPtrLo
        ldx     #BattleHudRightColumn
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
        ldx     #BattleHudRightColumn
        ldy     #PlayerTwoHudLabelRow
        jsr     QueueTileAtCoordinates
FinishPlayerHudLabels:
LC858:  rts

; WaitForNextFrame сначала исполняет прежнюю PPU-очередь и обнуляет её позицию.
; Затем ставит две двухтайловые строки значка Stage (по 5 байт команд) и строку
; 1..3 цифр (4..6 байт): всего 14..16 байт плюс будущий NMI lookahead.
; Значок копируется в shadow, цифры — нет; все новые команды остаются в очереди
; до следующего NMI.
; Вход: NMI включён, StageNumber=1..ExtendedStageUpperBound,
; NametablePpuOffset=ShadowToPrimaryNametableOffset. При ненулевом StageNumber
; SelectVisibleDigits не читает DigitBlankMode.
; Выход: A=0, X=PpuBufferPos=14..16, Y=число цифр 1..3,
; TileTranslationOffset=0. Меняет ScratchPtr, PpuTileRowBits,
; ScoreIncrementDigits/decimal scratch, PpuUpdateBuffer и четыре shadow-тайла.
; Обслуживший ожидание NMI также обновляет PPU/OAM, input, audio и счётчики.
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
        lda     #BattleHudDecimalTileBias
        sta     TileTranslationOffset
        lda     StageNumber
        jsr     ByteToDisplayDigits
        ldy     #(ScoreIncrementDigits+1)
        ldx     #BattleHudDigitFieldColumn
        jsr     SelectVisibleDigits
        ldy     #StageHudDigitRow
        jsr     QueueTranslatedTileString
        lda     #$00
        sta     TileTranslationOffset
        rts

; Преобразует линейный индекс ячейки сетки врагов A=0..19 в HUD-координаты:
; X=EnemyMarkerGridLeftColumn+(A&1), Y=EnemyMarkerGridTopRow+(A>>1).
; Выход: A=Y=(вход>>1)+3, X — столбец, C=0; RAM сохраняет, SP после временного
; PHA восстанавливает.
EnemyMarkerIndexToHudCoordinates:
LC894:  pha
        and     #EnemyMarkerGridColumnMask
        clc
        adc     #EnemyMarkerGridLeftColumn
        tax
        pla
        lsr     a
        clc
        adc     #EnemyMarkerGridTopRow
        tay
        rts

; Ставит двухтайловую пару RemainingEnemyMarkerTiles с чётного индекса A=0..18.
; Требует пять свободных байтов команды и один байт lookahead; меняет два тайла
; shadow. Вход: NametablePpuOffset=ShadowToPrimaryNametableOffset. Выход:
; A=$FF, X=PpuBufferPos, Y=2. Меняет ScratchPtr, PpuTileRowBits и PPU-очередь;
; PPU registers напрямую не трогает.
DrawRemainingEnemyMarker:
LC8A2:  jsr     EnemyMarkerIndexToHudCoordinates
        lda     #>RemainingEnemyMarkerTiles
        sta     ScratchPtrHi
        lda     #<RemainingEnemyMarkerTiles
        sta     ScratchPtrLo
        jsr     QueueTileAtCoordinates
        rts

; Заменяет одну ячейку маркера с индексом A=0..19 тайлом BlankTileText.
; Требует четыре свободных байта команды и один байт lookahead; меняет один
; shadow-тайл. Вход: NametablePpuOffset=ShadowToPrimaryNametableOffset. Выход:
; A=$FF, X=PpuBufferPos, Y=1. Меняет ScratchPtr, PpuTileRowBits и PPU-очередь;
; PPU registers напрямую не трогает.
ClearRemainingEnemyMarker:
LC8B1:  jsr     EnemyMarkerIndexToHudCoordinates
        lda     #>BlankTileText
        sta     ScratchPtrHi
        lda     #<BlankTileText
        sta     ScratchPtrLo
        jsr     QueueTileAtCoordinates
        rts

; Ставит десять двухтайловых строк с чётными индексами $12..0, заполняя все
; EnemyCountPerStage=20 ячеек. Требует 50 свободных байтов PPU-очереди и ещё
; один байт lookahead по конечной позиции; меняет все 20 shadow-тайлов.
; Вход: NametablePpuOffset=ShadowToPrimaryNametableOffset. Выход: A=$FF,
; X=PpuBufferPos=old PpuBufferPos+50, Y=2, RemainingEnemyMarkerIndex=$FE.
; Меняет ScratchPtr/PpuTileRowBits и PPU-очередь; PPU registers не трогает.
InitializeRemainingEnemyMarkers:
LC8C0:  lda     #LastEnemyMarkerPairStartIndex
        sta     RemainingEnemyMarkerIndex
DrawNextRemainingEnemyMarker:
LC8C4:  lda     RemainingEnemyMarkerIndex
        jsr     DrawRemainingEnemyMarker
        dec     RemainingEnemyMarkerIndex
        dec     RemainingEnemyMarkerIndex
        bpl     DrawNextRemainingEnemyMarker
        rts
