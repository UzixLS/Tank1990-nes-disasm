; Исполняемые обработчики расширений Tank 1990 в первом PRG-банке
; ($A553-$A73C). В текущем полном статическом графе ссылок извне блока нет:
; штатный gameplay использует более поздние реализации из верхнего PRG-банка.
; Поэтому entry points ниже документируют сохранённый, но недостижимый код;
; вызов их ромхаком требует соблюдать continuation/stack contracts, а не считать
; каждую метку обычной JSR-процедурой.

MinimumLifeDonationCount = $02
ModeExtensionEnabledValue       = $20
ModeExtensionFirstVariant       = $03
InitialPlayerShieldTimerValue   = $0A
IntegrityGateFirstScoreSum      = $03
IntegrityGateSecondScoreSum     = $06
IntegrityGateThirdScoreSum      = $09

GameOverTextChecksumExpected   = $9D
StageAdvanceChecksumExpected   = $11
TankLevelDataChecksumExpected  = $BB
GameOverTextChecksumByteCount  = $09
StageAdvanceChecksumByteCount  = $0D
TankLevelDataChecksumByteCount = $07
StageAdvanceChecksumStart      = StageDataBaseAdjusted + 1
TankLevelDataChecksumStart     = TankLevels + $0D12

; Передаёт жизнь выбывшему партнёру при любом MenuSelection!=0. Получатель
; обязан иметь ровно 0 жизней, донор — не менее двух; кнопку A должен удерживать
; именно получатель. Если оба живы или оба без жизней, передачи нет.
; Вход: MenuSelection, Player*Lives и Joy*Held; входные X/Y не читаются.
; Всегда вызывает UpdateHalfSecondPhaseFlag; тот меняет BackgroundPaletteIndex
; только на соответствующей полусекундной фазе.
; Без передачи жизни возвращается, портя A и флаги. При успехе переносит одну
; жизнь от живого игрока выбывшему, задаёт X=0/1 получателя и хвостовым
; переходом уходит в score-gated checksum/respawn chain; этот путь не
; возвращается в данную процедуру. Y сохраняется до вызванных продолжений;
; PPU/OAM/audio/RNG непосредственно не меняет.
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
        ldx     #Player1TankSlot
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
        ldx     #Player2TankSlot
        jmp     RespawnAfterSharedLife
FinishLifeSharingCheck:
LA58A:  rts

; Continuation после передачи жизни: score gate либо сразу хвостом вызывает
; SpawnTank, либо проверяет GameText. В текущем ROM GameText XOR=$FF не равен
; встроенному $9D, поэтому включённый gate всегда ведёт к ошибочному NMI-path.
; Вход: X — слот игрока 0/1 и на стеке return address внешнего JSR caller-а.
; Самостоятельно не возвращается: SpawnTank RTS возвращает этому caller-у;
; checksum-failure нарушает обычный стековый протокол через JMP NmiHandler.
RespawnAfterSharedLife:
LA58B:  jsr     ShouldRunIntegrityCheck
        bcc     ContinueSharedLifeRespawn
        jmp     VerifyRespawnCodeAndContinue

; Неиспользуемый статически одношаговый hook: при входном C=0 хвостом вызывает
; SpawnTank, при C=1 делает обычный RTS. A/X/Y/RAM до выбранного пути сохраняет.
CarryGuardedRespawnHook:
LA593:  bcc     ContinueSharedLifeRespawn
        rts
ContinueSharedLifeRespawn:
LA596:  jmp     SpawnTank

; Проверяет XOR девяти байтов GameText/OverText ($D343..$D34B): строку "GAME",
; терминатор и первые четыре байта "OVER". Последний терминатор $D34C не входит.
; Фактические bytes исходного ROM дают $FF, а embedded expected value=$9D:
; неизменённый образ всегда возвращает ошибку. Это сохранённое поведение,
; а не проверка, которую следует автоматически "чинить" в производной работе.
; Выход: C=0 при совпадении, C=1 при ошибке; A — фактический XOR, Y=$FF,
; X сохранён, N/Z от CMP (в исходном ROM N=0/Z=0). V сохраняется.
; Портит ScratchPtr=$D343, A/Y; проверяемые ROM bytes и прочую RAM не меняет.
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
; C=1, сначала проверяет машинный код шага по картам $EFC0..$EFCC. Его текущий
; XOR=$9A не равен embedded $11, поэтому на score sums 3/6/9 исходный ROM
; намеренно навсегда зацикливается; на остальных sums возвращает upgrade byte.
; Вход: X должен индексировать существующий PlayerUpgradeLevel (штатно 0/1).
; Выход нормального пути: A=PlayerUpgradeLevel,X, N/Z по нему; X сохранён.
; Портит flags, а на проверочном пути также Y и ScratchPtr=$EFC0.
GuardedLoadPlayerUpgradeLevel:
LA5B2:  jsr     ShouldRunIntegrityCheck
        bcc     LoadGuardedPlayerUpgradeLevel
        jsr     VerifyStageAdvanceCodeChecksum
        bcc     LoadGuardedPlayerUpgradeLevel
HaltOnStageAdvanceChecksumFailure:
LA5BC:  jmp     HaltOnStageAdvanceChecksumFailure

LoadGuardedPlayerUpgradeLevel:
LA5BF:  lda     PlayerUpgradeLevel,x
        rts

; Проверяет XOR машинного кода $EFC0..$EFCC в LoadAndDrawStage: от
; STA StageWrapOffset до младшего байта операнда JMP AdvanceToSelectedStage.
; Старший байт адреса перехода по $EFCD в checksum не входит.
; Текущие bytes дают $9A при embedded expected value=$11, поэтому неизменённый
; ROM всегда возвращает ошибку. Выход: C=0 при совпадении, C=1 при ошибке;
; A=фактический XOR, Y=$FF, X сохранён, N/Z от CMP (штатно N=1/Z=0),
; V сохраняется. Портит ScratchPtr=$EFC0; проверяемый код не меняет.
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

; Hook инициализации PlayerShieldTimer,X. На score sums 3/6/9 проверяет семь
; байтов TankLevels; в исходном ROM их XOR совпадает с $BB. После успешной
; проверки или при закрытом gate записывает shield timer=$0A; при несовпадении
; намеренно навсегда зацикливается.
; Вход: X должен быть player index 0/1. Выход успешного пути:
; A=InitialPlayerShieldTimerValue, X сохранён, N=0/Z=C=V=0 при корректных
; score digits; Y сохраняется без проверки либо становится $FF с ней.
; Портит PlayerShieldTimer,X, а при проверке также
; ScratchPtr=$8D12; PPU/OAM/audio/RNG не меняет.
GuardedInitializePlayerShieldTimer:
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
; назначение сверх принадлежности данным карт не установлено. Текущие bytes
; дают ровно embedded expected value=$BB.
; Выход: C=0 при совпадении, C=1 при ошибке; A=фактический XOR, Y=$FF,
; X сохранён, N/Z от CMP, V сохраняется. Портит ScratchPtr=$8D12;
; данные уровней и прочую RAM не меняет.
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
; ошибке входит в полный NmiHandler обычным JMP. Handler сохранит/восстановит
; регистры своими PHA/PHP, но финальный RTI затем примет лежащий на стеке JSR
; return address внешнего caller-а за status/PCL и возьмёт PCH из ещё более
; старого stack byte. Это не обычный NMI и не определённый возврат/перезапуск;
; PPU/OAM/input/audio/frame side effects NMI успевают выполниться до wild RTI.
VerifyRespawnCodeAndContinue:
LA607:  jsr     VerifyGameOverTextChecksum
        bcc     ContinueRespawnAfterChecksum
        jmp     NmiHandler

ContinueRespawnAfterChecksum:
LA60F:  jmp     SpawnTank

; Записывает ModeExtensionEnabledValue в PlayerUpgradeLevel,X при
; GameVariant>=3 (беззнаковое сравнение), иначе 0.
; Вход: X=0/1; bounds check нет. Выход: A=записанное значение, X/Y сохранены;
; N=0, Z отражает записанный ноль, C=1 для variant>=3 и 0 иначе, V сохранён.
SetPlayerUpgradeLevelForVariant:
LA612:  lda     GameVariant
        cmp     #ModeExtensionFirstVariant
        bcc     ClearIndexedPlayerUpgrade
        lda     #ModeExtensionEnabledValue
        bne     StoreIndexedPlayerUpgrade
ClearIndexedPlayerUpgrade:
LA61C:  lda     #$00
StoreIndexedPlayerUpgrade:
LA61E:  sta     PlayerUpgradeLevel,x
        rts

; Неиндексированный вариант SetPlayerUpgradeLevelForVariant для первого элемента
; PlayerUpgradeLevel. Выход и сохранность регистров совпадают с ним.
SetPlayerOneUpgradeLevelForVariant:
LA622:  lda     GameVariant
        cmp     #ModeExtensionFirstVariant
        bcc     ClearPlayerOneUpgrade
        lda     #ModeExtensionEnabledValue
        bne     StorePlayerOneUpgrade
ClearPlayerOneUpgrade:
LA62C:  lda     #$00
StorePlayerOneUpgrade:
LA62E:  sta     PlayerUpgradeLevel
        rts
; $A632-$A67F: erased-ROM padding without static data/code references.
UnreferencedA632FfPadding:
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
; Для слотов игроков X=0/1 прибавляет подготовленные семь decimal digits
; ScoreIncrementDigits к соответствующему score modulo 10^7, затем проверяет
; пороги дополнительных жизней обоих игроков. HighScore/HUD/PPU напрямую не
; обновляет. Может изменить Player*Score/Lives, PlayerExtraLifeAwarded и
; запросить оба extra-life audio streams. Возвращает X=$FF для P1 либо $07
; для P2, Y=$FF; A/flags после AwardScoreThresholdLives зависят от award path.
; При исходном X>=PlayerTankCount RAM и A/X/Y не меняет, flags задаёт CPX #2.
ApplyPreparedScoreAndAwardsForPlayer:
LA680:  cpx     #PlayerTankCount
        bcs     FinishPreparedScoreAndAwards
        jsr     AddScoreDigitsToRecord
        jsr     AwardScoreThresholdLives
FinishPreparedScoreAndAwards:
LA68A:  rts

; $A68B-$A68F: padding between independent preserved entry points.
UnreferencedA68bFfPadding:
        .byte   $FF,$FF,$FF,$FF,$FF
; Ждёт кадр и проверяет удержание A+B первым игроком; прочие held buttons не
; мешают после mask. Без комбинации возвращается после WaitForNextFrame,
; A=Joy1Held&(BUTTON_A|BUTTON_B), X/Y сохранены, N/Z/C от CMP #$C0;
; обслуживший кадр NMI уже обновил PPU/OAM/input/audio/counters.
; При комбинации рассчитан на вход через JSR: два PLA выбрасывают low/high
; return address текущего caller-а, затем GameVariant=$AB и JMP ResetHandler.
; Reset позже устанавливает новый SP, поэтому этот путь не возвращается и не
; оставляет снятый stack frame. Прямой JMP-вход ошибочно снимет чужие bytes.
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
        lda     #BootVariantMarker
        sta     GameVariant
        jmp     ResetHandler

; $A6A5-$A6FF: 91 bytes $FF without static references.
UnreferencedA6a5FfPadding:
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
        .byte   $FF,$FF,$FF,$FF,$FF,$FF
; $A700-$A727: двадцать пар bytes; каждая пара суммируется в decimal 10.
; Статических consumers нет, формат/назначение таблицы не установлены.
UnreferencedA700ComplementPairs:
        .byte   $04,$06
        .byte   $05,$05,$04,$06,$04,$06,$04,$06
        .byte   $03,$07,$04,$06,$02,$08,$04,$06
        .byte   $06,$04,$04,$06,$07,$03,$04,$06
        .byte   $08,$02,$04,$06,$09,$01,$04,$06
        .byte   $01,$09,$04,$06,$06,$04
; Score-dependent gate для трёх сохранённых проверок целостности. Складывает
; отдельные unpacked decimal digits десятков тысяч P1/P2 обычным binary ADC;
; при корректных digits 0..9 сумма 0..18 и overflow невозможен.
; Выход: A=sum, C=1/Z=1/N=0 только при сумме 3,6,9; иначе C=0/Z=0 и N
; соответствует финальному CMP #9. V=0 при корректных digits; X/Y и RAM
; сохраняются. Gate не имеет собственного счётчика/периода: он активен на
; каждом вызове, пока выбранная сумма score digits остаётся равной 3/6/9.
ShouldRunIntegrityCheck:
LA728:  clc
        lda     Player1Score+2
        adc     Player2Score+2
        cmp     #IntegrityGateFirstScoreSum
        beq     EnableScheduledIntegrityCheck
        cmp     #IntegrityGateSecondScoreSum
        beq     EnableScheduledIntegrityCheck
        cmp     #IntegrityGateThirdScoreSum
        beq     EnableScheduledIntegrityCheck
        clc
        rts

EnableScheduledIntegrityCheck:
LA73B:  sec
        rts
