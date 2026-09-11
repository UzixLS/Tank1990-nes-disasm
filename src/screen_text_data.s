; Строки заглавного экрана и статистики ($D284-$D2F7).

; $FF-терминированные строки экранного шрифта. ASCII-подобные байты совпадают
; с видимыми латинскими буквами; значения вне этого диапазона — специальные
; тайлы/значки, поэтому ниже они не интерпретируются как управляющий язык.
CreditsWrittenByText:
LD284:  .byte   $57,$52,$49,$54,$54,$45,$4E,$20,$42,$59,$FF
CreditsCopyrightText:
LD28F:  .byte   $40,$20,$59,$53,$20,$31,$39,$39,$30,$FF
TitleDecorativeTileRow:
IntactBaseLowerRow:
LD299:  .byte   $00,$00,$C9,$CB,$00,$00,$FF
TitleCityText:
LD2A0:  .byte   $43,$49,$54,$59,$FF
PlayerOneScorePrefix:
LD2A5:  .byte   $5E,$6B,$FF
PlayerTwoScorePrefix:
LD2A8:  .byte   $5F,$6B,$FF
PlayerOneCompactMarker:
LD2AB:  .byte   $58,$13,$FF
PlayerTwoCompactMarker:
LD2AE:  .byte   $5A,$13,$FF
HighScoreCompactPrefix:
LD2B1:  .byte   $48,$49,$6B,$FF
HighScoreText:
LD2B5:  .byte   $48,$49,$53,$43,$4F,$52,$45,$FF
HighScoreStatisticsPrefix:
LD2BD:  .byte   $48,$49,$6B,$53,$43,$4F,$52,$45,$FF
OnePlayerMenuText:
LD2C6:  .byte   $31,$20,$50,$4C,$41,$59,$45,$52,$FF
TwoPlayersMenuText:
LD2CF:  .byte   $32,$20,$50,$4C,$41,$59,$45,$52,$53,$FF
PlayerOneStatisticsHeader:
LD2D9:  .byte   $5E,$6B,$50,$4C,$41,$59,$45,$52,$FF
PlayerTwoStatisticsHeader:
LD2E2:  .byte   $5F,$6B,$50,$4C,$41,$59,$45,$52,$FF
ConstructionMenuText:
LD2EB:  .byte   $43,$4F,$4E,$53,$54,$52,$55,$43,$54,$49,$4F,$4E,$FF
