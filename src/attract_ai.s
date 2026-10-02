; Генерация ввода игроков для attract mode ($C642-$C6C5).

AttractPlayerSlot             = $5A
AttractFirstTargetSlotOffset  = 2
AttractSecondTargetSlotOffset = 4
AttractThirdTargetSlotOffset  = 3
AttractPressedButtonsCutoffY  = $C8
AttractActionButtonMask       = BUTTON_A | BUTTON_B

; Полностью заменяет Joy1/Joy2 Held и Pressed синтетическим вводом. Слоты
; обходятся P2, затем P1. Приоритет цели каждого игрока:
;   1. существующий неполученный power-up (PowerUpX!=0 и pickup timer=0);
;   2. первый объект со state $80..$DF в slots X+2, X+4, X+3.
; Поэтому P1 проверяет enemy slots 2,4,3, а P2 — 3,5,4; slots 6/7 demo-AI
; никогда не выбирает. Если подходящей цели нет, обе input-маски игрока равны 0.
;
; ChooseTankStateTowardTarget для player slots не вызывает RNG и чередует
; vertical/horizontal priority по bit1 SlowFrameCounter, у P1/P2 в противофазе.
; Полученное направление превращается в D-pad+A+B. В GameMode=5 held B
; обслуживается как непрерывный огонь, поэтому demo-танки пытаются стрелять при
; каждом разрешённом firing tick независимо от очистки Pressed ниже.
;
; Выход: AttractPlayerSlot=$FF, X=Player1TankSlot; A/Y не определены. Меняет
; Joy1/Joy2 Held/Pressed, TankTargetX/Y и targeting scratch; координаты/states
; объектов, power-up, RNG, PPU/OAM/audio не меняет.
GenerateAttractModeInput:
LC642:  lda     #Player2TankSlot
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
LC65E:  lda     ObjectState+AttractFirstTargetSlotOffset,x
        bpl     TrySecondAttractEnemyTarget
        cmp     #NonTargetableTankStateMin
        bcs     TrySecondAttractEnemyTarget
        lda     ObjectX+AttractFirstTargetSlotOffset,x
        sta     TankTargetX
        lda     ObjectY+AttractFirstTargetSlotOffset,x
        sta     TankTargetY
        jsr     ChooseTankStateTowardTarget
        jmp     ConvertAttractDirectionToInput

TrySecondAttractEnemyTarget:
LC674:  lda     ObjectState+AttractSecondTargetSlotOffset,x
        bpl     TryThirdAttractEnemyTarget
        cmp     #NonTargetableTankStateMin
        bcs     TryThirdAttractEnemyTarget
        lda     ObjectX+AttractSecondTargetSlotOffset,x
        sta     TankTargetX
        lda     ObjectY+AttractSecondTargetSlotOffset,x
        sta     TankTargetY
        jsr     ChooseTankStateTowardTarget
        jmp     ConvertAttractDirectionToInput

TryThirdAttractEnemyTarget:
LC68A:  lda     ObjectState+AttractThirdTargetSlotOffset,x
        bpl     UseAttractNeutralInput
        cmp     #NonTargetableTankStateMin
        bcs     UseAttractNeutralInput
        lda     ObjectX+AttractThirdTargetSlotOffset,x
        sta     TankTargetX
        lda     ObjectY+AttractThirdTargetSlotOffset,x
        sta     TankTargetY
        jsr     ChooseTankStateTowardTarget
        jmp     ConvertAttractDirectionToInput

UseAttractNeutralInput:
LC6A0:  lda     #$00
        jmp     StoreAttractPlayerInput

; Преобразует младшие два бита полного active state A=$A0..$A3 в D-pad+A+B и
; проваливается в общий хвост записи ввода игрока AttractPlayerSlot. Таблица
; обязана сохранять порядок direction-кодов Up,Left,Down,Right.
ConvertAttractDirectionToInput:
LC6A5:  and     #DirectionMask
        tay
        lda     AttractInputByDirection,y
; Альтернативный вход: A уже содержит маску Joy. Одинаковое значение сначала
; пишется в Held и Pressed. При ObjectY>=AttractPressedButtonsCutoffY в Pressed
; остаётся только D-pad, но Held сохраняет A+B: это убирает кнопочные фронты,
; не прекращая непрерывный огонь по held B в OnePlayerGameMode.
; После P2 проваливается к обработке P1, после P1 возвращается. Портит A/X;
; Y сохраняется на прямом входе, но может быть изменён targeting-путём.
StoreAttractPlayerInput:
LC6AB:  ldx     AttractPlayerSlot
        sta     Joy1Held,x
        sta     Joy1Pressed,x
        lda     ObjectY,x
        cmp     #AttractPressedButtonsCutoffY
        bcc     AdvanceAttractPlayer
        lda     Joy1Pressed,x
        and     #BUTTON_DIRECTIONS
        sta     Joy1Pressed,x
AdvanceAttractPlayer:
LC6BD:  dec     AttractPlayerSlot
        bpl     GenerateNextAttractPlayerInput
        rts

AttractInputByDirection:
LC6C2:  .byte   BUTTON_UP    | AttractActionButtonMask
        .byte   BUTTON_LEFT  | AttractActionButtonMask
        .byte   BUTTON_DOWN  | AttractActionButtonMask
        .byte   BUTTON_RIGHT | AttractActionButtonMask
