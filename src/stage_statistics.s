; Экран и анимация послеэтапной статистики ($CCD4-$D137).

; Scratch-поля принадлежат экрану статистики и перекрываются с рабочими
; переменными других экранов/подсистем.
StatisticsPlayer1Count = $5D
StatisticsPlayer2Count = $5E
StatisticsEnemyType    = $5A
StatisticsKillsConsumed = $7C
Player1StageKillTotal  = $7D
Player2StageKillTotal  = $7E

; Временные семизначные записи начисления за текущий тип противника.
StatisticsPlayer1AwardDigits = $25
StatisticsPlayer2AwardDigits = $2D
StatisticsPlayer1AwardRecord = $02
StatisticsPlayer2AwardRecord = $03
StatisticsEnemyTypeCount     = $04

; Тайминги анимации в кадрах. Значки противников перерисовываются каждый кадр
; внутри DelayWithStatisticsIcons, поэтому эти паузы одновременно удерживают
; их в OAM shadow.
StatisticsIntroDelayFrames       = $1E
StatisticsBeforeTotalsDelayFrames = $1E
StatisticsRowStepDelayFrames     = $08
StatisticsBetweenRowsDelayFrames = $14
StatisticsWinnerDelayFrames      = $0F
StatisticsFinalDelayFrames       = $78

; Координаты динамических числовых полей. Строки категорий идут через три
; nametable-строки: StatisticsFirstEnemyRow + StatisticsEnemyType*3.
StatisticsScoreRow          = $09
StatisticsFirstEnemyRow     = $0C
StatisticsSecondEnemyRow    = StatisticsFirstEnemyRow + 3
StatisticsThirdEnemyRow     = StatisticsFirstEnemyRow + 6
StatisticsFourthEnemyRow    = StatisticsFirstEnemyRow + 9
StatisticsTotalsRow         = $17
StatisticsBonusLabelRow     = $19
StatisticsBonusValueRow     = $1A
StatisticsPlayer1ScoreFormatColumn = $05
StatisticsPlayer1AwardFormatColumn = $01
StatisticsPlayer1CountFormatColumn = $08
StatisticsPlayer2ScoreFormatColumn = $17
StatisticsPlayer2AwardFormatColumn = $13
StatisticsPlayer2CountFormatColumn = $0E
StatisticsPlayer2BonusFormatColumn = $14
StatisticsPlayer1BonusLabelColumn = $03
StatisticsPlayer2BonusLabelColumn = $16
StatisticsPlayer1BonusPointsColumn = $08
StatisticsPlayer2BonusPointsColumn = $1B

; Статическая разметка и режим PPU экрана статистики.
StatisticsNametablePpuOffset = $24
StatisticsNametableBits      = $02
StatisticsDigitTileBias      = $30
StatisticsBackgroundPalette  = $03
StatisticsHighScoreLabelColumn = $08
StatisticsHighScoreFormatColumn = $12
StatisticsHeaderRow            = $03
StatisticsStageLabelColumn     = $0C
StatisticsStageFormatColumn    = $0E
StatisticsStageRow             = $05
StatisticsPlayer1HeaderColumn  = $03
StatisticsPlayer2HeaderColumn  = $15
StatisticsPlayerHeaderRow      = $07
StatisticsPlayer1MarkerColumn  = $0E
StatisticsPlayer2MarkerColumn  = $11
StatisticsPlayer1RowPointsColumn = $08
StatisticsPlayer2RowPointsColumn = $1A
StatisticsDividerColumn        = $0C
StatisticsDividerRow           = $16
StatisticsTotalLabelColumn     = $06

; Экранные параметры четырёх двухспрайтовых значков типов противника.
StatisticsEnemyIconAttributes = $02
StatisticsEnemyIconX          = $81
StatisticsType0IconY          = $64
StatisticsType1IconY          = $7C
StatisticsType2IconY          = $94
StatisticsType3IconY          = $AC
StatisticsType0IconTile       = $80
StatisticsType1IconTile       = $A0
StatisticsType2IconTile       = $C0
StatisticsType3IconTile       = $E0

StatisticsPlayer1ScoreRecord = $00
StatisticsPlayer2ScoreRecord = $01
StatisticsWinnerBonusAward   = $00       ; особый случай PreparePackedScoreIncrement -> 1000
StatisticsKillConsumed       = $01
StatisticsBlankZeroEnabled   = $01

; Показывает и анимирует послеэтапную статистику.
; Player1KillCounts/Player2KillCounts — четыре счётчика уничтоженных типов;
; их восьмибитные суммы без насыщения сохраняются в Player1/Player2StageKillTotal.
; Для каждой категории одна итерация уменьшает не более чем по одному счётчику
; каждого игрока, увеличивает экранные StatisticsPlayer1/2Count, накапливает
; награду ScoreAwardsByEnemyType во временных StatisticsPlayer1/2AwardDigits и
; обновляет UI. После последнего убийства выполняется ещё одна итерация без
; списания: она выводит окончательные значения и переводит цикл к следующему типу.
; После четырёх категорий выводит суммы. При BattleState!=0, двух игроках и
; неравном результате живому игроку с большей суммой добавляет специальную
; награду PreparePackedScoreIncrement(0), то есть 1000 очков.
; Входы: таблицы убийств и счёта заполнены завершившимся этапом; MenuSelection
; задаёт число игроков. Выходов в регистрах нет.
; Побочно уничтожает Player1/2KillCounts, меняет записи счёта и временных
; наград, жизни/флаги награды, PPU/OAM, состояния аудиопотоков и рабочие
; StatisticsEnemyType/StatisticsPlayer*Count/StatisticsKillsConsumed и итоговые счётчики.
; A/X/Y не сохраняются; работа занимает много кадров и завершается с
; NametableBits, BackgroundPaletteIndex, TileTranslationOffset и DigitBlankMode=0.
ShowStageStatistics:
LCCD4:  jsr     BuildStageStatisticsScreen
        ldx     #StatisticsIntroDelayFrames
        jsr     DelayWithStatisticsIcons
        lda     Player1KillCounts
        clc
        adc     Player1KillCounts+1
        clc
        adc     Player1KillCounts+2
        clc
        adc     Player1KillCounts+3
        sta     Player1StageKillTotal
        lda     Player2KillCounts
        clc
        adc     Player2KillCounts+1
        clc
        adc     Player2KillCounts+2
        clc
        adc     Player2KillCounts+3
        sta     Player2StageKillTotal
        lda     #$00
        sta     StatisticsEnemyType
BeginEnemyStatisticsRow:
LCCFA:  jsr     WaitForNextFrame
        jsr     DrawStatisticsEnemyIcons
; Накопленные очки и показанные количества относятся только к текущему типу.
; Общие записи счёта игроков между строками не сбрасываются.
        ldx     #StatisticsPlayer1AwardDigits
        jsr     ResetEightByteRecord
        ldx     #StatisticsPlayer2AwardDigits
        jsr     ResetEightByteRecord
        lda     #$00
        sta     StatisticsPlayer1Count
        sta     StatisticsPlayer2Count
AnimateEnemyStatisticsRow:
LCD10:  jsr     WaitForNextFrame
        jsr     DrawStatisticsEnemyIcons
; Флаг ставится только если эта итерация действительно списала хотя бы одно
; убийство. Нулевой флаг после вывода значений завершает строку.
        lda     #$00
        sta     StatisticsKillsConsumed
        ldx     StatisticsEnemyType
        lda     ScoreAwardsByEnemyType,x
        jsr     PreparePackedScoreIncrement
        ldx     StatisticsEnemyType
        lda     Player1KillCounts,x
        beq     ConsumePlayer2Kill
        lda     #AudioStateStartRequested
        sta     StatisticsCountPulseAudioState
        sta     StatisticsCountNoiseAudioState
        dec     Player1KillCounts,x
        inc     StatisticsPlayer1Count
        ldx     #StatisticsPlayer1AwardRecord
        jsr     AddScoreDigitsToRecord
        lda     #StatisticsKillConsumed
        sta     StatisticsKillsConsumed
        jsr     AwardScoreThresholdLives
ConsumePlayer2Kill:
LCD40:  ldx     StatisticsEnemyType
        lda     Player2KillCounts,x
        beq     QueueStatisticsRowValues
        lda     #AudioStateStartRequested
        sta     StatisticsCountPulseAudioState
        sta     StatisticsCountNoiseAudioState
        dec     Player2KillCounts,x
        inc     StatisticsPlayer2Count
        ldx     #StatisticsPlayer2AwardRecord
        jsr     AddScoreDigitsToRecord
        lda     #StatisticsKillConsumed
        sta     StatisticsKillsConsumed
        jsr     AwardScoreThresholdLives
; Ставит в PPU-очередь общий счёт, начисление за текущий тип и число уже
; обработанных убийств. Строка вычисляется как 12+StatisticsEnemyType*3;
; поля P2 пропускаются в однопользовательском режиме. Вход: индекс типа 0..3,
; счётчики, award-records и score-records уже актуальны. Меняет A/X/Y,
; ScratchPtr и ScoreIncrementDigits; исходные счётчики/счёт и OAM не меняет.
QueueStatisticsRowValues:
LCD5E:  ldy     #(Player1Score+1)
        ldx     #StatisticsPlayer1ScoreFormatColumn
        jsr     SelectVisibleDigits
        ldy     #StatisticsScoreRow
        jsr     QueueTranslatedTileString
        ldx     #StatisticsPlayer1AwardFormatColumn
        ldy     #(StatisticsPlayer1AwardDigits+1)
        jsr     SelectVisibleDigits
        lda     StatisticsEnemyType
        asl     a
        clc
        adc     StatisticsEnemyType
        clc
        adc     #StatisticsFirstEnemyRow
        tay
        jsr     QueueTranslatedTileString
; Эта исходная загрузка X не влияет на результат: ByteToDisplayDigits сразу
; заменяет X адресом ScoreIncrementDigits.
        ldx     StatisticsEnemyType
        lda     StatisticsPlayer1Count
        jsr     ByteToDisplayDigits
        ldx     #StatisticsPlayer1CountFormatColumn
        ldy     #(ScoreIncrementDigits+1)
        jsr     SelectVisibleDigits
        lda     StatisticsEnemyType
        asl     a
        clc
        adc     StatisticsEnemyType
        clc
        adc     #StatisticsFirstEnemyRow
        tay
        jsr     QueueTranslatedTileString
        lda     MenuSelection
        beq     WaitAfterStatisticsRowStep
        ldy     #(Player2Score+1)
        ldx     #StatisticsPlayer2ScoreFormatColumn
        jsr     SelectVisibleDigits
        ldy     #StatisticsScoreRow
        jsr     QueueTranslatedTileString
        ldx     #StatisticsPlayer2AwardFormatColumn
        ldy     #(StatisticsPlayer2AwardDigits+1)
        jsr     SelectVisibleDigits
        lda     StatisticsEnemyType
        asl     a
        clc
        adc     StatisticsEnemyType
        clc
        adc     #StatisticsFirstEnemyRow
        tay
        jsr     QueueTranslatedTileString
; Аналогичная неиспользуемая загрузка X сохранена для побайтового совпадения.
        ldx     StatisticsEnemyType
        lda     StatisticsPlayer2Count
        jsr     ByteToDisplayDigits
        ldx     #StatisticsPlayer2CountFormatColumn
        ldy     #(ScoreIncrementDigits+1)
        jsr     SelectVisibleDigits
        lda     StatisticsEnemyType
        asl     a
        clc
        adc     StatisticsEnemyType
        clc
        adc     #StatisticsFirstEnemyRow
        tay
        jsr     QueueTranslatedTileString
WaitAfterStatisticsRowStep:
LCDD8:  ldx     #StatisticsRowStepDelayFrames
        jsr     DelayWithStatisticsIcons
        lda     StatisticsKillsConsumed
        beq     AdvanceStatisticsEnemyType
        jmp     AnimateEnemyStatisticsRow

AdvanceStatisticsEnemyType:
LCDE4:  inc     StatisticsEnemyType
        lda     StatisticsEnemyType
        cmp     #StatisticsEnemyTypeCount
        beq     QueueStatisticsTotals
        ldx     #StatisticsBetweenRowsDelayFrames
        jsr     DelayWithStatisticsIcons
        jmp     BeginEnemyStatisticsRow

QueueStatisticsTotals:
LCDF4:  ldx     #StatisticsBeforeTotalsDelayFrames
        jsr     DelayWithStatisticsIcons
        lda     Player1StageKillTotal
        jsr     ByteToDisplayDigits
        ldy     #(ScoreIncrementDigits+1)
        ldx     #StatisticsPlayer1CountFormatColumn
        jsr     SelectVisibleDigits
        ldy     #StatisticsTotalsRow
        jsr     QueueTranslatedTileString
        lda     MenuSelection
        beq     WaitBeforeStatisticsWinnerBonus
        lda     Player2StageKillTotal
        jsr     ByteToDisplayDigits
        ldy     #(ScoreIncrementDigits+1)
        ldx     #StatisticsPlayer2CountFormatColumn
        jsr     SelectVisibleDigits
        ldy     #StatisticsTotalsRow
        jsr     QueueTranslatedTileString
WaitBeforeStatisticsWinnerBonus:
LCE1F:  ldx     #StatisticsWinnerDelayFrames
        jsr     DelayWithStatisticsIcons
        lda     MenuSelection
        bne     CheckStatisticsWinnerBonus
        jmp     FinishStageStatistics

; Бонус сравнивается только для двух игроков и только при ненулевом BattleState.
; Ничья, ноль жизней у кандидата или нулевой BattleState оставляют счёт прежним.
CheckStatisticsWinnerBonus:
LCE2B:  lda     BattleState
        bne     TryAwardPlayerOneStatisticsBonus
        jmp     FinishStageStatistics

TryAwardPlayerOneStatisticsBonus:
LCE32:  lda     Player2StageKillTotal
        cmp     Player1StageKillTotal
        bcs     TryAwardPlayerTwoStatisticsBonus
        lda     Player1Lives
        beq     TryAwardPlayerTwoStatisticsBonus
        lda     #StatisticsWinnerBonusAward
        jsr     PreparePackedScoreIncrement
        ldx     #StatisticsPlayer1ScoreRecord
        jsr     AddScoreDigitsToRecord
        ldy     #(Player1Score+1)
        ldx     #StatisticsPlayer1ScoreFormatColumn
        jsr     SelectVisibleDigits
        ldy     #StatisticsScoreRow
        jsr     QueueTranslatedTileString
        ldy     #(ScoreIncrementDigits+1)
        ldx     #StatisticsPlayer1AwardFormatColumn
        jsr     SelectVisibleDigits
        ldy     #StatisticsBonusValueRow
        jsr     QueueTranslatedTileString
        lda     #>StatisticsBonusText
        sta     ScratchPtrHi
        lda     #<StatisticsBonusText
        sta     ScratchPtrLo
        ldx     #StatisticsPlayer1BonusLabelColumn
        ldy     #StatisticsBonusLabelRow
        jsr     QueueTileAtCoordinates
        lda     #>PointsText
        sta     ScratchPtrHi
        lda     #<PointsText
        sta     ScratchPtrLo
        ldx     #StatisticsPlayer1BonusPointsColumn
        ldy     #StatisticsBonusValueRow
        jsr     QueueTileAtCoordinates
        lda     #AudioStateStartRequested
        sta     StatisticsWinnerBonusAudioState
; Одновременно перезаписывает channel/control записи потока паузы значением 1;
; зачем это требуется экрану статистики, по статическому коду не установлено.
        sta     AudioStreamRecords
        sta     AudioStreamRecords+1
        jsr     AwardScoreThresholdLives
        jmp     FinishStageStatistics

TryAwardPlayerTwoStatisticsBonus:
LCE8D:  lda     Player1StageKillTotal
        cmp     Player2StageKillTotal
        bcs     FinishStageStatistics
        lda     Player2Lives
        beq     FinishStageStatistics
        lda     #StatisticsWinnerBonusAward
        jsr     PreparePackedScoreIncrement
        ldx     #StatisticsPlayer2ScoreRecord
        jsr     AddScoreDigitsToRecord
        ldy     #(Player2Score+1)
        ldx     #StatisticsPlayer2ScoreFormatColumn
        jsr     SelectVisibleDigits
        ldy     #StatisticsScoreRow
        jsr     QueueTranslatedTileString
        ldy     #(ScoreIncrementDigits+1)
        ldx     #StatisticsPlayer2BonusFormatColumn
        jsr     SelectVisibleDigits
        ldy     #StatisticsBonusValueRow
        jsr     QueueTranslatedTileString
        lda     #>StatisticsBonusText
        sta     ScratchPtrHi
        lda     #<StatisticsBonusText
        sta     ScratchPtrLo
        ldx     #StatisticsPlayer2BonusLabelColumn
        ldy     #StatisticsBonusLabelRow
        jsr     QueueTileAtCoordinates
        lda     #>PointsText
        sta     ScratchPtrHi
        lda     #<PointsText
        sta     ScratchPtrLo
        ldx     #StatisticsPlayer2BonusPointsColumn
        ldy     #StatisticsBonusValueRow
        jsr     QueueTileAtCoordinates
        lda     #AudioStateStartRequested
        sta     StatisticsWinnerBonusAudioState
; Та же недокументированная запись в первые два байта записи потока паузы.
        sta     AudioStreamRecords
        sta     AudioStreamRecords+1
        jsr     AwardScoreThresholdLives
FinishStageStatistics:
LCEE5:  ldx     #StatisticsFinalDelayFrames
        jsr     DelayWithStatisticsIcons
        lda     #$00
        sta     NametableBits
        sta     TileTranslationOffset
        sta     DigitBlankMode
        lda     #$00
        sta     BackgroundPaletteIndex
        rts
; Строит статический экран статистики в nametable $2800. Значение
; NametablePpuOffset=$24 прибавляется к high-byte адреса shadow ($04..$07),
; а NametableBits=$02 выбирает ту же физическую nametable для рендеринга.
; Отключает рендеринг/NMI, очищает shadow, задаёт палитровые атрибуты,
; целиком передаёт nametable и снова включает NMI. Затем за несколько кадров
; ставит заголовки, текущие суммарные очки, номер этапа, четыре строки типов
; противников и поля счётчиков для одного или двух игроков.
; Вход: MenuSelection определяет наличие второго столбца; StageNumber и записи
; Player1Score/Player2Score/HighScore используются для UI. Побочно меняет
; A/X/Y, ScratchPtr, RenderAttributes/NametablePpuOffset,
; TileTranslationOffset/DigitBlankMode, BackgroundPaletteIndex,
; VerticalScroll/NametableBits, shadow/attributes и PPU-очередь. Возвращается
; после постановки footer в очередь; прямые записи PPU выполняются при отключённом
; рендеринге, а NMI снова разрешён до построения текстовых полей.
BuildStageStatisticsScreen:
LCEF7:  jsr     WaitForNextFrame
        lda     #StatisticsBlankZeroEnabled
        sta     DigitBlankMode
        lda     #StatisticsNametablePpuOffset
        sta     NametablePpuOffset
        lda     #$00
        sta     VerticalScroll
        lda     #StatisticsNametableBits
        sta     NametableBits
        lda     #StatisticsDigitTileBias
        sta     TileTranslationOffset
        lda     #StatisticsBackgroundPalette
        sta     BackgroundPaletteIndex
        jsr     DisableRenderingForBulkUpdate
        jsr     ClearNametableBuffer
        jsr     InitializeStatisticsAttributes
        jsr     UploadNametableBuffer
        jsr     EnableNmiAfterVblank
        lda     #>HighScoreStatisticsPrefix
        sta     ScratchPtrHi
        lda     #<HighScoreStatisticsPrefix
        sta     ScratchPtrLo
        ldx     #StatisticsHighScoreLabelColumn
        ldy     #StatisticsHeaderRow
        jsr     QueueTileAtCoordinates
        ldy     #(HighScore+1)
        ldx     #StatisticsHighScoreFormatColumn
        jsr     SelectVisibleDigits
        ldy     #StatisticsHeaderRow
        jsr     QueueTranslatedTileString
        lda     #>StatisticsStageText
        sta     ScratchPtrHi
        lda     #<StatisticsStageText
        sta     ScratchPtrLo
        ldx     #StatisticsStageLabelColumn
        ldy     #StatisticsStageRow
        jsr     QueueTileAtCoordinates
        lda     StageNumber
        jsr     ByteToDisplayDigits
        ldy     #(ScoreIncrementDigits+1)
        ldx     #StatisticsStageFormatColumn
        jsr     SelectVisibleDigits
        ldy     #StatisticsStageRow
        jsr     QueueTranslatedTileString
        jsr     WaitForNextFrame
        lda     #>PlayerOneStatisticsHeader
        sta     ScratchPtrHi
        lda     #<PlayerOneStatisticsHeader
        sta     ScratchPtrLo
        ldx     #StatisticsPlayer1HeaderColumn
        ldy     #StatisticsPlayerHeaderRow
        jsr     QueueTileAtCoordinates
        ldy     #(Player1Score+1)
        ldx     #StatisticsPlayer1ScoreFormatColumn
        jsr     SelectVisibleDigits
        ldy     #StatisticsScoreRow
        jsr     QueueTranslatedTileString
        lda     #>PlayerOneStatisticsMarker
        sta     ScratchPtrHi
        lda     #<PlayerOneStatisticsMarker
        sta     ScratchPtrLo
        ldx     #StatisticsPlayer1MarkerColumn
        ldy     #StatisticsFirstEnemyRow
        jsr     QueueTileAtCoordinates
        lda     #>PlayerOneStatisticsMarker
        sta     ScratchPtrHi
        lda     #<PlayerOneStatisticsMarker
        sta     ScratchPtrLo
        ldx     #StatisticsPlayer1MarkerColumn
        ldy     #StatisticsSecondEnemyRow
        jsr     QueueTileAtCoordinates
        lda     #>PlayerOneStatisticsMarker
        sta     ScratchPtrHi
        lda     #<PlayerOneStatisticsMarker
        sta     ScratchPtrLo
        ldx     #StatisticsPlayer1MarkerColumn
        ldy     #StatisticsThirdEnemyRow
        jsr     QueueTileAtCoordinates
        lda     #>PlayerOneStatisticsMarker
        sta     ScratchPtrHi
        lda     #<PlayerOneStatisticsMarker
        sta     ScratchPtrLo
        ldx     #StatisticsPlayer1MarkerColumn
        ldy     #StatisticsFourthEnemyRow
        jsr     QueueTileAtCoordinates
        lda     MenuSelection
        beq     QueueStatisticsCountFields
        jsr     WaitForNextFrame
        lda     #>PlayerTwoStatisticsHeader
        sta     ScratchPtrHi
        lda     #<PlayerTwoStatisticsHeader
        sta     ScratchPtrLo
        ldx     #StatisticsPlayer2HeaderColumn
        ldy     #StatisticsPlayerHeaderRow
        jsr     QueueTileAtCoordinates
        ldy     #(Player2Score+1)
        ldx     #StatisticsPlayer2ScoreFormatColumn
        jsr     SelectVisibleDigits
        ldy     #StatisticsScoreRow
        jsr     QueueTranslatedTileString
        lda     #>PlayerTwoStatisticsMarker
        sta     ScratchPtrHi
        lda     #<PlayerTwoStatisticsMarker
        sta     ScratchPtrLo
        ldx     #StatisticsPlayer2MarkerColumn
        ldy     #StatisticsFirstEnemyRow
        jsr     QueueTileAtCoordinates
        lda     #>PlayerTwoStatisticsMarker
        sta     ScratchPtrHi
        lda     #<PlayerTwoStatisticsMarker
        sta     ScratchPtrLo
        ldx     #StatisticsPlayer2MarkerColumn
        ldy     #StatisticsSecondEnemyRow
        jsr     QueueTileAtCoordinates
        lda     #>PlayerTwoStatisticsMarker
        sta     ScratchPtrHi
        lda     #<PlayerTwoStatisticsMarker
        sta     ScratchPtrLo
        ldx     #StatisticsPlayer2MarkerColumn
        ldy     #StatisticsThirdEnemyRow
        jsr     QueueTileAtCoordinates
        lda     #>PlayerTwoStatisticsMarker
        sta     ScratchPtrHi
        lda     #<PlayerTwoStatisticsMarker
        sta     ScratchPtrLo
        ldx     #StatisticsPlayer2MarkerColumn
        ldy     #StatisticsFourthEnemyRow
        jsr     QueueTileAtCoordinates
QueueStatisticsCountFields:
; Размещает четыре строки PTS в колонке P1; при двух игроках повторяет их в
; колонке P2. Числовые поля здесь не ставятся: их впервые выводит анимация
; QueueStatisticsRowValues, в том числе на завершающей пустой итерации строки.
LD014:  jsr     WaitForNextFrame
        lda     #>PointsText
        sta     ScratchPtrHi
        lda     #<PointsText
        sta     ScratchPtrLo
        ldx     #StatisticsPlayer1RowPointsColumn
        ldy     #StatisticsFirstEnemyRow
        jsr     QueueTileAtCoordinates
        lda     #>PointsText
        sta     ScratchPtrHi
        lda     #<PointsText
        sta     ScratchPtrLo
        ldx     #StatisticsPlayer1RowPointsColumn
        ldy     #StatisticsSecondEnemyRow
        jsr     QueueTileAtCoordinates
        lda     #>PointsText
        sta     ScratchPtrHi
        lda     #<PointsText
        sta     ScratchPtrLo
        ldx     #StatisticsPlayer1RowPointsColumn
        ldy     #StatisticsThirdEnemyRow
        jsr     QueueTileAtCoordinates
        lda     #>PointsText
        sta     ScratchPtrHi
        lda     #<PointsText
        sta     ScratchPtrLo
        ldx     #StatisticsPlayer1RowPointsColumn
        ldy     #StatisticsFourthEnemyRow
        jsr     QueueTileAtCoordinates
        lda     MenuSelection
        beq     QueueStatisticsFooter
        jsr     WaitForNextFrame
        lda     #>PointsText
        sta     ScratchPtrHi
        lda     #<PointsText
        sta     ScratchPtrLo
        ldx     #StatisticsPlayer2RowPointsColumn
        ldy     #StatisticsFirstEnemyRow
        jsr     QueueTileAtCoordinates
        lda     #>PointsText
        sta     ScratchPtrHi
        lda     #<PointsText
        sta     ScratchPtrLo
        ldx     #StatisticsPlayer2RowPointsColumn
        ldy     #StatisticsSecondEnemyRow
        jsr     QueueTileAtCoordinates
        lda     #>PointsText
        sta     ScratchPtrHi
        lda     #<PointsText
        sta     ScratchPtrLo
        ldx     #StatisticsPlayer2RowPointsColumn
        ldy     #StatisticsThirdEnemyRow
        jsr     QueueTileAtCoordinates
        lda     #>PointsText
        sta     ScratchPtrHi
        lda     #<PointsText
        sta     ScratchPtrLo
        ldx     #StatisticsPlayer2RowPointsColumn
        ldy     #StatisticsFourthEnemyRow
        jsr     QueueTileAtCoordinates
QueueStatisticsFooter:
; Завершает разметку горизонтальным разделителем и подписью TOTAL.
LD096:  jsr     WaitForNextFrame
        lda     #>StatisticsDivider
        sta     ScratchPtrHi
        lda     #<StatisticsDivider
        sta     ScratchPtrLo
        ldx     #StatisticsDividerColumn
        ldy     #StatisticsDividerRow
        jsr     QueueTileAtCoordinates
        lda     #>StatisticsTotalText
        sta     ScratchPtrHi
        lda     #<StatisticsTotalText
        sta     ScratchPtrLo
        ldx     #StatisticsTotalLabelColumn
        ldy     #StatisticsTotalsRow
        jsr     QueueTileAtCoordinates
        rts
; Выводит четыре двухтайловых изображения типов противников на экране
; статистики. Фиксированный X=$81; Y=$64,$7C,$94,$AC; базовые тайлы
; $80,$A0,$C0,$E0; атрибуты $02. Добавляет восемь спрайтов в OAM shadow.
; Меняет A/X/Y, RenderAttributes/OamTile/OamPairX/OamPairY и OamBufferPos.
DrawStatisticsEnemyIcons:
LD0B8:  lda     #StatisticsEnemyIconAttributes
        sta     RenderAttributes
        ldy     #StatisticsType0IconY
        lda     #StatisticsType0IconTile
        jsr     DrawStatisticsEnemyIcon
        ldy     #StatisticsType1IconY
        lda     #StatisticsType1IconTile
        jsr     DrawStatisticsEnemyIcon
        ldy     #StatisticsType2IconY
        lda     #StatisticsType2IconTile
        jsr     DrawStatisticsEnemyIcon
        ldy     #StatisticsType3IconY
        lda     #StatisticsType3IconTile
        jsr     DrawStatisticsEnemyIcon
        rts

; Заполняет выбранные байты shadow attribute table для двух колонок экрана
; статистики. Остальные байты должны быть заранее обнулены.
; Вход: NametableAttributes уже очищена. Выход A=$05; X/Y не меняются.
; Побочный эффект ограничен перечисленными байтами shadow attribute table.
InitializeStatisticsAttributes:
LD0D9:  lda     #$50
        sta     NametableAttributes+$00
        sta     NametableAttributes+$01
        sta     NametableAttributes+$02
        sta     NametableAttributes+$03
        sta     NametableAttributes+$08
        sta     NametableAttributes+$09
        sta     NametableAttributes+$0A
        sta     NametableAttributes+$0D
        sta     NametableAttributes+$0E
        sta     NametableAttributes+$0F
        lda     #$A0
        sta     NametableAttributes+$04
        sta     NametableAttributes+$05
        sta     NametableAttributes+$06
        sta     NametableAttributes+$07
        lda     #$0A
        sta     NametableAttributes+$10
        sta     NametableAttributes+$11
        sta     NametableAttributes+$12
        sta     NametableAttributes+$15
        sta     NametableAttributes+$16
        sta     NametableAttributes+$17
        lda     #$05
        sta     NametableAttributes+$30
        sta     NametableAttributes+$31
        sta     NametableAttributes+$32
        sta     NametableAttributes+$35
        sta     NametableAttributes+$36
        sta     NametableAttributes+$37
        rts

; Адаптер вывода одного двухтайлового значка статистики.
; Вход: A — базовый tile, Y — экранная координата; X принудительно $81,
; RenderAttributes уже содержит атрибуты. Добавляет два горизонтально соседних
; спрайта в OAM shadow; меняет A/X/Y, OamTile/OamPairX/OamPairY и OamBufferPos.
DrawStatisticsEnemyIcon:
LD130:  sta     OamTile
        ldx     #StatisticsEnemyIconX
        jsr     EmitTwoTileOamPair
        rts
