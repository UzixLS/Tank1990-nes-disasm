; Строки заглавного экрана и статистики ($D284-$D2F7).

; $FF-терминированные строки экранного шрифта. ASCII-подобные байты совпадают
; с видимыми латинскими буквами; значения вне этого диапазона — специальные
; тайлы/значки, поэтому ниже они не интерпретируются как управляющий язык.
; QueueTileAtCoordinates копирует строку и в shadow, и в PPU update buffer;
; терминатор служит только потоку и в shadow не записывается.
CreditsWrittenByText:
LD284:  .byte   $57,$52,$49,$54,$54,$45,$4E,$20,$42,$59,$FF
; Девять tiles; BuildTitleNametable ставит 12-byte pending command в (11,24).
; Эта фиксированная длина определяет его документированный итоговый cursor=12.
CreditsCopyrightText:
LD28F:  .byte   $40,$20,$59,$53,$20,$31,$39,$39,$30,$FF
; Шеститайловая нижняя строка голой базы для специальной ветви PowerUpEffect2.
IntactBaseLowerRow:
LD299:  .byte   $00,$00,BaseTileIntactLowerLeft,BaseTileIntactLowerRight,$00,$00,$FF
TitleCityText:
LD2A0:  .byte   $43,$49,$54,$59,$FF
; Title score-row prefixes: два tiles P1/P2 (по 5 bytes queue command) и три
; tiles high score (6 bytes). Их длины входят в 21..29/31..43-byte score batch.
PlayerOneScorePrefix:
LD2A5:  .byte   $5E,$6B,$FF
PlayerTwoScorePrefix:
LD2A8:  .byte   $5F,$6B,$FF
; Компактные двухтайловые метки игроков для боевого HUD.
PlayerOneCompactMarker:
LD2AB:  .byte   $58,$13,$FF
PlayerTwoCompactMarker:
LD2AE:  .byte   $5A,$13,$FF
HighScoreCompactPrefix:
LD2B1:  .byte   $48,$49,$6B,$FF
; Полная и сокращённая подписи рекорда используются разными экранами.
HighScoreText:
LD2B5:  .byte   $48,$49,$53,$43,$4F,$52,$45,$FF
HighScoreStatisticsPrefix:
LD2BD:  .byte   $48,$49,$6B,$53,$43,$4F,$52,$45,$FF
; Title menu lines содержат 8/9/12 tiles и дают команды 11/12/15 bytes,
; суммарно 38. Terminator не рисуется; изменение длин требует пересчитать
; capacity BuildTitleNametable и проверить горизонтальный layout от column 11.
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
