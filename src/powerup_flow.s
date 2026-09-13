; Выбор и дополнительные обработчики усилений ($C5F3-$C626).
; Файл включается из game_flow.s в исходной позиции для сохранения адресов ROM.

; Вход: Y=0..7 — псевдослучайный номер эффекта. При AllPowerUpsEnabled!=0
; возвращает его без изменений, иначе применяет RestrictedPowerUpTypeTable,
; исключающую эффект 7. Выход: A — номер; RAM и X/Y не меняются.
SelectPowerUpTypeForVariant:
LC5F3:  lda     AllPowerUpsEnabled
        beq     SelectRestrictedPowerUpType
        lda     AllPowerUpTypes,y
        rts

SelectRestrictedPowerUpType:
LC5FB:  lda     RestrictedPowerUpTypeTable,y
        rts

; Для игрока X<2 и AllPowerUpsEnabled!=0 увеличивает PlayerExtendedUpgrade,X
; на PlayerUpgradeLevel1, затем всегда переходит в ApplyPowerUpEffect3. Для противника или
; ограниченного набора сразу идёт в общую часть. Самостоятельно не возвращается.
PowerUpEffect3:
LC5FF:  cpx     #FirstEnemyTankSlot
        bcs     ApplyCommonPowerUpEffect3
        lda     AllPowerUpsEnabled
        beq     ApplyCommonPowerUpEffect3
        lda     PlayerExtendedUpgrade,x
        clc
        adc     #PlayerUpgradeLevel1
        sta     PlayerExtendedUpgrade,x
ApplyCommonPowerUpEffect3:
LC610:  jmp     ApplyPowerUpEffect3

; Для игрока X<2 и AllPowerUpsEnabled!=0 увеличивает PlayerExtendedUpgrade,X
; на PlayerUpgradeLevel3, затем переходит в SetMaximumObjectUpgrade. Для остальных слотов и
; вариантов выполняет только общую часть. Самостоятельно не возвращается.
PowerUpEffect6:
LC613:  cpx     #FirstEnemyTankSlot
        bcs     ApplyCommonPowerUpEffect6
        lda     AllPowerUpsEnabled
        beq     ApplyCommonPowerUpEffect6
        lda     PlayerExtendedUpgrade,x
        clc
        adc     #PlayerUpgradeLevel3
        sta     PlayerExtendedUpgrade,x
ApplyCommonPowerUpEffect6:
LC624:  jmp     SetMaximumObjectUpgrade
