; Формирование строковых команд PPU ($D6B3-$D705).

; Копирует $FF-терминированную строку тайлов в PPU-очередь и зеркалит её
; в shadow nametable. Вход: ScratchPtr -> строка, X/Y -- колонка/строка;
; NametablePpuOffset — разность между старшим байтом shadow ($04..) и PPU
; ($20..). Терминатор в shadow не пишется.
; Побочно: AuxPtr становится адресом shadow; меняет A/X/Y, $00, PpuUpdateBuffer/PpuBufferPos.
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
        cmp     #$FF
        beq     FinishShadowedStringQueue
        sta     (AuxPtrLo),y
        iny
        jmp     QueueNextShadowedStringByte

FinishShadowedStringQueue:
LD6DA:  stx     PpuBufferPos
        rts

; Добавляет в PPU-очередь строку без изменения shadow nametable.
; Для каждого байта < $80 прибавляет tile bias $60; управляющие байты >= $80,
; включая $FF-терминатор, копируются без сдвига. Вход: ScratchPtr, X/Y,
; NametablePpuOffset и TileTranslationOffset.
; Побочно: A/X/Y, $00, PpuUpdateBuffer/PpuBufferPos.
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
        cmp     #$FF
        beq     FinishTranslatedStringQueue
        iny
        jmp     QueueNextTranslatedStringByte

FinishTranslatedStringQueue:
LD703:  stx     PpuBufferPos
        rts
