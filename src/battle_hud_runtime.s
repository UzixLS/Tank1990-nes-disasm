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
HudOneTileQueueByteCount  = 4
HudTwoTileQueueByteCount  = 5
HudDecimalQueueMinBytes   = 4
HudDecimalQueueMaxBytes   = 6
LivesHudOnePlayerMaxQueueBytes = (HudOneTileQueueByteCount + HudDecimalQueueMaxBytes)
LivesHudTwoPlayerMaxQueueBytes = 2 * (HudOneTileQueueByteCount + HudDecimalQueueMaxBytes)
LivesHudOnePlayerMaxStartPos = $7F - LivesHudOnePlayerMaxQueueBytes
LivesHudTwoPlayerMaxStartPos = $7F - LivesHudTwoPlayerMaxQueueBytes
PlayerLabelsOnePlayerMaxStartPos = $7F - HudTwoTileQueueByteCount
PlayerLabelsTwoPlayerMaxStartPos = $7F - (2 * HudTwoTileQueueByteCount)
EnemyMarkerPairMaxStartPos = $7F - HudTwoTileQueueByteCount
EnemyMarkerClearMaxStartPos = $7F - HudOneTileQueueByteCount
AllEnemyMarkersQueueBytes = (EnemyCountPerStage / 2) * HudTwoTileQueueByteCount
AllEnemyMarkersMaxStartPos = $7F - AllEnemyMarkersQueueBytes

; Перерисовывает значки и число запасных жизней. P1 выводится всегда; P2 — при
; StageSetLength=AttractStageSetMarker или MenuSelection!=0. Для штатных lives
; 0..$80 число равно max(lives-1,0); $81..$FF также дают 0 из-за знакового BPL.
; В single-player добавляет 8..10 байт команд, с P2 — 16..20; вызывающий
; обеспечивает PpuBufferPos<=LivesHudOnePlayerMaxStartPos ($75) либо
; LivesHudTwoPlayerMaxStartPos ($6B), включая lookahead по конечному cursor.
; Однотайловые значки меняют shadow, строки цифр — нет. Между первым и последним
; формированием команды NMI не должен успеть flush-ить очередь.
; Вход: NametablePpuOffset=ShadowToPrimaryNametableOffset. Выход: A=0,
; X=PpuBufferPos=old+8..10 (1P) либо old+16..20 (2P), Y=число цифр P1
; (1..3), PlayerHudIndex=$FF,
; PlayerHudRowIndexScratch=0, TileTranslationOffset=DigitBlankMode=0,
; N=0/Z=1/C=1/V=0. ScratchPtr указывает на видимый suffix последнего (P1)
; числа, ScoreIncrementDigits и ByteToDecimalInput содержат его display-value,
; AuxPtr — на P1 icon в 1P либо P2 icon в 2P. Меняет
; PpuBufferPos/PpuUpdateBuffer, обе pointer pairs,
; PlayerHudRowIndexScratch/PpuTileRowBits, ScoreIncrementDigits и decimal
; scratch; PPU registers, lives и прочее игровое состояние сохраняет.
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
; PpuBufferPos<=PlayerLabelsOnePlayerMaxStartPos ($7A) либо
; PlayerLabelsTwoPlayerMaxStartPos ($75), включая lookahead. Обе метки копируются
; также в shadow; NMI не должен flush-ить очередь между ними.
; Вход: NametablePpuOffset=ShadowToPrimaryNametableOffset. Выход:
; X=PpuBufferPos=old+5 (1P) либо old+10 (2P), Y=2; A=0 на пути только P1,
; A=$FF на пути с P2.
; ScratchPtr и AuxPtr указывают соответственно на строку и shadow-адрес последней
; поставленной метки. Меняет обе pointer pairs, PpuTileRowBits,
; PpuBufferPos/PpuUpdateBuffer и два либо четыре shadow-тайла; player state и
; PPU registers сохраняет.
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
; TileTranslationOffset=0, N=0/Z=1/C=1/V=0. ScratchPtr указывает на видимый
; suffix цифр, ByteToDecimalInput=StageNumber, AuxPtr — на нижнюю строку значка
; Stage. Меняет обе pointer pairs, PpuTileRowBits, ScoreIncrementDigits/decimal
; scratch, PpuUpdateBuffer и четыре shadow-тайла.
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
; Проверки диапазона нет: больший индекс уводит запись ниже штатной сетки и может
; дойти до attribute-области shadow. Выход: A=Y=(вход>>1)+3, X — столбец,
; N=Z=C=V=0; RAM сохраняет, SP после временного PHA восстанавливает.
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

; Ставит двухтайловую пару RemainingEnemyMarkerTiles; штатный вход — чётный
; индекс A=0..18. Требует PpuBufferPos<=EnemyMarkerPairMaxStartPos ($7A), чтобы
; поместились пять байтов команды и lookahead; меняет два тайла shadow.
; Вход: NametablePpuOffset=ShadowToPrimaryNametableOffset. Выход: A=$FF,
; X=PpuBufferPos=old+5, Y=2, N=0/Z=1/C=1/V=0; ScratchPtr указывает на строку,
; AuxPtr — на первый shadow-тайл пары. Меняет обе pointer pairs,
; PpuTileRowBits и PPU-очередь; PPU registers напрямую не трогает.
DrawRemainingEnemyMarker:
LC8A2:  jsr     EnemyMarkerIndexToHudCoordinates
        lda     #>RemainingEnemyMarkerTiles
        sta     ScratchPtrHi
        lda     #<RemainingEnemyMarkerTiles
        sta     ScratchPtrLo
        jsr     QueueTileAtCoordinates
        rts

; Заменяет одну ячейку маркера с индексом A=0..19 тайлом BlankTileText.
; Требует PpuBufferPos<=EnemyMarkerClearMaxStartPos ($7B), чтобы поместились
; четыре байта команды и lookahead; меняет один shadow-тайл. Вход:
; NametablePpuOffset=ShadowToPrimaryNametableOffset. Выход: A=$FF,
; X=PpuBufferPos=old+4, Y=1, N=0/Z=1/C=1/V=0; ScratchPtr указывает на строку,
; AuxPtr — на очищенный shadow-тайл. Меняет обе pointer pairs,
; PpuTileRowBits и PPU-очередь; PPU registers напрямую не трогает.
ClearRemainingEnemyMarker:
LC8B1:  jsr     EnemyMarkerIndexToHudCoordinates
        lda     #>BlankTileText
        sta     ScratchPtrHi
        lda     #<BlankTileText
        sta     ScratchPtrLo
        jsr     QueueTileAtCoordinates
        rts

; Ставит десять двухтайловых строк с чётными индексами $12..0, заполняя все
; EnemyCountPerStage=20 ячеек. Требует PpuBufferPos<=AllEnemyMarkersMaxStartPos
; ($4D): AllEnemyMarkersQueueBytes (50) байт очереди и lookahead; меняет все 20
; shadow-тайлов. Алгоритм требует положительного чётного EnemyCountPerStage;
; изменение числа врагов также требует менять геометрию 2x10 и queue budget.
; Вход: NametablePpuOffset=ShadowToPrimaryNametableOffset. Выход: A=$FF,
; X=PpuBufferPos=old PpuBufferPos+50, Y=2, RemainingEnemyMarkerIndex=$FE.
; N=1/Z=0/C=1/V=0; ScratchPtr указывает на строку маркера, AuxPtr — на левую
; ячейку верхней пары. Меняет обе pointer pairs, PpuTileRowBits и PPU-очередь;
; PPU registers не трогает.
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
