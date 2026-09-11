; Главный проход логики танков и dispatch состояний ($DBF1-$DC51).

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
