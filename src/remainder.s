; Небольшие целочисленные операции ($D34D-$D357).

RemainderDividend = $00
RemainderBySixDivisor = $06

; Возвращает RemainderDividend mod RemainderBySixDivisor повторным вычитанием.
; Вход: RemainderDividend=$00 — unsigned byte 0..255; входные flags не нужны.
; Выполняет floor(dividend/6) SBC, максимум 42. Штатный caller использует
; гарантированный выходной C=0 непосредственно следующим ADC без CLC.
;
; Выход: A=0..5, C=0, N=1, Z=0 (flags оставляет финальный CMP #6).
; При dividend>=6 V=0 от последнего SBC 6..11 minus 6; при dividend<6 SBC
; не исполняется и V сохраняется со входа. RemainderDividend, X/Y, стек и вся
; RAM сохранены. Изменение divisor в romhack требует сохранить ненулевое
; значение и проверить ожидаемые callers-ом диапазон и выходной carry.
RemainderBySix:  lda     RemainderDividend
SubtractSixUntilBelowDivisor:
LD34F:  cmp     #RemainderBySixDivisor
        bcc     ReturnRemainderBySix
        sbc     #RemainderBySixDivisor
        bcs     SubtractSixUntilBelowDivisor
ReturnRemainderBySix:
LD357:  rts
