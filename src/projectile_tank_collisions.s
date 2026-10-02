; Столкновения снарядов с игроками и противниками ($E70C-$E83F).

TankCollisionSlot       = $5A
ProjectileCollisionSlot = $5B
ScoringPlayerIndex      = $47
TankProjectileHitRadius = $0A
EnemyTypeAttributeBias  = $04

; Общий проход снарядов по танкам.
; Фаза 1 проверяет игроков Object 1..0 против активных снарядов строго 7..2;
; slots 0/1 и дополнительные player slots 8/9 здесь не участвуют. Targetable
; ObjectState лежит в $80..$DF. Попадание — квадрат с обеими wrapped
; signed-distance строго <10. Например, координаты $FF и $00 считаются
; соседними, а разность $80 остаётся 128; romhack с объектами у края должен
; учитывать эту тороидальную 8-битную метрику.
;
; При shield снаряд сначала получает $33, затем сразу state=0 без impact-frame
; и без audio; скан оставшихся снарядов того же игрока продолжается. Без shield
; первый hit передаётся HandleProjectileHitOnPlayer и немедленно заканчивает
; projectile scan этого игрока: ObjectSpecialState поглощается с сохранением
; impact $33, maximum armor понижается до level 2 с armor sound, иначе игрок
; переходит в destroyed state и запрашивается destruction noise.
; Фаза 2 проверяет врагов Object 7..2 против логических снарядов игроков
; в порядке slots 9,8,1,0. Владелец и credit определяются только slot&1:
; 0/8 -> P1, 1/9 -> P2. При нескольких наложенных выстрелах armor может получить
; несколько hits за проход; после полного уничтожения следующий enemy начинается
; сразу. Снаряд, попавший в более высокий enemy slot, получает $33 и уже не может
; попасть в последующие slots.
;
; Вход: состояния и координаты танков/снарядов. Выход после фактических двух
; enemy passes: A=1, TankCollisionSlot=1, Z=1, C=1, N=0; X/Y,
; ProjectileCollisionSlot и V не определены. Побочно меняет ScoringPlayerIndex
; ($47, alias CollisionPointX/ShadowQueueSavedX), ProjectileState, состояния и
; атрибуты танков, kill counts, score records/ScoreIncrementDigits, lives и
; audio states. SpawnPowerUp дополнительно меняет RNG, $00 scratch,
; PowerUpCollectorSlot/display timer и поля бонуса. PPU queue/registers, OAM и
; terrain напрямую не меняются; HUD увидит score/lives в следующих update-фазах.
UpdateProjectileTankCollisions:
LE70C:  lda     #$01
        sta     TankCollisionSlot
CheckNextPlayerTank:
LE710:
        ldx     TankCollisionSlot
        lda     ObjectState,x
        bpl     SkipInactivePlayerCollisionPass
        cmp     #NonTargetableTankStateMin
        bcc     CheckEnemyProjectilesAgainstPlayer
SkipInactivePlayerCollisionPass:
LE71A:  jmp     AdvancePlayerCollisionPassOrBeginEnemyPass

CheckEnemyProjectilesAgainstPlayer:
        ; TankSlotCount-1=$07 намеренно задаёт только шесть enemy projectiles.
        ; Цикл заканчивается после slot 2 и никогда не читает 1/0 либо 9/8.
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
        ; Модуль знакового 8-битного delta совпадает с кратчайшим расстоянием
        ; на кольце 0..255; случай delta=$80 после отрицания остаётся $80.
LE739:  cmp     #TankProjectileHitRadius
        bcs     AdvanceEnemyProjectileCollision
        lda     ProjectileY,y
        sec
        sbc     ObjectY,x
        bpl     PlayerHitYDistanceReady
        eor     #$FF
        clc
        adc     #$01
PlayerHitYDistanceReady:
LE74A:  cmp     #TankProjectileHitRadius
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
; зеркалит их в PlayerExtendedUpgrade/PlayerUpgradeLevel/ObjectAttributes
; и продолжает общий проход.
; Вход: X — слот поражённого игрока. Не возвращается непосредственно:
; хвостовой JMP продолжает стековую схему прохода. Меняет три записи upgrade/
; attributes и PlayerOrBaseDestructionNoiseAudioState; портит A и флаги.
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
; AdvancePlayerTankCollisionPass. Первый переход сохраняет адрес возврата на
; стеке; вложенный вход при TankCollisionSlot<0 возвращается сюда и запускает
; проход врагов. Его RTS разматывает сохранённый адрес и тем же способом запускает
; проход врагов второй раз, после чего следующий RTS выходит к вызывающему.
; Фактический результат — два полных enemy passes 7..2. При рефакторинге нельзя
; сворачивать их в один без изменения точных side effects/тайминга.
AdvancePlayerCollisionPassOrBeginEnemyPass:
LE77A:  jsr     AdvancePlayerTankCollisionPass
        nop
        lda     #(TankSlotCount-1)
        sta     TankCollisionSlot
CheckNextEnemyTank:
LE782:  ldx     TankCollisionSlot
        lda     ObjectState,x
        bpl     SkipInactiveEnemyCollisionPass
        cmp     #NonTargetableTankStateMin
        bcc     CheckPlayerProjectilesAgainstEnemy
SkipInactiveEnemyCollisionPass:
LE78C:  jmp     AdvanceEnemyTankCollision

CheckPlayerProjectilesAgainstEnemy:
LE78F:  lda     #(ProjectileSlotCount-1)
        sta     ProjectileCollisionSlot
CheckNextPlayerProjectile:
LE793:  lda     ProjectileCollisionSlot
        and     #PlayerProjectileSlotMask
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
        ; Та же wrapped signed-distance, что и в player phase; обе оси <10.
LE7AA:  lda     ProjectileX,y
        sec
        sbc     ObjectX,x
        bpl     EnemyHitXDistanceReady
        eor     #$FF
        clc
        adc     #$01
EnemyHitXDistanceReady:
LE7B7:  cmp     #TankProjectileHitRadius
        bcs     AdvancePlayerProjectileCollision
        lda     ProjectileY,y
        sec
        sbc     ObjectY,x
        bpl     EnemyHitYDistanceReady
        eor     #$FF
        clc
        adc     #$01
EnemyHitYDistanceReady:
LE7C8:  cmp     #TankProjectileHitRadius
        bcs     AdvancePlayerProjectileCollision
        lda     #ProjectileStateImpact
        sta     ProjectileState,y
        lda     ObjectAttributes,x
        and     #EnemyPowerUpCarrierFlag
        beq     DamageOrDestroyEnemyTank
        jsr     SpawnPowerUp
        lda     ObjectAttributes,x
        cmp     #$E4
        bne     DamageOrDestroyEnemyTank
        ; Особый carrier $E4 после spawn становится $E3, а общий damage ниже
        ; сразу уменьшает его до $E2: первый hit не убивает его, снимает carrier
        ; flag и оставляет два дополнительных hit points. У остальных carriers
        ; bit2 здесь не очищается: пока он остаётся установлен, каждый новый hit
        ; снова вызывает SpawnPowerUp (например, $E5 -> $E4, затем особый путь).
        dec     ObjectAttributes,x
; Низкие два бита атрибутов работают как дополнительные hit points.
DamageOrDestroyEnemyTank:
; Вход: X — enemy slot, Y — попавший player projectile; его state уже $33.
; При ненулевых hit points уменьшает ObjectAttributes,X, запускает ArmorHitAudioState
; и продолжает проход. При нуле проваливается в полное уничтожение.
LE7E2:  lda     ObjectAttributes,x
        and     #EnemyHitPointMask
        beq     DestroyEnemyTankAndAwardScore
        dec     ObjectAttributes,x
        lda     #AudioStateStartRequested
        sta     ArmorHitAudioState
        jmp     AdvancePlayerProjectileCollision

; Полное уничтожение: state $73, ObjectSpecialState=0, запрос tank-destruction
; audio, статистика типа/владельца и, кроме StageSetLength=2, награда 100..400.
; Вход: X — enemy slot, ProjectileCollisionSlot — projectile slot. Не возвращается
; непосредственно: после обновления статистики/счёта переходит к следующему танку.
; Тип вычисляется как (ObjectAttributes>>5)-4; штатные high classes
; $80/$A0/$C0/$E0 дают индексы 0..3. Другие значения не проверяются и способны
; индексировать kill counters/award table за границами — romhack должен сохранить
; этот формат. DestroyTankAndClearExtension не стирает attributes, поэтому тип
; читается после него. Портит A/X/Y и ScoreIncrementDigits; уничтожение может
; выдать extra life/audio.
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
        sbc     #EnemyTypeAttributeBias
        tax
        lda     ProjectileCollisionSlot
        and     #$01
        sta     ScoringPlayerIndex
        bne     CreditPlayer2Kill
        inc     Player1KillCounts,x
        jmp     MaybeAwardEnemyScore

CreditPlayer2Kill:
LE813:  inc     Player2KillCounts,x
MaybeAwardEnemyScore:
        ; Attract marker подавляет только score и extra-life check. Kill count,
        ; destruction state/audio и возможный power-up spawn уже выполнены.
LE815:  lda     StageSetLength
        cmp     #AttractStageSetMarker
        beq     AdvanceEnemyTankCollision
        lda     EnemyTypeScoreAwards,x
        jsr     PreparePackedScoreIncrement
        lda     ScoringPlayerIndex
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
