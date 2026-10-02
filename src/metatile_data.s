; Палитры и тайлы TSA-метатайлов ($DABB-$DB0A).

MetatilePaletteTableSize = MetatileDefinitionCount
MetatileTileTableOffset  = MetatilePaletteTableSize
MetatileTileTableSize    = MetatileDefinitionCount * MetatileTilesPerDefinition

; Source assets/metatiles/background.tsa содержит ровно 16 логических записей
; формата
;   palette, top-left, top-right, bottom-left, bottom-right.
; Encoder сохраняет их не как 16 чередующихся пятёрок, а как две области:
; сначала 16 palette indexes, затем 16 последовательных четырёхтайловых записей.
; Terminator нет. Индекс определения обязан оставаться 0..15; palette=0..3,
; tile id=0..255. В частности, $FF здесь допустим как tile id: queued single-tile
; protocol кодирует его отдельным data byte перед собственным $FF terminator.
; Romhack может независимо менять все 80 значений, сохраняя размеры и порядок.
; Изменение числа/stride определений требует также менять индексные проверки
; callers и арифметику 4*index в DrawMetatile.
MetatilePalettes:
LDABB:  .incbin "../build/background-metatiles.bin", 0, MetatilePaletteTableSize
MetatileTiles:
LDACB:  .incbin "../build/background-metatiles.bin", MetatileTileTableOffset, MetatileTileTableSize
