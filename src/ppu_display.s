; Управление NMI, рендерингом и очисткой nametable shadow ($D467-$D490).

; Дожидается vblank и включает NMI с pattern table $1000.
; Побочно: чтение PPU_STATUS сбрасывает latch $2005/$2006; A и флаги изменены.
EnableNmiAfterVblank:
LD467:  jsr     WaitForVblankStart
        lda     #$B0
        sta     PPU_CTRL
        rts

; На границе кадра отключает NMI и основной рендеринг. Это режим для
; длинных прямых записей в PPU. Меняет A и PPU_CTRL/PPU_MASK.
DisableRenderingForBulkUpdate:
LD470:  jsr     WaitForNextFrame
        lda     #$10
        sta     PPU_CTRL
        lda     #$06
        sta     PPU_MASK
        rts

; Очищает теневую nametable в RAM $0400-$07FF.
; Выход: A=0, X=0; Y не меняет.
ClearNametableBuffer:  lda     #$00
        tax
ClearNextNametableShadowByte:
LD481:  sta     NametableShadow,x
        sta     NametableShadowPage1,x
        sta     NametableShadowPage2,x
        sta     NametableShadowPage3,x
        inx
        bne     ClearNextNametableShadowByte
        rts
