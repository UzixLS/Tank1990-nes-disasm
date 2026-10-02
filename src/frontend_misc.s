; Сохранённый zero-page inspector и прокрутка заставки ($C755-$C7C7).

RamInspectorDigitTileBias = $30
RamInspectorIndexColumn   = $09
RamInspectorValueColumn   = $0D
RamInspectorRow           = $02
RamInspectorPageStep      = $10
RamInspectorQueueByteCount = $0C
RamInspectorQueueMaxStartPos = $73

IntroScrollStart          = $00
IntroScrollEnd            = $F0
IntroExitButtonMask       = BUTTON_SELECT | BUTTON_START

; Статически неиспользуемый инспектор zero page. Сначала ставит в PPU-очередь
; DebugRamIndex в (9,2), затем текущее $00,DebugRamIndex в (13,2). Второе
; чтение происходит уже после первого format/queue: они меняют $00, decimal
; scratch, ScratchPtr и PpuBufferPos. В частности, index 0 читает $40 —
; PpuTileRowBits для row 2, а не входное значение zero-page $00.
; Оба байта проходят через PreparePackedScoreIncrement, поэтому отображаемая
; тройка равна [старший ниббл, младший ниббл, 0] с tile bias $30; нибблы
; $A..$F не преобразуются в десятичные цифры.
;
; После формирования строк SELECT/B/A последовательно меняют индекс на
; +1/-1/+16 с восьмибитным переполнением, поэтому несколько кнопок в одном
; кадре складывают эффекты. Изменённый индекс будет прочитан только при
; следующем вызове.
;
; Вход: DebugRamIndex, Joy1Pressed и корректный NametablePpuOffset;
; PpuBufferPos<=RamInspectorQueueMaxStartPos ($73), NMI не flush-ит очередь
; между командами. Каждая трёхтайловая строка занимает 6 bytes, всего 12;
; ограничение оставляет место и для lookahead по итоговому cursor.
;
; Выход: DebugRamIndex=(old+SELECT-B+16*A) mod 256, причём все три эффекта
; применяются последовательно; inspected address всегда старый. X=PpuBufferPos=
; old+RamInspectorQueueByteCount, Y=3, ScratchPtr=DecimalHundreds,
; TileTranslationOffset=0, PpuTileRowBits/ByteToDecimalInput=$40.
; Без BUTTON_A: A=0, N=0/Z=1/C=1; с BUTTON_A: A=новый DebugRamIndex, N/Z/C/V
; принадлежат сложению +$10. V без A остаётся от PPU-address arithmetic
; (0 для штатных nametable offsets).
; Меняет DebugRamIndex, ScoreIncrementDigits/decimal scratch, $00,
; PpuBufferPos и 12 bytes PpuUpdateBuffer; shadow и PPU registers не меняет.
; Обе команды QueueTranslatedTileString, поэтому display не отражается в shadow.
UnreferencedZeroPageInspector:
LC755:  lda     DebugRamIndex
        jsr     PreparePackedScoreIncrement
        lda     #RamInspectorDigitTileBias
        sta     TileTranslationOffset
        lda     #>DecimalHundreds
        sta     ScratchPtrHi
        lda     #<DecimalHundreds
        sta     ScratchPtrLo
        ldx     #RamInspectorIndexColumn
        ldy     #RamInspectorRow
        jsr     QueueTranslatedTileString
        ldx     DebugRamIndex
        lda     $00,x
        jsr     PreparePackedScoreIncrement
        lda     #>DecimalHundreds
        sta     ScratchPtrHi
        lda     #<DecimalHundreds
        sta     ScratchPtrLo
        ldx     #RamInspectorValueColumn
        ldy     #RamInspectorRow
        jsr     QueueTranslatedTileString
        lda     #$00
        sta     TileTranslationOffset
        lda     Joy1Pressed
        and     #BUTTON_SELECT
        beq     CheckRamInspectorPreviousByte
        inc     DebugRamIndex
CheckRamInspectorPreviousByte:
LC792:  lda     Joy1Pressed
        and     #BUTTON_B
        beq     CheckRamInspectorNextPage
        dec     DebugRamIndex
CheckRamInspectorNextPage:
LC79B:  lda     Joy1Pressed
        and     #BUTTON_A
        beq     FinishRamInspector
        lda     DebugRamIndex
        clc
        adc     #RamInspectorPageStep
        sta     DebugRamIndex
FinishRamInspector:
LC7AA:  rts

; Прокручивает заставку вертикально: перед каждым ожиданием NMI содержит
; очередное значение VerticalScroll, после кадра оно увеличивается на пиксель.
; Поэтому 240 NMI реально применяют $00..$EF; при достижении RAM-значения $F0
; процедура возвращает A=$F0, N=0/Z=1/C=1, X/Y и V сохранены.
; NametableBits=0; следующий TitleScreen сбросит scroll до того, как $F0 будет
; передан PPU. SELECT/START на последнем кадре имеет приоритет над normal return.
;
; Требует включённый NMI. Каждый WaitForNextFrame обслуживает PPU/OAM, input,
; audio и кадровые счётчики. SELECT/START проверяются после приращения scroll;
; при нажатии процедура снимает со стека ровно двухбайтный адрес возврата от
; своего JSR и хвостом переходит в EnterTitleMenu, поэтому к
; вызывающему continuation этот путь не возвращается. Такой interrupt-вход
; требует именно JSR-вызова и сбалансированного стека. До перехода меняет
; VerticalScroll и NametableBits; на прерванном пути дальнейшие эффекты задаёт
; TitleScreen.
ScrollIntroUntilInput:
LC7AB:  lda     #IntroScrollStart
        sta     VerticalScroll
        sta     NametableBits
ScrollNextIntroFrame:
LC7B1:  jsr     WaitForNextFrame
        inc     VerticalScroll
        lda     Joy1Pressed
        and     #IntroExitButtonMask
        bne     InterruptIntroScroll
        lda     VerticalScroll
        cmp     #IntroScrollEnd
        bne     ScrollNextIntroFrame
        rts

InterruptIntroScroll:
LC7C3:  pla
        pla
        jmp     EnterTitleMenu
