; Управление NMI, рендерингом и очисткой nametable shadow ($D467-$D490).

EnabledNmiPpuCtrlValue    = $B0
BulkUpdatePpuCtrlValue    = $10
BulkUpdatePpuMaskValue    = $06

; Дожидается vblank и включает NMI с pattern table $1000.
; Выход: A=EnabledNmiPpuCtrlValue; X/Y сохраняются. Записывает PPU_CTRL.
; Опрос PPU_STATUS сбрасывает vblank flag и общий write latch PPU_SCROLL/PPU_ADDR.
EnableNmiAfterVblank:
LD467:  jsr     WaitForVblankStart
        lda     #EnabledNmiPpuCtrlValue
        sta     PPU_CTRL
        rts

; На границе кадра отключает NMI и основной рендеринг. Это режим для
; длинных прямых записей в PPU. Вход: NMI должен быть включён, иначе ожидание
; зависнет. Выход: A=BulkUpdatePpuMaskValue; X/Y сохраняются. Записывает
; PPU_CTRL/PPU_MASK; PPU address/scroll latch напрямую не меняет.
DisableRenderingForBulkUpdate:
LD470:  jsr     WaitForNextFrame
        lda     #BulkUpdatePpuCtrlValue
        sta     PPU_CTRL
        lda     #BulkUpdatePpuMaskValue
        sta     PPU_MASK
        rts

; Очищает теневую nametable в RAM $0400-$07FF.
; Выход: A=0, X=0; Y и PPU state не меняет. Портит flags.
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
