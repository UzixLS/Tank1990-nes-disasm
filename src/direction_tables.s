; Общие смещения движения по направлениям ($D3D5-$D3DC).
; Файл включается из screens.s в исходной позиции для сохранения адресов ROM.

; Две параллельные таблицы без terminator: четыре signed two's-complement
; компоненты в порядке DIRECTION_UP, LEFT, DOWN, RIGHT (indices 0..3).
; Пары (dx,dy): (0,-1),(-1,0),(0,+1),(+1,0). Bounds check нет; index >=4
; читает соседнюю таблицу/следующие ROM bytes.
;
; ConstructionCursor выполняет четыре ASL и получает шаг +/-16; transition
; object прибавляет исходное значение как шаг +/-1. Оба consumer используют
; восьмибитную арифметику с wrap modulo 256, clipping здесь не задаётся.
; Romhack должен сохранять одинаковые length/order обеих таблиц и согласовать
; их с DIRECTION_* и DecodeDirectionButtons; изменение величин одновременно
; влияет на оба масштаба движения.
DirectionStepX:
LD3D5:  .byte   $00,$FF,$00,$01
DirectionStepY:
LD3D9:  .byte   $FF,$00,$01,$00
