; Инициализация новой игровой сессии ($C2B3-$C2E5).

NoSecondPlayerLives = $00

; Полный вход новой игровой сессии.
InitializeGameSession:
; Очищает две восьмибайтные записи Player1Score/Player2Score вместе с их
; завершающими байтами, затем проваливается в общий session initializer.
; Выход дополняет контракт ниже: X=Player2Score, обе records содержат
; семь нулей и $FF. HighScore не меняется.
LC2B3:  ldx     #Player1Score
        jsr     ResetEightByteRecord
        ldx     #Player2Score
        jsr     ResetEightByteRecord
; Альтернативный вход пропускает очистку score records; его использует attract mode.
; Базовые PlayerUpgradeLevel[0..1] становятся 0/$20 по sign/bit5 GameVariant;
; PlayerExtendedUpgrade и ObjectSpecialState не сбрасываются. Runtime checksum fields
; инициализируются, PlayerExtraLifeAwarded[0..1] и StageSelectionLocked обнуляются.
;
; SelectInitialLifeCount выбирает 21/8/11/3 по приоритету secret-code, held DOWN,
; held UP, default. Результат записывается в Player1Lives, Player2Lives
; и EnemySpawnColumn; последний байт позже перезапишет stage initializer. Если
; MenuSelection==0, P2 затем обнуляется; любое ненулевое значение оставляет
; P2 initial lives независимо от GameMode. StageNumber=FirstStageNumber.
;
; Выход: A=FirstStageNumber, N=0/Z=0; X сохранён (на полном входе X=Player2Score),
; Y=$FF, C=(TitleSecretInputCode>=SecretInitialLivesCode), V сохранён со входа;
; ScratchPtr=RuntimeChecksumInitialJumpTarget. GameVariant/MenuSelection/Joy*/
; TitleSecretInputCode/AllPowerUpsEnabled не меняются. PPU/OAM/APU/RNG не трогаются.
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
        ; Заполнение NOP из исходного ROM.
        nop
        nop
        nop
        nop
        rts
