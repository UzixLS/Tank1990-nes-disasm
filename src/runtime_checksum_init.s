; Инициализация runtime-проверки контрольной суммы ($D2F8-$D333).

RuntimeChecksumBlockSize     = $07
RuntimeChecksumExpectedValue = $CD
RuntimeChecksumClassicBlock1 = ClassicLevels + $0647
RuntimeChecksumClassicBlock2 = ClassicLevels + $0789

; Инициализирует runtime guard: последовательно XOR-ит два семибайтных окна
; внутри ClassicLevels ($F677 и $F7B9) и RuntimeChecksumFailureTarget в
; RuntimeChecksumActual, затем записывает $CD в RuntimeChecksumExpected.
; Структурное назначение двух окон карт отдельно не установлено.
; ScratchPtr остаётся равным RuntimeChecksumFailureTarget: при позднем
; несовпадении guard использует его как адрес косвенного перехода.
; Выход: A=RuntimeChecksumExpectedValue, RuntimeChecksumExpected=A,
; RuntimeChecksumActual=совокупный XOR, ScratchPtr=RuntimeChecksumFailureTarget,
; Y=$FF. X и проверяемые данные сохраняются.
InitializeRuntimeChecksumGuard:
LD2F8:  lda     #$00
        sta     RuntimeChecksumActual
        lda     #<RuntimeChecksumClassicBlock1
        sta     ScratchPtrLo
        lda     #>RuntimeChecksumClassicBlock1
        sta     ScratchPtrHi
        jsr     XorSevenByteBlock
        lda     #<RuntimeChecksumClassicBlock2
        sta     ScratchPtrLo
        lda     #>RuntimeChecksumClassicBlock2
        sta     ScratchPtrHi
        jsr     XorSevenByteBlock
        lda     #<RuntimeChecksumFailureTarget
        sta     ScratchPtrLo
        lda     #>RuntimeChecksumFailureTarget
        sta     ScratchPtrHi
        jsr     XorSevenByteBlock
        lda     #RuntimeChecksumExpectedValue
; Legacy screen helper starts at the operand byte of the following zero-page
; STA and treats machine code from there as a $FF-terminated tile stream.
; The +1 is intentional: the STA opcode itself is at the current address.
LegacyChecksumCodeStreamStart = * + 1
        sta     RuntimeChecksumExpected
        rts

; Альтернативный вход: принимает seed в A, записывает его в
; RuntimeChecksumActual и без отдельного JSR проваливается в XorSevenByteBlock.
; PHA/PLA сохраняют баланс стека; восстановленный A сразу заменяется первым
; байтом блока. ScratchPtr должен быть задан вызывающим; RuntimeChecksumExpected
; не меняется. Выход и остальные побочные эффекты — как у XorSevenByteBlock.
SeedAndXorSevenByteBlock:
LD322:  pha
        sta     RuntimeChecksumActual
        pla
; XOR-ит RuntimeChecksumBlockSize байтов (ScratchPtr)+6..0 в
; RuntimeChecksumActual, начиная с уже находящегося там seed.
; Выход: A=RuntimeChecksumActual=результат, Y=$FF; ScratchPtr, X, источник
; и стек сохраняются. Портит флаги.
XorSevenByteBlock:
LD326:  ldy     #(RuntimeChecksumBlockSize-1)
XorNextRuntimeChecksumByte:
LD328:  lda     (ScratchPtrLo),y
        eor     RuntimeChecksumActual
        sta     RuntimeChecksumActual
        dey
        bpl     XorNextRuntimeChecksumByte
        rts

; $D332 завершает описанный выше поток с $D320; отдельной статической ссылки на него нет.
LegacyChecksumCodeStreamEnd:
LD332:  .byte   $20,$FF
