LDB0B:  lda     $0311
        beq     LDB24
        ldx     #$00
        jsr     LDB38
        bne     LDB37
        ldx     #$01
        jsr     LDB38
        bne     LDB37
        lda     #$00
        sta     $0311
        rts

LDB24:  ldx     #$00
        jsr     LDB38
        bne     LDB32
        ldx     #$01
        jsr     LDB38
        beq     LDB37
LDB32:  lda     #$01
        sta     $0311
LDB37:  rts

LDB38:  lda     Joy1Held,x
        and     #BUTTON_DIRECTIONS
        beq     LDB45
        lda     ObjectState,x
        beq     LDB45
        lda     #$01
        rts

LDB45:  lda     #$00
        rts

LDB48:  lda     $82
        beq     LDB4F
        dec     $82
        rts

LDB4F:  lda     $7F
        beq     LDB74
        lda     GameMode
        sta     $5A
LDB57:  ldx     $5A
        lda     ObjectState,x
        bne     LDB6C
        lda     $84
        sta     $82
        jsr     LE363
        dec     $7F
        lda     $7F
        jsr     LC8B1
        rts

LDB6C:  dec     $5A
        lda     $5A
        cmp     #$01
        bne     LDB57
LDB74:  rts

LDB75:  lda     FrameCounter
        and     #$01
        bne     LDB81
        lda     FrameCounter
        and     #$03
        bne     LDBF0
LDB81:  ldx     #$01
LDB83:  lda     ObjectState,x
        bpl     LDBED
        cmp     #$E0
        bcs     LDBED
        lda     $6F,x
        beq     LDB94
        dec     $6F,x
        jmp     LDBA6

LDB94:  lda     $0103,x
        bpl     LDB9D
        and     #$10
        bne     LDBA6
LDB9D:  lda     Joy1Held,x
        jsr     DecodeDirectionButtons
        sta     $00
        bpl     LDBB4
LDBA6:  lda     #$80
        jsr     SetTankStateClass
        lda     #$08
        ora     ObjectState,x
        sta     ObjectState,x
        jmp     LDBED

LDBB4:  lda     $0103,x
        bpl     LDBC7
        and     #$1F
        bne     LDBC7
        lda     #$9C
        sta     $0103,x
        lda     #$01
        sta     $0310
LDBC7:  lda     ObjectState,x
        and     #$03
        cmp     $00
        beq     LDBE7
        eor     #$02
        cmp     $00
        beq     LDBE7
        lda     ObjectX,x
        clc
        adc     #$04
        and     #$F8
        sta     ObjectX,x
        lda     ObjectY,x
        clc
        adc     #$04
        and     #$F8
        sta     ObjectY,x
LDBE7:  lda     $00
        ora     #$A0
        sta     ObjectState,x
LDBED:  dex
        bpl     LDB83
NoOpHandler:
TankLogicState0:
TankDrawState0:
ProjectileLogicState0:
ProjectileDrawState0:
LDBF0:  rts

; Обновляет восемь танков: два слота игроков и шесть слотов противников.
UpdateTanks:
LDBF1:  lda     #$07
        sta     $5A
        lda     $0100
        beq     LDC03
        lda     FrameCounter
        and     #$3F
        bne     LDC03
        dec     $0100
LDC03:  ldx     $5A
        cpx     #$02
        bcs     LDC18
        lda     FrameCounter
        and     #$01
        bne     LDC35
        lda     FrameCounter
        and     #$03
        bne     LDC38
        jmp     LDC35

LDC18:  lda     $0100
        beq     LDC25
        lda     ObjectState,x
        bpl     LDC25
        cmp     #$E0
        bcc     LDC38
LDC25:  lda     ObjectAttributes,x
        and     #$F0
        cmp     #$A0
        beq     LDC35
        lda     $5A
        eor     FrameCounter
        and     #$01
        beq     LDC38
LDC35:  jsr     DispatchTankLogic
LDC38:  dec     $5A
        bpl     LDC03
        rts

; Старшая тетрада ObjectState выбирает обработчик логики танка.
DispatchTankLogic:
LDC3D:  lda     ObjectState,x
        lsr     a
        lsr     a
        lsr     a
        and     #$FE
        tay
        lda     TankLogicHandlers,y
        sta     ScratchPtrLo
        lda     TankLogicHandlers+1,y
        sta     ScratchPtrHi
        jmp     (ScratchPtrLo)

TankLogicState8:
        cpx     #$02
        bcs     LDC6B
        lda     $0103,x
        bpl     LDC6B
        and     #$7F
        beq     LDC6B
        dec     $0103,x
        lda     ObjectFrame,x
        eor     #$04
        sta     ObjectFrame,x
        jmp     LDC97

LDC6B:  lda     ObjectState,x
        sec
        sbc     #$04
        sta     ObjectState,x
        and     #$0C
        bne     LDC7B
        lda     #$A0
        jsr     SetTankStateClass
LDC7B:  rts

TankLogicStateA:
        cpx     #$02
        bcc     LDC97
        lda     ObjectX,x
        and     #$07
        bne     LDC97
        lda     ObjectY,x
        and     #$07
        bne     LDC97
        jsr     NextRandomByte
        and     #$0F
        bne     LDC97
        jsr     LDE72
        rts

LDC97:  lda     ObjectState,x
        and     #$03
        tay
        lda     DirectionDeltaY,y
        asl     a
        asl     a
        asl     a
        sta     $59
        lda     DirectionDeltaY,y
        clc
        adc     ObjectY,x
        sta     $57
        lda     DirectionDeltaX,y
        asl     a
        asl     a
        asl     a
        sta     $58
        lda     DirectionDeltaX,y
        clc
        adc     ObjectX,x
        sta     $56
        clc
        adc     $58
        clc
        adc     $59
        jsr     LDD6E
        tax
        lda     $57
        clc
        adc     $58
        clc
        adc     $59
        jsr     LDD76
        tay
        jsr     LD706
        lda     (ScratchPtrLo),y
        bmi     LDD11
        beq     LDCDF
        jmp     LFF05

        .byte   $EA
LDCDF:  lda     $56
        clc
        adc     $58
        sec
        sbc     $59
        jsr     LDD6E
        tax
        lda     $57
        clc
        adc     $59
        sec
        sbc     $58
        jsr     LDD76
        tay
        jsr     LD706
        lda     (ScratchPtrLo),y
        bmi     LDD11
        beq     LDD04
        jmp     LFF25

        .byte   $EA
LDD04:  ldx     $5A
        lda     $56
        sta     ObjectX,x
        lda     $57
        sta     ObjectY,x
        jmp     LDD29

LDD11:  ldx     $5A
        cpx     #$02
        bcc     LDD29
        jsr     NextRandomByte
        and     #$03
        beq     LDD30
        lda     #$80
        jsr     SetTankStateClass
        lda     #$08
        ora     ObjectState,x
        sta     ObjectState,x
LDD29:  lda     ObjectFrame,x
        eor     #$04
        sta     ObjectFrame,x
        rts

LDD30:  lda     ObjectX,x
        and     #$07
        bne     LDD41
        lda     ObjectY,x
        and     #$07
        bne     LDD41
        lda     #$90
        jsr     SetTankStateClass
LDD41:  lda     ObjectState,x
        eor     #$02
        sta     ObjectState,x
        rts

TankLogicState9:
        jsr     NextRandomByte
        and     #$01
        beq     LDD6A
        jsr     NextRandomByte
        and     #$01
        beq     LDD5E
        lda     ObjectState,x
        clc
        adc     #$01
        jmp     LDD63

LDD5E:  lda     ObjectState,x
        sec
        sbc     #$01
LDD63:  and     #$03
        ora     #$A0
        sta     ObjectState,x
        rts

LDD6A:  jsr     LDE72
        rts

LDD6E:  cmp     $56
        bcc     LDD75
        sec
        sbc     #$01
LDD75:  rts

LDD76:  cmp     $57
        bcc     LDD7D
        sec
        sbc     #$01
LDD7D:  rts

TankLogicStateD:
        lda     ObjectX
        sta     $71
        lda     ObjectY
        sta     $72
        jmp     LDD9C

TankLogicStateC:
        lda     $91
        sta     $71
        lda     $99
        sta     $72
        jmp     LDD9C

TankLogicStateB:
        lda     #$78
        sta     $71
        lda     #$D8
        sta     $72
LDD9C:  jsr     LDDA2
        sta     ObjectState,x
        rts

LDDA2:  lda     $71
        sec
        sbc     ObjectX,x
        jsr     LDAAF
        clc
        adc     #$01
        sta     $64
        lda     $72
        sec
        sbc     ObjectY,x
        jsr     LDAAF
        clc
        adc     #$01
        sta     $65
        asl     a
        clc
        adc     $65
        clc
        adc     $64
        sta     $64
        cpx     #$02
        bcs     LDDD4
        txa
        asl     a
        eor     $0A
        and     #$02
        beq     LDDE4
        jmp     LDDDB

LDDD4:  jsr     NextRandomByte
        and     #$01
        beq     LDDE4
LDDDB:  lda     #$09
        clc
        adc     $64
        tay
        jmp     LDDE6

LDDE4:  ldy     $64
LDDE6:  lda     LE486,y
        rts

TankLogicStates1To7:
        dec     ObjectState,x
        lda     ObjectState,x
        and     #$0F
        bne     LDE45
        lda     ObjectState,x
        sec
        sbc     #$10
        beq     LDE07
        cmp     #$10
        bne     LDE02
        ora     #$06
        jmp     LDE04

LDE02:  ora     #$03
LDE04:  sta     ObjectState,x
        rts

LDE07:  sta     ObjectState,x
        cpx     #$02
        bcs     LDE15
        dec     Player1Lives,x
        beq     LDE18
        jsr     LE363
        rts

LDE15:  dec     $80
        rts

LDE18:  lda     $68
        cmp     #$80
        bne     LDE45
        cpx     #$01
        beq     LDE34
        lda     Player2Lives
        beq     LDE45
        lda     #$03
        sta     $0107
        lda     #$20
        sta     $0105
        jsr     LDE46
        rts

LDE34:  lda     Player1Lives
        beq     LDE45
        lda     #$01
        sta     $0107
        lda     #$C0
        sta     $0105
        jsr     LDE46
LDE45:  rts

LDE46:  lda     #$0D
        sta     $0108
        lda     #$D8
        sta     $0106
        lda     #$00
        sta     FrameCounter
        rts

TankLogicStateF:
        inc     ObjectState,x
        lda     ObjectState,x
        and     #$0F
        cmp     #$0E
        bne     LDE63
        lda     #$E0
        sta     ObjectState,x
LDE63:  rts

TankLogicStateE:
        inc     ObjectState,x
        lda     ObjectState,x
        and     #$0F
        cmp     #$0E
        bne     LDE71
        jsr     InitializeTankState
LDE71:  rts

LDE72:  lda     $84
        lsr     a
        lsr     a
        cmp     $0A
        bcs     LDE7F
        lda     #$B0
        jmp     LDEA2

LDE7F:  lsr     a
        cmp     $0A
        bcc     LDE8E
        jsr     NextRandomByte
        and     #$03
        ora     #$A0
        sta     ObjectState,x
        rts

LDE8E:  lda     ObjectState
        beq     LDE9B
        txa
        and     #$01
        beq     LDEA0
        lda     $A1
        beq     LDEA0
LDE9B:  lda     #$C0
        jmp     LDEA2

LDEA0:  lda     #$D0
LDEA2:  jsr     SetTankStateClass
        rts

; Рисует восемь танков через отдельную таблицу состояний отображения.
DrawTanks:
LDEA6:  lda     #$00
        sta     $5A
LDEAA:  ldx     $5A
        jsr     DispatchTankDraw
        inc     $5A
        lda     $5A
        cmp     #$08
        bne     LDEAA
        rts

DispatchTankDraw:
LDEB8:  lda     ObjectState,x
        lsr     a
        lsr     a
        lsr     a
        and     #$FE
        tay
        lda     TankDrawHandlers,y
        sta     ScratchPtrLo
        lda     TankDrawHandlers+1,y
        sta     ScratchPtrHi
        jmp     (ScratchPtrLo)

DrawTankStates5To7:
        lda     #$00
        sta     $6E
        lda     ObjectState,x
        pha
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        pla
        jsr     LDEE2
        lda     #$20
        sta     $6E
        rts

LDEE2:  lsr     a
        lsr     a
        lsr     a
        lsr     a
        sec
        sbc     #$07
        eor     #$FF
        clc
        adc     #$01
        asl     a
        asl     a
LDEF0:  clc
        adc     #$F1
        sta     $53
        lda     #$03
        sta     $04
        jsr     LDA7B
        rts

DrawTankState1:
        lda     #$00
        sta     $6E
        lda     ObjectAttributes,x
        beq     LDF23
        lda     ObjectAttributes,x
        lsr     a
        lsr     a
        lsr     a
        and     #$FC
        sec
        sbc     #$10
        clc
        adc     #$B9
        sta     $53
        lda     #$03
        sta     $04
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        jsr     LDA7B
        jmp     LDF2E

LDF23:  lda     ObjectY,x
        tay
        lda     ObjectX,x
        tax
        lda     #$00
        jsr     LDEF0
LDF2E:  lda     #$20
        sta     $6E
        rts

DrawTankState2:
        lda     #$00
        sta     $6E
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        lda     #$08
        jsr     LDEF0
        lda     #$20
        sta     $6E
        rts

DrawTankStates3To4:
        lda     #$03
        sta     $04
        lda     #$00
        sta     $6E
        jsr     LDF99
        txa
        sec
        sbc     #$08
        tax
        tya
        sec
        sbc     #$08
        tay
        jsr     LDA7B
        lda     #$01
        jsr     LDF99
        txa
        clc
        adc     #$08
        tax
        tya
        sec
        sbc     #$08
        tay
        jsr     LDA7B
        lda     #$02
        jsr     LDF99
        txa
        sec
        sbc     #$08
        tax
        tya
        clc
        adc     #$08
        tay
        jsr     LDA7B
        lda     #$03
        jsr     LDF99
        txa
        clc
        adc     #$08
        tax
        tya
        clc
        adc     #$08
        tay
        jsr     LDA7B
        lda     #$20
        sta     $6E
        rts

LDF99:  ldx     $5A
        asl     a
        asl     a
        clc
        adc     #$D1
        sta     $00
        lda     ObjectState,x
        and     #$F0
        sec
        sbc     #$30
        eor     #$10
        clc
        adc     $00
        sta     $53
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        rts

DrawTankStates8ToD:
        cpx     #$02
        bcc     LDFDD
        lda     ObjectAttributes,x
        and     #$04
        beq     LDFCD
        lda     FrameCounter
        lsr     a
        lsr     a
        lsr     a
        and     #$01
        clc
        adc     #$02
        jmp     LDFE9

LDFCD:  lda     FrameCounter
        asl     a
        asl     a
        clc
        adc     ObjectAttributes,x
        and     #$07
        tay
        lda     LE003,y
        jmp     LDFE9

LDFDD:  lda     $6F,x
        beq     LDFE8
        lda     FrameCounter
        and     #$08
        beq     LDFE8
        rts

LDFE8:  txa
LDFE9:  sta     $04
        lda     ObjectState,x
        and     #$03
        pha
        lda     ObjectAttributes,x
        and     #$F0
        clc
        adc     ObjectFrame,x
        sta     $53
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        pla
        jsr     LDA73
        rts

LE003:  .byte   $02,$00,$00,$01,$02,$01,$02,$02
DrawTankStatesEToF:
LE00B:  lda     ObjectState,x
        and     #$0F
        sec
        sbc     #$07
        bpl     LE019
        eor     #$FF
        clc
        adc     #$01
LE019:  asl     a
        and     #$FC
        clc
        adc     #$A1
        sta     $53
        lda     #$03
        sta     $04
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        jsr     LDA7B
        rts

; Обновляет десять снарядов, по одному слоту на танк/источник.
