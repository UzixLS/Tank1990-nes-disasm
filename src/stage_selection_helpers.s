; Изменение номера этапа из экрана выбора ($E9F2-$EA0E).

ExtendedStageVariantIndex = ExtendedStageVariant
ExtendedStageEndSentinel  = ExtendedStageUpperBound + 1

; Увеличивает StageNumber; вызывается через JSR из цикла выбора этапа.
; Вход: StageNumber лежит в допустимом диапазоне выбранного варианта.
; Для (GameVariant & GameVariantIndexMask) != ExtendedStageVariantIndex
; возвращает A=новый StageNumber; стандартный sentinel $33 обрабатывает
; вызывающий код.
; Для расширенного варианта циклически держит диапазон 1..$76, снимает со
; стека собственный двухбайтовый адрес возврата и без возврата переходит в
; StageSelectionInputLoop. На этом пути A перезаписывается вторым PLA.
; Меняет StageNumber, A, флаги и стек описанным образом; X/Y сохраняются самой
; процедурой (последующий цикл выбора может их изменить).
AdvanceStageNumber:
LE9F2:  inc     StageNumber
        lda     GameVariant
        and     #GameVariantIndexMask
        cmp     #ExtendedStageVariantIndex
        beq     HandleExtendedStageRange
        lda     StageNumber
        rts

HandleExtendedStageRange:
LE9FF:  lda     StageNumber
        cmp     #ExtendedStageEndSentinel
        bne     DiscardAdvanceStageReturnAndResumeSelection
        lda     #FirstStageNumber
        sta     StageNumber
DiscardAdvanceStageReturnAndResumeSelection:
LEA09:  pla
        pla
        jmp     StageSelectionInputLoop

; Сохранённый недостижимый байт после безусловного перехода; ссылок не найдено.
UnreferencedEa0eByte:
LEA0E:  .byte   $01
