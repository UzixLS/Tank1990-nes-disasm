; Сохранённый адаптер legacy-потоков экрана ($D255-$D275).

LegacyFirstStreamLow  = $F8
LegacyFirstColumn     = $04
LegacyFirstRow        = $19
LegacySecondColumn    = $06
LegacySecondRow       = $1B
LegacyD2FirstStreamByteCount = $3B
LegacySecondStreamByteCount  = $13

; Адаптер двух $FF-терминированных byte streams без статических ссылок в текущем
; графе вызовов. QueueTileAtCoordinates трактует каждый байт до первого $FF как
; tile id, зеркалит его в shadow и копирует в PPU-команду
; [addr_hi,addr_lo,data...,$FF]. Литеральный tile $FF закодировать невозможно.
;
; Вход: A становится старшим байтом первого указателя A:$F8; поток начинается
; в tile ($04,$19). При A=$D2 это ровно 59 байт машинного кода $D2F8..$D332,
; terminator находится по $D333. Линейная запись $0724..$075E пересекает границу
; строк shadow 25/26; при primary offset соответствующий PPU range —
; $2324..$235E. Другие входные страницы статически не подтверждены. Первый $FF
; обязан встретиться при Y=0..255: иначе Y завернётся и reader зациклится, попутно
; переполняя PPU queue. Для доказанного A=$D2 исходный PpuBufferPos должен быть
; <=$41, чтобы 62-byte command и NMI lookahead помещались в $0180-$01FF.
; NMI не должен прервать построение этой первой команды; поскольку entry не
; синхронизируется с началом кадра, это отдельная обязанность неизвестного caller-а.
;
; Затем WaitForNextFrame исполняет первую и ранее накопленные команды и обнуляет
; PpuBufferPos. Требуются включённый NMI с обычным handler, PPU_CTRL increment=1
; и допустимый NametablePpuOffset; ожидание также обслуживает OAM/input/audio/
; palette/counters. Второй фиксированный поток — 19 code bytes $D320..$D332
; от operand STA RuntimeChecksumExpected до байта $20 перед тем же terminator
; $D333. Он зеркалится в $0766..$0778 и при primary offset — в $2366..$2378.
;
; Выход: A=$FF, X=PpuBufferPos=$16, Y=$13, ScratchPtr=$D320,
; AuxPtr=$0766, PpuTileRowBits=$60, Z=C=1/N=0; вторая 22-byte команда остаётся
; до следующего NMI. PPU registers и OAM напрямую не меняет, но меняет два
; shadow-диапазона и первый/второй PPU command stream.
;
; Назначение этого legacy-сценария и допустимые значения входного high byte,
; кроме структурно проверяемого A=$D2, не установлены.
QueueTwoLegacyByteStreams:
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
