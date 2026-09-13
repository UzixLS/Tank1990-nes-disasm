; Обработчик усиления 1 ($E3B8-$E3C8).

PowerUpEffect1:
; Вход: X — слот подобравшего. Для игрока X<2 перезагружает EnemyFreezeTimer;
; для X>=2 — оба PlayerStunTimer. Длительности заданы общими power-up-константами.
; Портит A и флаги; X/Y не меняет.
LE3B8:  cpx     #FirstEnemyTankSlot
        bcs     ApplyPowerUpEffect1ToEnemyCollector
        lda     #EnemyFreezePowerUpDuration
        sta     EnemyFreezeTimer
        rts

ApplyPowerUpEffect1ToEnemyCollector:
LE3C2:  lda     #PlayerStunPowerUpDuration
        sta     PlayerStunTimer
        sta     PlayerStunTimer+1
        rts
