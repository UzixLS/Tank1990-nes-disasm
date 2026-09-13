; Взаимное уничтожение сталкивающихся снарядов ($E910-$E971).

ProjectilePairOuterSlot  = $5A
ProjectilePairInnerSlot  = $5B
ProjectilePairLogicalId  = $00
ProjectilePairHitRadius  = $06
ProjectileLogicalIdMask  = $07

; Проверяет столкновения активных снарядов друг с другом.
; Внешний цикл рассматривает только логические player slots 0,1,8,9;
; внутренний — все 10 слотов. Пары с одинаковым индексом modulo 8 исключаются,
; поэтому основные и дополнительные слоты одного владельца не гасят друг друга.
; При |dx|<6 и |dy|<6 оба ProjectileState обнуляются без взрывного state $33.
; Вход: состояния и координаты десяти снарядов.
; Выход: ProjectilePairOuterSlot=$FF; A/X/Y и ProjectilePairInnerSlot не
; определены. Портит ProjectilePairLogicalId, ProjectileState и флаги;
; PPU/OAM, audio states, танки и счёт не меняет.
UpdateProjectileProjectileCollisions:
LE910:  lda     #(ProjectileSlotCount-1)
        sta     ProjectilePairOuterSlot
CheckNextProjectilePairOuter:
LE914:  lda     ProjectilePairOuterSlot
        and     #PlayerProjectileSlotMask
        bne     AdvanceProjectilePairOuter
        ldx     ProjectilePairOuterSlot
        lda     ProjectileState,x
        and     #StateClassMask
        cmp     #ProjectileStateActive
        bne     AdvanceProjectilePairOuter
        lda     #(ProjectileSlotCount-1)
        sta     ProjectilePairInnerSlot
CheckNextProjectilePairInner:
LE928:  lda     ProjectilePairInnerSlot
        tay
        and     #ProjectileLogicalIdMask
        sta     ProjectilePairLogicalId
        lda     ProjectilePairOuterSlot
        and     #ProjectileLogicalIdMask
        cmp     ProjectilePairLogicalId
        beq     AdvanceProjectilePairInner
        lda     ProjectileState,y
        and     #StateClassMask
        cmp     #ProjectileStateActive
        bne     AdvanceProjectilePairInner
        lda     ProjectileX,y
        sec
        sbc     ProjectileX,x
        bpl     ProjectilePairXDistanceReady
        eor     #$FF
        clc
        adc     #$01
ProjectilePairXDistanceReady:
LE94D:  cmp     #ProjectilePairHitRadius
        bcs     AdvanceProjectilePairInner
        lda     ProjectileY,y
        sec
        sbc     ProjectileY,x
        bpl     ProjectilePairYDistanceReady
        eor     #$FF
        clc
        adc     #$01
ProjectilePairYDistanceReady:
LE95E:  cmp     #ProjectilePairHitRadius
        bcs     AdvanceProjectilePairInner
        lda     #$00
        sta     ProjectileState,x
        sta     ProjectileState,y
AdvanceProjectilePairInner:
LE969:  dec     ProjectilePairInnerSlot
        bpl     CheckNextProjectilePairInner
AdvanceProjectilePairOuter:
LE96D:  dec     ProjectilePairOuterSlot
        bpl     CheckNextProjectilePairOuter
        rts
