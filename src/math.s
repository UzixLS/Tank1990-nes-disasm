; Общие арифметические помощники ($DAAF-$DABA).
; Файл включается из ppu.s в исходной позиции, чтобы сохранять адреса ROM.

; Преобразует результат беззнакового сравнения через SEC/SBC в -1/0/+1:
; A=0 при равенстве (Z=1), A=1 при отсутствии займа (Z=0,C=1), A=$FF при
; займе (Z=0,C=0). Это unsigned relation: N/V результата SBC не участвуют.
;
; Вход: A и Z/C должны без промежуточной flag-changing инструкции поступать
; от одного SEC/SBC. Равная ветвь полагается на A=0 от этого SBC и сама A не
; обнуляет, поэтому искусственно несогласованные A/Z нарушают контракт.
; Выход: A=$FF/0/1, N/Z соответствуют A; C и V сохраняются от вычитания.
; X/Y, RAM, стек и SP не меняются. Romhack-callers могут использовать C как
; исходный unsigned >=, но не должны трактовать результат как signed overflow.
NormalizeSubtractionSign:
LDAAF:  beq     ReturnNormalizedSubtractionSign
        bcs     ReturnPositiveSubtractionSign
        lda     #$FF
        jmp     ReturnNormalizedSubtractionSign

ReturnPositiveSubtractionSign:
LDAB8:  lda     #$01
ReturnNormalizedSubtractionSign:
LDABA:  rts
