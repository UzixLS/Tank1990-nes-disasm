; Заглавный экран, игровые UI-сценарии и их данные ($C9C0-$D3FF).

StatisticsPlayer1Count = $5D
StatisticsPlayer2Count = $5E
StatisticsEnemyType    = $5A
StatisticsRowActive    = $7C
Player1StageKillTotal  = $7D
Player2StageKillTotal  = $7E
CurtainRowIndex        = $57
NametableRowFillTile   = $63

.include "title_menu.s"
; На границе кадра формирует PPU-команды для надписи и десятичного StageNumber.
; Сначала пишет тайлы $23..$27,$11,$11 с ($0C,$0E), затем число с bias $6E.
; Меняет A/X/Y, ScratchPtr, $00, $35-$3C, $60 и PPU-очередь; на выходе $60=0.
UpdateStageNumberDisplay:
LCA91:  jsr     WaitForNextFrame
        ldx     #$0C
        ldy     #$0E
        jsr     TileCoordinatesToShadowAddress
        ldx     PpuBufferPos
        clc
        adc     #$1C
        sta     PpuUpdateBuffer,x
        inx
        tya
        sta     PpuUpdateBuffer,x
        inx
        lda     #$23
        sta     PpuUpdateBuffer,x
        inx
        lda     #$24
        sta     PpuUpdateBuffer,x
        inx
        lda     #$25
        sta     PpuUpdateBuffer,x
        inx
        lda     #$26
        sta     PpuUpdateBuffer,x
        inx
        lda     #$27
        sta     PpuUpdateBuffer,x
        inx
        lda     #$11
        sta     PpuUpdateBuffer,x
        inx
        lda     #$11
        sta     PpuUpdateBuffer,x
        inx
        lda     #$FF
        sta     PpuUpdateBuffer,x
        inx
        stx     PpuBufferPos
        lda     #$6E
        sta     TileTranslationOffset
        lda     StageNumber
        jsr     ByteToDisplayDigits
        ldy     #$36
        ldx     #$0E
        jsr     SelectVisibleDigits
        ldy     #$0E
        jsr     QueueTranslatedTileString
        lda     #$00
        sta     TileTranslationOffset
        rts

.include "base_render.s"
; За 64 кадра переносит NametableAttributes в PPU $23C0-$23FF,
; по одному байту за кадр. Меняет A/X/Y, ScratchPtr и PPU-очередь.
UploadAttributesGradually:
LCC27:  ldy     #$00
        lda     #$23
        sta     ScratchPtrHi
        lda     #$C0
        sta     ScratchPtrLo
UploadNextAttributeByte:
LCC31:  jsr     WaitForNextFrame
        ldx     PpuBufferPos
        lda     ScratchPtrHi
        sta     PpuUpdateBuffer,x
        inx
        lda     ScratchPtrLo
        sta     PpuUpdateBuffer,x
        inx
        lda     NametableAttributes,y
        iny
        sta     PpuUpdateBuffer,x
        inx
        lda     #$FF
        sta     PpuUpdateBuffer,x
        inx
        stx     PpuBufferPos
        lda     #$01
        jsr     AddAToPointer
        cpy     #$40
        bne     UploadNextAttributeByte
        rts

; Ставит в PPU-очередь полную 32-тайловую строку nametable.
; Вход: Y — номер строки; если NametableRowFillTile=0, данные берутся из
; shadow, иначе вся строка заполняется этим тайлом. Меняет A/X/Y, ScratchPtr,
; scratch $00 и PPU-очередь.
QueueNametableRow:
LCC5C:  ldx     #$00
        jsr     TileCoordinatesToShadowAddress
        sta     ScratchPtrHi
        sty     ScratchPtrLo
        ldx     PpuBufferPos
        lda     ScratchPtrHi
        clc
        adc     #$1C
        sta     PpuUpdateBuffer,x
        inx
        lda     ScratchPtrLo
        sta     PpuUpdateBuffer,x
        inx
        ldy     #$00
QueueNextNametableTile:
LCC78:  lda     NametableRowFillTile
        bne     StoreNametableTile
        lda     (ScratchPtrLo),y
StoreNametableTile:
LCC7E:  sta     PpuUpdateBuffer,x
        inx
        iny
        cpy     #$20
        bne     QueueNextNametableTile
        lda     #$FF
        sta     PpuUpdateBuffer,x
        inx
        stx     PpuBufferPos
        rts

; Шторка перед выбором этапа: за 16 кадров заполняет тайлом $11 парные строки,
; двигаясь от верхнего/нижнего краёв к центру. Меняет
; CurtainRowIndex/NametableRowFillTile и PPU-очередь.
CloseNametableCurtain:
LCC90:  lda     #$11
        sta     NametableRowFillTile
        lda     #$00
        sta     CurtainRowIndex
CloseCurtainNextRowPair:
LCC98:  jsr     WaitForNextFrame
        ldy     CurtainRowIndex
        jsr     QueueNametableRow
        lda     #$1D
        sec
        sbc     CurtainRowIndex
        tay
        jsr     QueueNametableRow
        inc     CurtainRowIndex
        lda     CurtainRowIndex
        cmp     #$10
        bne     CloseCurtainNextRowPair
        rts

; Обратная шторка: восстанавливает пары строк из shadow, двигаясь от центра
; к краям. Центральная пара при первых двух проходах записывается дважды.
; Меняет CurtainRowIndex/NametableRowFillTile и PPU-очередь.
OpenNametableCurtain:
LCCB2:  lda     #$00
        sta     NametableRowFillTile
        lda     #$0F
        sta     CurtainRowIndex
OpenCurtainNextRowPair:
LCCBA:  jsr     WaitForNextFrame
        ldy     CurtainRowIndex
        jsr     QueueNametableRow
        lda     #$1D
        sec
        sbc     CurtainRowIndex
        tay
        jsr     QueueNametableRow
        dec     CurtainRowIndex
        lda     CurtainRowIndex
        cmp     #$FF
        bne     OpenCurtainNextRowPair
        rts

.include "stage_statistics.s"
.include "score_rewards.s"
.include "title_render.s"
; Адаптер двух строк без статических ссылок в текущем графе вызовов.
; Вход: A становится старшим байтом указателя A:$F8 для строки в ($04,$19);
; затем всегда трактует поток с LegacyChecksumCodeStreamStart ($D320) как
; строку для ($06,$1B). Начало потока — opcode STA RuntimeChecksumExpected в
; InitializeRuntimeChecksumGuard. Строковый чтец проходил бы дальше по байтам
; опкодов до $FF в $D331. При A=$D2 первая строка аналогично началась бы с кода проверки $D2F8.
; Без вызывающего контекста назначение этого пути не подтверждено. Между потоками ждёт кадр.
; Назначение вызывающего сценария не подтверждено. Меняет A/X/Y, ScratchPtr
; и PPU-очередь.
QueueTwoLegacyScreenLines:
LD255:  nop
        sta     ScratchPtrHi
        lda     #$F8
        sta     ScratchPtrLo
        ldx     #$04
        ldy     #$19
        jsr     QueueTileAtCoordinates
        jsr     WaitForNextFrame
        lda     #>LegacyChecksumCodeStreamStart
        sta     ScratchPtrHi
        lda     #<LegacyChecksumCodeStreamStart
        sta     ScratchPtrLo
        ldx     #$06
        ldy     #$1B
        jsr     QueueTileAtCoordinates
        rts
; Ждёт X кадров, на каждом кадре заново выводя четыре значка статистики.
; Вход X должен быть 1..255: при X=0 цикл выполнит 256 проходов.
; Выход X=0; A/Y и OAM меняются через DrawStatisticsEnemyIcons.
DelayWithStatisticsIcons:
LD276:  jsr     WaitForNextFrame
        txa
        pha
        jsr     DrawStatisticsEnemyIcons
        pla
        tax
        dex
        bne     DelayWithStatisticsIcons
        rts

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
.include "runtime_checksum_init.s"
; Три самостоятельных $FF-терминированных фрагмента без статических ссылок.
; Байты $4F..$48 во втором попадают в буквенный диапазон экранного шрифта, но смысл строки не утверждается.
UnreferencedScreenTextFragments:
LD334:  .byte   $4F,$50,$45,$4E,$6B,$52,$45,$41,$43,$48,$FF
LD33F:  .byte   $69,$FF
; Двухбайтная строка значка жизней используется UpdateLivesHud в двух позициях.
LivesHudIconText:
LD341:  .byte   $14,$FF
; Литеральная строка GAME; статических ссылок нет.
GameText:
LD343:  .byte   $47,$41,$4D,$45,$FF
; Литеральная строка OVER; статических ссылок нет.
OverText:
LD348:  .byte   $4F,$56,$45,$52,$FF
.include "remainder.s"
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

; Семитайловые строки базы. $0F — кирпичная стена, $10 — стальная,
; $C8-$CB — целая база, $CC-$CF — разрушенная. Эти строки одновременно
; копируются в shadow и ставятся в PPU-очередь.
BlankBaseRow:
LD36D:  .byte   $00,$00,$00,$00,$00,$00,$FF
BrickBaseTopRow:
LD374:  .byte   $00,$0F,$0F,$0F,$0F,$00,$FF
BrickBaseUpperRow:
LD37B:  .byte   $00,$0F,$C8,$CA,$0F,$00,$FF
BrickBaseLowerRow:
LD382:  .byte   $00,$0F,$C9,$CB,$0F,$00,$FF
BlankSteelBaseRow:
LD389:  .byte   $00,$00,$00,$00,$00,$00,$FF
SteelBaseTopRow:
LD390:  .byte   $00,$10,$10,$10,$10,$00,$FF
SteelBaseUpperRow:
LD397:  .byte   $00,$10,$C8,$CA,$10,$00,$FF
SteelBaseLowerRow:
LD39E:  .byte   $00,$10,$C9,$CB,$10,$00,$FF
IntactBaseUpperTiles:
LD3A5:  .byte   $C8,$CA,$FF
IntactBaseLowerTiles:
LD3A8:  .byte   $C9,$CB,$FF
DestroyedBaseUpperTiles:
LD3AB:  .byte   $CC,$CE,$FF
DestroyedBaseLowerTiles:
LD3AE:  .byte   $CD,$CF,$FF

; Строки экрана статистики.
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
.include "direction_tables.s"
; Оба известных потребителя индексируют таблицы направлением 0..3; эти три $FF лежат за их границей.
PaddingBeforePowerUpEffect0:
LD3DD:  .byte   $FF,$FF,$FF
.include "powerup_effect0.s"

; Заполнение конца экранного модуля до следующей процедуры $D400; ссылок на эти байты нет.
ScreenModuleEndPadding:
LD3FD:  .byte   $FF,$FF,$FF
