; NMI, PPU-очередь, OAM и отрисовка метатайлов ($D400-$DB0A).
;
; Теневая nametable занимает $0400-$07FF. Для игрового поля
; её байты одновременно служат номерами фоновых тайлов и битовой
; маской четырёх подобластей 4x4 пикселя. Это позволяет одним байтом
; обслуживать и коллизии, и частичное разрушение кирпича.

.include "nmi.s"
.include "random.s"
.include "ppu_display.s"
.include "runtime_init.s"
.include "palette.s"
.include "ppu_attributes.s"
.include "input.s"
.include "ppu_queues.s"
.include "terrain_shadow.s"
.include "nametable_shadow.s"
.include "metatile_render.s"
.include "chr_raster.s"
.include "ppu_sync.s"
.include "score.s"
.include "oam.s"
.include "math.s"
.include "metatile_data.s"
