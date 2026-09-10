; Заглавный экран, игровые UI-сценарии и их данные ($C9C0-$D3FF).

StatisticsPlayer1Count = $5D
StatisticsPlayer2Count = $5E
StatisticsEnemyType    = $5A
StatisticsRowActive    = $7C
Player1StageKillTotal  = $7D
Player2StageKillTotal  = $7E
CurtainRowIndex        = $57
NametableRowFillTile   = $63

; Активный экран заголовка и главного меню.
; Использует слот танка 0 как мигающий курсор; SELECT циклически выбирает
; 1 PLAYER / 2 PLAYERS / CONSTRUCTION, START передаёт управление через таблицу.
; Если ConstructionMapFlag=0, после десяти тиков SlowFrameCounter возвращается для запуска демо-цикла.
; Скрытая комбинация ввода меняет TitleSecretInputCode; значение $2E при START открывает variant-меню.
; Побочно меняет состояние танков, MenuSelection, SlowFrameCounter/TitleSecretInputCode, scroll/nametable,
; палитру и OAM. A/X/Y не сохраняются. Ветви START снимают со стека адрес
; вызова TitleScreen и потому не возвращаются обычным RTS.
TitleScreen:
LC9C0:  lda     #$03
        sta     BackgroundPaletteIndex
        jsr     ClearTankStates
        lda     #$48
        sta     ObjectX
        jsr     UpdateTitleCursor
        lda     #$83
        sta     ObjectState
        lda     #$00
        sta     SlowFrameCounter
        sta     ObjectAttributes
        sta     ObjectFrame
        sta     PlayerStunTimer
        sta     PlayerStunTimer+1
        sta     VerticalScroll
        sta     TitleSecretInputCode
        lda     #$02
        sta     NametableBits
TitleMenuLoop:
LC9E6:  jsr     WaitForNextFrame
        lda     FrameCounter
        and     #$03
        bne     DrawTitleCursorAndReadInput
        lda     ObjectFrame
        eor     #$04
        sta     ObjectFrame
DrawTitleCursorAndReadInput:
LC9F5:  jsr     DrawTanks
        lda     Joy1Pressed
        and     #BUTTON_SELECT
        beq     CheckTitleSecretDownA
        inc     MenuSelection
        lda     #$00
        sta     SlowFrameCounter
CheckTitleSecretDownA:
LCA04:  lda     Joy1Held
        and     #BUTTON_DOWN
        beq     CheckTitleSecretRightB
        lda     Joy1Pressed
        and     #BUTTON_A
        beq     CheckTitleSecretRightB
        ; Down удерживается, A нажата в этом кадре: старший ниббл TitleSecretInputCode растёт.
        lda     #$10
        clc
        adc     TitleSecretInputCode
        sta     TitleSecretInputCode
CheckTitleSecretRightB:
LCA17:  lda     Joy1Held
        and     #BUTTON_RIGHT
        beq     NormalizeTitleMenuSelection
        lda     Joy1Pressed
        and     #BUTTON_B
        beq     NormalizeTitleMenuSelection
        ; Right удерживается, B нажата в этом кадре: TitleSecretInputCode уменьшается на единицу.
        dec     TitleSecretInputCode
NormalizeTitleMenuSelection:
LCA25:  lda     MenuSelection
        cmp     #$03
        bcc     UpdateTitleMenuCursor
        lda     #$00
        sta     MenuSelection
UpdateTitleMenuCursor:
LCA2F:  jsr     UpdateTitleCursor
        lda     SlowFrameCounter
        cmp     #$0A
        bne     CheckTitleStartInput
        lda     ConstructionMapFlag
        bne     CheckTitleStartInput
        rts

CheckTitleStartInput:
LCA3D:  lda     Joy1Pressed
        and     #BUTTON_START
        beq     TitleMenuLoop
        lda     TitleSecretInputCode
        cmp     #$2E
        bne     DispatchTitleMenuSelection
        jsr     RunVariantSelectionMenu
        pla
        pla
        jmp     MainFrontendLoop

        .byte   $EA
DispatchTitleMenuSelection:
LCA52:  lda     #$00
        sta     BackgroundPaletteIndex
        ; Удалить адрес возврата TitleScreen: выбранный обработчик продолжает
        ; верхнеуровневый сценарий и не должен вернуться к его вызывающему коду.
        pla
        pla
        lda     MenuSelection
        asl     a
        tay
        lda     MenuSelectionHandlers,y
        sta     ScratchPtrLo
        lda     MenuSelectionHandlers+1,y
        sta     ScratchPtrHi
        jmp     (ScratchPtrLo)

; Три адреса безвозвратной диспетчеризации по MenuSelection=0..2.
MenuSelectionHandlers:
LCA69:  .word   StartOnePlayer, StartTwoPlayers, StartConstruction

; GameMode=$05, новая игровая сессия и переход к выбору этапа.
StartOnePlayer:
        lda     #$05
        jmp     StartSelectedGameMode

; GameMode=$07, новая игровая сессия и переход к выбору этапа.
StartTwoPlayers:
        lda     #$07
StartSelectedGameMode:
LCA76:  sta     GameMode
        jsr     InitializeGameSession
        jmp     SelectStage

; Переходит в редактор Construction с GameMode=$07; сессию не инициализирует.
StartConstruction:
        lda     #$07
        sta     GameMode
        jmp     ConstructionMode

; Преобразует MenuSelection=0..2 в Y курсора:
; ObjectY=$8B+MenuSelection*$10. Возвращает это же значение в A; X/Y сохраняет.
UpdateTitleCursor:
LCA85:  lda     MenuSelection
        asl     a
        asl     a
        asl     a
        asl     a
        clc
        adc     #$8B
        sta     ObjectY
        rts

; На границе кадра формирует PPU-команды для надписи и десятичного StageNumber.
; Сначала пишет тайлы $23..$27,$11,$11 с ($0C,$0E), затем число с bias $6E.
; Меняет A/X/Y, ScratchPtr, $00, $35-$3C, $60 и PPU-очередь; на выходе $60=0.
UpdateStageNumberDisplay:
LCA91:  jsr     WaitForNextFrame
        ldx     #$0C
        ldy     #$0E
        jsr     TileCoordinatesToShadowAddress
        ldx     PpuBufferPos
        clc
        adc     #$1C
        sta     PpuUpdateBuffer,x
        inx
        tya
        sta     PpuUpdateBuffer,x
        inx
        lda     #$23
        sta     PpuUpdateBuffer,x
        inx
        lda     #$24
        sta     PpuUpdateBuffer,x
        inx
        lda     #$25
        sta     PpuUpdateBuffer,x
        inx
        lda     #$26
        sta     PpuUpdateBuffer,x
        inx
        lda     #$27
        sta     PpuUpdateBuffer,x
        inx
        lda     #$11
        sta     PpuUpdateBuffer,x
        inx
        lda     #$11
        sta     PpuUpdateBuffer,x
        inx
        lda     #$FF
        sta     PpuUpdateBuffer,x
        inx
        stx     PpuBufferPos
        lda     #$6E
        sta     TileTranslationOffset
        lda     StageNumber
        jsr     ByteToDisplayDigits
        ldy     #$36
        ldx     #$0E
        jsr     SelectVisibleDigits
        ldy     #$0E
        jsr     QueueTranslatedTileString
        lda     #$00
        sta     TileTranslationOffset
        rts

; Рисует четыре семитайловые строки базы и кирпичного ограждения в ($0C,$18).
; Затем обнуляет часть атрибутов $07F3/$07F4 и ставит два байта в PPU-очередь.
; Меняет A/X/Y, ScratchPtr, shadow nametable/attributes и PPU-очередь.
DrawBrickBaseEnclosure:
LCAF5:  lda     #>BlankBaseRow
        sta     ScratchPtrHi
        lda     #<BlankBaseRow
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$18
        jsr     QueueTileAtCoordinates
        lda     #>BrickBaseTopRow
        sta     ScratchPtrHi
        lda     #<BrickBaseTopRow
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$19
        jsr     QueueTileAtCoordinates
        lda     #>BrickBaseUpperRow
        sta     ScratchPtrHi
        lda     #<BrickBaseUpperRow
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$1A
        jsr     QueueTileAtCoordinates
        lda     #>BrickBaseLowerRow
        sta     ScratchPtrHi
        lda     #<BrickBaseLowerRow
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$1B
        jsr     QueueTileAtCoordinates

; Общий хвост обновления палитры нижней части базы: BaseAttributeUpper=0,
; в BaseAttributeLower сохраняются только биты $CC. Очередь получает адрес $23F3 и два байта.
QueueBrickBaseAttributes:
LCB31:
        ldx     PpuBufferPos
        lda     #$23
        sta     PpuUpdateBuffer,x
        inx
        lda     #$F3
        sta     PpuUpdateBuffer,x
        inx
        lda     #$00
        sta     BaseAttributeUpper
        sta     PpuUpdateBuffer,x
        inx
        lda     BaseAttributeLower
        and     #$CC
        sta     BaseAttributeLower
        sta     PpuUpdateBuffer,x
        inx
        lda     #$FF
        sta     PpuUpdateBuffer,x
        inx
        stx     PpuBufferPos
        rts

; Рисует только две центральные строки целой базы без окружающих стен.
; Очищает верхнюю пару палитр в BaseAttributeUpper маской $3F и ставит атрибут в очередь.
; Меняет A/X/Y, ScratchPtr, shadow nametable/attributes и PPU-очередь.
DrawBareBase:
LCB5D:  lda     #>IntactBaseUpperTiles
        sta     ScratchPtrHi
        lda     #<IntactBaseUpperTiles
        sta     ScratchPtrLo
        ldx     #$0E
        ldy     #$1A
        jsr     QueueTileAtCoordinates
        lda     #>IntactBaseLowerTiles
        sta     ScratchPtrHi
        lda     #<IntactBaseLowerTiles
        sta     ScratchPtrLo
        ldx     #$0E
        ldy     #$1B
        jsr     QueueTileAtCoordinates
        ldx     PpuBufferPos
        lda     #$23
        sta     PpuUpdateBuffer,x
        inx
        lda     #$F3
        sta     PpuUpdateBuffer,x
        inx
        lda     BaseAttributeUpper
        and     #$3F
        sta     BaseAttributeUpper
        sta     PpuUpdateBuffer,x
        inx
        lda     #$FF
        sta     PpuUpdateBuffer,x
        inx
        stx     PpuBufferPos
        rts

; Рисует четыре семитайловые строки базы со стальным ограждением.
; Устанавливает соответствующие палитровые поля BaseAttributeUpper/Lower и ставит их в очередь.
; Вызывается в том числе при мигании заканчивающегося защитного эффекта $45.
; Меняет A/X/Y, ScratchPtr, shadow nametable/attributes и PPU-очередь.
DrawSteelBaseEnclosure:
LCB9E:  lda     #>BlankSteelBaseRow
        sta     ScratchPtrHi
        lda     #<BlankSteelBaseRow
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$18
        jsr     QueueTileAtCoordinates
        lda     #>SteelBaseTopRow
        sta     ScratchPtrHi
        lda     #<SteelBaseTopRow
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$19
        jsr     QueueTileAtCoordinates
        lda     #>SteelBaseUpperRow
        sta     ScratchPtrHi
        lda     #<SteelBaseUpperRow
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$1A
        jsr     QueueTileAtCoordinates
        lda     #>SteelBaseLowerRow
        sta     ScratchPtrHi
        lda     #<SteelBaseLowerRow
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$1B
        jsr     QueueTileAtCoordinates
        ldx     PpuBufferPos
        lda     #$23
        sta     PpuUpdateBuffer,x
        inx
        lda     #$F3
        sta     PpuUpdateBuffer,x
        inx
        lda     #$3F
        sta     BaseAttributeUpper
        sta     PpuUpdateBuffer,x
        inx
        lda     BaseAttributeLower
        and     #$CC
        ora     #$33
        sta     BaseAttributeLower
        sta     PpuUpdateBuffer,x
        inx
        lda     #$FF
        sta     PpuUpdateBuffer,x
        inx
        stx     PpuBufferPos
        rts

; Заменяет центральные две строки базы изображением разрушенного состояния.
; Стены и атрибуты не меняет. Меняет A/X/Y, ScratchPtr, shadow и PPU-очередь.
DrawDestroyedBase:
LCC08:  lda     #>DestroyedBaseUpperTiles
        sta     ScratchPtrHi
        lda     #<DestroyedBaseUpperTiles
        sta     ScratchPtrLo
        ldx     #$0E
        ldy     #$1A
        jsr     QueueTileAtCoordinates
        lda     #>DestroyedBaseLowerTiles
        sta     ScratchPtrHi
        lda     #<DestroyedBaseLowerTiles
        sta     ScratchPtrLo
        ldx     #$0E
        ldy     #$1B
        jsr     QueueTileAtCoordinates
        rts

; За 64 кадра переносит NametableAttributes в PPU $23C0-$23FF,
; по одному байту за кадр. Меняет A/X/Y, ScratchPtr и PPU-очередь.
UploadAttributesGradually:
LCC27:  ldy     #$00
        lda     #$23
        sta     ScratchPtrHi
        lda     #$C0
        sta     ScratchPtrLo
UploadNextAttributeByte:
LCC31:  jsr     WaitForNextFrame
        ldx     PpuBufferPos
        lda     ScratchPtrHi
        sta     PpuUpdateBuffer,x
        inx
        lda     ScratchPtrLo
        sta     PpuUpdateBuffer,x
        inx
        lda     NametableAttributes,y
        iny
        sta     PpuUpdateBuffer,x
        inx
        lda     #$FF
        sta     PpuUpdateBuffer,x
        inx
        stx     PpuBufferPos
        lda     #$01
        jsr     AddAToPointer
        cpy     #$40
        bne     UploadNextAttributeByte
        rts

; Ставит в PPU-очередь полную 32-тайловую строку nametable.
; Вход: Y — номер строки; если NametableRowFillTile=0, данные берутся из
; shadow, иначе вся строка заполняется этим тайлом. Меняет A/X/Y, ScratchPtr,
; scratch $00 и PPU-очередь.
QueueNametableRow:
LCC5C:  ldx     #$00
        jsr     TileCoordinatesToShadowAddress
        sta     ScratchPtrHi
        sty     ScratchPtrLo
        ldx     PpuBufferPos
        lda     ScratchPtrHi
        clc
        adc     #$1C
        sta     PpuUpdateBuffer,x
        inx
        lda     ScratchPtrLo
        sta     PpuUpdateBuffer,x
        inx
        ldy     #$00
QueueNextNametableTile:
LCC78:  lda     NametableRowFillTile
        bne     StoreNametableTile
        lda     (ScratchPtrLo),y
StoreNametableTile:
LCC7E:  sta     PpuUpdateBuffer,x
        inx
        iny
        cpy     #$20
        bne     QueueNextNametableTile
        lda     #$FF
        sta     PpuUpdateBuffer,x
        inx
        stx     PpuBufferPos
        rts

; Шторка перед выбором этапа: за 16 кадров заполняет тайлом $11 парные строки,
; двигаясь от верхнего/нижнего краёв к центру. Меняет
; CurtainRowIndex/NametableRowFillTile и PPU-очередь.
CloseNametableCurtain:
LCC90:  lda     #$11
        sta     NametableRowFillTile
        lda     #$00
        sta     CurtainRowIndex
CloseCurtainNextRowPair:
LCC98:  jsr     WaitForNextFrame
        ldy     CurtainRowIndex
        jsr     QueueNametableRow
        lda     #$1D
        sec
        sbc     CurtainRowIndex
        tay
        jsr     QueueNametableRow
        inc     CurtainRowIndex
        lda     CurtainRowIndex
        cmp     #$10
        bne     CloseCurtainNextRowPair
        rts

; Обратная шторка: восстанавливает пары строк из shadow, двигаясь от центра
; к краям. Центральная пара при первых двух проходах записывается дважды.
; Меняет CurtainRowIndex/NametableRowFillTile и PPU-очередь.
OpenNametableCurtain:
LCCB2:  lda     #$00
        sta     NametableRowFillTile
        lda     #$0F
        sta     CurtainRowIndex
OpenCurtainNextRowPair:
LCCBA:  jsr     WaitForNextFrame
        ldy     CurtainRowIndex
        jsr     QueueNametableRow
        lda     #$1D
        sec
        sbc     CurtainRowIndex
        tay
        jsr     QueueNametableRow
        dec     CurtainRowIndex
        lda     CurtainRowIndex
        cmp     #$FF
        bne     OpenCurtainNextRowPair
        rts

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

; Однократно выдаёт дополнительную жизнь, когда десятитысячная цифра счёта
; достигает как минимум 2 (обычный первый порог — 20000 очков).
; Работает только при BattleStateActive. Для P1 проверяет Player1Score+2
; и PlayerExtraLifeAwarded; для P2 дополнительно требует MenuSelection!=0 и
; использует Player2Score+2/PlayerExtraLifeAwarded+1. При награде увеличивает
; соответствующий PlayerLives и запрашивает два аудиопотока дополнительной жизни. Меняет A и флаги;
; X/Y сохраняются.
AwardScoreThresholdLives:
LD138:  lda     BattleState
        cmp     #BattleStateActive
        bne     ReturnFromExtraLifeCheck
        lda     PlayerExtraLifeAwarded
        bne     CheckPlayerTwoExtraLife
        lda     Player1Score+2
        cmp     #$02
        bcc     CheckPlayerTwoExtraLife
        inc     Player1Lives
        inc     PlayerExtraLifeAwarded
        jmp     RequestExtraLifeAudio

CheckPlayerTwoExtraLife:
LD14F:  lda     MenuSelection
        beq     ReturnFromExtraLifeCheck
        lda     PlayerExtraLifeAwarded+1
        bne     ReturnFromExtraLifeCheck
        lda     Player2Score+2
        cmp     #$02
        bcc     ReturnFromExtraLifeCheck
        inc     Player2Lives
        inc     PlayerExtraLifeAwarded+1
RequestExtraLifeAudio:
LD161:  lda     #AudioStateStartRequested
        sta     ExtraLifePulse1AudioState
        sta     ExtraLifePulse2AudioState
ReturnFromExtraLifeCheck:
LD169:  rts

; Очищает основную nametable $2000: отключает рендеринг/NMI, обнуляет shadow,
; напрямую загружает 1 KiB и снова включает NMI. Выбирает фоновую палитру 3.
; Меняет A/X/Y, ScratchPtr, NametablePpuOffset, BackgroundPaletteIndex,
; shadow и PPU.
ClearPrimaryNametableScreen:
LD16A:  jsr     DisableRenderingForBulkUpdate
        lda     #$03
        sta     BackgroundPaletteIndex
        lda     #$1C
        sta     NametablePpuOffset
        jsr     ClearNametableBuffer
        jsr     UploadNametableBuffer
        jsr     EnableNmiAfterVblank
        rts

; Один раз строит статическую nametable заглавного экрана в $2400.
; При отключённом рендеринге очищает shadow, добавляет крупный логотип через
; внешний LE3D8 и крупную строку из CHR через LD8D2, затем загружает весь 1 KiB.
; После включения NMI ставит в очередь подписи рекорда, игроков и трёх пунктов
; меню; MenuSelection определяет наличие строки второго игрока.
; Побочно меняет A/X/Y, ScratchPtr/AuxPtr, NametablePpuOffset, $56/$57,
; TileTranslationOffset, shadow, PPU и очередь.
BuildTitleNametable:
LD17F:  jsr     DisableRenderingForBulkUpdate
        lda     #$24
        sta     NametablePpuOffset
        jsr     ClearNametableBuffer
        ldx     #$1A
        stx     RasterStringX
        ldy     #$2E
        sty     RasterStringY
        jsr     DrawVariantTitleData
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
        lda     #$E5
        sta     AuxPtrHi
        lda     #$E0
        sta     AuxPtrLo
        jsr     RasterizeTileStringToShadow
        jsr     UploadNametableBuffer
        jsr     EnableNmiAfterVblank
        lda     #$30
        sta     TileTranslationOffset
        lda     #>PlayerOneScorePrefix
        sta     ScratchPtrHi
        lda     #<PlayerOneScorePrefix
        sta     ScratchPtrLo
        ldx     #$02
        ldy     #$03
        jsr     QueueTileAtCoordinates
        ldy     #$16
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
        ldy     #$3E
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
        ldy     #$1E
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

; Адаптер двух строк без статических ссылок в текущем графе вызовов.
; Вход: A становится старшим байтом указателя A:$F8 для строки в ($04,$19);
; затем всегда трактует поток байтов с $D320 как строку для ($06,$1B).
; $D320 есть операнд STA $8C в InitializeRuntimeChecksumGuard. Строковый чтец проходил бы дальше по байтам
; опкодов до $FF в $D331. При A=$D2 первая строка аналогично началась бы с кода проверки $D2F8.
; Без вызывающего контекста назначение этого пути не подтверждено. Между потоками ждёт кадр.
; Назначение вызывающего сценария не подтверждено. Меняет A/X/Y, ScratchPtr
; и PPU-очередь.
QueueTwoLegacyScreenLines:
LD255:  nop
        sta     ScratchPtrHi
        lda     #$F8
        sta     ScratchPtrLo
        ldx     #$04
        ldy     #$19
        jsr     QueueTileAtCoordinates
        jsr     WaitForNextFrame
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$20
        sta     ScratchPtrLo
        ldx     #$06
        ldy     #$1B
        jsr     QueueTileAtCoordinates
        rts
; Ждёт X кадров, на каждом кадре заново выводя четыре значка статистики.
; Вход X должен быть 1..255: при X=0 цикл выполнит 256 проходов.
; Выход X=0; A/Y и OAM меняются через DrawStatisticsEnemyIcons.
DelayWithStatisticsIcons:
LD276:  jsr     WaitForNextFrame
        txa
        pha
        jsr     DrawStatisticsEnemyIcons
        pla
        tax
        dex
        bne     DelayWithStatisticsIcons
        rts

; $FF-терминированные строки экранного шрифта. ASCII-подобные байты совпадают
; с видимыми латинскими буквами; значения вне этого диапазона — специальные
; тайлы/значки, поэтому ниже они не интерпретируются как управляющий язык.
CreditsWrittenByText:
LD284:  .byte   $57,$52,$49,$54,$54,$45,$4E,$20,$42,$59,$FF
CreditsCopyrightText:
LD28F:  .byte   $40,$20,$59,$53,$20,$31,$39,$39,$30,$FF
TitleDecorativeTileRow:
LD299:  .byte   $00,$00,$C9,$CB,$00,$00,$FF
TitleCityText:
LD2A0:  .byte   $43,$49,$54,$59,$FF
PlayerOneScorePrefix:
LD2A5:  .byte   $5E,$6B,$FF
PlayerTwoScorePrefix:
LD2A8:  .byte   $5F,$6B,$FF
PlayerOneCompactMarker:
LD2AB:  .byte   $58,$13,$FF
PlayerTwoCompactMarker:
LD2AE:  .byte   $5A,$13,$FF
HighScoreCompactPrefix:
LD2B1:  .byte   $48,$49,$6B,$FF
HighScoreText:
LD2B5:  .byte   $48,$49,$53,$43,$4F,$52,$45,$FF
HighScoreStatisticsPrefix:
LD2BD:  .byte   $48,$49,$6B,$53,$43,$4F,$52,$45,$FF
OnePlayerMenuText:
LD2C6:  .byte   $31,$20,$50,$4C,$41,$59,$45,$52,$FF
TwoPlayersMenuText:
LD2CF:  .byte   $32,$20,$50,$4C,$41,$59,$45,$52,$53,$FF
PlayerOneStatisticsHeader:
LD2D9:  .byte   $5E,$6B,$50,$4C,$41,$59,$45,$52,$FF
PlayerTwoStatisticsHeader:
LD2E2:  .byte   $5F,$6B,$50,$4C,$41,$59,$45,$52,$FF
ConstructionMenuText:
LD2EB:  .byte   $43,$4F,$4E,$53,$54,$52,$55,$43,$54,$49,$4F,$4E,$FF
; Инициализирует проверку целостности во время игры: XOR-ит по семь байтов из
; $F677, $F7B9 и RuntimeChecksumFailureTarget в $8D, затем кладёт ожидаемое значение $CD в $8C.
; ScratchPtr остаётся равным RuntimeChecksumFailureTarget; при позднем несовпадении $8D/$8C код
; использует именно его как адрес косвенного перехода.
; Выход: A=$CD, $8C=$CD, $8D=вычисленный XOR, ScratchPtr=RuntimeChecksumFailureTarget, Y=$FF.
; X не меняется. Назначение проверяемых семибайтных областей отдельно не доказано.
InitializeRuntimeChecksumGuard:
LD2F8:  lda     #$00
        sta     RuntimeChecksumActual
        lda     #$77
        sta     ScratchPtrLo
        lda     #$F6
        sta     ScratchPtrHi
        jsr     XorSevenByteBlock
        lda     #$B9
        sta     ScratchPtrLo
        lda     #$F7
        sta     ScratchPtrHi
        jsr     XorSevenByteBlock
        lda     #<RuntimeChecksumFailureTarget
        sta     ScratchPtrLo
        lda     #>RuntimeChecksumFailureTarget
        sta     ScratchPtrHi
        jsr     XorSevenByteBlock
        lda     #$CD
        sta     RuntimeChecksumExpected
        rts

; Альтернативный вход: заменяет текущий XOR seed $8D входным A и затем
; обрабатывает семь байтов по ScratchPtr. PHA/PLA сохраняют баланс стека;
; восстановленный A сразу заменяется первым байтом блока.
SeedAndXorSevenByteBlock:
LD322:  pha
        sta     RuntimeChecksumActual
        pla
; XOR-ит (ScratchPtr)+6..0 в аккумулятор $8D.
; Вход: ScratchPtr; $8D — предыдущий seed. Выход: A=$8D=XOR, Y=$FF;
; ScratchPtr и X сохраняются.
XorSevenByteBlock:
LD326:  ldy     #$06
LD328:  lda     (ScratchPtrLo),y
        eor     RuntimeChecksumActual
        sta     RuntimeChecksumActual
        dey
        bpl     LD328
        rts

; $D332 завершает описанный выше поток с $D320; отдельной статической ссылки на него нет.
LegacyChecksumCodeStreamEnd:
LD332:  .byte   $20,$FF
; Три самостоятельных $FF-терминированных фрагмента без статических ссылок.
; Байты $4F..$48 во втором попадают в буквенный диапазон экранного шрифта, но смысл строки не утверждается.
UnreferencedScreenTextFragments:
LD334:  .byte   $4F,$50,$45,$4E,$6B,$52,$45,$41,$43,$48,$FF
LD33F:  .byte   $69,$FF
; Двухбайтная строка значка жизней используется UpdateLivesHud в двух позициях.
LivesHudIconText:
LD341:  .byte   $14,$FF
; Литеральная строка GAME; статических ссылок нет.
GameText:
LD343:  .byte   $47,$41,$4D,$45,$FF
; Литеральная строка OVER; статических ссылок нет.
OverText:
LD348:  .byte   $4F,$56,$45,$52,$FF
; Возвращает в A остаток от деления scratch-байта $00 на 6.
; Входное $00 не меняет; X/Y сохраняет. C=0 на выходе, кроме теоретического
; случая переполнения промежуточного вычитания, недостижимого для байта.
RemainderBySix:  lda     $00
SubtractSixUntilBelowDivisor:
LD34F:  cmp     #$06
        bcc     ReturnRemainderBySix
        sbc     #$06
        bcs     SubtractSixUntilBelowDivisor
ReturnRemainderBySix:
LD357:  rts

; Литеральная строка ORIKO; статических ссылок нет.
OrikoText:
LD358:  .byte   $4F,$52,$49,$4B,$4F,$FF
; Подпись PTS для восьми полей счётчиков на экране статистики.
PointsText:
LD35E:  .byte   $50,$54,$53,$FF
; Два одинаковых тайла маркера оставшихся противников в HUD.
RemainingEnemyMarkerTiles:
LD362:  .byte   $6A,$6A,$FF
; Верхняя и нижняя двухтайловые строки значка StageNumber в HUD.
StageHudUpperTiles:
LD365:  .byte   $6C,$FC,$FF
StageHudLowerTiles:
LD368:  .byte   $6D,$FD,$FF
BlankTileText:
LD36B:  .byte   $11,$FF

; Семитайловые строки базы. $0F — кирпичная стена, $10 — стальная,
; $C8-$CB — целая база, $CC-$CF — разрушенная. Эти строки одновременно
; копируются в shadow и ставятся в PPU-очередь.
BlankBaseRow:
LD36D:  .byte   $00,$00,$00,$00,$00,$00,$FF
BrickBaseTopRow:
LD374:  .byte   $00,$0F,$0F,$0F,$0F,$00,$FF
BrickBaseUpperRow:
LD37B:  .byte   $00,$0F,$C8,$CA,$0F,$00,$FF
BrickBaseLowerRow:
LD382:  .byte   $00,$0F,$C9,$CB,$0F,$00,$FF
BlankSteelBaseRow:
LD389:  .byte   $00,$00,$00,$00,$00,$00,$FF
SteelBaseTopRow:
LD390:  .byte   $00,$10,$10,$10,$10,$00,$FF
SteelBaseUpperRow:
LD397:  .byte   $00,$10,$C8,$CA,$10,$00,$FF
SteelBaseLowerRow:
LD39E:  .byte   $00,$10,$C9,$CB,$10,$00,$FF
IntactBaseUpperTiles:
LD3A5:  .byte   $C8,$CA,$FF
IntactBaseLowerTiles:
LD3A8:  .byte   $C9,$CB,$FF
DestroyedBaseUpperTiles:
LD3AB:  .byte   $CC,$CE,$FF
DestroyedBaseLowerTiles:
LD3AE:  .byte   $CD,$CF,$FF

; Строки экрана статистики.
PlayerOneStatisticsMarker:
LD3B1:  .byte   $5B,$FF
PlayerTwoStatisticsMarker:
VariantMenuSelectionCursor:
LD3B3:  .byte   $5D,$FF
StatisticsTotalText:
LD3B5:  .byte   $54,$4F,$54,$41,$4C,$FF
StatisticsDivider:
LD3BB:  .byte   $5C,$5C,$5C,$5C,$5C,$5C,$5C,$5C,$FF
StatisticsBonusText:
LD3C4:  .byte   $42,$4F,$4E,$55,$53,$15,$FF
StatisticsStageText:
LD3CB:  .byte   $53,$54,$41,$47,$45,$FF
; Упакованные десятичные награды за четыре типа противников.
; PreparePackedScoreIncrement помещает эти нибблы в сотни/десятки, поэтому
; фактические прибавки к счёту равны 100, 200, 300 и 400.
ScoreAwardsByEnemyType:
LD3D1:  .byte   $10,$20,$30,$40
; Шаг курсора/редактора по направлениям
; Up,Left,Down,Right. В одном месте значения масштабируются на 16 пикселей,
; в другом прибавляются непосредственно к координатам.
DirectionStepX:
LD3D5:  .byte   $00,$FF,$00,$01
DirectionStepY:
LD3D9:  .byte   $FF,$00,$01,$00
; Оба известных потребителя индексируют таблицы направлением 0..3; эти три $FF лежат за их границей.
PaddingBeforePowerUpEffect0:
LD3DD:  .byte   $FF,$FF,$FF
PowerUpEffect0:
; Эффект усиления 0 зависит от типа подобравшего слота.
; Для X=0/1 ставит таймер $89,X=$0A. Для X>=2 временно сохраняет X и проходит
; слоты танков 7..2, устанавливая младшие биты атрибутов и инвертируя бит $04:
; ObjectAttributes=(old|$03)^$04. Возвращает исходный X; A и флаги меняются.
LD3E0:  cpx     #$02
        bcc     ApplyPlayerPowerUpEffect0
        txa
        pha
        ldx     #$07
ApplyPowerUpEffect0ToNextEnemy:
LD3E8:  lda     ObjectAttributes,x
        ora     #$03
        eor     #$04
        sta     ObjectAttributes,x
        dex
        cpx     #$01
        bne     ApplyPowerUpEffect0ToNextEnemy
        pla
        tax
        rts

ApplyPlayerPowerUpEffect0:
LD3F8:  lda     #$0A
        sta     PlayerShieldTimer,x
        rts

; Заполнение конца экранного модуля до следующей процедуры $D400; ссылок на эти байты нет.
ScreenModuleEndPadding:
LD3FD:  .byte   $FF,$FF,$FF
