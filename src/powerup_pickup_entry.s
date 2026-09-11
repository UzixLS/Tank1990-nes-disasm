; Выбор начального слота прохода подбора усиления ($E55B-$E567).

; При GameVariant>7 начинает со слота 7, иначе со слота 1, затем хвостовым
; переходом передаёт управление CheckPowerUpTankOverlap. Для штатных вариантов
; это даёт проверку 7..0 либо 1..0. Портит A/X/Y/ScratchPtr и рабочую RAM
; согласно контракту продолжения в powerup_pickup.s.
BeginPowerUpCollectorScan:
LE55B:  lda     #$07
        cmp     GameVariant
        bcc     StorePowerUpCollectorScanStart
        lda     #$01
StorePowerUpCollectorScanStart:
LE563:  sta     PowerUpCollectorSlot
        jmp     CheckPowerUpTankOverlap
