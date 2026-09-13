; Маркеры занятости клеток танками ($E181-$E23A).
; Файл включается из projectiles.s в исходной позиции для сохранения адресов ROM.

TankShadowPtrLo         = $E0
TankShadowPtrHiAndFlags = $E8
OccupancyTankSlot       = $5A
TankCenterShadowOffset  = $21

TankOccupancyBelowFlag = $80
TankOccupancyRightFlag = $40
TankHalfExtentPixels    = $08
TileAlignmentMask       = $07
ShadowPageIndexMask     = $03
NametableShadowBasePage = $04
ShadowRowStride         = $20
TileOccupiedFlag        = $80
TileUnoccupiedMask      = $7F

; Перед движением помечает в nametable shadow клетки активных танков 7..0.
; PixelCoordinatesToShadowPointer возвращает адрес для точки
; (ObjectX-8,ObjectY-8); адрес и признаки дополнительных клеток кэшируются в
; TankShadowPtrLo/TankShadowPtrHiAndFlags. Bit7 тайла служит occupancy-маркером.
; Для игрока также обновляет PlayerIceState по тайлу PlayerIceTile.
; Портит A/X/Y/ScratchPtr, TerrainSubcellMask и OccupancyTankSlot.
MarkTankOccupiedTiles:
LE181:  lda     #(TankSlotCount-1)
        sta     OccupancyTankSlot
MarkNextTankOccupiedTiles:
LE185:  ldx     OccupancyTankSlot
        lda     ObjectState,x
        bpl     AdvanceTankOccupancySlot
        cmp     #NonTargetableTankStateMin
        bcs     AdvanceTankOccupancySlot
        lda     ObjectY,x
        sec
        sbc     #TankHalfExtentPixels
        tay
        lda     ObjectX,x
        sec
        sbc     #TankHalfExtentPixels
        tax
        jsr     PixelCoordinatesToShadowPointer
        ldx     OccupancyTankSlot
        lda     ScratchPtrLo
        sta     TankShadowPtrLo,x
        lda     ScratchPtrHi
        and     #ShadowPageIndexMask
        sta     TankShadowPtrHiAndFlags,x
        ldy     #TankCenterShadowOffset
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
        and     #TileAlignmentMask
        bne     CheckTankVerticalAlignment
        lda     TankShadowPtrHiAndFlags,x
        ora     #TankOccupancyBelowFlag
        sta     TankShadowPtrHiAndFlags,x
        ldy     #ShadowRowStride
        jsr     SetTileOccupiedFlag
CheckTankVerticalAlignment:
LE1DD:  lda     ObjectY,x
        and     #TileAlignmentMask
        bne     AdvanceTankOccupancySlot
        lda     TankShadowPtrHiAndFlags,x
        ora     #TankOccupancyRightFlag
        sta     TankShadowPtrHiAndFlags,x
        ldy     #$01
        jsr     SetTileOccupiedFlag
AdvanceTankOccupancySlot:
LE1EE:  dec     OccupancyTankSlot
        bpl     MarkNextTankOccupiedTiles
        rts

; Вход: ScratchPtr+Y — байт nametable shadow. Ставит bit7; портит A и флаги.
SetTileOccupiedFlag:
LE1F3:  lda     (ScratchPtrLo),y
        ora     #TileOccupiedFlag
        sta     (ScratchPtrLo),y
        rts

; После движения снимает occupancy-bit7 с тех же клеток по кэшу. Обходит
; активные танки 7..0. Портит A/X/Y/ScratchPtr/OccupancyTankSlot и shadow.
ClearTankOccupiedTiles:
LE1FA:  lda     #(TankSlotCount-1)
        sta     OccupancyTankSlot
ClearNextTankOccupiedTiles:
LE1FE:  ldx     OccupancyTankSlot
        lda     ObjectState,x
        bpl     AdvanceClearOccupancySlot
        cmp     #NonTargetableTankStateMin
        bcs     AdvanceClearOccupancySlot
        lda     TankShadowPtrLo,x
        sta     ScratchPtrLo
        lda     TankShadowPtrHiAndFlags,x
        and     #ShadowPageIndexMask
        ora     #NametableShadowBasePage
        sta     ScratchPtrHi
        ldy     #TankCenterShadowOffset
        jsr     ClearTileOccupiedFlag
        lda     TankShadowPtrHiAndFlags,x
        and     #TankOccupancyBelowFlag
        beq     ClearTankVerticalOccupancy
        ldy     #ShadowRowStride
        jsr     ClearTileOccupiedFlag
ClearTankVerticalOccupancy:
LE224:  lda     TankShadowPtrHiAndFlags,x
        and     #TankOccupancyRightFlag
        beq     AdvanceClearOccupancySlot
        ldy     #$01
        jsr     ClearTileOccupiedFlag
AdvanceClearOccupancySlot:
LE22F:  dec     OccupancyTankSlot
        bpl     ClearNextTankOccupiedTiles
        rts

; Вход: ScratchPtr+Y — байт nametable shadow. Снимает bit7; портит A и флаги.
ClearTileOccupiedFlag:
LE234:  lda     (ScratchPtrLo),y
        and     #TileUnoccupiedMask
        sta     (ScratchPtrLo),y
        rts
