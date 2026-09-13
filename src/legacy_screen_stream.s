; Сохранённый адаптер legacy-потоков экрана ($D255-$D275).

LegacyFirstStreamLow  = $F8
LegacyFirstColumn     = $04
LegacyFirstRow        = $19
LegacySecondColumn    = $06
LegacySecondRow       = $1B

; Адаптер двух строк без статических ссылок в текущем графе вызовов.
; Вход: A становится старшим байтом указателя A:$F8 для строки в ($04,$19);
; затем всегда трактует поток с LegacyChecksumCodeStreamStart ($D320) как
; строку для ($06,$1B). Начало потока — opcode STA RuntimeChecksumExpected в
; InitializeRuntimeChecksumGuard. Строковый чтец проходил бы дальше по байтам
; опкодов до $FF в $D331. При A=$D2 первая строка аналогично началась бы с кода проверки $D2F8.
; Без вызывающего контекста назначение сценария не подтверждено; входная страница
; должна содержать достижимый $FF, иначе строковый reader выйдет за ожидаемый блок.
; Между потоками ждёт кадр, поэтому первая команда успевает выполниться, а вторая
; остаётся в очереди до следующего NMI. Меняет A/X/Y, ScratchPtr, AuxPtr,
; nametable shadow, PPU update buffer и кадровое/input/audio-состояние ожидания.
QueueTwoLegacyScreenLines:
LD255:  nop
        sta     ScratchPtrHi
        lda     #LegacyFirstStreamLow
        sta     ScratchPtrLo
        ldx     #LegacyFirstColumn
        ldy     #LegacyFirstRow
        jsr     QueueTileAtCoordinates
        jsr     WaitForNextFrame
        lda     #>LegacyChecksumCodeStreamStart
        sta     ScratchPtrHi
        lda     #<LegacyChecksumCodeStreamStart
        sta     ScratchPtrLo
        ldx     #LegacySecondColumn
        ldy     #LegacySecondRow
        jsr     QueueTileAtCoordinates
        rts
