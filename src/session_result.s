; Экран завершения игровой сессии ($C44B-$C49B).

; Показывает экран нового рекорда/окончания сессии, запускает три потока
; музыки результата и ждёт завершения pulse-1 потока.
; В цикле меняет BackgroundPaletteIndex от 5 до 8 по младшим битам
; FrameCounter. Выход: A=0, BackgroundPaletteIndex=0; меняет shadow/PPU,
; audio state и рабочую RAM, портит X/Y и флаги.
ShowSessionResultScreen:
LC44B:  jsr     DisableRenderingForBulkUpdate
        lda     #$1C
        sta     NametablePpuOffset
        lda     #$00
        sta     VerticalScroll
        sta     NametableBits
        jsr     ClearNametableBuffer
        ldx     #$10
        stx     RasterStringX
        ldy     #$32
        sty     RasterStringY
        lda     #>HighScoreText
        sta     AuxPtrHi
        lda     #<HighScoreText
        sta     AuxPtrLo
        jsr     RasterizeTileStringToShadow
        jsr     RenderLargeScoreRecord
        jsr     UploadNametableBuffer
        jsr     EnableNmiAfterVblank
        lda     #$00
        sta     SlowFrameCounter
        lda     #AudioStateStartRequested
        sta     SessionResultPulse1AudioState
        sta     SessionResultPulse2AudioState
        sta     SessionResultTriangleAudioState
WaitForSessionResultMusic:
LC486:  jsr     WaitForNextFrame
        lda     FrameCounter
        and     #$03
        clc
        adc     #$05
        sta     BackgroundPaletteIndex
        lda     SessionResultPulse1AudioState
        bne     WaitForSessionResultMusic
        lda     #$00
        sta     BackgroundPaletteIndex
        rts
