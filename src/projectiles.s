UpdateProjectiles:
LE02E:  lda     #$09
        sta     $5A
LE032:  ldx     $5A
        jsr     DispatchProjectileLogic
        dec     $5A
        bpl     LE032
        rts

DispatchProjectileLogic:
LE03C:  lda     ProjectileState,x
        lsr     a
        lsr     a
        lsr     a
        and     #$FE
        tay
        lda     ProjectileLogicHandlers,y
        sta     ScratchPtrLo
        lda     ProjectileLogicHandlers+1,y
        sta     ScratchPtrHi
        jmp     (ScratchPtrLo)

ProjectileLogicState4:
        lda     ProjectileState,x
        and     #$03
        tay
        jsr     LE063
        lda     ProjectileFlags,x
        and     #$01
        beq     LE062
        jsr     LE063
LE062:  rts

LE063:  lda     DirectionDeltaX,y
        asl     a
        clc
        adc     ProjectileX,x
        sta     ProjectileX,x
        lda     DirectionDeltaY,y
        asl     a
        clc
        adc     ProjectileY,x
        sta     ProjectileY,x
        rts

ProjectileLogicStates1To3:
        dec     ProjectileState,x
        lda     ProjectileState,x
        and     #$0F
        bne     LE08B
        lda     ProjectileState,x
        and     #$F0
        sec
        sbc     #$10
        beq     LE089
        ora     #$03
LE089:  sta     ProjectileState,x
LE08B:  rts

LE08C:  lda     ProjectileState,x
        bne     LE0D7
        cpx     #$02
        bcs     LE099
        lda     #$01
        sta     $030F
LE099:  lda     ObjectState,x
        and     #$03
        tay
        ora     #$40
        sta     ProjectileState,x
        lda     DirectionDeltaX,y
        asl     a
        asl     a
        asl     a
        clc
        adc     ObjectX,x
        sta     ProjectileX,x
        lda     DirectionDeltaY,y
        asl     a
        asl     a
        asl     a
        clc
        adc     ObjectY,x
        sta     ProjectileY,x
        lda     #$00
        sta     ProjectileFlags,x
        jmp     LFFC1

        .byte   $F0
LE0C0:
        beq     LE0D7
        cmp     #$C0
        beq     LE0CE
        cmp     #$60
        beq     LE0D3
        and     #$80
        bne     LE0D7
LE0CE:  lda     #$01
        sta     ProjectileFlags,x
        rts

LE0D3:  lda     #$03
        sta     ProjectileFlags,x
LE0D7:  rts

DrawProjectiles:
LE0D8:  lda     #$09
        sta     $5A
LE0DC:  ldx     $5A
        jsr     DispatchProjectileDraw
        dec     $5A
        bpl     LE0DC
        rts

DispatchProjectileDraw:
LE0E6:  lda     ProjectileState,x
        lsr     a
        lsr     a
        lsr     a
        and     #$FE
        tay
        lda     ProjectileDrawHandlers,y
        sta     ScratchPtrLo
        lda     ProjectileDrawHandlers+1,y
        sta     ScratchPtrHi
        jmp     (ScratchPtrLo)

ProjectileDrawState4:
        lda     ProjectileState,x
        and     #$03
        pha
        ldy     ProjectileY,x
        lda     ProjectileX,x
        tax
        lda     #$02
        sta     $04
        lda     #$B1
        sta     $53
        pla
        jsr     LDA64
        rts

ProjectileDrawStates1To3:
        lda     ProjectileState,x
        pha
        ldy     ProjectileY,x
        lda     ProjectileX,x
        tax
        pla
        clc
        adc     #$40
        jsr     LDEE2
        rts

LE122:  lda     #$01
        sta     $5A
LE126:  ldx     $5A
        lda     ObjectState,x
        bpl     LE15D
        cmp     #$E0
        bcs     LE15D
        jmp     LC019

        .byte   $03,$F0,$27
LE136:  lda     ObjectAttributes,x
        and     #$C0
        cmp     #$40
        bne     LE15A
        lda     ProjectileState,x
        beq     LE15A
        lda     $D4,x
        bne     LE15D
        lda     ProjectileState,x
        sta     $D4,x
        lda     ProjectileX,x
        sta     $C0,x
        lda     ProjectileY,x
        sta     $CA,x
        lda     ProjectileFlags,x
        sta     $DE,x
        lda     #$00
        sta     ProjectileState,x
LE15A:  jsr     LE08C
LE15D:  dec     $5A
        bpl     LE126
        rts

LE162:  lda     $0100
        bne     LE180
        ldx     #$07
LE169:  lda     ObjectState,x
        bpl     LE17B
        cmp     #$E0
        bcs     LE17B
        jsr     NextRandomByte
        and     #$1F
        bne     LE17B
        jsr     LE08C
LE17B:  dex
        cpx     #$01
        bne     LE169
LE180:  rts

LE181:  lda     #$07
        sta     $5A
LE185:  ldx     $5A
        lda     ObjectState,x
        bpl     LE1EE
        cmp     #$E0
        bcs     LE1EE
        lda     ObjectY,x
        sec
        sbc     #$08
        tay
        lda     ObjectX,x
        sec
        sbc     #$08
        tax
        jsr     LD706
        ldx     $5A
        lda     ScratchPtrLo
        sta     $E0,x
        lda     ScratchPtrHi
        and     #$03
        sta     $E8,x
        ldy     #$21
        cpx     #$02
        bcs     LE1C9
        lda     (ScratchPtrLo),y
        cmp     #$21
        bne     LE1C1
        lda     #$80
        ora     $0103,x
        sta     $0103,x
        jmp     LE1C9

LE1C1:  lda     $0103,x
        and     #$7F
        sta     $0103,x
LE1C9:  jsr     LE1F3
        lda     ObjectX,x
        and     #$07
        bne     LE1DD
        lda     $E8,x
        ora     #$80
        sta     $E8,x
        ldy     #$20
        jsr     LE1F3
LE1DD:  lda     ObjectY,x
        and     #$07
        bne     LE1EE
        lda     $E8,x
        ora     #$40
        sta     $E8,x
        ldy     #$01
        jsr     LE1F3
LE1EE:  dec     $5A
        bpl     LE185
        rts

LE1F3:  lda     (ScratchPtrLo),y
        ora     #$80
        sta     (ScratchPtrLo),y
        rts

LE1FA:  lda     #$07
        sta     $5A
LE1FE:  ldx     $5A
        lda     ObjectState,x
        bpl     LE22F
        cmp     #$E0
        bcs     LE22F
        lda     $E0,x
        sta     ScratchPtrLo
        lda     $E8,x
        and     #$03
        ora     #$04
        sta     ScratchPtrHi
        ldy     #$21
        jsr     LE234
        lda     $E8,x
        and     #$80
        beq     LE224
        ldy     #$20
        jsr     LE234
LE224:  lda     $E8,x
        and     #$40
        beq     LE22F
        ldy     #$01
        jsr     LE234
LE22F:  dec     $5A
        bpl     LE1FE
        rts

LE234:  lda     (ScratchPtrLo),y
        and     #$7F
        sta     (ScratchPtrLo),y
        rts

LE23B:  lda     $86
        beq     LE27B
        lda     $62
        beq     LE259
        dec     $62
        bne     LE24E
        lda     #$00
        sta     $86
        jmp     LE27B

LE24E:  lda     #$02
        sta     $04
        lda     #$3B
        sta     $53
        jmp     LE26C

LE259:  lda     FrameCounter
        and     #$08
        beq     LE27B
        lda     #$02
        sta     $04
        lda     $88
        asl     a
        asl     a
        clc
        adc     #$81
        sta     $53
LE26C:  ldx     $86
        ldy     $87
        lda     #$00
        sta     $6E
        jsr     LDA7B
        lda     #$20
        sta     $6E
LE27B:  rts

LE27C:  lda     #$01
        sta     $5A
LE280:  ldx     $5A
        lda     $89,x
        beq     LE2A4
        lda     FrameCounter
        and     #$3F
        bne     LE28E
        dec     $89,x
LE28E:  lda     #$02
        sta     $04
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        lda     FrameCounter
        and     #$02
        asl     a
        clc
        adc     #$29
        sta     $53
        jsr     LDA7B
LE2A4:  dec     $5A
        bpl     LE280
        rts

LE2A9:  lda     $45
        beq     LE2D2
        lda     FrameCounter
        and     #$0F
        bne     LE2D2
        lda     FrameCounter
        and     #$3F
        bne     LE2BD
        dec     $45
        beq     LE2CF
LE2BD:  lda     $45
        cmp     #$04
        bcs     LE2D2
        lda     FrameCounter
        and     #$10
        beq     LE2CF
        jsr     LCB9E
        jmp     LE2D2

LE2CF:  jsr     LCAF5
LE2D2:  lda     $68
        beq     LE305
        bmi     LE305
        lda     #$03
        sta     $04
        dec     $68
        lda     $68
        lsr     a
        lsr     a
        sec
        sbc     #$05
        bpl     LE2EC
        eor     #$FF
        clc
        adc     #$01
LE2EC:  sec
        sbc     #$05
        bpl     LE2F6
        eor     #$FF
        clc
        adc     #$01
LE2F6:  asl     a
        tay
        lda     LE306,y
        sta     ScratchPtrLo
        lda     LE306+1,y
        sta     ScratchPtrHi
        jmp     (ScratchPtrLo)

LE305:  rts

BaseExplosionFrameHandlers:
LE306:  .word   NoOpHandler, LE312, LE317, LE31C, LE32E, LE336

LE312:  lda     #$F1
        jmp     LE31E

LE317:  lda     #$F5
        jmp     LE31E

LE31C:  lda     #$F9
LE31E:  ldx     #$78
        ldy     #$D8
LE322:  sta     $53
        jsr     LDA7B
        rts

LE328:  clc
        adc     $69
        jmp     LE322

LE32E:  lda     #$00
        sta     $69
        jsr     LE33E
        rts

LE336:  lda     #$10
        sta     $69
        jsr     LE33E
        rts

LE33E:  ldx     #$70
        ldy     #$D0
        lda     #$D1
        jsr     LE328
        ldx     #$80
        ldy     #$D0
        lda     #$D5
        jsr     LE328
        ldx     #$70
        ldy     #$E0
        lda     #$D9
        jsr     LE328
        ldx     #$80
        ldy     #$E0
        lda     #$DD
        jsr     LE328
        rts
LE363:  lda     #$00
        sta     ObjectAttributes,x
        cpx     #$02
        bcs     LE37C
        lda     LE47A,x
        sta     ObjectX,x
        lda     LE47C,x
        sta     ObjectY,x
        lda     #$00
        sta     $6F,x
        jmp     LE393

LE37C:  inc     $6A
        ldy     $6A
        cpy     #$03
        bne     LE389
        lda     #$00
        sta     $6A
        tay
LE389:  lda     LE474,y
        sta     ObjectX,x
        lda     LE477,y
        sta     ObjectY,x
LE393:  lda     #$F0
        sta     ObjectState,x
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        lda     #$0F
        jsr     DrawMetatile
        rts

        .byte   $04
LE3A3:  sta     ObjectAttributes,x
        lda     #$00
        sta     $86
        lda     #$F0
        sta     ObjectState,x
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        lda     #$0F
        jsr     DrawMetatile
        rts

PowerUpEffect1:
LE3B8:  cpx     #$02
        bcs     LE3C2
        lda     #$0A
        sta     $0100
        rts

LE3C2:  lda     #$C8
        sta     $6F
        sta     $70
        rts
LE3C9:  lda     $46
        bpl     LE3CF
        lda     #$20
LE3CF:  and     #$20
        sta     $0101
        sta     $0102
        rts

LE3D8:  lda     #$E5
        sta     AuxPtrHi
        lda     $46
        asl     a
        bcc     LE3E4
        clc
        adc     #$0E
LE3E4:  asl     a
        asl     a
        clc
        adc     #$70
        sta     AuxPtrLo
        jsr     LD8D2
        rts

LE3EF:  lda     #$73
        sta     ObjectState,x
        lda     #$00
        sta     $0170,x
        rts

        .byte   $03
LE3FA:  ora     ObjectAttributes,x
        cmp     #$E7
        bne     LE402
        lda     #$E4
LE402:  sta     ObjectAttributes,x
        lda     #$00
        sta     ObjectFrame,x
        rts
ClearProjectileStates:
LE409:  ldx     #$09
        lda     #$00
LE40D:  sta     ProjectileState,x
        dex
        bpl     LE40D
        rts

ClearTankStates:
LE413:  lda     #$00
        ldx     #$07
LE417:  sta     ObjectState,x
        sta     $0103,x
        dex
        bpl     LE417
        rts

; Заменяет старшую тетраду ObjectState, сохраняя направление в младшей.
SetTankStateClass:
LE420:  sta     $00
        lda     ObjectState,x
        and     #$0F
        ora     $00
        sta     ObjectState,x
        rts

; Для режимов 0-5 доступны группы по 12 классических карт; режим 6
; использует все 36. Последний $8B не входит в семь описателей.
ClassicLevelSetDescriptors:
LE42B:  .word   ClassicLevels
        .byte   12
        .word   ClassicLevels + 12 * 91
        .byte   12
        .word   ClassicLevels + 24 * 91
        .byte   12
        .word   ClassicLevels
        .byte   12
        .word   ClassicLevels + 12 * 91
        .byte   12
        .word   ClassicLevels + 24 * 91
        .byte   12
        .word   ClassicLevels
        .byte   36
        .byte   $8B
LE441:  lda     $E579,y
        sta     $8C
        lda     $E57A,y
        sta     $8D
        lda     $E57B,y
        sta     $8E
        rts
; Преобразует первый установленный бит Right/Left/Down/Up в направление 3/1/2/0.
DecodeDirectionButtons:
LE451:  asl     a
        bcc     LE457
        lda     #DIRECTION_RIGHT
        rts

LE457:  asl     a
        bcc     LE45D
        lda     #DIRECTION_LEFT
        rts

LE45D:  asl     a
        bcc     LE463
        lda     #DIRECTION_DOWN
        rts

LE463:  asl     a
        bcc     LE469
        lda     #DIRECTION_UP
        rts

LE469:  lda     #$FF
        rts

DirectionDeltaX:
LE46C:  .byte   0,$FF,0,1
DirectionDeltaY:
LE470:  .byte   $FF,0,1,0
LE474:  .byte   $18,$78,$D8
LE477:  .byte   $18,$18,$18
LE47A:  .byte   $58,$98
LE47C:  .byte   $D8,$D8
LE47E:  .byte   $A0,$A0,$A2,$A2,$A2,$A2,$A2,$A2
LE486:  .byte   $A0,$A0,$A0,$A1,$A0,$A3,$A2,$A2
        .byte   $A2,$A1,$A0,$A3,$A1,$A0,$A3,$A1
        .byte   $A2,$A3

; Таблицы адресов обработчиков состояний объекта. Индекс задаётся младшими
; битами ObjectState; таблица выбирается фазой игрового автомата.
; Таблицы индексируются удвоенной старшей тетрадой байта состояния.
TankLogicHandlers:
LE498:  .word   TankLogicState0
        .word   TankLogicStates1To7,TankLogicStates1To7,TankLogicStates1To7
        .word   TankLogicStates1To7,TankLogicStates1To7,TankLogicStates1To7,TankLogicStates1To7
        .word   TankLogicState8,TankLogicState9,TankLogicStateA,TankLogicStateB
        .word   TankLogicStateC,TankLogicStateD,TankLogicStateE,TankLogicStateF
TankDrawHandlers:
LE4B8:  .word   TankDrawState0,DrawTankState1,DrawTankState2
        .word   DrawTankStates3To4,DrawTankStates3To4
        .word   DrawTankStates5To7,DrawTankStates5To7,DrawTankStates5To7
        .word   DrawTankStates8ToD,DrawTankStates8ToD,DrawTankStates8ToD
        .word   DrawTankStates8ToD,DrawTankStates8ToD,DrawTankStates8ToD
        .word   DrawTankStatesEToF,DrawTankStatesEToF
ProjectileLogicHandlers:
LE4D8:  .word   ProjectileLogicState0
        .word   ProjectileLogicStates1To3,ProjectileLogicStates1To3,ProjectileLogicStates1To3
        .word   ProjectileLogicState4
ProjectileDrawHandlers:
LE4E2:  .word   ProjectileDrawState0
        .word   ProjectileDrawStates1To3,ProjectileDrawStates1To3,ProjectileDrawStates1To3
        .word   ProjectileDrawState4

; Заполняет начальное состояние объекта. Для врагов дополнительные свойства
; (тип, бонусный флаг и скорость) выбираются псевдослучайно.
InitializeTankState:
LE4EC:  lda     LE47E,x
        sta     ObjectState,x
        cpx     #$02
        bcs     LE505
        lda     #$03
        sta     $89,x
        lda     $0101,x
        ora     ObjectAttributes,x
        sta     ObjectAttributes,x
        lda     #$00
        sta     ObjectFrame,x
        rts

LE505:  jsr     NextRandomByte
        and     #$03
        tay
        lda     LC5A9,y
        ora     ObjectAttributes,x
        sta     ObjectAttributes,x
        lda     StageNumber
        cmp     #$0C
        bcc     LE520
        jsr     NextRandomByte
        and     #$03
        jmp     LE525

LE520:  jsr     NextRandomByte
        and     #$07
LE525:  tay
        lda     LC5BF,y
        ora     ObjectAttributes,x
        sta     ObjectAttributes,x
        lda     StageNumber
        cmp     #$0C
        bcc     LE53B
        jsr     NextRandomByte
        and     #$07
        jmp     LE540

LE53B:  jsr     NextRandomByte
        and     #$03
LE540:  tay
        lda     LC5AD,y
        ora     ObjectAttributes,x
        sta     ObjectAttributes,x
        lda     #$00
        sta     ObjectFrame,x
        rts

        .byte   $E0,$A0
LE54F:  lda     $8056,y
        ora     ObjectAttributes,x
        sta     ObjectAttributes,x
        lda     #$00
        sta     ObjectFrame,x
        rts
LE55B:  lda     #$07
        cmp     $46
        bcc     LE563
        lda     #$01
LE563:  sta     $49
        jmp     LE97E

LE568:  cpx     #$02
        bcs     LE56F
        jsr     LD9BE
LE56F:  rts

        .byte   $54,$41,$4E,$4B,$20,$41,$FF,$FF
        .byte   $54,$41,$4E,$4B,$20,$42,$FF,$FF
        .byte   $54,$41,$4E,$4B,$20,$43,$FF,$FF
        .byte   $54,$41,$4E,$4B,$20,$44,$FF,$FF
        .byte   $54,$41,$4E,$4B,$20,$45,$FF,$FF
        .byte   $54,$41,$4E,$4B,$20,$46,$FF,$FF
        .byte   $54,$41,$4E,$4B,$20,$47,$FF,$FF
        .byte   $54,$41,$4E
        .byte   $4B,$20,$48,$FF,$FF,$54,$41,$4E
        .byte   $4B,$20,$49,$FF,$FF,$54,$41,$4E
        .byte   $4B,$20,$4A,$FF,$FF,$54,$41,$4E
        .byte   $4B,$20,$4B,$FF,$FF,$54,$41,$4E
        .byte   $4B,$20,$4C,$FF,$FF,$54,$41,$4E
        .byte   $4B,$20,$4D,$FF,$FF,$54,$41,$4E
        .byte   $4B,$20,$4E,$FF,$FF,$31,$39,$39
        .byte   $30,$FF,$01,$0F,$02,$00,$00,$C8
        .byte   $CA,$00,$00,$FF,$5C,$5C,$5C,$5C
        .byte   $5C,$5C,$5C,$5C,$5C,$5C,$5C,$5C
        .byte   $5C,$5C,$5C,$5C,$5C,$5C,$5C,$5C
        .byte   $FF
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
