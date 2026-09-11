; Взаимное уничтожение сталкивающихся снарядов ($E910-$E971).

ProjectilePairOuterSlot  = $5A
ProjectilePairInnerSlot  = $5B
ProjectilePairOwnerIndex = $00

; Проверяет столкновения активных снарядов друг с другом.
; Внешний цикл рассматривает только логические player slots 0,1,8,9;
; внутренний — все 10 слотов. Пары с одинаковым индексом modulo 8 исключаются,
; поэтому основные и дополнительные слоты одного владельца не гасят друг друга.
; При |dx|<6 и |dy|<6 оба ProjectileState обнуляются без взрывного state $33.
; Побочно меняет A/X/Y, ProjectilePairOuterSlot/
; ProjectilePairInnerSlot/ProjectilePairOwnerIndex и ProjectileState; прочую RAM не меняет.
UpdateProjectileProjectileCollisions:
LE910:  lda     #(ProjectileSlotCount-1)
        sta     ProjectilePairOuterSlot
CheckNextProjectilePairOuter:
LE914:  lda     ProjectilePairOuterSlot
        and     #$06
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
        and     #$07
        sta     ProjectilePairOwnerIndex
        lda     ProjectilePairOuterSlot
        and     #$07
        cmp     ProjectilePairOwnerIndex
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
LE94D:  cmp     #$06
        bcs     AdvanceProjectilePairInner
        lda     ProjectileY,y
        sec
        sbc     ProjectileY,x
        bpl     ProjectilePairYDistanceReady
        eor     #$FF
        clc
        adc     #$01
ProjectilePairYDistanceReady:
LE95E:  cmp     #$06
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
