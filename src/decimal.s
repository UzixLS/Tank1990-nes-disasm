; Преобразование байта в десятичные цифры ($C03A-$C056).
; Файл включается из game_flow.s в исходной позиции для сохранения адресов ROM.

ByteToDecimalInput = $00

; Вход: ByteToDecimalInput — байт 0..255, DecimalHundreds/Tens заранее обнулены.
; Выход: DecimalHundreds/Tens/Ones — десятичные цифры.
; Портит A и флаги; X/Y не меняет. Не обнуляет сотни/десятки самостоятельно.
ByteToDecimalDigits:
        lda     ByteToDecimalInput
CountDecimalHundreds:
LC03C:  cmp     #$64
        bcc     CountDecimalTens
LC040:  sec
        sbc     #$64
        inc     DecimalHundreds
        jmp     CountDecimalHundreds

CountDecimalTens:
LC048:  cmp     #$0A
        bcc     StoreByteDecimalOnes
        sec
        sbc     #$0A
        inc     DecimalTens
        jmp     CountDecimalTens

StoreByteDecimalOnes:
LC054:  sta     DecimalOnes
        rts
