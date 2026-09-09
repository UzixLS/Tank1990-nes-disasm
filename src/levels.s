; Уровни упакованы по два TSA-индекса на байт. В каждой из 13 строк
; хранится 13 блоков и один padding nibble.

.segment "TANK_LEVELS"
TankLevels:
    .incbin "../build/tank-levels.bin"

; Неиспользуемый 14-байтный префикс перед первым классическим уровнем.
; Декодируется как две строки упакованной карты, но загрузчик и все описатели
; начинают чтение с $F030. Сохранён для идентичности ROM; происхождение неизвестно.
.segment "CLASSIC_PREFIX"
ClassicLevelPrefix:
    .byte $CC, $CC, $CC, $CC, $CD, $C4, $D4
    .byte $44, $D4, $44, $D4, $CD, $C4, $D4

.segment "CLASSIC_LEVELS"
ClassicLevels:
    .incbin "../build/classic-levels.bin"
