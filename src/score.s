; Форматирование, сравнение и начисление счёта ($D934-$DA2A).
; Файл включается из ppu.s в исходной позиции, чтобы сохранять адреса ROM.

; Подавляет ведущие нули в нулевой странице и готовит указатель на печатаемую
; часть цифровой $FF-терминированной записи. Вход: Y -- адрес первой цифры,
; X -- начальная колонка, DigitBlankMode -- режим сдвига пустого числа.
; Выход: ScratchPtr=$00:Y, X сдвинут на число пропущенных знаков, A=0.
; Саму запись не меняет.
SelectVisibleDigits:
SkipNextLeadingZero:
LD934:  lda     $00,y
        bne     HandleFirstVisibleDigit
        iny
        inx
        jmp     SkipNextLeadingZero

HandleFirstVisibleDigit:
LD93E:  cmp     #$FF
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

; Рисует текущую семизначную запись HighScore крупными CHR-знаками.
; Ведущие нули смещают начало на $20 пикселей. Использует CHR bias $30 и
; позицию ($10,$64). Меняет A/X/Y, AuxPtr, RasterStringX/Y,
; TileTranslationOffset и области RasterizeTileStringToShadow.
RenderLargeScoreRecord:
LD951:  lda     #$10
        sta     RasterStringX
        lda     #$64
        sta     RasterStringY
        lda     #$30
        sta     TileTranslationOffset
        ldy     #HighScore
SkipNextHighScoreLeadingZero:
LD95F:  lda     $00,y
        bne     RasterizeVisibleHighScore
        iny
        lda     RasterStringX
        clc
        adc     #$20
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

; Сравнивает две семизначные записи Player1Score/Player2Score с HighScore.
; Сравнение лексикографическое от старшей цифры; большая запись копируется в
; HighScore. Возвращает Y=1, если рекорд обновил P1; Y=$FF -- P2; Y=0 -- никто.
; A/X и флаги содержат промежуточный результат последнего сравнения/копирования.
UpdateHighScoreRecord:
LD97D:  ldx     #$00
        ldy     #$00
ComparePlayer1ScoreDigit:
LD981:  lda     Player1Score,x
        cmp     HighScore,x
        bne     EvaluatePlayer1ScoreDifference
        inx
        cpx     #$07
        beq     ComparePlayer2Score
        jmp     ComparePlayer1ScoreDigit

EvaluatePlayer1ScoreDifference:
LD98F:  bmi     ComparePlayer2Score
        ldx     #$00
CopyNextPlayer1ScoreDigit:
LD993:  lda     Player1Score,x
        sta     HighScore,x
        inx
        cpx     #$07
        bne     CopyNextPlayer1ScoreDigit
        ldy     #$01
ComparePlayer2Score:
LD99E:  ldx     #$00
ComparePlayer2ScoreDigit:
LD9A0:  lda     Player2Score,x
        cmp     HighScore,x
        bne     EvaluatePlayer2ScoreDifference
        inx
        cpx     #$07
        beq     FinishHighScoreUpdate
        jmp     ComparePlayer2ScoreDigit

EvaluatePlayer2ScoreDifference:
LD9AE:  bmi     FinishHighScoreUpdate
        ldx     #$00
CopyNextPlayer2ScoreDigit:
LD9B2:  lda     Player2Score,x
        sta     HighScore,x
        inx
        cpx     #$07
        bne     CopyNextPlayer2ScoreDigit
        ldy     #$FF
FinishHighScoreUpdate:
LD9BD:  rts

; Прибавляет семизначное десятичное ScoreIncrementDigits к записи игрока.
; Вход: X -- индекс записи (0 -> Player1Score, 1 -> Player2Score).
; Сложение идёт от младшей цифры с переносом по основанию 10; переполнение за
; семь цифр теряется. Выход X указывает на байт перед записью, Y=$FF.
AddScoreDigitsToRecord:
LD9BE:  txa
        asl     a
        asl     a
        asl     a
        clc
        adc     #$06
        tax
        ldy     #$06
        clc
AddNextScoreDigit:
LD9C9:  lda     ScoreIncrementDigits,y
        adc     Player1Score,x
        cmp     #$0A
        bmi     ClearScoreDigitCarry
        sec
        sbc     #$0A
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

; Готовит в ScoreIncrementDigits приращение счёта из упакованного десятичного A:
; старший ниббл -> DecimalHundreds, младший -> DecimalTens. Для A=0 специально
; записывает 1 в ScoreIncrementThousands. Меняет A/X, ByteToDecimalInput и
; ScoreIncrementDigits; Y не меняет.
PreparePackedScoreIncrement:
LD9E1:  sta     ByteToDecimalInput
        ldx     #ScoreIncrementDigits
        jsr     ResetEightByteRecord
        lda     ByteToDecimalInput
        beq     PrepareOneThousandPointIncrement
        and     #$0F
        sta     DecimalTens
        lda     ByteToDecimalInput
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        sta     DecimalHundreds
        rts

PrepareOneThousandPointIncrement:
LD9F9:  lda     #$01
        sta     ScoreIncrementThousands
        rts

; Инициализирует восьмибайтовую запись: семь нулей и завершающий $FF.
; Вход: X -- базовый адрес в нулевой странице. Выход A=$FF; X/Y не меняются.
ResetEightByteRecord:  lda     #$00
        sta     $00,x
        sta     $01,x
        sta     $02,x
        sta     $03,x
        sta     $04,x
        sta     $05,x
        sta     Joy1Held,x
        lda     #$FF
        sta     Joy2Held,x
        rts

; Преобразует беззнаковый байт A в DecimalHundreds/Tens/Ones,
; предварительно обнуляя ScoreIncrementDigits. Выход A=единицы,
; X=ScoreIncrementDigits; Y не меняется.
ByteToDisplayDigits:
LDA13:  sta     ByteToDecimalInput
        ldx     #ScoreIncrementDigits
        jsr     ResetEightByteRecord
        jmp     ByteToDecimalDigits

; Отдельных ссылок на этот вход не найдено. Он удваивает A и пытается вычесть 10
; с накоплением DecimalTens. JMP $DA1C попадает на последний байт предыдущей
; JMP-инструкции; смысл намеренного входа в середину инструкции не подтверждён.
LDA1D:  asl     a
        bcc     StoreDecimalOnes
        sec
        sbc     #$0A
        inc     DecimalTens
        jmp     $DA1C                 ; Хаковый вход внутрь предыдущего JMP.
StoreDecimalOnes:
LDA28:  sta     DecimalOnes
        rts
