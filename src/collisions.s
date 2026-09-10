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
        bne     LE61D
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
        bpl     LE62C
        eor     #$FF
        clc
        adc     #$01
LE62C:  sta     TerrainAxisXMagnitude
        asl     a
        asl     a
        sta     TerrainFarYOffset
        lda     ProjectileDirectionStepY,y
        bpl     LE63C
        eor     #$FF
        clc
        adc     #$01
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
        bmi     LE692
        jmp     CheckNextProjectileTerrain

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
; снаряд без взрыва; иначе управление передаётся HandleProjectileHitOnTank.
; AdvanceTankCollisionPass из high-bank возвращает сюда для следующего игрока.
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
        bpl     LE739
        eor     #$FF
        clc
        adc     #$01
LE739:  cmp     #$0A
        bcs     AdvanceEnemyProjectileCollision
        lda     ProjectileY,y
        sec
        sbc     ObjectY,x
        bpl     LE74A
        eor     #$FF
        clc
        adc     #$01
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
LE75F:  jmp     HandleProjectileHitOnTank

; Недостижимый NOP после безусловного JMP.
UnreferencedE762Nop:
LE762:  .byte   $EA
; Хвост реакции игрока на попадание: получает variant bits,
; зеркалит их в $0178/$0101/ObjectAttributes и продолжает общий проход.
ApplyPlayerHitVariantState:
LE763:
        jsr     GetVariantAttributeBits
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
; AdvanceTankCollisionPass. Первый
; переход сохраняет адрес возврата на стеке, второй вызов при $5A<0 возвращается
; сюда и запускает проход врагов. Его RTS разматывает сохранённый адрес и тем же
; способом запускает проход врагов второй раз, после чего следующий RTS выходит
; к исходному вызывающему. Это намеренная стековая схема, а не обычный цикл.
AdvancePlayerCollisionPassOrBeginEnemyPass:
LE77A:  jsr     AdvanceTankCollisionPass
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
        bpl     LE7B7
        eor     #$FF
        clc
        adc     #$01
LE7B7:  cmp     #$0A
        bcs     AdvancePlayerProjectileCollision
        lda     ProjectileY,y
        sec
        sbc     ObjectY,x
        bpl     LE7C8
        eor     #$FF
        clc
        adc     #$01
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

; Четырнадцать фиксированных восьмибайтных строк скрытого variant-меню.
; LC4F9 выбирает запись младшим байтом $40+index*8 при старшем $E8.
VariantMenuTankNames:
LE840:  .byte   $54,$41,$4E,$4B,$20,$20,$41,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$42,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$43,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$44,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$45,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$46,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$47,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$48,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$49,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$4A,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$4B,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$4C,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$4D,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$4E,$FF
; Дубликат строки-курсора из screens.s; статических ссылок на эту копию нет.
VariantMenuCursorText:
LE8B0:  .byte   $5D,$FF
; Строка с пробелом используется при стирании курсора variant-меню.
VariantMenuBlankCursorText:
LE8B2:  .byte   $20,$FF
; Шесть байтов заполнения между строкой стирания курсора и таблицей очков.
; Все равны $FF; статических ссылок внутрь диапазона $E8B4-$E8B9 нет.
UnreferencedE8b4Fill:
LE8B4:  .byte   $FF,$FF,$FF,$FF,$FF,$FF

; Упакованные десятичные награды за типы врагов; фактически 100..400 очков.
EnemyTypeScoreAwards:
LE8BA:  .byte   $10,$20,$30,$40

; Выбирает свободную позицию и тип появляющегося power-up.
; PowerUpX/Y получают одну из координат 48,96,144,192. Пока кандидат пересекается
; с активным танком, CheckPowerUpTankOverlap ставит PowerUpPickupDisplayTimer и
; генерация повторяется. Во время проверки PowerUpType=$FF служит sentinel
; «ещё не создано». После успешной
; позиции случайный индекс 0..7 проходит через SelectPowerUpTypeForVariant,
; результат сохраняется в PowerUpType, а таймер обнуляется.
; В конце восстанавливает X/Y из caller-owned TankCollisionSlot/
; ProjectileCollisionSlot; меняет A, RNG,
; PowerUpSpawnAudioState, PowerUpCollectorSlot и поля бонуса.
SpawnPowerUp:
LE8BE:  lda     #AudioStateStartRequested
        sta     PowerUpSpawnAudioState
ChoosePowerUpCoordinates:
LE8C3:  jsr     NextRandomByte
        and     #$03
        jsr     GridIndexToPowerUpCoordinate
        sta     PowerUpX
        jsr     NextRandomByte
        and     #$03
        jsr     GridIndexToPowerUpCoordinate
        sta     PowerUpY
        lda     #$FF
        sta     PowerUpType
        lda     #$00
        sta     PowerUpPickupDisplayTimer
        jsr     UpdatePowerUpPickup
        lda     PowerUpPickupDisplayTimer
        bne     ChoosePowerUpCoordinates
        jsr     NextRandomByte
        and     #$07
        tay
        jsr     SelectPowerUpTypeForVariant
        sta     PowerUpType
        lda     #$00
        sta     PowerUpPickupDisplayTimer
        ldx     TankCollisionSlot
        ldy     ProjectileCollisionSlot
        rts

; Полный вариант разрешает все восемь типов без преобразования.
AllPowerUpTypes:
LE8FA:  .byte   $00,$01,$02,$03,$04,$05,$06,$07

; Преобразует A=0..3 в координату (A*6+6)*8: 48,96,144,192.
; Выход A; меняет PowerUpCoordinateGridIndex и флаги, X/Y сохраняет.
GridIndexToPowerUpCoordinate:
LE902:  sta     PowerUpCoordinateGridIndex
        asl     a
        clc
        adc     PowerUpCoordinateGridIndex
        asl     a
        clc
        adc     #$06
        asl     a
        asl     a
        asl     a
        rts

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
        bpl     LE94D
        eor     #$FF
        clc
        adc     #$01
LE94D:  cmp     #$06
        bcs     AdvanceProjectilePairInner
        lda     ProjectileY,y
        sec
        sbc     ProjectileY,x
        bpl     LE95E
        eor     #$FF
        clc
        adc     #$01
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

; Проверяет power-up в (PowerUpX,PowerUpY) против активных танков.
; PowerUpX=0 означает отсутствие power-up; ненулевой PowerUpPickupDisplayTimer
; запрещает повторную проверку. Scan helper LE55B выбирает через
; PowerUpCollectorSlot слоты 1..0 при GameVariant<=7 или 7..0 при
; GameVariant>7, затем передаёт управление CheckPowerUpTankOverlap.
; Квадрат захвата: |dx|<12, |dy|<12.
; При PowerUpType=$FF процедура используется SpawnPowerUp только как проверка
; свободного места: ставит PowerUpPickupDisplayTimer=$32 и возвращается без
; эффекта. При PowerUpType=0..7 выполняет pickup:
; при $C6!=$06 добавляет 500 очков сборщику X<2 и ставит PowerUpPickupAudioState; для X>=2
; счёт не меняется. Значение $C6=$06 пропускает оба действия, но всё равно
; dispatch'ит выбранный эффект.
; Побочно меняет A/X/Y, PowerUpCollectorSlot, PowerUpPickupDisplayTimer,
; счёт/жизни и состояния аудиопотоков; обработчик эффекта
; может менять произвольное игровое состояние. При dispatch снимает со стека
; собственный адрес возврата. Поэтому RTS обработчика разматывает ещё один уровень
; стека и пропускает остаток процедуры, которая вызвала UpdatePowerUpPickup.
UpdatePowerUpPickup:
LE972:  lda     PowerUpX
        beq     FinishPowerUpPickupScan
        lda     PowerUpPickupDisplayTimer
        bne     FinishPowerUpPickupScan
        jmp     BeginPowerUpCollectorScan

; Недостижимый NOP между trampoline LE55B и циклом проверки.
UnreferencedE97dNop:
LE97D:  .byte   $EA
CheckPowerUpTankOverlap:
LE97E:  ldx     PowerUpCollectorSlot
        lda     ObjectState,x
        bpl     AdvancePowerUpCollectorScan
        cmp     #NonTargetableTankStateMin
        bcs     AdvancePowerUpCollectorScan
        lda     ObjectX,x
        sec
        sbc     PowerUpX
        bpl     LE994
        eor     #$FF
        clc
        adc     #$01
LE994:  cmp     #$0C
        bcs     AdvancePowerUpCollectorScan
        lda     ObjectY,x
        sec
        sbc     PowerUpY
        bpl     LE9A4
        eor     #$FF
        clc
        adc     #$01
LE9A4:  cmp     #$0C
        bcs     AdvancePowerUpCollectorScan
        lda     #$32
        sta     PowerUpPickupDisplayTimer
        lda     PowerUpType
        bmi     FinishPowerUpPickupScan
        lda     $C6
        cmp     #$06
        beq     DispatchCollectedPowerUp
        lda     #$50
        jsr     PreparePackedScoreIncrement
        ldx     PowerUpCollectorSlot
        ; AddPreparedScoreForPlayerSlot работает только для слотов игроков 0/1.
        jsr     AddPreparedScoreForPlayerSlot
        jsr     AwardScoreThresholdLives
        ldx     PowerUpCollectorSlot
        lda     #AudioStateStartRequested
        sta     PowerUpPickupAudioState
DispatchCollectedPowerUp:
LE9CA:  lda     PowerUpType
        asl     a
        tay
        lda     PowerUpEffectHandlers,y
        sta     ScratchPtrLo
        lda     PowerUpEffectHandlers+1,y
        sta     ScratchPtrHi
        pla
        pla
        jmp     (ScratchPtrLo)

AdvancePowerUpCollectorScan:
LE9DD:  dec     PowerUpCollectorSlot
        bpl     CheckPowerUpTankOverlap
FinishPowerUpPickupScan:
LE9E1:  rts

; Восемь 16-битных адресов обработчиков, индекс $88*2. Номера здесь намеренно
; не получают игровые имена, но наблюдаемые действия таковы:
; 0 — таймер защиты игрока / преобразование атрибутов врагов;
; 1 — общий таймер либо таймеры игроков; 2 — блоки вокруг базы;
; 3 — повышение атрибутов; 4 — уничтожение танков противоположной стороны;
; 5 — жизнь игроку / преобразование атрибутов врагов; 6 — максимум атрибутов;
; 7 — включение дополнительного состояния $0170,X.
PowerUpEffectHandlers:
LE9E2:  .word   PowerUpEffect0,PowerUpEffect1,PowerUpEffect2,PowerUpEffect3
        .word   PowerUpEffect4,PowerUpEffect5,PowerUpEffect6,PowerUpEffect7

; Увеличивает StageNumber. Обычно возвращает новое значение в A.
; Для variant ($46&$0F)=6 диапазон равен 1..$76: $77 заменяется на 1. В этом
; variant процедура всегда снимает адрес возврата и безвозвратно переходит в
; цикл обновления номера LC172, даже когда переход через границу не понадобился.
; Меняет A, StageNumber и флаги; X/Y сохраняются.
AdvanceStageNumber:
LE9F2:  inc     StageNumber
        lda     GameVariant
        and     #$0F
        cmp     #$06
        beq     LE9FF
        lda     StageNumber
        rts

LE9FF:  lda     StageNumber
        cmp     #$77
        bne     LEA09
        lda     #$01
        sta     StageNumber
LEA09:  pla
        pla
        jmp     StageSelectionInputLoop

; Сохранённый недостижимый байт после безусловного перехода StageSelectionInputLoop.
; Статических ссылок на него и следующий trampoline не найдено.
UnreferencedEa0eByte:
LEA0E:  .byte   $01
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
        bne     LEA2E
        lda     TerrainProjectileSlot
        and     #$01
        tax
        lda     PlayerExtendedUpgrade,x
        cmp     #$A0
        bcc     LEA2E
        nop
        pla
        cmp     #$22
        bne     LEA2F
        jmp     DestroyWholeTerrainTile

LEA2E:  pla
LEA2F:  cmp     #$12
        bcc     LEA36
        jmp     FinishTerrainProbeWithoutPartialDamage

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
