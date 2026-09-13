; Экран и анимация послеэтапной статистики ($CCD4-$D137).

; Scratch-поля принадлежат экрану статистики и перекрываются с рабочими
; переменными других экранов/подсистем.
StatisticsPlayer1Count = $5D
StatisticsPlayer2Count = $5E
StatisticsEnemyType    = $5A
StatisticsRowActive    = $7C
Player1StageKillTotal  = $7D
Player2StageKillTotal  = $7E

; Временные семизначные записи начисления за текущий тип противника.
StatisticsPlayer1AwardDigits = $25
StatisticsPlayer2AwardDigits = $2D
StatisticsPlayer1AwardRecord = $02
StatisticsPlayer2AwardRecord = $03
StatisticsEnemyTypeCount     = $04

; Показывает и анимирует послеэтапную статистику.
; Player1KillCounts/Player2KillCounts — четыре счётчика уничтоженных типов;
; их суммы сохраняются в Player1/Player2StageKillTotal. Для каждой категории
; процедура по одному уменьшает исходные счётчики, увеличивает экранные
; StatisticsPlayer1/2Count, накапливает награду ScoreAwardsByEnemyType во
; временных StatisticsPlayer1/2AwardDigits и обновляет UI.
; После четырёх категорий выводит суммы. При BattleState!=0, двух игроках и
; неравном результате живому игроку с большей суммой добавляет специальную
; награду PreparePackedScoreIncrement(0), то есть 1000 очков.
; Входы: таблицы убийств и счёта заполнены завершившимся этапом; MenuSelection
; задаёт число игроков. Выходов в регистрах нет.
; Побочно уничтожает Player1/2KillCounts, меняет записи счёта и временных
; наград, жизни/флаги награды, PPU/OAM, состояния аудиопотоков и рабочие
; StatisticsEnemyType/StatisticsPlayer*Count/StatisticsRowActive и итоговые счётчики.
; A/X/Y не сохраняются; работа занимает много кадров и завершается с
; NametableBits, BackgroundPaletteIndex, TileTranslationOffset и DigitBlankMode=0.
ShowStageStatistics:
LCCD4:  jsr     BuildStageStatisticsScreen
        ldx     #$1E
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
        lda     #$00
        sta     StatisticsRowActive
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
        lda     #$01
        sta     StatisticsRowActive
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
        lda     #$01
        sta     StatisticsRowActive
        jsr     AwardScoreThresholdLives
; Перерисовывает общий счёт игрока, начисление за текущий тип и число уже
; обработанных убийств. QueueTranslatedTileString пишет только в PPU-очередь.
QueueStatisticsRowValues:
LCD5E:  ldy     #(Player1Score+1)
        ldx     #$05
        jsr     SelectVisibleDigits
        ldy     #$09
        jsr     QueueTranslatedTileString
        ldx     #$01
        ldy     #(StatisticsPlayer1AwardDigits+1)
        jsr     SelectVisibleDigits
        lda     StatisticsEnemyType
        asl     a
        clc
        adc     StatisticsEnemyType
        clc
        adc     #$0C
        tay
        jsr     QueueTranslatedTileString
        ldx     StatisticsEnemyType
        lda     StatisticsPlayer1Count
        jsr     ByteToDisplayDigits
        ldx     #$08
        ldy     #(ScoreIncrementDigits+1)
        jsr     SelectVisibleDigits
        lda     StatisticsEnemyType
        asl     a
        clc
        adc     StatisticsEnemyType
        clc
        adc     #$0C
        tay
        jsr     QueueTranslatedTileString
        lda     MenuSelection
        beq     WaitAfterStatisticsRowStep
        ldy     #(Player2Score+1)
        ldx     #$17
        jsr     SelectVisibleDigits
        ldy     #$09
        jsr     QueueTranslatedTileString
        ldx     #$13
        ldy     #(StatisticsPlayer2AwardDigits+1)
        jsr     SelectVisibleDigits
        lda     StatisticsEnemyType
        asl     a
        clc
        adc     StatisticsEnemyType
        clc
        adc     #$0C
        tay
        jsr     QueueTranslatedTileString
        ldx     StatisticsEnemyType
        lda     StatisticsPlayer2Count
        jsr     ByteToDisplayDigits
        ldx     #$0E
        ldy     #(ScoreIncrementDigits+1)
        jsr     SelectVisibleDigits
        lda     StatisticsEnemyType
        asl     a
        clc
        adc     StatisticsEnemyType
        clc
        adc     #$0C
        tay
        jsr     QueueTranslatedTileString
WaitAfterStatisticsRowStep:
LCDD8:  ldx     #$08
        jsr     DelayWithStatisticsIcons
        lda     StatisticsRowActive
        beq     AdvanceStatisticsEnemyType
        jmp     AnimateEnemyStatisticsRow

AdvanceStatisticsEnemyType:
LCDE4:  inc     StatisticsEnemyType
        lda     StatisticsEnemyType
        cmp     #StatisticsEnemyTypeCount
        beq     QueueStatisticsTotals
        ldx     #$14
        jsr     DelayWithStatisticsIcons
        jmp     BeginEnemyStatisticsRow

QueueStatisticsTotals:
LCDF4:  ldx     #$1E
        jsr     DelayWithStatisticsIcons
        lda     Player1StageKillTotal
        jsr     ByteToDisplayDigits
        ldy     #(ScoreIncrementDigits+1)
        ldx     #$08
        jsr     SelectVisibleDigits
        ldy     #$17
        jsr     QueueTranslatedTileString
        lda     MenuSelection
        beq     WaitBeforeStatisticsWinnerBonus
        lda     Player2StageKillTotal
        jsr     ByteToDisplayDigits
        ldy     #(ScoreIncrementDigits+1)
        ldx     #$0E
        jsr     SelectVisibleDigits
        ldy     #$17
        jsr     QueueTranslatedTileString
WaitBeforeStatisticsWinnerBonus:
LCE1F:  ldx     #$0F
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
        lda     #$00
        jsr     PreparePackedScoreIncrement
        ldx     #$00
        jsr     AddScoreDigitsToRecord
        ldy     #(Player1Score+1)
        ldx     #$05
        jsr     SelectVisibleDigits
        ldy     #$09
        jsr     QueueTranslatedTileString
        ldy     #(ScoreIncrementDigits+1)
        ldx     #$01
        jsr     SelectVisibleDigits
        ldy     #$1A
        jsr     QueueTranslatedTileString
        lda     #>StatisticsBonusText
        sta     ScratchPtrHi
        lda     #<StatisticsBonusText
        sta     ScratchPtrLo
        ldx     #$03
        ldy     #$19
        jsr     QueueTileAtCoordinates
        lda     #>PointsText
        sta     ScratchPtrHi
        lda     #<PointsText
        sta     ScratchPtrLo
        ldx     #$08
        ldy     #$1A
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
        lda     #$00
        jsr     PreparePackedScoreIncrement
        ldx     #$01
        jsr     AddScoreDigitsToRecord
        ldy     #(Player2Score+1)
        ldx     #$17
        jsr     SelectVisibleDigits
        ldy     #$09
        jsr     QueueTranslatedTileString
        ldy     #(ScoreIncrementDigits+1)
        ldx     #$14
        jsr     SelectVisibleDigits
        ldy     #$1A
        jsr     QueueTranslatedTileString
        lda     #>StatisticsBonusText
        sta     ScratchPtrHi
        lda     #<StatisticsBonusText
        sta     ScratchPtrLo
        ldx     #$16
        ldy     #$19
        jsr     QueueTileAtCoordinates
        lda     #>PointsText
        sta     ScratchPtrHi
        lda     #<PointsText
        sta     ScratchPtrLo
        ldx     #$1B
        ldy     #$1A
        jsr     QueueTileAtCoordinates
        lda     #AudioStateStartRequested
        sta     StatisticsWinnerBonusAudioState
; Та же недокументированная запись в первые два байта записи потока паузы.
        sta     AudioStreamRecords
        sta     AudioStreamRecords+1
        jsr     AwardScoreThresholdLives
FinishStageStatistics:
LCEE5:  ldx     #$78
        jsr     DelayWithStatisticsIcons
        lda     #$00
        sta     NametableBits
        sta     TileTranslationOffset
        sta     DigitBlankMode
        lda     #$00
        sta     BackgroundPaletteIndex
        rts
; Строит статический экран статистики в nametable $2400.
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
        lda     #$01
        sta     DigitBlankMode
        lda     #$24
        sta     NametablePpuOffset
        lda     #$00
        sta     VerticalScroll
        lda     #$02
        sta     NametableBits
        lda     #$30
        sta     TileTranslationOffset
        lda     #$03
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
        ldx     #$08
        ldy     #$03
        jsr     QueueTileAtCoordinates
        ldy     #(HighScore+1)
        ldx     #$12
        jsr     SelectVisibleDigits
        ldy     #$03
        jsr     QueueTranslatedTileString
        lda     #>StatisticsStageText
        sta     ScratchPtrHi
        lda     #<StatisticsStageText
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$05
        jsr     QueueTileAtCoordinates
        lda     StageNumber
        jsr     ByteToDisplayDigits
        ldy     #(ScoreIncrementDigits+1)
        ldx     #$0E
        jsr     SelectVisibleDigits
        ldy     #$05
        jsr     QueueTranslatedTileString
        jsr     WaitForNextFrame
        lda     #>PlayerOneStatisticsHeader
        sta     ScratchPtrHi
        lda     #<PlayerOneStatisticsHeader
        sta     ScratchPtrLo
        ldx     #$03
        ldy     #$07
        jsr     QueueTileAtCoordinates
        ldy     #(Player1Score+1)
        ldx     #$05
        jsr     SelectVisibleDigits
        ldy     #$09
        jsr     QueueTranslatedTileString
        lda     #>PlayerOneStatisticsMarker
        sta     ScratchPtrHi
        lda     #<PlayerOneStatisticsMarker
        sta     ScratchPtrLo
        ldx     #$0E
        ldy     #$0C
        jsr     QueueTileAtCoordinates
        lda     #>PlayerOneStatisticsMarker
        sta     ScratchPtrHi
        lda     #<PlayerOneStatisticsMarker
        sta     ScratchPtrLo
        ldx     #$0E
        ldy     #$0F
        jsr     QueueTileAtCoordinates
        lda     #>PlayerOneStatisticsMarker
        sta     ScratchPtrHi
        lda     #<PlayerOneStatisticsMarker
        sta     ScratchPtrLo
        ldx     #$0E
        ldy     #$12
        jsr     QueueTileAtCoordinates
        lda     #>PlayerOneStatisticsMarker
        sta     ScratchPtrHi
        lda     #<PlayerOneStatisticsMarker
        sta     ScratchPtrLo
        ldx     #$0E
        ldy     #$15
        jsr     QueueTileAtCoordinates
        lda     MenuSelection
        beq     QueueStatisticsCountFields
        jsr     WaitForNextFrame
        lda     #>PlayerTwoStatisticsHeader
        sta     ScratchPtrHi
        lda     #<PlayerTwoStatisticsHeader
        sta     ScratchPtrLo
        ldx     #$15
        ldy     #$07
        jsr     QueueTileAtCoordinates
        ldy     #(Player2Score+1)
        ldx     #$17
        jsr     SelectVisibleDigits
        ldy     #$09
        jsr     QueueTranslatedTileString
        lda     #>PlayerTwoStatisticsMarker
        sta     ScratchPtrHi
        lda     #<PlayerTwoStatisticsMarker
        sta     ScratchPtrLo
        ldx     #$11
        ldy     #$0C
        jsr     QueueTileAtCoordinates
        lda     #>PlayerTwoStatisticsMarker
        sta     ScratchPtrHi
        lda     #<PlayerTwoStatisticsMarker
        sta     ScratchPtrLo
        ldx     #$11
        ldy     #$0F
        jsr     QueueTileAtCoordinates
        lda     #>PlayerTwoStatisticsMarker
        sta     ScratchPtrHi
        lda     #<PlayerTwoStatisticsMarker
        sta     ScratchPtrLo
        ldx     #$11
        ldy     #$12
        jsr     QueueTileAtCoordinates
        lda     #>PlayerTwoStatisticsMarker
        sta     ScratchPtrHi
        lda     #<PlayerTwoStatisticsMarker
        sta     ScratchPtrLo
        ldx     #$11
        ldy     #$15
        jsr     QueueTileAtCoordinates
QueueStatisticsCountFields:
; Размещает одинаковую строку PTS и четыре пустых числовых поля в колонке P1;
; при двух игроках повторяет поля в колонке P2.
LD014:  jsr     WaitForNextFrame
        lda     #>PointsText
        sta     ScratchPtrHi
        lda     #<PointsText
        sta     ScratchPtrLo
        ldx     #$08
        ldy     #$0C
        jsr     QueueTileAtCoordinates
        lda     #>PointsText
        sta     ScratchPtrHi
        lda     #<PointsText
        sta     ScratchPtrLo
        ldx     #$08
        ldy     #$0F
        jsr     QueueTileAtCoordinates
        lda     #>PointsText
        sta     ScratchPtrHi
        lda     #<PointsText
        sta     ScratchPtrLo
        ldx     #$08
        ldy     #$12
        jsr     QueueTileAtCoordinates
        lda     #>PointsText
        sta     ScratchPtrHi
        lda     #<PointsText
        sta     ScratchPtrLo
        ldx     #$08
        ldy     #$15
        jsr     QueueTileAtCoordinates
        lda     MenuSelection
        beq     QueueStatisticsFooter
        jsr     WaitForNextFrame
        lda     #>PointsText
        sta     ScratchPtrHi
        lda     #<PointsText
        sta     ScratchPtrLo
        ldx     #$1A
        ldy     #$0C
        jsr     QueueTileAtCoordinates
        lda     #>PointsText
        sta     ScratchPtrHi
        lda     #<PointsText
        sta     ScratchPtrLo
        ldx     #$1A
        ldy     #$0F
        jsr     QueueTileAtCoordinates
        lda     #>PointsText
        sta     ScratchPtrHi
        lda     #<PointsText
        sta     ScratchPtrLo
        ldx     #$1A
        ldy     #$12
        jsr     QueueTileAtCoordinates
        lda     #>PointsText
        sta     ScratchPtrHi
        lda     #<PointsText
        sta     ScratchPtrLo
        ldx     #$1A
        ldy     #$15
        jsr     QueueTileAtCoordinates
QueueStatisticsFooter:
; Завершает разметку горизонтальным разделителем и подписью TOTAL.
LD096:  jsr     WaitForNextFrame
        lda     #>StatisticsDivider
        sta     ScratchPtrHi
        lda     #<StatisticsDivider
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$16
        jsr     QueueTileAtCoordinates
        lda     #>StatisticsTotalText
        sta     ScratchPtrHi
        lda     #<StatisticsTotalText
        sta     ScratchPtrLo
        ldx     #$06
        ldy     #$17
        jsr     QueueTileAtCoordinates
        rts
; Выводит четыре двухтайловых изображения типов противников на экране
; статистики. Фиксированный X=$81; Y=$64,$7C,$94,$AC; базовые тайлы
; $80,$A0,$C0,$E0; атрибуты $02. Добавляет восемь спрайтов в OAM shadow.
; Меняет A/X/Y, RenderAttributes/OamTile/OamPairX/OamPairY и OamBufferPos.
DrawStatisticsEnemyIcons:
LD0B8:  lda     #$02
        sta     RenderAttributes
        ldy     #$64
        lda     #$80
        jsr     DrawStatisticsEnemyIcon
        ldy     #$7C
        lda     #$A0
        jsr     DrawStatisticsEnemyIcon
        ldy     #$94
        lda     #$C0
        jsr     DrawStatisticsEnemyIcon
        ldy     #$AC
        lda     #$E0
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
        ldx     #$81
        jsr     EmitTwoTileOamPair
        rts
