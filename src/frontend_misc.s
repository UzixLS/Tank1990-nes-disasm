; Сохранённый zero-page inspector и прокрутка заставки ($C755-$C7C7).

RamInspectorDigitTileBias = $30
RamInspectorIndexColumn   = $09
RamInspectorValueColumn   = $0D
RamInspectorRow           = $02
RamInspectorPageStep      = $10

IntroScrollStart          = $00
IntroScrollEnd            = $F0
IntroExitButtonMask       = BUTTON_SELECT | BUTTON_START

; Статически неиспользуемый инспектор zero page. Сначала ставит в PPU-очередь
; DebugRamIndex в (9,2), затем уже прочитанный $00,DebugRamIndex в (13,2).
; Оба байта проходят через PreparePackedScoreIncrement, поэтому отображаемая
; тройка равна [старший ниббл, младший ниббл, 0] с tile bias $30; нибблы
; $A..$F не преобразуются в десятичные цифры.
;
; После формирования строк SELECT/B/A последовательно меняют индекс на
; +1/-1/+16 с восьмибитным переполнением, поэтому несколько кнопок в одном
; кадре складывают эффекты. Изменённый индекс будет прочитан только при
; следующем вызове.
;
; Вход: DebugRamIndex, Joy1Pressed, NametablePpuOffset; в PPU-очереди должно
; оставаться не менее 12 байт. Выход: TileTranslationOffset=0,
; ScratchPtr=DecimalHundreds, X=PpuBufferPos, Y=3; A зависит от ввода.
; Меняет DebugRamIndex, ByteToDecimalInput, ScoreIncrementDigits и decimal
; scratch, PpuTileRowBits, PpuBufferPos/PpuUpdateBuffer; shadow и PPU registers
; напрямую не меняет. Проверки ёмкости очереди нет.
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
; Поэтому NMI реально применяет $00..$EF; при достижении RAM-значения $F0
; процедура возвращает A=$F0/Z=1, X/Y сохранены. Следующий TitleScreen сбросит
; scroll до того, как $F0 будет передан PPU.
;
; Требует включённый NMI. Каждый WaitForNextFrame обслуживает PPU/OAM, input,
; audio и кадровые счётчики. SELECT/START проверяются после приращения scroll;
; при нажатии процедура снимает со стека двухбайтный адрес возврата от своего
; JSR и хвостом переходит в EnterTitleMenu, поэтому к
; RestartTitleAttractCycle этот путь не возвращается. До перехода меняет
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
