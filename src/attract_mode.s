; Подготовка и кадровый цикл attract mode ($C3B5-$C44A).

AttractLoadedStageSentinel = $FF
AttractDisplayedStage      = $1E

; Готовит демо-этап: сохраняет score records, но сбрасывает остальную сессию;
; загружает служебную карту через StageNumber=$FF, затем выставляет видимый этап
; 30 и StageSetLength=2 как attract-маркер. Рисует заголовок варианта/год,
; инициализирует runtime и возвращает с GameMode=OnePlayerGameMode.
; Выход: A=OnePlayerGameMode; меняет почти всю session/game RAM, shadow/PPU и A/X/Y.
InitializeAttractMode:
LC3B5:  lda     #$01
        sta     PauseState
        lda     #$00
        sta     BackgroundPaletteIndex
        jsr     InitializeSessionAfterScoreRecords
        lda     #$03
        sta     Player2Lives
        lda     #$00
        sta     VerticalScroll
        sta     NametableBits
        sta     SlowFrameCounter
        sta     FrameCounter
        jsr     InitializePlayfieldRectangle
        lda     #AttractLoadedStageSentinel
        sta     StageNumber
        jsr     LoadAndDrawStage
        lda     #AttractDisplayedStage
        sta     StageNumber
        lda     #AttractStageSetMarker
        sta     StageSetLength
        jsr     DisableRenderingForBulkUpdate
        ldx     #$1A
        stx     RasterStringX
        ldy     #$46
        sty     RasterStringY
        jsr     DrawVariantTitleData
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        ldx     #$3C
        stx     RasterStringX
        ldy     #$78
        sty     RasterStringY
        lda     #>EditionYearText
        sta     AuxPtrHi
        lda     #<EditionYearText
        sta     AuxPtrLo
        jsr     RasterizeTileStringToShadow
        jsr     UploadNametableBuffer
        jsr     EnableNmiAfterVblank
        jsr     InitializeStageRuntime
        jsr     DrawBrickBaseEnclosure
        jsr     WaitForNextFrame
        lda     #OnePlayerGameMode
        sta     GameMode
        rts

; Кадровый цикл демо: генерирует ввод и выполняет обычные logic/render passes.
; При штатном завершении этапа очищает PpuBufferPos и возвращается вызывающему.
; SELECT/START снимают со стека двухбайтный адрес возврата от JSR RunAttractMode,
; очищают экран и хвостом переходят в EnterTitleMenu; этот путь не возвращается.
; Портит игровую RAM, shadow/PPU/OAM/audio state и A/X/Y.
RunAttractMode:
LC41D:  jsr     WaitForNextFrame
        lda     Joy1Pressed
        and     #(BUTTON_SELECT | BUTTON_START)
        bne     ExitAttractModeToTitle
        jsr     GenerateAttractModeInput
        jsr     RunGameplayLogicTick
        jsr     DrawAndExpirePowerUp
        jsr     DrawTanks
        jsr     DrawProjectiles
        jsr     CheckStageLoopFinished
        beq     RunAttractMode
        lda     #$00
        sta     PpuBufferPos
        rts

ExitAttractModeToTitle:
LC43F:  pla
        pla
        lda     #$00
        sta     PpuBufferPos
        jsr     ClearPrimaryNametableScreen
        jmp     EnterTitleMenu
