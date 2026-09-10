; Логика и отрисовка восьми танков: слоты 0-1 принадлежат игрокам, 2-7 —
; противникам. Старшая тетрада ObjectState выбирает класс логики/отрисовки,
; биты 1..0 активных состояний задают направление 0=up, 1=left, 2=down, 3=right.

CurrentTankSlot      = $5A
ProposedTankX        = $56
ProposedTankY        = $57
TankProbeXOffset     = $58
TankProbeYOffset     = $59
PlayerDirectionCandidate = $00
LargeTankQuadrantTileBase = $00
; В первой половине процедуры здесь хранится отношение цели по X (0/1/2),
; затем готовый индекс направления 0..8.
TankTargetDirectionIndex = $64
TankTargetYRelation      = $65
; Поддерживает циклический аудиопоток 17, пока хотя бы у одного игрока нажатое
; направление и его ObjectState ненулевой. Класс состояния не проверяется.
; Побочный эффект: PlayerMovementLoopAudioState принимает 0, 1 (запрос)
; или 2 (поток уже запущен).
; Портит A, X; Y не меняет.
UpdatePlayerMovementAudio:
LDB0B:  lda     PlayerMovementLoopAudioState
        beq     StartPlayerMovementAudioIfNeeded
        ldx     #$00
        jsr     IsPlayerTankMoving
        bne     ReturnFromPlayerMovementAudioUpdate
        ldx     #$01
        jsr     IsPlayerTankMoving
        bne     ReturnFromPlayerMovementAudioUpdate
        lda     #AudioStateOff
        sta     PlayerMovementLoopAudioState
        rts

StartPlayerMovementAudioIfNeeded:
LDB24:  ldx     #$00
        jsr     IsPlayerTankMoving
        bne     RequestPlayerMovementAudio
        ldx     #$01
        jsr     IsPlayerTankMoving
        beq     ReturnFromPlayerMovementAudioUpdate
RequestPlayerMovementAudio:
LDB32:  lda     #AudioStateStartRequested
        sta     PlayerMovementLoopAudioState
ReturnFromPlayerMovementAudioUpdate:
LDB37:  rts

; Вход: X=0/1. Возвращает A=1/Z=0, если ObjectState игрока ненулевой и нажато
; направление; иначе A=0/Z=1. X/Y и RAM не меняет.
IsPlayerTankMoving:
LDB38:  lda     Joy1Held,x
        and     #BUTTON_DIRECTIONS
        beq     ReturnPlayerNotMoving
        lda     ObjectState,x
        beq     ReturnPlayerNotMoving
        lda     #$01
        rts

ReturnPlayerNotMoving:
LDB45:  lda     #$00
        rts

; Пытается разместить одного из оставшихся противников ($7F) в свободный слот.
; EnemySpawnTimer — текущая задержка, EnemyActivityInterval — её
; перезагружаемое значение. GameMode=5/7 задаёт последний
; доступный слот для игры одного/двух игроков. При успехе вызывает спавн, уменьшает $7F
; и обновляет экранный счётчик. Портит A, X, CurrentTankSlot и вызываемые процедуры.
SpawnPendingEnemyTank:
LDB48:  lda     EnemySpawnTimer
        beq     TrySpawnPendingEnemy
        dec     EnemySpawnTimer
        rts

TrySpawnPendingEnemy:
LDB4F:  lda     EnemiesToSpawn
        beq     ReturnFromEnemySpawn
        lda     GameMode
        sta     CurrentTankSlot
CheckEnemySpawnSlot:
LDB57:  ldx     CurrentTankSlot
        lda     ObjectState,x
        bne     ScanPreviousEnemySlot
        lda     EnemyActivityInterval
        sta     EnemySpawnTimer
        jsr     SpawnTank
        dec     EnemiesToSpawn
        lda     EnemiesToSpawn
        jsr     ClearRemainingEnemyMarker
        rts

ScanPreviousEnemySlot:
LDB6C:  dec     CurrentTankSlot
        lda     CurrentTankSlot
        cmp     #(FirstEnemyTankSlot-1)
        bne     CheckEnemySpawnSlot
ReturnFromEnemySpawn:
LDB74:  rts

; Преобразует ввод двух игроков в направление и класс $A их ObjectState.
; Кадры FrameCounter mod 4 = 2 пропускаются. Ввод принимается только для активного
; танка с классом $8-$D. При повороте не на 180° X/Y привязываются к сетке 8 px.
; PlayerStunTimer+X и отрицательные значения PlayerIceState+X могут временно запретить ввод.
; Побочные эффекты: ObjectState/ObjectX/ObjectY/ObjectFrame, два таймера игроков,
; PlayerIceState[0..1] и состояние аудиопотока начала скольжения.
; Портит A, X, PlayerDirectionCandidate.
UpdatePlayerTankInput:
LDB75:  lda     FrameCounter
        and     #$01
        bne     ProcessPlayerTankInput
        lda     FrameCounter
        and     #$03
        bne     NoOpHandler
ProcessPlayerTankInput:
LDB81:  ldx     #(PlayerTankCount-1)
UpdatePlayerInputForSlot:
LDB83:  lda     ObjectState,x
        bpl     AdvanceToPreviousPlayer
        cmp     #NonTargetableTankStateMin
        bcs     AdvanceToPreviousPlayer
        lda     PlayerStunTimer,x
        beq     ReadPlayerDirection
        dec     PlayerStunTimer,x
        jmp     SetPlayerTankIdleState

ReadPlayerDirection:
LDB94:  lda     PlayerIceState,x
        bpl     DecodePlayerDirectionButtons
        and     #PlayerIceInputLockFlag
        bne     SetPlayerTankIdleState
DecodePlayerDirectionButtons:
LDB9D:  lda     Joy1Held,x
        jsr     DecodeDirectionButtons
        sta     PlayerDirectionCandidate
        bpl     ApplyPlayerDirection
; Без принятого направления переводит танк в класс $8 с флагом бита 3.
SetPlayerTankIdleState:
LDBA6:  lda     #$80
        jsr     SetTankStateClass
        lda     #$08
        ora     ObjectState,x
        sta     ObjectState,x
        jmp     AdvanceToPreviousPlayer

ApplyPlayerDirection:
LDBB4:  lda     PlayerIceState,x
        bpl     AlignPlayerTankForTurn
        and     #$1F
        bne     AlignPlayerTankForTurn
        lda     #PlayerIceReloadValue
        sta     PlayerIceState,x
        lda     #AudioStateStartRequested
        sta     IceSlideStartAudioState
; Перекрёстный поворот выравнивает танк по сетке; разворот на 180° не выравнивает.
AlignPlayerTankForTurn:
LDBC7:  lda     ObjectState,x
        and     #DirectionMask
        cmp     PlayerDirectionCandidate
        beq     CommitPlayerTankDirection
        eor     #$02
        cmp     PlayerDirectionCandidate
        beq     CommitPlayerTankDirection
        lda     ObjectX,x
        clc
        adc     #$04
        and     #$F8
        sta     ObjectX,x
        lda     ObjectY,x
        clc
        adc     #$04
        and     #$F8
        sta     ObjectY,x
CommitPlayerTankDirection:
LDBE7:  lda     PlayerDirectionCandidate
        ora     #$A0
        sta     ObjectState,x
AdvanceToPreviousPlayer:
LDBED:  dex
        bpl     UpdatePlayerInputForSlot
NoOpHandler:
TankLogicState0:
TankDrawState0:
ProjectileLogicState0:
ProjectileDrawState0:
LDBF0:  rts

; Обновляет восемь танков в обратном порядке. Расписание пропускает часть объектов
; по чётности FrameCounter/слота; танки игроков обслуживаются по отдельному ритму.
; EnemyFreezeTimer
; уменьшается раз в 64 кадра. Побочные эффекты зависят от обработчика состояния;
; всегда меняет CurrentTankSlot и портит A, X, Y, ScratchPtrLo/Hi.
UpdateTanks:
LDBF1:  lda     #(TankSlotCount-1)
        sta     CurrentTankSlot
        lda     EnemyFreezeTimer
        beq     UpdateNextTank
        lda     FrameCounter
        and     #$3F
        bne     UpdateNextTank
        dec     EnemyFreezeTimer
UpdateNextTank:
LDC03:  ldx     CurrentTankSlot
        cpx     #FirstEnemyTankSlot
        bcs     CheckEnemyTankSchedule
        lda     FrameCounter
        and     #$01
        bne     RunTankLogicForSlot
        lda     FrameCounter
        and     #$03
        bne     SkipTankLogicForSlot
        jmp     RunTankLogicForSlot

CheckEnemyTankSchedule:
LDC18:  lda     EnemyFreezeTimer
        beq     ApplyTankUpdateSchedule
        lda     ObjectState,x
        bpl     ApplyTankUpdateSchedule
        cmp     #NonTargetableTankStateMin
        bcc     SkipTankLogicForSlot
ApplyTankUpdateSchedule:
LDC25:  lda     ObjectAttributes,x
        and     #$F0
        cmp     #$A0
        beq     RunTankLogicForSlot
        lda     CurrentTankSlot
        eor     FrameCounter
        and     #$01
        beq     SkipTankLogicForSlot
RunTankLogicForSlot:
LDC35:  jsr     DispatchTankLogic
SkipTankLogicForSlot:
LDC38:  dec     CurrentTankSlot
        bpl     UpdateNextTank
        rts

; Старшая тетрада ObjectState,X выбирает обработчик логики танка из TankLogicHandlers.
; Вход: X=слот 0..7. Не возвращается сам: переходит к обработчику. Портит A, Y,
; ScratchPtrLo/Hi; контракт X и побочные эффекты зависят от выбранного состояния.
DispatchTankLogic:
LDC3D:  lda     ObjectState,x
        lsr     a
        lsr     a
        lsr     a
        and     #$FE
        tay
        lda     TankLogicHandlers,y
        sta     ScratchPtrLo
        lda     TankLogicHandlers+1,y
        sta     ScratchPtrHi
        jmp     (ScratchPtrLo)

; Класс $8: промежуточное/недвижное состояние. PlayerIceState+X может продлить его для
; игрока; иначе биты 3..2 уменьшаются по $04 до перехода в класс $A. Вход:
; X=слот танка. Меняет ObjectState, а при скольжении также PlayerIceState и
; ObjectFrame; портит A, X/Y сохраняет.
TankLogicState8:
        cpx     #FirstEnemyTankSlot
        bcs     AdvanceTankIdlePhase
        lda     PlayerIceState,x
        bpl     AdvanceTankIdlePhase
        and     #PlayerIceInactiveMask
        beq     AdvanceTankIdlePhase
        dec     PlayerIceState,x
        lda     ObjectFrame,x
        eor     #$04
        sta     ObjectFrame,x
        jmp     AdvanceTankMovement

AdvanceTankIdlePhase:
LDC6B:  lda     ObjectState,x
        sec
        sbc     #$04
        sta     ObjectState,x
        and     #$0C
        bne     ReturnFromTankIdlePhase
        lda     #$A0
        jsr     SetTankStateClass
ReturnFromTankIdlePhase:
LDC7B:  rts

; Класс $A: движение на 1 px по направлению. Противник в узле сетки с вероятностью
; 1/16 выбирает новый режим навигации. Две точки на передней границе танка проверяются
; по NametableShadow. При успехе меняются ObjectX/Y и ObjectFrame; при столкновении противник
; может перейти в $8/$9 или сменить направление. Портит A, X, Y,
; ProposedTankX/ProposedTankY, TankProbeXOffset/TankProbeYOffset и ScratchPtrLo/Hi.
TankLogicStateA:
        cpx     #FirstEnemyTankSlot
        bcc     AdvanceTankMovement
        lda     ObjectX,x
        and     #$07
        bne     AdvanceTankMovement
        lda     ObjectY,x
        and     #$07
        bne     AdvanceTankMovement
        jsr     NextRandomByte
        and     #$0F
        bne     AdvanceTankMovement
        jsr     ChooseEnemyTankAiMode
        rts

AdvanceTankMovement:
LDC97:  lda     ObjectState,x
        and     #DirectionMask
        tay
        lda     DirectionDeltaY,y
        asl     a
        asl     a
        asl     a
        sta     TankProbeYOffset
        lda     DirectionDeltaY,y
        clc
        adc     ObjectY,x
        sta     ProposedTankY
        lda     DirectionDeltaX,y
        asl     a
        asl     a
        asl     a
        sta     TankProbeXOffset
        lda     DirectionDeltaX,y
        clc
        adc     ObjectX,x
        sta     ProposedTankX
        clc
        adc     TankProbeXOffset
        clc
        adc     TankProbeYOffset
        jsr     ClampFirstTankProbeX
        tax
        lda     ProposedTankY
        clc
        adc     TankProbeXOffset
        clc
        adc     TankProbeYOffset
        jsr     ClampFirstTankProbeY
        tay
        jsr     PixelCoordinatesToShadowPointer
        lda     (ScratchPtrLo),y
        bmi     HandleBlockedTankMovement
        beq     ProbeSecondTankCorner
        jmp     RouteFirstTerrainProbe

        .byte   $EA
ProbeSecondTankCorner:
; Вход: CurrentTankSlot и ProposedTankX/Y задают перемещение, TankProbeX/YOffset —
; переднюю грань танка. Проверяет второй её угол через NametableShadow.
; Пустой terrain передаёт управление CommitProposedTankMovement, блокирующий —
; HandleBlockedTankMovement, прочий — RouteSecondTerrainProbe.
; Не возвращается самостоятельно; портит A/X/Y и ScratchPtrLo/Hi.
LDCDF:  lda     ProposedTankX
        clc
        adc     TankProbeXOffset
        sec
        sbc     TankProbeYOffset
        jsr     ClampFirstTankProbeX
        tax
        lda     ProposedTankY
        clc
        adc     TankProbeYOffset
        sec
        sbc     TankProbeXOffset
        jsr     ClampFirstTankProbeY
        tay
        jsr     PixelCoordinatesToShadowPointer
        lda     (ScratchPtrLo),y
        bmi     HandleBlockedTankMovement
        beq     CommitProposedTankMovement
        jmp     RouteSecondTerrainProbe

        .byte   $EA
CommitProposedTankMovement:
; Фиксирует предложенные координаты для CurrentTankSlot и переключает bit2
; ObjectFrame как фазу гусениц. Выход: X=CurrentTankSlot, A=новый ObjectFrame,X;
; Y сохраняется. Меняет ObjectX/Y и ObjectFrame текущего танка.
LDD04:  ldx     CurrentTankSlot
        lda     ProposedTankX
        sta     ObjectX,x
        lda     ProposedTankY
        sta     ObjectY,x
        jmp     ToggleTankAnimationFrame

HandleBlockedTankMovement:
; Отменяет предложенное перемещение. Для игрока только переключает фазу гусениц.
; Противник с вероятностью 1/4 разворачивается через ReverseEnemyTankDirection;
; иначе переводится в класс $8 с установленным bit3 и переключает ObjectFrame.
; Игрок сразу переключает ObjectFrame. Выход зависит от выбранного хвоста;
; X=CurrentTankSlot, Y сохраняется. Портит A, флаги и RNG; ObjectX/Y не меняются.
LDD11:  ldx     CurrentTankSlot
        cpx     #FirstEnemyTankSlot
        bcc     ToggleTankAnimationFrame
        jsr     NextRandomByte
        and     #$03
        beq     ReverseEnemyTankDirection
        lda     #$80
        jsr     SetTankStateClass
        lda     #$08
        ora     ObjectState,x
        sta     ObjectState,x
ToggleTankAnimationFrame:
LDD29:  lda     ObjectFrame,x
        eor     #$04
        sta     ObjectFrame,x
        rts

; При столкновении на узле 8x8 переводит противника в класс $9, затем разворачивает
; направление на 180 градусов. Вне узла меняется только направление. Вход:
; X=слот противника. Выход: A=новый ObjectState,X; X/Y и прочую RAM сохраняет.
ReverseEnemyTankDirection:
LDD30:  lda     ObjectX,x
        and     #$07
        bne     CommitReversedEnemyDirection
        lda     ObjectY,x
        and     #$07
        bne     CommitReversedEnemyDirection
        lda     #$90
        jsr     SetTankStateClass
CommitReversedEnemyDirection:
LDD41:  lda     ObjectState,x
        eor     #$02
        sta     ObjectState,x
        rts

; Класс $9 выбирает новое направление: половина вызовов переходит к более крупному
; AI-решению, остальные случайно поворачивают на соседнее направление. Вход:
; X=слот противника. Меняет ObjectState,X и RNG; портит A, Y может быть изменён
; целевым AI-путём, X сохраняется.
TankLogicState9:
        jsr     NextRandomByte
        and     #$01
        beq     ChooseAiDirectionForState9
        jsr     NextRandomByte
        and     #$01
        beq     TurnEnemyCounterclockwise
        lda     ObjectState,x
        clc
        adc     #$01
        jmp     CommitRandomEnemyTurn

TurnEnemyCounterclockwise:
LDD5E:  lda     ObjectState,x
        sec
        sbc     #$01
CommitRandomEnemyTurn:
LDD63:  and     #DirectionMask
        ora     #$A0
        sta     ObjectState,x
        rts

ChooseAiDirectionForState9:
LDD6A:  jsr     ChooseEnemyTankAiMode
        rts

; Корректирует координату точки переднего края, не позволяя ей совпасть с базовой
; предложенной координатой или перейти через неё. Вход: A=проверяемая X; выход:
; A либо неизменён, либо уменьшен на 1. X/Y и RAM сохраняет.
ClampFirstTankProbeX:
LDD6E:  cmp     ProposedTankX
        bcc     ReturnClampedTankProbeX
        sec
        sbc     #$01
ReturnClampedTankProbeX:
LDD75:  rts

ClampFirstTankProbeY:
; Аналог ClampFirstTankProbeX для A=проверяемой Y и ProposedTankY.
LDD76:  cmp     ProposedTankY
        bcc     ReturnClampedTankProbeY
        sec
        sbc     #$01
ReturnClampedTankProbeY:
LDD7D:  rts

; Классы $B-$D выбирают цель и сразу сводятся к классу $A с направлением из
; TankAiDirectionStateTable. $D целится в игрока 1 (слот 0), $C — в игрока 2
; (слот 1), $B — в базу в точке ($78,$D8). Портят A/Y, TankTargetX/Y и рабочие
; поля выбора направления; X сохраняется.
TankLogicStateD:
        lda     ObjectX
        sta     TankTargetX
        lda     ObjectY
        sta     TankTargetY
        jmp     ChooseDirectionTowardSelectedTarget

TankLogicStateC:
        lda     ObjectX+1
        sta     TankTargetX
        lda     ObjectY+1
        sta     TankTargetY
        jmp     ChooseDirectionTowardSelectedTarget

TankLogicStateB:
        lda     #$78
        sta     TankTargetX
        lda     #$D8
        sta     TankTargetY
ChooseDirectionTowardSelectedTarget:
LDD9C:  jsr     ChooseTankStateTowardTarget
        sta     ObjectState,x
        rts

; Выбирает направление к TankTargetX/Y. Знаки разностей X/Y кодируются значениями
; 0..2, образуют индекс 0..8, а альтернативная половина таблицы используется по
; кадровому/случайному условию. Выход: A — готовое состояние из
; TankAiDirectionStateTable. Портит A/Y, TankTargetDirectionIndex и
; TankTargetYRelation; для противника также RNG. X сохраняет.
ChooseTankStateTowardTarget:
LDDA2:  lda     TankTargetX
        sec
        sbc     ObjectX,x
        jsr     NormalizeSubtractionSign
        clc
        adc     #$01
        sta     TankTargetDirectionIndex
        lda     TankTargetY
        sec
        sbc     ObjectY,x
        jsr     NormalizeSubtractionSign
        clc
        adc     #$01
        sta     TankTargetYRelation
        asl     a
        clc
        adc     TankTargetYRelation
        clc
        adc     TankTargetDirectionIndex
        sta     TankTargetDirectionIndex
        cpx     #FirstEnemyTankSlot
        bcs     ChooseRandomEnemyAxisPriority
        txa
        asl     a
        eor     SlowFrameCounter
        and     #$02
        beq     UsePrimaryTargetDirection
        jmp     UseAlternateTargetDirection

ChooseRandomEnemyAxisPriority:
LDDD4:  jsr     NextRandomByte
        and     #$01
        beq     UsePrimaryTargetDirection
UseAlternateTargetDirection:
LDDDB:  lda     #$09
        clc
        adc     TankTargetDirectionIndex
        tay
        jmp     LoadTargetDirectionState

UsePrimaryTargetDirection:
LDDE4:  ldy     TankTargetDirectionIndex
LoadTargetDirectionState:
LDDE6:  lda     TankAiDirectionStateTable,y
        rts

; Классы $1-$7 -- обратный фазовый отсчёт. Класс уменьшается, когда младшая
; тетрада после DEC достигает нуля; после $2 следует промежуточная фаза $16,
; остальные получают младшую фазу 3.
; Завершение класса $1 удаляет объект: у игрока списывается жизнь и при наличии запаса
; запускается возрождение, у противника уменьшается EnemiesRemaining. Вход:
; X=слот танка. Меняет ObjectState и при завершении — число жизней/противников;
; SpawnTank может изменить дополнительные поля. Портит A, X/Y сохраняются без спавна.
TankLogicStates1To7:
        dec     ObjectState,x
        lda     ObjectState,x
        and     #$0F
        bne     ReturnFromTankDestructionUpdate
        lda     ObjectState,x
        sec
        sbc     #$10
        beq     FinishTankDestruction
        cmp     #$10
        bne     SetDefaultDestructionPhase
        ora     #$06
        jmp     CommitNextDestructionPhase

SetDefaultDestructionPhase:
LDE02:  ora     #$03
CommitNextDestructionPhase:
LDE04:  sta     ObjectState,x
        rts

FinishTankDestruction:
LDE07:  sta     ObjectState,x
        cpx     #FirstEnemyTankSlot
        bcs     RemoveDestroyedEnemy
        dec     Player1Lives,x
        beq     PrepareSurvivingPlayerTransition
        jsr     SpawnTank
        rts

RemoveDestroyedEnemy:
LDE15:  dec     EnemiesRemaining
        rts

; Если в специальном состоянии $68=$80 один игрок окончательно выбыл, но партнёр жив,
; готовит TransitionObjectX..TransitionObjectTimer для переходной анимации.
; Смысл кодов $01/$03 и
; координат $20/$C0 следует из поведения, их пользовательское название не закреплено.
PrepareSurvivingPlayerTransition:
LDE18:  lda     BattleState
        cmp     #BattleStateActive
        bne     ReturnFromTankDestructionUpdate
        cpx     #$01
        beq     PreparePlayerTwoTransition
        lda     Player2Lives
        beq     ReturnFromTankDestructionUpdate
        lda     #$03
        sta     TransitionObjectDirection
        lda     #$20
        sta     TransitionObjectX
        jsr     InitializePlayerTransitionRecord
        rts

PreparePlayerTwoTransition:
LDE34:  lda     Player1Lives
        beq     ReturnFromTankDestructionUpdate
        lda     #$01
        sta     TransitionObjectDirection
        lda     #$C0
        sta     TransitionObjectX
        jsr     InitializePlayerTransitionRecord
ReturnFromTankDestructionUpdate:
LDE45:  rts

InitializePlayerTransitionRecord:
; Завершает создание переходного объекта: timer=13, Y=$D8 и FrameCounter=0.
; Выход: A=0; X/Y сохраняет. Меняет только перечисленные поля.
LDE46:  lda     #$0D
        sta     TransitionObjectTimer
        lda     #$D8
        sta     TransitionObjectY
        lda     #$00
        sta     FrameCounter
        rts

; Класс $F проигрывает возрастающий 14-фазный переход и становится классом $E.
; Вход: X=слот. Меняет ObjectState,X; выход A — младшая фаза либо $E0,
; X/Y и остальную RAM сохраняет.
TankLogicStateF:
        inc     ObjectState,x
        lda     ObjectState,x
        and     #$0F
        cmp     #$0E
        bne     ReturnFromTankLogicStateF
        lda     #$E0
        sta     ObjectState,x
ReturnFromTankLogicStateF:
LDE63:  rts

; Класс $E проигрывает возрастающий 14-фазный переход, затем инициализирует танк.
; Вход: X=слот. До последней фазы меняет только ObjectState,X и сохраняет X/Y;
; InitializeTankState на последней фазе меняет остальные поля танка.
TankLogicStateE:
        inc     ObjectState,x
        lda     ObjectState,x
        and     #$0F
        cmp     #$0E
        bne     ReturnFromTankLogicStateE
        jsr     InitializeTankState
ReturnFromTankLogicStateE:
LDE71:  rts

; Выбирает следующий AI-класс. Сравнения EnemyActivityInterval с
; SlowFrameCounter
; переключают между случайным направлением класса $A и целевыми классами $B-$D.
; Вход: X — слот противника. Если игрок 1 неактивен, выбирает цель игрока 2;
; иначе чётные слоты целятся в игрока 1, а нечётные — в живого игрока 2.
; Выход: ObjectState,X изменён, A содержит записанный класс. Портит A и RNG;
; X/Y сохраняет.
ChooseEnemyTankAiMode:
LDE72:  lda     EnemyActivityInterval
        lsr     a
        lsr     a
        cmp     SlowFrameCounter
        bcs     MaybeChooseRandomEnemyDirection
        lda     #$B0
        jmp     CommitEnemyAiClass

MaybeChooseRandomEnemyDirection:
LDE7F:  lsr     a
        cmp     SlowFrameCounter
        bcc     ChooseEnemyPlayerTarget
        jsr     NextRandomByte
        and     #DirectionMask
        ora     #$A0
        sta     ObjectState,x
        rts

ChooseEnemyPlayerTarget:
LDE8E:  lda     ObjectState
        beq     TargetSecondPlayer
        txa
        and     #$01
        beq     TargetFirstPlayer
        lda     ObjectState+1
        beq     TargetFirstPlayer
TargetSecondPlayer:
LDE9B:  lda     #$C0
        jmp     CommitEnemyAiClass

TargetFirstPlayer:
LDEA0:  lda     #$D0
CommitEnemyAiClass:
LDEA2:  jsr     SetTankStateClass
        rts

; Рисует восемь танков через отдельную таблицу состояний отображения.
; Портит A/X/Y, CurrentTankSlot, ScratchPtr и рабочие поля OAM-процедур.
DrawTanks:
LDEA6:  lda     #$00
        sta     CurrentTankSlot
DrawNextTank:
LDEAA:  ldx     CurrentTankSlot
        jsr     DispatchTankDraw
        inc     CurrentTankSlot
        lda     CurrentTankSlot
        cmp     #TankSlotCount
        bne     DrawNextTank
        rts

; Старшая тетрада ObjectState,X выбирает обработчик из TankDrawHandlers.
; Не возвращается самостоятельно; контракт определяется обработчиком.
DispatchTankDraw:
LDEB8:  lda     ObjectState,x
        lsr     a
        lsr     a
        lsr     a
        and     #$FE
        tay
        lda     TankDrawHandlers,y
        sta     ScratchPtrLo
        lda     TankDrawHandlers+1,y
        sta     ScratchPtrHi
        jmp     (ScratchPtrLo)

; Классы $5-$7: двухспрайтовая фазовая анимация с палитрой 3. На время вывода
; отключает SpriteBehindTerrainMask и восстанавливает его в $20 после вызова.
DrawTankStates5To7:
        lda     #$00
        sta     SpriteBehindTerrainMask
        lda     ObjectState,x
        pha
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        pla
        jsr     ComputeAndDrawTankTransitionFrame
        lda     #$20
        sta     SpriteBehindTerrainMask
        rts

ComputeAndDrawTankTransitionFrame:
; Вход: A — ObjectState класса $5-$7, X/Y — экранные координаты пары спрайтов.
; Преобразует класс в tile $F9/$F5/$F1, задаёт RenderAttributes=3 и выводит
; пару через EmitTwoTileOamPair. Портит A/X/Y, OamTile, RenderAttributes,
; OAM cursor/shadow и scratch-поля EmitTwoTileOamPair.
LDEE2:  lsr     a
        lsr     a
        lsr     a
        lsr     a
        sec
        sbc     #$07
        eor     #$FF
        clc
        adc     #$01
        asl     a
        asl     a
; Альтернативный вход: A уже содержит смещение кадра относительно tile $F1.
DrawTankTransitionFrameFromOffset:
LDEF0:  clc
        adc     #$F1
        sta     OamTile
        lda     #$03
        sta     RenderAttributes
        jsr     EmitTwoTileOamPair
        rts

; Класс $1: вариант финальной анимации зависит от ObjectAttributes,X; при нуле
; используется первый кадр общей переходной последовательности.
DrawTankState1:
        lda     #$00
        sta     SpriteBehindTerrainMask
        lda     ObjectAttributes,x
        beq     DrawDefaultTankState1Frame
        lda     ObjectAttributes,x
        lsr     a
        lsr     a
        lsr     a
        and     #$FC
        sec
        sbc     #$10
        clc
        adc     #$B9
        sta     OamTile
        lda     #$03
        sta     RenderAttributes
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        jsr     EmitTwoTileOamPair
        jmp     RestoreTankSpritePriority

DrawDefaultTankState1Frame:
LDF23:  lda     ObjectY,x
        tay
        lda     ObjectX,x
        tax
        lda     #$00
        jsr     DrawTankTransitionFrameFromOffset
RestoreTankSpritePriority:
LDF2E:  lda     #$20
        sta     SpriteBehindTerrainMask
        rts

; Класс $2: выводит кадр 8 общей переходной последовательности.
DrawTankState2:
        lda     #$00
        sta     SpriteBehindTerrainMask
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        lda     #$08
        jsr     DrawTankTransitionFrameFromOffset
        lda     #$20
        sta     SpriteBehindTerrainMask
        rts

; Классы $3-$4: выводят четыре двухспрайтовых элемента вокруг центра танка,
; формируя объект 32x32. LDF99 выбирает tile-base по классу и номеру квадранта.
DrawTankStates3To4:
        lda     #$03
        sta     RenderAttributes
        lda     #$00
        sta     SpriteBehindTerrainMask
        jsr     PrepareLargeTankQuadrant
        txa
        sec
        sbc     #$08
        tax
        tya
        sec
        sbc     #$08
        tay
        jsr     EmitTwoTileOamPair
        lda     #$01
        jsr     PrepareLargeTankQuadrant
        txa
        clc
        adc     #$08
        tax
        tya
        sec
        sbc     #$08
        tay
        jsr     EmitTwoTileOamPair
        lda     #$02
        jsr     PrepareLargeTankQuadrant
        txa
        sec
        sbc     #$08
        tax
        tya
        clc
        adc     #$08
        tay
        jsr     EmitTwoTileOamPair
        lda     #$03
        jsr     PrepareLargeTankQuadrant
        txa
        clc
        adc     #$08
        tax
        tya
        clc
        adc     #$08
        tay
        jsr     EmitTwoTileOamPair
        lda     #$20
        sta     SpriteBehindTerrainMask
        rts

PrepareLargeTankQuadrant:
; Вход: A=номер квадранта 0..3, CurrentTankSlot — рисуемый танк класса $3/$4.
; Вычисляет OamTile для квадранта, затем возвращает его координаты одновременно
; как A=X=ObjectX и Y=ObjectY. Меняет LargeTankQuadrantTileBase и OamTile;
; Object/RAM кроме этих scratch-полей не меняет.
LDF99:  ldx     CurrentTankSlot
        asl     a
        asl     a
        clc
        adc     #$D1
        sta     LargeTankQuadrantTileBase
        lda     ObjectState,x
        and     #StateClassMask
        sec
        sbc     #$30
        eor     #$10
        clc
        adc     LargeTankQuadrantTileBase
        sta     OamTile
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        rts

; Классы $8-$D: обычный танк. Палитра игроков равна номеру слота, палитра противника
; анимируется по ObjectAttributes/FrameCounter. Направление выбирает один из четырёх
; кадров, ObjectFrame добавляется к старшей тетраде tile-base.
DrawTankStates8ToD:
        cpx     #FirstEnemyTankSlot
        bcc     DrawPlayerTank
        lda     ObjectAttributes,x
        and     #$04
        beq     SelectEnemyPaletteCycle
        lda     FrameCounter
        lsr     a
        lsr     a
        lsr     a
        and     #$01
        clc
        adc     #$02
        jmp     DrawTankWithSelectedPalette

SelectEnemyPaletteCycle:
LDFCD:  lda     FrameCounter
        asl     a
        asl     a
        clc
        adc     ObjectAttributes,x
        and     #$07
        tay
        lda     LE003,y
        jmp     DrawTankWithSelectedPalette

DrawPlayerTank:
LDFDD:  lda     PlayerStunTimer,x
        beq     UsePlayerTankPalette
        lda     FrameCounter
        and     #$08
        beq     UsePlayerTankPalette
        rts

UsePlayerTankPalette:
LDFE8:  txa
DrawTankWithSelectedPalette:
LDFE9:  sta     RenderAttributes
        lda     ObjectState,x
        and     #DirectionMask
        pha
        lda     ObjectAttributes,x
        and     #$F0
        clc
        adc     ObjectFrame,x
        sta     OamTile
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        pla
        jsr     EmitTwoTileOamObject
        rts

EnemyTankPaletteCycle:
LE003:  .byte   $02,$00,$00,$01,$02,$01,$02,$02
; Классы $E-$F: симметричная переходная анимация вокруг фазы 7.
DrawTankStatesEToF:
LE00B:  lda     ObjectState,x
        and     #$0F
        sec
        sbc     #$07
        bpl     ConvertTankTransitionPhaseToTile
        eor     #$FF
        clc
        adc     #$01
ConvertTankTransitionPhaseToTile:
LE019:  asl     a
        and     #$FC
        clc
        adc     #$A1
        sta     OamTile
        lda     #$03
        sta     RenderAttributes
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        jsr     EmitTwoTileOamPair
        rts

; Обновляет десять снарядов, по одному слоту на танк/источник.
