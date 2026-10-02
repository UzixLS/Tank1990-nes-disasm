; Variant-классификация местности для снаряда ($EA12-$EA38).

TerrainClearingUpgradeMin = $A0
ClearableSpecialTerrainTile = $22
ProjectileBlockingTileLimit = $12
ProjectileOwnerIndexMask = $01

; Классифицирует tile, прочитанный ProbeProjectileTerrainAtPixel.
; Вход: A=tile, TerrainProjectileSlot=projectile slot;
; ScratchPtr указывает terrain shadow byte, Y=0 и TerrainSubcellMask содержит
; выбранный one-hot subcell. Это continuation resolve-path, а не безопасный
; самостоятельный API: TestTerrainSubcell уже подтвердил занятость точки.
; Для player slots 0,1,8,9 и PlayerExtendedUpgrade,owner не ниже
; TerrainClearingUpgradeMin tile ClearableSpecialTerrainTile может быть
; полностью очищен одной 4-byte PPU-командой с brick-hit audio, но без остановки
; снаряда. Owner определяется slot&1. Tile не ниже
; ProjectileBlockingTileLimit в остальных случаях пропускает снаряд;
; меньший tile передаётся DestroyProjectileOnTerrain: boundary/steel/обычный
; terrain обрабатываются там с whole-vs-subcell правилами и state $33.
;
; PHA всегда сбалансирован PLA до tail-JMP. На logical-player path X становится
; owner 0/1 даже если upgrade недостаточен или tile просто пропускается; на
; enemy pass-through X сохраняет входное значение, а blocking path позднее
; загружает projectile slot. Выход A/Z и side effects совпадают с
; ResolveProjectileTerrainHit: A=1 только после partial clear, иначе 0.
; Может менять projectile/shadow/PPU queue/audio state через tail targets;
; OAM и PPU registers напрямую не меняет. Slots вне 0..9 не поддерживаются.
ClassifyTerrainForProjectile:
LEA12:  pha
        lda     TerrainProjectileSlot
        and     #PlayerProjectileSlotMask
        bne     RestoreTerrainTileForClassification
        lda     TerrainProjectileSlot
        and     #ProjectileOwnerIndexMask
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
