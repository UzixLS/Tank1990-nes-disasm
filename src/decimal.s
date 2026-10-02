; Преобразование байта в десятичные цифры ($C03A-$C056).
; Файл включается из game_flow.s в исходной позиции для сохранения адресов ROM.

ByteToDecimalInput = $00
DecimalHundredValue = 100
DecimalTenValue     = 10

; Вход: ByteToDecimalInput — байт 0..255, DecimalHundreds/Tens заранее обнулены.
; Повторным вычитанием сначала накапливает сотни, затем десятки; ненулевые
; исходные DecimalHundreds/Tens поэтому прибавляются к результату и являются
; ошибкой вызывающего, а не автоматически очищаются.
; Выход: DecimalHundreds/Tens/Ones — цифры 0..2/0..9/0..9, A=ones.
; Flags остаются от финального CMP #10: C=0, N=1, Z=0 независимо от ones;
; V зависит от выполненных SBC (а без вычитаний сохраняет входное значение).
; X/Y и ByteToDecimalInput сохраняет; меняет только три выходных байта
; (сотни/десятки через INC) и flags.
ByteToDecimalDigits:
        lda     ByteToDecimalInput
CountDecimalHundreds:
LC03C:  cmp     #DecimalHundredValue
        bcc     CountDecimalTens
SubtractOneHundred:
LC040:  sec
        sbc     #DecimalHundredValue
        inc     DecimalHundreds
        jmp     CountDecimalHundreds

CountDecimalTens:
LC048:  cmp     #DecimalTenValue
        bcc     StoreByteDecimalOnes
        sec
        sbc     #DecimalTenValue
        inc     DecimalTens
        jmp     CountDecimalTens

StoreByteDecimalOnes:
LC054:  sta     DecimalOnes
        rts
