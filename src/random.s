; Генератор псевдослучайных байтов ($D44D-$D466).

; Обновляет RandomState/RandomIndex, сохраняя X.
; В расчёт входят 7*предыдущее RandomState, SlowFrameCounter и байт нулевой
; страницы с индексом из предварительно увеличенного RandomIndex; перенос
; первого сложения намеренно поступает во второе ADC.
; Выход: A=новый RandomState; X/Y и стек сохранены. Портит flags и два байта RNG;
; прочую RAM читает, но не меняет.
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
        adc     $00,x
        sta     RandomState
        pla
        tax
        lda     RandomState
        rts
