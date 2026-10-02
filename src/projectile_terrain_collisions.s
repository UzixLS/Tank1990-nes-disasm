; Столкновения снарядов с местностью ($E604-$E70B).

TerrainProjectileSlot = $5A
TerrainAxisXMagnitude = $54
TerrainAxisYMagnitude = $55
TerrainFarYOffset     = $64
TerrainFarXOffset     = $65

; Проверяет активные снаряды 9..0 против местности в теневой nametable.
; Активен state-class $40. Снаряды с нулевым ProjectileFlags проверяются
; только при (slot xor FrameCounter)&1=1, остальные — каждый кадр. Знак вектора
; направления отбрасывается, поэтому Up/Down имеют одну геометрию проб, а
; Left/Right — другую. Для вертикального снаряда проверяются точки (x,y),
; условно (x+4,y), затем (x-1,y), условно (x-5,y); для горизонтального —
; (x,y), условно (x,y+4), затем (x,y-1), условно (x,y-5). Дальняя точка
; проверяется только когда ближняя вернула A=1, то есть действительно сняла
; один low-nibble bit частично разрушаемого terrain.
;
; Все прибавления/вычитания координат 8-битные и заворачиваются через $00/$FF.
; PixelCoordinatesToShadowPointer не ограничивает Y: значения 240..255 попадают
; в attribute bytes $07C0..$07FF. Штатная геометрия и boundary tiles удерживают
; снаряды в допустимой области; romhack обязан сохранить это ограничение либо
; добавить clipping. После первого попадания state может стать $33, но текущий
; проход не перепроверяет его и всё равно заканчивает оставшиеся точки.
; Вход: состояния/координаты снарядов и playfield shadow.
; Выход: TerrainProjectileSlot=$FF, N=1, Z=0; A/X/Y не определены.
; Портит ScratchPtr, CollisionPointX/Y, TerrainSubcellMask и локальные
; terrain scratch aliases. StoreAndQueueShadowTile использует тот же $47, что
; CollisionPointX, как ShadowQueueSavedX, поэтому координата действительна лишь
; до queued write. Каждый partial/whole-tile update добавляет 4 bytes в PPU
; queue, DrawDestroyedBase — 10; за один снаряд возможно до четырёх probes,
; общей проверки ёмкости нет. OAM и PPU registers напрямую не меняются.
; Также может менять BattleState, ProjectileState и audio states уничтожения
; базы, кирпича и рикошета. В штатном tick эта фаза предшествует pair/tank
; collisions, и переведённый в $33 снаряд ими уже не рассматривается.
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
; TerrainAxisXMagnitude/TerrainAxisYMagnitude — |dx|/|dy|, то есть 0/1;
; TerrainFarYOffset=4*|dx| и TerrainFarXOffset=4*|dy| задают поперечное
; смещение дальней точки. Направление движения влияет только на выбор оси.
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
; Предусловия: ScratchPtr указывает shadow tile, Y=0, CollisionPointX/Y содержат
; исходный пиксель, TerrainProjectileSlot — текущий снаряд. Y=0 существенен для
; queued terrain writes: StoreAndQueueShadowTile не прибавляет Y к PPU address.
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
        ; Маска $FC распознаёт $C8-$CB — четыре тайла целой базы. При
        ; BattleState!=0 первое такое попадание записывает countdown $27,
        ; запрашивает tone+noise, добавляет 10 bytes изображения разрушенного
        ; центра базы в PPU queue+shadow и ставит снаряду impact-state. После
        ; этого четыре tiles уже имеют классы $CC-$CF, поэтому следующие probes
        ; не перезапускают countdown. Стены/attributes базы здесь не меняются.
        ; Выход: A=0/Z=1, поэтому дальняя точка этой половины не проверяется,
        ; но вторая ближняя точка всё ещё будет проверена.
        ; При BattleState=0 $C8-$CB уходят в общий classifier и как >=$12
        ; пропускают снаряд без изменения.
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
; Очищает весь байт terrain, добавляет одну 4-byte PPU-команду и запрашивает
; BrickHitAudioState для любого владельца. Сам ProjectileState не меняет:
; обычный ProjectileFlagBreakSteel-путь приходит сюда уже со state $33, а
; особый player-only путь tile $22 из classifier входит напрямую и потому
; сохраняет летящий снаряд. Этот особый путь доступен logical player slots
; 0/1/8/9 при PlayerExtendedUpgrade[slot&1]>=$A0. BreakSteel очищает целиком
; также кирпичный byte вместо одного subcell; boundary $11 проверен раньше и
; сюда не попадает.
; Вход: ScratchPtr указывает tile, Y=0. Выход: A=0, X/Y сохраняются относительно
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
        ; Только основные player projectile slots 0/1 получают brick-hit sound.
        ; Дополнительные player slots 8/9 classifier считает игроками, но это
        ; сравнение по диапазону считает их «вражескими» и оставляет звук выключенным.
        lda     #AudioStateStartRequested
        sta     BrickHitAudioState
DestroyTerrainSubcell:
LE6FA:  jsr     ClearTerrainSubcellQueued
        lda     #$01
        rts

MaybePlayProjectileRicochet:
LE700:  cpx     #FirstEnemyTankSlot
        bcs     FinishTerrainProbeWithoutPartialDamage
        ; Та же асимметрия slots: boundary/steel дают ricochet только 0/1,
        ; но не дополнительным player projectiles 8/9 и не enemies 2..7.
        lda     #AudioStateStartRequested
        sta     RicochetOrMenuStepAudioState
FinishTerrainProbeWithoutPartialDamage:
LE709:  lda     #$00
        rts
