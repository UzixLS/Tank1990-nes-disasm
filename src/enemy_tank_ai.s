; Выбор режима навигации противника ($DE72-$DEA5).

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
        lda     #TankStateTargetBaseClass
        jmp     CommitEnemyAiClass

MaybeChooseRandomEnemyDirection:
LDE7F:  lsr     a
        cmp     SlowFrameCounter
        bcc     ChooseEnemyPlayerTarget
        jsr     NextRandomByte
        and     #DirectionMask
        ora     #TankStateActiveClass
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
LDE9B:  lda     #TankStateTargetPlayerTwoClass
        jmp     CommitEnemyAiClass

TargetFirstPlayer:
LDEA0:  lda     #TankStateTargetPlayerOneClass
CommitEnemyAiClass:
LDEA2:  jsr     SetTankStateClass
        rts
