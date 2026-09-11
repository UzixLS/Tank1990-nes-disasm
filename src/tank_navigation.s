; Движение, terrain probes и смена направления танка ($DC52-$DD7D).
ProposedTankX    = $56
ProposedTankY    = $57
TankProbeXOffset = $58
TankProbeYOffset = $59

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
