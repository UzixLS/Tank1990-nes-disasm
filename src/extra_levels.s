; Пять дополнительных карт Tank 1990 ($A38C-$A552).

ExtraLevelCount = 5

; Пять 91-byte записей того же packed TSA-формата, 455 bytes total. Символ
; ExtraLevels не имеет статических ссылок, и ClassicLevelSetDescriptors сюда не
; указывает: штатный LoadAndDrawStage эти карты не выбирает. Данные выделены как
; asset для byte-exact сборки/аудита и могут стать catalog только после явного
; добавления descriptor/caller logic с проверкой selector и stage bounds.
ExtraLevels:
        .incbin "../build/extra-levels.bin"
