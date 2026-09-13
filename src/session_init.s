; Инициализация новой игровой сессии ($C2B3-$C2E5).

; Сбрасывает записи двух игроков и общие счётчики новой игровой сессии.
InitializeGameSession:
; Очищает две восьмибайтные записи Player1Score/Player2Score вместе с их
; завершающими байтами, затем проваливается в общий session initializer.
; Задаёт обоим игрокам выбранное число жизней, а в single-player обнуляет P2;
; StageNumber=1. Портит A/X/Y, ScratchPtr и перечисленную RAM; PPU/OAM/APU
; напрямую не трогает.
LC2B3:  ldx     #Player1Score
        jsr     ResetEightByteRecord
        ldx     #Player2Score
        jsr     ResetEightByteRecord
; Альтернативный вход пропускает очистку двух восьмибайтных записей; используется
; attract mode. Инициализирует variant attributes, runtime checksum guard,
; флаги награды/выбора и жизни. Выход: A=1, X остаётся от вызывающего этого
; входа, Y=$FF из checksum; ScratchPtr указывает на RuntimeChecksumFailureTarget.
InitializeSessionAfterScoreRecords:
LC2BD:  jsr     InitializePlayerVariantAttributes
        jsr     InitializeRuntimeChecksumGuard
        lda     #$00
        sta     PlayerExtraLifeAwarded
        sta     PlayerExtraLifeAwarded+1
        sta     StageSelectionLocked
        jsr     SelectInitialLifeCount
        nop
        sta     Player1Lives
        sta     Player2Lives
        sta     EnemySpawnColumn
        lda     MenuSelection
        bne     FinishGameSessionInitialization
        lda     #$00
        sta     Player2Lives
FinishGameSessionInitialization:
LC2DD:  lda     #FirstStageNumber
        sta     StageNumber
        nop
        nop
        nop
        nop
        rts
