; Инициализация runtime-проверки контрольной суммы ($D2F8-$D333).

RuntimeChecksumBlockSize     = $07
RuntimeChecksumExpectedValue = $CD
RuntimeChecksumClassicBlock1 = ClassicLevels + $0647
RuntimeChecksumClassicBlock2 = ClassicLevels + $0789

; Инициализирует runtime guard: последовательно XOR-ит три семибайтных окна:
;   $F677..$F67D внутри ClassicLevels  -> $DB;
;   $F7B9..$F7BF внутри ClassicLevels  -> $04;
;   $C5C9..$C5CF variant-menu header   -> $12.
; С накоплением от нуля получается $DB^$04^$12=$CD; это значение остаётся в
; RuntimeChecksumActual, а literal $CD записывается в RuntimeChecksumExpected.
; На выходе ScratchPtr равен RuntimeChecksumInitialJumpTarget, но это лишь
; начальное значение: gameplay helpers свободно перезаписывают volatile pointer,
; а поздний guard его не восстанавливает перед косвенным переходом.
; Выход: A=RuntimeChecksumExpectedValue, RuntimeChecksumExpected=A,
; RuntimeChecksumActual=совокупный XOR,
; ScratchPtr=RuntimeChecksumInitialJumpTarget,
; Y=$FF, N=1/Z=0; C/V и X сохраняются. PPU/OAM/audio/RNG и проверяемые данные
; не меняет. При изменении окон нужно обновить ожидаемую сумму,
; при переносе — константы указателей.
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
        lda     #<RuntimeChecksumInitialJumpTarget
        sta     ScratchPtrLo
        lda     #>RuntimeChecksumInitialJumpTarget
        sta     ScratchPtrHi
        jsr     XorSevenByteBlock
        lda     #RuntimeChecksumExpectedValue
; Legacy-обработчик экрана начинает строковый поток с operand следующего
; zero-page STA ($8C по адресу $D320) и трактует машинный код до $D332 как
; $FF-терминированные tiles. Смещение +1 намеренно: по текущему адресу $D31F
; находится opcode STA. Рефакторинг/перемещение этого кода меняет одновременно
; исполняемую процедуру и legacy screen asset; label должен следовать operand.
LegacyChecksumCodeStreamStart = * + 1
        sta     RuntimeChecksumExpected
        rts

; Альтернативный, статически неиспользуемый вход: принимает seed в A, записывает его в
; RuntimeChecksumActual и без отдельного JSR проваливается в XorSevenByteBlock.
; PHA/PLA сохраняют баланс стека; восстановленный A сразу заменяется первым
; байтом блока. ScratchPtr должен быть задан вызывающим; RuntimeChecksumExpected
; не меняется. Выход и остальные побочные эффекты — как у XorSevenByteBlock;
; источник может быть любым семибайтным readable window, bounds check нет.
SeedAndXorSevenByteBlock:
LD322:  pha
        sta     RuntimeChecksumActual
        pla
; XOR-ит RuntimeChecksumBlockSize байтов (ScratchPtr)+6..0 в
; RuntimeChecksumActual, начиная с уже находящегося там seed.
; Выход: A=RuntimeChecksumActual=результат, Y=$FF, N=1/Z=0 независимо от A;
; C/V, ScratchPtr, X, источник и глубина стека сохраняются. PPU/OAM/audio/RNG
; не затрагивает. Именно DEY 0->$FF задаёт финальные N/Z, не checksum byte.
XorSevenByteBlock:
LD326:  ldy     #(RuntimeChecksumBlockSize-1)
XorNextRuntimeChecksumByte:
LD328:  lda     (ScratchPtrLo),y
        eor     RuntimeChecksumActual
        sta     RuntimeChecksumActual
        dey
        bpl     XorNextRuntimeChecksumByte
        rts

; $D332 ($20) — последний tile legacy-потока с $D320; следующий ROM byte $D333
; равен $FF и служит terminator. Отдельной исполняемой ссылки на эти data bytes нет.
LegacyChecksumCodeStreamEnd:
LD332:  .byte   $20,$FF
