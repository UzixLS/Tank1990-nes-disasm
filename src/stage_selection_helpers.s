; Изменение номера этапа из экрана выбора ($E9F2-$EA0E).

ExtendedStageVariantIndex = ExtendedStageVariant
ExtendedStageEndSentinel  = ExtendedStageUpperBound + 1

; Увеличивает StageNumber; вызывается через JSR из цикла выбора этапа.
; Вход: StageNumber лежит в допустимом диапазоне выбранного варианта.
; Для (GameVariant & GameVariantIndexMask) != ExtendedStageVariantIndex
; делает StageNumber=(old+1) mod256 и возвращает A=новый StageNumber, N/Z по A;
; стандартный sentinel $33 обрабатывает вызывающий код. C остаётся от сравнения
; variant с 6: C=1 для невалидных standard-index 7..15 и C=0 для 0..5;
; V, X/Y, стек и SP сохраняются.
; Для расширенного варианта циклически держит диапазон 1..$76, снимает со
; стека собственный двухбайтовый адрес возврата и без возврата переходит в
; StageSelectionInputLoop. При штатном единственном call site второй PLA даёт
; A=$C1 (high byte return address); это не API-результат, потому что target сразу
; продолжает UI-loop. C=1 только на wrap $77->$01, иначе C=0; V сохраняется.
; Требует именно JSR с return address на вершине стека: wrapper/tail-JMP меняет
; смысл двух PLA. Значения вне заявленных 1..50/1..118 не clamp-ятся: например,
; $FF+1 даёт stage 0, который опасен для LoadAndDrawStage.
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
