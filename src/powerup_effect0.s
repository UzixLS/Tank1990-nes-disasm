; Обработчик усиления 0 ($D3E0-$D3FC).
; Файл включается из screens.s в исходной позиции для сохранения адресов ROM.

; Для игрока X=0/1 ставит PlayerShieldTimer,X=PlayerShieldPowerUpDuration.
; Для X>=2 сохраняет исходный X и преобразует ObjectAttributes всех шести
; enemy slots 7..2: младшие два бита устанавливаются, bit2 инвертируется,
; остальные биты сохраняются. Состояние активности слотов не проверяется.
; Выход: X восстановлен, Y сохранён; A равно записанному таймеру для игрока
; либо исходному collector slot для enemy-пути (PLA/TAX). Player path даёт
; C=0, N=0/Z=0; enemy path C=1 и N/Z по восстановленному X; V сохраняется.
; Bounds check верхней границы collector X нет. PPU/OAM, score, audio, RNG и
; состояние самого усиления не меняются.
PowerUpEffect0:
LD3E0:  cpx     #FirstEnemyTankSlot
        bcc     ApplyPlayerPowerUpEffect0
        txa
        pha
        ldx     #(TankSlotCount-1)
ApplyPowerUpEffect0ToNextEnemy:
LD3E8:  lda     ObjectAttributes,x
        ora     #EnemyHitPointMask
        eor     #EnemyPowerUpCarrierFlag
        sta     ObjectAttributes,x
        dex
        cpx     #(FirstEnemyTankSlot-1)
        bne     ApplyPowerUpEffect0ToNextEnemy
        pla
        tax
        rts

ApplyPlayerPowerUpEffect0:
LD3F8:  lda     #PlayerShieldPowerUpDuration
        sta     PlayerShieldTimer,x
        rts
