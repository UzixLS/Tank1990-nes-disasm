; Сохранённый адаптер legacy-потоков экрана ($D255-$D275).

; Адаптер двух строк без статических ссылок в текущем графе вызовов.
; Вход: A становится старшим байтом указателя A:$F8 для строки в ($04,$19);
; затем всегда трактует поток с LegacyChecksumCodeStreamStart ($D320) как
; строку для ($06,$1B). Начало потока — opcode STA RuntimeChecksumExpected в
; InitializeRuntimeChecksumGuard. Строковый чтец проходил бы дальше по байтам
; опкодов до $FF в $D331. При A=$D2 первая строка аналогично началась бы с кода проверки $D2F8.
; Без вызывающего контекста назначение сценария не подтверждено. Между потоками
; ждёт кадр. Меняет A/X/Y, ScratchPtr и PPU-очередь.
QueueTwoLegacyScreenLines:
LD255:  nop
        sta     ScratchPtrHi
        lda     #$F8
        sta     ScratchPtrLo
        ldx     #$04
        ldy     #$19
        jsr     QueueTileAtCoordinates
        jsr     WaitForNextFrame
        lda     #>LegacyChecksumCodeStreamStart
        sta     ScratchPtrHi
        lda     #<LegacyChecksumCodeStreamStart
        sta     ScratchPtrLo
        ldx     #$06
        ldy     #$1B
        jsr     QueueTileAtCoordinates
        rts
