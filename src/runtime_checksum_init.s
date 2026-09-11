; Инициализация runtime-проверки контрольной суммы ($D2F8-$D333).

; Инициализирует проверку целостности во время игры: XOR-ит по семь байтов из
; $F677, $F7B9 и RuntimeChecksumFailureTarget в $8D, затем кладёт ожидаемое значение $CD в $8C.
; ScratchPtr остаётся равным RuntimeChecksumFailureTarget; при позднем несовпадении $8D/$8C код
; использует именно его как адрес косвенного перехода.
; Выход: A=$CD, $8C=$CD, $8D=вычисленный XOR, ScratchPtr=RuntimeChecksumFailureTarget, Y=$FF.
; X не меняется. Назначение проверяемых семибайтных областей отдельно не доказано.
InitializeRuntimeChecksumGuard:
LD2F8:  lda     #$00
        sta     RuntimeChecksumActual
        lda     #$77
        sta     ScratchPtrLo
        lda     #$F6
        sta     ScratchPtrHi
        jsr     XorSevenByteBlock
        lda     #$B9
        sta     ScratchPtrLo
        lda     #$F7
        sta     ScratchPtrHi
        jsr     XorSevenByteBlock
        lda     #<RuntimeChecksumFailureTarget
        sta     ScratchPtrLo
        lda     #>RuntimeChecksumFailureTarget
        sta     ScratchPtrHi
        jsr     XorSevenByteBlock
        lda     #$CD
; Legacy screen helper starts at the operand byte of the following zero-page
; STA and treats machine code from there as a $FF-terminated tile stream.
; The +1 is intentional: the STA opcode itself is at the current address.
LegacyChecksumCodeStreamStart = * + 1
        sta     RuntimeChecksumExpected
        rts

; Альтернативный вход: заменяет текущий XOR seed $8D входным A и затем
; обрабатывает семь байтов по ScratchPtr. PHA/PLA сохраняют баланс стека;
; восстановленный A сразу заменяется первым байтом блока.
SeedAndXorSevenByteBlock:
LD322:  pha
        sta     RuntimeChecksumActual
        pla
; XOR-ит (ScratchPtr)+6..0 в аккумулятор $8D.
; Вход: ScratchPtr; $8D — предыдущий seed. Выход: A=$8D=XOR, Y=$FF;
; ScratchPtr и X сохраняются.
XorSevenByteBlock:
LD326:  ldy     #$06
LD328:  lda     (ScratchPtrLo),y
        eor     RuntimeChecksumActual
        sta     RuntimeChecksumActual
        dey
        bpl     LD328
        rts

; $D332 завершает описанный выше поток с $D320; отдельной статической ссылки на него нет.
LegacyChecksumCodeStreamEnd:
LD332:  .byte   $20,$FF
