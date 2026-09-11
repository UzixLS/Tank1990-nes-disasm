; Размещение танков в точках появления ($E363-$E3B7).
; Файл включается из projectiles.s в исходной позиции для сохранения адресов ROM.

; Создаёт танк в слоте X в TankStateSpawning. Игроки 0/1 используют
; PlayerSpawnX/Y; противники циклически используют три EnemySpawnX/Y.
; Обнуляет attributes, для игроков также PlayerStunTimer,X; рисует spawn-
; метатайл $0F. Портит A/X/Y, ScratchPtr, render/terrain scratch,
; EnemySpawnColumn для противника, nametable shadow и PPU-очередь.
SpawnTank:
LE363:  lda     #$00
        sta     ObjectAttributes,x
        cpx     #FirstEnemyTankSlot
        bcs     SelectEnemySpawnPosition
        lda     PlayerSpawnX,x
        sta     ObjectX,x
        lda     PlayerSpawnY,x
        sta     ObjectY,x
        lda     #$00
        sta     PlayerStunTimer,x
        jmp     CommitTankSpawn

SelectEnemySpawnPosition:
LE37C:  inc     EnemySpawnColumn
        ldy     EnemySpawnColumn
        cpy     #$03
        bne     LoadEnemySpawnPosition
        lda     #$00
        sta     EnemySpawnColumn
        tay
LoadEnemySpawnPosition:
LE389:  lda     EnemySpawnX,y
        sta     ObjectX,x
        lda     EnemySpawnY,y
        sta     ObjectY,x
CommitTankSpawn:
LE393:  lda     #TankStateSpawning
        sta     ObjectState,x
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        lda     #$0F
        jsr     DrawMetatile
        rts

; Сохранённый байт между RTS и отдельным альтернативным spawn-entry.
; Статических ссылок на $E3A2 нет; назначение заполнения неизвестно.
UnreferencedE3a2Byte:
LE3A2:  .byte   $04

; Альтернативный spawn entry: вход A записывает в ObjectAttributes,X,
; обнуляет PowerUpX, ставит TankStateSpawning и рисует spawn-метатайл.
; Статических ссылок нет; побочные эффекты соответствуют SpawnTank.
SpawnTankWithAttributes:
LE3A3:  sta     ObjectAttributes,x
        lda     #$00
        sta     PowerUpX
        lda     #TankStateSpawning
        sta     ObjectState,x
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        lda     #$0F
        jsr     DrawMetatile
        rts
