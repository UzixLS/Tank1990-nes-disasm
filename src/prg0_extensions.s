; Активные расширения Tank 1990 в первом PRG-банке ($A553-$A73C).

; Расширения Tank 1990 в свободных областях первого PRG-банка.

MinimumLifeDonationCount = $02

; Передаёт жизнь выбывшему партнёру в режиме двух игроков.
; Вход: текущие MenuSelection, Player*Lives и Joy*Held.
; Побочные эффекты: меняет оба счётчика жизней; при успехе X — номер
; возрождаемого игрока (0/1), а управление передаётся в общий код возрождения.
ShareLifeWithDefeatedPartner:
LA553:  jsr     UpdateHalfSecondPhaseFlag
        lda     MenuSelection
        beq     FinishLifeSharingCheck
        lda     Player2Lives
        beq     TryDonateLifeToPlayer2
        cmp     #MinimumLifeDonationCount
        bcc     FinishLifeSharingCheck
        lda     Player1Lives
        bne     FinishLifeSharingCheck
        lda     Joy1Held
        and     #BUTTON_A
        beq     FinishLifeSharingCheck
        inc     Player1Lives
        dec     Player2Lives
        ldx     #$00
        jmp     RespawnAfterSharedLife

TryDonateLifeToPlayer2:
LA575:  lda     Player1Lives
        cmp     #MinimumLifeDonationCount
        bcc     FinishLifeSharingCheck
        lda     Joy2Held
        and     #BUTTON_A
        beq     FinishLifeSharingCheck
        inc     Player2Lives
        dec     Player1Lives
        ldx     #$01
        jmp     RespawnAfterSharedLife
FinishLifeSharingCheck:
LA58A:  rts

; Пропускает передачу в код возрождения через периодическую проверку ROM.
; Вход: X — слот игрока. Не возвращается: переходит в LE363 или NMI при ошибке.
RespawnAfterSharedLife:
LA58B:  jsr     ShouldRunIntegrityCheck
        bcc     LA596
        jmp     VerifyRespawnCodeAndContinue

; Неиспользуемый статически одношаговый hook: продолжает возрождение только при C=0.
LA593:  bcc     LA596
        rts
LA596:  jmp     SpawnTank

; Проверяет XOR-контрольную сумму девяти байт $D343..$D34B.
; Выход: C=0 при совпадении, C=1 при ошибке; A — фактический XOR, Y=$FF.
; Портит ScratchPtrLo/Hi, A, Y; проверяемые байты не меняет.
VerifyD343Checksum:
LA599:  lda     #$43
        sta     ScratchPtrLo
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$00
        ldy     #$08
LA5A5:  eor     (ScratchPtrLo),y
        dey
        bpl     LA5A5
        cmp     #$9D
        bne     LA5B0
        clc
        rts

LA5B0:  sec
        rts

; Hook чтения $0101,X. На выбранных фазах кадра сначала проверяет ROM;
; при ошибке намеренно зависает. Выход: A=$0101,X; портит флаги, а при проверке ещё Y и ScratchPtr.
GuardedLoadObjectExtensionByte:
LA5B2:  jsr     ShouldRunIntegrityCheck
        bcc     LA5BF
        jsr     VerifyEfc0Checksum
        bcc     LA5BF
LA5BC:  jmp     LA5BC

LA5BF:  lda     PlayerUpgradeLevel,x
        rts

; Вторая XOR-контрольная сумма: $EFC0..$EFCC (13 байт).
; Выход: C=0 при совпадении, C=1 при ошибке; портит ScratchPtrLo/Hi, A, Y.
VerifyEfc0Checksum:
LA5C3:  lda     #$C0
        sta     ScratchPtrLo
        lda     #$EF
        sta     ScratchPtrHi
        lda     #$00
        ldy     #$0C
LA5CF:  eor     (ScratchPtrLo),y
        dey
        bpl     LA5CF
        cmp     #$11
        bne     LA5DA
        clc
        rts
LA5DA:  sec
        rts

; Hook инициализации $89,X значением $0A. На выбранных фазах проверяет ROM;
; при ошибке намеренно зависает. Портит A; при проверке также Y и ScratchPtr.
GuardedInitializeObjectTimer:
LA5DC:  jsr     ShouldRunIntegrityCheck
        bcc     LA5E9
        jsr     Verify8D12Checksum
        bcc     LA5E9
LA5E6:  jmp     LA5E6

LA5E9:  lda     #$0A
        sta     PlayerShieldTimer,x
        rts

; XOR-контрольная сумма $8D12..$8D18 (область данных уровней).
; Выход: C=0 при совпадении, C=1 при ошибке; портит ScratchPtrLo/Hi, A, Y.
Verify8D12Checksum:
LA5EE:  lda     #$12
        sta     ScratchPtrLo
        lda     #$8D
        sta     ScratchPtrHi
        lda     #$00
        ldy     #$06
LA5FA:  eor     (ScratchPtrLo),y
        dey
        bpl     LA5FA
        cmp     #$BB
        bne     LA605
        clc
        rts
LA605:  sec
        rts
; Проверка перед возрождением: при ошибке передаёт управление NMI, иначе — LE363.
VerifyRespawnCodeAndContinue:
LA607:  jsr     VerifyD343Checksum
        bcc     LA60F
        jmp     NmiHandler

LA60F:  jmp     SpawnTank

; Записывает $20 в $0101,X при $46 >= 3, иначе 0.
; Вход: X — индекс; выход: A — записанное значение; портит флаги.
SetIndexedModeExtensionByte:
LA612:  lda     GameVariant
        cmp     #$03
        bcc     ClearIndexedModeExtension
        lda     #$20
        bne     StoreIndexedModeExtension
ClearIndexedModeExtension:
LA61C:  lda     #$00
StoreIndexedModeExtension:
LA61E:  sta     PlayerUpgradeLevel,x
        rts

; Неиндексированный вариант SetIndexedModeExtensionByte для $0101.
SetPlayerOneModeExtensionByte:
LA622:  lda     GameVariant
        cmp     #$03
        bcc     ClearPlayerOneModeExtension
        lda     #$20
        bne     StorePlayerOneModeExtension
ClearPlayerOneModeExtension:
LA62C:  lda     #$00
StorePlayerOneModeExtension:
LA62E:  sta     PlayerUpgradeLevel
        rts
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF
; Для слотов игроков (X=0/1) вызывает два UI-обработчика; для остальных ничего не делает.
; Побочные эффекты LD9BE/LD138 зависят от их контрактов; регистры не сохраняются.
UpdatePlayerSlotUi:
LA680:  cpx     #PlayerTankCount
        bcs     FinishPlayerSlotUiUpdate
        jsr     AddScoreDigitsToRecord
        jsr     AwardScoreThresholdLives
FinishPlayerSlotUiUpdate:
LA68A:  rts

        .byte   $FF,$FF,$FF,$FF,$FF
; Ждёт кадр; при удержании A+B первым игроком снимает адрес возврата,
; записывает маркер $AB в $46 и перезапускает игру. Без комбинации обычно возвращается.
HandleResetChord:
LA690:  jsr     WaitForNextFrame
        lda     Joy1Held
        and     #(BUTTON_A | BUTTON_B)
        cmp     #(BUTTON_A | BUTTON_B)
        beq     RestartFromResetChord
        rts
RestartFromResetChord:
LA69C:  pla
        pla
        lda     #$AB
        sta     GameVariant
        jmp     ResetHandler

        .byte   $FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$04,$06
        .byte   $05,$05,$04,$06,$04,$06,$04,$06
        .byte   $03,$07,$04,$06,$02,$08,$04,$06
        .byte   $06,$04,$04,$06,$07,$03,$04,$06
        .byte   $08,$02,$04,$06,$09,$01,$04,$06
        .byte   $01,$09,$04,$06,$06,$04
; Периодический gate для проверок целостности.
; Вход: десятитысячные цифры Player1Score+2 и Player2Score+2.
; Выход: C=1, если их сумма равна 3, 6 или 9; иначе C=0.
; Портит A и флаги; X/Y и RAM не меняет.
ShouldRunIntegrityCheck:
LA728:  clc
        lda     Player1Score+2
        adc     Player2Score+2
        cmp     #$03
        beq     LA73B
        cmp     #$06
        beq     LA73B
        cmp     #$09
        beq     LA73B
        clc
        rts

LA73B:  sec
        rts
