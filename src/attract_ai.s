; Генерация ввода игроков для attract mode ($C642-$C6C5).

AttractPlayerSlot = $5A
; Генерирует Joy1/Joy2 для attract mode. Для каждого игрока выбирает цель:
; координаты существующего бонуса при PowerUpPickupDisplayTimer=0, иначе первый
; активный танк из слотов
; X+2, X+4, X+3 (для игроков 0/1 это соответственно 2/4/3 и 3/5/4).
; ChooseTankStateTowardTarget возвращает направление; DemoInputByDirection
; добавляет огонь. Меняет Joy*Held/Pressed, AttractPlayerSlot, TankTargetX/Y
; и work RAM; портит A/X/Y.
GenerateAttractModeInput:
LC642:  lda     #$01
        sta     AttractPlayerSlot
GenerateNextAttractPlayerInput:
LC646:  ldx     AttractPlayerSlot
        lda     PowerUpX
        beq     TryFirstAttractEnemyTarget
        lda     PowerUpPickupDisplayTimer
        bne     TryFirstAttractEnemyTarget
        lda     PowerUpX
        sta     TankTargetX
        lda     PowerUpY
        sta     TankTargetY
        jsr     ChooseTankStateTowardTarget
        jmp     ConvertAttractDirectionToInput

TryFirstAttractEnemyTarget:
LC65E:  lda     ObjectState+2,x
        bpl     TrySecondAttractEnemyTarget
        cmp     #NonTargetableTankStateMin
        bcs     TrySecondAttractEnemyTarget
        lda     ObjectX+2,x
        sta     TankTargetX
        lda     ObjectY+2,x
        sta     TankTargetY
        jsr     ChooseTankStateTowardTarget
        jmp     ConvertAttractDirectionToInput

TrySecondAttractEnemyTarget:
LC674:  lda     ObjectState+4,x
        bpl     TryThirdAttractEnemyTarget
        cmp     #NonTargetableTankStateMin
        bcs     TryThirdAttractEnemyTarget
        lda     ObjectX+4,x
        sta     TankTargetX
        lda     ObjectY+4,x
        sta     TankTargetY
        jsr     ChooseTankStateTowardTarget
        jmp     ConvertAttractDirectionToInput

TryThirdAttractEnemyTarget:
LC68A:  lda     ObjectState+3,x
        bpl     UseAttractNeutralInput
        cmp     #NonTargetableTankStateMin
        bcs     UseAttractNeutralInput
        lda     ObjectX+3,x
        sta     TankTargetX
        lda     ObjectY+3,x
        sta     TankTargetY
        jsr     ChooseTankStateTowardTarget
        jmp     ConvertAttractDirectionToInput

UseAttractNeutralInput:
LC6A0:  lda     #$00
        jmp     StoreAttractPlayerInput

ConvertAttractDirectionToInput:
LC6A5:  and     #DirectionMask
        tay
        lda     DemoInputByDirection,y
StoreAttractPlayerInput:
LC6AB:  ldx     AttractPlayerSlot
        sta     Joy1Held,x
        sta     Joy1Pressed,x
        lda     ObjectY,x
        cmp     #$C8
        bcc     AdvanceAttractPlayer
        lda     Joy1Pressed,x
        and     #BUTTON_DIRECTIONS
        sta     Joy1Pressed,x
AdvanceAttractPlayer:
LC6BD:  dec     AttractPlayerSlot
        bpl     GenerateNextAttractPlayerInput
        rts

DemoInputByDirection:
LC6C2:  .byte   $13,$43,$23,$83
