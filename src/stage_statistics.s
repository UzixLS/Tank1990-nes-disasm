; Экран и анимация послеэтапной статистики ($CCD4-$D137).

; Scratch-поля принадлежат экрану статистики и перекрываются с рабочими
; переменными других экранов/подсистем.
StatisticsPlayer1Count = $5D
StatisticsPlayer2Count = $5E
StatisticsEnemyType    = $5A
StatisticsRowHadKillFlag = $7C
Player1StageKillTotal  = $7D
Player2StageKillTotal  = $7E

; Временные семизначные записи начисления за текущий тип противника.
StatisticsPlayer1AwardDigits = $25
StatisticsPlayer2AwardDigits = $2D
StatisticsPlayer1AwardRecordIndex = $02
StatisticsPlayer2AwardRecordIndex = $03
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

StatisticsPlayer1ScoreRecordIndex = $00
StatisticsPlayer2ScoreRecordIndex = $01
StatisticsWinnerBonusPackedAward  = $00 ; особый случай PreparePackedScoreIncrement -> 1000
StatisticsRowHadKill              = $01
StatisticsShowSingleZero          = $01
StatisticsAttributesBottomPalette1 = $50
StatisticsAttributesBottomPalette2 = $A0
StatisticsAttributesTopPalette2    = $0A
StatisticsAttributesTopPalette1    = $05

; Показывает и анимирует послеэтапную статистику в nametable $2800.
; Player1KillCounts/Player2KillCounts — по четыре unsigned счётчика
; типов 0..3. Их суммы сохраняются по модулю 256: carry между
; ADC намеренно сбрасывается, а старший байт не хранится. Для ромхака с
; суммой >255 и вывод TOTAL, и unsigned-сравнение победителя будут
; работать с уже обёрнутыми значениями.
; Для каждой категории одна итерация уменьшает не более чем по одному счётчику
; каждого игрока, увеличивает экранные StatisticsPlayer1/2Count, накапливает
; награду ScoreAwardsByEnemyType во временных StatisticsPlayer1/2AwardDigits и
; обновляет UI. После последнего убийства выполняется ещё одна итерация без
; списания: она выводит окончательные значения и переводит цикл к следующему типу.
; Временные award-records — семь отдельных десятичных цифр+терминатор;
; они сбрасываются для каждого типа и не являются счётом игрока. Этот экран
; не повторяет gameplay-начисление за убийства: он меняет общий счёт
; только бонусом победителя. В UI выводятся только младшие шесть цифр
; каждой семизначной score/award record: million digit не показывается.
; После четырёх категорий выводит суммы. При BattleState!=0, двух игроках и
; неравном результате живому игроку с большей суммой добавляет специальную
; награду PreparePackedScoreIncrement(0), то есть 1000 очков.
; Каждая категория занимает 1+9*(max(P1kills,P2kills)+1) NMI: один NMI
; перед сбросом строки, по одному перед каждой итерацией и по восемь
; после неё; +1 — пустая завершающая итерация. Без учёта Build весь Show ждёт
; 295+9*sum(max(kills[type])) NMI; Build добавляет 5 NMI в 1P и 7 NMI в 2P.
; Входы: таблицы убийств и счёта заполнены завершившимся этапом; MenuSelection=0
; выбирает 1P, любое ненулевое значение — 2P. Выход: A=X=Y=0, Z=1/N=0;
; C/V остаются от последней OAM-отрисовки и не заданы контрактом.
; Побочно уничтожает Player1/2KillCounts, меняет записи счёта и временных
; наград, жизни/флаги награды, PPU/OAM, состояния аудиопотоков и рабочие
; StatisticsEnemyType/StatisticsPlayer*Count/StatisticsRowHadKillFlag и
; итоговые счётчики. Входные kill arrays на выходе нулевые; count fields
; содержат количества лишь последнего, типа 3, а totals — исходные суммы.
; StatisticsEnemyType=4 и StatisticsRowHadKillFlag=0; temporary records содержат
; накопления только за тип 3.
; PpuBufferPos=0 после последнего WaitForNextFrame; hardware OAM содержит
; значки предыдущей итерации, OAM shadow — свежие восемь для следующего DMA.
; NametablePpuOffset остаётся $24; TileTranslationOffset/DigitBlankMode сразу
; сбрасываются в 0. NametableBits=0 и BackgroundPaletteIndex=0 — лишь RAM-запросы:
; после их записи нет NMI, поэтому аппаратные PPU_CTRL/palette остаются
; статистическими до NMI caller-а.
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
; Начало категории: очищает только временные award/count поля этой строки.
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
; Одна итерация списывает не более одного убийства каждого игрока. Флаг ставится
; только если действительно списано хотя бы одно; ноль после вывода завершает строку.
; PreparePackedScoreIncrement готовит 100/200/300/400 по ScoreAwardsByEnemyType;
; AddScoreDigitsToRecord здесь прибавляет их только к temporary record 2/3. При каждом
; списании оба audio channels получают start request, а threshold-life scan
; смотрит не этот temporary record, а оба глобальных score records.
        lda     #$00
        sta     StatisticsRowHadKillFlag
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
        ldx     #StatisticsPlayer1AwardRecordIndex
        jsr     AddScoreDigitsToRecord
        lda     #StatisticsRowHadKill
        sta     StatisticsRowHadKillFlag
        jsr     AwardScoreThresholdLives
; Симметричная половина P2 использует то же подготовленное приращение текущего
; enemy type. MenuSelection здесь не проверяется: даже в 1P ненулевые P2 counts
; будут скрыто списаны, попадут в тайминг/временную награду и запустят audio;
; одноигрочный caller должен держать таблицу P2 нулевой.
ConsumePlayer2Kill:
LCD40:  ldx     StatisticsEnemyType
        lda     Player2KillCounts,x
        beq     QueueStatisticsRowValues
        lda     #AudioStateStartRequested
        sta     StatisticsCountPulseAudioState
        sta     StatisticsCountNoiseAudioState
        dec     Player2KillCounts,x
        inc     StatisticsPlayer2Count
        ldx     #StatisticsPlayer2AwardRecordIndex
        jsr     AddScoreDigitsToRecord
        lda     #StatisticsRowHadKill
        sta     StatisticsRowHadKillFlag
        jsr     AwardScoreThresholdLives
; Ставит в PPU-очередь общий счёт, award за текущий тип и число уже
; обработанных убийств. Строка = 12+StatisticsEnemyType*3; P2 пропускается при
; MenuSelection=0. Каждое поле есть отдельная [addr_hi,addr_lo,data,$FF] command:
; score/award дают 4..9 bytes, byte-count — 4..6; всего 12..24 bytes в 1P
; и 24..48 в 2P. Это наибольший batch экрана и он с lookahead помещается
; в 128-byte PpuUpdateBuffer. Первый NMI в последующей 8-frame паузе flush-ит
; batch. Цифровые commands не копируются в nametable shadow.
; Вход: StatisticsEnemyType=0..3; счётчики, award/score records актуальны;
; очередь пуста после WaitForNextFrame выше. Меняет A/X/Y, ScratchPtr,
; PpuTileRowBits, PpuBufferPos/queue и ScoreIncrementDigits; исходные
; счётчики/score records, nametable shadow и OAM не меняет.
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
; Загрузка X не влияет на результат: ByteToDisplayDigits сразу заменяет его
; адресом ScoreIncrementDigits.
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
; Аналогичная нейтральная загрузка X с тем же недоказанным назначением.
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
        lda     StatisticsRowHadKillFlag
        beq     AdvanceStatisticsEnemyType
        jmp     AnimateEnemyStatisticsRow

; Пустая завершающая итерация уже вывела финальные числа. Переходит к следующей
; из четырёх категорий либо к строке TOTAL.
AdvanceStatisticsEnemyType:
LCDE4:  inc     StatisticsEnemyType
        lda     StatisticsEnemyType
        cmp     #StatisticsEnemyTypeCount
        beq     QueueStatisticsTotals
        ldx     #StatisticsBetweenRowsDelayFrames
        jsr     DelayWithStatisticsIcons
        jmp     BeginEnemyStatisticsRow

QueueStatisticsTotals:
; После 30 NMI ставит unsigned totals 0..255 в строку 23.
; Одна command занимает 4..6 bytes; 2P batch — не более 12 bytes.
; Очередь flush-ится первым NMI 15-frame winner delay; shadow не меняется.
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

; Бонус сравнивается только для двух игроков и при любом BattleState!=0,
; не только при одном конкретном state. Сравнение unsigned и строгое: ничья,
; ноль жизней у игрока с большим total или BattleState=0 не дают бонус никому.
; Победитель получает 1000 в score modulo 10^7. Бонусный batch: score
; 4..9 bytes, число 1000 — 7, BONUS — 9, PTS — 6; всего 26..31 bytes.
; Первый NMI финальной 120-frame паузы flush-ит его; только BONUS/PTS
; также попадают в shadow, цифровые поля — нет.
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
        lda     #StatisticsWinnerBonusPackedAward
        jsr     PreparePackedScoreIncrement
        ldx     #StatisticsPlayer1ScoreRecordIndex
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
; Побочный эффект: запись 1 в route и кеш регистра APU 0 потока паузы.
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
        lda     #StatisticsWinnerBonusPackedAward
        jsr     PreparePackedScoreIncrement
        ldx     #StatisticsPlayer2ScoreRecordIndex
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
; Та же недоказанная pause-stream запись, что и в ветви P1.
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
; NametablePpuOffset=ShadowToNametable2800Offset прибавляется к high-byte shadow ($04..$07),
; а NametableBits=$02 выбирает ту же физическую nametable для рендеринга.
; Отключает рендеринг/NMI, очищает shadow, задаёт палитровые атрибуты,
; целиком передаёт nametable и снова включает NMI. Затем за несколько кадров
; ставит заголовки, текущие суммарные очки, номер этапа, четыре строки типов
; противников и поля счётчиков для одного или двух игроков.
; Статические QueueTileAtCoordinates calls обновляют и shadow, и PPU queue;
; цифровые QueueTranslatedTileString calls меняют только очередь. DigitBlankMode=1
; оставляет один ноль в целиком нулевом поле; bias $30 превращает digits
; 0..9 в tiles $30..$39. Общий score/high score берётся с record+1, поэтому поле
; не шире шести цифр; StageNumber конвертируется как unsigned byte 0..255.
;
; NMI/batch layout (числа включают address, terminator, но не lookahead):
;   initial Wait + DisableRenderingForBulkUpdate = 2 NMI;
;   high-score/stage batch = 27..34 bytes, затем Wait;
;   player header/score/four markers = 31..36 bytes на игрока;
;   four PTS strings = 24 bytes на игрока;
;   footer divider+TOTAL = 19 bytes и остаётся pending на возврате.
; Итог: 5 NMI в 1P, 7 NMI в 2P, плюс один опрошенный vblank в
; EnableNmiAfterVblank; максимальный batch 36 bytes безопасен для 128-byte queue.
; Первый intro NMI в caller-е передаёт footer в PPU.
; Вход: MenuSelection определяет наличие второго столбца; StageNumber и записи
; Player1Score/Player2Score/HighScore используются для UI. Побочно меняет
; A/X/Y, ScratchPtr/AuxPtr/PpuTileRowBits, NametablePpuOffset,
; TileTranslationOffset/DigitBlankMode, BackgroundPaletteIndex,
; VerticalScroll/NametableBits, shadow/attributes и PPU-очередь. Возвращается
; с A=$FF, X=PpuBufferPos=19, Y=5, Z=1/N=0/C=1/V=0. ScratchPtr
; указывает на StatisticsTotalText, AuxPtr — на shadow row 23,column 6;
; BackgroundPaletteIndex=$FF после palette upload в NMI, PpuBufferPos=19.
; NametablePpuOffset=$24, VerticalScroll=0, NametableBits=2,
; TileTranslationOffset=$30 и DigitBlankMode=1 остаются для анимации.
; Прямые PPU-записи идут при выключённом rendering; после EnableNmiAfterVblank
; нельзя увеличивать batch так, чтобы его построение пересеклось с NMI flush.
BuildStageStatisticsScreen:
LCEF7:  jsr     WaitForNextFrame
        lda     #StatisticsShowSingleZero
        sta     DigitBlankMode
        lda     #ShadowToNametable2800Offset
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
; Каждый 4*"PTS" batch занимает точно 24 queue bytes и при построении
; также копирует 12 tiles в nametable shadow.
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
; Завершает разметку 8-tile разделителем и 5-tile подписью TOTAL.
; После Wait queue пуста; обе commands дают точно 19 bytes, обновляют
; shadow и остаются pending до первого intro NMI в ShowStageStatistics.
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
; статистики. Опорный screen X=$81; Y=$64,$7C,$94,$AC; tile pairs
; $80/$82,$A0/$A2,$C0/$C2,$E0/$E2. Всего добавляет 8 hardware entries = 32 bytes
; OAM shadow по текущему OamBufferStep; hardware OAM изменится лишь на
; следующем NMI DMA. Caller должен дать восемь свободных entries и cursor/step,
; выровненные по 4; штатный WaitForNextFrame это обеспечивает.
; Начальные attributes=$02, но EmitOamSprite может sticky-OR-нуть
; SpriteBehindTerrainMask, если terrain probe найдёт shadow tile $22; для изменённой
; разметки этот эффект тоже должен учитываться.
; Выход: A=OamBufferPos после 8 entries, X=offset последней entry,
; Y=0, OamTile=$E2, N/Z/C/V от последнего cursor+step. Меняет RenderAttributes,
; OamTile/OamPairX/OamPairY, OamSavedX/Y, ScratchPtr/PpuTileRowBits и OamBufferPos.
; После четвёртой пары OamPairX/Y=$81/$AC, OamSavedX/Y=$81/$A4,
; ScratchPtr=$06B0 и PpuTileRowBits=$A0; PPU queue/registers не меняются.
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

; Заполняет 26 выбранных байтов 8x8 shadow attribute table. Каждый
; byte задаёт четыре 2-bit background palette indices для 4x4-tile области:
;   bottom palette1 -> offsets 00..03,08..0A,0D..0F (10 bytes);
;   bottom palette2 -> offsets 04..07 (4 bytes);
;   top palette2 -> offsets 10..12,15..17 (6 bytes);
;   top palette1 -> offsets 30..32,35..37 (6 bytes).
; Все остальные 38 bytes должны быть заранее обнулены; штатно это делает
; ClearNametableBuffer. Границы палитр выровнены по блокам 4x4 тайла.
; Вход: NametableAttributes очищена. Выход: A=$05, N=0/Z=0;
; X/Y и C/V сохранены. PPU queue/registers и tile area shadow не меняются.
InitializeStatisticsAttributes:
LD0D9:  lda     #StatisticsAttributesBottomPalette1
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
        lda     #StatisticsAttributesBottomPalette2
        sta     NametableAttributes+$04
        sta     NametableAttributes+$05
        sta     NametableAttributes+$06
        sta     NametableAttributes+$07
        lda     #StatisticsAttributesTopPalette2
        sta     NametableAttributes+$10
        sta     NametableAttributes+$11
        sta     NametableAttributes+$12
        sta     NametableAttributes+$15
        sta     NametableAttributes+$16
        sta     NametableAttributes+$17
        lda     #StatisticsAttributesTopPalette1
        sta     NametableAttributes+$30
        sta     NametableAttributes+$31
        sta     NametableAttributes+$32
        sta     NametableAttributes+$35
        sta     NametableAttributes+$36
        sta     NametableAttributes+$37
        rts

; Адаптер вывода одного двухтайлового значка статистики.
; Вход: A=base tile, Y=screen Y; screen X принудительно $81;
; RenderAttributes, SpriteBehindTerrainMask и OAM cursor/step подготовлены.
; Пишет entries в X=$79/$81 с tiles base/base+2. Выход: A=новый cursor,
; X=offset второй entry, Y=0, OamTile=base+2; flags от второго cursor+step.
; Меняет OAM shadow/cursor, RenderAttributes условно, OAM/coordinate scratch
; и shadow-pointer scratch; hardware OAM/PPU queue/registers не меняет.
DrawStatisticsEnemyIcon:
LD130:  sta     OamTile
        ldx     #StatisticsEnemyIconX
        jsr     EmitTwoTileOamPair
        rts
