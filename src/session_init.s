; Инициализация новой игровой сессии ($C2B3-$C2E5).

; Сбрасывает записи двух игроков и общие счётчики новой игровой сессии.
InitializeGameSession:
; Очищает две восьмибайтные записи игроков, пересчитывает integrity-сумму, сбрасывает session-флаги,
; задаёт обоим игрокам выбранное число жизней, а в single-player обнуляет Player2Lives. StageNumber=1.
; Портит A/X/Y, $11/$12 и перечисленную RAM; PPU/OAM/APU не трогает.
LC2B3:  ldx     #$15
        jsr     ResetEightByteRecord
        ldx     #$1D
        jsr     ResetEightByteRecord
; Альтернативный вход пропускает очистку двух записей счёта; используется attract mode.
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
LC2DD:  lda     #$01
        sta     StageNumber
        nop
        nop
        nop
        nop
        rts
