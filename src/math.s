; Общие арифметические помощники ($DAAF-$DABA).
; Файл включается из ppu.s в исходной позиции, чтобы сохранять адреса ROM.

; Нормализует результат предшествующего SEC/SBC: A=0 при Z=1, A=1 при C=1,
; A=$FF при заёме. Входные Z/C должны поступать без изменяющей flags инструкции
; после SBC. Выход N/Z соответствуют A, C сохраняется от вычитания;
; X/Y, RAM, стек и V сохраняются.
NormalizeSubtractionSign:
LDAAF:  beq     ReturnNormalizedSubtractionSign
        bcs     ReturnPositiveSubtractionSign
        lda     #$FF
        jmp     ReturnNormalizedSubtractionSign

ReturnPositiveSubtractionSign:
LDAB8:  lda     #$01
ReturnNormalizedSubtractionSign:
LDABA:  rts
