; Инициализация новой игровой сессии ($C2B3-$C2E5).

NoSecondPlayerLives = $00

; Сбрасывает записи двух игроков и общие счётчики новой игровой сессии.
InitializeGameSession:
; Очищает две восьмибайтные записи Player1Score/Player2Score вместе с их
; завершающими байтами, затем проваливается в общий session initializer.
; Задаёт обоим игрокам выбранное число жизней, а в single-player обнуляет P2;
; StageNumber=FirstStageNumber. Выход: A=FirstStageNumber, X=Player2Score,
; Y=$FF; обе score records содержат семь нулей и $FF. HighScore не меняет.
LC2B3:  ldx     #Player1Score
        jsr     ResetEightByteRecord
        ldx     #Player2Score
        jsr     ResetEightByteRecord
; Альтернативный вход пропускает очистку двух восьмибайтных записей; используется
; attract mode. Инициализирует уровни upgrade по variant, checksum guard,
; флаги награды/выбора и жизни, сохраняя обе score records. Выход:
; A=FirstStageNumber, X сохраняется, Y=$FF; сразу после этого входа ScratchPtr
; указывает на RuntimeChecksumInitialJumpTarget. PPU/OAM/APU не меняет.
; GameVariant/MenuSelection/Joy*/TitleSecretInputCode также сохраняются.
InitializeSessionPreservingScores:
LC2BD:  jsr     InitializePlayerUpgradeLevelsForVariant
        jsr     InitializeRuntimeChecksumGuard
        lda     #$00
        sta     PlayerExtraLifeAwarded
        sta     PlayerExtraLifeAwarded+1
        sta     StageSelectionLocked
        jsr     SelectInitialLifeCount
        ; Исполняемый NOP не меняет состояние; исходное назначение неизвестно.
        nop
        sta     Player1Lives
        sta     Player2Lives
        ; Эта копия initial lives в runtime-byte сохраняет оригинальные байты,
        ; но оба штатных пути до gameplay перезаписывают EnemySpawnColumn нулём
        ; в InitializeStageRuntime.
        sta     EnemySpawnColumn
        lda     MenuSelection
        bne     FinishGameSessionInitialization
        lda     #NoSecondPlayerLives
        sta     Player2Lives
FinishGameSessionInitialization:
LC2DD:  lda     #FirstStageNumber
        sta     StageNumber
        ; Четыре NOP не имеют внутренних entry points/side effects и сохранены
        ; для byte identity; исходное назначение не установлено.
        nop
        nop
        nop
        nop
        rts
