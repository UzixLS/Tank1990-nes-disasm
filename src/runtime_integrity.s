; Отложенная runtime-проверка контрольной суммы ($FD94-$FDB0).

; Проверка использует абсолютную индексацию с X=5/4, поэтому её база на
; четыре байта ниже RuntimeChecksumExpected.
IntegrityWorkBase = RuntimeChecksumExpected - $04

; При StageNumber<26 и в большинстве кадров только вызывает
; UpdateHalfSecondPhaseFlag. Начиная с 26-го этапа с вероятностью 1/8
; сравнивает RuntimeChecksumActual с RuntimeChecksumExpected. При несовпадении
; выполняет непрямой переход по ScratchPtr и к вызывающему коду не возвращается.
; Портит A; при выполнении сравнения оставляет X=4, иначе X сохраняется.
; При StageNumber>=26 может также изменить состояние RNG.
MaybeEnforceRuntimeChecksum:
LFD94:
        lda     StageNumber
        cmp     #$1A
        bcc     LFDAD
        jsr     NextRandomByte
        and     #$0E
        bne     LFDAD
        ldx     #$05
        lda     IntegrityWorkBase,x
        dex
        cmp     IntegrityWorkBase,x
        beq     LFDAD
        jmp     (ScratchPtrLo)

LFDAD:  jsr     UpdateHalfSecondPhaseFlag
        rts
