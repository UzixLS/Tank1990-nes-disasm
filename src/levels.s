; Оба asset-а используют записи по PackedStageByteSize=91 bytes: 13 строк,
; в каждой 13 TSA indexes high/low по порядку и один low padding nibble.

.segment "TANK_LEVELS"
; 100 карт Tank 1990 занимают весь $8000-$A38B. В текущем статическом графе ни
; один ClassicLevelSetDescriptors не указывает сюда, поэтому LoadAndDrawStage
; НЕ использует TankLevels как runtime map catalog. Известные code reads —
; семибайтное checksum-окно TankLevels+$0D12 и статически неиспользуемый
; ApplyLevelByteToTankAttributesStub по TankLevels+$56+Y. Asset остаётся важен
; для byte-exact ROM, checksum и возможных производных работ, но не для штатного
; выбора карты.
TankLevels:
    .incbin "../build/tank-levels.bin"

; Неиспользуемый 14-byte префикс перед первым классическим уровнем. Формально
; это две packed rows, но loader/descriptors начинают с ClassicLevels=$F030;
; статических data-ссылок на prefix нет. Сохранён ради byte identity/layout.
.segment "CLASSIC_PREFIX"
ClassicLevelPrefix:
    .byte $CC, $CC, $CC, $CC, $CD, $C4, $D4
    .byte $44, $D4, $44, $D4, $CD, $C4, $D4

.segment "CLASSIC_LEVELS"
; Единственный штатный runtime catalog: 36*91=$0CCC bytes, $F030-$FCFB.
; Дескрипторы выбирают его начало либо offsets 12*91/24*91. Из-за фазовой
; поправки loader-а 0/2/4 последние shifted windows могут захватить bytes
; $FCFC-$FCFF уже после segment-а; romhack-layout обязан учитывать этот tail.
ClassicLevels:
    .incbin "../build/classic-levels.bin"
