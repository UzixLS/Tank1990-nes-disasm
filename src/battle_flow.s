; Выбор этапа, основной цикл боя и разбор исхода ($C159-$C2B2).

StageSelectionRepeatMask       = $07
StageSelectionBackgroundPalette = $04
GameplayBackgroundPalette       = $00
PauseToggleMask                  = $01
LongStageTransitionCounterStart  = $FE
StageTransitionFinishedCounter = $02
AutomaticStageWrapSentinel       = $FF

; Полный безвозвратный сценарий от выбора этапа до следующего этапа/frontend.
; Требует включённый NMI: первый WaitForNextFrame передаёт накопленные команды,
; после чего audio engine сбрасывается, scroll/nametable выбирают $2000,
; PauseState очищается, palette 4 планируется и 16-итерационная шторка закрывает
; поле. Ручной выбор использует P1 A/B, START подтверждает StageNumber.
SelectStage:
; Вход: StageNumber!=0, ConstructionMapFlag!=0 обозначает сохранённую карту
; Construction. Меняет почти всё игровое состояние, PPU/OAM/APU и A/X/Y.
; Все выходы идут через gameplay/result/frontend continuations; к caller-у не
; возвращается. Ромхак не должен вызывать этот entry при выключенном NMI.
LC159:  jsr     WaitForNextFrame
        jsr     ResetAudioEngine
        lda     #ShadowToPrimaryNametableOffset
        sta     NametablePpuOffset
        lda     #$00
        sta     VerticalScroll
        sta     NametableBits
        sta     PauseState
        lda     #StageSelectionBackgroundPalette
        sta     BackgroundPaletteIndex
        jsr     CloseNametableCurtain
StageSelectionInputLoop:
; Каждая итерация сначала ждёт NMI, выводит номер и получает свежий input.
; StageSelectionLocked!=0 проверяется раньше кнопок и автоматически подтверждает
; текущий номер. Нажатие A/B срабатывает сразу; удержание повторяется при
; FrameCounter mod8=0, причём выполненное изменение сбрасывает FrameCounter=0.
; A имеет приоритет над B, если оба подходят в одной итерации.
;
; Ручные диапазоны цикличны: 1..50 обычно и 1..118 при
; (GameVariant&$0F)=6. Расширенный AdvanceStageNumber снимает собственный адрес
; JSR со стека и прыгает прямо сюда; этот call site нельзя заменять tail-JMP,
; оборачивать дополнительным stack frame или ожидать обычного возврата.
; Автоматический номер после завершённого этапа может быть выше ручной границы.
; Меняет StageNumber, FrameCounter, decimal/scratch и PPU queue; shadow для
; текста выбора не обновляется. X/Y зависят от вызванных helpers.
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

; Подтверждён этап. Три intro-потока запрашиваются до длительной подготовки,
; поэтому начинают обслуживаться во внутренних NMI загрузчика. Обычный путь
; очищает 26x26 playfield в shadow, распаковывает StageNumber и добавляет
; кирпичную базу. ConstructionMapFlag!=0 считает уже построенную shadow-карту
; валидной, не очищает/не загружает уровень и дорисовывает только голую базу.
;
; После обоих путей PpuBufferPos=0 намеренно отбрасывает команды stage-number,
; base helpers и любые остатки loader-а: карта должна быть полностью отражена
; в NametableShadow. Это обязательный контракт для производного map loader-а.
; Затем 64 NMI передают attributes, 16 итераций шторки восстанавливают tile rows,
; palette 0 применяется отдельным WaitForNextFrame, и InitializeStageRuntime
; создаёт объекты/счётчики. Его последняя HUD-команда остаётся до первого NMI
; gameplay-loop. Не возвращается: проваливается в MainGameplayFrameLoop.
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
        lda     #GameplayBackgroundPalette
        sta     BackgroundPaletteIndex
        jsr     WaitForNextFrame
        jsr     InitializeStageRuntime
; Основной кадровый цикл. Каждый Wait сначала передаёт предыдущий OAM/PPU frame,
; читает input и обновляет audio/counters. При PauseState=0 выполняется полный
; logic tick; при паузе заморожены game logic, shield/base timers и collision,
; но бонус продолжает мигать/уменьшать pickup-display timer, а снаряды и танки
; перерисовываются из неизменного state.
;
; Порядок OAM этого цикла: effects из logic, power-up, projectiles, tanks,
; затем возможный PAUSE overlay. START переключает pause уже после отрисовки
; объектов и записывает то же 0/1 в PauseAudioState; audio применит запрос на
; следующем NMI. CheckStageLoopFinished вызывается даже в паузе. OAM/PPU queue
; capacity нигде здесь не проверяется. Процедура не возвращается.
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
        lda     #PauseToggleMask
        eor     PauseState
        sta     PauseState
        sta     PauseAudioState
FinishGameplayFrame:
LC21B:  jsr     DrawPauseOverlay
        jsr     CheckStageLoopFinished
        beq     MainGameplayFrameLoop
        ; Останавливаются только два loop-потока; прочие sounds живут до
        ; ResetAudioEngine после transition delay.
        lda     #$00
        sta     SlowFrameCounter
        sta     FrameCounter
        sta     PlayerMovementLoopAudioState
        sta     GameplayLoopAudioState
        lda     TransitionObjectTimer
        beq     TransitionObjectFrameLoop
        lda     #LongStageTransitionCounterStart
        sta     SlowFrameCounter
; После исхода FrameCounter начинается с 0. Если TransitionObjectTimer=0,
; SlowFrameCounter стартует с 0 и штатно достигает 2 через 128 NMI; ненулевой
; timer выбирает старт $FE и четыре приращения через wrap, то есть 256 NMI.
; Ненулевой timer может быть только что созданным GAME OVER либо оставшимся
; переходом выбывшего игрока.
;
; PauseState здесь не проверяется: logic продолжает работать всегда. Input
; сохраняется только при BattleState=$80; при countdown/поражении он обнуляется
; перед logic tick. Порядок видимого OAM отличается от основного цикла:
; logic effects, power-up, tanks, projectiles. UpdateHalfSecondPhaseFlag на
; FrameCounter mod64=0/32 планирует palette 2/1. Цикл заканчивается строго по
; SlowFrameCounter=2, а не по TransitionObjectTimer.
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
        ; Автоматическая последовательность не использует ручные границы
        ; 50/118: byte StageNumber проходит 1..$FE, а $FF заменяется единицей.
        inc     StageNumber
        lda     StageNumber
        cmp     #AutomaticStageWrapSentinel
        bne     ResolveStageOutcome
        lda     #FirstStageNumber
        sta     StageNumber
; После статистики продолжение возможно только при хотя бы одной жизни и точном
; BattleState=$80. Положительный destruction countdown, ноль и любые другие
; значения возвращают во frontend. Сложение жизней восьмибитное: ромхак не
; должен позволять Player1Lives+Player2Lives обернуться в 0.
; HandleSecretContinueChord независимо от chord хвостом идёт в SelectStage;
; комбинация влияет только на восстановление выбывшего партнёра и режим двух игроков.
ResolveStageOutcome:
LC265:  lda     Player1Lives
        clc
        adc     Player2Lives
        beq     ReturnToTitleAfterStage
        lda     BattleState
        cmp     #BattleStateActive
        bne     ReturnToTitleAfterStage
        jmp     HandleSecretContinueChord

; Статически неиспользуемый альтернативный continuation: ожидает A=Player1Lives,
; складывает с Player2Lives по модулю 256 и при точном BattleState=$80 хвостом
; переходит в SelectStage без проверки secret chord. Иначе проваливается ниже.
UnusedContinueTail:
LC275:  clc
        adc     Player2Lives
        beq     ReturnToTitleAfterStage
        lda     BattleState
        cmp     #BattleStateActive
        bne     ReturnToTitleAfterStage
        jmp     SelectStage
ReturnToTitleAfterStage:
; Очищает экран/audio, затем сравнивает оба score record с HighScore. При Y=0
; сразу перестраивает title; Y=1/$FF показывает экран нового рекорда, после него
; ещё раз очищает nametable и только затем уходит в title continuation.
;
; Важный edge/romhack-контракт: этот путь сам не обнуляет PauseState, тогда как
; ShowNewHighScoreScreen ждёт завершения непаузного audio stream. Если outcome
; может наступить в кадр включения паузы, вызывающая логика должна гарантировать
; PauseState=0, иначе high-score wait не сможет продвинуть нужный поток.
LC283:  jsr     ClearScreenAndAudio
        ; Y=0 означает, что рекорд не изменился; отдельный экран нужен только
        ; после копирования результата одного из игроков в HighScore.
        jsr     UpdateHighScoreRecord
        tya
        beq     RebuildTitleAfterStage
        jsr     ShowNewHighScoreScreen
        jsr     ClearScreenAndResumeNmi
RebuildTitleAfterStage:
LC292:  jmp     RebuildTitleNametable

; Повторная очистка после экрана рекорда. Предусловия: NMI включён,
; NametablePpuOffset указывает нужный 1-KiB PPU-диапазон (штатно $2000), latch
; допускает bulk helper. DisableRenderingForBulkUpdate сначала ждёт NMI, поэтому
; косвенно обслуживает OAM DMA/input/audio и очищает PPU queue. Затем shadow
; обнуляется и напрямую загружается в VRAM.
; Выход: A=EnabledNmiPpuCtrlValue, X=Y=0, ScratchPtr=$0800, NMI включён;
; PPU_MASK остаётся bulk=$06 до следующего NMI. OAM shadow/audio напрямую не
; сбрасываются, NametablePpuOffset/scroll/NametableBits сохраняются.
ClearScreenAndResumeNmi:
LC295:  jsr     DisableRenderingForBulkUpdate
        jsr     ClearNametableBuffer
        jsr     UploadNametableBuffer
        jsr     EnableNmiAfterVblank
        rts

; Фильтр input послебоевого logic tick. Только точный BattleState=$80 оставляет
; четыре Joy-байта без изменений; любое другое значение обнуляет held/pressed
; обоих контроллеров. Выход: X/Y сохраняются; A=$80 либо 0, Z=1/N=0 на обоих
; путях. C=1 на active и на неравных значениях >=$80, иначе C=0; V сохраняется.
; PPU/OAM/audio и остальная RAM не меняются.
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
