; Экран и анимация послеэтапной статистики ($CCD4-$D137).

; Показывает и анимирует послеэтапную статистику.
; Player1KillCounts/Player2KillCounts — четыре счётчика уничтоженных типов;
; их суммы сохраняются в Player1/Player2StageKillTotal. Для каждой категории процедура по одному
; уменьшает исходные счётчики, увеличивает сценические счётчики $5D/$5E,
; прибавляет награду ScoreAwardsByEnemyType к записям $25/$2D и обновляет UI.
; После четырёх категорий выводит суммы. При $68!=0, режиме двух игроков и
; неравном результате живому игроку с большей суммой добавляет специальную
; награду PreparePackedScoreIncrement(0), то есть 1000 очков.
; Побочно уничтожает исходные счётчики $73-$7A, меняет записи счёта $15-$32,
; жизни/флаги награды, PPU/OAM, состояния аудиопотоков и рабочие
; StatisticsEnemyType/StatisticsPlayer*Count/StatisticsRowActive и итоговые счётчики.
; A/X/Y не сохраняются; работа занимает много кадров и завершается с
; NametableBits=0, $4D=$60=$6B=0.
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
NextEnemyStatisticsRow:
LCCFA:  jsr     WaitForNextFrame
        jsr     DrawStatisticsEnemyIcons
        ldx     #$25
        jsr     ResetEightByteRecord
        ldx     #$2D
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
        beq     ProcessPlayer2StatisticsCount
        lda     #AudioStateStartRequested
        sta     StatisticsCountPulseAudioState
        sta     StatisticsCountNoiseAudioState
        dec     Player1KillCounts,x
        inc     StatisticsPlayer1Count
        ldx     #$02
        jsr     AddScoreDigitsToRecord
        lda     #$01
        sta     StatisticsRowActive
        jsr     AwardScoreThresholdLives
ProcessPlayer2StatisticsCount:
LCD40:  ldx     StatisticsEnemyType
        lda     Player2KillCounts,x
        beq     RenderStatisticsRowValues
        lda     #AudioStateStartRequested
        sta     StatisticsCountPulseAudioState
        sta     StatisticsCountNoiseAudioState
        dec     Player2KillCounts,x
        inc     StatisticsPlayer2Count
        ldx     #$03
        jsr     AddScoreDigitsToRecord
        lda     #$01
        sta     StatisticsRowActive
        jsr     AwardScoreThresholdLives
RenderStatisticsRowValues:
LCD5E:  ldy     #$16
        ldx     #$05
        jsr     SelectVisibleDigits
        ldy     #$09
        jsr     QueueTranslatedTileString
        ldx     #$01
        ldy     #$26
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
        ldy     #$36
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
        beq     DelayAfterStatisticsUpdate
        ldy     #$1E
        ldx     #$17
        jsr     SelectVisibleDigits
        ldy     #$09
        jsr     QueueTranslatedTileString
        ldx     #$13
        ldy     #$2E
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
        ldy     #$36
        jsr     SelectVisibleDigits
        lda     StatisticsEnemyType
        asl     a
        clc
        adc     StatisticsEnemyType
        clc
        adc     #$0C
        tay
        jsr     QueueTranslatedTileString
DelayAfterStatisticsUpdate:
LCDD8:  ldx     #$08
        jsr     DelayWithStatisticsIcons
        lda     StatisticsRowActive
        beq     FinishEnemyStatisticsRow
        jmp     AnimateEnemyStatisticsRow

FinishEnemyStatisticsRow:
LCDE4:  inc     StatisticsEnemyType
        lda     StatisticsEnemyType
        cmp     #$04
        beq     ShowStatisticsTotals
        ldx     #$14
        jsr     DelayWithStatisticsIcons
        jmp     NextEnemyStatisticsRow

ShowStatisticsTotals:
LCDF4:  ldx     #$1E
        jsr     DelayWithStatisticsIcons
        lda     Player1StageKillTotal
        jsr     ByteToDisplayDigits
        ldy     #$36
        ldx     #$08
        jsr     SelectVisibleDigits
        ldy     #$17
        jsr     QueueTranslatedTileString
        lda     MenuSelection
        beq     DelayBeforeStatisticsBonus
        lda     Player2StageKillTotal
        jsr     ByteToDisplayDigits
        ldy     #$36
        ldx     #$0E
        jsr     SelectVisibleDigits
        ldy     #$17
        jsr     QueueTranslatedTileString
DelayBeforeStatisticsBonus:
LCE1F:  ldx     #$0F
        jsr     DelayWithStatisticsIcons
        lda     MenuSelection
        bne     AwardStatisticsWinnerBonus
        jmp     FinishStageStatistics

; Бонус сравнивается только для двух игроков и только при ненулевом $68.
AwardStatisticsWinnerBonus:
LCE2B:  lda     BattleState
        bne     AwardPlayerOneStatisticsBonus
        jmp     FinishStageStatistics

AwardPlayerOneStatisticsBonus:
LCE32:  lda     Player2StageKillTotal
        cmp     Player1StageKillTotal
        bcs     AwardPlayerTwoStatisticsBonus
        lda     Player1Lives
        beq     AwardPlayerTwoStatisticsBonus
        lda     #$00
        jsr     PreparePackedScoreIncrement
        ldx     #$00
        jsr     AddScoreDigitsToRecord
        ldy     #$16
        ldx     #$05
        jsr     SelectVisibleDigits
        ldy     #$09
        jsr     QueueTranslatedTileString
        ldy     #$36
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
        sta     AudioStreamRecords
        sta     AudioStreamRecords+1
        jsr     AwardScoreThresholdLives
        jmp     FinishStageStatistics

AwardPlayerTwoStatisticsBonus:
LCE8D:  lda     Player1StageKillTotal
        cmp     Player2StageKillTotal
        bcs     FinishStageStatistics
        lda     Player2Lives
        beq     FinishStageStatistics
        lda     #$00
        jsr     PreparePackedScoreIncrement
        ldx     #$01
        jsr     AddScoreDigitsToRecord
        ldy     #$1E
        ldx     #$17
        jsr     SelectVisibleDigits
        ldy     #$09
        jsr     QueueTranslatedTileString
        ldy     #$36
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
; A/X/Y, ScratchPtr, $04/NametablePpuOffset,
; $60/$6B, $4D, VerticalScroll/NametableBits, shadow/attributes и PPU-очередь.
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
        ldy     #$3E
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
        ldy     #$36
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
        ldy     #$16
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
        ldy     #$1E
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
; $80,$A0,$C0,$E0; атрибуты $02. Меняет A/X/Y, $04/$53-$55 и OAM.
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
; Выход A=$05; X/Y не меняются.
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
; $04 уже содержит атрибуты. Меняет A/X/Y, $53-$55 и OAM.
DrawStatisticsEnemyIcon:
LD130:  sta     OamTile
        ldx     #$81
        jsr     EmitTwoTileOamPair
        rts
