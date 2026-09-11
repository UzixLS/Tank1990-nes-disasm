; Ожидание кадра и исполнение PPU-очереди ($D8F6-$D933).

; Ожидает изменения FrameCounter обработчиком NMI. Требует включённые NMI;
; иначе цикл не завершится. Выход: A=новое значение FrameCounter; X/Y не меняются.
WaitForNextFrame:  lda     FrameCounter
WaitForFrameCounterChange:
LD8F8:  cmp     FrameCounter
        beq     WaitForFrameCounterChange
        rts

; Выполняет накопленные записи из PpuUpdateBuffer. Команда имеет вид
; [addr_hi, addr_lo, data..., $FF]; следующий байт после $FF -- адрес новой команды.
; Пара $FF,$FF позволяет записать один литеральный $FF и тут же закончить команду.
; После выполнения обнуляет PpuBufferPos. Меняет A/X и PPU_ADDR/PPU_DATA; Y сохраняет.
FlushPpuUpdateBuffer:  ldx     PpuBufferPos
        lda     #$00
        sta     PpuUpdateBuffer,x
        tax
FlushNextPpuCommand:
LD905:  cpx     PpuBufferPos
        beq     FinishPpuBufferFlush
        lda     PpuUpdateBuffer,x
        inx
        sta     PPU_ADDR
        lda     PpuUpdateBuffer,x
        inx
        sta     PPU_ADDR
FlushNextPpuDataByte:
LD917:  lda     PpuUpdateBuffer,x
        inx
        cmp     #$FF
        bne     WritePpuDataByte
        lda     PpuUpdateBuffer,x
        cmp     #$FF
        bne     FlushNextPpuCommand
        lda     PpuUpdateBuffer-1,x
WritePpuDataByte:
LD929:  sta     PPU_DATA
        jmp     FlushNextPpuDataByte

FinishPpuBufferFlush:
LD92F:  lda     #$00
        sta     PpuBufferPos
        rts
