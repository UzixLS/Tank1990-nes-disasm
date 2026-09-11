; Планирование появления противников ($DB48-$DB74).

; Пытается разместить одного из оставшихся противников ($7F) в свободный слот.
; EnemySpawnTimer — текущая задержка, EnemyActivityInterval — её
; перезагружаемое значение. GameMode=5/7 задаёт последний
; доступный слот для игры одного/двух игроков. При успехе вызывает спавн, уменьшает $7F
; и обновляет экранный счётчик. Портит A, X, CurrentTankSlot и вызываемые процедуры.
SpawnPendingEnemyTank:
LDB48:  lda     EnemySpawnTimer
        beq     TrySpawnPendingEnemy
        dec     EnemySpawnTimer
        rts

TrySpawnPendingEnemy:
LDB4F:  lda     EnemiesToSpawn
        beq     ReturnFromEnemySpawn
        lda     GameMode
        sta     CurrentTankSlot
CheckEnemySpawnSlot:
LDB57:  ldx     CurrentTankSlot
        lda     ObjectState,x
        bne     ScanPreviousEnemySlot
        lda     EnemyActivityInterval
        sta     EnemySpawnTimer
        jsr     SpawnTank
        dec     EnemiesToSpawn
        lda     EnemiesToSpawn
        jsr     ClearRemainingEnemyMarker
        rts

ScanPreviousEnemySlot:
LDB6C:  dec     CurrentTankSlot
        lda     CurrentTankSlot
        cmp     #(FirstEnemyTankSlot-1)
        bne     CheckEnemySpawnSlot
ReturnFromEnemySpawn:
LDB74:  rts
