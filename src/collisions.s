LE604:  lda     #$09
        sta     $5A
LE608:  ldx     $5A
        lda     ProjectileState,x
        and     #$F0
        cmp     #$40
        bne     LE68B
        lda     ProjectileFlags,x
        bne     LE61D
        txa
        eor     FrameCounter
        and     #$01
        beq     LE68B
LE61D:  lda     ProjectileState,x
        and     #$03
        tay
        lda     LEA49,y
        bpl     LE62C
        eor     #$FF
        clc
        adc     #$01
LE62C:  sta     $54
        asl     a
        asl     a
        sta     $64
        lda     LEA4D,y
        bpl     LE63C
        eor     #$FF
        clc
        adc     #$01
LE63C:  sta     $55
        asl     a
        asl     a
        sta     $65
        ldy     ProjectileY,x
        lda     ProjectileX,x
        tax
        jsr     LE693
        beq     LE65F
        ldx     $5A
        lda     ProjectileY,x
        clc
        adc     $64
        sta     $48
        lda     ProjectileX,x
        clc
        adc     $65
        sta     $47
        jsr     LE69A
LE65F:  ldx     $5A
        lda     ProjectileY,x
        sec
        sbc     $54
        tay
        lda     ProjectileX,x
        sec
        sbc     $55
        tax
        jsr     LE693
        beq     LE68B
        ldx     $5A
        lda     ProjectileY,x
        sec
        sbc     $64
        sec
        sbc     $54
        sta     $48
        lda     ProjectileX,x
        sec
        sbc     $65
        sec
        sbc     $55
        sta     $47
        jsr     LE69A
LE68B:  dec     $5A
        bmi     LE692
        jmp     LE608

LE692:  rts

LE693:  stx     $47
        sty     $48
        jsr     LD706
LE69A:  jsr     LD725
        jsr     LD73C
        beq     LE709
        lda     (ScratchPtrLo),y
        and     #$FC
        cmp     #$C8
        bne     LE6C6
        lda     $68
        beq     LE6C6
        lda     #$27
        sta     $68
        lda     #$01
        sta     $030B
        sta     $0307
        jsr     LCC08
        ldx     $5A
        lda     #$33
        sta     ProjectileState,x
        jmp     LE709

LE6C6:  lda     (ScratchPtrLo),y
        jmp     LEA12

        .byte   $EA
LE6CC:  ldx     $5A
        lda     #$33
        sta     ProjectileState,x
        lda     (ScratchPtrLo),y
        cmp     #$11
        beq     LE700
        lda     ProjectileFlags,x
        and     #$02
        beq     LE6EB
LE6DE:  lda     #$00
        jsr     LD784
        lda     #$01
        sta     $030C
        jmp     LE709

LE6EB:  lda     (ScratchPtrLo),y
        cmp     #$10
        beq     LE700
        cpx     #$02
        bcs     LE6FA
        lda     #$01
        sta     $030C
LE6FA:  jsr     LD743
        lda     #$01
        rts

LE700:  cpx     #$02
        bcs     LE709
        lda     #$01
        sta     $030D
LE709:  lda     #$00
        rts

LE70C:  lda     #$01
        sta     $5A
LE710:
        ldx     $5A
        lda     ObjectState,x
        bpl     LE71A
        cmp     #$E0
        bcc     LE71D
LE71A:  jmp     LE77A

LE71D:  lda     #$07
        sta     $5B
LE721:  ldy     $5B
        lda     ProjectileState,y
        and     #$F0
        cmp     #$40
        bne     LE772
        lda     ProjectileX,y
        sec
        sbc     ObjectX,x
        bpl     LE739
        eor     #$FF
        clc
        adc     #$01
LE739:  cmp     #$0A
        bcs     LE772
        lda     ProjectileY,y
        sec
        sbc     ObjectY,x
        bpl     LE74A
        eor     #$FF
        clc
        adc     #$01
LE74A:  cmp     #$0A
        bcs     LE772
        lda     #$33
        sta     ProjectileState,y
        lda     $89,x
        beq     LE75F
        lda     #$00
        sta     ProjectileState,y
        jmp     LE772

LE75F:  jmp     LFF66

        .byte   $EA
LE763:
        jsr     LFF93
        nop
        sta     $0178,x
        sta     $0101,x
        sta     ObjectAttributes,x
        jmp     LE77A

LE772:  dec     $5B
        lda     $5B
        cmp     #$01
        bne     LE721
LE77A:  jsr     LFFA8
        nop
        lda     #$07
        sta     $5A
LE782:  ldx     $5A
        lda     ObjectState,x
        bpl     LE78C
        cmp     #$E0
        bcc     LE78F
LE78C:  jmp     LE834

LE78F:  lda     #$09
        sta     $5B
LE793:  lda     $5B
        and     #$06
        beq     LE79C
        jmp     LE82D

LE79C:  ldy     $5B
        lda     ProjectileState,y
        and     #$F0
        cmp     #$40
        beq     LE7AA
        jmp     LE82D

LE7AA:  lda     ProjectileX,y
        sec
        sbc     ObjectX,x
        bpl     LE7B7
        eor     #$FF
        clc
        adc     #$01
LE7B7:  cmp     #$0A
        bcs     LE82D
        lda     ProjectileY,y
        sec
        sbc     ObjectY,x
        bpl     LE7C8
        eor     #$FF
        clc
        adc     #$01
LE7C8:  cmp     #$0A
        bcs     LE82D
        lda     #$33
        sta     ProjectileState,y
        lda     ObjectAttributes,x
        and     #$04
        beq     LE7E2
        jsr     LE8BE
        lda     ObjectAttributes,x
        cmp     #$E4
        bne     LE7E2
        dec     ObjectAttributes,x
LE7E2:  lda     ObjectAttributes,x
        and     #$03
        beq     LE7F2
        dec     ObjectAttributes,x
        lda     #$01
        sta     $030E
        jmp     LE82D

LE7F2:  jsr     LE3EF
        nop
        lda     #$01
        sta     $030A
        lda     ObjectAttributes,x
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        sec
        sbc     #$04
        tax
        lda     $5B
        and     #$01
        sta     $47
        bne     LE813
        inc     $73,x
        jmp     LE815

LE813:  inc     $77,x
LE815:  lda     $8F
        cmp     #$02
        beq     LE834
        lda     LE8BA,x
        jsr     LD9E1
        lda     $47
        tax
        jsr     LD9BE
        jsr     LD138
        jmp     LE834

LE82D:  dec     $5B
        bmi     LE834
        jmp     LE793

LE834:  dec     $5A
        lda     $5A
        cmp     #$01
        beq     LE83F
        jmp     LE782

LE83F:  rts

        .byte   $54,$41,$4E,$4B,$20,$20,$41,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$42,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$43,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$44,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$45,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$46,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$47,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$48,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$49,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$4A,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$4B,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$4C,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$4D,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$4E,$FF
        .byte   $5D,$FF,$20,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF
LE8BA:  .byte   $10,$20,$30,$40
LE8BE:  lda     #$01
        sta     $0309
LE8C3:  jsr     NextRandomByte
        and     #$03
        jsr     LE902
        sta     $86
        jsr     NextRandomByte
        and     #$03
        jsr     LE902
        sta     $87
        lda     #$FF
        sta     $88
        lda     #$00
        sta     $62
        jsr     LE972
        lda     $62
        bne     LE8C3
        jsr     NextRandomByte
        and     #$07
        tay
        jsr     LC5F3
        sta     $88
        lda     #$00
        sta     $62
        ldx     $5A
        ldy     $5B
        rts

LE8FA:  .byte   $00,$01,$02,$03,$04,$05,$06,$07
LE902:  sta     $00
        asl     a
        clc
        adc     $00
        asl     a
        clc
        adc     #$06
        asl     a
        asl     a
        asl     a
        rts

LE910:  lda     #$09
        sta     $5A
LE914:  lda     $5A
        and     #$06
        bne     LE96D
        ldx     $5A
        lda     ProjectileState,x
        and     #$F0
        cmp     #$40
        bne     LE96D
        lda     #$09
        sta     $5B
LE928:  lda     $5B
        tay
        and     #$07
        sta     $00
        lda     $5A
        and     #$07
        cmp     $00
        beq     LE969
        lda     ProjectileState,y
        and     #$F0
        cmp     #$40
        bne     LE969
        lda     ProjectileX,y
        sec
        sbc     ProjectileX,x
        bpl     LE94D
        eor     #$FF
        clc
        adc     #$01
LE94D:  cmp     #$06
        bcs     LE969
        lda     ProjectileY,y
        sec
        sbc     ProjectileY,x
        bpl     LE95E
        eor     #$FF
        clc
        adc     #$01
LE95E:  cmp     #$06
        bcs     LE969
        lda     #$00
        sta     ProjectileState,x
        sta     ProjectileState,y
LE969:  dec     $5B
        bpl     LE928
LE96D:  dec     $5A
        bpl     LE914
        rts

LE972:  lda     $86
        beq     LE9E1
        lda     $62
        bne     LE9E1
        jmp     LE55B

        .byte   $EA
LE97E:  ldx     $49
        lda     ObjectState,x
        bpl     LE9DD
        cmp     #$E0
        bcs     LE9DD
        lda     ObjectX,x
        sec
        sbc     $86
        bpl     LE994
        eor     #$FF
        clc
        adc     #$01
LE994:  cmp     #$0C
        bcs     LE9DD
        lda     ObjectY,x
        sec
        sbc     $87
        bpl     LE9A4
        eor     #$FF
        clc
        adc     #$01
LE9A4:  cmp     #$0C
        bcs     LE9DD
        lda     #$32
        sta     $62
        lda     $88
        bmi     LE9E1
        lda     $C6
        cmp     #$06
        beq     LE9CA
        lda     #$50
        jsr     LD9E1
        ldx     $49
        jsr     LE568
        jsr     LD138
        ldx     $49
        lda     #$01
        sta     $0306
LE9CA:  lda     $88
        asl     a
        tay
        lda     PowerUpEffectHandlers,y
        sta     ScratchPtrLo
        lda     PowerUpEffectHandlers+1,y
        sta     ScratchPtrHi
        pla
        pla
        jmp     (ScratchPtrLo)

LE9DD:  dec     $49
        bpl     LE97E
LE9E1:  rts

PowerUpEffectHandlers:
LE9E2:  .word   PowerUpEffect0,PowerUpEffect1,PowerUpEffect2,PowerUpEffect3
        .word   PowerUpEffect4,PowerUpEffect5,PowerUpEffect6,PowerUpEffect7

; Увеличивает номер этапа; в специальном режиме выполняет переход $76 -> $01.
AdvanceStageNumber:
LE9F2:  inc     StageNumber
        lda     $46
        and     #$0F
        cmp     #$06
        beq     LE9FF
        lda     StageNumber
        rts

LE9FF:  lda     StageNumber
        cmp     #$77
        bne     LEA09
        lda     #$01
        sta     StageNumber
LEA09:  pla
        pla
        jmp     LC172

        .byte   $01
        jmp     LFE9B
LEA12:  pha
        lda     $5A
        and     #$06
        bne     LEA2E
        lda     $5A
        and     #$01
        tax
        lda     $0178,x
        cmp     #$A0
        bcc     LEA2E
        nop
        pla
        cmp     #$22
        bne     LEA2F
        jmp     LE6DE

LEA2E:  pla
LEA2F:  cmp     #$12
        bcc     LEA36
        jmp     LE709

LEA36:  jmp     LE6CC

LEA39:  lda     #$00
        sta     $0178,x
        lda     $0101,x
        jmp     LE3FA

        .byte   $03
LEA45:  sta     $0305
        rts
LEA49:  .byte   $00,$FF,$00,$01
LEA4D:  .byte   $FF,$00,$01,$00
