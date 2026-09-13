; Ожидание кадра и исполнение PPU-очереди ($D8F6-$D933).

; Ожидает изменения FrameCounter обработчиком NMI. Требует включённые NMI;
; иначе цикл не завершится. A удерживает значение FrameCounter, захваченное до
; ожидания; выход происходит, когда текущий FrameCounter уже отличается от A.
; X/Y и RAM самой процедурой не меняются. NMI между чтениями обслуживает PPU,
; OAM, input, audio и кадровые счётчики по своему контракту.
WaitForNextFrame:  lda     FrameCounter
WaitForFrameCounterChange:
LD8F8:  cmp     FrameCounter
        beq     WaitForFrameCounterChange
        rts

; Выполняет накопленные записи из PpuUpdateBuffer. Команда имеет вид
; [addr_hi, addr_lo, data..., $FF]; следующий байт после $FF -- адрес новой команды.
; Пара $FF,$FF позволяет записать один литеральный $FF и тут же закончить команду.
; Вход: write latch PPU_ADDR должен ожидать high byte; buffer должен быть корректно
; терминирован и не изменяться конкурентно. Выход: A=0, PpuBufferPos=0,
; X=прежняя длина буфера; Y сохраняется. Меняет PPU_ADDR/PPU_DATA и внутренний
; VRAM address, содержимое буфера кроме sentinel по старой позиции сохраняет.
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
        cmp     #PpuQueueTerminator
        bne     WritePpuDataByte
        lda     PpuUpdateBuffer,x
        cmp     #PpuQueueTerminator
        bne     FlushNextPpuCommand
        lda     PpuUpdateBuffer-1,x
WritePpuDataByte:
LD929:  sta     PPU_DATA
        jmp     FlushNextPpuDataByte

FinishPpuBufferFlush:
LD92F:  lda     #$00
        sta     PpuBufferPos
        rts
