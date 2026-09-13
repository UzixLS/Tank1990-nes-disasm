; Основной цикл редактора Construction ($C0AE-$C158).

; Редактор Construction: перемещает курсор, меняет TSA-блок и затем
; возвращается в общий игровой цикл.
ConstructionMetatileIndex    = $5C
ConstructionMoveRepeatTimer = $7B
ConstructionEditLatch        = $81
ConstructionMetatileCount    = $0E
ConstructionCursorStartX     = $10
ConstructionCursorStartY     = $18
ConstructionCursorState      = $84
ConstructionMode:
; Вход: ConstructionMapFlag=0 требует первичной очистки/отрисовки поля;
; ненулевое значение повторно использует уже построенную shadow-карту. Объект 0
; становится мигающим курсором. D-pad двигает его по сетке 16 px; A/B выбирают
; TSA $00..$0D. Первый A/B после перемещения только рисует текущий TSA,
; последующие нажатия циклически меняют его; движение сбрасывает
; ConstructionEditLatch. START увеличивает ConstructionMapFlag и хвостом
; переходит в EnterTitleMenu. Процедура сама не возвращается; меняет объект 0,
; shadow nametable, PPU-очередь и рабочую RAM, портит A/X/Y.
LC0AE:  lda     ConstructionMapFlag
        bne     InitializeConstructionEditor
        jsr     DisableRenderingForBulkUpdate
        jsr     InitializePlayfieldRectangle
        jsr     UploadNametableBuffer
        jsr     EnableNmiAfterVblank
InitializeConstructionEditor:
LC0BE:  jsr     ClearTankStates
        lda     #ConstructionCursorStartX
        sta     ObjectX
        lda     #ConstructionCursorStartY
        sta     ObjectY
        lda     #ConstructionCursorState
        sta     ObjectState
        lda     #$00
        sta     ObjectAttributes
        sta     SpriteBehindTerrainMask
        sta     ObjectFrame
        sta     ConstructionEditLatch
        sta     ConstructionMoveRepeatTimer
        sta     ConstructionMetatileIndex
        sta     VerticalScroll
        sta     NametableBits
        sta     PlayerStunTimer
        sta     PlayerStunTimer+1
        lda     ConstructionMapFlag
        bne     ConstructionEditorFrame
        jsr     DrawBrickBaseEnclosure
ConstructionEditorFrame:
LC0EA:  jsr     WaitForNextFrame
        jsr     UpdateConstructionCursor
        jsr     ClampConstructionCursor
        lda     FrameCounter
        and     #$10
        beq     ProcessConstructionEditorInput
        jsr     DrawTanks
ProcessConstructionEditorInput:
LC0FC:  lda     Joy1Held
        and     #BUTTON_DIRECTIONS
        bne     CheckConstructionPaintHeld
        lda     Joy1Pressed
        and     #BUTTON_A
        beq     CheckConstructionPreviousTile
        lda     ConstructionEditLatch
        bne     SelectNextConstructionTile
        inc     ConstructionEditLatch
        jmp     PaintConstructionTile

SelectNextConstructionTile:
LC111:  inc     ConstructionMetatileIndex
        lda     ConstructionMetatileIndex
        cmp     #ConstructionMetatileCount
        bne     PaintConstructionTile
        lda     #$00
        sta     ConstructionMetatileIndex
        jmp     PaintConstructionTile

CheckConstructionPreviousTile:
LC120:  lda     Joy1Pressed
        and     #BUTTON_B
        beq     CheckConstructionPaintHeld
        lda     ConstructionEditLatch
        bne     SelectPreviousConstructionTile
        inc     ConstructionEditLatch
        jmp     PaintConstructionTile

SelectPreviousConstructionTile:
LC12F:  dec     ConstructionMetatileIndex
        lda     ConstructionMetatileIndex
        cmp     #$FF
        bne     PaintConstructionTile
        lda     #(ConstructionMetatileCount-1)
        sta     ConstructionMetatileIndex
        jmp     PaintConstructionTile

CheckConstructionPaintHeld:
LC13E:  lda     Joy1Held
        and     #(BUTTON_A | BUTTON_B)
        beq     CheckConstructionExit
PaintConstructionTile:
LC144:  jsr     DrawConstructionMetatile
CheckConstructionExit:
LC147:  lda     Joy1Pressed
        and     #BUTTON_START
        bne     ExitConstructionEditor
        jmp     ConstructionEditorFrame

ExitConstructionEditor:
LC150:  lda     #$20
        sta     SpriteBehindTerrainMask
        inc     ConstructionMapFlag
        jmp     EnterTitleMenu
