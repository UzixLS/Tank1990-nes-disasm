; Инициализация объектов и счётчиков выбранного этапа ($C331-$C3B4).

EnemyCountPerStage          = $14
FirstZeroEnemyActivityIntervalStage = $0C
EarlyStageActivityChoiceBase        = $0C

; Инициализирует runtime выбранного этапа. ClearProjectileStates обнуляет только
; state десяти снарядов; ClearTankStates — state восьми танков и перекрывающийся
; блок PlayerIceState/transition/debug RAM. Остальные payload-поля объектов могут
; оставаться старыми, но state=0 делает слоты неактивными. Для каждого игрока с
; Lives!=0 создаёт spawn-object в слотах Player1TankSlot/Player2TankSlot.
; Задаёт по 20 EnemiesToSpawn/EnemiesRemaining и HUD-маркеров. EnemySpawnTimer=0
; разрешает попытку spawn уже на первом logic tick; EnemySpawnColumn=0 из-за
; pre-increment в SpawnTank делает первой точкой индекс 1 (центр), затем 2 и 0.
; PowerUpX=0 удаляет активный бонус, но Y/type/display timer здесь не очищаются.
;
; Требует включённый NMI: один WaitForNextFrame вызывается явно, второй — внутри
; DrawStageNumberHud. Они косвенно обслуживают OAM DMA, input и audio; FrameCounter
; не сбрасывается и продвигается на два кадра. Первый NMI передаёт spawn tiles и
; enemy markers, второй — player labels; stage-number commands остаются в очереди
; до следующего NMI. SlowFrameCounter после двух ожиданий не обязан оставаться 0.
; ConstructionMapFlag сбрасывается, а StageSelectionLocked=1 автоматически
; пропускает следующий выбор этапа. GameplayLoopAudioState=1 запрашивается уже
; после последнего внутреннего NMI и будет обработан не раньше следующего.
;
; Для StageNumber 1..11 выбирает randomByte % (12-StageNumber), затем берёт
; EarlyStageActivityIntervalTable[index]; для StageNumber>=12 задаёт interval=0
; без вызова RNG. Меняет перечисленные runtime-поля, HUD/PPU-очередь, scratch и
; A/X/Y; RemainingEnemyMarkerIndex (общий scratch $5A) остаётся $FE. Выход:
; A=EnemyActivityInterval. Score/lives/upgrades/PauseState и payload неактивных
; объектов не очищает.
InitializeStageRuntime:
LC331:  jsr     ClearProjectileStates
        jsr     ClearTankStates
        lda     #OamHiddenY
        sta     TransitionObjectY
        lda     #$00
        sta     TransitionObjectTimer
        lda     Player1Lives
        beq     TrySpawnSecondPlayer
        ldx     #Player1TankSlot
        jsr     SpawnTank
TrySpawnSecondPlayer:
LC34A:  lda     Player2Lives
        beq     InitializeStageCounters
        ldx     #Player2TankSlot
        jsr     SpawnTank
InitializeStageCounters:
LC353:  lda     #EnemyCountPerStage
        sta     EnemiesToSpawn
        sta     EnemiesRemaining
        lda     #$00
        ; Исполняемые NOP не меняют state и не имеют внутренних entry points;
        ; исходное назначение неизвестно, сохранены ради byte identity/layout.
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
        ; Аналогичный сохранённый блок: только 6 CPU cycles, без side effects.
        nop
        nop
        nop
        lda     #BattleStateActive
        sta     BattleState
        lda     #AudioStateStartRequested
        sta     GameplayLoopAudioState
        ; Числовое значение AudioStateStartRequested одновременно является true
        ; для boolean StageSelectionLocked; отдельная перезагрузка A не нужна.
        sta     StageSelectionLocked
        lda     StageNumber
        cmp     #FirstZeroEnemyActivityIntervalStage
        bcc     SelectEarlyStageActivityInterval
        lda     #$00
        sta     EnemyActivityInterval
        rts

SelectEarlyStageActivityInterval:
; Временно хранит в EnemyActivityInterval число вариантов 12-StageNumber,
; сводит random byte к остатку повторным вычитанием и заменяет временное
; значение настоящим интервалом. Для штатных stages 1..11 доступны индексы
; 0..10; последний элемент таблицы достижим только при StageNumber=0.
LC39C:  lda     #EarlyStageActivityChoiceBase
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
        lda     EarlyStageActivityIntervalTable,x
        sta     EnemyActivityInterval
        rts
