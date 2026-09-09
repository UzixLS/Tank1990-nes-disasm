; Выбор, распаковка и отрисовка карты этапа ($EF76-$F021).

; Выбирает набор карт по режиму, вычисляет адрес StageNumber и рисует поле 13x13.
LoadAndDrawStage:
LEF76:  cmp     #$FF
        bne     LEF82
        lda     #$20
        sta     StageNumber
        lda     #$06
        bne     LEF86
LEF82:  lda     $46
        and     #$0F
LEF86:  sta     $8F
        asl     a
        clc
        adc     $8F
        tax
        lda     ClassicLevelSetDescriptors,x
        sta     ScratchPtrLo
        inx
        lda     ClassicLevelSetDescriptors,x
        sta     ScratchPtrHi
        inx
        lda     ClassicLevelSetDescriptors,x
        sta     $8F
        lda     #$00
        sta     $00
        lda     StageNumber
LEFA4:  cmp     $8F
        bcc     LEFB3
        beq     LEFB3
        sec
        sbc     $8F
        inc     $00
        inc     $00
        bne     LEFA4
LEFB3:  pha
        jsr     RemainderBySix
        adc     ScratchPtrLo
        sta     ScratchPtrLo
        bcc     LEFBF
        inc     ScratchPtrHi
LEFBF:  pla
        sta     $00
LEFC2:  dec     $00
        beq     LEFCE
        lda     #$5B
        jsr     AddAToPointer
        jmp     LEFC2

LEFCE:  lda     #$00
        sta     $5A
        lda     ScratchPtrLo
        sta     AuxPtrLo
        lda     ScratchPtrHi
        sta     AuxPtrHi
        lda     #$10
        sta     $57
LEFDE:  jsr     WaitForNextFrame
        lda     #$10
        sta     $56
LEFE5:  lda     $5A
        lsr     a
        tay
        lda     $5A
        and     #$01
        beq     LEFF6
        lda     (AuxPtrLo),y
        and     #$0F
        jmp     LEFFC

LEFF6:  lda     (AuxPtrLo),y
        lsr     a
        lsr     a
        lsr     a
        lsr     a
LEFFC:  ldx     $56
        ldy     $57
        jsr     DrawMetatile
        lda     #$00
        sta     PpuBufferPos
        inc     $5A
        lda     $56
        clc
        adc     #$10
        sta     $56
        cmp     #$E0
        bne     LEFE5
        inc     $5A
        lda     $57
        clc
        adc     #$10
        sta     $57
        cmp     #$E0
        bne     LEFDE
        rts
