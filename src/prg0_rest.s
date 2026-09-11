; Данные и расширения кода первого PRG-банка после таблицы 100 уровней.

.segment        "PRG0_REST": absolute

.include "extra_levels.s"
.include "prg0_extensions.s"
.include "prg0_unreferenced_data.s"
.include "deferred_integrity_bridge.s"
.include "prg0_extension_prototypes.s"

; End of "PRG0_REST" segment
.code
