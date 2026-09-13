; Variant-классификация местности для снаряда ($EA12-$EA38).

TerrainClearingUpgradeMin = $A0
ClearableSpecialTerrainTile = $22
ProjectileBlockingTileLimit = $12

; Классифицирует tile, прочитанный ProbeProjectileTerrainAtPixel.
; Вход: A=tile, TerrainProjectileSlot=projectile slot;
; ScratchPtr/Y и TerrainSubcellMask указывают подобласть.
; Для player slots 0,1,8,9 и PlayerExtendedUpgrade,owner не ниже
; TerrainClearingUpgradeMin tile ClearableSpecialTerrainTile может быть
; полностью очищен без остановки снаряда. Tile не ниже
; ProjectileBlockingTileLimit в остальных случаях пропускает снаряд;
; меньший tile передаётся DestroyProjectileOnTerrain.
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
        cmp     #ClearableSpecialTerrainTile
        bne     ClassifyTerrainTileRange
        jmp     DestroyWholeTerrainTile

RestoreTerrainTileForClassification:
LEA2E:  pla
ClassifyTerrainTileRange:
LEA2F:  cmp     #ProjectileBlockingTileLimit
        bcc     DispatchDestructibleTerrainHit
        jmp     FinishTerrainProbeWithoutPartialDamage

DispatchDestructibleTerrainHit:
LEA36:  jmp     DestroyProjectileOnTerrain
