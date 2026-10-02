; Мост к отложенной проверке runtime checksum ($BF80-$BF83).

; Единственный статически достижимый entry point хвоста первого PRG-банка.
; UpdateTank1990Extensions вызывает его один раз в конце каждого gameplay tick,
; после OAM-меток расширений и перед возможной передачей жизни.
;
; Обычный путь: JSR MaybeEnforceRuntimeChecksum, затем RTS внешнему caller-у.
; A/flags приходят из UpdateHalfSecondPhaseFlag; Y сохранён. X сохраняется,
; если checksum comparison не выполнялся, либо равен 4 после состоявшегося
; сравнения. Проверка может продвинуть RNG и полусекундную palette phase, но
; PPU queue/registers, OAM shadow и audio напрямую не меняет.
;
; При mismatch внутренний JSR return address ($BF82, возвращающий на RTS по
; $BF83) остаётся верхним stack frame, а guard делает indirect JMP вместо RTS.
; Цель, закончившаяся RTS, ещё может вернуться через bridge; начальная цель
; после session init начинается с RTI и интерпретирует этот JSR frame как
; interrupt frame. Поэтому mismatch-path не имеет общего return contract.
RunDeferredIntegrityGuard:
LBF80:
        jsr     MaybeEnforceRuntimeChecksum
        rts
