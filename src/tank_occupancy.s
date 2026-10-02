; Маркеры занятости клеток танками ($E181-$E23A).
; Файл включается из projectiles.s в исходной позиции для сохранения адресов ROM.

OccupancyScanSlot          = $5A
TankOccupancyCenterTileOffset = $21
TankOccupancyLeftTileOffset   = $20
TankOccupancyAboveTileOffset  = $01

TankOccupancyLeftOfCenterFlag = $80
TankOccupancyAboveCenterFlag  = $40
TankOccupancyProbeHalfExtent  = $08
OccupancyCachedPageBitsMask   = $03
TankOccupancyMarkerFlag       = $80
TankOccupancyMarkerClearMask  = $7F

; Перед UpdateTanks строит transient snapshot старых позиций слотов 7..0 со
; state $80..$DF. Для каждого слота ScratchPtr указывает на 8x8 tile точки
; (ObjectX-8,ObjectY-8). Маркер ставится в tile по offset $21; при
; ObjectX mod 8=0 также по $20 слева, при ObjectY mod 8=0 — по $01 выше.
; Даже при обеих выровненных координатах диагональный upper-left tile не
; помечается: snapshot занимает L-образный набор из максимум трёх tiles.
;
; Кеш формата на слот:
;   TankOccupancyPtrLo          — low byte базового ScratchPtr;
;   TankOccupancyPageAndFlags   — bits0..1=(ScratchPtrHi&3), bits2..5=0,
;                                 bit6=above marker, bit7=left marker.
; Полный high byte восстанавливается как $04|bits0..1, поэтому формат жёстко
; привязан к 1-KiB shadow $0400-$07FF и не подходит для произвольно
; перемещённого/расширенного shadow без изменения кода.
;
; Bit7 меняется только в NametableShadow и не ставится в PPU queue. Mark/Clear
; должны оставаться парой в одном logic tick без промежуточного shadow upload:
; иначе временный marker попадёт в PPU как tile code. Схема предполагает, что
; все tiles, на которых может находиться танк, исходно имеют bit7=0: clear не
; хранит старое значение и безусловно снимает bit7. Два танка могут разделять
; marker без refcount, но Clear вызывается только после всего movement pass.
;
; Для P1/P2 точное значение center tile $21 ставит ice-active bit
; PlayerIceState; любое другое снимает только этот bit. Уже помеченный ранее
; обработанным слотом ice byte $A1 не распознаётся. Skipped state не обновляет
; ни ice flag, ни кеш слота.
;
; Координаты не clipping-уются. ObjectX/Y<8 оборачивают вычитание и заставляют
; offsets выйти из соответствующей строки/за $07FF; для tile-области также
; требуется ObjectY<=239 (rows 30/31 являются attribute storage). Штатная
; геометрия поля удовлетворяет этим ограничениям.
;
; Выход: OccupancyScanSlot=$FF, X=0, N=1/Z=0. Если был подходящий слот,
; ScratchPtr и PpuTileRowBits/TerrainSubcellMask отражают последний обработанный
; (с наименьшим индексом), Y — его последний marker; иначе scratch и Y сохранены.
; A зависит от проверки/обработки финального слота 0 и не является результатом
; последнего подходящего слота. Меняет occupancy cache, marker bytes
; shadow и для активных P1/P2 bit7 PlayerIceState; PPU queue/registers не трогает.
MarkTankOccupiedTiles:
LE181:  lda     #(TankSlotCount-1)
        sta     OccupancyScanSlot
MarkNextTankOccupiedTiles:
LE185:  ldx     OccupancyScanSlot
        lda     ObjectState,x
        bpl     AdvanceTankOccupancySlot
        cmp     #NonTargetableTankStateMin
        bcs     AdvanceTankOccupancySlot
        lda     ObjectY,x
        sec
        sbc     #TankOccupancyProbeHalfExtent
        tay
        lda     ObjectX,x
        sec
        sbc     #TankOccupancyProbeHalfExtent
        tax
        jsr     PixelCoordinatesToShadowPointer
        ldx     OccupancyScanSlot
        lda     ScratchPtrLo
        sta     TankOccupancyPtrLo,x
        lda     ScratchPtrHi
        and     #OccupancyCachedPageBitsMask
        sta     TankOccupancyPageAndFlags,x
        ldy     #TankOccupancyCenterTileOffset
        cpx     #FirstEnemyTankSlot
        bcs     MarkTankCenterOccupied
        lda     (ScratchPtrLo),y
        cmp     #PlayerIceTile
        bne     ClearPlayerIceFlag
        lda     #PlayerIceActiveFlag
        ora     PlayerIceState,x
        sta     PlayerIceState,x
        jmp     MarkTankCenterOccupied

ClearPlayerIceFlag:
LE1C1:  lda     PlayerIceState,x
        and     #PlayerIceInactiveMask
        sta     PlayerIceState,x
MarkTankCenterOccupied:
LE1C9:  jsr     SetTileOccupiedFlag
        lda     ObjectX,x
        and     #TankGridSubpixelMask
        bne     CheckTankVerticalAlignment
        lda     TankOccupancyPageAndFlags,x
        ora     #TankOccupancyLeftOfCenterFlag
        sta     TankOccupancyPageAndFlags,x
        ldy     #TankOccupancyLeftTileOffset
        jsr     SetTileOccupiedFlag
CheckTankVerticalAlignment:
LE1DD:  lda     ObjectY,x
        and     #TankGridSubpixelMask
        bne     AdvanceTankOccupancySlot
        lda     TankOccupancyPageAndFlags,x
        ora     #TankOccupancyAboveCenterFlag
        sta     TankOccupancyPageAndFlags,x
        ldy     #TankOccupancyAboveTileOffset
        jsr     SetTileOccupiedFlag
AdvanceTankOccupancySlot:
LE1EE:  dec     OccupancyScanSlot
        bpl     MarkNextTankOccupiedTiles
        rts

; Вход: (ScratchPtr),Y указывает tile shadow, исходный bit7=0. Ставит marker
; bit7 без изменения bits0..6. Выход: A=новый и уже записанный byte; X/Y,
; ScratchPtr и остальная RAM сохранены, N=1/Z=0. PPU queue/registers не трогает.
SetTileOccupiedFlag:
LE1F3:  lda     (ScratchPtrLo),y
        ora     #TankOccupancyMarkerFlag
        sta     (ScratchPtrLo),y
        rts

; После UpdateTanks снимает marker bit7 по кешу СТАРЫХ позиций, снова обходя
; слоты 7..0. Фильтр использует уже ТЕКУЩИЙ state $80..$DF, а отдельного valid
; flag у кеша нет. Поэтому слот, ставший active внутри UpdateTanks, может
; очистить stale cache; слот, покинувший диапазон, оставит marker. Это исходное
; поведение сохранено ради byte-exact результата.
;
; Сначала всегда очищается center offset $21, затем условные left/above согласно
; bits7/6 кеша. Refcount нет: при общем byte первый очищаемый слот снимает marker
; за всех, но все движения к этому моменту уже закончены. Cache и ice state не
; изменяются. Требуются кеш от парного Mark и неизменная база shadow $0400.
;
; Выход: OccupancyScanSlot=$FF, X=0, N=1/Z=0. ScratchPtr указывает на кеш
; последнего подходящего слота, Y — на его последний очищенный offset; если таких
; слотов нет, ScratchPtr/Y сохранены. A зависит от финального пути слота 0 и
; стабильного значения не имеет. Меняет только marker bytes shadow,
; OccupancyScanSlot и ScratchPtr; PPU queue/registers не трогает.
ClearTankOccupiedTiles:
LE1FA:  lda     #(TankSlotCount-1)
        sta     OccupancyScanSlot
ClearNextTankOccupiedTiles:
LE1FE:  ldx     OccupancyScanSlot
        lda     ObjectState,x
        bpl     AdvanceClearOccupancySlot
        cmp     #NonTargetableTankStateMin
        bcs     AdvanceClearOccupancySlot
        lda     TankOccupancyPtrLo,x
        sta     ScratchPtrLo
        lda     TankOccupancyPageAndFlags,x
        and     #OccupancyCachedPageBitsMask
        ora     #>NametableShadow
        sta     ScratchPtrHi
        ldy     #TankOccupancyCenterTileOffset
        jsr     ClearTileOccupiedFlag
        lda     TankOccupancyPageAndFlags,x
        and     #TankOccupancyLeftOfCenterFlag
        beq     ClearTankVerticalOccupancy
        ldy     #TankOccupancyLeftTileOffset
        jsr     ClearTileOccupiedFlag
ClearTankVerticalOccupancy:
LE224:  lda     TankOccupancyPageAndFlags,x
        and     #TankOccupancyAboveCenterFlag
        beq     AdvanceClearOccupancySlot
        ldy     #TankOccupancyAboveTileOffset
        jsr     ClearTileOccupiedFlag
AdvanceClearOccupancySlot:
LE22F:  dec     OccupancyScanSlot
        bpl     ClearNextTankOccupiedTiles
        rts

; Вход: (ScratchPtr),Y указывает ранее помеченный shadow byte. Безусловно
; снимает bit7 и не восстанавливает его исходное значение. Выход: A=новый и
; уже записанный byte, N=0, Z по его bits0..6; X/Y, ScratchPtr и остальная RAM
; сохранены. PPU queue/registers не трогает.
ClearTileOccupiedFlag:
LE234:  lda     (ScratchPtrLo),y
        and     #TankOccupancyMarkerClearMask
        sta     (ScratchPtrLo),y
        rts
