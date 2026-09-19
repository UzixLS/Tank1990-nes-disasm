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
; Вход: состояния/координаты снарядов и playfield shadow.
; Выход: TerrainProjectileSlot=$FF; A/X/Y не определены.
; Портит ScratchPtr, CollisionPointX/Y, TerrainSubcellMask и локальные
; terrain scratch aliases; также может менять
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
        beq     ProbeSecondProjectileEdge
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
ProbeSecondProjectileEdge:
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
; Возвращает A=1 после очистки выбранной 4x4-подобласти обычного terrain
; (она может оказаться последним установленным битом); A=0 для отсутствия
; столкновения, пути полного уничтожения тайла, стали/границы и базы.
; Вход: X/Y — пиксельные координаты. Выход: Z отражает A; X/Y не определены.
; Побочные эффекты совпадают с ResolveProjectileTerrainHit.
ProbeProjectileTerrainAtPixel:
LE693:  stx     CollisionPointX
        sty     CollisionPointY
        jsr     PixelCoordinatesToShadowPointer
ResolveProjectileTerrainHit:
; Альтернативный вход после вычисления ScratchPtr и CollisionPointX/Y.
; Предусловия: ScratchPtr/Y указывают shadow tile, CollisionPointX/Y содержат
; исходный пиксель, TerrainProjectileSlot — текущий снаряд.
; Выход: A=1 после ClearTerrainSubcellQueued, иначе A=0; Z соответствует A.
; Может изменить ProjectileState, BattleState, terrain shadow,
; PPU update buffer и audio states; PPU-регистры и OAM напрямую не трогает.
LE69A:  jsr     RecomputeTerrainSubcellMask
        jsr     TestTerrainSubcell
        beq     FinishTerrainProbeWithoutPartialDamage
        lda     (ScratchPtrLo),y
        and     #TerrainTileClassMask
        cmp     #TerrainTileIntactBaseClass
        bne     ClassifyProjectileTerrainTile
        ; $C8-$CB — четыре тайла целой базы. При BattleState!=0 попадание
        ; запускает countdown разрушения с $27, оба звуковых потока, немедленную
        ; замену центра базы и impact-state снаряда. Выход этого пути: A=0/Z=1.
        ; При BattleState=0 та же графика классифицируется как обычный terrain.
        lda     BattleState
        beq     ClassifyProjectileTerrainTile
        lda     #BattleStateBaseDestructionStart
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
; Вход: TerrainProjectileSlot, ScratchPtr/Y и TerrainSubcellMask подготовлены;
; X может быть произвольным. Выход: A=0 или 1 по контракту resolve, X получает
; TerrainProjectileSlot. Меняет ProjectileState и при разрушении shadow/PPU/audio.
DestroyProjectileOnTerrain:
LE6CC:  ldx     TerrainProjectileSlot
        lda     #ProjectileStateImpact
        sta     ProjectileState,x
        lda     (ScratchPtrLo),y
        cmp     #TerrainTileBoundary
        beq     MaybePlayProjectileRicochet
        lda     ProjectileFlags,x
        and     #ProjectileFlagBreakSteel
        beq     DamageProjectileTerrain
; Очищает весь байт terrain и запрашивает BrickHitAudioState. Сам ProjectileState не
; меняет: обычный усиленный выстрел приходит сюда уже со state $33, а особый
; путь tile $22 входит напрямую и потому сохраняет летящий снаряд.
; Вход: ScratchPtr/Y указывают tile. Выход: A=0, X/Y сохраняются относительно
; StoreAndQueueShadowTile; меняет shadow, PPU update buffer и BrickHitAudioState.
DestroyWholeTerrainTile:
LE6DE:  lda     #$00
        jsr     StoreAndQueueShadowTile
        lda     #AudioStateStartRequested
        sta     BrickHitAudioState
        jmp     FinishTerrainProbeWithoutPartialDamage

DamageProjectileTerrain:
LE6EB:  lda     (ScratchPtrLo),y
        cmp     #TerrainTileSteel
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
