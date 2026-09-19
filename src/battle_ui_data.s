; Строки HUD, базы и послеэтапной статистики ($D358-$D3D4).
; Все строки в этом файле завершаются $FF; терминатор не является экранным тайлом.

; Литеральная строка ORIKO; статических ссылок нет.
OrikoText:
LD358:  .byte   $4F,$52,$49,$4B,$4F,$FF
; Подпись PTS для восьми полей счётчиков на экране статистики.
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

; Строки экрана статистики. Тайл $5D намеренно разделяют маркер второго
; игрока и курсор variant-меню — это два подтверждённых consumer одного байта.
PlayerOneStatisticsMarker:
LD3B1:  .byte   $5B,$FF
PlayerTwoStatisticsMarker:
VariantMenuSelectionCursor:
LD3B3:  .byte   $5D,$FF
StatisticsTotalText:
LD3B5:  .byte   $54,$4F,$54,$41,$4C,$FF
StatisticsDivider:
LD3BB:  .byte   $5C,$5C,$5C,$5C,$5C,$5C,$5C,$5C,$FF
StatisticsBonusText:
LD3C4:  .byte   $42,$4F,$4E,$55,$53,$15,$FF
StatisticsStageText:
LD3CB:  .byte   $53,$54,$41,$47,$45,$FF
; Упакованные десятичные награды за четыре типа противников.
; PreparePackedScoreIncrement помещает эти нибблы в сотни/десятки, поэтому
; фактические прибавки к счёту равны 100, 200, 300 и 400.
ScoreAwardsByEnemyType:
LD3D1:  .byte   $10,$20,$30,$40
