; Дополнительные жизни за порог счёта ($D138-$D169).

; Однократно выдаёт дополнительную жизнь, когда десятитысячная цифра счёта
; достигает как минимум 2 (обычный первый порог — 20000 очков).
; Работает только при BattleStateActive. Для P1 проверяет Player1Score+2
; и PlayerExtraLifeAwarded; для P2 дополнительно требует MenuSelection!=0 и
; использует Player2Score+2/PlayerExtraLifeAwarded+1. При награде увеличивает
; соответствующий PlayerLives и запрашивает два аудиопотока дополнительной жизни. Меняет A и флаги;
; X/Y сохраняются.
AwardScoreThresholdLives:
LD138:  lda     BattleState
        cmp     #BattleStateActive
        bne     ReturnFromExtraLifeCheck
        lda     PlayerExtraLifeAwarded
        bne     CheckPlayerTwoExtraLife
        lda     Player1Score+2
        cmp     #$02
        bcc     CheckPlayerTwoExtraLife
        inc     Player1Lives
        inc     PlayerExtraLifeAwarded
        jmp     RequestExtraLifeAudio

CheckPlayerTwoExtraLife:
LD14F:  lda     MenuSelection
        beq     ReturnFromExtraLifeCheck
        lda     PlayerExtraLifeAwarded+1
        bne     ReturnFromExtraLifeCheck
        lda     Player2Score+2
        cmp     #$02
        bcc     ReturnFromExtraLifeCheck
        inc     Player2Lives
        inc     PlayerExtraLifeAwarded+1
; Общий хвост награды: запускает оба pulse-потока extra life.
; Выход: A=AudioStateStartRequested; X/Y и счётчики жизней не меняет.
RequestExtraLifeAudio:
LD161:  lda     #AudioStateStartRequested
        sta     ExtraLifePulse1AudioState
        sta     ExtraLifePulse2AudioState
ReturnFromExtraLifeCheck:
LD169:  rts
