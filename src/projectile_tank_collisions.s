; Столкновения снарядов с игроками и противниками ($E70C-$E83F).

TankCollisionSlot       = $5A
ProjectileCollisionSlot = $5B
ScoringPlayerIndex      = $47
TankProjectileHitRadius = $0A

; Общий проход снарядов по танкам.
; Фаза 1 проверяет игроков Object 1..0 против активных снарядов 9..2:
; сюда входят вражеские слоты 2..7 и дополнительные player-слоты 8/9.
; Попадание определяется квадратом |dx|<10, |dy|<10. PlayerShieldTimer,X поглощает
; снаряд без взрыва; иначе управление передаётся HandleProjectileHitOnPlayer.
; AdvancePlayerTankCollisionPass из collision_extensions.s возвращает сюда
; для следующего игрока.
; Фаза 2 проверяет врагов Object 7..2 против логических снарядов игроков
; в слотах 0,1,8,9, начисляет уничтожения и очки.
; Вход: состояния и координаты танков/снарядов. Выход: A=1,
; TankCollisionSlot=1; X/Y и ProjectileCollisionSlot не определены.
; Побочно меняет ScoringPlayerIndex, ProjectileState, состояния/атрибуты
; танков, Player1KillCounts/Player2KillCounts, записи счёта и audio/bonus-флаги. Условное
; создание бонуса также меняет RNG, PowerUpSpawnAudioState,
; PowerUpCollectorSlot и поля бонуса.
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
; Это намеренная стековая схема, а не обычный цикл.
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
        and     #$04
        beq     DamageOrDestroyEnemyTank
        jsr     SpawnPowerUp
        lda     ObjectAttributes,x
        cmp     #$E4
        bne     DamageOrDestroyEnemyTank
        dec     ObjectAttributes,x
; Низкие два бита атрибутов работают как дополнительные hit points.
DamageOrDestroyEnemyTank:
; Вход: X — enemy slot, Y — попавший player projectile; его state уже $33.
; При ненулевых hit points уменьшает ObjectAttributes,X, запускает ArmorHitAudioState
; и продолжает проход. При нуле проваливается в полное уничтожение.
LE7E2:  lda     ObjectAttributes,x
        and     #$03
        beq     DestroyEnemyTankAndAwardScore
        dec     ObjectAttributes,x
        lda     #AudioStateStartRequested
        sta     ArmorHitAudioState
        jmp     AdvancePlayerProjectileCollision

; Полное уничтожение: state $73, запрос TankDestructionAudioState,
; статистика типа/владельца и, кроме StageSetLength=2, награда 100..400 очков.
; Вход: X — enemy slot, ProjectileCollisionSlot — projectile slot. Не возвращается
; непосредственно: после обновления статистики/счёта переходит к следующему танку.
; Портит A/X/Y и ScoreIncrementDigits; уничтожение может выдать extra life/audio.
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
        sta     ScoringPlayerIndex
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
