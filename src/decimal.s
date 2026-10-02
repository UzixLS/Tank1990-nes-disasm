; Преобразование байта в десятичные цифры ($C03A-$C056).
; Файл включается из game_flow.s в исходной позиции для сохранения адресов ROM.

ByteToDecimalInput = $00
DecimalHundredValue = 100
DecimalTenValue     = 10

; Преобразует unsigned ByteToDecimalInput=0..255 повторным вычитанием 100 и 10.
; Предусловие: DecimalHundreds=DecimalTens=0. Процедура сама их не очищает, а
; лишь INC-ит; ненулевые начальные значения складываются с количеством сотен/
; десятков по модулю 256 и уже не являются decimal digits. DecimalOnes всегда
; перезаписывается остатком.
;
; Выход при выполненном предусловии: DecimalHundreds=0..2,
; DecimalTens/Ones=0..9, A=ones; X/Y и ByteToDecimalInput сохранены.
; Финальный CMP #10 гарантирует C=0/N=1/Z=0 для остатка 0..9. CMP не меняет V:
; без SBC (input<10) V сохраняется от caller-а, иначе отражает последнюю SBC.
; PPU/OAM/audio/RNG и прочая RAM не затрагиваются. Время исполнения зависит от
; значения input; алгоритм не является constant-time.
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
