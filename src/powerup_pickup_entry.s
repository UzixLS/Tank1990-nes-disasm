; Выбор начального слота прохода подбора усиления ($E55B-$E567).

PowerUpExtendedCollectorVariantMin = TankSlotCount

; При GameVariant>=PowerUpExtendedCollectorVariantMin начинает с последнего
; tank slot, иначе с последнего player slot, затем хвостовым
; переходом передаёт управление CheckPowerUpTankOverlap. Для штатных вариантов
; это даёт проверку 7..0 либо 1..0. Портит A/X/Y/ScratchPtr и рабочую RAM
; согласно контракту продолжения в powerup_pickup.s.
BeginPowerUpCollectorScan:
LE55B:  lda     #(TankSlotCount-1)
        cmp     GameVariant
        bcc     StorePowerUpCollectorScanStart
        lda     #(PlayerTankCount-1)
StorePowerUpCollectorScanStart:
LE563:  sta     PowerUpCollectorSlot
        jmp     CheckPowerUpTankOverlap
