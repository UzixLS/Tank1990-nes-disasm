; Ожидание кадра и исполнение PPU-очереди ($D8F6-$D933).

; Активно ждёт, пока NMI изменит FrameCounter. Вход: NMI включён, а его
; обработчик увеличивает FrameCounter; иначе цикл не завершится.
; Выход: A=значение FrameCounter до ожидания, текущий FrameCounter!=A;
; X/Y сохранены, flags соответствуют успешному CMP. Сам цикл RAM не пишет;
; обслуживший его NMI по своему контракту обновляет PPU, OAM, input, audio
; и кадровые счётчики.
WaitForNextFrame:  lda     FrameCounter
WaitForFrameCounterChange:
LD8F8:  cmp     FrameCounter
        beq     WaitForFrameCounterChange
        rts

; Исполняет накопленные PPU-команды. Поток состоит из последовательных
; [addr_hi, addr_lo, data..., $FF]. Одиночный $FF заканчивает данные команды;
; если ещё остались байты, следующий байт есть addr_hi новой команды.
; Пара $FF,$FF кодирует один литеральный $FF, после чего второй $FF повторно
; читается как терминатор; цепочка из N байтов $FF пишет N-1 байт.
; Вход: PpuBufferPos указывает сразу за последним байтом полного потока; каждая
; команда терминирована, поток не меняется конкурентно; PPU_ADDR ожидает high byte,
; а PPU_CTRL выбирает VRAM increment 1 для строк длиннее байта.
; Процедура записывает нулевой lookahead в PpuUpdateBuffer[old PpuBufferPos],
; поэтому этот индекс тоже должен лежать в допустимой области буфера.
; Выход: A=0, PpuBufferPos=0, X=old PpuBufferPos, Y сохранён; flags изменены.
; Перезаписывает указанные VRAM-байты через PPU_ADDR/PPU_DATA. После непустой
; последней строки внутренний VRAM address стоит сразу за её последним data byte;
; после команды без данных — на заданном ею адресе. Кроме lookahead и PpuBufferPos,
; RAM не меняет; при пустом потоке PPU registers/VRAM не трогает.
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
