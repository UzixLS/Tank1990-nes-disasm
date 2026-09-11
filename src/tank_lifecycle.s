; Разрушение, удаление, появление и переходные состояния танков ($DDEA-$DE71).

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
