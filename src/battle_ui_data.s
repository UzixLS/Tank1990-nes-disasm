; Строки HUD, базы и послеэтапной статистики ($D358-$D3D4).
; Все строки в этом файле завершаются $FF; терминатор не является экранным тайлом.

; Литеральная строка ORIKO; статических ссылок нет.
OrikoText:
LD358:  .byte   $4F,$52,$49,$4B,$4F,$FF
; Трёхтайловая подпись PTS. BuildStageStatisticsScreen ставит её
; после четырёх полей P1 и, в 2P, ещё четырёх P2; winner branch — рядом
; с 1000. Одна QueueTileAtCoordinates command занимает 6 bytes.
PointsText:
LD35E:  .byte   $50,$54,$53,$FF
; Два одинаковых тайла маркера оставшихся противников в HUD.
RemainingEnemyMarkerTiles:
LD362:  .byte   $6A,$6A,$FF
; Верхняя и нижняя двухтайловые строки значка StageNumber в HUD.
StageHudUpperTiles:
LD365:  .byte   $6C,$FC,$FF
StageHudLowerTiles:
LD368:  .byte   $6D,$FD,$FF
BlankTileText:
LD36B:  .byte   $11,$FF

; Шеститайловые строки базы. TerrainTileBrick/Steel — стены,
; $C8-$CB — целая база, $CC-$CF — разрушенная. Эти строки одновременно
; копируются в shadow и ставятся в PPU-очередь.
BlankBaseRow:
LD36D:  .byte   $00,$00,$00,$00,$00,$00,$FF
BrickBaseTopRow:
LD374:  .byte   $00,TerrainTileBrick,TerrainTileBrick,TerrainTileBrick,TerrainTileBrick,$00,$FF
BrickBaseUpperRow:
LD37B:  .byte   $00,TerrainTileBrick,BaseTileIntactUpperLeft,BaseTileIntactUpperRight,TerrainTileBrick,$00,$FF
BrickBaseLowerRow:
LD382:  .byte   $00,TerrainTileBrick,BaseTileIntactLowerLeft,BaseTileIntactLowerRight,TerrainTileBrick,$00,$FF
BlankSteelBaseRow:
LD389:  .byte   $00,$00,$00,$00,$00,$00,$FF
SteelBaseTopRow:
LD390:  .byte   $00,TerrainTileSteel,TerrainTileSteel,TerrainTileSteel,TerrainTileSteel,$00,$FF
SteelBaseUpperRow:
LD397:  .byte   $00,TerrainTileSteel,BaseTileIntactUpperLeft,BaseTileIntactUpperRight,TerrainTileSteel,$00,$FF
SteelBaseLowerRow:
LD39E:  .byte   $00,TerrainTileSteel,BaseTileIntactLowerLeft,BaseTileIntactLowerRight,TerrainTileSteel,$00,$FF
IntactBaseUpperTiles:
LD3A5:  .byte   BaseTileIntactUpperLeft,BaseTileIntactUpperRight,$FF
IntactBaseLowerTiles:
LD3A8:  .byte   BaseTileIntactLowerLeft,BaseTileIntactLowerRight,$FF
DestroyedBaseUpperTiles:
LD3AB:  .byte   BaseTileDestroyedUpperLeft,BaseTileDestroyedUpperRight,$FF
DestroyedBaseLowerTiles:
LD3AE:  .byte   BaseTileDestroyedLowerLeft,BaseTileDestroyedLowerRight,$FF

; Строки экрана статистики. Каждый one-tile marker даёт 4-byte queue
; command; четыре копии стоят напротив четырёх enemy rows. Тайл $5D
; намеренно разделяют маркер P2 и курсор variant-меню — это два
; подтверждённых consumer одного байта.
PlayerOneStatisticsMarker:
LD3B1:  .byte   $5B,$FF
PlayerTwoStatisticsMarker:
VariantMenuSelectionCursor:
LD3B3:  .byte   $5D,$FF
StatisticsTotalText:
; 5 tiles, queue command 8 bytes; column 6,row 23.
LD3B5:  .byte   $54,$4F,$54,$41,$4C,$FF
StatisticsDivider:
; 8 tiles, queue command 11 bytes; column 12,row 22.
LD3BB:  .byte   $5C,$5C,$5C,$5C,$5C,$5C,$5C,$5C,$FF
StatisticsBonusText:
; 6 tiles, queue command 9 bytes. Первые пять — BONUS; точная
; глифическая роль заключительного специального тайла $15 НЕ ДОКАЗАНА.
LD3C4:  .byte   $42,$4F,$4E,$55,$53,$15,$FF
StatisticsStageText:
; 5 literal tiles, queue command 8 bytes; column 12,row 5.
LD3CB:  .byte   $53,$54,$41,$47,$45,$FF
; Упакованные десятичные награды за четыре типа противников.
; PreparePackedScoreIncrement помещает эти нибблы в сотни/десятки, поэтому
; приращения award rows за одно убийство равны 100, 200, 300 и 400.
; Индекс StatisticsEnemyType жёстко ограничен 0..3 циклом; bounds check нет.
; Оба nibble каждого ненулевого байта должны быть decimal digits 0..9;
; PreparePackedScoreIncrement не валидирует arbitrary hex digits.
; Это отдельный дубликат EnemyTypeScoreAwards, который gameplay использует
; при фактическом уничтожении танка. Ромхак должен менять обе таблицы
; согласованно, если послеэтапная анимация должна совпадать с начислениями.
; Байт $00 имеет в PreparePackedScoreIncrement особый смысл 1000, а не 0.
ScoreAwardsByEnemyType:
LD3D1:  .byte   $10,$20,$30,$40
