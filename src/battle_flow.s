; Выбор этапа, основной цикл боя и разбор исхода ($C159-$C2B2).

StageSelectionRepeatMask       = $07
StageSelectionNametableOffset  = $1C
StageTransitionFinishedCounter = $02

; Экран выбора этапа. Удержание A/B повторяет изменение через
; FrameCounter, START подтверждает StageNumber.
SelectStage:
; Вход: StageNumber — текущий этап, ConstructionMapFlag!=0 обозначает карту Construction.
; A/B листают этапы с автоповтором,
; START подтверждает. Далее загружает/рисует карту, инициализирует объекты и выполняет кадровый цикл до исхода этапа.
; Меняет почти всё игровое состояние, PPU/OAM/APU и A/X/Y. Все выходы идут
; через gameplay/result/frontend continuations; к непосредственному вызывающему
; процедура не возвращается.
LC159:  jsr     WaitForNextFrame
        jsr     ResetAudioEngine
        lda     #StageSelectionNametableOffset
        sta     NametablePpuOffset
        lda     #$00
        sta     VerticalScroll
        sta     NametableBits
        sta     PauseState
        lda     #$04
        sta     BackgroundPaletteIndex
        jsr     CloseNametableCurtain
StageSelectionInputLoop:
; Кадровый цикл выбора: обновляет надпись, A увеличивает StageNumber, B уменьшает;
; удержание повторяется раз в восемь кадров. Обычный диапазон циклически равен
; 1..50. Вариант 6 использует 1..118; его AdvanceStageNumber возвращается сюда
; нестандартно, снимая с аппаратного стека собственный адрес возврата.
; StageSelectionLocked!=0 или START передаёт управление BeginSelectedStage.
; Вход: StageNumber, StageSelectionLocked и Joy1*. Не возвращается самостоятельно.
; Меняет StageNumber, FrameCounter и PPU-очередь; портит A и флаги, X/Y зависят
; от UpdateStageNumberDisplay/AdvanceStageNumber/WrapStageNumberBackward.
LC172:  jsr     UpdateStageNumberDisplay
        lda     StageSelectionLocked
        bne     BeginSelectedStage
        lda     Joy1Pressed
        and     #BUTTON_START
        bne     BeginSelectedStage
        lda     Joy1Pressed
        and     #BUTTON_A
        bne     AdvanceStageSelection
        lda     Joy1Held
        and     #BUTTON_A
        beq     CheckStageSelectionBackward
        lda     FrameCounter
        and     #StageSelectionRepeatMask
        bne     CheckStageSelectionBackward
AdvanceStageSelection:
LC191:  lda     #$00
        sta     FrameCounter
        jsr     AdvanceStageNumber
        nop
        cmp     #(StandardStageUpperBound+1)
        bne     StageSelectionInputLoop
        lda     #FirstStageNumber
        sta     StageNumber
        jmp     StageSelectionInputLoop

CheckStageSelectionBackward:
LC1A4:  lda     Joy1Pressed
        and     #BUTTON_B
        bne     RetreatStageSelection
        lda     Joy1Held
        and     #BUTTON_B
        beq     StageSelectionInputLoop
        lda     FrameCounter
        and     #StageSelectionRepeatMask
        bne     StageSelectionInputLoop
RetreatStageSelection:
LC1B6:  lda     #$00
        sta     FrameCounter
        dec     StageNumber
        bne     StageSelectionInputLoop
        jsr     WrapStageNumberBackward
        nop
        jmp     StageSelectionInputLoop

; Подтверждён этап: запрашивает три потока вступительной музыки, рисует
; обычную или уже построенную Construction-карту и запускает игру.
; Вход: StageNumber и ConstructionMapFlag. Не возвращается: после подготовки
; проваливается в MainGameplayFrameLoop. Меняет PPU/shadow, игровые объекты,
; состояния трёх аудиопотоков и A/X/Y.
BeginSelectedStage:
LC1C5:  lda     #AudioStateStartRequested
        sta     StageIntroPulse1AudioState
        sta     StageIntroTriangleAudioState
        sta     StageIntroPulse2AudioState
        lda     ConstructionMapFlag
        bne     DrawConstructionStageBase
        jsr     InitializePlayfieldRectangle
        lda     StageNumber
        jsr     LoadAndDrawStage
        jsr     DrawBrickBaseEnclosure
        jmp     FinishSelectedStageSetup

DrawConstructionStageBase:
LC1E2:  jsr     DrawBareBase
FinishSelectedStageSetup:
LC1E5:  lda     #$00
        sta     PpuBufferPos
        jsr     UploadAttributesGradually
        jsr     OpenNametableCurtain
        lda     #$00
        sta     BackgroundPaletteIndex
        jsr     WaitForNextFrame
        jsr     InitializeStageRuntime
; Основной кадровый цикл. PauseState!=0 приостанавливает игровую логику, но
; оставляет отрисовку; START переключает паузу и её аудиопоток. При завершении
; этапа сбрасывает loop-аудио и входит в TransitionObjectFrameLoop.
; Вызванный как самостоятельная процедура не возвращается: дальнейшие пути
; заканчиваются новым выбором этапа либо переходом во frontend. Меняет игровую
; RAM, PPU/OAM/audio state и A/X/Y.
MainGameplayFrameLoop:
LC1F9:  jsr     WaitForNextFrame
        lda     PauseState
        bne     RenderGameplayFrame
        jsr     RunGameplayLogicTick
RenderGameplayFrame:
LC203:  jsr     DrawAndExpirePowerUp
        jsr     DrawProjectiles
        jsr     DrawTanks
        lda     Joy1Pressed
        and     #BUTTON_START
        beq     FinishGameplayFrame
        lda     #$01
        eor     PauseState
        sta     PauseState
        sta     PauseAudioState
FinishGameplayFrame:
LC21B:  jsr     DrawPauseOverlay
        jsr     CheckStageLoopFinished
        beq     MainGameplayFrameLoop
        lda     #$00
        sta     SlowFrameCounter
        sta     FrameCounter
        sta     PlayerMovementLoopAudioState
        sta     GameplayLoopAudioState
        lda     TransitionObjectTimer
        beq     TransitionObjectFrameLoop
        lda     #$FE
        sta     SlowFrameCounter
; Анимация/задержка после исхода этапа. Продолжает логику и рендеринг, пока
; SlowFrameCounter не станет 2.
TransitionObjectFrameLoop:
LC238:  jsr     WaitForNextFrame
        jsr     SuppressInputOutsideActiveStage
        jsr     RunGameplayLogicTick
        jsr     DrawAndExpirePowerUp
        jsr     DrawTanks
        jsr     DrawProjectiles
        jsr     UpdateHalfSecondPhaseFlag
        lda     SlowFrameCounter
        cmp     #StageTransitionFinishedCounter
        bne     TransitionObjectFrameLoop
        jsr     ResetAudioEngine
        jsr     ShowStageStatistics
        inc     StageNumber
        lda     StageNumber
        cmp     #$FF
        bne     ResolveStageOutcome
        lda     #FirstStageNumber
        sta     StageNumber
; После экрана статистики выбирает продолжение либо возврат во frontend.
; HandleSecretContinueChord проверяет chord, но независимо от него хвостом
; переходит в SelectStage; chord влияет только на восстановление выбывшего игрока.
ResolveStageOutcome:
LC265:  lda     Player1Lives
        clc
        adc     Player2Lives
        beq     ReturnToTitleAfterStage
        lda     BattleState
        cmp     #BattleStateActive
        bne     ReturnToTitleAfterStage
        jmp     HandleSecretContinueChord

; Статически неиспользуемый альтернативный continuation: ожидает в A число
; жизней P1, добавляет Player2Lives и при BattleStateActive хвостом переходит
; в SelectStage. При неуспехе проваливается в ReturnToTitleAfterStage.
UnusedContinueTail:
LC275:  clc
        adc     Player2Lives
        beq     ReturnToTitleAfterStage
        lda     BattleState
        cmp     #BattleStateActive
        bne     ReturnToTitleAfterStage
        jmp     SelectStage
ReturnToTitleAfterStage:
LC283:  jsr     ClearScreenAndAudio
        jsr     UpdateHighScoreRecord
        tya
        beq     RebuildTitleAfterStage
        jsr     ShowSessionResultScreen
        jsr     ClearScreenAndResumeNmi
RebuildTitleAfterStage:
LC292:  jmp     RebuildTitleNametable

; Гасит рендеринг, очищает shadow nametable, загружает её в nametable,
; выбранную NametableBits, и снова включает NMI.
; Портит A/X/Y, ScratchPtr и PPU state; OAM/APU не меняет.
ClearScreenAndResumeNmi:
LC295:  jsr     DisableRenderingForBulkUpdate
        jsr     ClearNametableBuffer
        jsr     UploadNametableBuffer
        jsr     EnableNmiAfterVblank
        rts

; Обнуляет held/pressed обоих контроллеров, если BattleState!=BattleStateActive.
; Выход: X/Y сохраняются; A=BattleState на активном пути, иначе A=0. Портит флаги.
SuppressInputOutsideActiveStage:
LC2A2:  lda     BattleState
        cmp     #BattleStateActive
        beq     FinishInputSuppression
        lda     #$00
        sta     Joy1Held
        sta     Joy2Held
        sta     Joy1Pressed
        sta     Joy2Pressed
FinishInputSuppression:
LC2B2:  rts
