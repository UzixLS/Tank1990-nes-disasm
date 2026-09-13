; Изменение номера этапа из экрана выбора ($E9F2-$EA0E).

ExtendedStageVariantIndex = ExtendedStageVariant
ExtendedStageEndSentinel  = ExtendedStageUpperBound + 1

; Увеличивает StageNumber. Обычно возвращает новое значение в A.
; Для (GameVariant & $0F)=6 диапазон равен 1..$76: $77 заменяется на 1.
; В этом варианте процедура всегда снимает адрес возврата и переходит прямо в
; StageSelectionInputLoop. Меняет A, StageNumber и флаги; X/Y сохраняются.
AdvanceStageNumber:
LE9F2:  inc     StageNumber
        lda     GameVariant
        and     #GameVariantIndexMask
        cmp     #ExtendedStageVariantIndex
        beq     WrapExtendedStageRange
        lda     StageNumber
        rts

WrapExtendedStageRange:
LE9FF:  lda     StageNumber
        cmp     #ExtendedStageEndSentinel
        bne     ResumeStageSelectionAfterIncrement
        lda     #FirstStageNumber
        sta     StageNumber
ResumeStageSelectionAfterIncrement:
LEA09:  pla
        pla
        jmp     StageSelectionInputLoop

; Сохранённый недостижимый байт после безусловного перехода; ссылок не найдено.
UnreferencedEa0eByte:
LEA0E:  .byte   $01
