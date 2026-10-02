; Выбор режима навигации противника ($DE72-$DEA5).

EnemyTargetSlotParityMask = $01

; Выбирает следующий AI-state по E=EnemyActivityInterval и
; S=SlowFrameCounter. Целочисленные LSR делят с округлением вниз:
;   S <= floor(E/8)                 -> random direction, state $A0..$A3;
;   floor(E/8) < S <= floor(E/4)   -> target player, class $C/$D;
;   S > floor(E/4)                  -> target base, class $B.
; Границы поэтому включительны именно со стороны более раннего режима. При E=0
; random выбирается только при S=0, player-window пусто, а при S>0 выбирается
; база. SlowFrameCounter — 8-битный счётчик NMI/64 и после переполнения цикл
; временных зон начинается заново.
;
; Вход: X=enemy slot 2..7, старый ObjectState,X содержит low nibble, который
; надо сохранить для target-класса. Player selection проверяет не полноценную
; «живость», а только точное равенство ObjectState slot нулю:
;   - если P1 state=0, выбирается P2 даже при P2 state=0;
;   - иначе чётный enemy slot выбирает P1;
;   - нечётный выбирает P2, если P2 state!=0, и P1 в противном случае.
; Destruction и spawn states игроков, будучи ненулевыми, считаются доступными.
;
; Random-ветвь единственная вызывает NextRandomByte и непосредственно записывает
; $A0|(random&3), полностью заменяя старый low nibble. Target-ветви вызывают
; SetTankStateClass и записывают class $B/$C/$D с сохранением old low nibble;
; координаты цели и направление будут выбраны соответствующим handler позже.
; Выход: A=записанный ObjectState,X, X/Y сохранены, N/Z соответствуют state.
; Меняет ObjectState,X; random-ветвь также RandomState/RandomIndex, target-ветви
; также zero-page scratch TankStateClassCandidate. PPU/OAM/audio и прочую
; object RAM не трогает.
ChooseEnemyTankAiMode:
LDE72:  lda     EnemyActivityInterval
        lsr     a
        lsr     a
        cmp     SlowFrameCounter
        bcs     CompareEnemyRandomModeThreshold
        lda     #TankStateTargetBaseClass
        jmp     CommitEnemyAiClass

CompareEnemyRandomModeThreshold:
LDE7F:  lsr     a
        cmp     SlowFrameCounter
        bcc     ChooseEnemyPlayerTarget
        ; Только этот mode расходует RNG; low two bits становятся direction.
        jsr     NextRandomByte
        and     #DirectionMask
        ora     #TankStateActiveClass
        sta     ObjectState,x
        rts

ChooseEnemyPlayerTarget:
LDE8E:  lda     ObjectState
        beq     TargetSecondPlayer
        txa
        and     #EnemyTargetSlotParityMask
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
