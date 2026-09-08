; Заключительная часть кода и векторы ($FCFC-$FFFF).

.segment "PRG1_HI": absolute

        .byte   $20,$D2,$0D,$2D,$30,$31,$5D,$31
        .byte   $34,$FF,$31,$35,$5D,$32,$38,$FF
LFD0C:  lda     $8E
        bne     LFD14
        lda     #$00
        beq     LFD16
LFD14:  lda     #$06
LFD16:  sta     ScratchPtrLo
        lda     #$FD
        sta     ScratchPtrHi
        ldx     #$15
        ldy     #$03
        jsr     QueueTileAtCoordinates
        jsr     WaitForNextFrame
        rts

LFD27:  ldx     #$0B
        lda     $46
        clc
        bpl     LFD32
        and     #$0F
        adc     #$07
LFD32:  adc     #$09
        tay
        jsr     QueueTileAtCoordinates
        rts

        .byte   $9D,$DD,$DD,$DD,$86,$DD,$DD,$9D
        .byte   $DD,$DD,$D9,$99,$DD
LFD46:  lda     $4A
        cmp     #$0F
        bne     LFD4F
        lda     #$15
        rts

LFD4F:  lda     Joy1Held
        and     #$20
        beq     LFD58
        lda     #$08
        rts

LFD58:  lda     Joy1Held
        and     #$10
        beq     LFD61
        lda     #$0B
        rts

LFD61:  lda     #$03
        rts

LFD64:  lda     Joy1Held
        and     #$01
        beq     LFD91
        lda     Joy2Held
        and     #$02
        beq     LFD91
        lda     Joy2Held
        and     #$01
        beq     LFD91
        lda     Player1Lives
        bne     LFD81
        lda     #$03
        sta     Player1Lives
        bne     LFD89
        nop
LFD81:  lda     Player2Lives
        bne     LFD91
        lda     #$03
        sta     Player2Lives
LFD89:  lda     #$01
        sta     MenuSelection
        lda     #$07
        sta     GameMode
LFD91:  jmp     SelectStage

LFD94:
        lda     StageNumber
        cmp     #$1A
        bcc     LFDAD
        jsr     NextRandomByte
        and     #$0E
        bne     LFDAD
        ldx     #$05
        lda     $88,x
        dex
        cmp     $88,x
        beq     LFDAD
        jmp     (ScratchPtrLo)

LFDAD:  jsr     LC31D
        rts

LFDB1:  cpx     #$02
        bcs     LFDBB
        lda     #$0A
        sta     $0100
        rts

LFDBB:  cpx     #$02
        bcc     LFDEF
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$6D
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$19
        jsr     QueueTileAtCoordinates
        lda     #$E5
        sta     ScratchPtrHi
        lda     #$E8
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$1A
        jsr     QueueTileAtCoordinates
        lda     #$D2
        sta     ScratchPtrHi
        lda     #$99
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$1B
        jsr     QueueTileAtCoordinates
        jmp     LCB31

LFDEF:  lda     $68
        bpl     LFDFA
        jsr     LCB9E
        lda     #$14
        sta     $45
LFDFA:  rts

LFDFB:  cpx     #$02
        bcc     LFE12
        txa
        pha
        ldx     #$07
LFE03:  lda     ObjectAttributes,x
        ora     #$08
        sta     ObjectAttributes,x
        nop
        dex
        cpx     #$01
        bne     LFE03
        pla
        tax
        rts

LFE12:  lda     $0101,x
        cmp     #$60
        bcs     LFE21
        clc
        adc     #$20
        sta     $0101,x
        sta     ObjectAttributes,x
LFE21:  rts

LFE22:  cpx     #$02
        bcc     LFE51
        lda     #$01
        sta     $5A
        sta     $030A
LFE2D:  ldy     $5A
        lda     ObjectState,y
        bpl     LFE4C
        cmp     #$E0
        bcs     LFE4C
        lda     $6F,y
        bne     LFE4C
        lda     #$20
        sta     $0101,y
        lda     #$73
        sta     ObjectState,y
        lda     #$00
        sta     ObjectAttributes,y
LFE4C:  dec     $5A
        bpl     LFE2D
        rts

LFE51:  lda     #$07
        sta     $5A
        lda     #$01
        sta     $030A
LFE5A:  ldy     $5A
        lda     ObjectState,y
        bpl     LFE6F
        cmp     #$E0
        bcs     LFE6F
        lda     #$73
        sta     ObjectState,y
        lda     #$00
        sta     ObjectAttributes,y
LFE6F:  dec     $5A
        lda     $5A
        cmp     #$01
        bne     LFE5A
        rts

LFE78:  cpx     #$02
        bcs     LFE87
        inc     Player1Lives,x
        lda     #$01
        sta     $0304
        sta     $0305
        rts

LFE87:  txa
        pha
        ldx     #$07
LFE8B:  lda     ObjectAttributes,x
        ora     #$03
        eor     #$04
        sta     ObjectAttributes,x
        dex
        cpx     #$01
        bne     LFE8B
        pla
        tax
        rts

LFE9B:  lda     #$63
        cpx     #$02
        bcs     LFEA4
        sta     $0101,x
LFEA4:  sta     ObjectAttributes,x
        rts

LFEA7:  lda     #$FF
        sta     $0170,x
        rts

LFEAD:  lda     #$07
        sta     $5A
LFEB1:  ldx     $5A
        lda     $0170,x
        nop
        nop
        beq     LFEC9
        txa
        sta     $04
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        lda     #$63
        sta     $53
        jsr     LDA7B
LFEC9:  dec     $5A
        bpl     LFEB1
        jsr     LBF80
        lda     MenuSelection
        beq     LFF04
        lda     Player2Lives
        beq     LFEEF
        cmp     #$02
        bcc     LFF04
        lda     Player1Lives
        bne     LFF04
        lda     Joy1Held
        and     #$01
        beq     LFF04
        inc     Player1Lives
        dec     Player2Lives
        ldx     #$00
        jmp     LE363

LFEEF:  lda     Player1Lives
        cmp     #$02
        bcc     LFF04
        lda     Joy2Held
        and     #$01
        beq     LFF04
        inc     Player2Lives
        dec     Player1Lives
        ldx     #$01
        jmp     LE363

LFF04:  rts

LFF05:  pha
        nop
        nop
        nop
        nop
        nop
        ldx     $5A
        lda     $0170,x
        nop
        nop
        nop
        beq     LFF1D
        pla
        cmp     #$12
        bne     LFF1E
LFF1A:  jmp     LDCDF

LFF1D:  pla
LFF1E:  cmp     #$20
        bcs     LFF1A
        jmp     LDD11

LFF25:  pha
        nop
        nop
        nop
        nop
        nop
        ldx     $5A
        lda     $0170,x
        nop
        nop
        nop
        beq     LFF3D
        pla
        cmp     #$12
        bne     LFF3E
LFF3A:  jmp     LDD04

LFF3D:  pla
LFF3E:  cmp     #$20
        bcs     LFF3A
        jmp     LDD11

LFF45:  lda     #$00
        ldx     #$0F
LFF49:  sta     $0170,x
        dex
        bpl     LFF49
        jsr     LD491
        rts

LFF53:  sta     $0174
        sta     $0175
        sta     $0176
        sta     $0177
        sta     $0178
        jsr     LD491
        rts
LFF66:  lda     $0170,x
        beq     LFF73
        lda     #$00
        sta     $0170,x
        jmp     LE77A

LFF73:  lda     $0101,x
        cmp     #$63
        beq     LFF81
        lda     #$73
        sta     ObjectState,x
        jmp     LE763

LFF81:  lda     #$01
        sta     $030E
        lda     #$40
        sta     $0101,x
        sta     $0178,x
        sta     ObjectAttributes,x
        jmp     LE77A

LFF93:  lda     #$01
        sta     $0307
        lda     $46
        bmi     LFF9F
        lda     #$00
        rts

LFF9F:  lda     #$20
        rts

        .byte   $01
LFFA3:  sta     ObjectAttributes,x
        jmp     LE77A
LFFA8:  lda     ObjectState,x
        cmp     #$73
        bne     LFFB3
        lda     #$00
        sta     $0170,x
LFFB3:  dec     $5A
        bpl     LFFB8
        rts

LFFB8:  jmp     LE710

LFFBB:  lda     #$00
        sta     $0170,x
        rts
LFFC1:  lda     $46
        bmi     LFFCC
        lda     ObjectAttributes,x
        and     #$F0
        jmp     LE0C0

LFFCC:  lda     ObjectAttributes,x
        and     #$08
        beq     LFFD5
        jmp     LE0D3

LFFD5:  lda     ObjectAttributes,x
        and     #$F0
        beq     LFFF0
        cmp     #$A0
        bcs     LFFE7
        cmp     #$60
        beq     LFFEC
        and     #$80
        bne     LFFF0
LFFE7:  lda     #$01
        sta     $D6,x
        rts

LFFEC:  lda     #$03
        sta     $D6,x
LFFF0:  rts

        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF

        .word   NmiHandler
        .word   ResetHandler
        .word   ResetHandler

