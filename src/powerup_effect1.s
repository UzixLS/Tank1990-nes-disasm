; Обработчик усиления 1 ($E3B8-$E3C8).

PowerUpEffect1:
; Вход: X — слот подобравшего. Для игрока X<2 ставит EnemyFreezeTimer=$0A;
; для X>=2 — оба PlayerStunTimer=$C8.
; Портит A и флаги; X/Y не меняет.
LE3B8:  cpx     #FirstEnemyTankSlot
        bcs     ApplyPowerUpEffect1ToEnemyCollector
        lda     #$0A
        sta     EnemyFreezeTimer
        rts

ApplyPowerUpEffect1ToEnemyCollector:
LE3C2:  lda     #$C8
        sta     PlayerStunTimer
        sta     PlayerStunTimer+1
        rts
