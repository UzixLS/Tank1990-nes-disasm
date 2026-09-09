; Основной исполняемый PRG-банк $C000-$FBFF.

.segment        "PRG1_LO": absolute

.include "game_flow.s"

.include "screens.s"

.include "ppu.s"

.include "tanks.s"

.include "projectiles.s"

.include "collisions.s"

.include "audio.s"

.include "stage_loader.s"

; End of "PRG1_LO" segment
.code
