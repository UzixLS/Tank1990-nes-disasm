; Векторы шага снаряда по направлениям ($EA49-$EA50).

; Независимая четырёхэлементная копия signed unit vectors в порядке
; Up,Left,Down,Right: (0,-1),(-1,0),(0,+1),(+1,0). Terminator и bounds check
; нет; штатный caller маскирует direction до 0..3. Эти таблицы использует только
; terrain collision geometry, тогда как движение/spawn снаряда использует
; отдельные DirectionDeltaX/Y из tank_tables.s.
;
; Terrain caller берёт abs(component): знак Up/Down и Left/Right теряется,
; magnitude задаёт ближний поперечный offset, а 4*magnitude — дальний. Поэтому
; romhack, меняющий скорость/направления, обязан синхронно согласовать обе пары
; таблиц; простое изменение DirectionDelta не изменит collision probes.
ProjectileDirectionStepX:
LEA49:  .byte   $00,$FF,$00,$01
ProjectileDirectionStepY:
LEA4D:  .byte   $FF,$00,$01,$00
