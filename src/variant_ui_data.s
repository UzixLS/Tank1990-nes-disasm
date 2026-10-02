; Тайловые строки заголовка и меню вариантов ($E570-$E603).

; 14 записей fixed stride 8: шесть tile bytes "TANK A".."TANK N" и два $FF.
; Первый $FF завершает RasterizeTileStringToShadow, второй служит padding.
; DrawVariantTitleData отображает GameVariant 0..6 в записи 0..6 и $80..$86
; в 7..13. Он фиксирует high byte и вычисляет только low byte, поэтому вся
; таблица и терминаторы обязаны оставаться на одной странице; stride 8 зашит
; в три ASL. CopyThreeVariantLabelBytes читает произвольные три байта начиная
; с TankVariantLabels+9+Y и не является bounds-checked record accessor.
TankVariantLabels:
        .byte   $54,$41,$4E,$4B,$20,$41,$FF,$FF
        .byte   $54,$41,$4E,$4B,$20,$42,$FF,$FF
        .byte   $54,$41,$4E,$4B,$20,$43,$FF,$FF
        .byte   $54,$41,$4E,$4B,$20,$44,$FF,$FF
        .byte   $54,$41,$4E,$4B,$20,$45,$FF,$FF
        .byte   $54,$41,$4E,$4B,$20,$46,$FF,$FF
        .byte   $54,$41,$4E,$4B,$20,$47,$FF,$FF
        .byte   $54,$41,$4E,$4B,$20,$48,$FF,$FF
        .byte   $54,$41,$4E,$4B,$20,$49,$FF,$FF
        .byte   $54,$41,$4E,$4B,$20,$4A,$FF,$FF
        .byte   $54,$41,$4E,$4B,$20,$4B,$FF,$FF
        .byte   $54,$41,$4E,$4B,$20,$4C,$FF,$FF
        .byte   $54,$41,$4E,$4B,$20,$4D,$FF,$FF
        .byte   $54,$41,$4E,$4B,$20,$4E,$FF,$FF
EditionYearText:
        .byte   $31,$39,$39,$30,$FF
; Три байта перед строкой верхней части целой базы; статических ссылок нет.
UnreferencedTileSequenceE5e5Prefix:
LE5E5:  .byte   $01,$0F,$02
; Верхняя строка голой целой базы, используемая вражеской веткой PowerUpEffect2.
IntactBaseUpperRow:
LE5E8:  .byte   $00,$00,BaseTileIntactUpperLeft,BaseTileIntactUpperRight,$00,$00,$FF
; Горизонтальный разделитель variant-меню: два вызова выводят 20 tiles $5C
; начиная с column 7 в rows 1 и 4, то есть занимают columns 7..26 без wrap.
; Терминатор $FF обязателен; изменение длины влияет на pre-NMI capacity menu
; queue (текущий batch header+2*divider+option занимает 69 байтов).
VariantMenuDividerText:
LE5EF:  .byte   $5C,$5C,$5C,$5C,$5C,$5C,$5C,$5C
        .byte   $5C,$5C,$5C,$5C,$5C,$5C,$5C,$5C
        .byte   $5C,$5C,$5C,$5C,$FF
