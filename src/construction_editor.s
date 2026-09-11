; Основной цикл редактора Construction ($C0AE-$C158).

; Редактор Construction: перемещает курсор, меняет TSA-блок и затем
; возвращается в общий игровой цикл.
ConstructionMetatileIndex    = $5C
ConstructionMoveRepeatTimer = $7B
ConstructionEditLatch        = $81
ConstructionMode:
; Вход: ConstructionMapFlag=0 для первичной отрисовки. Объект 0 используется как мигающий курсор.
; D-pad двигает его по сетке 16 px; A/B выбирают TSA $00..$0D и вызывают DrawMetatile.
; START поднимает ConstructionMapFlag и
; возвращается в главное меню. Меняет объект 0, тень nametable, PPU-очередь и рабочую RAM; портит A/X/Y.
LC0AE:  lda     ConstructionMapFlag
        bne     InitializeConstructionEditor
        jsr     DisableRenderingForBulkUpdate
        jsr     InitializePlayfieldRectangle
        jsr     UploadNametableBuffer
        jsr     EnableNmiAfterVblank
InitializeConstructionEditor:
LC0BE:  jsr     ClearTankStates
        lda     #$10
        sta     ObjectX
        lda     #$18
        sta     ObjectY
        lda     #$84
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
        cmp     #$0E
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
        lda     #$0D
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
