; Подготовка и кадровый цикл attract mode ($C3B5-$C44A).

; Готовит демо-этап для attract mode: сбрасывает сессию, загружает служебную карту StageNumber=$FF,
; затем ставит StageNumber=$1E, StageSetLength=2, рисует демо-экран и запускает игру с GameMode=5.
; Меняет всю session/game RAM, PPU/OAM и A/X/Y.
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
        lda     #$FF
        sta     StageNumber
        jsr     LoadAndDrawStage
        lda     #$1E
        sta     StageNumber
        lda     #$02
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
        lda     #$05
        sta     GameMode
        rts

; Кадровый цикл демо-режима. Генерирует ввод ботов и выполняет обычные шаги логики/отрисовки до исхода этапа.
; SELECT/START снимают адрес возврата со стека, очищают экран и сразу возвращаются к title. Портит всю game RAM и A/X/Y.
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
