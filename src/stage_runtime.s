; Инициализация объектов и счётчиков выбранного этапа ($C331-$C3B4).

EnemyCountPerStage          = $14
FirstLateStageNumber        = $0C
EarlyStageIntervalNumerator = $0C

; Инициализирует рабочее состояние выбранного этапа: очищает танки/снаряды, создаёт танки живых игроков,
; задаёт EnemyCountPerStage в EnemiesToSpawn/EnemiesRemaining, сбрасывает
; таймеры/флаги, рисует HUD и включает BattleStateActive.
; Для этапов 1..11 выбирает псевдослучайный EnemyActivityInterval из
; EarlyStageSpawnDelayTable, для поздних — 0.
; Меняет объекты, HUD/PPU-очередь и рабочую RAM; для этапов 1..11 также RNG.
; Портит A/X/Y и ScratchPtr; OAM/APU напрямую не меняет.
InitializeStageRuntime:
LC331:  jsr     ClearProjectileStates
        jsr     ClearTankStates
        lda     #$F0
        sta     TransitionObjectY
        lda     #$00
        sta     TransitionObjectTimer
        lda     Player1Lives
        beq     TrySpawnSecondPlayer
        ldx     #$00
        jsr     SpawnTank
TrySpawnSecondPlayer:
LC34A:  lda     Player2Lives
        beq     InitializeStageCounters
        ldx     #$01
        jsr     SpawnTank
InitializeStageCounters:
LC353:  lda     #EnemyCountPerStage
        sta     EnemiesToSpawn
        sta     EnemiesRemaining
        lda     #$00
        nop
        nop
        sta     SlowFrameCounter
        sta     ConstructionMapFlag
        sta     BaseFortificationTimer
        sta     PlayerStunTimer
        sta     PlayerStunTimer+1
        sta     PlayerShieldTimer
        sta     PlayerShieldTimer+1
        sta     EnemySpawnTimer
        sta     PowerUpX
        sta     EnemyFreezeTimer
        sta     EnemySpawnColumn
        jsr     ClearStageWorkBytes
        jsr     InitializeRemainingEnemyMarkers
        jsr     WaitForNextFrame
        jsr     DrawPlayerHudLabels
        jsr     DrawStageNumberHud
        nop
        nop
        nop
        lda     #BattleStateActive
        sta     BattleState
        lda     #AudioStateStartRequested
        sta     GameplayLoopAudioState
        sta     StageSelectionLocked
        lda     StageNumber
        cmp     #FirstLateStageNumber
        bcc     SelectEarlyStageActivityInterval
        lda     #$00
        sta     EnemyActivityInterval
        rts

SelectEarlyStageActivityInterval:
; Вычисляет делитель 12-StageNumber, сводит случайный байт к остатку повторным
; вычитанием и использует его как индекс EarlyStageSpawnDelayTable.
LC39C:  lda     #EarlyStageIntervalNumerator
        sec
        sbc     StageNumber
        sta     EnemyActivityInterval
        jsr     NextRandomByte
ReduceActivityIntervalRandomIndex:
LC3A6:  cmp     EnemyActivityInterval
        bcc     LoadEarlyStageActivityInterval
        sbc     EnemyActivityInterval
        bcs     ReduceActivityIntervalRandomIndex
LoadEarlyStageActivityInterval:
LC3AE:  tax
        lda     EarlyStageSpawnDelayTable,x
        sta     EnemyActivityInterval
        rts
