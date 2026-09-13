; Заключительная часть кода и векторы ($FCFC-$FFFF).

.segment "PRG1_HI": absolute

.include "frontend_extensions.s"

.include "runtime_integrity.s"

.include "powerup_effects_hi.s"

.include "tank1990_extensions.s"

.include "collision_extensions.s"

.include "projectile_variant.s"

; $FFF1..$FFF9 — заполнение $FF перед аппаратными векторами.
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF

; NROM использует ResetHandler и как RESET-, и как IRQ/BRK-вектор.
        .word   NmiHandler
        .word   ResetHandler
        .word   ResetHandler
