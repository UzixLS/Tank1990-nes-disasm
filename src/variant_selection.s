; Обработка boot marker и меню выбора варианта ($C49C-$C59C).

VariantStandardCount       = $07
VariantExtendedFirst       = $80
VariantExtendedPastLast    = $87
VariantExtendedBeforeFirst = $7F
VariantMenuRowCount        = $0E
VariantMenuTextStride      = $08
VariantMenuRepeatMask      = $0F

; Вход: A=GameVariant. Если A!=BootVariantMarker, возвращает его без изменений
; (флаги задаёт CMP, X/Y и RAM сохраняются). При маркере синхронно запускает
; модальное меню и возвращается только после START; UI/PPU и A/X/Y изменяются.
HandleBootVariantMarker:
LC49C:  cmp     #BootVariantMarker
        beq     RunVariantSelectionMenu
        rts

VariantMenuRow       = TitleSecretInputCode
VariantMenuTextPtrLo = ConstructionMapFlag

; Рисует 14 пунктов и выбирает GameVariant по Up/Down в двух диапазонах
; 0..6/$80..$86. SELECT переключает AllPowerUpsEnabled, START возвращается.
; Меняет shadow/PPU-очередь, FrameCounter, GameVariant, MenuSelection,
; VariantMenuRow/TextPtrLo и UI-флаги; портит A/X/Y и ScratchPtr.
; Layout constraint: 14 восьмибайтных записей VariantMenuTankNames должны
; оставаться на одной странице: цикл меняет только младший байт указателя.
RunVariantSelectionMenu:
LC4A1:  lda     #VariantExtendedFirst
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
        lda     #>VariantMenuHeaderText
        sta     ScratchPtrHi
        lda     #<VariantMenuHeaderText
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
        adc     #VariantMenuTextStride
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
        cmp     #VariantMenuRowCount
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
        cmp     #VariantStandardCount
        bne     CheckVariantMenuExtendedUpperBound
        lda     #VariantExtendedFirst
CheckVariantMenuExtendedUpperBound:
LC53A:  cmp     #VariantExtendedPastLast
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
        bne     CheckVariantMenuExtendedLowerBound
        lda     #(VariantExtendedPastLast-1)
CheckVariantMenuExtendedLowerBound:
LC558:  cmp     #VariantExtendedBeforeFirst
        bne     CommitPreviousVariantSelection
        lda     #(VariantStandardCount-1)
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

; Debounce/autorepeat: сбрасывает FrameCounter, ждёт следующую фазу mod16=0,
; запрашивает RicochetOrMenuStepAudioState и заменяет курсор строкой
; VariantMenuBlankCursorText в позиции текущего пункта. Портит A/X/Y,
; ScratchPtr, FrameCounter и PPU-очередь.
WaitVariantMenuRepeatAndEraseCursor:
LC579:  lda     #$00
        sta     FrameCounter
WaitForVariantMenuRepeatPhase:
LC57D:  jsr     WaitForNextFrame
        lda     FrameCounter
        and     #VariantMenuRepeatMask
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
