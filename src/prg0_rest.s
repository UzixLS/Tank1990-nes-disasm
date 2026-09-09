; Данные и расширения кода первого PRG-банка после таблицы 100 уровней.

.segment        "PRG0_REST": absolute

ExtraLevels:
        .incbin "../build/extra-levels.bin"

; Расширения Tank 1990 в свободных областях первого PRG-банка.

; Передаёт жизнь выбывшему партнёру в режиме двух игроков.
; Вход: текущие MenuSelection, Player*Lives и Joy*Held.
; Побочные эффекты: меняет оба счётчика жизней; при успехе X — номер
; возрождаемого игрока (0/1), а управление передаётся в общий код возрождения.
ShareLifeWithDefeatedPartner:
LA553:  jsr     UpdateHalfSecondPhaseFlag
        lda     MenuSelection
        beq     LA58A
        lda     Player2Lives
        beq     LA575
        cmp     #$02
        bcc     LA58A
        lda     Player1Lives
        bne     LA58A
        lda     Joy1Held
        and     #BUTTON_A
        beq     LA58A
        inc     Player1Lives
        dec     Player2Lives
        ldx     #$00
        jmp     RespawnAfterSharedLife

LA575:  lda     Player1Lives
        cmp     #$02
        bcc     LA58A
        lda     Joy2Held
        and     #BUTTON_A
        beq     LA58A
        inc     Player2Lives
        dec     Player1Lives
        ldx     #$01
        jmp     RespawnAfterSharedLife
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

LA5BF:  lda     $0101,x
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
        sta     $89,x
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
LA612:  lda     $46
        cmp     #$03
        bcc     LA61C
        lda     #$20
        bne     LA61E
LA61C:  lda     #$00
LA61E:  sta     $0101,x
        rts

; Неиндексированный вариант SetIndexedModeExtensionByte для $0101.
SetPlayerOneModeExtensionByte:
LA622:  lda     $46
        cmp     #$03
        bcc     LA62C
        lda     #$20
        bne     LA62E
LA62C:  lda     #$00
LA62E:  sta     $0101
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
LA680:  cpx     #$02
        bcs     LA68A
        jsr     AddScoreDigitsToRecord
        jsr     AwardScoreThresholdLives
LA68A:  rts

        .byte   $FF,$FF,$FF,$FF,$FF
; Ждёт кадр; при удержании A+B первым игроком снимает адрес возврата,
; записывает маркер $AB в $46 и перезапускает игру. Без комбинации обычно возвращается.
HandleResetChord:
LA690:  jsr     WaitForNextFrame
        lda     Joy1Held
        and     #(BUTTON_A | BUTTON_B)
        cmp     #(BUTTON_A | BUTTON_B)
        beq     LA69C
        rts
LA69C:  pla
        pla
        lda     #$AB
        sta     $46
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
; Вход: счётчики $17 и $1F. Выход: C=1, если их сумма равна 3, 6 или 9; иначе C=0.
; Портит A и флаги; X/Y и RAM не меняет.
ShouldRunIntegrityCheck:
LA728:  clc
        lda     $17
        adc     $1F
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

; $A73D..$BF7F не содержит подтверждённых точек входа или статических ссылок.
; Не-$FF участки ниже имеют регулярные размеры и алфавиты, несовместимые с обычным
; потоком 6502-кода; они разделены как данные. Возможный доступ через вычисляемые
; указатели не доказан, поэтому назначение таблиц намеренно не закреплено.
UnreferencedPrg0Data:
UnusedPaddingA73d:
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF

; 40 байт $02..$08. Первые 32 байта совпадают с $AE6C..$AE8B, последние восемь —
; с $AD40..$AD47/$AF40..$AF47. Это составная копия фрагментов таблиц ниже;
; потребитель и исходная размерность не найдены.
UnreferencedSmallValuesA780:
        .byte   $06,$04,$06,$04,$03
        .byte   $06,$05,$06,$05,$05,$04,$06,$06
        .byte   $03,$05,$06,$04,$05,$05,$06,$07
        .byte   $04,$03,$06,$05,$03,$06,$06,$05
        .byte   $06,$03,$06,$05,$02,$07,$06,$06
        .byte   $08,$02,$04

UnusedPaddingA7a8:
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
        .byte   $FF,$FF,$FF

; 91 байт, то есть ровно один используемый проектом формат упакованной карты:
; 13 строк по 14 нибблов, включая padding-ниббл каждой строки. Значения образуют
; регулярное поле из TSA $9,$A,$B,$D,$E, но игровая ссылка на эту карту не найдена.
UnreferencedPackedMapA800:
        .incbin "../build/unused-level-a800.bin"

UnusedPaddingA85b:
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
        .byte   $FF,$FF,$FF,$FF,$FF

; 240 байт можно без остатка разделить на 12 записей по 20 байт. Старшие биты
; похожи на кодирование ObjectAttributes врагов, однако потребитель не найден.
UnreferencedA900Table:
        .byte   $A0,$C0
        .byte   $E0,$A0
        .byte   $A0,$C0
        .byte   $A0,$E0
        .byte   $A0,$E0
        .byte   $C0,$E0
        .byte   $A0,$E0
        .byte   $C0,$A0
        .byte   $A0,$E0
        .byte   $A0,$C0
        .byte   $C0,$A0
        .byte   $E0,$A0
        .byte   $A0,$E0
        .byte   $A0,$E0
        .byte   $E0,$C0
        .byte   $E0,$A0
        .byte   $E0,$C0
        .byte   $A0,$E0
        .byte   $E0,$A0
        .byte   $C0,$E0
        .byte   $E0,$A0
        .byte   $C0,$A0
        .byte   $E0,$A0
        .byte   $E0,$A0
        .byte   $A0,$E0
        .byte   $A0,$E0
        .byte   $E0,$A0
        .byte   $E0,$A0
        .byte   $A0,$A0
        .byte   $E0,$E0
        .byte   $E0,$E0
        .byte   $A0,$A0
        .byte   $A0,$E0
        .byte   $E0,$E0
        .byte   $E0,$A0
        .byte   $A0,$A0
        .byte   $A0,$E0
        .byte   $A0,$E0
        .byte   $E0,$A0
        .byte   $E0,$A0
        .byte   $A0,$A0
        .byte   $E0,$E0
        .byte   $E0,$E0
        .byte   $A0,$A0
        .byte   $A0,$E0
        .byte   $E0,$E0
        .byte   $E0,$A0
        .byte   $A0,$A0
        .byte   $C0,$A2
        .byte   $C2,$C1,$C1,$C0,$A2,$E0,$A0,$C2
        .byte   $E0,$A1,$C1,$A0,$E0,$A2,$C2,$C1
        .byte   $C0,$A2,$C3,$A0,$A1,$C2,$C3,$C0
        .byte   $A1,$E0,$C0,$A1,$C2,$C3,$C7,$A4
        .byte   $A5,$E0,$E0,$C3,$A0,$A1,$C3,$C2
        .byte   $A1,$C0,$E0,$A1,$C0,$C3,$A0,$A2
        .byte   $C3,$C2,$C2,$C0,$A2,$E0,$E0,$A2
        .byte   $C0,$C2,$C3,$C2,$A0,$A2,$C2,$A0
        .byte   $A3,$C3,$C0,$A3,$E0,$C2,$C3,$C2
        .byte   $A0,$A3,$C6,$A4,$A7,$C7,$A3,$C0
        .byte   $C2,$E0,$C0,$C2,$C3,$A3,$C3,$A3
        .byte   $A0,$C2,$C2,$A0,$A3,$C3,$C3,$A0
        .byte   $A3,$C3,$A0,$C3,$C3,$A3,$C3,$A3
        .byte   $A0,$C3,$C3,$A0,$A3,$C3,$C1,$C3
        .byte   $E0,$A3,$C3,$A0,$A3,$C3,$A3,$C3
        .byte   $A0,$C3,$A0,$C3,$C3,$A3,$A7,$C5
        .byte   $C7,$E0,$A0,$A3,$C3,$60,$A0,$60
        .byte   $A3,$C3,$C3,$60,$A0,$A3

UnusedPaddingA9f0:
        .byte   $FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF

; Шесть выровненных по страницам блоков по 140 байт. Значения лежат в диапазоне
; $00..$12. $AD00 и $AF00 совпадают полностью; $AC00/$AE00 — близкие варианты
; с одинаковыми вставками/удалениями. Это данные либо сохранённые копии таблиц,
; но их размерность и назначение не доказаны.
UnreferencedSmallValueTableAa00:
        .byte   $12,$02
        .byte   $00,$00,$02,$04,$00,$0E,$0E,$04
        .byte   $00
        .byte   $02,$0A,$05,$02,$03,$05,$02,$08
        .byte   $05,$07,$02,$09,$02,$03,$04,$06
        .byte   $07,$07,$02,$04,$07,$06,$04,$07
        .byte   $03,$0C,$02,$04,$02,$05,$06,$04
        .byte   $05,$08,$06,$00,$06,$08,$08,$00
        .byte   $04,$0A,$04,$00,$06,$02,$00,$0A
        .byte   $08,$10,$00,$02,$02,$02,$02,$08
        .byte   $08,$04,$02,$06,$08,$04,$08,$04
        .byte   $04,$08,$02,$02,$08,$08,$02,$06
        .byte   $04,$08,$06,$02,$04,$06,$00,$04
        .byte   $0A,$04,$02,$04,$0A,$02,$08,$00
        .byte   $0A,$06,$06,$04,$04,$02,$08,$08
        .byte   $02,$02,$01,$0F,$02,$0A,$04,$00
        .byte   $06,$04,$08,$04,$04,$03,$08,$06
        .byte   $03,$08,$06,$02,$04,$04,$08,$04
        .byte   $04,$04,$0A,$00,$06,$04,$06,$00
        .byte   $0A

UnusedPaddingAa8c:
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF
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
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF

UnreferencedSmallValueTableAb00:
        .byte   $08,$02,$08
        .byte   $02,$06,$04,$04,$06,$08,$04,$06
        .byte   $02,$02,$07,$08,$03,$06,$04,$05
        .byte   $05,$06,$05,$07,$02,$05,$05,$05
        .byte   $05,$04,$05,$07,$04,$06,$05,$04
        .byte   $05,$05,$05,$04,$06,$02,$06,$05
        .byte   $07,$00,$08,$06,$06,$00,$0A,$06
        .byte   $04,$00,$04,$06,$0A,$06,$04,$02
        .byte   $08,$08,$02,$02,$08,$06,$04,$04
        .byte   $06,$04,$02,$04,$0A,$02,$08,$06
        .byte   $04,$02,$02,$0C,$04,$04,$04,$06
        .byte   $06,$02,$04,$0A,$04,$04,$00,$0A
        .byte   $06,$06,$04,$04,$06,$00,$0A,$02
        .byte   $08,$02,$06,$08,$04,$08,$0A,$02
        .byte   $08,$09,$04,$05,$02,$00,$08,$06
        .byte   $06,$04,$0A,$02,$04,$08,$08,$02
        .byte   $02,$04,$02,$0A,$04,$04,$08,$04
        .byte   $04,$00,$0A,$04,$06,$00,$08,$02
        .byte   $0A

UnusedPaddingAb8c:
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF
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
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF

UnreferencedSmallValueTableAc00:
        .byte   $04,$04,$0A
        .byte   $02,$03,$08,$04,$05,$06,$06,$04
        .byte   $04,$06,$05,$04,$05,$03,$06,$05
        .byte   $06,$06,$08,$04,$02,$06,$04,$05
        .byte   $05,$03,$04,$07,$06,$08,$05,$05
        .byte   $02,$04,$06,$02,$08,$04,$08,$06
        .byte   $02,$04,$06,$03,$07,$03,$07,$04
        .byte   $06,$03,$0A,$03,$04,$04,$06,$05
        .byte   $05,$03,$04,$06,$07,$04,$07,$02
        .byte   $07,$03,$02,$08,$07,$04,$0C,$02
        .byte   $02,$03,$04,$03,$0A,$03,$03,$03
        .byte   $0B,$05,$06,$06,$03,$05,$04,$07
        .byte   $04,$03,$07,$04,$06,$06,$02,$08
        .byte   $04,$03,$07,$02,$08,$07,$03,$08
        .byte   $02,$03,$08,$01,$08,$07,$01,$08
        .byte   $04,$06,$04,$06,$04,$03,$06,$05
        .byte   $06,$05,$05,$04,$06,$06,$03,$05
        .byte   $06,$04,$05,$05,$06,$07,$04,$03
        .byte   $06

UnusedPaddingAc8c:
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF
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
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF

UnreferencedSmallValueTableAd00:
        .byte   $03,$03,$03
        .byte   $0B,$05,$06,$06,$03,$05,$04,$07
        .byte   $04,$03,$07,$04,$06,$03,$07,$02
        .byte   $08,$07,$03,$08,$02,$03,$08,$01
        .byte   $08,$07,$01,$08,$04,$06,$04,$06
        .byte   $04,$06,$02,$08,$04,$05,$05,$04
        .byte   $06,$06,$03,$05,$06,$04,$05,$05
        .byte   $06,$07,$04,$03,$06,$05,$03,$06
        .byte   $06,$05,$06,$03,$06,$05,$02,$07
        .byte   $06,$06,$08,$02,$04,$04,$04,$04
        .byte   $08,$03,$08,$04,$05,$04,$04,$08
        .byte   $04,$03,$04,$08,$05,$06,$05,$05
        .byte   $04,$05,$06,$03,$06,$05,$06,$05
        .byte   $04,$05,$06,$07,$02,$04,$05,$03
        .byte   $08,$08,$03,$06,$03,$01,$09,$05
        .byte   $05,$04,$06,$01,$09,$06,$05,$06
        .byte   $03,$04,$06,$04,$06,$04,$07,$03
        .byte   $06,$06,$05,$07,$02,$04,$06,$03
        .byte   $07

UnusedPaddingAd8c:
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF
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
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF

UnreferencedSmallValueTableAe00:
        .byte   $04,$04,$0A
        .byte   $02,$03,$08,$04,$05,$06,$06,$04
        .byte   $04,$06,$05,$04,$05,$03,$06,$05
        .byte   $06,$06,$08,$04,$02,$06,$04,$05
        .byte   $05,$03,$04,$07,$06,$08,$05,$05
        .byte   $02,$04,$08,$06,$02,$04,$06,$03
        .byte   $07,$03,$07,$04,$06,$03,$0A,$03
        .byte   $04,$04,$06,$05,$05,$03,$04,$06
        .byte   $07,$04,$07,$02,$07,$03,$02,$08
        .byte   $07,$04,$0C,$02,$02,$03,$04,$03
        .byte   $0A,$03,$03,$03,$0B,$05,$06,$06
        .byte   $03,$05,$04,$07,$04,$03,$07,$04
        .byte   $06,$03,$07,$02,$08,$07,$03,$08
        .byte   $02,$03,$08,$01,$08,$07,$01,$08
        .byte   $04,$06,$04,$06,$04,$03,$06,$05
        .byte   $06,$05,$05,$04,$06,$06,$03,$05
        .byte   $06,$04,$05,$05,$06,$07,$04,$03
        .byte   $06,$05,$03,$06,$06,$05,$06,$03
        .byte   $06

UnusedPaddingAe8c:
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF
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
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF

; Побайтовая копия UnreferencedSmallValueTableAd00.
UnreferencedSmallValueTableAf00:
        .byte   $03,$03,$03
        .byte   $0B,$05,$06,$06,$03,$05,$04,$07
        .byte   $04,$03,$07,$04,$06,$03,$07,$02
        .byte   $08,$07,$03,$08,$02,$03,$08,$01
        .byte   $08,$07,$01,$08,$04,$06,$04,$06
        .byte   $04,$06,$02,$08,$04,$05,$05,$04
        .byte   $06,$06,$03,$05,$06,$04,$05,$05
        .byte   $06,$07,$04,$03,$06,$05,$03,$06
        .byte   $06,$05,$06,$03,$06,$05,$02,$07
        .byte   $06,$06,$08,$02,$04,$04,$04,$04
        .byte   $08,$03,$08,$04,$05,$04,$04,$08
        .byte   $04,$03,$04,$08,$05,$06,$05,$05
        .byte   $04,$05,$06,$03,$06,$05,$06,$05
        .byte   $04,$05,$06,$07,$02,$04,$05,$03
        .byte   $08,$08,$03,$06,$03,$01,$09,$05
        .byte   $05,$04,$06,$01,$09,$06,$05,$06
        .byte   $03,$04,$06,$04,$06,$04,$07,$03
        .byte   $06,$06,$05,$07,$02,$04,$06,$03
        .byte   $07

UnusedPaddingAf8c:
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF
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
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF

; Ещё шесть page-aligned блоков по 140 байт. Диапазон значений совпадает с
; наблюдаемым кодированием ObjectAttributes ($80/$A0/$C0/$E0 и младшие флаги),
; но без ссылки это остаётся только характеристикой формата. $B300=$B500;
; изменения $B200/$B400 структурно совпадают с изменениями $AC00/$AE00.
UnreferencedAttributeLikeTableB000:
        .byte   $80,$A0
        .byte   $C0,$E0
        .byte   $E0,$A0
        .byte   $C0,$80
        .byte   $80,$A0,$C0,$E0,$C0,$A0,$80,$E0
        .byte   $C0,$E0,$80,$A0,$C0,$A0,$80,$E0
        .byte   $80,$A0,$C0,$80,$C0,$E0,$A0,$80
        .byte   $80,$A0,$C0,$E0,$80,$A0,$C0,$E0
        .byte   $A0,$E0,$C0,$A0,$C0,$A0,$80,$E0
        .byte   $C0,$A0,$80,$E0,$C0,$A0,$80,$E0
        .byte   $80,$C0,$A0,$E0,$80,$C0,$A0,$E0
        .byte   $E0,$A0,$C0,$80,$E0,$80,$C0,$A0
        .byte   $A0,$E0,$80,$C0,$A0,$80,$C0,$E0
        .byte   $C0,$A0,$80,$E0,$A0,$80,$C0,$E0
        .byte   $E0,$80,$C0,$A0,$C0,$E0,$A0,$80
        .byte   $C0,$A0,$80,$E0,$A0,$E0,$80,$C0
        .byte   $C0,$E0,$A0,$80,$A0,$E0,$80,$C0
        .byte   $C0,$A0,$80,$E0,$80,$A0,$C0,$E0
        .byte   $C0,$A0,$E0,$C0,$E0,$80,$C0,$A0
        .byte   $A0,$E0,$C0,$A0,$C0,$A0,$80,$E0
        .byte   $C0,$A0,$E0,$E0

UnusedPaddingB08c:
        .byte   $FF,$FF,$FF,$FF
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
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF

UnreferencedAttributeLikeTableB100:
        .byte   $C0,$A0,$80,$E0,$C0,$A0,$E0,$80
        .byte   $C0,$A0,$80,$E0,$80,$A0,$C0,$E0
        .byte   $80,$E0,$C0,$A0,$80,$A0,$C0,$E0
        .byte   $C0,$A0,$80,$80,$A0,$E0,$C0,$80
        .byte   $C0,$A0,$80,$E0,$C0,$A0,$80,$E0
        .byte   $C0,$E0,$A0,$A0,$80,$A0,$C0,$E0
        .byte   $80,$A0,$C0,$E0,$80,$A0,$C0,$E0
        .byte   $A0,$C0,$80,$E0,$A0,$C0,$80,$E0
        .byte   $C0,$A0,$E0,$80,$C0,$80,$E0,$A0
        .byte   $80,$E0,$A0,$C0,$C0,$80,$A0,$E0
        .byte   $80,$A0,$C0,$E0,$C0,$80,$A0,$E0
        .byte   $C0,$80,$E0,$A0,$A0,$E0,$C0,$80
        .byte   $80,$A0,$C0,$E0,$80,$E0,$A0,$C0
        .byte   $A0,$E0,$C0,$80,$80,$E0,$A0,$C0
        .byte   $80,$A0,$C0,$E0,$C0,$A0,$80,$E0
        .byte   $E0,$A0,$C0,$C0,$C0,$80,$E0,$A0
        .byte   $C0,$E0,$A0,$A0,$80,$A0,$C0,$E0
        .byte   $80,$A0,$C0,$E0

UnusedPaddingB18c:
        .byte   $FF,$FF,$FF,$FF
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
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF

UnreferencedAttributeLikeTableB200:
        .byte   $80,$A1,$E0,$C1,$C1,$A0,$A1,$E0
        .byte   $C1,$E0,$C0,$A1,$E0,$A1,$A0,$C1
        .byte   $C2,$C1,$A1,$80,$A1,$C0,$C1,$C2
        .byte   $A0,$C1,$E0,$A1,$C1,$A0,$A1,$E0
        .byte   $A1,$C0,$C1,$C2,$E0,$C5,$A4,$A5
        .byte   $C0,$A1,$E0,$C2,$A0,$C1,$E0,$A1
        .byte   $C1,$A0,$A2,$E0,$C2,$A1,$C0,$C2
        .byte   $E0,$C1,$C0,$A2,$C1,$A0,$A2,$E0
        .byte   $C0,$A2,$C2,$C1,$C1,$C0,$A2,$E0
        .byte   $A0,$C2,$E0,$A1,$C1,$A0,$E0,$A2
        .byte   $C2,$C1,$C0,$A2,$C3,$A0,$A1,$C2
        .byte   $C3,$C0,$A1,$E0,$C0,$A1,$C2,$C3
        .byte   $C7,$A4,$A5,$E0,$E0,$C3,$A0,$A1
        .byte   $C3,$C2,$A1,$C0,$E0,$A1,$C0,$C3
        .byte   $A1,$A0,$C3,$C2,$A0,$C2,$C3,$A2
        .byte   $C2,$C0,$A2,$E0,$A2,$C0,$C2,$C3
        .byte   $C3,$C2,$A0,$A2,$C0,$C2,$A2,$E0
        .byte   $E0,$C2,$C0,$A2

UnusedPaddingB28c:
        .byte   $FF,$FF,$FF,$FF
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
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF

UnreferencedAttributeLikeTableB300:
        .byte   $C2,$C1,$C0,$A2,$C3,$A0,$A1,$C2
        .byte   $C3,$C0,$A1,$E0,$C0,$A1,$C2,$C3
        .byte   $E0,$C3,$A0,$A1,$C3,$C2,$A1,$C0
        .byte   $E0,$A1,$C0,$C3,$A1,$A0,$C3,$C2
        .byte   $A0,$C2,$C3,$A2,$C7,$A4,$A5,$E0
        .byte   $A2,$C0,$C2,$C3,$C3,$C2,$A0,$A2
        .byte   $C0,$C2,$A2,$E0,$E0,$C2,$C0,$A2
        .byte   $C2,$A0,$A2,$C3,$A0,$A2,$C3,$C2
        .byte   $C2,$C0,$A2,$E0,$E0,$A2,$C0,$C2
        .byte   $C3,$C2,$A0,$A2,$C2,$A0,$A3,$C3
        .byte   $C0,$A3,$E0,$C2,$C3,$C2,$A0,$A3
        .byte   $A3,$C0,$C2,$E0,$C0,$C2,$C3,$A3
        .byte   $C6,$A4,$A7,$C7,$C2,$A0,$A3,$C3
        .byte   $C0,$C2,$E0,$A3,$A3,$C0,$C2,$E0
        .byte   $C3,$A3,$A0,$C2,$E0,$C2,$A0,$A3
        .byte   $C3,$C1,$A3,$E0,$A0,$C3,$C3,$A3
        .byte   $A0,$A3,$C3,$C3,$C3,$A0,$A3,$C3
        .byte   $A0,$C3,$C3,$A3

UnusedPaddingB38c:
        .byte   $FF,$FF,$FF,$FF
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
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF

UnreferencedAttributeLikeTableB400:
        .byte   $80,$A1,$E0,$C1,$C1,$A0,$A1,$E0
        .byte   $C1,$E0,$C0,$A1,$E0,$A1,$A0,$C1
        .byte   $C2,$C1,$A1,$80,$A1,$C0,$C1,$C2
        .byte   $A0,$C1,$E0,$A1,$C1,$A0,$A1,$E0
        .byte   $A1,$C0,$C1,$C2,$C0,$A1,$E0,$C2
        .byte   $A0,$C1,$E0,$A1,$C1,$A0,$A2,$E0
        .byte   $C2,$A1,$C0,$C2,$E0,$C1,$C0,$A2
        .byte   $C1,$A0,$A2,$E0,$C0,$A2,$C2,$C1
        .byte   $C1,$C0,$A2,$E0,$A0,$C2,$E0,$A1
        .byte   $C1,$A0,$E0,$A2,$C2,$C1,$C0,$A2
        .byte   $C3,$A0,$A1,$C2,$C3,$C0,$A1,$E0
        .byte   $C0,$A1,$C2,$C3,$E0,$C3,$A0,$A1
        .byte   $C3,$C2,$A1,$C0,$E0,$A1,$C0,$C3
        .byte   $A1,$A0,$C3,$C2,$A0,$C2,$C3,$A2
        .byte   $C2,$C0,$A2,$E0,$A2,$C0,$C2,$C3
        .byte   $C3,$C2,$A0,$A2,$C0,$C2,$A2,$E0
        .byte   $E0,$C2,$C0,$A2,$C2,$A0,$A2,$C3
        .byte   $A0,$A2,$C3,$C2

UnusedPaddingB48c:
        .byte   $FF,$FF,$FF,$FF
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
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF

; Побайтовая копия UnreferencedAttributeLikeTableB300.
UnreferencedAttributeLikeTableB500:
        .byte   $C2,$C1,$C0,$A2,$C3,$A0,$A1,$C2
        .byte   $C3,$C0,$A1,$E0,$C0,$A1,$C2,$C3
        .byte   $E0,$C3,$A0,$A1,$C3,$C2,$A1,$C0
        .byte   $E0,$A1,$C0,$C3,$A1,$A0,$C3,$C2
        .byte   $A0,$C2,$C3,$A2,$C7,$A4,$A5,$E0
        .byte   $A2,$C0,$C2,$C3,$C3,$C2,$A0,$A2
        .byte   $C0,$C2,$A2,$E0,$E0,$C2,$C0,$A2
        .byte   $C2,$A0,$A2,$C3,$A0,$A2,$C3,$C2
        .byte   $C2,$C0,$A2,$E0,$E0,$A2,$C0,$C2
        .byte   $C3,$C2,$A0,$A2,$C2,$A0,$A3,$C3
        .byte   $C0,$A3,$E0,$C2,$C3,$C2,$A0,$A3
        .byte   $A3,$C0,$C2,$E0,$C0,$C2,$C3,$A3
        .byte   $C6,$A4,$A7,$C7,$C2,$A0,$A3,$C3
        .byte   $C0,$C2,$E0,$A3,$A3,$C0,$C2,$E0
        .byte   $C3,$A3,$A0,$C2,$E0,$C2,$A0,$A3
        .byte   $C3,$C1,$A3,$E0,$A0,$C3,$C3,$A3
        .byte   $A0,$A3,$C3,$C3,$C3,$A0,$A3,$C3
        .byte   $A0,$C3,$C3,$A3

; Остаток $B58C..$BF7F заполнен $FF. После него по $BF80 начинается
; статически достижимый RunDeferredIntegrityGuard.
UnusedPaddingB58c:
        .byte   $FF,$FF,$FF,$FF
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
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
; Единственный статически достижимый entry point этого хвоста банка.
; Запускает отложенную проверку контрольной суммы из второго PRG-банка.
; В обычном случае возвращается; при несовпадении проверка может сменить поток управления.
RunDeferredIntegrityGuard:
LBF80:
        jsr     MaybeEnforceRuntimeChecksum
        rts

; Ниже лежат неиспользуемые копии/заготовки обработчиков расширения. Статических
; вызовов нет. $BF93..$BFBA побайтно совпадает с активным кодом $FF93..$FFBA;
; $BF86..$BF92 — с $FF86..$FF92, но перед копией добавлено STA $00.

; Вход: A сохраняется в $00, X — объект. Инициализирует три поля объекта значением $40,
; затем переходит в общий обработчик LE77A. Портит A и флаги; X сохраняет до перехода.
InitializeObjectExtensionPrototype:
LBF84:  sta     $00
        lda     #$40
        sta     $0101,x
        sta     $0178,x
        sta     ObjectAttributes,x
        jmp     AdvancePlayerCollisionPassOrBeginEnemyPass

; Возвращает A=$20, если $46 отрицателен, иначе A=0; всегда поднимает флаг $0307.
GetModeExtensionBitsPrototype:
LBF93:  lda     #$01
        sta     $0307
        lda     $46
        bmi     LBF9F
        lda     #$00
        rts
LBF9F:  lda     #$20
        rts

        .byte   $01
; Записывает A в ObjectAttributes,X и переходит к общему хвосту столкновений.
StoreObjectAttributesPrototype:
LBFA3:  sta     ObjectAttributes,x
        jmp     AdvancePlayerCollisionPassOrBeginEnemyPass

; Очищает поле $0170,X для состояния $73, затем продолжает обход по $5A.
; Выход: $5A уменьшен; портит A и флаги, X не меняет до перехода.
AdvanceExtensionObjectLoopPrototype:
LBFA8:  lda     ObjectState,x
        cmp     #$73
        bne     LBFB3
        lda     #$00
        sta     $0170,x
LBFB3:  dec     $5A
        bpl     LBFB8
        rts
LBFB8:  jmp     CheckNextPlayerTank

; Первые пять байт совпадают с ClearObjectExtensionState по $FFBB, но вместо
; завершающего RTS по $BFC0 начинается заполнение $FF.
ClearObjectExtensionPrototype:
LBFBB:  lda     #$00
        sta     $0170,x
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF

; End of "PRG0_REST" segment
.code

