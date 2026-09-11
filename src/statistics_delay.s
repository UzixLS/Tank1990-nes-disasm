; Кадровая задержка с иконками статистики ($D276-$D283).

; Ждёт X кадров, на каждом кадре заново выводя четыре значка статистики.
; Вход X должен быть 1..255: при X=0 цикл выполнит 256 проходов.
; Выход X=0; A/Y и OAM меняются через DrawStatisticsEnemyIcons.
DelayWithStatisticsIcons:
LD276:  jsr     WaitForNextFrame
        txa
        pha
        jsr     DrawStatisticsEnemyIcons
        pla
        tax
        dex
        bne     DelayWithStatisticsIcons
        rts
