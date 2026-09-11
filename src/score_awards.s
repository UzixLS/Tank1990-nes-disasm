; Адаптер начисления подготовленного счёта игроку ($E568-$E56F).

; Для X=0/1 прибавляет подготовленные цифры к записи счёта; для слотов врагов
; ничего не делает. При сложении портит A/X/Y и запись выбранного игрока.
AddPreparedScoreForPlayerSlot:
LE568:  cpx     #FirstEnemyTankSlot
        bcs     FinishPreparedScoreAward
        jsr     AddScoreDigitsToRecord
FinishPreparedScoreAward:
LE56F:  rts
