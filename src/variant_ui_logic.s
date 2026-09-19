; Инициализация upgrade игроков и заголовок варианта ($E3C9-$E3EE).

; Инициализирует PlayerUpgradeLevel обоих игроков значением
; PlayerUpgradeLevel1, если GameVariant отрицателен либо в его неотрицательном
; значении установлен bit5; иначе записывает 0. Для menu-вариантов это даёт
; upgrade 1 для extended $80..$86 и 0 для standard 0..6.
; Выход: A — записанное значение; X/Y и остальная RAM не меняются.
InitializePlayerUpgradeLevelsForVariant:
LE3C9:  lda     GameVariant
        bpl     MaskVariantUpgradeLevel
        lda     #PlayerUpgradeLevel1
MaskVariantUpgradeLevel:
LE3CF:  and     #PlayerUpgradeLevel1
        sta     PlayerUpgradeLevel
        sta     PlayerUpgradeLevel+1
        rts

; Выбирает одну из строк TankVariantLabels по GameVariant, записывает её адрес
; в AuxPtr и растрирует по RasterStringX/Y.
; Значения 0..6 выбирают TANK A..G, $80..$86 — TANK H..N. Портит A/X/Y/AuxPtr, $56/$5F и nametable shadow.
DrawVariantTitleData:
LE3D8:  lda     #>TankVariantLabels
        sta     AuxPtrHi
        lda     GameVariant
        asl     a
        bcc     ComputeVariantTitleOffset
        clc
        adc     #$0E
ComputeVariantTitleOffset:
LE3E4:  asl     a
        asl     a
        clc
        adc     #<TankVariantLabels
        sta     AuxPtrLo
        jsr     RasterizeTileStringToShadow
        rts
