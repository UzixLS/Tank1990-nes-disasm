; Генерация ввода игроков для attract mode ($C642-$C6C5).

AttractPlayerSlot = $5A
AttractBottomFireCutoff = $C8
; Генерирует Joy1/Joy2 для attract mode. Для каждого игрока выбирает цель:
; координаты неполученного бонуса (PowerUpX!=0, pickup timer=0), иначе первый
; targetable танк из слотов
; X+2, X+4, X+3 (для игроков 0/1 это соответственно 2/4/3 и 3/5/4).
; ChooseTankStateTowardTarget возвращает направление; DemoInputByDirection
; добавляет A+B. Выход: AttractPlayerSlot=$FF, X=0; A/Y не определены.
; Меняет Joy*Held/Pressed, TankTargetX/Y и targeting scratch; PPU/OAM/audio
; state и игровое состояние объектов не меняет.
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

; Преобразует младшие два бита состояния-направления A в D-pad+A+B и
; проваливается в общий хвост записи ввода игрока AttractPlayerSlot.
ConvertAttractDirectionToInput:
LC6A5:  and     #DirectionMask
        tay
        lda     DemoInputByDirection,y
; Альтернативный вход: A уже содержит маску Joy. Для игрока с Y>=cutoff
; оставляет в JoyPressed только D-pad; JoyHeld сохраняет исходную маску.
; После P1 проваливается к обработке P0, после P0 возвращается. Портит A/X;
; Y сохраняется на прямом входе, но может быть изменён targeting-путём.
StoreAttractPlayerInput:
LC6AB:  ldx     AttractPlayerSlot
        sta     Joy1Held,x
        sta     Joy1Pressed,x
        lda     ObjectY,x
        cmp     #AttractBottomFireCutoff
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
