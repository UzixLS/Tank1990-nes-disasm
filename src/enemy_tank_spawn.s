; Планирование появления противников ($DB48-$DB74).

; Планирует появление одного из EnemiesToSpawn врагов. Ненулевой
; EnemySpawnTimer только уменьшается; значение 1 становится 0 без попытки spawn,
; поэтому она произойдёт не раньше следующего logic tick. При нулевом timer
; сканируются slots GameMode..FirstEnemyTankSlot в обратном порядке: GameMode
; здесь одновременно является верхним индексом (штатно 5/6/7 даёт 4/5/6
; enemy slots). Если свободного state=0 нет, timer остаётся нулевым и следующий
; tick повторяет попытку.
;
; При успехе timer перезагружается EnemyActivityInterval, SpawnTank начинает
; lifecycle $F0 и очищает spawn-cell, затем EnemiesToSpawn уменьшается и HUD-cell
; с индексом нового значения очищается. Обе операции вместе добавляют 24 байта
; PPU-команд и меняют пять tile bytes плюс palette quadrant в shadow. Требуется
; NametablePpuOffset=ShadowToPrimaryNametableOffset, 24 свободных байта и
; lookahead в PPU buffer; NMI не должен прервать построение команд.
;
; Выход при успехе: CurrentTankSlot=выбранный slot, EnemiesToSpawn уменьшен,
; A=$FF, X=PpuBufferPos, Y=1; меняются поля spawned tank, EnemySpawnColumn,
; PPU queue/shadow и scratch вызванных helpers. Без свободного slot:
; CurrentTankSlot=FirstEnemyTankSlot-1, A=то же значение, X=последний проверенный
; slot, прочее состояние сохраняется. При EnemiesToSpawn=0 возвращает A=0, не
; меняя CurrentTankSlot; timer-ветвь возвращает A=его старое ненулевое значение.
SpawnPendingEnemyTank:
LDB48:  lda     EnemySpawnTimer
        beq     TrySpawnPendingEnemy
        dec     EnemySpawnTimer
        rts

TrySpawnPendingEnemy:
LDB4F:  lda     EnemiesToSpawn
        beq     FinishPendingEnemySpawn
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
FinishPendingEnemySpawn:
LDB74:  rts
