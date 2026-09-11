; Тайловые строки заголовка и меню вариантов ($E570-$E603).

; 14 фиксированных 8-байтных тайловых строк "TANK A".."TANK N", каждая с двумя $FF.
; DrawVariantTitleData выбирает их по двум диапазонам $46; CopyThreeVariantLabelBytes читает три байта из середины.
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
LE5E8:  .byte   $00,$00,$C8,$CA,$00,$00,$FF
; Горизонтальный разделитель variant-меню: два вызова из RunVariantSelectionMenu
; выводят эту строку на строках 1 и 4. Формат — 20 тайлов $5C и терминатор $FF.
VariantMenuDividerText:
LE5EF:  .byte   $5C,$5C,$5C,$5C,$5C,$5C,$5C,$5C
        .byte   $5C,$5C,$5C,$5C,$5C,$5C,$5C,$5C
        .byte   $5C,$5C,$5C,$5C,$FF
