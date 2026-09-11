; Выбор этапа, основной цикл боя и разбор исхода ($C159-$C2B2).

; Экран выбора этапа. Удержание A/B повторяет изменение через
; FrameCounter, START подтверждает StageNumber.
SelectStage:
; Вход: StageNumber — текущий этап, ConstructionMapFlag!=0 обозначает карту Construction.
; A/B листают этапы с автоповтором,
; START подтверждает. Далее загружает/рисует карту, инициализирует объекты и выполняет кадровый цикл до исхода этапа.
; Меняет почти всё игровое состояние, PPU/OAM/APU и A/X/Y; в обычном потоке не возвращается к вызывающему.
LC159:  jsr     WaitForNextFrame
        jsr     ResetAudioEngine
        lda     #$1C
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
        and     #$07
        bne     CheckStageSelectionBackward
AdvanceStageSelection:
LC191:  lda     #$00
        sta     FrameCounter
        jsr     AdvanceStageNumber
        nop
        cmp     #$33
        bne     StageSelectionInputLoop
        lda     #$01
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
        and     #$07
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
; переходит в MainGameplayFrameLoop. Меняет PPU/shadow, игровые объекты,
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
; Не возвращается; меняет игровую RAM, PPU/OAM/audio state и A/X/Y.
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
        cmp     #$02
        bne     TransitionObjectFrameLoop
        jsr     ResetAudioEngine
        jsr     ShowStageStatistics
        inc     StageNumber
        lda     StageNumber
        cmp     #$FF
        bne     ResolveStageOutcome
        lda     #$01
        sta     StageNumber
; После сброса звука и экрана результата выбирает продолжение, секретный continue или возврат в главное меню.
ResolveStageOutcome:
LC265:  lda     Player1Lives
        clc
        adc     Player2Lives
        beq     ReturnToTitleAfterStage
        lda     BattleState
        cmp     #BattleStateActive
        bne     ReturnToTitleAfterStage
        jmp     HandleSecretContinueChord

; Альтернативный хвост продолжения: ожидает в A жизни P1, добавляет Player2Lives и при $68=$80 переходит в SelectStage.
; Прямых ссылок на LC275 нет; при неуспехе проваливается в общий возврат к главному меню.
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

; Гасит рендеринг, очищает shadow RAM, загружает её в текущую nametable,
; выбранную через $05, и снова включает NMI.
; Портит A/X и PPU state; Y не гарантируется из-за вызываемых процедур.
ClearScreenAndResumeNmi:
LC295:  jsr     DisableRenderingForBulkUpdate
        jsr     ClearNametableBuffer
        jsr     UploadNametableBuffer
        jsr     EnableNmiAfterVblank
        rts

; Обнуляет held/pressed обоих контроллеров, если $68!=$80. Портит A и флаги.
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
