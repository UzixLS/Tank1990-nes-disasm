; Размещение танков в точках появления ($E363-$E3B7).
; Файл включается из projectiles.s в исходной позиции для сохранения адресов ROM.

EnemySpawnPointCount = 3
TankSpawnClearMetatile = $0F

; Создаёт tank slot X в первой половине spawn lifecycle, state $F0. Игроки
; получают фиксированные центры ($58/$98,$D8). Враги циклически используют
; верхние центры X=$78,$D8,$18: pre-increment EnemySpawnColumn при штатном
; начальном нуле даёт последовательность индексов 1,2,0.
;
; Всегда обнуляет ObjectAttributes,X; у игрока также PlayerStunTimer,X. Затем
; метатайлом $0F (четыре blank tiles, palette 0) очищает 16x16 spawn-cell в
; shadow и добавляет 20 байт PPU-команд. Вход: X=slot 0..7; для enemy исходный
; EnemySpawnColumn=0..2; в PPU buffer свободны 20 байт и lookahead, NMI не
; прерывает построение команд. Выход: A=$FF, X=$40, Y=0,
; PpuBufferPos=old+20, ScratchPtr указывает на lower-right tile spawn-cell.
; Меняет metatile/render/terrain scratch, четыре tile bytes и palette quadrant
; shadow; PPU registers не трогает. У врага меняет EnemySpawnColumn, у игрока
; сохраняет его. Остальные payload-поля slot здесь намеренно не очищаются.
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
        cpy     #EnemySpawnPointCount
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
        lda     #TankSpawnClearMetatile
        jsr     DrawMetatile
        rts

; Сохранённый байт между RTS и отдельным альтернативным spawn-entry.
; Статических ссылок на $E3A2 нет; назначение заполнения неизвестно.
UnreferencedE3a2Byte:
LE3A2:  .byte   $04

; Статически неиспользуемый альтернативный spawn entry. Вход: X=slot 0..7,
; A=готовые ObjectAttributes; ObjectX/Y уже заданы, требования PPU-очереди те
; же, что у SpawnTank. Обнуляет PowerUpX, ставит state $F0 и очищает spawn-cell.
; В отличие от основного входа не выбирает координаты, не очищает stun и не
; меняет EnemySpawnColumn. Выход и metatile side effects те же: A=$FF, X=$40,
; Y=0, PpuBufferPos=old+20; прочие payload-поля slot сохраняет.
SpawnTankWithAttributes:
LE3A3:  sta     ObjectAttributes,x
        lda     #$00
        sta     PowerUpX
        lda     #TankStateSpawning
        sta     ObjectState,x
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        lda     #TankSpawnClearMetatile
        jsr     DrawMetatile
        rts
