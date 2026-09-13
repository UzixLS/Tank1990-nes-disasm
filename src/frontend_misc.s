; Сохранённый RAM inspector и прокрутка заставки ($C755-$C7C7).

; Статически неиспользуемый RAM-инспектор: рисует DebugRamIndex и байт
; zero-page[DebugRamIndex]. SELECT/B/A последовательно меняют индекс на
; +1/-1/+16, поэтому несколько кнопок в одном кадре складывают эффекты.
; Портит A/X/Y, ScratchPtr, ScoreIncrementDigits/decimal scratch,
; TileTranslationOffset, PPU-очередь и DebugRamIndex.
UnusedRamInspector:
LC755:  lda     DebugRamIndex
        jsr     PreparePackedScoreIncrement
        lda     #$30
        sta     TileTranslationOffset
        lda     #$00
        sta     ScratchPtrHi
        lda     #$39
        sta     ScratchPtrLo
        ldx     #$09
        ldy     #$02
        jsr     QueueTranslatedTileString
        ldx     DebugRamIndex
        lda     $00,x
        jsr     PreparePackedScoreIncrement
        lda     #$00
        sta     ScratchPtrHi
        lda     #$39
        sta     ScratchPtrLo
        ldx     #$0D
        ldy     #$02
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
        adc     #$10
        sta     DebugRamIndex
FinishRamInspector:
LC7AA:  rts
; Прокручивает заставку вертикально от 0 до $F0 по одному пикселю за кадр.
; При достижении $F0 возвращается обычным RTS. SELECT/START снимают со стека
; двухбайтный адрес возврата от JSR ScrollIntroUntilInput и хвостом переходят
; в EnterTitleMenu, поэтому к RestartTitleAttractCycle этот путь не возвращается.
; Меняет VerticalScroll/NametableBits; портит A и флаги, X/Y сохраняет.
ScrollIntroUntilInput:
LC7AB:  lda     #$00
        sta     VerticalScroll
        sta     NametableBits
ScrollNextIntroFrame:
LC7B1:  jsr     WaitForNextFrame
        inc     VerticalScroll
        lda     Joy1Pressed
        and     #(BUTTON_SELECT | BUTTON_START)
        bne     InterruptIntroScroll
        lda     VerticalScroll
        cmp     #$F0
        bne     ScrollNextIntroFrame
        rts

InterruptIntroScroll:
LC7C3:  pla
        pla
        jmp     EnterTitleMenu
