; Адресный контейнер логики и отрисовки танков ($DB0B-$E02D).
; Слоты 0-1 принадлежат игрокам, 2-7 — противникам.

CurrentTankSlot = $5A

.include "tank_player_audio.s"
.include "enemy_tank_spawn.s"
.include "tank_player_input.s"
.include "tank_update.s"
.include "tank_navigation.s"
.include "tank_targeting.s"
.include "tank_lifecycle.s"
.include "enemy_tank_ai.s"
.include "tank_render.s"
