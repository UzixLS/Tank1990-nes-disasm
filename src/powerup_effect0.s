; Обработчик усиления 0 ($D3E0-$D3FC).
; Файл включается из screens.s в исходной позиции для сохранения адресов ROM.

; Для игрока X=0/1 ставит PlayerShieldTimer,X=PlayerShieldPowerUpDuration.
; Для X>=2 сохраняет исходный X и преобразует ObjectAttributes всех шести
; enemy slots 7..2: младшие два бита устанавливаются, bit2 инвертируется,
; остальные биты сохраняются. Состояние активности слотов не проверяется.
; Выход: X восстановлен, Y сохранён; A равно записанному таймеру для игрока
; либо последним обработанным attributes слота 2 для enemy-пути. Портит флаги;
; PPU/OAM, score, audio и состояние самого усиления не меняет.
PowerUpEffect0:
LD3E0:  cpx     #FirstEnemyTankSlot
        bcc     ApplyPlayerPowerUpEffect0
        txa
        pha
        ldx     #(TankSlotCount-1)
ApplyPowerUpEffect0ToNextEnemy:
LD3E8:  lda     ObjectAttributes,x
        ora     #EnemyAttributeTransformSetBits
        eor     #EnemyAttributeTransformToggleBit
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
