; Адаптер начисления подготовленного счёта игроку ($E568-$E56F).

; Адаптирует tank slot к record index. Вход: X=slot, ScoreIncrementDigits —
; валидная семизначная decimal-запись. Для X=0/1 вызывает
; AddScoreDigitsToRecord; X>=2 отвергается без начисления и без extra-life check.
;
; Принятый путь: запись игрока меняется по модулю 10^7; A=новая цифра миллионов,
; Y=$FF, X=$FF для P1 либо $07 для P2, C=carry за миллионами, N=1/Z=0.
; Отклонённый путь сохраняет A/X/Y и RAM; C=1, Z=1 только для X=2, N задаётся
; CPX #2. ScoreIncrementDigits, HighScore, PPU/OAM/audio/RNG не меняются.
AddPreparedScoreForPlayerSlot:
LE568:  cpx     #FirstEnemyTankSlot
        bcs     FinishPreparedScoreAward
        jsr     AddScoreDigitsToRecord
FinishPreparedScoreAward:
LE56F:  rts
