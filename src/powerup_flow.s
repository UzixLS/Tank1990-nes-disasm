; Выбор и дополнительные обработчики усилений ($C5F3-$C626).
; Файл включается из game_flow.s в исходной позиции для сохранения адресов ROM.

; Преобразует уже полученный индекс в номер типа; сама RNG не вызывает.
; Вход: Y=0..7. Проверки границ нет, обе таблицы обязаны содержать 8 байтов.
; При AllPowerUpsEnabled!=0 используется identity-таблица 0..7. При нуле
; RestrictedPowerUpTypeTable задаёт 0,1,2,3,3,4,5,6: тип 7 исключён, а тип 3
; занимает два из восьми входных индексов. Это зависит от feature flag, а не
; непосредственно от GameVariant.
; Выход: A=тип, N/Z соответствуют A; X, Y и RAM не меняются.
; Порядок типов обязан оставаться согласованным с PowerUpEffectHandlers и
; графическими блоками по четыре tile, выбираемыми через PowerUpType.
SelectPowerUpTypeForVariant:
LC5F3:  lda     AllPowerUpsEnabled
        beq     LoadRestrictedPowerUpType
        lda     AllPowerUpTypes,y
        rts

LoadRestrictedPowerUpType:
LC5FB:  lda     RestrictedPowerUpTypeTable,y
        rts

; Дополнительная часть effect 3 для расширенного набора.
; Вход: X=slot collector-а. Для игрока X<2 при AllPowerUpsEnabled!=0 прибавляет
; $20 к PlayerExtendedUpgrade,X с обычным восьмибитным wrap, без saturation и
; без проверки текущего upgrade. Противник или restricted-набор пропускает это.
; Затем tail-call ApplyPowerUpEffect3: игроку он повышает PlayerUpgradeLevel на
; $20 только пока тот <$60 и копирует уровень в ObjectAttributes; для enemy
; collector устанавливает bit 3 атрибутов всех enemy slots 2..7 и восстанавливает
; исходный X. Wrapper не вызывает RNG и сам не меняет PPU/OAM/audio.
; Выход и флаги принадлежат ApplyPowerUpEffect3; самостоятельно не возвращается.
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

; Дополнительная часть effect 6 для расширенного набора.
; Вход: X=slot collector-а. Для игрока X<2 при AllPowerUpsEnabled!=0 прибавляет
; $60 к PlayerExtendedUpgrade,X с восьмибитным wrap, без saturation. Для enemy
; collector или restricted-набора накопитель не меняется.
; Затем tail-call SetMaximumObjectUpgrade устанавливает ObjectAttributes,X=$63
; и для игрока также PlayerUpgradeLevel,X=$63; у противника меняется только
; ObjectAttributes. Итог: A=$63, X/Y сохранены; flags остаются от CPX #2 внутри
; SetMaximumObjectUpgrade (C=0/N=1 для игроков, Z=1 для enemy slot 2, иначе
; C=1/N=Z=0). PPU/OAM/audio/RNG не затрагиваются. Wrapper самостоятельно не
; возвращается.
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
