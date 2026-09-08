; Уровни упакованы по два TSA-индекса на байт. В каждой из 13 строк
; хранится 13 блоков и один padding nibble.

.segment "TANK_LEVELS"
TankLevels:
    .incbin "../build/tank-levels.bin"

; 14 байт перед первым классическим уровнем. Загрузчик начинает чтение
; с $F030, поэтому назначение этого хвоста уточняется отдельно.
.segment "CLASSIC_PREFIX"
ClassicLevelPrefix:
    .byte $CC, $CC, $CC, $CC, $CD, $C4, $D4
    .byte $44, $D4, $44, $D4, $CD, $C4, $D4

.segment "CLASSIC_LEVELS"
ClassicLevels:
    .incbin "../build/classic-levels.bin"
