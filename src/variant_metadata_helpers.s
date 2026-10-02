; Сохранённый вспомогательный код variant-метаданных ($E441-$E450).

; Статически неиспользуемый копировщик трёх соседних байтов.
; Вход: Y — беззнаковый offset от TankVariantLabels+9; bounds check отсутствует,
; поэтому это не безопасный selector четырнадцати записей. Записывает байты в
; RuntimeChecksumExpected, RuntimeChecksumActual и AllPowerUpsEnabled, то есть
; третий байт способен изменить feature flag произвольным ненулевым значением.
; Выход: A=третий байт, N/Z по нему; C/V и X/Y сохраняются. PPU/OAM/audio/RNG
; не затрагиваются. Назначение helper-а без статических callers не доказано;
; производной работе не следует считать первые два байта валидной checksum-парой.
CopyThreeVariantLabelBytes:
LE441:  lda     TankVariantLabels+9,y
        sta     RuntimeChecksumExpected
        lda     TankVariantLabels+10,y
        sta     RuntimeChecksumActual
        lda     TankVariantLabels+11,y
        sta     AllPowerUpsEnabled
        rts
