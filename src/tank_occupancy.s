; Маркеры занятости клеток танками ($E181-$E23A).
; Файл включается из projectiles.s в исходной позиции для сохранения адресов ROM.

OccupancyScanSlot          = $5A
TankOccupancyCenterOffset  = $21
TankOccupancyLeftOffset    = $20
TankOccupancyAboveOffset   = $01

TankOccupancyLeftOfCenterFlag = $80
TankOccupancyAboveCenterFlag  = $40
TankOccupancyProbeHalfExtent  = $08
NametableShadowPageMask       = $03
TankOccupancyTileFlag         = $80
TerrainWithoutOccupancyMask   = $7F

; Перед движением строит transient snapshot старых позиций танков со state
; $80..$DF, обходя слоты 7..0. Base pointer соответствует тайлу точки
; (ObjectX-8,ObjectY-8). Всегда помечает center offset $21; при ObjectX mod8=0
; также tile слева ($20), при ObjectY mod8=0 — tile выше ($01). Диагональный
; upper-left tile не помечается. Pointer/page и признаки дополнительных клеток
; кэшируются в TankOccupancyPtrLo/TankOccupancyPageAndFlags.
;
; Bit7 меняется только в NametableShadow и не ставится в PPU queue. Mark/Clear
; должны оставаться парой в одном logic tick без промежуточного shadow upload:
; иначе временный marker попадёт в PPU как tile code. Схема предполагает, что
; исходные проходимые tile bytes имеют bit7=0; clear не хранит исходное значение.
; Два танка могут разделять marker без refcount, но clear идёт после всего move pass.
;
; Для P1/P2 exact center tile $21 ставит ice-active bit PlayerIceState; другое
; значение снимает только этот bit. Уже помеченный другим танком ice byte $A1
; не распознаётся. Вычитание 8 беззнаковое, поэтому romhack spawn coordinates
; должны быть >=8. Выход: OccupancyScanSlot=$FF, X=0; A/Y/ScratchPtr и
; TerrainSubcellMask(PpuTileRowBits) зависят от последнего подходящего слота.
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
        and     #NametableShadowPageMask
        sta     TankOccupancyPageAndFlags,x
        ldy     #TankOccupancyCenterOffset
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
        ldy     #TankOccupancyLeftOffset
        jsr     SetTileOccupiedFlag
CheckTankVerticalAlignment:
LE1DD:  lda     ObjectY,x
        and     #TankGridSubpixelMask
        bne     AdvanceTankOccupancySlot
        lda     TankOccupancyPageAndFlags,x
        ora     #TankOccupancyAboveCenterFlag
        sta     TankOccupancyPageAndFlags,x
        ldy     #TankOccupancyAboveOffset
        jsr     SetTileOccupiedFlag
AdvanceTankOccupancySlot:
LE1EE:  dec     OccupancyScanSlot
        bpl     MarkNextTankOccupiedTiles
        rts

; Вход: ScratchPtr+Y — байт nametable shadow. Ставит bit7. Выход: A=новый
; byte; X/Y/ScratchPtr сохраняет, PPU queue/registers не меняет; портит flags.
SetTileOccupiedFlag:
LE1F3:  lda     (ScratchPtrLo),y
        ora     #TankOccupancyTileFlag
        sta     (ScratchPtrLo),y
        rts

; После движения снимает occupancy-bit7 по кэшу старых позиций. Повторно
; фильтрует ТЕКУЩИЙ state $80..$DF, а отдельного marked-valid flag нет. Поэтому
; spawn slot, ставший active внутри UpdateTanks, может очистить stale cache;
; наоборот, slot, вышедший из active range, оставит marker. Это исходный edge,
; который byte-exact версия сохраняет. Clear также не refcounted: при общем
; byte первый танк снимает marker за обоих, но движение к этому моменту завершено.
; Выход: OccupancyScanSlot=$FF, X=0; меняет cached shadow bytes и scratch,
; PPU queue/registers не трогает; A/Y не определены.
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
        and     #NametableShadowPageMask
        ora     #>NametableShadow
        sta     ScratchPtrHi
        ldy     #TankOccupancyCenterOffset
        jsr     ClearTileOccupiedFlag
        lda     TankOccupancyPageAndFlags,x
        and     #TankOccupancyLeftOfCenterFlag
        beq     ClearTankVerticalOccupancy
        ldy     #TankOccupancyLeftOffset
        jsr     ClearTileOccupiedFlag
ClearTankVerticalOccupancy:
LE224:  lda     TankOccupancyPageAndFlags,x
        and     #TankOccupancyAboveCenterFlag
        beq     AdvanceClearOccupancySlot
        ldy     #TankOccupancyAboveOffset
        jsr     ClearTileOccupiedFlag
AdvanceClearOccupancySlot:
LE22F:  dec     OccupancyScanSlot
        bpl     ClearNextTankOccupiedTiles
        rts

; Вход: ScratchPtr+Y — байт nametable shadow. Безусловно снимает bit7, не
; восстанавливая исходный terrain class. Выход: A=новый byte;
; X/Y/ScratchPtr сохраняет, PPU queue/registers не меняет; портит flags.
ClearTileOccupiedFlag:
LE234:  lda     (ScratchPtrLo),y
        and     #TerrainWithoutOccupancyMask
        sta     (ScratchPtrLo),y
        rts
