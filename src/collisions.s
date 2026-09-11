; Столкновения снарядов с местностью/танками, бонусы и диспетчеризация ($E604-$EA50).

; Локальные роли перегруженной scratch-RAM. Адреса совпадают
; намеренно: роль меняется между несвязанными проходами.
TerrainProjectileSlot       = $5A
TerrainAxisXMagnitude      = $54
TerrainAxisYMagnitude      = $55
TerrainFarYOffset          = $64
TerrainFarXOffset          = $65
TankCollisionSlot          = $5A
ProjectileCollisionSlot    = $5B
ProjectileOwnerParity      = $47
ProjectilePairOuterSlot    = $5A
ProjectilePairInnerSlot    = $5B
ProjectilePairOwnerIndex   = $00
PowerUpCoordinateGridIndex = $00

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

; Общий проход снарядов по танкам.
; Фаза 1 проверяет игроков Object 1..0 против активных вражеских снарядов 7..2.
; Попадание определяется квадратом |dx|<10, |dy|<10. Таймер $89,X поглощает
; снаряд без взрыва; иначе управление передаётся HandleProjectileHitOnPlayer.
; AdvancePlayerTankCollisionPass из high-bank возвращает сюда для следующего игрока.
; Фаза 2 проверяет врагов Object 7..2 против логических снарядов игроков
; в слотах 0,1,8,9, начисляет уничтожения и очки.
; Побочно меняет A/X/Y, TankCollisionSlot,
; ProjectileCollisionSlot/ProjectileOwnerParity, ProjectileState, состояния/атрибуты
; танков, статистику $73-$7A, записи счёта и звуковые/bonus-флаги. Условное
; создание бонуса также меняет RNG, PowerUpSpawnAudioState,
; PowerUpCollectorSlot и поля бонуса.
UpdateProjectileTankCollisions:
LE70C:  lda     #$01
        sta     TankCollisionSlot
CheckNextPlayerTank:
LE710:
        ldx     TankCollisionSlot
        lda     ObjectState,x
        bpl     SkipCurrentPlayerCollisionPass
        cmp     #NonTargetableTankStateMin
        bcc     CheckEnemyProjectilesAgainstPlayer
SkipCurrentPlayerCollisionPass:
LE71A:  jmp     AdvancePlayerCollisionPassOrBeginEnemyPass

CheckEnemyProjectilesAgainstPlayer:
LE71D:  lda     #(TankSlotCount-1)
        sta     ProjectileCollisionSlot
CheckNextEnemyProjectile:
LE721:  ldy     ProjectileCollisionSlot
        lda     ProjectileState,y
        and     #StateClassMask
        cmp     #ProjectileStateActive
        bne     AdvanceEnemyProjectileCollision
        lda     ProjectileX,y
        sec
        sbc     ObjectX,x
        bpl     PlayerHitXDistanceReady
        eor     #$FF
        clc
        adc     #$01
PlayerHitXDistanceReady:
LE739:  cmp     #$0A
        bcs     AdvanceEnemyProjectileCollision
        lda     ProjectileY,y
        sec
        sbc     ObjectY,x
        bpl     PlayerHitYDistanceReady
        eor     #$FF
        clc
        adc     #$01
PlayerHitYDistanceReady:
LE74A:  cmp     #$0A
        bcs     AdvanceEnemyProjectileCollision
        lda     #ProjectileStateImpact
        sta     ProjectileState,y
        lda     PlayerShieldTimer,x
        beq     HandleUnshieldedPlayerHit
        lda     #$00
        sta     ProjectileState,y
        jmp     AdvanceEnemyProjectileCollision

HandleUnshieldedPlayerHit:
LE75F:  jmp     HandleProjectileHitOnPlayer

; Недостижимый NOP после безусловного JMP.
UnreferencedE762Nop:
LE762:  .byte   $EA
; Хвост реакции игрока на попадание: получает variant bits,
; зеркалит их в $0178/$0101/ObjectAttributes и продолжает общий проход.
ApplyPlayerHitVariantState:
LE763:
        jsr     RequestPlayerDestructionAudioAndGetVariantBits
        nop
        sta     PlayerExtendedUpgrade,x
        sta     PlayerUpgradeLevel,x
        sta     ObjectAttributes,x
        jmp     AdvancePlayerCollisionPassOrBeginEnemyPass

AdvanceEnemyProjectileCollision:
LE772:  dec     ProjectileCollisionSlot
        lda     ProjectileCollisionSlot
        cmp     #$01
        bne     CheckNextEnemyProjectile
; JSR вызывает проход игроков повторно через внутренний JMP из
; AdvancePlayerTankCollisionPass. Первый
; переход сохраняет адрес возврата на стеке, второй вызов при $5A<0 возвращается
; сюда и запускает проход врагов. Его RTS разматывает сохранённый адрес и тем же
; способом запускает проход врагов второй раз, после чего следующий RTS выходит
; к исходному вызывающему. Это намеренная стековая схема, а не обычный цикл.
AdvancePlayerCollisionPassOrBeginEnemyPass:
LE77A:  jsr     AdvancePlayerTankCollisionPass
        nop
        lda     #(TankSlotCount-1)
        sta     TankCollisionSlot
CheckNextEnemyTank:
LE782:  ldx     TankCollisionSlot
        lda     ObjectState,x
        bpl     SkipCurrentEnemyCollisionPass
        cmp     #NonTargetableTankStateMin
        bcc     CheckPlayerProjectilesAgainstEnemy
SkipCurrentEnemyCollisionPass:
LE78C:  jmp     AdvanceEnemyTankCollision

CheckPlayerProjectilesAgainstEnemy:
LE78F:  lda     #(ProjectileSlotCount-1)
        sta     ProjectileCollisionSlot
CheckNextPlayerProjectile:
LE793:  lda     ProjectileCollisionSlot
        and     #$06
        beq     TestPlayerProjectileAgainstEnemy
        ; Только слоты 0,1,8,9 принадлежат логическим выстрелам игроков.
        jmp     AdvancePlayerProjectileCollision

TestPlayerProjectileAgainstEnemy:
LE79C:  ldy     ProjectileCollisionSlot
        lda     ProjectileState,y
        and     #StateClassMask
        cmp     #ProjectileStateActive
        beq     MeasurePlayerProjectileTankDistance
        jmp     AdvancePlayerProjectileCollision

MeasurePlayerProjectileTankDistance:
LE7AA:  lda     ProjectileX,y
        sec
        sbc     ObjectX,x
        bpl     EnemyHitXDistanceReady
        eor     #$FF
        clc
        adc     #$01
EnemyHitXDistanceReady:
LE7B7:  cmp     #$0A
        bcs     AdvancePlayerProjectileCollision
        lda     ProjectileY,y
        sec
        sbc     ObjectY,x
        bpl     EnemyHitYDistanceReady
        eor     #$FF
        clc
        adc     #$01
EnemyHitYDistanceReady:
LE7C8:  cmp     #$0A
        bcs     AdvancePlayerProjectileCollision
        lda     #ProjectileStateImpact
        sta     ProjectileState,y
        lda     ObjectAttributes,x
        and     #$04
        beq     DamageOrDestroyEnemyTank
        jsr     SpawnPowerUp
        lda     ObjectAttributes,x
        cmp     #$E4
        bne     DamageOrDestroyEnemyTank
        dec     ObjectAttributes,x
; Низкие два бита атрибутов работают как дополнительные hit points.
DamageOrDestroyEnemyTank:
LE7E2:  lda     ObjectAttributes,x
        and     #$03
        beq     DestroyEnemyTankAndAwardScore
        dec     ObjectAttributes,x
        lda     #AudioStateStartRequested
        sta     ArmorHitAudioState
        jmp     AdvancePlayerProjectileCollision

; Полное уничтожение: state $73, запрос TankDestructionAudioState,
; статистика типа/владельца
; и, кроме специального режима $8F=2, награда 100..400 очков.
DestroyEnemyTankAndAwardScore:
LE7F2:  jsr     DestroyTankAndClearExtension
        nop
        lda     #AudioStateStartRequested
        sta     TankDestructionAudioState
        lda     ObjectAttributes,x
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        sec
        sbc     #$04
        tax
        lda     ProjectileCollisionSlot
        and     #$01
        sta     ProjectileOwnerParity
        bne     CreditPlayer2Kill
        inc     Player1KillCounts,x
        jmp     MaybeAwardEnemyScore

CreditPlayer2Kill:
LE813:  inc     Player2KillCounts,x
MaybeAwardEnemyScore:
LE815:  lda     StageSetLength
        cmp     #$02
        beq     AdvanceEnemyTankCollision
        lda     EnemyTypeScoreAwards,x
        jsr     PreparePackedScoreIncrement
        lda     ProjectileOwnerParity
        tax
        jsr     AddScoreDigitsToRecord
        jsr     AwardScoreThresholdLives
        jmp     AdvanceEnemyTankCollision

AdvancePlayerProjectileCollision:
LE82D:  dec     ProjectileCollisionSlot
        bmi     AdvanceEnemyTankCollision
        jmp     CheckNextPlayerProjectile

AdvanceEnemyTankCollision:
LE834:  dec     TankCollisionSlot
        lda     TankCollisionSlot
        cmp     #$01
        beq     FinishProjectileTankCollisions
        jmp     CheckNextEnemyTank

FinishProjectileTankCollisions:
LE83F:  rts

.include "variant_menu_data.s"

; Упакованные десятичные награды за типы врагов; фактически 100..400 очков.
EnemyTypeScoreAwards:
LE8BA:  .byte   $10,$20,$30,$40

.include "powerup_spawn.s"

; Проверяет столкновения активных снарядов друг с другом.
; Внешний цикл рассматривает только логические player slots 0,1,8,9;
; внутренний — все 10 слотов. Пары с одинаковым индексом modulo 8 исключаются,
; поэтому основные и дополнительные слоты одного владельца не гасят друг друга.
; При |dx|<6 и |dy|<6 оба ProjectileState обнуляются без взрывного state $33.
; Побочно меняет A/X/Y, ProjectilePairOuterSlot/
; ProjectilePairInnerSlot/ProjectilePairOwnerIndex и ProjectileState; прочую RAM не меняет.
UpdateProjectileProjectileCollisions:
LE910:  lda     #(ProjectileSlotCount-1)
        sta     ProjectilePairOuterSlot
CheckNextProjectilePairOuter:
LE914:  lda     ProjectilePairOuterSlot
        and     #$06
        bne     AdvanceProjectilePairOuter
        ldx     ProjectilePairOuterSlot
        lda     ProjectileState,x
        and     #StateClassMask
        cmp     #ProjectileStateActive
        bne     AdvanceProjectilePairOuter
        lda     #(ProjectileSlotCount-1)
        sta     ProjectilePairInnerSlot
CheckNextProjectilePairInner:
LE928:  lda     ProjectilePairInnerSlot
        tay
        and     #$07
        sta     ProjectilePairOwnerIndex
        lda     ProjectilePairOuterSlot
        and     #$07
        cmp     ProjectilePairOwnerIndex
        beq     AdvanceProjectilePairInner
        lda     ProjectileState,y
        and     #StateClassMask
        cmp     #ProjectileStateActive
        bne     AdvanceProjectilePairInner
        lda     ProjectileX,y
        sec
        sbc     ProjectileX,x
        bpl     ProjectilePairXDistanceReady
        eor     #$FF
        clc
        adc     #$01
ProjectilePairXDistanceReady:
LE94D:  cmp     #$06
        bcs     AdvanceProjectilePairInner
        lda     ProjectileY,y
        sec
        sbc     ProjectileY,x
        bpl     ProjectilePairYDistanceReady
        eor     #$FF
        clc
        adc     #$01
ProjectilePairYDistanceReady:
LE95E:  cmp     #$06
        bcs     AdvanceProjectilePairInner
        lda     #$00
        sta     ProjectileState,x
        sta     ProjectileState,y
AdvanceProjectilePairInner:
LE969:  dec     ProjectilePairInnerSlot
        bpl     CheckNextProjectilePairInner
AdvanceProjectilePairOuter:
LE96D:  dec     ProjectilePairOuterSlot
        bpl     CheckNextProjectilePairOuter
        rts

.include "powerup_pickup.s"
.include "stage_selection_helpers.s"
UnreferencedMaximumUpgradeTrampoline:
LEA0F:
        jmp     SetMaximumObjectUpgrade

; Классифицирует tile, прочитанный ProbeProjectileTerrainAtPixel.
; Вход: A=tile, TerrainProjectileSlot=projectile slot;
; ScratchPtr/Y и TerrainSubcellMask указывают подобласть.
; Для player slots 0,1,8,9 и улучшения $0178,owner >= $A0 tile $22 может быть
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
        cmp     #$A0
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

; Неиспользуемый напрямую адаптер: очищает $0178,X, загружает $0101,X
; и передаёт управление MergeTankAttributeBits.
; Меняет A, ObjectAttributes/ObjectFrame и $0178,X; X/Y сохраняются.
ClearUpgradeExtensionAndRefreshAttributes:
LEA39:  lda     #$00
        sta     PlayerExtendedUpgrade,x
        lda     PlayerUpgradeLevel,x
        jmp     MergeTankAttributeBits

; Сохранённый недостижимый байт после хвостового JMP MergeTankAttributeBits;
; следующий адрес $EA45 является самостоятельным entry point. Ссылок нет.
UnreferencedEa44Byte:
LEA44:  .byte   $03
; Небольшой адаптер без статических ссылок: пишет A в состояние второго
; pulse-потока звука дополнительной жизни.
; RAM кроме ExtraLifePulse2AudioState и регистры X/Y не меняет.
StoreEventFlag0305:
LEA45:  sta     ExtraLifePulse2AudioState
        rts
; Знаковые единичные векторы для направлений Up,Left,Down,Right.
ProjectileDirectionStepX:
LEA49:  .byte   $00,$FF,$00,$01
ProjectileDirectionStepY:
LEA4D:  .byte   $FF,$00,$01,$00
