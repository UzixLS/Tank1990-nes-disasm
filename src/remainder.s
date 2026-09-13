; Небольшие целочисленные операции ($D34D-$D357).

RemainderDividend = $00
RemainderDivisor  = $06

; Возвращает в A остаток от деления RemainderDividend на 6 повторным вычитанием.
; Выход: A=0..5, C=0; RemainderDividend и X/Y не меняются. Время выполнения
; зависит от частного (не более 42 вычитаний для входного байта).
RemainderBySix:  lda     RemainderDividend
SubtractSixUntilBelowDivisor:
LD34F:  cmp     #RemainderDivisor
        bcc     ReturnRemainderBySix
        sbc     #RemainderDivisor
        bcs     SubtractSixUntilBelowDivisor
ReturnRemainderBySix:
LD357:  rts
