; Общие смещения движения по направлениям ($D3D5-$D3DC).
; Файл включается из screens.s в исходной позиции для сохранения адресов ROM.

; Две параллельные таблицы четырёх знаковых 8-битных смещений в порядке
; DIRECTION_UP, LEFT, DOWN, RIGHT. ConstructionCursor масштабирует их до 16 пикселей;
; UpdateTransitionObject прибавляет непосредственно как шаг в 1 пиксель.
DirectionStepX:
LD3D5:  .byte   $00,$FF,$00,$01
DirectionStepY:
LD3D9:  .byte   $FF,$00,$01,$00
