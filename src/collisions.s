; Адресный контейнер столкновений и соседних подсистем ($E604-$EA50).
; Смысловые модули подключаются в исходном порядке байтов ROM.

.include "projectile_terrain_collisions.s"
.include "projectile_tank_collisions.s"
.include "variant_menu_data.s"

.include "enemy_score_awards.s"
.include "powerup_spawn.s"

.include "projectile_pair_collisions.s"
.include "powerup_pickup.s"
.include "stage_selection_helpers.s"
.include "maximum_upgrade_trampoline.s"
.include "projectile_terrain_classifier.s"
.include "upgrade_state_helper.s"
.include "audio_state_helper.s"
.include "projectile_direction_tables.s"
