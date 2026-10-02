; Форматирование, сравнение и начисление счёта ($D934-$DA2A).
; Файл включается из ppu.s в исходной позиции, чтобы сохранять адреса ROM.
; Score record состоит из семи отдельных digits 0..9 от миллионов к единицам
; и $FF; представимый диапазон 0000000..9999999.

ScoreDigitCount = $07
ScoreRecordSize = $08
ScoreTerminator = $FF
ScoreDecimalBase        = 10
ZeroPageRecordBase     = $00
ScoreLastDigitOffset   = $06
ScoreTerminatorOffset  = $07
PackedScoreDigitMask   = $0F
OneThousandScoreDigit  = $01
LargeScoreRasterX      = $10
LargeScoreRasterY      = $64
LargeScoreTileBias     = $30
LargeScoreGlyphAdvance = $20

; Выбирает видимый suffix цифровой записи в zero page.
; Вход: Y=адрес первой рассматриваемой цифры, X=начальная tile-column; далее
; должна находиться последовательность цифр и достижимый $FF. Ведущие нули
; увеличивают X/Y. При первой цифре 1..9 она становится началом suffix. Если
; все цифры до терминатора нулевые, DigitBlankMode=0 отступает на две позиции
; и выводит "00", а любое ненулевое значение — на одну и выводит "0".
; Вызывающий обязан предоставить перед $FF достаточно цифр для этого отступа;
; bounds check нет, zero-page Y при ошибке циклически переполняется.
;
; Выход: ScratchPtr=$00:Y, Y=первая видимая цифра, X сдвинут так же, A=0,
; N=0/Z=1. C=0 для найденной ненулевой цифры и C=1 для all-zero/terminator
; пути; V сохраняется. Запись, DigitBlankMode, PPU/OAM/audio/RNG не меняются.
SelectVisibleDigits:
SkipNextLeadingZero:
LD934:  lda     ZeroPageRecordBase,y
        bne     HandleFirstVisibleDigit
        iny
        inx
        jmp     SkipNextLeadingZero

HandleFirstVisibleDigit:
LD93E:  cmp     #ScoreTerminator
        bne     StoreVisibleDigitsPointer
        lda     DigitBlankMode
        bne     AdjustBlankDigitPosition
        dex
        dey
AdjustBlankDigitPosition:
LD948:  dex
        dey
StoreVisibleDigitsPointer:
LD94A:  lda     #$00
        sta     ScratchPtrHi
        sty     ScratchPtrLo
        rts

; Рисует семизначный HighScore крупными CHR-знаками в nametable shadow.
; Формат record: digits миллионов..единиц в $3D..$43, затем $FF. Ведущие нули
; не рисуются, но сдвигают RasterStringX на $20 каждый; последующие нули после
; первой значащей цифры рисуются. Полностью нулевая запись доходит указателем до
; терминатора и не рисует даже один ноль. Старые glyphs в пропущенной области
; не очищаются, поэтому штатный caller предварительно очищает shadow.
;
; Выход для валидной 7-digit/$FF записи: RasterStringX=$F0,
; RasterStringY=$64, TileTranslationOffset=0, AuxPtr указывает на первую
; значащую цифру либо терминатор, A=0, N=0/Z=1/C=1; Y — offset терминатора
; относительно AuxPtr, X не определён, V зависит от raster helper. Меняет
; raster scratch, shadow, PPU_ADDR и внутренний PPU read buffer/address;
; HighScore, PPU queue, OAM/audio/RNG не трогает. Rendering/NMI должны быть
; выключены по контракту CHR rasterizer. Все digits должны быть 0..9, иначе
; выбираются посторонние CHR tiles.
RenderLargeScoreRecord:
LD951:  lda     #LargeScoreRasterX
        sta     RasterStringX
        lda     #LargeScoreRasterY
        sta     RasterStringY
        lda     #LargeScoreTileBias
        sta     TileTranslationOffset
        ldy     #HighScore
SkipNextHighScoreLeadingZero:
LD95F:  lda     ZeroPageRecordBase,y
        bne     RasterizeVisibleHighScore
        iny
        lda     RasterStringX
        clc
        adc     #LargeScoreGlyphAdvance
        sta     RasterStringX
        jmp     SkipNextHighScoreLeadingZero

RasterizeVisibleHighScore:
LD96F:  lda     #$00
        sta     AuxPtrHi
        sty     AuxPtrLo
        jsr     RasterizeTileStringToShadow
        lda     #$00
        sta     TileTranslationOffset
        rts

; Сравнивает fixed-length семь digits Player1Score, Player2Score и HighScore
; лексикографически от миллионов к единицам. Используется N результата CMP
; (BMI), а не carry, поэтому корректность требует каждую цифру 0..9: тогда
; разность лежит в -9..9. Терминаторы не читаются и не копируются; HighScore+7
; должен уже содержать $FF.
;
; Только строго большая запись копируется. Сначала проверяется P1, затем P2 уже
; против возможного результата P1: при равенстве игроков побеждает P1.
; Выход: Y=1 для P1, $FF для P2, 0 если обновления не было. X=7 после полного
; равенства/копирования P2 либо индекс первой меньшей цифры P2; A и flags
; зависят от пути. Меняет только семь цифр HighScore; player records,
; terminator, PPU/OAM/audio/RNG не трогает.
UpdateHighScoreRecord:
LD97D:  ldx     #$00
        ldy     #$00
ComparePlayer1ScoreDigit:
LD981:  lda     Player1Score,x
        cmp     HighScore,x
        bne     EvaluatePlayer1ScoreDifference
        inx
        cpx     #ScoreDigitCount
        beq     ComparePlayer2Score
        jmp     ComparePlayer1ScoreDigit

EvaluatePlayer1ScoreDifference:
LD98F:  bmi     ComparePlayer2Score
        ldx     #$00
CopyNextPlayer1ScoreDigit:
LD993:  lda     Player1Score,x
        sta     HighScore,x
        inx
        cpx     #ScoreDigitCount
        bne     CopyNextPlayer1ScoreDigit
        ldy     #$01
ComparePlayer2Score:
LD99E:  ldx     #$00
ComparePlayer2ScoreDigit:
LD9A0:  lda     Player2Score,x
        cmp     HighScore,x
        bne     EvaluatePlayer2ScoreDifference
        inx
        cpx     #ScoreDigitCount
        beq     FinishHighScoreUpdate
        jmp     ComparePlayer2ScoreDigit

EvaluatePlayer2ScoreDifference:
LD9AE:  bmi     FinishHighScoreUpdate
        ldx     #$00
CopyNextPlayer2ScoreDigit:
LD9B2:  lda     Player2Score,x
        sta     HighScore,x
        inx
        cpx     #ScoreDigitCount
        bne     CopyNextPlayer2ScoreDigit
        ldy     #$FF
FinishHighScoreUpdate:
LD9BD:  rts

; Прибавляет семизначный ScoreIncrementDigits к score record игрока.
; Вход: X=record index 0/1. Три ASL зашивают stride 8 и выбирают соответственно
; Player1Score либо Player2Score; другое значение индексирует соседнюю zero-page
; RAM без bounds check. Обе записи должны содержать digits 0..9: код вычитает
; 10 не более одного раза и использует N результата CMP, что корректно только
; для суммы digit+digit+carry в диапазоне 0..19.
;
; Сложение идёт от единиц к миллионам; overflow теряется, поэтому счёт хранится
; по модулю 10^7. Терминатор записи и ScoreIncrementDigits не меняются.
; Выход: A=новая цифра миллионов, Y=$FF, X=$FF для P1 либо $07 для P2,
; C=потерянный carry за миллионами, N=1/Z=0; V зависит от арифметики старшей
; цифры. PPU/OAM/audio/RNG и HighScore не затрагиваются.
AddScoreDigitsToRecord:
LD9BE:  txa
        asl     a
        asl     a
        asl     a
        clc
        adc     #(ScoreDigitCount-1)
        tax
        ldy     #(ScoreDigitCount-1)
        clc
AddNextScoreDigit:
LD9C9:  lda     ScoreIncrementDigits,y
        adc     Player1Score,x
        cmp     #ScoreDecimalBase
        bmi     ClearScoreDigitCarry
        sec
        sbc     #ScoreDecimalBase
        sec
        jmp     StoreScoreDigit

ClearScoreDigitCarry:
LD9D9:  clc
StoreScoreDigit:
LD9DA:  sta     Player1Score,x
        dex
        dey
        bpl     AddNextScoreDigit
        rts

; Готовит восьмибайтный ScoreIncrementDigits из packed-decimal A=$HT.
; Для A!=0 high nibble H становится цифрой сотен, low nibble T — десятков,
; единицы остаются 0: численное приращение равно 100*H+10*T. Оба nibble должны
; быть 0..9; проверки нет, а AddScoreDigitsToRecord не нормализует произвольные
; hex digits. A=$00 — зарезервированный special case 1000, а не нулевая награда.
;
; Всегда сначала записывает семь нулей и $FF, сохраняет исходный A в
; ByteToDecimalInput. Выход: X=ScoreIncrementDigits, Y сохранён. Для nonzero
; A=H, N=0, Z по H, C=исходный bit3; для special case A=1, N=0/Z=0 и C
; сохраняется от входа. V сохраняется на обоих путях. Меняет только
; ByteToDecimalInput и increment record;
; score records, PPU/OAM/audio/RNG не трогает.
PreparePackedScoreIncrement:
LD9E1:  sta     ByteToDecimalInput
        ldx     #ScoreIncrementDigits
        jsr     ResetEightByteRecord
        lda     ByteToDecimalInput
        beq     PrepareOneThousandPointIncrement
        and     #PackedScoreDigitMask
        sta     DecimalTens
        lda     ByteToDecimalInput
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        sta     DecimalHundreds
        rts

PrepareOneThousandPointIncrement:
LD9F9:  lda     #OneThousandScoreDigit
        sta     ScoreIncrementThousands
        rts

; Инициализирует zero-page record: семь нулей и завершающий $FF.
; Вход: X=base. Пишет ровно восемь байтов через zero-page indexed addressing;
; при X>$F8 адреса циклически переходят через $FF->$00, bounds check нет.
; Выход: A=$FF, N=1/Z=0; C/V и X/Y сохраняются. Другую RAM и
; PPU/OAM/audio/RNG не меняет.
ResetEightByteRecord:  lda     #$00
        sta     ZeroPageRecordBase,x
        sta     $01,x
        sta     $02,x
        sta     $03,x
        sta     $04,x
        sta     $05,x
        sta     ScoreLastDigitOffset,x
        lda     #ScoreTerminator
        sta     ScoreTerminatorOffset,x
        rts

; Преобразует unsigned A=0..255 в display record ScoreIncrementDigits.
; Сначала создаёт [0,0,0,0,0,0,0,$FF], затем ByteToDecimalDigits записывает
; сотни/десятки/единицы в offsets 4..6; числовой диапазон результата 000..255.
; Выход: A=ones, X=ScoreIncrementDigits, Y сохранён, ByteToDecimalInput=input;
; C=0/N=1/Z=0 от финального CMP #10, V по контракту converter-а.
; PPU/OAM/audio/RNG не затрагиваются.
ByteToDisplayDigits:
LDA13:  sta     ByteToDecimalInput
        ldx     #ScoreIncrementDigits
        jsr     ResetEightByteRecord
        jmp     ByteToDecimalDigits

; Статически неиспользуемый вход с намеренным overlap инструкций; назначение не
; доказано. Сначала удваивает A. Если ASL не дал carry, сразу пишет doubled byte
; в DecimalOnes без decimal normalization. При carry вычитает 10, один раз
; увеличивает DecimalTens и прыгает на $DA1C — high operand byte $C0 предыдущего
; JMP, который вместе с байтом $0A по адресу $DA1D декодируется как CPY #$0A.
; При Y<10 этот скрытый CPY направляет BCC к StoreDecimalOnes. При Y>=10 BCC не
; выполняется, а неизменяемый Y заставляет бесконечно повторять SBC #10/INC.
; Безопасного общего decimal API этот entry не образует; производной работе не
; следует вызывать его без воспроизведения точного overlapped layout.
UnreferencedDoubleDecimalDigit:
LDA1D:  asl     a
        bcc     StoreDecimalOnes
        sec
        sbc     #ScoreDecimalBase
        inc     DecimalTens
        jmp     $DA1C                 ; Хаковый вход внутрь предыдущего JMP.
StoreDecimalOnes:
LDA28:  sta     DecimalOnes
        rts
