; Небольшие целочисленные операции ($D34D-$D357).

; Возвращает в A остаток от деления scratch-байта $00 на 6.
; Входное $00 не меняет; X/Y сохраняет. C=0 на выходе, кроме теоретического
; случая переполнения промежуточного вычитания, недостижимого для байта.
RemainderBySix:  lda     $00
SubtractSixUntilBelowDivisor:
LD34F:  cmp     #$06
        bcc     ReturnRemainderBySix
        sbc     #$06
        bcs     SubtractSixUntilBelowDivisor
ReturnRemainderBySix:
LD357:  rts
