; Сохранённый вспомогательный код variant-метаданных ($E441-$E450).

; Статически неиспользуемый копировщик трёх соседних байтов.
; Вход: Y — беззнаковое смещение от TankVariantLabels+9 без проверки границ.
; Записывает байты в RuntimeChecksumExpected, RuntimeChecksumActual
; и AllPowerUpsEnabled без проверки контрольной суммы и значения флага.
; Выход: A=третий байт, N/Z по нему; C/V и X/Y сохраняются. PPU/OAM/audio/RNG
; не затрагиваются. Назначение неизвестно.
CopyThreeVariantLabelBytes:
LE441:  lda     TankVariantLabels+9,y
        sta     RuntimeChecksumExpected
        lda     TankVariantLabels+10,y
        sta     RuntimeChecksumActual
        lda     TankVariantLabels+11,y
        sta     AllPowerUpsEnabled
        rts
