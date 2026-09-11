; Инициализация атрибутов игрока и заголовок варианта ($E3C9-$E3EE).

; Инициализирует $0101/$0102 значением $20, если $46 отрицателен либо в его
; неотрицательном значении установлен bit5; иначе записывает 0.
; Выход: A — записанное значение; X/Y и остальная RAM не меняются.
InitializePlayerVariantAttributes:
LE3C9:  lda     GameVariant
        bpl     MaskPlayerVariantAttribute
        lda     #$20
MaskPlayerVariantAttribute:
LE3CF:  and     #$20
        sta     PlayerUpgradeLevel
        sta     PlayerUpgradeLevel+1
        rts

; Выбирает одну из строк TankVariantLabels по $46, записывает её адрес в AuxPtr и растрирует по $56/$57.
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
