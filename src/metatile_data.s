; Палитры и тайлы TSA-метатайлов ($DABB-$DB0A).

MetatilePalettes:
; 16 palette-индексов 0..3, по одному на TSA metatile. Формат и число записей
; проверяются asset pipeline; исполняемых входов и terminator нет.
LDABB:  .incbin "../build/background-metatiles.bin", 0, 16
MetatileTiles:
; 16 последовательных наборов по четыре tile id: top-left, top-right,
; bottom-left, bottom-right. Значения не интерпретируются сверх этого формата.
LDACB:  .incbin "../build/background-metatiles.bin", 16, 64
