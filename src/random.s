; Генератор псевдослучайных байтов ($D44D-$D466).

; Обновляет псевдослучайное состояние в $0F/$10, сохраняя X.
; Возвращает новый байт в A; Y не меняет. Подмешивает $0A и байт
; нулевой страницы с индексом из растущего $10.
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
