; Управление NMI, рендерингом и очисткой nametable shadow ($D467-$D490).

EnabledNmiPpuCtrlValue    = $B0
BulkUpdatePpuCtrlValue    = $10
BulkUpdatePpuMaskValue    = $06

; Активно ждёт vblank и записывает PPU_CTRL=$B0: NMI включён,
; базовая nametable $2000, VRAM increment 1, background pattern table $1000,
; спрайты 8x16. Вход: PPU должен генерировать vblank.
; Обычно вызывается при выключенном NMI после bulk update: конкурирующий NMI,
; который тоже читает PPU_STATUS, способен заставить polling ждать ещё кадр.
; Выход: A=EnabledNmiPpuCtrlValue, N=1/Z=0; X/Y и C/V сохраняются. Меняет
; PPU_CTRL и temporary nametable bits, но не PPU_MASK: rendering остаётся в
; прежнем состоянии до следующего NMI. Чтения PPU_STATUS сбрасывают общий
; first/second-write latch PPU_SCROLL/PPU_ADDR; успешное также снимает vblank.
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
; зависнет. Ожидаемый NMI сначала выполняет OAM DMA, flush очереди, возможную
; palette upload, input/OAM/audio и счётчики; лишь после возврата NMI и rendering
; выключаются. Выход: A=BulkUpdatePpuMaskValue, N=Z=0; X/Y сохраняются, C/V
; остаются от WaitForNextFrame. Меняет PPU_CTRL/PPU_MASK и temporary nametable
; bits; first/second-write latch не переключает. После выхода NMI и rendering
; выключены, increment=1, address latch после штатного NMI ожидает high write.
DisableRenderingForBulkUpdate:
LD470:  jsr     WaitForNextFrame
        lda     #BulkUpdatePpuCtrlValue
        sta     PPU_CTRL
        lda     #BulkUpdatePpuMaskValue
        sta     PPU_MASK
        rts

; Заполняет нулями всю теневую nametable $0400-$07FF, включая
; 64-байтную attribute table $07C0-$07FF. Выход: A=0, X=0; Y сохранён.
; N=0/Z=1, C/V сохранены. Меняет NametableShadow и flags; PPU registers,
; PPU queue и остальную RAM не трогает. Это только RAM-операция: для очистки
; видимого экрана после неё нужен direct upload либо queued update.
ClearNametableShadow:
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
