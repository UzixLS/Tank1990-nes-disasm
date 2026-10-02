; Обработчик усиления 1 ($E3B8-$E3C8).

PowerUpEffect1:
; Вход: X — слот подобравшего. Для игрока X<2 перезагружает EnemyFreezeTimer;
; для X>=2 — оба PlayerStunTimer. Длительности заданы общими power-up-константами.
; Активность/верхняя граница collector slot и состояния целей не проверяются.
; Player path: A=$0A, N=0/Z=0/C=0; enemy path: A=$C8, N=1/Z=0/C=1;
; V и X/Y сохраняются. PPU/OAM/audio/RNG напрямую не меняются.
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
