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
