; Столкновения снарядов с местностью ($E604-$E70B).

TerrainProjectileSlot = $5A
TerrainAxisXMagnitude = $54
TerrainAxisYMagnitude = $55
TerrainFarYOffset     = $64
TerrainFarXOffset     = $65

; Проверяет активные снаряды 9..0 против местности в теневой nametable.
; Активен state-class $40. Снаряды с нулевым ProjectileFlags проверяются
; через кадр по чётности slot^FrameCounter, остальные — каждый кадр.
; Для направления из младших двух битов ProjectileState вычисляются две
; передние стороны снаряда; каждая сторона может затронуть две соседние
; 4x4-подобласти местности. Это позволяет разрушать соответствующую часть кирпича.
; Побочно меняет A/X/Y, ScratchPtr, terrain scratch aliases,
; состояние базы BattleState, shadow/PPU-очередь, состояния снарядов и
; состояния соответствующих аудиопотоков уничтожения, удара и рикошета.
UpdateProjectileTerrainCollisions:
LE604:  lda     #(ProjectileSlotCount-1)
        sta     TerrainProjectileSlot
CheckNextProjectileTerrain:
LE608:  ldx     TerrainProjectileSlot
        lda     ProjectileState,x
        and     #StateClassMask
        cmp     #ProjectileStateActive
        bne     AdvanceTerrainProjectile
        lda     ProjectileFlags,x
        bne     PrepareProjectileTerrainOffsets
        txa
        eor     FrameCounter
        and     #$01
        beq     AdvanceTerrainProjectile
; TerrainAxisXMagnitude/TerrainAxisYMagnitude — |dx|/|dy|;
; TerrainFarYOffset/TerrainFarXOffset — поперечные смещения на 4 px
; для второй точки каждой передней стороны снаряда.
PrepareProjectileTerrainOffsets:
LE61D:  lda     ProjectileState,x
        and     #DirectionMask
        tay
        lda     ProjectileDirectionStepX,y
        bpl     StoreTerrainAxisXMagnitude
        eor     #$FF
        clc
        adc     #$01
StoreTerrainAxisXMagnitude:
LE62C:  sta     TerrainAxisXMagnitude
        asl     a
        asl     a
        sta     TerrainFarYOffset
        lda     ProjectileDirectionStepY,y
        bpl     StoreTerrainAxisYMagnitude
        eor     #$FF
        clc
        adc     #$01
StoreTerrainAxisYMagnitude:
LE63C:  sta     TerrainAxisYMagnitude
        asl     a
        asl     a
        sta     TerrainFarXOffset
        ldy     ProjectileY,x
        lda     ProjectileX,x
        tax
        jsr     ProbeProjectileTerrainAtPixel
        beq     ProbeOppositeProjectileEdge
        ldx     TerrainProjectileSlot
        lda     ProjectileY,x
        clc
        adc     TerrainFarYOffset
        sta     CollisionPointY
        lda     ProjectileX,x
        clc
        adc     TerrainFarXOffset
        sta     CollisionPointX
        jsr     ResolveProjectileTerrainHit
ProbeOppositeProjectileEdge:
LE65F:  ldx     TerrainProjectileSlot
        lda     ProjectileY,x
        sec
        sbc     TerrainAxisXMagnitude
        tay
        lda     ProjectileX,x
        sec
        sbc     TerrainAxisYMagnitude
        tax
        jsr     ProbeProjectileTerrainAtPixel
        beq     AdvanceTerrainProjectile
        ldx     TerrainProjectileSlot
        lda     ProjectileY,x
        sec
        sbc     TerrainFarYOffset
        sec
        sbc     TerrainAxisXMagnitude
        sta     CollisionPointY
        lda     ProjectileX,x
        sec
        sbc     TerrainFarXOffset
        sec
        sbc     TerrainAxisYMagnitude
        sta     CollisionPointX
        jsr     ResolveProjectileTerrainHit
AdvanceTerrainProjectile:
LE68B:  dec     TerrainProjectileSlot
        bmi     FinishProjectileTerrainCollisions
        jmp     CheckNextProjectileTerrain

FinishProjectileTerrainCollisions:
LE692:  rts

; Проверяет terrain в пиксельной точке X/Y.
; Сохраняет координаты в CollisionPointX/Y, вычисляет ScratchPtr и маску подобласти,
; затем проваливается в ResolveProjectileTerrainHit.
; Возвращает A=1 только при частичном разрушении обычного terrain; A=0 для
; отсутствия столкновения, целого уничтожения тайла, стали/границы и базы.
ProbeProjectileTerrainAtPixel:
LE693:  stx     CollisionPointX
        sty     CollisionPointY
        jsr     PixelCoordinatesToShadowPointer
ResolveProjectileTerrainHit:
LE69A:  jsr     RecomputeTerrainSubcellMask
        jsr     TestTerrainSubcell
        beq     FinishTerrainProbeWithoutPartialDamage
        lda     (ScratchPtrLo),y
        and     #$FC
        cmp     #$C8
        bne     ClassifyProjectileTerrainTile
        ; $C8-$CB — четыре тайла целой базы.
        lda     BattleState
        beq     ClassifyProjectileTerrainTile
        lda     #$27
        sta     BattleState
        lda     #AudioStateStartRequested
        sta     BaseDestructionToneAudioState
        sta     PlayerOrBaseDestructionNoiseAudioState
        jsr     DrawDestroyedBase
        ldx     TerrainProjectileSlot
        lda     #ProjectileStateImpact
        sta     ProjectileState,x
        jmp     FinishTerrainProbeWithoutPartialDamage

ClassifyProjectileTerrainTile:
LE6C6:  lda     (ScratchPtrLo),y
        jmp     ClassifyTerrainForProjectile

; Недостижимый NOP между безусловным JMP и следующим обработчиком.
UnreferencedE6cbNop:
LE6CB:  .byte   $EA
; Общий путь попадания в непроходимый terrain: переводит снаряд в state $33.
; $11 — неразрушаемая граница; $10 — сталь, которую разрушает только флаг $02.
; Остальные значения < $12 теряют выбранный бит 4x4-подобласти.
DestroyProjectileOnTerrain:
LE6CC:  ldx     TerrainProjectileSlot
        lda     #ProjectileStateImpact
        sta     ProjectileState,x
        lda     (ScratchPtrLo),y
        cmp     #$11
        beq     MaybePlayProjectileRicochet
        lda     ProjectileFlags,x
        and     #$02
        beq     DamageProjectileTerrain
; Очищает весь байт terrain и запрашивает BrickHitAudioState. Сам ProjectileState не
; меняет: обычный усиленный выстрел приходит сюда уже со state $33, а особый
; путь tile $22 входит напрямую и потому сохраняет летящий снаряд.
DestroyWholeTerrainTile:
LE6DE:  lda     #$00
        jsr     StoreAndQueueShadowTile
        lda     #AudioStateStartRequested
        sta     BrickHitAudioState
        jmp     FinishTerrainProbeWithoutPartialDamage

DamageProjectileTerrain:
LE6EB:  lda     (ScratchPtrLo),y
        cmp     #$10
        beq     MaybePlayProjectileRicochet
        cpx     #FirstEnemyTankSlot
        bcs     DestroyTerrainSubcell
        lda     #AudioStateStartRequested
        sta     BrickHitAudioState
DestroyTerrainSubcell:
LE6FA:  jsr     ClearTerrainSubcellQueued
        lda     #$01
        rts

MaybePlayProjectileRicochet:
LE700:  cpx     #FirstEnemyTankSlot
        bcs     FinishTerrainProbeWithoutPartialDamage
        lda     #AudioStateStartRequested
        sta     RicochetOrMenuStepAudioState
FinishTerrainProbeWithoutPartialDamage:
LE709:  lda     #$00
        rts
