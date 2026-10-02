; Генератор псевдослучайных байтов ($D44D-$D466).

RandomEntropyZeroPageBase = $00

; Продвигает восьмибитный state и индекс выборки zero page. Точная арифметика:
;   product = (7*old RandomState) & $FF;
;   partial = product + SlowFrameCounter;
;   RandomIndex = (RandomIndex+1) & $FF;
;   new state = (low(partial) + ZP[RandomIndex] + carry(partial)) & $FF.
; Carry первого ADC намеренно проходит через INC/LDX во второй ADC, поэтому это
; не простая сумма трёх байтов modulo 256. Вся zero page является частью
; входного состояния генератора; одинаковый seed без одинаковой RAM/кадровой
; фазы не гарантирует одинаковую последовательность.
;
; Выход: A=RandomState, N/Z по нему, C/V от финального ADC; X/Y и глубина стека
; сохранены. Меняет только RandomState/RandomIndex и flags, остальную zero page
; читает без записи. RandomIndex естественно оборачивается $FF->$00.
NextRandomByte:  txa
        pha
        lda     RandomState
        asl     a
        asl     a
        asl     a
        sec
        sbc     RandomState
        clc
        adc     SlowFrameCounter
        inc     RandomIndex
        ldx     RandomIndex
        adc     RandomEntropyZeroPageBase,x
        sta     RandomState
        pla
        tax
        lda     RandomState
        rts
