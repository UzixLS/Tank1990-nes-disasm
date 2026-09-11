; Сохранённый вспомогательный код variant-метаданных ($E441-$E450).

; Статически неиспользуемый копировщик: переносит три байта из TankVariantLabels+9+Y в $8C..$8E.
; Вход: Y — offset; выход: A — третий байт. X/Y не меняет; флаги по последнему LDA.
CopyThreeVariantLabelBytes:
LE441:  lda     TankVariantLabels+9,y
        sta     RuntimeChecksumExpected
        lda     TankVariantLabels+10,y
        sta     RuntimeChecksumActual
        lda     TankVariantLabels+11,y
        sta     AllPowerUpsEnabled
        rts
