; Отложенная runtime-проверка контрольной суммы ($FD94-$FDB0).

; Проверка использует zero-page indexed addressing с X=5/4, поэтому её база на
; четыре байта ниже RuntimeChecksumExpected.
IntegrityWorkBase = RuntimeChecksumExpected - $04
RuntimeIntegrityExpectedIndex = RuntimeChecksumExpected - IntegrityWorkBase
RuntimeIntegrityActualIndex   = RuntimeChecksumActual - IntegrityWorkBase
RuntimeIntegrityFirstStage = $1A
RuntimeIntegrityRandomMask = $0E

; До stage $1A RNG/checksum не трогает. На stage $1A+ каждый вызов расходует
; ровно один NextRandomByte; comparison выполняется, когда random bits1..3=0
; (32 из 256 значений, то есть 1/8 только при равномерном RNG; bit0 игнорируется).
; Обфусцированные indexed reads с base $88 и indexes5/4 фактически загружают
; RuntimeChecksumActual ($8D) и сравнивают его с Expected ($8C).
;
; При равенстве и на всех пропущенных checks вызывает UpdateHalfSecondPhaseFlag;
; тот меняет BackgroundPaletteIndex лишь при FrameCounter mod64=0/32. Выход
; возвращающихся путей: A/flags от этого helper-а, Y сохранён; X=4 после
; состоявшегося comparison, иначе входной X сохранён. На stage $1A+ RNG state/
; index обновляются даже если random gate затем пропускает сравнение.
;
; При несовпадении НЕ обновляет полусекундную phase и делает JMP по текущему
; volatile ScratchPtr без проверки target. InitializeRuntimeChecksumGuard
; первоначально оставляет pointer=$C5C9, где первый byte $40 есть RTI, но HUD,
; render и другие helpers широко перезаписывают pointer до первого возможного
; check. На mismatch A=Actual, X=4, Y сохранён, flags от CMP; return address
; вызвавшего JSR остаётся на стеке. Цель с RTS может использовать этот frame и
; вернуться, а начальный RTI примет JSR return bytes за interrupt frame; любая
; другая текущая цель исполняет произвольный control flow.
;
; Процедура сама не читает ROM и не восстанавливает checksum либо ScratchPtr.
MaybeEnforceRuntimeChecksum:
LFD94:
        lda     StageNumber
        cmp     #RuntimeIntegrityFirstStage
        bcc     UpdateIntegrityPhaseAndReturn
        jsr     NextRandomByte
        and     #RuntimeIntegrityRandomMask
        bne     UpdateIntegrityPhaseAndReturn
        ldx     #RuntimeIntegrityActualIndex
        lda     IntegrityWorkBase,x
        dex
        cmp     IntegrityWorkBase,x
        beq     UpdateIntegrityPhaseAndReturn
        jmp     (ScratchPtrLo)

UpdateIntegrityPhaseAndReturn:
LFDAD:  jsr     UpdateHalfSecondPhaseFlag
        rts
