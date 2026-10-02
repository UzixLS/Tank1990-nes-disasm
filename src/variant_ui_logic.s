; Инициализация upgrade игроков и заголовок варианта ($E3C9-$E3EE).

VariantTitleExtendedDoubleIndexBias = $0E

; Инициализирует PlayerUpgradeLevel обоих игроков значением
; PlayerUpgradeLevel1, если GameVariant отрицателен либо в его неотрицательном
; значении установлен bit5; иначе записывает 0. Для menu-вариантов это даёт
; upgrade 1 для extended $80..$86 и 0 для standard 0..6.
; Выход: A — записанные 0 либо $20; N=0, Z соответствует A, C/V сохраняются.
; X/Y и остальная RAM не меняются; PPU/OAM/audio/RNG не затрагиваются.
; Для производных вариантов это проверка sign/bit5, а не table lookup: любое
; отрицательное значение получает upgrade, а нестандартное положительное —
; только если в нём установлен $20.
InitializePlayerUpgradeLevelsForVariant:
LE3C9:  lda     GameVariant
        bpl     MaskVariantUpgradeLevel
        lda     #PlayerUpgradeLevel1
MaskVariantUpgradeLevel:
LE3CF:  and     #PlayerUpgradeLevel1
        sta     PlayerUpgradeLevel
        sta     PlayerUpgradeLevel+1
        rts

; Выбирает восьмибайтную запись TankVariantLabels и растрирует её по входным
; RasterStringX/Y. 0..6 дают записи 0..6, $80..$86 — 7..13. Bounds check нет;
; для иных значений low-byte арифметика может выбрать данные вне таблицы.
; AuxPtrHi всегда равен странице TankVariantLabels, а carry финального сложения
; не переносится: все выбираемые записи и их первый $FF обязаны оставаться на
; одной 256-byte странице. Record stride=8 зашит тремя ASL.
;
; Выход штатной шеститайловой записи: AuxPtr указывает на выбранную запись,
; A=$FF, Y=6, N=0/Z=1/C=1, X не определён; RasterStringX увеличен на $C0 по
; модулю 256, RasterStringY сохранён, RasterStringIndex=6. Меняет nametable
; shadow, raster scratch, PPU_ADDR и внутренний read buffer/address PPU;
; PPU queue, OAM, audio и RNG не трогает. Rendering/NMI должны быть выключены
; по контракту RasterizeTileStringToShadow, как у штатных callers.
DrawVariantTitleData:
LE3D8:  lda     #>TankVariantLabels
        sta     AuxPtrHi
        lda     GameVariant
        asl     a
        bcc     ComputeVariantTitleOffset
        clc
        ; $80..$86 преобразуются в удвоенные индексы 7..13.
        adc     #VariantTitleExtendedDoubleIndexBias
ComputeVariantTitleOffset:
LE3E4:  asl     a
        asl     a
        clc
        adc     #<TankVariantLabels
        sta     AuxPtrLo
        jsr     RasterizeTileStringToShadow
        rts
