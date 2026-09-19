; Обновление номера этапа в HUD ($CA91-$CAF4).

StageNumberHudColumn  = $0C
StageNumberHudRow     = $0E
StageNumberDigitColumn= $0E
StageNumberTileBias   = $6E

; На границе кадра формирует PPU-команды для надписи и десятичного StageNumber.
; Сначала ставит тайлы $23..$27,$11,$11 в (StageNumberHudColumn,
; StageNumberHudRow), затем число с StageNumberTileBias. Обе записи обходят
; nametable shadow и попадают только в PPU update buffer.
; Вход: StageNumber. Выход: TileTranslationOffset=0; A=0.
; Портит X/Y, ScratchPtr, ByteToDecimalInput/ScoreIncrementDigits,
; DecimalHundreds/Tens/Ones, PpuBufferPos и PpuUpdateBuffer. WaitForNextFrame
; также обслуживает input, audio, OAM DMA и счётчики кадра.
UpdateStageNumberDisplay:
LCA91:  jsr     WaitForNextFrame
        ldx     #StageNumberHudColumn
        ldy     #StageNumberHudRow
        jsr     TileCoordinatesToShadowAddress
        ldx     PpuBufferPos
        clc
        adc     #ShadowToPrimaryNametableOffset
        sta     PpuUpdateBuffer,x
        inx
        tya
        sta     PpuUpdateBuffer,x
        inx
        lda     #$23
        sta     PpuUpdateBuffer,x
        inx
        lda     #$24
        sta     PpuUpdateBuffer,x
        inx
        lda     #$25
        sta     PpuUpdateBuffer,x
        inx
        lda     #$26
        sta     PpuUpdateBuffer,x
        inx
        lda     #$27
        sta     PpuUpdateBuffer,x
        inx
        lda     #$11
        sta     PpuUpdateBuffer,x
        inx
        lda     #$11
        sta     PpuUpdateBuffer,x
        inx
        lda     #$FF
        sta     PpuUpdateBuffer,x
        inx
        stx     PpuBufferPos
        lda     #StageNumberTileBias
        sta     TileTranslationOffset
        lda     StageNumber
        jsr     ByteToDisplayDigits
        ldy     #(ScoreIncrementDigits+1)
        ldx     #StageNumberDigitColumn
        jsr     SelectVisibleDigits
        ldy     #StageNumberHudRow
        jsr     QueueTranslatedTileString
        lda     #$00
        sta     TileTranslationOffset
        rts
