; Обновление номера этапа в HUD ($CA91-$CAF4).

; На границе кадра формирует PPU-команды для надписи и десятичного StageNumber.
; Сначала пишет тайлы $23..$27,$11,$11 с ($0C,$0E), затем число с bias $6E.
; Меняет A/X/Y, ScratchPtr, $00, $35-$3C, $60 и PPU-очередь; на выходе $60=0.
UpdateStageNumberDisplay:
LCA91:  jsr     WaitForNextFrame
        ldx     #$0C
        ldy     #$0E
        jsr     TileCoordinatesToShadowAddress
        ldx     PpuBufferPos
        clc
        adc     #$1C
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
        lda     #$6E
        sta     TileTranslationOffset
        lda     StageNumber
        jsr     ByteToDisplayDigits
        ldy     #$36
        ldx     #$0E
        jsr     SelectVisibleDigits
        ldy     #$0E
        jsr     QueueTranslatedTileString
        lda     #$00
        sta     TileTranslationOffset
        rts
