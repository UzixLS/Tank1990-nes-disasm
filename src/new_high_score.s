; Экран нового рекорда ($C44B-$C49B).

NewHighScoreHeaderRasterX    = $10
NewHighScoreHeaderRasterY    = $32
NewHighScorePaletteFrameMask = $03
NewHighScoreFirstPalette     = $05
NewHighScoreExitPalette      = $00

; Показывает не пропускаемый input-ом экран после успешного
; UpdateHighScoreRecord. Предусловия: HighScore — семь digits 0..9 и $FF;
; NMI включён, PauseState=0, TileTranslationOffset=0. При pause audio engine
; замораживает нужные streams и цикл ожидания pulse1 не завершится; чужой tile
; bias исказит header до того, как RenderLargeScoreRecord установит свой.
;
; DisableRenderingForBulkUpdate сначала ждёт NMI и flush-ит старую PPU queue.
; Затем процедура очищает shadow, растрирует header в ($10,$32) и score в
; ($10,$64), напрямую загружает всю nametable $2000 и снова включает NMI.
; Новых PPU-команд не создаёт, PpuBufferPos остаётся 0.
;
; Три music streams получают start request, но termination gate следит только
; за pulse1. В исходных данных pulse2 заканчивается в тот же NMI, triangle —
; раньше; производная работа при изменении длительности должна сохранить это
; либо явно остановить оставшиеся streams. Input не проверяется.
; FrameCounter не сбрасывается. После каждого NMI код планирует palette
; 5+(FrameCounter&3), то есть 5..8, которая применяется лишь следующим NMI.
; В NMI завершения pulse1 очередная palette 5..8 ещё вычисляется, затем RAM-
; request заменяется на 0 без ожидания: PPU сохраняет предыдущую 5..8 до NMI
; caller-а, который уже применит palette 0. SlowFrameCounter сбрасывается, но
; затем снова увеличивается обслуживающими ожидание NMI.
;
; Выход: A=0, Y=0, X не определён, N=0/Z=1/C=0/V=0; NMI включён,
; VerticalScroll=NametableBits=0, NametablePpuOffset=$1C,
; BackgroundPaletteIndex=0, PpuBufferPos=0, ScratchPtr=$0800. AuxPtr указывает
; на первую значащую digit HighScore либо его terminator. Меняет shadow/PPU,
; frame/input/OAM/audio state и raster scratch; HighScore и RNG сохраняются.
ShowNewHighScoreScreen:
LC44B:  jsr     DisableRenderingForBulkUpdate
        lda     #ShadowToPrimaryNametableOffset
        sta     NametablePpuOffset
        lda     #$00
        sta     VerticalScroll
        sta     NametableBits
        jsr     ClearNametableBuffer
        ldx     #NewHighScoreHeaderRasterX
        stx     RasterStringX
        ldy     #NewHighScoreHeaderRasterY
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
        sta     NewHighScorePulse1AudioState
        sta     NewHighScorePulse2AudioState
        sta     NewHighScoreTriangleAudioState
WaitForNewHighScoreMusic:
LC486:  jsr     WaitForNextFrame
        lda     FrameCounter
        and     #NewHighScorePaletteFrameMask
        clc
        adc     #NewHighScoreFirstPalette
        sta     BackgroundPaletteIndex
        lda     NewHighScorePulse1AudioState
        bne     WaitForNewHighScoreMusic
        lda     #NewHighScoreExitPalette
        sta     BackgroundPaletteIndex
        rts
