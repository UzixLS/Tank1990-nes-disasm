; Логика и отрисовка восьми танков: слоты 0-1 принадлежат игрокам, 2-7 —
; противникам. Старшая тетрада ObjectState выбирает класс логики/отрисовки,
; биты 1..0 активных состояний задают направление 0=up, 1=left, 2=down, 3=right.

TankSlotCount        = $08
PlayerTankCount      = $02
FirstEnemyTankSlot   = $02
CurrentTankSlot      = $5A
ProposedTankX        = $56
ProposedTankY        = $57
TankProbeXOffset     = $58
TankProbeYOffset     = $59
TankTargetX          = $71
TankTargetY          = $72
PlayerMoveAudioFlag  = $0311

; Поддерживает циклический аудиопоток 17, пока хотя бы у одного игрока нажатое
; направление и его ObjectState ненулевой. Класс состояния не проверяется.
; Побочный эффект: PlayerMoveAudioFlag=0/1.
; Портит A, X; Y не меняет.
UpdatePlayerMovementAudio:
LDB0B:  lda     PlayerMoveAudioFlag
        beq     LDB24
        ldx     #$00
        jsr     IsPlayerTankMoving
        bne     LDB37
        ldx     #$01
        jsr     IsPlayerTankMoving
        bne     LDB37
        lda     #$00
        sta     PlayerMoveAudioFlag
        rts

StartPlayerMovementAudioIfNeeded:
LDB24:  ldx     #$00
        jsr     IsPlayerTankMoving
        bne     LDB32
        ldx     #$01
        jsr     IsPlayerTankMoving
        beq     LDB37
LDB32:  lda     #$01
        sta     PlayerMoveAudioFlag
LDB37:  rts

; Вход: X=0/1. Возвращает A=1/Z=0, если ObjectState игрока ненулевой и нажато
; направление; иначе A=0/Z=1. X/Y и RAM не меняет.
IsPlayerTankMoving:
LDB38:  lda     Joy1Held,x
        and     #BUTTON_DIRECTIONS
        beq     LDB45
        lda     ObjectState,x
        beq     LDB45
        lda     #$01
        rts

LDB45:  lda     #$00
        rts

; Пытается разместить одного из оставшихся противников ($7F) в свободный слот.
; $82 — текущая задержка, $84 — её перезагружаемое значение. GameMode=5/7 задаёт последний
; доступный слот для игры одного/двух игроков. При успехе вызывает спавн, уменьшает $7F
; и обновляет экранный счётчик. Портит A, X, CurrentTankSlot и вызываемые процедуры.
SpawnPendingEnemyTank:
LDB48:  lda     $82
        beq     LDB4F
        dec     $82
        rts

LDB4F:  lda     $7F
        beq     LDB74
        lda     GameMode
        sta     CurrentTankSlot
LDB57:  ldx     $5A
        lda     ObjectState,x
        bne     LDB6C
        lda     $84
        sta     $82
        jsr     SpawnTank
        dec     $7F
        lda     $7F
        jsr     ClearRemainingEnemyMarker
        rts

ScanPreviousEnemySlot:
LDB6C:  dec     CurrentTankSlot
        lda     CurrentTankSlot
        cmp     #(FirstEnemyTankSlot-1)
        bne     LDB57
LDB74:  rts

; Преобразует ввод двух игроков в направление и класс $A их ObjectState.
; Кадры FrameCounter mod 4 = 2 пропускаются. Ввод принимается только для активного
; танка с классом $8-$D. При повороте не на 180° X/Y привязываются к сетке 8 px.
; $6F+X и отрицательные значения $0103+X могут временно запретить ввод. Побочные эффекты:
; ObjectState/ObjectX/ObjectY/ObjectFrame, $6F-$70, $0103-$0104 и аудиофлаг $0310. Портит A, X, $00.
UpdatePlayerTankInput:
LDB75:  lda     FrameCounter
        and     #$01
        bne     LDB81
        lda     FrameCounter
        and     #$03
        bne     LDBF0
ProcessPlayerTankInput:
LDB81:  ldx     #(PlayerTankCount-1)
LDB83:  lda     ObjectState,x
        bpl     LDBED
        cmp     #$E0
        bcs     LDBED
        lda     $6F,x
        beq     LDB94
        dec     $6F,x
        jmp     LDBA6

ReadPlayerDirection:
LDB94:  lda     $0103,x
        bpl     LDB9D
        and     #$10
        bne     LDBA6
LDB9D:  lda     Joy1Held,x
        jsr     DecodeDirectionButtons
        sta     $00
        bpl     LDBB4
; Без принятого направления переводит танк в класс $8 с флагом бита 3.
SetPlayerTankIdleState:
LDBA6:  lda     #$80
        jsr     SetTankStateClass
        lda     #$08
        ora     ObjectState,x
        sta     ObjectState,x
        jmp     LDBED

ApplyPlayerDirection:
LDBB4:  lda     $0103,x
        bpl     LDBC7
        and     #$1F
        bne     LDBC7
        lda     #$9C
        sta     $0103,x
        lda     #$01
        sta     $0310
; Перекрёстный поворот выравнивает танк по сетке; разворот на 180° не выравнивает.
AlignPlayerTankForTurn:
LDBC7:  lda     ObjectState,x
        and     #$03
        cmp     $00
        beq     LDBE7
        eor     #$02
        cmp     $00
        beq     LDBE7
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
LDBE7:  lda     $00
        ora     #$A0
        sta     ObjectState,x
LDBED:  dex
        bpl     LDB83
NoOpHandler:
TankLogicState0:
TankDrawState0:
ProjectileLogicState0:
ProjectileDrawState0:
LDBF0:  rts

; Обновляет восемь танков в обратном порядке. Расписание пропускает часть объектов
; по чётности FrameCounter/слота; танки игроков обслуживаются по отдельному ритму. $0100
; уменьшается раз в 64 кадра. Побочные эффекты зависят от обработчика состояния;
; всегда меняет CurrentTankSlot и портит A, X, Y, ScratchPtrLo/Hi.
UpdateTanks:
LDBF1:  lda     #(TankSlotCount-1)
        sta     CurrentTankSlot
        lda     $0100
        beq     LDC03
        lda     FrameCounter
        and     #$3F
        bne     LDC03
        dec     $0100
UpdateNextTank:
LDC03:  ldx     CurrentTankSlot
        cpx     #FirstEnemyTankSlot
        bcs     LDC18
        lda     FrameCounter
        and     #$01
        bne     LDC35
        lda     FrameCounter
        and     #$03
        bne     LDC38
        jmp     LDC35

LDC18:  lda     $0100
        beq     LDC25
        lda     ObjectState,x
        bpl     LDC25
        cmp     #$E0
        bcc     LDC38
LDC25:  lda     ObjectAttributes,x
        and     #$F0
        cmp     #$A0
        beq     LDC35
        lda     CurrentTankSlot
        eor     FrameCounter
        and     #$01
        beq     LDC38
RunTankLogicForSlot:
LDC35:  jsr     DispatchTankLogic
SkipTankLogicForSlot:
LDC38:  dec     CurrentTankSlot
        bpl     LDC03
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

; Класс $8: промежуточное/недвижное состояние. Поле $0103+X может продлить его для
; игрока; иначе биты 3..2 уменьшаются по $04 до перехода в класс $A.
TankLogicState8:
        cpx     #$02
        bcs     LDC6B
        lda     $0103,x
        bpl     LDC6B
        and     #$7F
        beq     LDC6B
        dec     $0103,x
        lda     ObjectFrame,x
        eor     #$04
        sta     ObjectFrame,x
        jmp     LDC97

AdvanceTankIdlePhase:
LDC6B:  lda     ObjectState,x
        sec
        sbc     #$04
        sta     ObjectState,x
        and     #$0C
        bne     LDC7B
        lda     #$A0
        jsr     SetTankStateClass
LDC7B:  rts

; Класс $A: движение на 1 px по направлению. Противник в узле сетки с вероятностью
; 1/16 выбирает новый режим навигации. Две точки на передней границе танка проверяются
; по NametableShadow. При успехе меняются ObjectX/Y и ObjectFrame; при столкновении противник
; может перейти в $8/$9 или сменить направление. Портит A, X, Y, $56-$59, ScratchPtrLo/Hi.
TankLogicStateA:
        cpx     #$02
        bcc     LDC97
        lda     ObjectX,x
        and     #$07
        bne     LDC97
        lda     ObjectY,x
        and     #$07
        bne     LDC97
        jsr     NextRandomByte
        and     #$0F
        bne     LDC97
        jsr     ChooseEnemyTankAiMode
        rts

LDC97:  lda     ObjectState,x
        and     #$03
        tay
        lda     DirectionDeltaY,y
        asl     a
        asl     a
        asl     a
        sta     $59
        lda     DirectionDeltaY,y
        clc
        adc     ObjectY,x
        sta     $57
        lda     DirectionDeltaX,y
        asl     a
        asl     a
        asl     a
        sta     $58
        lda     DirectionDeltaX,y
        clc
        adc     ObjectX,x
        sta     $56
        clc
        adc     $58
        clc
        adc     $59
        jsr     ClampFirstTankProbeX
        tax
        lda     $57
        clc
        adc     $58
        clc
        adc     $59
        jsr     ClampFirstTankProbeY
        tay
        jsr     PixelCoordinatesToShadowPointer
        lda     (ScratchPtrLo),y
        bmi     LDD11
        beq     LDCDF
        jmp     RouteFirstTerrainProbe

        .byte   $EA
ProbeSecondTankCorner:
LDCDF:  lda     $56
        clc
        adc     $58
        sec
        sbc     $59
        jsr     ClampFirstTankProbeX
        tax
        lda     $57
        clc
        adc     $59
        sec
        sbc     $58
        jsr     ClampFirstTankProbeY
        tay
        jsr     PixelCoordinatesToShadowPointer
        lda     (ScratchPtrLo),y
        bmi     LDD11
        beq     LDD04
        jmp     RouteSecondTerrainProbe

        .byte   $EA
CommitProposedTankMovement:
LDD04:  ldx     $5A
        lda     $56
        sta     ObjectX,x
        lda     $57
        sta     ObjectY,x
        jmp     LDD29

HandleBlockedTankMovement:
LDD11:  ldx     $5A
        cpx     #$02
        bcc     LDD29
        jsr     NextRandomByte
        and     #$03
        beq     LDD30
        lda     #$80
        jsr     SetTankStateClass
        lda     #$08
        ora     ObjectState,x
        sta     ObjectState,x
LDD29:  lda     ObjectFrame,x
        eor     #$04
        sta     ObjectFrame,x
        rts

; При столкновении на узле 8x8 переводит противника в класс $9, затем разворачивает
; направление на 180 градусов. Вне узла меняется только направление.
ReverseEnemyTankDirection:
LDD30:  lda     ObjectX,x
        and     #$07
        bne     LDD41
        lda     ObjectY,x
        and     #$07
        bne     LDD41
        lda     #$90
        jsr     SetTankStateClass
LDD41:  lda     ObjectState,x
        eor     #$02
        sta     ObjectState,x
        rts

; Класс $9 выбирает новое направление: половина вызовов переходит к более крупному
; AI-решению, остальные случайно поворачивают на соседнее направление.
TankLogicState9:
        jsr     NextRandomByte
        and     #$01
        beq     LDD6A
        jsr     NextRandomByte
        and     #$01
        beq     LDD5E
        lda     ObjectState,x
        clc
        adc     #$01
        jmp     LDD63

LDD5E:  lda     ObjectState,x
        sec
        sbc     #$01
LDD63:  and     #$03
        ora     #$A0
        sta     ObjectState,x
        rts

LDD6A:  jsr     ChooseEnemyTankAiMode
        rts

; Корректирует координату первой точки переднего края, не позволяя ей пересечь
; предложенную координату движения $56/$57. Эти два входа сохраняют X/Y.
ClampFirstTankProbeX:
LDD6E:  cmp     $56
        bcc     LDD75
        sec
        sbc     #$01
LDD75:  rts

ClampFirstTankProbeY:
LDD76:  cmp     $57
        bcc     LDD7D
        sec
        sbc     #$01
LDD7D:  rts

; Классы $B-$D выбирают фиксированную/динамическую цель и сразу сводятся к классу $A
; с направлением, выбранным таблицей LE486. $D целится в координаты слота 0, $C -- в
; пару $91/$99, $B -- в точку ($78,$D8). Точное игровое назначение $91/$99 не установлено.
TankLogicStateD:
        lda     ObjectX
        sta     $71
        lda     ObjectY
        sta     $72
        jmp     LDD9C

TankLogicStateC:
        lda     $91
        sta     $71
        lda     $99
        sta     $72
        jmp     LDD9C

TankLogicStateB:
        lda     #$78
        sta     $71
        lda     #$D8
        sta     $72
LDD9C:  jsr     ChooseTankStateTowardTarget
        sta     ObjectState,x
        rts

; Выбирает направление к TankTargetX/Y. Знаки разностей X/Y кодируются значениями
; 0..2, образуют индекс 0..8, а альтернативная половина таблицы используется по
; кадровому/случайному условию. Выход: A -- готовое состояние из LE486. Портит A/Y,$64/$65.
ChooseTankStateTowardTarget:
LDDA2:  lda     $71
        sec
        sbc     ObjectX,x
        jsr     NormalizeSubtractionSign
        clc
        adc     #$01
        sta     $64
        lda     $72
        sec
        sbc     ObjectY,x
        jsr     NormalizeSubtractionSign
        clc
        adc     #$01
        sta     $65
        asl     a
        clc
        adc     $65
        clc
        adc     $64
        sta     $64
        cpx     #$02
        bcs     LDDD4
        txa
        asl     a
        eor     $0A
        and     #$02
        beq     LDDE4
        jmp     LDDDB

LDDD4:  jsr     NextRandomByte
        and     #$01
        beq     LDDE4
LDDDB:  lda     #$09
        clc
        adc     $64
        tay
        jmp     LDDE6

LDDE4:  ldy     $64
LDDE6:  lda     LE486,y
        rts

; Классы $1-$7 -- обратный фазовый отсчёт. Класс уменьшается, когда младшая
; тетрада после DEC достигает нуля; после $2 следует промежуточная фаза $16,
; остальные получают младшую фазу 3.
; Завершение класса $1 удаляет объект: у игрока списывается жизнь и при наличии запаса
; запускается возрождение, у противника уменьшается счётчик $80.
TankLogicStates1To7:
        dec     ObjectState,x
        lda     ObjectState,x
        and     #$0F
        bne     LDE45
        lda     ObjectState,x
        sec
        sbc     #$10
        beq     LDE07
        cmp     #$10
        bne     LDE02
        ora     #$06
        jmp     LDE04

LDE02:  ora     #$03
LDE04:  sta     ObjectState,x
        rts

LDE07:  sta     ObjectState,x
        cpx     #$02
        bcs     LDE15
        dec     Player1Lives,x
        beq     LDE18
        jsr     SpawnTank
        rts

LDE15:  dec     $80
        rts

; Если в специальном состоянии $68=$80 один игрок окончательно выбыл, но партнёр жив,
; готовит общую запись $0105-$0108 для переходной анимации. Смысл кодов $01/$03 и
; координат $20/$C0 следует из поведения, их пользовательское название не закреплено.
PrepareSurvivingPlayerTransition:
LDE18:  lda     $68
        cmp     #$80
        bne     LDE45
        cpx     #$01
        beq     LDE34
        lda     Player2Lives
        beq     LDE45
        lda     #$03
        sta     $0107
        lda     #$20
        sta     $0105
        jsr     InitializePlayerTransitionRecord
        rts

LDE34:  lda     Player1Lives
        beq     LDE45
        lda     #$01
        sta     $0107
        lda     #$C0
        sta     $0105
        jsr     InitializePlayerTransitionRecord
LDE45:  rts

InitializePlayerTransitionRecord:
LDE46:  lda     #$0D
        sta     $0108
        lda     #$D8
        sta     $0106
        lda     #$00
        sta     FrameCounter
        rts

; Класс $F проигрывает возрастающий 14-фазный переход и становится классом $E.
TankLogicStateF:
        inc     ObjectState,x
        lda     ObjectState,x
        and     #$0F
        cmp     #$0E
        bne     LDE63
        lda     #$E0
        sta     ObjectState,x
LDE63:  rts

; Класс $E проигрывает возрастающий 14-фазный переход, затем инициализирует танк.
TankLogicStateE:
        inc     ObjectState,x
        lda     ObjectState,x
        and     #$0F
        cmp     #$0E
        bne     LDE71
        jsr     InitializeTankState
LDE71:  rts

; Выбирает следующий AI-класс. Сравнения темпа $84 с медленным счётчиком $0A
; переключают между случайным направлением класса $A и целевыми классами $B-$D.
; Вход: X -- слот; выход: ObjectState,X изменён, A содержит записанный класс.
ChooseEnemyTankAiMode:
LDE72:  lda     $84
        lsr     a
        lsr     a
        cmp     $0A
        bcs     LDE7F
        lda     #$B0
        jmp     LDEA2

LDE7F:  lsr     a
        cmp     $0A
        bcc     LDE8E
        jsr     NextRandomByte
        and     #$03
        ora     #$A0
        sta     ObjectState,x
        rts

LDE8E:  lda     ObjectState
        beq     LDE9B
        txa
        and     #$01
        beq     LDEA0
        lda     $A1
        beq     LDEA0
LDE9B:  lda     #$C0
        jmp     LDEA2

LDEA0:  lda     #$D0
LDEA2:  jsr     SetTankStateClass
        rts

; Рисует восемь танков через отдельную таблицу состояний отображения.
; Портит A/X/Y, CurrentTankSlot, ScratchPtr и рабочие поля OAM-процедур.
DrawTanks:
LDEA6:  lda     #$00
        sta     $5A
LDEAA:  ldx     $5A
        jsr     DispatchTankDraw
        inc     $5A
        lda     $5A
        cmp     #$08
        bne     LDEAA
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
; отключает добавочные атрибуты $6E и восстанавливает их в $20 после вызова.
DrawTankStates5To7:
        lda     #$00
        sta     $6E
        lda     ObjectState,x
        pha
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        pla
        jsr     ComputeAndDrawTankTransitionFrame
        lda     #$20
        sta     $6E
        rts

ComputeAndDrawTankTransitionFrame:
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
        sta     $53
        lda     #$03
        sta     $04
        jsr     EmitTwoTileOamPair
        rts

; Класс $1: вариант финальной анимации зависит от ObjectAttributes,X; при нуле
; используется первый кадр общей переходной последовательности.
DrawTankState1:
        lda     #$00
        sta     $6E
        lda     ObjectAttributes,x
        beq     LDF23
        lda     ObjectAttributes,x
        lsr     a
        lsr     a
        lsr     a
        and     #$FC
        sec
        sbc     #$10
        clc
        adc     #$B9
        sta     $53
        lda     #$03
        sta     $04
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        jsr     EmitTwoTileOamPair
        jmp     LDF2E

LDF23:  lda     ObjectY,x
        tay
        lda     ObjectX,x
        tax
        lda     #$00
        jsr     DrawTankTransitionFrameFromOffset
LDF2E:  lda     #$20
        sta     $6E
        rts

; Класс $2: выводит кадр 8 общей переходной последовательности.
DrawTankState2:
        lda     #$00
        sta     $6E
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        lda     #$08
        jsr     DrawTankTransitionFrameFromOffset
        lda     #$20
        sta     $6E
        rts

; Классы $3-$4: выводят четыре двухспрайтовых элемента вокруг центра танка,
; формируя объект 32x32. LDF99 выбирает tile-base по классу и номеру квадранта.
DrawTankStates3To4:
        lda     #$03
        sta     $04
        lda     #$00
        sta     $6E
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
        sta     $6E
        rts

PrepareLargeTankQuadrant:
LDF99:  ldx     $5A
        asl     a
        asl     a
        clc
        adc     #$D1
        sta     $00
        lda     ObjectState,x
        and     #$F0
        sec
        sbc     #$30
        eor     #$10
        clc
        adc     $00
        sta     $53
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        rts

; Классы $8-$D: обычный танк. Палитра игроков равна номеру слота, палитра противника
; анимируется по ObjectAttributes/FrameCounter. Направление выбирает один из четырёх
; кадров, ObjectFrame добавляется к старшей тетраде tile-base.
DrawTankStates8ToD:
        cpx     #$02
        bcc     LDFDD
        lda     ObjectAttributes,x
        and     #$04
        beq     LDFCD
        lda     FrameCounter
        lsr     a
        lsr     a
        lsr     a
        and     #$01
        clc
        adc     #$02
        jmp     LDFE9

LDFCD:  lda     FrameCounter
        asl     a
        asl     a
        clc
        adc     ObjectAttributes,x
        and     #$07
        tay
        lda     LE003,y
        jmp     LDFE9

LDFDD:  lda     $6F,x
        beq     LDFE8
        lda     FrameCounter
        and     #$08
        beq     LDFE8
        rts

LDFE8:  txa
LDFE9:  sta     $04
        lda     ObjectState,x
        and     #$03
        pha
        lda     ObjectAttributes,x
        and     #$F0
        clc
        adc     ObjectFrame,x
        sta     $53
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
        bpl     LE019
        eor     #$FF
        clc
        adc     #$01
LE019:  asl     a
        and     #$FC
        clc
        adc     #$A1
        sta     $53
        lda     #$03
        sta     $04
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        jsr     EmitTwoTileOamPair
        rts

; Обновляет десять снарядов, по одному слоту на танк/источник.
