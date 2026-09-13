; Адресный контейнер экранных подсистем и их данных ($C9C0-$D3FF).
; Include-точки сохраняют исходный порядок байтов ROM.

.include "title_menu.s"
.include "battle_hud.s"
.include "base_render.s"
.include "screen_transitions.s"
.include "stage_statistics.s"
.include "score_rewards.s"
.include "title_render.s"
.include "legacy_screen_stream.s"
.include "statistics_delay.s"
.include "screen_text_data.s"
.include "runtime_checksum_init.s"
.include "screen_misc_text.s"
.include "remainder.s"
.include "battle_ui_data.s"
.include "direction_tables.s"
; Оба известных потребителя индексируют таблицы направлением 0..3; эти три $FF лежат за их границей.
PaddingBeforePowerUpEffect0:
LD3DD:  .byte   $FF,$FF,$FF
.include "powerup_effect0.s"

; Заполнение конца экранного модуля до следующей процедуры $D400; ссылок на эти байты нет.
ScreenModuleEndPadding:
LD3FD:  .byte   $FF,$FF,$FF
