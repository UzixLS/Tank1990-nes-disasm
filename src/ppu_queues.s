; Формирование строковых команд PPU ($D6B3-$D705).

PpuQueueTerminator = $FF

; Копирует строку [tile_0..tile_(N-1), $FF] в PPU-очередь как команду
; [addr_hi, addr_lo, tile_0..tile_(N-1), $FF] и зеркалит N тайлов в shadow.
; Вход: ScratchPtr указывает на доступную через (zp),Y строку с первым
; терминатором $FF в пределах 256 байтов; X=0..31 и Y=0..31 задают начальный
; линейный адрес
; NametableShadow+32*Y+X. NametablePpuOffset прибавляется к high byte этого
; shadow-адреса и должен переводить весь диапазон в нужную PPU nametable.
; PpuBufferPos и N должны оставлять N+3 байта команды и ещё один байт lookahead
; внутри PpuUpdateBuffer $0180-$01FF; во время построения NMI flush недопустим.
; $FF может быть только терминатором и в shadow не пишется. Ни строка, ни PPU
; command не ограничиваются концом 32-тайловой строки: допустимый линейный
; диапазон и отсутствие нежелательного перехода строки обеспечивает вызывающий;
; для обычной tile-строки он остаётся в $0400-$07BF.
; Выход: A=$FF, X=PpuBufferPos=old PpuBufferPos+N+3, Y=N;
; AuxPtr=NametableShadow+32*input Y+input X, ScratchPtr сохранён, flags отражают
; сравнение терминатора. Меняет PpuTileRowBits, AuxPtr, N shadow-байтов,
; PpuBufferPos и N+3 байта PpuUpdateBuffer; PPU registers не трогает.
QueueTileAtCoordinates:  jsr     TileCoordinatesToShadowAddress
        sta     AuxPtrHi
        clc
        adc     NametablePpuOffset
        ldx     PpuBufferPos
        sta     PpuUpdateBuffer,x
        inx
        tya
        sta     PpuUpdateBuffer,x
        inx
        sta     AuxPtrLo
        ldy     #$00
QueueNextShadowedStringByte:
LD6CA:  lda     (ScratchPtrLo),y
        sta     PpuUpdateBuffer,x
        inx
        cmp     #PpuQueueTerminator
        beq     FinishShadowedStringQueue
        sta     (AuxPtrLo),y
        iny
        jmp     QueueNextShadowedStringByte

FinishShadowedStringQueue:
LD6DA:  stx     PpuBufferPos
        rts

; Добавляет строку в PPU-очередь без изменения shadow nametable. Для каждого
; исходного байта $00..$7F записывает (byte+TileTranslationOffset) mod 256;
; байты $80..$FE копирует без преобразования, а $FF копирует как терминатор.
; Сложение не должно превращать нетерминальный байт в $FF: такой результат
; преждевременно завершит обработку до исходного терминатора и PPU-команду. Литеральный $FF
; эта процедура закодировать не умеет.
; Вход: ScratchPtr указывает на строку с первым исходным $FF в пределах 256 байтов;
; X=0..31/Y=0..31 и NametablePpuOffset задают начальный PPU-адрес так же, как у
; QueueTileAtCoordinates. PpuBufferPos и длина N должны оставлять N+3 байта
; команды и следующий lookahead внутри $0180-$01FF; NMI flush во время построения
; недопустим. Переход за 32-тайловую строку не проверяется.
; Выход: A=$FF, X=PpuBufferPos=old PpuBufferPos+N+3, Y=N; ScratchPtr, AuxPtr,
; TileTranslationOffset и nametable shadow сохранены, flags отражают сравнение
; терминатора. Меняет PpuTileRowBits, PpuBufferPos и N+3 байта PpuUpdateBuffer;
; PPU registers не трогает.
QueueTranslatedTileString:
LD6DD:  jsr     TileCoordinatesToShadowAddress
        clc
        adc     NametablePpuOffset
        ldx     PpuBufferPos
        sta     PpuUpdateBuffer,x
        inx
        tya
        sta     PpuUpdateBuffer,x
        inx
        ldy     #$00
QueueNextTranslatedStringByte:
LD6F0:  lda     (ScratchPtrLo),y
        bmi     StoreTranslatedStringByte
        clc
        adc     TileTranslationOffset
StoreTranslatedStringByte:
LD6F7:  sta     PpuUpdateBuffer,x
        inx
        cmp     #PpuQueueTerminator
        beq     FinishTranslatedStringQueue
        iny
        jmp     QueueNextTranslatedStringByte

FinishTranslatedStringQueue:
LD703:  stx     PpuBufferPos
        rts
