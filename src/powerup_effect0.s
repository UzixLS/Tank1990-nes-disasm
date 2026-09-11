; Обработчик усиления 0 ($D3E0-$D3FC).
; Файл включается из screens.s в исходной позиции для сохранения адресов ROM.

; Для игрока X=0/1 ставит PlayerShieldTimer,X=$0A. Для противника X>=2
; временно сохраняет X и проходит слоты танков 7..2, преобразуя атрибуты:
; ObjectAttributes=(old|$03)^$04. Возвращает исходный X; A и флаги меняются.
PowerUpEffect0:
LD3E0:  cpx     #FirstEnemyTankSlot
        bcc     ApplyPlayerPowerUpEffect0
        txa
        pha
        ldx     #(TankSlotCount-1)
ApplyPowerUpEffect0ToNextEnemy:
LD3E8:  lda     ObjectAttributes,x
        ora     #$03
        eor     #$04
        sta     ObjectAttributes,x
        dex
        cpx     #$01
        bne     ApplyPowerUpEffect0ToNextEnemy
        pla
        tax
        rts

ApplyPlayerPowerUpEffect0:
LD3F8:  lda     #$0A
        sta     PlayerShieldTimer,x
        rts
