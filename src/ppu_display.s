; Управление NMI, рендерингом и очисткой nametable shadow ($D467-$D490).

EnabledNmiPpuCtrlValue    = $B0
BulkUpdatePpuCtrlValue    = $10
BulkUpdatePpuMaskValue    = $06

; Активно ждёт vblank и записывает PPU_CTRL=$B0: NMI включён,
; базовая nametable $2000, VRAM increment 1, background pattern table $1000,
; спрайты 8x16. Вход: PPU должен генерировать vblank.
; Выход: A=EnabledNmiPpuCtrlValue; X/Y сохраняются. Меняет PPU_CTRL и flags.
; Успешное чтение PPU_STATUS очищает vblank flag и сбрасывает общий
; first/second-write latch PPU_SCROLL/PPU_ADDR.
EnableNmiAfterVblank:
LD467:  jsr     WaitForVblankStart
        lda     #EnabledNmiPpuCtrlValue
        sta     PPU_CTRL
        rts

; Дожидается следующего NMI, затем записывает PPU_CTRL=$10 и PPU_MASK=$06:
; NMI и background/sprite rendering выключены, базовая nametable $2000,
; VRAM increment 1, background pattern table $1000, sprite pattern table $0000,
; спрайты 8x8. Биты
; left-column background/sprites остаются включёнными, но при выключенном
; основном рендеринге не дают пикселей. Это режим для длинных прямых записей в PPU.
; Вход: NMI включён, а его обработчик увеличивает FrameCounter; иначе ожидание
; зависнет. Выход: A=BulkUpdatePpuMaskValue; X/Y сохраняются. Меняет
; PPU_CTRL/PPU_MASK и flags. Запись PPU_CTRL выбирает nametable 0 в temporary
; VRAM address, но first/second-write latch не переключает.
DisableRenderingForBulkUpdate:
LD470:  jsr     WaitForNextFrame
        lda     #BulkUpdatePpuCtrlValue
        sta     PPU_CTRL
        lda     #BulkUpdatePpuMaskValue
        sta     PPU_MASK
        rts

; Заполняет нулями всю теневую nametable $0400-$07FF, включая
; 64-байтную attribute table $07C0-$07FF. Выход: A=0, X=0; Y сохранён.
; Меняет NametableShadow и flags; PPU registers, PPU queue и остальную RAM
; не трогает.
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
