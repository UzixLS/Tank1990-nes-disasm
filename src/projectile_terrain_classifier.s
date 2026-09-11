; Variant-классификация местности для снаряда ($EA12-$EA38).

TerrainClearingUpgradeMin = $A0

; Классифицирует tile, прочитанный ProbeProjectileTerrainAtPixel.
; Вход: A=tile, TerrainProjectileSlot=projectile slot;
; ScratchPtr/Y и TerrainSubcellMask указывают подобласть.
; Для player slots 0,1,8,9 и PlayerExtendedUpgrade,owner не ниже
; TerrainClearingUpgradeMin tile $22 может быть
; полностью очищен без остановки снаряда. Tile >=$12 в остальных случаях
; пропускает снаряд; tile <$12 передаётся DestroyProjectileOnTerrain.
; Выход и побочные эффекты совпадают с ResolveProjectileTerrainHit.
ClassifyTerrainForProjectile:
LEA12:  pha
        lda     TerrainProjectileSlot
        and     #$06
        bne     RestoreTerrainTileForClassification
        lda     TerrainProjectileSlot
        and     #$01
        tax
        lda     PlayerExtendedUpgrade,x
        cmp     #TerrainClearingUpgradeMin
        bcc     RestoreTerrainTileForClassification
        nop
        pla
        cmp     #$22
        bne     ClassifyTerrainTileRange
        jmp     DestroyWholeTerrainTile

RestoreTerrainTileForClassification:
LEA2E:  pla
ClassifyTerrainTileRange:
LEA2F:  cmp     #$12
        bcc     DispatchDestructibleTerrainHit
        jmp     FinishTerrainProbeWithoutPartialDamage

DispatchDestructibleTerrainHit:
LEA36:  jmp     DestroyProjectileOnTerrain
