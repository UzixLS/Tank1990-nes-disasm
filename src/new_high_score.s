; Экран нового рекорда ($C44B-$C49B).

NewHighScoreHeaderRasterX    = $10
NewHighScoreHeaderRasterY    = $32
NewHighScorePaletteFrameMask = $03
NewHighScoreFirstPalette     = $05
NewHighScoreExitPalette      = $00

; Показывает экран после успешного UpdateHighScoreRecord. Предусловия:
; HighScore уже содержит валидную 7-digit/$FF запись, NMI включён,
; PauseState=0 и TileTranslationOffset=0. Иначе ожидание audio может зависнуть
; либо заголовок растрируется с чужим CHR bias. На время bulk update
; отключает rendering/NMI, очищает shadow, растеризует заголовок в ($10,$32),
; а RenderLargeScoreRecord — сам рекорд в своей фиксированной позиции ($10,$64).
; Затем загружает nametable $2000, включает NMI и запускает три музыкальных
; потока, но control flow ждёт завершения только pulse 1. В исходных audio data
; pulse 2 заканчивается в тот же NMI, triangle раньше; производная работа при
; изменении длительностей должна сохранить это либо явно остановить потоки.
; FrameCounter не сбрасывается, поэтому начальная фаза
; палитры зависит от кадра; каждый цикл планирует палитру 5..8 через NMI.
; Финальный BackgroundPaletteIndex=0 тоже только планируется: после записи
; процедура кадра уже не ждёт, а в PPU остаётся последняя палитра 5..8 до NMI
; caller-а. Долгое ожидание через NMI обновляет input/OAM/audio/frame counters.
; Выход: A=0, Y=0, X не определён, NMI включён, VerticalScroll=0,
; NametableBits=0, NametablePpuOffset=ShadowToPrimaryNametableOffset,
; BackgroundPaletteIndex=NewHighScoreExitPalette. Меняет
; shadow/PPU, SlowFrameCounter, AuxPtr, ScratchPtr=$0800, raster scratch,
; audio state и рабочую RAM.
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
