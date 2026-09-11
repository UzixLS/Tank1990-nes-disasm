; Обработка boot marker и меню выбора варианта ($C49C-$C59C).

; Вход: A — $46. Возвращается без изменений, если A!=$AB; иначе открывает модальное меню вариантов.
HandleBootVariantMarker:
LC49C:  cmp     #$AB
        beq     RunVariantSelectionMenu
        rts

VariantMenuRow       = TitleSecretInputCode
VariantMenuTextPtrLo = ConstructionMapFlag

; Рисует пункты вариантов, выбирает GameVariant по Up/Down в двух диапазонах 0..6/$80..$86,
; SELECT переключает AllPowerUpsEnabled. START возвращается. Меняет nametable/PPU-очередь,
; FrameCounter, GameVariant, VariantMenuRow/TextPtrLo и UI-флаги; портит A/X/Y.
RunVariantSelectionMenu:
LC4A1:  lda     #$80
        sta     GameVariant
        jsr     DisableRenderingForBulkUpdate
        lda     #$1C
        sta     NametablePpuOffset
        lda     #$00
        sta     VerticalScroll
        sta     NametableBits
        jsr     ClearNametableBuffer
        jsr     UploadNametableBuffer
        jsr     EnableNmiAfterVblank
        lda     #$C5
        sta     ScratchPtrHi
        lda     #$C9
        sta     ScratchPtrLo
        ldy     #$03
        ldx     #$07
        jsr     QueueTileAtCoordinates
        lda     #>VariantMenuDividerText
        sta     ScratchPtrHi
        lda     #<VariantMenuDividerText
        sta     ScratchPtrLo
        ldy     #$04
        ldx     #$07
        jsr     QueueTileAtCoordinates
        lda     #>VariantMenuDividerText
        sta     ScratchPtrHi
        lda     #<VariantMenuDividerText
        sta     ScratchPtrLo
        ldy     #$01
        ldx     #$07
        jsr     QueueTileAtCoordinates
        lda     #$01
        sta     AllPowerUpsEnabled
        jsr     DrawSelectedMenuOption
        lda     #<VariantMenuTankNames
        sta     VariantMenuTextPtrLo
        lda     #$00
        sta     MenuSelection
        sta     VariantMenuRow
DrawNextVariantMenuRow:
LC4F9:  lda     #>VariantMenuTankNames
        sta     ScratchPtrHi
        lda     VariantMenuTextPtrLo
        sta     ScratchPtrLo
        clc
        adc     #$08
        sta     VariantMenuTextPtrLo
        lda     VariantMenuRow
        clc
        adc     #$09
        tay
        ldx     #$0D
        jsr     QueueTileAtCoordinates
        jsr     WaitForNextFrame
        inc     VariantMenuRow
        lda     VariantMenuRow
        cmp     #$0E
        bcc     DrawNextVariantMenuRow
DrawVariantMenuCursor:
LC51C:  lda     #>VariantMenuSelectionCursor
        sta     ScratchPtrHi
        lda     #<VariantMenuSelectionCursor
        sta     ScratchPtrLo
        jsr     QueueVariantMenuText
VariantMenuInputLoop:
LC527:  lda     Joy1Held
        and     #BUTTON_DOWN
        beq     CheckVariantMenuUp
        jsr     WaitVariantMenuRepeatAndEraseCursor
        inc     GameVariant
        lda     GameVariant
        cmp     #$07
        bne     WrapVariantMenuAfterSix
        lda     #$80
WrapVariantMenuAfterSix:
LC53A:  cmp     #$87
        bne     CommitVariantMenuSelection
        lda     #$00
CommitVariantMenuSelection:
LC540:  sta     GameVariant
        jmp     DrawVariantMenuCursor

CheckVariantMenuUp:
LC545:  lda     Joy1Held
        and     #BUTTON_UP
        beq     CheckVariantMenuPowerUps
        jsr     WaitVariantMenuRepeatAndEraseCursor
        dec     GameVariant
        lda     GameVariant
        cmp     #$FF
        bne     WrapVariantMenuBeforeExtendedRange
        lda     #$86
WrapVariantMenuBeforeExtendedRange:
LC558:  cmp     #$7F
        bne     CommitPreviousVariantSelection
        lda     #$06
CommitPreviousVariantSelection:
LC55E:  sta     GameVariant
        jmp     DrawVariantMenuCursor

CheckVariantMenuPowerUps:
LC563:  lda     Joy1Pressed
        and     #BUTTON_SELECT
        beq     CheckVariantMenuExit
        lda     AllPowerUpsEnabled
        eor     #$01
        sta     AllPowerUpsEnabled
        jsr     DrawSelectedMenuOption
CheckVariantMenuExit:
LC572:  lda     Joy1Pressed
        and     #BUTTON_START
        beq     VariantMenuInputLoop
        rts

; Debounce/autorepeat меню: сбрасывает FrameCounter, ждёт фазу mod16=0,
; запрашивает поток RicochetOrMenuStepAudioState
; и помещает строку $E8B2 в позицию текущего пункта. Портит A/X/Y, ScratchPtr и PPU-очередь.
WaitVariantMenuRepeatAndEraseCursor:
LC579:  lda     #$00
        sta     FrameCounter
WaitForVariantMenuRepeatPhase:
LC57D:  jsr     WaitForNextFrame
        lda     FrameCounter
        and     #$0F
        bne     WaitForVariantMenuRepeatPhase
        lda     #AudioStateStartRequested
        sta     RicochetOrMenuStepAudioState
        lda     #>VariantMenuBlankCursorText
        sta     ScratchPtrHi
        lda     #<VariantMenuBlankCursorText
        sta     ScratchPtrLo
        jsr     QueueVariantMenuText
        rts

; Два статически неиспользуемых дубля: возвращают A=0, RAM и X/Y не меняют.
ReturnZeroStub1:
LC597:  lda     #$00
        rts
ReturnZeroStub2:
LC59A:  lda     #$00
        rts
