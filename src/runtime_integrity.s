; Отложенная runtime-проверка контрольной суммы ($FD94-$FDB0).

; Проверка использует zero-page indexed addressing с X=5/4, поэтому её база на
; четыре байта ниже RuntimeChecksumExpected.
IntegrityWorkBase = RuntimeChecksumExpected - $04
RuntimeIntegrityFirstStage = $1A
RuntimeIntegrityRandomMask = $0E

; При StageNumber<RuntimeIntegrityFirstStage и в большинстве вызовов только
; вызывает UpdateHalfSecondPhaseFlag. Начиная с 26-го этапа с вероятностью 1/8
; сравнивает RuntimeChecksumActual с RuntimeChecksumExpected. При несовпадении
; выполняет JMP по текущему volatile ScratchPtr. InitializeRuntimeChecksumGuard
; оставляет там RuntimeChecksumInitialJumpTarget (его первый байт — RTI), но до
; первой проверки pointer обычно меняют HUD/render helpers; guard адрес не
; восстанавливает. Поэтому фактическая цель mismatch зависит от последнего
; пользователя ScratchPtr, и путь не обязан возвращаться обычным RTS.
; На всех возвращающихся путях вызывает UpdateHalfSecondPhaseFlag, который
; меняет BackgroundPaletteIndex только на полусекундной фазе. Портит A и
; флаги; при сравнении оставляет X=4,
; иначе X сохраняется; Y сохраняется. На этапах 26+ обновляет RandomState и
; RandomIndex при каждом вызове, дошедшем до вероятностной проверки.
MaybeEnforceRuntimeChecksum:
LFD94:
        lda     StageNumber
        cmp     #RuntimeIntegrityFirstStage
        bcc     UpdateIntegrityPhaseAndReturn
        jsr     NextRandomByte
        and     #RuntimeIntegrityRandomMask
        bne     UpdateIntegrityPhaseAndReturn
        ldx     #$05
        lda     IntegrityWorkBase,x
        dex
        cmp     IntegrityWorkBase,x
        beq     UpdateIntegrityPhaseAndReturn
        jmp     (ScratchPtrLo)

UpdateIntegrityPhaseAndReturn:
LFDAD:  jsr     UpdateHalfSecondPhaseFlag
        rts
