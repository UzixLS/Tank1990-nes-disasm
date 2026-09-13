; Исполняемые обработчики расширений Tank 1990 в первом PRG-банке
; ($A553-$A73C). В текущем именованном графе вызовов внешних ссылок на этот
; блок нет; близкие варианты части обработчиков находятся в верхнем PRG-банке.

MinimumLifeDonationCount = $02
ModeExtensionEnabledValue       = $20
InitialPlayerShieldTimerValue   = $0A

GameOverTextChecksumExpected   = $9D
StageAdvanceChecksumExpected   = $11
TankLevelDataChecksumExpected  = $BB
GameOverTextChecksumByteCount  = $09
StageAdvanceChecksumByteCount  = $0D
TankLevelDataChecksumByteCount = $07
StageAdvanceChecksumStart      = StageDataBaseAdjusted + 1
TankLevelDataChecksumStart     = TankLevels + $0D12

; Передаёт жизнь выбывшему партнёру в режиме двух игроков.
; Вход: MenuSelection, Player*Lives и Joy*Held; X/Y не используются.
; Всегда вызывает UpdateHalfSecondPhaseFlag; тот меняет BackgroundPaletteIndex
; только на соответствующей полусекундной фазе.
; Без передачи жизни возвращается, портя A и флаги. При успехе переносит одну
; жизнь от живого игрока выбывшему, оставляет X=0/1 для возрождаемого игрока
; и хвостовым переходом уходит в SpawnTank либо в integrity guard; этот путь
; самостоятельно не возвращается.
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
        bcc     ContinueSharedLifeRespawn
        jmp     VerifyRespawnCodeAndContinue

; Неиспользуемый статически одношаговый hook: продолжает возрождение только при C=0.
CarryGuardedRespawnHook:
LA593:  bcc     ContinueSharedLifeRespawn
        rts
ContinueSharedLifeRespawn:
LA596:  jmp     SpawnTank

; Проверяет XOR девяти байтов GameText/OverText ($D343..$D34B): строку "GAME",
; терминатор и первые четыре байта "OVER". Последний терминатор $D34C не входит.
; Выход: C=0 при совпадении, C=1 при ошибке; A — фактический XOR, Y=$FF.
; Портит ScratchPtrLo/Hi, A, Y; проверяемые байты не меняет.
VerifyGameOverTextChecksum:
VerifyD343Checksum:
LA599:  lda     #<GameText
        sta     ScratchPtrLo
        lda     #>GameText
        sta     ScratchPtrHi
        lda     #$00
        ldy     #(GameOverTextChecksumByteCount-1)
XorNextGameOverTextByte:
LA5A5:  eor     (ScratchPtrLo),y
        dey
        bpl     XorNextGameOverTextByte
        cmp     #GameOverTextChecksumExpected
        bne     ReportGameOverTextChecksumFailure
        clc
        rts

ReportGameOverTextChecksumFailure:
LA5B0:  sec
        rts

; Hook чтения PlayerUpgradeLevel,X. Когда ShouldRunIntegrityCheck возвращает
; C=1, сначала проверяет машинный код шага по картам $EFC0..$EFCC; при ошибке
; намеренно зависает. Выход: A=PlayerUpgradeLevel,X; X сохраняется. Портит
; флаги, а на проверочном пути также Y и ScratchPtr.
GuardedLoadObjectExtensionByte:
LA5B2:  jsr     ShouldRunIntegrityCheck
        bcc     LoadGuardedObjectExtensionByte
        jsr     VerifyStageAdvanceCodeChecksum
        bcc     LoadGuardedObjectExtensionByte
HaltOnStageAdvanceChecksumFailure:
LA5BC:  jmp     HaltOnStageAdvanceChecksumFailure

LoadGuardedObjectExtensionByte:
LA5BF:  lda     PlayerUpgradeLevel,x
        rts

; Проверяет XOR машинного кода $EFC0..$EFCC в LoadAndDrawStage: от
; STA StageWrapOffset до младшего байта операнда JMP AdvanceToSelectedStage.
; Старший байт адреса перехода по $EFCD в checksum не входит.
; Выход: C=0 при совпадении, C=1 при ошибке; A — фактический XOR, Y=$FF.
; Портит ScratchPtrLo/Hi, A, Y; X и проверяемый код сохраняются.
VerifyStageAdvanceCodeChecksum:
VerifyEfc0Checksum:
LA5C3:  lda     #<StageAdvanceChecksumStart
        sta     ScratchPtrLo
        lda     #>StageAdvanceChecksumStart
        sta     ScratchPtrHi
        lda     #$00
        ldy     #(StageAdvanceChecksumByteCount-1)
XorNextStageAdvanceCodeByte:
LA5CF:  eor     (ScratchPtrLo),y
        dey
        bpl     XorNextStageAdvanceCodeByte
        cmp     #StageAdvanceChecksumExpected
        bne     ReportStageAdvanceChecksumFailure
        clc
        rts
ReportStageAdvanceChecksumFailure:
LA5DA:  sec
        rts

; Hook инициализации PlayerShieldTimer,X. На выбранных score-фазах проверяет
; семь байтов level data; при ошибке намеренно зависает.
; Вход: X — индекс таймера. Выход: A=InitialPlayerShieldTimerValue, X сохраняется.
; Записывает PlayerShieldTimer,X; портит флаги, а на проверочном пути также Y
; и ScratchPtr.
GuardedInitializeObjectTimer:
LA5DC:  jsr     ShouldRunIntegrityCheck
        bcc     InitializeGuardedPlayerShieldTimer
        jsr     VerifyTankLevelDataChecksum
        bcc     InitializeGuardedPlayerShieldTimer
HaltOnTankLevelDataChecksumFailure:
LA5E6:  jmp     HaltOnTankLevelDataChecksumFailure

InitializeGuardedPlayerShieldTimer:
LA5E9:  lda     #InitialPlayerShieldTimerValue
        sta     PlayerShieldTimer,x
        rts

; Проверяет XOR семи байтов $8D12..$8D18 внутри TankLevels. Их структурное
; назначение сверх принадлежности данным карт не установлено.
; Выход: C=0 при совпадении, C=1 при ошибке; A — фактический XOR, Y=$FF.
; Портит ScratchPtrLo/Hi, A, Y; X и данные уровней сохраняются.
VerifyTankLevelDataChecksum:
Verify8D12Checksum:
LA5EE:  lda     #<TankLevelDataChecksumStart
        sta     ScratchPtrLo
        lda     #>TankLevelDataChecksumStart
        sta     ScratchPtrHi
        lda     #$00
        ldy     #(TankLevelDataChecksumByteCount-1)
XorNextTankLevelDataByte:
LA5FA:  eor     (ScratchPtrLo),y
        dey
        bpl     XorNextTankLevelDataByte
        cmp     #TankLevelDataChecksumExpected
        bne     ReportTankLevelDataChecksumFailure
        clc
        rts
ReportTankLevelDataChecksumFailure:
LA605:  sec
        rts

; Проверка перед возрождением. При успехе хвостом переходит в SpawnTank. При
; ошибке входит в NmiHandler обычным JMP, поэтому его RTI использует текущий
; стек вместо аппаратного NMI-кадра; к вызывающему пути процедура не возвращается.
VerifyRespawnCodeAndContinue:
LA607:  jsr     VerifyGameOverTextChecksum
        bcc     ContinueRespawnAfterChecksum
        jmp     NmiHandler

ContinueRespawnAfterChecksum:
LA60F:  jmp     SpawnTank

; Записывает ModeExtensionEnabledValue в PlayerUpgradeLevel,X при
; GameVariant>=3 (беззнаковое сравнение), иначе 0.
; Вход: X — индекс; выход: A — записанное значение; X/Y сохраняются.
SetIndexedModeExtensionByte:
LA612:  lda     GameVariant
        cmp     #$03
        bcc     ClearIndexedModeExtension
        lda     #ModeExtensionEnabledValue
        bne     StoreIndexedModeExtension
ClearIndexedModeExtension:
LA61C:  lda     #$00
StoreIndexedModeExtension:
LA61E:  sta     PlayerUpgradeLevel,x
        rts

; Неиндексированный вариант SetIndexedModeExtensionByte для первого элемента
; PlayerUpgradeLevel. Выход и сохранность регистров совпадают с ним.
SetPlayerOneModeExtensionByte:
LA622:  lda     GameVariant
        cmp     #$03
        bcc     ClearPlayerOneModeExtension
        lda     #ModeExtensionEnabledValue
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
; Для слотов игроков X=0/1 прибавляет ScoreIncrementDigits к соответствующему
; счёту, затем проверяет пороги дополнительных жизней обоих игроков. Может
; изменить Player*Score, Player*Lives, PlayerExtraLifeAwarded и запросы двух
; аудиоканалов extra-life. Возвращает X=$FF для P1 либо $07 для P2, Y=$FF;
; при исходном X>=PlayerTankCount RAM и A/X/Y не меняет, флаги задаёт CPX.
UpdatePlayerSlotUi:
LA680:  cpx     #PlayerTankCount
        bcs     FinishPlayerSlotUiUpdate
        jsr     AddScoreDigitsToRecord
        jsr     AwardScoreThresholdLives
FinishPlayerSlotUiUpdate:
LA68A:  rts

        .byte   $FF,$FF,$FF,$FF,$FF
; Ждёт кадр и проверяет удержание A+B первым игроком. Без комбинации возвращается
; после WaitForNextFrame, портя A и флаги; X/Y сохраняются, а кадровое/input-
; состояние успевает обновиться через NMI. При комбинации снимает со стека двухбайтный адрес возврата,
; записывает reset-маркер $AB в GameVariant и хвостом уходит в ResetHandler;
; этот путь не возвращается.
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
; Вход: десятичные цифры десятков тысяч Player1Score+2 и Player2Score+2.
; Выход: C=1, если их сумма равна 3, 6 или 9; иначе C=0.
; Портит A и флаги; X/Y и RAM не меняет.
ShouldRunIntegrityCheck:
LA728:  clc
        lda     Player1Score+2
        adc     Player2Score+2
        cmp     #$03
        beq     EnableScheduledIntegrityCheck
        cmp     #$06
        beq     EnableScheduledIntegrityCheck
        cmp     #$09
        beq     EnableScheduledIntegrityCheck
        clc
        rts

EnableScheduledIntegrityCheck:
LA73B:  sec
        rts
