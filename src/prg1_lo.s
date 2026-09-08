; Основная часть исполняемого кода ($C000-$F02F).
; Адресные имена Lxxxx временные и заменяются смысловыми по мере анализа.

.segment        "PRG1_LO": absolute

        .byte   $43,$4F,$50,$59,$52,$49,$47,$48
BootHook:
        jsr     ResetEightByteRecord
        lda     #$AB
        sta     $46
        rts

LC010:  jsr     LD467
        lda     $46
        jsr     LC49C
        rts

LC019:  lda     GameMode
        cmp     #$06
        beq     LC031
        lda     Joy1Pressed,x
        and     #$01
        bne     LC02B
        lda     Joy1Held,x
        and     #$02
        beq     LC02E
LC02B:  jmp     LE136

LC02E:  jmp     LE15D

LC031:  lda     Joy1Pressed,x
        and     #$03
        beq     LC02E
        jmp     LE136

ByteToDecimalDigits:
        lda     $00
LC03C:  cmp     #$64
        bcc     LC048
LC040:  sec
        sbc     #$64
        inc     $39
        jmp     LC03C

LC048:  cmp     #$0A
        bcc     LC054
        sec
        sbc     #$0A
        inc     $3A
        jmp     LC048

LC054:  sta     $3B
        rts

        .byte   $49,$20,$48,$59,$4F,$55,$44,$4F
        .byte   $55,$4A,$55,$4E,$4B,$4F,$20,$4F
        .byte   $5A,$41,$57,$41,$20,$20,$20,$20
        .byte   $20

ResetHandler:
        sei
        lda     #$10
        sta     PPU_CTRL
        cld
        ldx     #$02
LC079:  lda     PPU_STATUS
        bpl     LC079
        lda     #$06
        sta     PPU_MASK
        dex
        bne     LC079
        ldx     #$6F
        txs
        jsr     LFF45
        lda     #$00
        sta     VerticalScroll
        sta     NametableBits
LC092:  jsr     LC010
LC095:  jsr     LD17F
        lda     #$00
        sta     $4B
LC09C:  jsr     LD16A
        jsr     LC7AB
LC0A2:  jsr     TitleScreen
        jsr     LC3B5
        jsr     LC41D
        jmp     LC09C

; Редактор Construction: перемещает курсор, меняет TSA-блок и затем
; возвращается в общий игровой цикл.
ConstructionMode:
LC0AE:  lda     $4B
        bne     LC0BE
        jsr     LD470
        jsr     LC9B0
        jsr     UploadNametableBuffer
        jsr     LD467
LC0BE:  jsr     LE413
        lda     #$10
        sta     ObjectX
        lda     #$18
        sta     ObjectY
        lda     #$84
        sta     ObjectState
        lda     #$00
        sta     ObjectAttributes
        sta     $6E
        sta     ObjectFrame
        sta     $81
        sta     $7B
        sta     $5C
        sta     VerticalScroll
        sta     NametableBits
        sta     $6F
        sta     $70
        lda     $4B
        bne     LC0EA
        jsr     LCAF5
LC0EA:  jsr     WaitForNextFrame
        jsr     LC6D2
        jsr     LC8D0
        lda     FrameCounter
        and     #$10
        beq     LC0FC
        jsr     LDEA6
LC0FC:  lda     Joy1Held
        and     #$F0
        bne     LC13E
        lda     Joy1Pressed
        and     #$01
        beq     LC120
        lda     $81
        bne     LC111
        inc     $81
        jmp     LC144

LC111:  inc     $5C
        lda     $5C
        cmp     #$0E
        bne     LC144
        lda     #$00
        sta     $5C
        jmp     LC144

LC120:  lda     Joy1Pressed
        and     #$02
        beq     LC13E
        lda     $81
        bne     LC12F
        inc     $81
        jmp     LC144

LC12F:  dec     $5C
        lda     $5C
        cmp     #$FF
        bne     LC144
        lda     #$0D
        sta     $5C
        jmp     LC144

LC13E:  lda     Joy1Held
        and     #$03
        beq     LC147
LC144:  jsr     LC6C6
LC147:  lda     Joy1Pressed
        and     #$08
        bne     LC150
        jmp     LC0EA

LC150:  lda     #$20
        sta     $6E
        inc     $4B
        jmp     LC0A2

; Экран выбора этапа. Удержание направления повторяет изменение через
; FrameCounter, START подтверждает StageNumber.
SelectStage:
LC159:  jsr     WaitForNextFrame
        jsr     ResetAudioEngine
        lda     #$1C
        sta     $05
        lda     #$00
        sta     VerticalScroll
        sta     NametableBits
        sta     $6D
        lda     #$04
        sta     $4D
        jsr     LCC90
LC172:  jsr     UpdateStageNumberDisplay
        lda     $4C
        bne     LC1C5
        lda     Joy1Pressed
        and     #$08
        bne     LC1C5
        lda     Joy1Pressed
        and     #$01
        bne     LC191
        lda     Joy1Held
        and     #$01
        beq     LC1A4
        lda     FrameCounter
        and     #$07
        bne     LC1A4
LC191:  lda     #$00
        sta     FrameCounter
        jsr     AdvanceStageNumber
        nop
        cmp     #$33
        bne     LC172
        lda     #$01
        sta     StageNumber
        jmp     LC172

LC1A4:  lda     Joy1Pressed
        and     #$02
        bne     LC1B6
        lda     Joy1Held
        and     #$02
        beq     LC172
        lda     FrameCounter
        and     #$07
        bne     LC172
LC1B6:  lda     #$00
        sta     FrameCounter
        dec     StageNumber
        bne     LC172
        jsr     LC627
        nop
        jmp     LC172

LC1C5:  lda     #$01
        sta     $0301
        sta     $0302
        sta     $0303
        lda     $4B
        bne     LC1E2
        jsr     LC9B0
        lda     StageNumber
        jsr     LEF76
        jsr     LCAF5
        jmp     LC1E5

LC1E2:  jsr     LCB5D
LC1E5:  lda     #$00
        sta     PpuBufferPos
        jsr     LCC27
        jsr     LCCB2
        lda     #$00
        sta     $4D
        jsr     WaitForNextFrame
        jsr     LC331
LC1F9:  jsr     WaitForNextFrame
        lda     $6D
        bne     LC203
        jsr     LC2E6
LC203:  jsr     LE23B
        jsr     LE0D8
        jsr     LDEA6
        lda     Joy1Pressed
        and     #$08
        beq     LC21B
        lda     #$01
        eor     $6D
        sta     $6D
        sta     $0300
LC21B:  jsr     LC8F9
        jsr     LC728
        beq     LC1F9
        lda     #$00
        sta     $0A
        sta     FrameCounter
        sta     $0311
        sta     $0312
        lda     $0108
        beq     LC238
        lda     #$FE
        sta     $0A
LC238:  jsr     WaitForNextFrame
        jsr     LC2A2
        jsr     LC2E6
        jsr     LE23B
        jsr     LDEA6
        jsr     LE0D8
        jsr     LC31D
        lda     $0A
        cmp     #$02
        bne     LC238
        jsr     ResetAudioEngine
        jsr     LCCD4
        inc     StageNumber
        lda     StageNumber
        cmp     #$FF
        bne     LC265
        lda     #$01
        sta     StageNumber
LC265:  lda     Player1Lives
        clc
        adc     Player2Lives
        beq     LC283
        lda     $68
        cmp     #$80
        bne     LC283
        jmp     LFD64

LC275:  clc
        adc     Player2Lives
        beq     LC283
        lda     $68
        cmp     #$80
        bne     LC283
        jmp     SelectStage
LC283:  jsr     LC5D9
        jsr     LD97D
        tya
        beq     LC292
        jsr     LC44B
        jsr     LC295
LC292:  jmp     LC095

LC295:  jsr     LD470
        jsr     ClearNametableBuffer
        jsr     UploadNametableBuffer
        jsr     LD467
        rts

LC2A2:  lda     $68
        cmp     #$80
        beq     LC2B2
        lda     #$00
        sta     Joy1Held
        sta     Joy2Held
        sta     Joy1Pressed
        sta     Joy2Pressed
LC2B2:  rts

; Сбрасывает записи двух игроков и общие счётчики новой игровой сессии.
InitializeGameSession:
LC2B3:  ldx     #$15
        jsr     ResetEightByteRecord
        ldx     #$1D
        jsr     ResetEightByteRecord
LC2BD:  jsr     LE3C9
        jsr     LD2F8
        lda     #$00
        sta     $66
        sta     $67
        sta     $4C
        jsr     LFD46
        nop
        sta     Player1Lives
        sta     Player2Lives
        sta     $6A
        lda     MenuSelection
        bne     LC2DD
        lda     #$00
        sta     Player2Lives
LC2DD:  lda     #$01
        sta     StageNumber
        nop
        nop
        nop
        nop
        rts

LC2E6:  jsr     LE181
        jsr     LDB75
        jsr     LDBF1
        jsr     LE1FA
        jsr     LE02E
        jsr     LE2A9
        jsr     LE27C
        jsr     LE122
        jsr     LE162
        jsr     LDB48
        jsr     LE604
        jsr     LE910
        jsr     LE70C
        jsr     LE972
        jsr     LC972
        jsr     LDB0B
        jsr     LC7C8
        jmp     LFEAD

        .byte   $60
LC31D:  lda     FrameCounter
        and     #$3F
        beq     LC32C
        cmp     #$20
        bne     LC330
        lda     #$01
        sta     $4D
        rts

LC32C:  lda     #$02
        sta     $4D
LC330:  rts

LC331:  jsr     LE409
        jsr     LE413
        lda     #$F0
        sta     $0106
        lda     #$00
        sta     $0108
        lda     Player1Lives
        beq     LC34A
        ldx     #$00
        jsr     LE363
LC34A:  lda     Player2Lives
        beq     LC353
        ldx     #$01
        jsr     LE363
LC353:  lda     #$14
        sta     $7F
        sta     $80
        lda     #$00
        nop
        nop
        sta     $0A
        sta     $4B
        sta     $45
        sta     $6F
        sta     $70
        sta     $89
        sta     $8A
        sta     $82
        sta     $86
        sta     $0100
        sta     $6A
        jsr     LC71E
        jsr     LC8C0
        jsr     WaitForNextFrame
        jsr     LC830
        jsr     LC859
        nop
        nop
        nop
        lda     #$80
        sta     $68
        lda     #$01
        sta     $0312
        sta     $4C
        lda     StageNumber
        cmp     #$0C
        bcc     LC39C
        lda     #$00
        sta     $84
        rts

LC39C:  lda     #$0C
        sec
        sbc     StageNumber
        sta     $84
        jsr     NextRandomByte
LC3A6:  cmp     $84
        bcc     LC3AE
        sbc     $84
        bcs     LC3A6
LC3AE:  tax
        lda     LC59D,x
        sta     $84
        rts

LC3B5:  lda     #$01
        sta     $6D
        lda     #$00
        sta     $4D
        jsr     LC2BD
        lda     #$03
        sta     Player2Lives
        lda     #$00
        sta     VerticalScroll
        sta     NametableBits
        sta     $0A
        sta     FrameCounter
        jsr     LC9B0
        lda     #$FF
        sta     StageNumber
        jsr     LEF76
        lda     #$1E
        sta     StageNumber
        lda     #$02
        sta     $8F
        jsr     LD470
        ldx     #$1A
        stx     $56
        ldy     #$46
        sty     $57
        jsr     LE3D8
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        ldx     #$3C
        stx     $56
        ldy     #$78
        sty     $57
        lda     #$E5
        sta     AuxPtrHi
        lda     #$E0
        sta     AuxPtrLo
        jsr     LD8D2
        jsr     UploadNametableBuffer
        jsr     LD467
        jsr     LC331
        jsr     LCAF5
        jsr     WaitForNextFrame
        lda     #$05
        sta     GameMode
        rts

LC41D:  jsr     WaitForNextFrame
        lda     Joy1Pressed
        and     #$0C
        bne     LC43F
        jsr     LC642
        jsr     LC2E6
        jsr     LE23B
        jsr     LDEA6
        jsr     LE0D8
        jsr     LC728
        beq     LC41D
        lda     #$00
        sta     PpuBufferPos
        rts

LC43F:  pla
        pla
        lda     #$00
        sta     PpuBufferPos
        jsr     LD16A
        jmp     LC0A2

LC44B:  jsr     LD470
        lda     #$1C
        sta     $05
        lda     #$00
        sta     VerticalScroll
        sta     NametableBits
        jsr     ClearNametableBuffer
        ldx     #$10
        stx     $56
        ldy     #$32
        sty     $57
        lda     #$D2
        sta     AuxPtrHi
        lda     #$B5
        sta     AuxPtrLo
        jsr     LD8D2
        jsr     LD951
        jsr     UploadNametableBuffer
        jsr     LD467
        lda     #$00
        sta     $0A
        lda     #$01
        sta     $0315
        sta     $0316
        sta     $0317
LC486:  jsr     WaitForNextFrame
        lda     FrameCounter
        and     #$03
        clc
        adc     #$05
        sta     $4D
        lda     $0315
        bne     LC486
        lda     #$00
        sta     $4D
        rts

LC49C:  cmp     #$AB
        beq     LC4A1
        rts

LC4A1:  lda     #$80
        sta     $46
        jsr     LD470
        lda     #$1C
        sta     $05
        lda     #$00
        sta     VerticalScroll
        sta     NametableBits
        jsr     ClearNametableBuffer
        jsr     UploadNametableBuffer
        jsr     LD467
        lda     #$C5
        sta     ScratchPtrHi
        lda     #$C9
        sta     ScratchPtrLo
        ldy     #$03
        ldx     #$07
        jsr     QueueTileAtCoordinates
        lda     #$E5
        sta     ScratchPtrHi
        lda     #$EF
        sta     ScratchPtrLo
        ldy     #$04
        ldx     #$07
        jsr     QueueTileAtCoordinates
        lda     #$E5
        sta     ScratchPtrHi
        lda     #$EF
        sta     ScratchPtrLo
        ldy     #$01
        ldx     #$07
        jsr     QueueTileAtCoordinates
        lda     #$01
        sta     $8E
        jsr     LFD0C
        lda     #$40
        sta     $4B
        lda     #$00
        sta     MenuSelection
        sta     $4A
LC4F9:  lda     #$E8
        sta     ScratchPtrHi
        lda     $4B
        sta     ScratchPtrLo
        clc
        adc     #$08
        sta     $4B
        lda     $4A
        clc
        adc     #$09
        tay
        ldx     #$0D
        jsr     QueueTileAtCoordinates
        jsr     WaitForNextFrame
        inc     $4A
        lda     $4A
        cmp     #$0E
        bcc     LC4F9
LC51C:  lda     #$D3
        sta     ScratchPtrHi
        lda     #$B3
        sta     ScratchPtrLo
        jsr     LFD27
LC527:  lda     Joy1Held
        and     #$20
        beq     LC545
        jsr     LC579
        inc     $46
        lda     $46
        cmp     #$07
        bne     LC53A
        lda     #$80
LC53A:  cmp     #$87
        bne     LC540
        lda     #$00
LC540:  sta     $46
        jmp     LC51C

LC545:  lda     Joy1Held
        and     #$10
        beq     LC563
        jsr     LC579
        dec     $46
        lda     $46
        cmp     #$FF
        bne     LC558
        lda     #$86
LC558:  cmp     #$7F
        bne     LC55E
        lda     #$06
LC55E:  sta     $46
        jmp     LC51C

LC563:  lda     Joy1Pressed
        and     #$04
        beq     LC572
        lda     $8E
        eor     #$01
        sta     $8E
        jsr     LFD0C
LC572:  lda     Joy1Pressed
        and     #$08
        beq     LC527
        rts

LC579:  lda     #$00
        sta     FrameCounter
LC57D:  jsr     WaitForNextFrame
        lda     FrameCounter
        and     #$0F
        bne     LC57D
        lda     #$01
        sta     $030D
        lda     #$E8
        sta     ScratchPtrHi
        lda     #$B2
        sta     ScratchPtrLo
        jsr     LFD27
        rts

LC597:  lda     #$00
        rts
LC59A:  lda     #$00
        rts
LC59D:  .byte   $03,$08,$0D,$12,$17,$1C,$21,$26
        .byte   $2B,$30,$35,$3A
LC5A9:  .byte   $80,$A0,$C0,$E0
LC5AD:  .byte   $02,$00,$01,$00,$01,$00,$01,$00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00
        .byte   $00,$00
LC5BF:  .byte   $04,$04,$00,$00,$00,$00,$00,$00
        .byte   $00,$00,$40,$20,$59,$69,$53,$20
        .byte   $31,$39,$39,$30,$69,$32,$FF,$FF
        .byte   $FF,$FF
LC5D9:  jsr     LD470
        lda     #$1C
        sta     $05
        lda     #$00
        sta     VerticalScroll
        sta     NametableBits
        jsr     ClearNametableBuffer
        jsr     UploadNametableBuffer
        jsr     LD467
        jsr     ResetAudioEngine
        rts

LC5F3:  lda     $8E
        beq     LC5FB
        lda     LE8FA,y
        rts

LC5FB:  lda     LC63A,y
        rts

LC5FF:  cpx     #$02
        bcs     LC610
        lda     $8E
        beq     LC610
        lda     $0178,x
        clc
        adc     #$20
        sta     $0178,x
LC610:  jmp     LFDFB

LC613:  cpx     #$02
        bcs     LC624
        lda     $8E
        beq     LC624
        lda     $0178,x
        clc
        adc     #$60
        sta     $0178,x
LC624:  jmp     LFE9B
LC627:  lda     $46
        and     #$0F
        cmp     #$06
        beq     LC633
        lda     #$32
        bne     LC635
LC633:  lda     #$76
LC635:  sta     StageNumber
        rts

        .byte   $20,$B4
LC63A:  .byte   $00,$01,$02,$03,$03,$04,$05,$06
LC642:  lda     #$01
        sta     $5A
LC646:  ldx     $5A
        lda     $86
        beq     LC65E
        lda     $62
        bne     LC65E
        lda     $86
        sta     $71
        lda     $87
        sta     $72
        jsr     LDDA2
        jmp     LC6A5

LC65E:  lda     $A2,x
        bpl     LC674
        cmp     #$E0
        bcs     LC674
        lda     $92,x
        sta     $71
        lda     $9A,x
        sta     $72
        jsr     LDDA2
        jmp     LC6A5

LC674:  lda     $A4,x
        bpl     LC68A
        cmp     #$E0
        bcs     LC68A
        lda     $94,x
        sta     $71
        lda     $9C,x
        sta     $72
        jsr     LDDA2
        jmp     LC6A5

LC68A:  lda     $A3,x
        bpl     LC6A0
        cmp     #$E0
        bcs     LC6A0
        lda     $93,x
        sta     $71
        lda     $9B,x
        sta     $72
        jsr     LDDA2
        jmp     LC6A5

LC6A0:  lda     #$00
        jmp     LC6AB

LC6A5:  and     #$03
        tay
        lda     LC6C2,y
LC6AB:  ldx     $5A
        sta     Joy1Held,x
        sta     Joy1Pressed,x
        lda     ObjectY,x
        cmp     #$C8
        bcc     LC6BD
        lda     Joy1Pressed,x
        and     #$F0
        sta     Joy1Pressed,x
LC6BD:  dec     $5A
        bpl     LC646
        rts

LC6C2:  .byte   $13,$43,$23,$83
LC6C6:  lda     $5C
        and     #$0F
        ldx     ObjectX
        ldy     ObjectY
        jsr     DrawMetatile
        rts

LC6D2:  lda     Joy1Held
        and     #$F0
        beq     LC6E1
        inc     $7B
        lda     #$00
        sta     $81
        jmp     LC6E5

LC6E1:  lda     #$00
        sta     $7B
LC6E5:  lda     $7B
        cmp     #$14
        beq     LC6FB
        lda     Joy1Pressed
        and     #$F0
        beq     LC71D
        lda     Joy1Pressed
        jsr     LE451
        bmi     LC71D
        jmp     LC704

LC6FB:  lda     #$0F
        sta     $7B
        lda     Joy1Held
        jsr     LE451
LC704:  tay
        lda     LD3D5,y
        asl     a
        asl     a
        asl     a
        asl     a
        clc
        adc     ObjectX
        sta     ObjectX
        lda     LD3D9,y
        asl     a
        asl     a
        asl     a
        asl     a
        clc
        adc     ObjectY
        sta     ObjectY
LC71D:  rts

LC71E:  ldx     #$07
        lda     #$00
LC722:  sta     $73,x
        dex
        bpl     LC722
        rts

LC728:  lda     $68
        beq     LC737
        lda     $80
        beq     LC74F
        lda     Player1Lives
        clc
        adc     Player2Lives
        bne     LC752
LC737:  lda     #$70
        sta     $0105
        lda     #$F0
        sta     $0106
        lda     #$00
        sta     $0107
        lda     #$11
        sta     $0108
        lda     #$00
        sta     FrameCounter
LC74F:  lda     #$01
        rts

LC752:  lda     #$00
        rts

LC755:  lda     $0109
        jsr     LD9E1
        lda     #$30
        sta     $60
        lda     #$00
        sta     ScratchPtrHi
        lda     #$39
        sta     ScratchPtrLo
        ldx     #$09
        ldy     #$02
        jsr     LD6DD
        ldx     $0109
        lda     $00,x
        jsr     LD9E1
        lda     #$00
        sta     ScratchPtrHi
        lda     #$39
        sta     ScratchPtrLo
        ldx     #$0D
        ldy     #$02
        jsr     LD6DD
        lda     #$00
        sta     $60
        lda     Joy1Pressed
        and     #$04
        beq     LC792
        inc     $0109
LC792:  lda     Joy1Pressed
        and     #$02
        beq     LC79B
        dec     $0109
LC79B:  lda     Joy1Pressed
        and     #$01
        beq     LC7AA
        lda     $0109
        clc
        adc     #$10
        sta     $0109
LC7AA:  rts
LC7AB:  lda     #$00
        sta     VerticalScroll
        sta     NametableBits
LC7B1:  jsr     WaitForNextFrame
        inc     VerticalScroll
        lda     Joy1Pressed
        and     #$0C
        bne     LC7C3
        lda     VerticalScroll
        cmp     #$F0
        bne     LC7B1
        rts

LC7C3:  pla
        pla
        jmp     LC0A2

LC7C8:  lda     #$01
        sta     $5A
        sta     $6B
        lda     #$6E
        sta     $60
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$41
        sta     ScratchPtrLo
        ldx     #$1D
        ldy     #$12
        jsr     QueueTileAtCoordinates
        lda     $8F
        cmp     #$02
        beq     LC7F2
        lda     MenuSelection
        bne     LC7F2
        lda     #$00
        sta     $5A
        jmp     LC801

LC7F2:  lda     #$D3
        sta     ScratchPtrHi
        lda     #$41
        sta     ScratchPtrLo
        ldx     #$1D
        ldy     #$15
        jsr     QueueTileAtCoordinates
LC801:  ldx     $5A
        lda     Player1Lives,x
        sec
        sbc     #$01
        bpl     LC80C
        lda     #$00
LC80C:  jsr     LDA13
        ldy     #$36
        ldx     #$19
        jsr     LD934
        lda     $5A
        sta     $00
        asl     a
        clc
        adc     $00
        clc
        adc     #$12
        tay
        jsr     LD6DD
        dec     $5A
        bpl     LC801
        lda     #$00
        sta     $60
        sta     $6B
        rts

LC830:  lda     #$D2
        sta     ScratchPtrHi
        lda     #$AB
        sta     ScratchPtrLo
        ldx     #$1D
        ldy     #$11
        jsr     QueueTileAtCoordinates
        lda     $8F
        cmp     #$02
        beq     LC849
        lda     MenuSelection
        beq     LC858
LC849:  lda     #$D2
        sta     ScratchPtrHi
        lda     #$AE
        sta     ScratchPtrLo
        ldx     #$1D
        ldy     #$14
        jsr     QueueTileAtCoordinates
LC858:  rts

LC859:  jsr     WaitForNextFrame
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$65
        sta     ScratchPtrLo
        ldx     #$1D
        ldy     #$17
        jsr     QueueTileAtCoordinates
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$68
        sta     ScratchPtrLo
        ldx     #$1D
        ldy     #$18
        jsr     QueueTileAtCoordinates
        lda     #$6E
        sta     $60
        lda     StageNumber
        jsr     LDA13
        ldy     #$36
        ldx     #$19
        jsr     LD934
        ldy     #$19
        jsr     LD6DD
        lda     #$00
        sta     $60
        rts

LC894:  pha
        and     #$01
        clc
        adc     #$1D
        tax
        pla
        lsr     a
        clc
        adc     #$03
        tay
        rts

LC8A2:  jsr     LC894
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$62
        sta     ScratchPtrLo
        jsr     QueueTileAtCoordinates
        rts

LC8B1:  jsr     LC894
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$6B
        sta     ScratchPtrLo
        jsr     QueueTileAtCoordinates
        rts

LC8C0:  lda     #$12
        sta     $5A
LC8C4:  lda     $5A
        jsr     LC8A2
        dec     $5A
        dec     $5A
        bpl     LC8C4
        rts

LC8D0:  lda     ObjectX
        cmp     #$D8
        bcc     LC8DA
        lda     #$D8
        sta     ObjectX
LC8DA:  lda     ObjectX
        cmp     #$18
        bcs     LC8E4
        lda     #$18
        sta     ObjectX
LC8E4:  lda     ObjectY
        cmp     #$D8
        bcc     LC8EE
        lda     #$D8
        sta     ObjectY
LC8EE:  lda     ObjectY
        cmp     #$18
        bcs     LC8F8
        lda     #$18
        sta     ObjectY
LC8F8:  rts

LC8F9:  lda     $6D
        beq     LC946
        lda     FrameCounter
        and     #$10
        beq     LC946
        lda     #$03
        sta     $04
        lda     #$00
        sta     $6E
        ldx     #$64
        ldy     #$80
        lda     #$17
        sta     $53
        jsr     LDA2B
        ldx     #$6C
        ldy     #$80
        lda     #$19
        sta     $53
        jsr     LDA2B
        ldx     #$74
        ldy     #$80
        lda     #$1B
        sta     $53
        jsr     LDA2B
        ldx     #$7C
        ldy     #$80
        lda     #$1D
        sta     $53
        jsr     LDA2B
        ldx     #$84
        ldy     #$80
        lda     #$1F
        sta     $53
        jsr     LDA2B
        lda     #$20
        sta     $6E
LC946:  rts

LC947:  lda     #$03
        sta     $04
        lda     #$00
        sta     $6E
        ldx     $0105
        ldy     $0106
        lda     #$79
        sta     $53
        jsr     LDA7B
        lda     $0105
        clc
        adc     #$10
        tax
        ldy     $0106
        lda     #$7D
        sta     $53
        jsr     LDA7B
        lda     #$20
        sta     $6E
        rts

LC972:  lda     $0108
        beq     LC9AF
        lda     $8F
        cmp     #$02
        beq     LC9AF
        lda     FrameCounter
        and     #$0F
        bne     LC98D
        dec     $0108
        bne     LC98D
        lda     #$F0
        sta     $0106
LC98D:  lda     $0108
        cmp     #$0A
        bcc     LC9AC
        lda     $0107
        tay
        lda     LD3D5,y
        clc
        adc     $0105
        sta     $0105
        lda     LD3D9,y
        clc
        adc     $0106
        sta     $0106
LC9AC:  jsr     LC947
LC9AF:  rts

LC9B0:  lda     #$02
        sta     $56
        sta     $57
        lda     #$1A
        sta     $5A
        sta     $5B
        jsr     LD7CC
        rts

; Главное меню с тремя вариантами: один игрок, два игрока, Construction.
TitleScreen:
LC9C0:  lda     #$03
        sta     $4D
        jsr     LE413
        lda     #$48
        sta     ObjectX
        jsr     UpdateTitleCursor
        lda     #$83
        sta     ObjectState
        lda     #$00
        sta     $0A
        sta     ObjectAttributes
        sta     ObjectFrame
        sta     $6F
        sta     $70
        sta     VerticalScroll
        sta     $4A
        lda     #$02
        sta     NametableBits
LC9E6:  jsr     WaitForNextFrame
        lda     FrameCounter
        and     #$03
        bne     LC9F5
        lda     ObjectFrame
        eor     #$04
        sta     ObjectFrame
LC9F5:  jsr     LDEA6
        lda     Joy1Pressed
        and     #$04
        beq     LCA04
        inc     MenuSelection
        lda     #$00
        sta     $0A
LCA04:  lda     Joy1Held
        and     #$20
        beq     LCA17
        lda     Joy1Pressed
        and     #$01
        beq     LCA17
        lda     #$10
        clc
        adc     $4A
        sta     $4A
LCA17:  lda     Joy1Held
        and     #$80
        beq     LCA25
        lda     Joy1Pressed
        and     #$02
        beq     LCA25
        dec     $4A
LCA25:  lda     MenuSelection
        cmp     #$03
        bcc     LCA2F
        lda     #$00
        sta     MenuSelection
LCA2F:  jsr     UpdateTitleCursor
        lda     $0A
        cmp     #$0A
        bne     LCA3D
        lda     $4B
        bne     LCA3D
        rts

LCA3D:  lda     Joy1Pressed
        and     #$08
        beq     LC9E6
        lda     $4A
        cmp     #$2E
        bne     LCA52
        jsr     LC4A1
        pla
        pla
        jmp     LC092

        .byte   $EA
LCA52:  lda     #$00
        sta     $4D
        pla
        pla
        lda     MenuSelection
        asl     a
        tay
        lda     MenuSelectionHandlers,y
        sta     ScratchPtrLo
        lda     MenuSelectionHandlers+1,y
        sta     ScratchPtrHi
        jmp     (ScratchPtrLo)

MenuSelectionHandlers:
LCA69:  .word   StartOnePlayer, StartTwoPlayers, StartConstruction

StartOnePlayer:
        lda     #$05
        jmp     LCA76

StartTwoPlayers:
        lda     #$07
LCA76:  sta     GameMode
        jsr     InitializeGameSession
        jmp     SelectStage

StartConstruction:
        lda     #$07
        sta     GameMode
        jmp     ConstructionMode

; Преобразует MenuSelection в экранную Y-координату курсора.
UpdateTitleCursor:
LCA85:  lda     MenuSelection
        asl     a
        asl     a
        asl     a
        asl     a
        clc
        adc     #$8B
        sta     ObjectY
        rts

; Формирует PPU-команды для надписи номера выбранного этапа.
UpdateStageNumberDisplay:
LCA91:  jsr     WaitForNextFrame
        ldx     #$0C
        ldy     #$0E
        jsr     LD5FB
        ldx     PpuBufferPos
        clc
        adc     #$1C
        sta     PpuUpdateBuffer,x
        inx
        tya
        sta     PpuUpdateBuffer,x
        inx
        lda     #$23
        sta     PpuUpdateBuffer,x
        inx
        lda     #$24
        sta     PpuUpdateBuffer,x
        inx
        lda     #$25
        sta     PpuUpdateBuffer,x
        inx
        lda     #$26
        sta     PpuUpdateBuffer,x
        inx
        lda     #$27
        sta     PpuUpdateBuffer,x
        inx
        lda     #$11
        sta     PpuUpdateBuffer,x
        inx
        lda     #$11
        sta     PpuUpdateBuffer,x
        inx
        lda     #$FF
        sta     PpuUpdateBuffer,x
        inx
        stx     PpuBufferPos
        lda     #$6E
        sta     $60
        lda     StageNumber
        jsr     LDA13
        ldy     #$36
        ldx     #$0E
        jsr     LD934
        ldy     #$0E
        jsr     LD6DD
        lda     #$00
        sta     $60
        rts

LCAF5:  lda     #$D3
        sta     ScratchPtrHi
        lda     #$6D
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$18
        jsr     QueueTileAtCoordinates
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$74
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$19
        jsr     QueueTileAtCoordinates
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$7B
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$1A
        jsr     QueueTileAtCoordinates
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$82
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$1B
        jsr     QueueTileAtCoordinates

LCB31:
        ldx     PpuBufferPos
        lda     #$23
        sta     PpuUpdateBuffer,x
        inx
        lda     #$F3
        sta     PpuUpdateBuffer,x
        inx
        lda     #$00
        sta     $07F3
        sta     PpuUpdateBuffer,x
        inx
        lda     $07F4
        and     #$CC
        sta     $07F4
        sta     PpuUpdateBuffer,x
        inx
        lda     #$FF
        sta     PpuUpdateBuffer,x
        inx
        stx     PpuBufferPos
        rts

LCB5D:  lda     #$D3
        sta     ScratchPtrHi
        lda     #$A5
        sta     ScratchPtrLo
        ldx     #$0E
        ldy     #$1A
        jsr     QueueTileAtCoordinates
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$A8
        sta     ScratchPtrLo
        ldx     #$0E
        ldy     #$1B
        jsr     QueueTileAtCoordinates
        ldx     PpuBufferPos
        lda     #$23
        sta     PpuUpdateBuffer,x
        inx
        lda     #$F3
        sta     PpuUpdateBuffer,x
        inx
        lda     $07F3
        and     #$3F
        sta     $07F3
        sta     PpuUpdateBuffer,x
        inx
        lda     #$FF
        sta     PpuUpdateBuffer,x
        inx
        stx     PpuBufferPos
        rts

LCB9E:  lda     #$D3
        sta     ScratchPtrHi
        lda     #$89
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$18
        jsr     QueueTileAtCoordinates
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$90
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$19
        jsr     QueueTileAtCoordinates
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$97
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$1A
        jsr     QueueTileAtCoordinates
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$9E
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$1B
        jsr     QueueTileAtCoordinates
        ldx     PpuBufferPos
        lda     #$23
        sta     PpuUpdateBuffer,x
        inx
        lda     #$F3
        sta     PpuUpdateBuffer,x
        inx
        lda     #$3F
        sta     $07F3
        sta     PpuUpdateBuffer,x
        inx
        lda     $07F4
        and     #$CC
        ora     #$33
        sta     $07F4
        sta     PpuUpdateBuffer,x
        inx
        lda     #$FF
        sta     PpuUpdateBuffer,x
        inx
        stx     PpuBufferPos
        rts

LCC08:  lda     #$D3
        sta     ScratchPtrHi
        lda     #$AB
        sta     ScratchPtrLo
        ldx     #$0E
        ldy     #$1A
        jsr     QueueTileAtCoordinates
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$AE
        sta     ScratchPtrLo
        ldx     #$0E
        ldy     #$1B
        jsr     QueueTileAtCoordinates
        rts

LCC27:  ldy     #$00
        lda     #$23
        sta     ScratchPtrHi
        lda     #$C0
        sta     ScratchPtrLo
LCC31:  jsr     WaitForNextFrame
        ldx     PpuBufferPos
        lda     ScratchPtrHi
        sta     PpuUpdateBuffer,x
        inx
        lda     ScratchPtrLo
        sta     PpuUpdateBuffer,x
        inx
        lda     $07C0,y
        iny
        sta     PpuUpdateBuffer,x
        inx
        lda     #$FF
        sta     PpuUpdateBuffer,x
        inx
        stx     PpuBufferPos
        lda     #$01
        jsr     AddAToPointer
        cpy     #$40
        bne     LCC31
        rts

LCC5C:  ldx     #$00
        jsr     LD5FB
        sta     ScratchPtrHi
        sty     ScratchPtrLo
        ldx     PpuBufferPos
        lda     ScratchPtrHi
        clc
        adc     #$1C
        sta     PpuUpdateBuffer,x
        inx
        lda     ScratchPtrLo
        sta     PpuUpdateBuffer,x
        inx
        ldy     #$00
LCC78:  lda     $63
        bne     LCC7E
        lda     (ScratchPtrLo),y
LCC7E:  sta     PpuUpdateBuffer,x
        inx
        iny
        cpy     #$20
        bne     LCC78
        lda     #$FF
        sta     PpuUpdateBuffer,x
        inx
        stx     PpuBufferPos
        rts

LCC90:  lda     #$11
        sta     $63
        lda     #$00
        sta     $57
LCC98:  jsr     WaitForNextFrame
        ldy     $57
        jsr     LCC5C
        lda     #$1D
        sec
        sbc     $57
        tay
        jsr     LCC5C
        inc     $57
        lda     $57
        cmp     #$10
        bne     LCC98
        rts

LCCB2:  lda     #$00
        sta     $63
        lda     #$0F
        sta     $57
LCCBA:  jsr     WaitForNextFrame
        ldy     $57
        jsr     LCC5C
        lda     #$1D
        sec
        sbc     $57
        tay
        jsr     LCC5C
        dec     $57
        lda     $57
        cmp     #$FF
        bne     LCCBA
        rts

LCCD4:  jsr     LCEF7
        ldx     #$1E
        jsr     LD276
        lda     $73
        clc
        adc     $74
        clc
        adc     $75
        clc
        adc     $76
        sta     $7D
        lda     $77
        clc
        adc     $78
        clc
        adc     $79
        clc
        adc     $7A
        sta     $7E
        lda     #$00
        sta     $5A
LCCFA:  jsr     WaitForNextFrame
        jsr     LD0B8
        ldx     #$25
        jsr     ResetEightByteRecord
        ldx     #$2D
        jsr     ResetEightByteRecord
        lda     #$00
        sta     $5D
        sta     $5E
LCD10:  jsr     WaitForNextFrame
        jsr     LD0B8
        lda     #$00
        sta     $7C
        ldx     $5A
        lda     LD3D1,x
        jsr     LD9E1
        ldx     $5A
        lda     $73,x
        beq     LCD40
        lda     #$01
        sta     $0313
        sta     $0314
        dec     $73,x
        inc     $5D
        ldx     #$02
        jsr     LD9BE
        lda     #$01
        sta     $7C
        jsr     LD138
LCD40:  ldx     $5A
        lda     $77,x
        beq     LCD5E
        lda     #$01
        sta     $0313
        sta     $0314
        dec     $77,x
        inc     $5E
        ldx     #$03
        jsr     LD9BE
        lda     #$01
        sta     $7C
        jsr     LD138
LCD5E:  ldy     #$16
        ldx     #$05
        jsr     LD934
        ldy     #$09
        jsr     LD6DD
        ldx     #$01
        ldy     #$26
        jsr     LD934
        lda     $5A
        asl     a
        clc
        adc     $5A
        clc
        adc     #$0C
        tay
        jsr     LD6DD
        ldx     $5A
        lda     $5D
        jsr     LDA13
        ldx     #$08
        ldy     #$36
        jsr     LD934
        lda     $5A
        asl     a
        clc
        adc     $5A
        clc
        adc     #$0C
        tay
        jsr     LD6DD
        lda     MenuSelection
        beq     LCDD8
        ldy     #$1E
        ldx     #$17
        jsr     LD934
        ldy     #$09
        jsr     LD6DD
        ldx     #$13
        ldy     #$2E
        jsr     LD934
        lda     $5A
        asl     a
        clc
        adc     $5A
        clc
        adc     #$0C
        tay
        jsr     LD6DD
        ldx     $5A
        lda     $5E
        jsr     LDA13
        ldx     #$0E
        ldy     #$36
        jsr     LD934
        lda     $5A
        asl     a
        clc
        adc     $5A
        clc
        adc     #$0C
        tay
        jsr     LD6DD
LCDD8:  ldx     #$08
        jsr     LD276
        lda     $7C
        beq     LCDE4
        jmp     LCD10

LCDE4:  inc     $5A
        lda     $5A
        cmp     #$04
        beq     LCDF4
        ldx     #$14
        jsr     LD276
        jmp     LCCFA

LCDF4:  ldx     #$1E
        jsr     LD276
        lda     $7D
        jsr     LDA13
        ldy     #$36
        ldx     #$08
        jsr     LD934
        ldy     #$17
        jsr     LD6DD
        lda     MenuSelection
        beq     LCE1F
        lda     $7E
        jsr     LDA13
        ldy     #$36
        ldx     #$0E
        jsr     LD934
        ldy     #$17
        jsr     LD6DD
LCE1F:  ldx     #$0F
        jsr     LD276
        lda     MenuSelection
        bne     LCE2B
        jmp     LCEE5

LCE2B:  lda     $68
        bne     LCE32
        jmp     LCEE5

LCE32:  lda     $7E
        cmp     $7D
        bcs     LCE8D
        lda     Player1Lives
        beq     LCE8D
        lda     #$00
        jsr     LD9E1
        ldx     #$00
        jsr     LD9BE
        ldy     #$16
        ldx     #$05
        jsr     LD934
        ldy     #$09
        jsr     LD6DD
        ldy     #$36
        ldx     #$01
        jsr     LD934
        ldy     #$1A
        jsr     LD6DD
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$C4
        sta     ScratchPtrLo
        ldx     #$03
        ldy     #$19
        jsr     QueueTileAtCoordinates
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$5E
        sta     ScratchPtrLo
        ldx     #$08
        ldy     #$1A
        jsr     QueueTileAtCoordinates
        lda     #$01
        sta     $031B
        sta     $031C
        sta     $031D
        jsr     LD138
        jmp     LCEE5

LCE8D:  lda     $7D
        cmp     $7E
        bcs     LCEE5
        lda     Player2Lives
        beq     LCEE5
        lda     #$00
        jsr     LD9E1
        ldx     #$01
        jsr     LD9BE
        ldy     #$1E
        ldx     #$17
        jsr     LD934
        ldy     #$09
        jsr     LD6DD
        ldy     #$36
        ldx     #$14
        jsr     LD934
        ldy     #$1A
        jsr     LD6DD
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$C4
        sta     ScratchPtrLo
        ldx     #$16
        ldy     #$19
        jsr     QueueTileAtCoordinates
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$5E
        sta     ScratchPtrLo
        ldx     #$1B
        ldy     #$1A
        jsr     QueueTileAtCoordinates
        lda     #$01
        sta     $031B
        sta     $031C
        sta     $031D
        jsr     LD138
LCEE5:  ldx     #$78
        jsr     LD276
        lda     #$00
        sta     NametableBits
        sta     $60
        sta     $6B
        lda     #$00
        sta     $4D
        rts

LCEF7:  jsr     WaitForNextFrame
        lda     #$01
        sta     $6B
        lda     #$24
        sta     $05
        lda     #$00
        sta     VerticalScroll
        lda     #$02
        sta     NametableBits
        lda     #$30
        sta     $60
        lda     #$03
        sta     $4D
        jsr     LD470
        jsr     ClearNametableBuffer
        jsr     LD0D9
        jsr     UploadNametableBuffer
        jsr     LD467
        lda     #$D2
        sta     ScratchPtrHi
        lda     #$BD
        sta     ScratchPtrLo
        ldx     #$08
        ldy     #$03
        jsr     QueueTileAtCoordinates
        ldy     #$3E
        ldx     #$12
        jsr     LD934
        ldy     #$03
        jsr     LD6DD
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$CB
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$05
        jsr     QueueTileAtCoordinates
        lda     StageNumber
        jsr     LDA13
        ldy     #$36
        ldx     #$0E
        jsr     LD934
        ldy     #$05
        jsr     LD6DD
        jsr     WaitForNextFrame
        lda     #$D2
        sta     ScratchPtrHi
        lda     #$D9
        sta     ScratchPtrLo
        ldx     #$03
        ldy     #$07
        jsr     QueueTileAtCoordinates
        ldy     #$16
        ldx     #$05
        jsr     LD934
        ldy     #$09
        jsr     LD6DD
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$B1
        sta     ScratchPtrLo
        ldx     #$0E
        ldy     #$0C
        jsr     QueueTileAtCoordinates
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$B1
        sta     ScratchPtrLo
        ldx     #$0E
        ldy     #$0F
        jsr     QueueTileAtCoordinates
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$B1
        sta     ScratchPtrLo
        ldx     #$0E
        ldy     #$12
        jsr     QueueTileAtCoordinates
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$B1
        sta     ScratchPtrLo
        ldx     #$0E
        ldy     #$15
        jsr     QueueTileAtCoordinates
        lda     MenuSelection
        beq     LD014
        jsr     WaitForNextFrame
        lda     #$D2
        sta     ScratchPtrHi
        lda     #$E2
        sta     ScratchPtrLo
        ldx     #$15
        ldy     #$07
        jsr     QueueTileAtCoordinates
        ldy     #$1E
        ldx     #$17
        jsr     LD934
        ldy     #$09
        jsr     LD6DD
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$B3
        sta     ScratchPtrLo
        ldx     #$11
        ldy     #$0C
        jsr     QueueTileAtCoordinates
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$B3
        sta     ScratchPtrLo
        ldx     #$11
        ldy     #$0F
        jsr     QueueTileAtCoordinates
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$B3
        sta     ScratchPtrLo
        ldx     #$11
        ldy     #$12
        jsr     QueueTileAtCoordinates
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$B3
        sta     ScratchPtrLo
        ldx     #$11
        ldy     #$15
        jsr     QueueTileAtCoordinates
LD014:  jsr     WaitForNextFrame
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$5E
        sta     ScratchPtrLo
        ldx     #$08
        ldy     #$0C
        jsr     QueueTileAtCoordinates
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$5E
        sta     ScratchPtrLo
        ldx     #$08
        ldy     #$0F
        jsr     QueueTileAtCoordinates
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$5E
        sta     ScratchPtrLo
        ldx     #$08
        ldy     #$12
        jsr     QueueTileAtCoordinates
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$5E
        sta     ScratchPtrLo
        ldx     #$08
        ldy     #$15
        jsr     QueueTileAtCoordinates
        lda     MenuSelection
        beq     LD096
        jsr     WaitForNextFrame
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$5E
        sta     ScratchPtrLo
        ldx     #$1A
        ldy     #$0C
        jsr     QueueTileAtCoordinates
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$5E
        sta     ScratchPtrLo
        ldx     #$1A
        ldy     #$0F
        jsr     QueueTileAtCoordinates
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$5E
        sta     ScratchPtrLo
        ldx     #$1A
        ldy     #$12
        jsr     QueueTileAtCoordinates
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$5E
        sta     ScratchPtrLo
        ldx     #$1A
        ldy     #$15
        jsr     QueueTileAtCoordinates
LD096:  jsr     WaitForNextFrame
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$BB
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$16
        jsr     QueueTileAtCoordinates
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$B5
        sta     ScratchPtrLo
        ldx     #$06
        ldy     #$17
        jsr     QueueTileAtCoordinates
        rts
LD0B8:  lda     #$02
        sta     $04
        ldy     #$64
        lda     #$80
        jsr     LD130
        ldy     #$7C
        lda     #$A0
        jsr     LD130
        ldy     #$94
        lda     #$C0
        jsr     LD130
        ldy     #$AC
        lda     #$E0
        jsr     LD130
        rts

LD0D9:  lda     #$50
        sta     $07C0
        sta     $07C1
        sta     $07C2
        sta     $07C3
        sta     $07C8
        sta     $07C9
        sta     $07CA
        sta     $07CD
        sta     $07CE
        sta     $07CF
        lda     #$A0
        sta     $07C4
        sta     $07C5
        sta     $07C6
        sta     $07C7
        lda     #$0A
        sta     $07D0
        sta     $07D1
        sta     $07D2
        sta     $07D5
        sta     $07D6
        sta     $07D7
        lda     #$05
        sta     $07F0
        sta     $07F1
        sta     $07F2
        sta     $07F5
        sta     $07F6
        sta     $07F7
        rts

LD130:  sta     $53
        ldx     #$81
        jsr     LDA7B
        rts

LD138:  lda     $68
        cmp     #$80
        bne     LD169
        lda     $66
        bne     LD14F
        lda     $17
        cmp     #$02
        bcc     LD14F
        inc     Player1Lives
        inc     $66
        jmp     LD161

LD14F:  lda     MenuSelection
        beq     LD169
        lda     $67
        bne     LD169
        lda     $1F
        cmp     #$02
        bcc     LD169
        inc     Player2Lives
        inc     $67
LD161:  lda     #$01
        sta     $0304
        sta     $0305
LD169:  rts

LD16A:  jsr     LD470
        lda     #$03
        sta     $4D
        lda     #$1C
        sta     $05
        jsr     ClearNametableBuffer
        jsr     UploadNametableBuffer
        jsr     LD467
        rts

LD17F:  jsr     LD470
        lda     #$24
        sta     $05
        jsr     ClearNametableBuffer
        ldx     #$1A
        stx     $56
        ldy     #$2E
        sty     $57
        jsr     LE3D8
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        ldx     #$3C
        stx     $56
        ldy     #$56
        sty     $57
        lda     #$E5
        sta     AuxPtrHi
        lda     #$E0
        sta     AuxPtrLo
        jsr     LD8D2
        jsr     UploadNametableBuffer
        jsr     LD467
        lda     #$30
        sta     $60
        lda     #$D2
        sta     ScratchPtrHi
        lda     #$A5
        sta     ScratchPtrLo
        ldx     #$02
        ldy     #$03
        jsr     QueueTileAtCoordinates
        ldy     #$16
        ldx     #$04
        jsr     LD934
        ldy     #$03
        jsr     LD6DD
        lda     #$D2
        sta     ScratchPtrHi
        lda     #$B1
        sta     ScratchPtrLo
        ldx     #$0B
        ldy     #$03
        jsr     QueueTileAtCoordinates
        ldy     #$3E
        ldx     #$0E
        jsr     LD934
        ldy     #$03
        jsr     LD6DD
        lda     MenuSelection
        beq     LD20E
        lda     #$D2
        sta     ScratchPtrHi
        lda     #$A8
        sta     ScratchPtrLo
        ldx     #$15
        ldy     #$03
        jsr     QueueTileAtCoordinates
        ldy     #$1E
        ldx     #$17
        jsr     LD934
        ldy     #$03
        jsr     LD6DD
LD20E:  lda     #$00
        sta     $60
        jsr     WaitForNextFrame
        lda     #$D2
        sta     ScratchPtrHi
        lda     #$C6
        sta     ScratchPtrLo
        ldx     #$0B
        ldy     #$11
        jsr     QueueTileAtCoordinates
        lda     #$D2
        sta     ScratchPtrHi
        lda     #$CF
        sta     ScratchPtrLo
        ldx     #$0B
        ldy     #$13
        jsr     QueueTileAtCoordinates
        lda     #$D2
        sta     ScratchPtrHi
        lda     #$EB
        sta     ScratchPtrLo
        ldx     #$0B
        ldy     #$15
        jsr     QueueTileAtCoordinates
        jsr     WaitForNextFrame
        lda     #$D2
        sta     ScratchPtrHi
        lda     #$8F
        sta     ScratchPtrLo
        ldx     #$0B
        ldy     #$18
        jsr     QueueTileAtCoordinates
        rts

LD255:  nop
        sta     ScratchPtrHi
        lda     #$F8
        sta     ScratchPtrLo
        ldx     #$04
        ldy     #$19
        jsr     QueueTileAtCoordinates
        jsr     WaitForNextFrame
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$20
        sta     ScratchPtrLo
        ldx     #$06
        ldy     #$1B
        jsr     QueueTileAtCoordinates
        rts
LD276:  jsr     WaitForNextFrame
        txa
        pha
        jsr     LD0B8
        pla
        tax
        dex
        bne     LD276
        rts

        .byte   $57,$52,$49,$54,$54,$45,$4E,$20
        .byte   $42,$59,$FF,$40,$20,$59,$53,$20
        .byte   $31,$39,$39,$30,$FF,$00,$00,$C9
        .byte   $CB,$00,$00,$FF,$43,$49,$54,$59
        .byte   $FF,$5E,$6B,$FF,$5F,$6B,$FF,$58
        .byte   $13,$FF,$5A,$13,$FF,$48,$49,$6B
        .byte   $FF,$48,$49,$53,$43,$4F,$52,$45
        .byte   $FF,$48,$49,$6B,$53,$43,$4F,$52
        .byte   $45,$FF,$31,$20,$50,$4C,$41,$59
        .byte   $45,$52,$FF,$32,$20,$50,$4C,$41
        .byte   $59,$45,$52,$53,$FF,$5E,$6B,$50
        .byte   $4C,$41,$59,$45,$52,$FF,$5F,$6B
        .byte   $50,$4C,$41,$59,$45,$52,$FF,$43
        .byte   $4F,$4E,$53,$54,$52,$55,$43,$54
        .byte   $49,$4F,$4E,$FF
LD2F8:  lda     #$00
        sta     $8D
        lda     #$77
        sta     ScratchPtrLo
        lda     #$F6
        sta     ScratchPtrHi
        jsr     LD326
        lda     #$B9
        sta     ScratchPtrLo
        lda     #$F7
        sta     ScratchPtrHi
        jsr     LD326
        lda     #$C9
        sta     ScratchPtrLo
        lda     #$C5
        sta     ScratchPtrHi
        jsr     LD326
        lda     #$CD
        sta     $8C
        rts

LD322:  pha
        sta     $8D
        pla
LD326:  ldy     #$06
LD328:  lda     (ScratchPtrLo),y
        eor     $8D
        sta     $8D
        dey
        bpl     LD328
        rts

        .byte   $20,$FF,$4F,$50,$45,$4E,$6B,$52
        .byte   $45,$41,$43,$48,$FF,$69,$FF,$14
        .byte   $FF,$47,$41,$4D,$45,$FF,$4F,$56
        .byte   $45,$52,$FF
; Возвращает в A остаток от деления scratch-байта $00 на 6.
RemainderBySix:  lda     $00
LD34F:  cmp     #$06
        bcc     LD357
        sbc     #$06
        bcs     LD34F
LD357:  rts

        .byte   $4F,$52,$49,$4B,$4F,$FF,$50,$54
        .byte   $53,$FF,$6A,$6A,$FF,$6C,$FC,$FF
        .byte   $6D,$FD,$FF,$11,$FF,$00,$00,$00
        .byte   $00,$00,$00,$FF,$00,$0F,$0F,$0F
        .byte   $0F,$00,$FF,$00,$0F,$C8,$CA,$0F
        .byte   $00,$FF,$00,$0F,$C9,$CB,$0F,$00
        .byte   $FF,$00,$00,$00,$00,$00,$00,$FF
        .byte   $00,$10,$10,$10,$10,$00,$FF,$00
        .byte   $10,$C8,$CA,$10,$00,$FF,$00,$10
        .byte   $C9,$CB,$10,$00,$FF,$C8,$CA,$FF
        .byte   $C9,$CB,$FF,$CC,$CE,$FF,$CD,$CF
        .byte   $FF,$5B,$FF,$5D,$FF,$54,$4F,$54
        .byte   $41,$4C,$FF,$5C,$5C,$5C,$5C,$5C
        .byte   $5C,$5C,$5C,$FF,$42,$4F,$4E,$55
        .byte   $53,$15,$FF,$53,$54,$41,$47,$45
        .byte   $FF
LD3D1:  .byte   $10,$20,$30,$40
LD3D5:  .byte   $00,$FF,$00,$01
LD3D9:  .byte   $FF,$00,$01,$00,$FF,$FF,$FF
LD3E0:  cpx     #$02
        bcc     LD3F8
        txa
        pha
        ldx     #$07
LD3E8:  lda     ObjectAttributes,x
        ora     #$03
        eor     #$04
        sta     ObjectAttributes,x
        dex
        cpx     #$01
        bne     LD3E8
        pla
        tax
        rts

LD3F8:  lda     #$0A
        sta     $89,x
        rts

        .byte   $FF,$FF,$FF

NmiHandler:
        pha
        txa
        pha
        tya
        pha
        php
        lda     #$00
        sta     OAM_ADDR
        lda     #$02
        sta     OAM_DMA
        lda     PPU_STATUS
        jsr     FlushPpuUpdateBuffer
        lda     $4D
        bmi     LD41D
        jsr     UploadBackgroundPalette
LD41D:  lda     NametableBits
        ora     #$B0
        sta     PPU_CTRL
        lda     #$00
        sta     PPU_SCROLL
        lda     VerticalScroll
        sta     PPU_SCROLL
        lda     #$1E
        sta     PPU_MASK
        jsr     ReadControllers
        jsr     LDA93
        jsr     UpdateAudioEngine
        inc     FrameCounter
        lda     FrameCounter
        and     #$3F
        bne     LD446
        inc     $0A
LD446:  plp
        pla
        tay
        pla
        tax
        pla
        rti

; Обновляет псевдослучайное состояние в $0F/$10, сохраняя X.
NextRandomByte:  txa
        pha
        lda     $0F
        asl     a
        asl     a
        asl     a
        sec
        sbc     $0F
        clc
        adc     $0A
        inc     $10
        ldx     $10
        adc     $00,x
        sta     $0F
        pla
        tax
        lda     $0F
        rts

LD467:  jsr     LD5F5
        lda     #$B0
        sta     PPU_CTRL
        rts

LD470:  jsr     WaitForNextFrame
        lda     #$10
        sta     PPU_CTRL
        lda     #$06
        sta     PPU_MASK
        rts

; Очищает теневую nametable в RAM $0400-$07FF.
ClearNametableBuffer:  lda     #$00
        tax
LD481:  sta     NametableShadow,x
        sta     $0500,x
        sta     $0600,x
        sta     $0700,x
        inx
        bne     LD481
        rts

LD491:
        lda     #$00
        sta     $60
        sta     $6B
        sta     PpuBufferPos
        sta     $0D
        sta     $6D
        lda     #$FF
        sta     $4D
        jsr     LD502
        lda     #$04
        sta     $0E
        lda     #$20
        sta     $6E
        jsr     ClearNametableBuffer
        jsr     LDA93
        ldx     #$15
        jsr     ResetEightByteRecord
        ldx     #$1D
        jsr     ResetEightByteRecord
        jsr     LD4EF
        bne     LD4CE
        ldx     #$3D
        jsr     BootHook
        lda     #$02
        sta     $3F
        lda     #$00
        sta     MenuSelection
LD4CE:  lda     #$1C
        sta     $05
        jsr     UploadNametableBuffer
        lda     #$24
        sta     $05
        jsr     UploadNametableBuffer
        jsr     LD4E3
        jsr     ResetAudioEngine
        rts

LD4E3:  ldx     #$0F
LD4E5:  lda     LC040,x
        sta     $0110,x
        dex
        bpl     LD4E5
        rts

LD4EF:  ldx     #$0F
LD4F1:  lda     $0110,x
        cmp     LC040,x
        bne     LD4FF
        dex
        bpl     LD4F1
        lda     #$01
        rts

LD4FF:  lda     #$00
        rts

LD502:  jsr     LD5F5
        jsr     UploadSpritePalette
        lda     #$00
        jsr     UploadBackgroundPalette
        rts

; A выбирает один из 16-байтовых наборов фоновой палитры.
UploadBackgroundPalette:
LD50E:  asl     a
        asl     a
        asl     a
        asl     a
        tax
        ldy     #$10
        lda     #$3F
        sta     PPU_ADDR
        lda     #$00
        sta     PPU_ADDR
LD51F:  lda     BackgroundPaletteSets,x
        sta     PPU_DATA
        inx
        dey
        bne     LD51F
        lda     #$FF
        sta     $4D
        lda     #$3F
        sta     PPU_ADDR
        lda     #$00
        sta     PPU_ADDR
        sta     PPU_ADDR
        sta     PPU_ADDR
        rts

; Загружает постоянную 16-байтовую палитру спрайтов в $3F10.
UploadSpritePalette:
LD53E:  ldx     #$00
        ldy     #$10
        lda     #$3F
        sta     PPU_ADDR
        sty     PPU_ADDR
LD54A:  lda     SpritePalette,x
        sta     PPU_DATA
        inx
        dey
        bne     LD54A
        rts

SpritePalette:
LD555:  .byte   $0F,$18,$27,$38,$0F,$0A,$1B,$3B
        .byte   $0F,$0C,$10,$20,$0F,$04,$16,$20
BackgroundPaletteSets:
LD565:  .byte   $0F,$17,$06,$00,$0F,$3C,$10,$12
        .byte   $0F,$29,$09,$0B,$0F,$00,$10,$20
        .byte   $0F,$17,$06,$00,$0F,$3C,$12,$12
        .byte   $0F,$29,$09,$0B,$0F,$00,$10,$20
        .byte   $0F,$17,$06,$00,$0F,$12,$3C,$12
        .byte   $0F,$29,$09,$0B,$0F,$00,$10,$20
        .byte   $0F,$16,$16,$30,$0F,$3C,$10,$16
        .byte   $0F,$29,$09,$27,$0F,$00,$10,$20
        .byte   $0F,$17,$06,$00,$0F,$3C,$10,$00
        .byte   $0F,$29,$09,$00,$0F,$00,$10,$00
        .byte   $0F,$0F,$06,$00,$0F,$3C,$10,$00
        .byte   $0F,$29,$09,$00,$0F,$00,$10,$00
        .byte   $0F,$12,$06,$00,$0F,$3C,$10,$00
        .byte   $0F,$29,$09,$00,$0F,$00,$10,$00
        .byte   $0F,$00,$06,$00,$0F,$3C,$10,$00
        .byte   $0F,$29,$09,$00,$0F,$00,$10,$00
        .byte   $0F,$30,$06,$00,$0F,$3C,$10,$00
        .byte   $0F,$29,$09,$00,$0F,$00,$10,$00
LD5F5:  lda     PPU_STATUS
        bpl     LD5F5
        rts

LD5FB:  lda     #$00
        sta     $00
        tya
        lsr     a
        ror     $00
        lsr     a
        ror     $00
        lsr     a
        ror     $00
        pha
        txa
        ora     $00
        tay
        pla
        ora     #$04
        rts

LD612:  jsr     LD635
        ldx     PpuBufferPos
        lda     #$23
        sta     PpuUpdateBuffer,x
        inx
        tya
        clc
        adc     #$C0
        sta     PpuUpdateBuffer,x
        inx
        lda     $07C0,y
        sta     PpuUpdateBuffer,x
        inx
        lda     #$FF
        sta     PpuUpdateBuffer,x
        inx
        stx     PpuBufferPos
        rts

LD635:  lda     $04
        jsr     LD684
        jsr     LD684
        jsr     LD684
        sta     $02
        tya
        and     #$02
        bne     LD656
        txa
        and     #$02
        beq     LD651
        lda     #$F3
        jmp     LD662

LD651:  lda     #$FC
        jmp     LD662

LD656:  txa
        and     #$02
        beq     LD660
        lda     #$3F
        jmp     LD662

LD660:  lda     #$CF
LD662:  sta     $01
        tya
        asl     a
        and     #$F8
        sta     $00
        txa
        lsr     a
        lsr     a
        clc
        adc     $00
        tay
        lda     $01
        eor     #$FF
        and     $02
        sta     $02
        lda     $07C0,y
        and     $01
        ora     $02
        sta     $07C0,y
        rts

LD684:  asl     a
        asl     a
        ora     $04
        rts

; Последовательно читает оба контроллера. $06/$07 — текущее состояние,
; $08/$09 — фронты вновь нажатых кнопок.
ReadControllers:  ldx     #$01
        stx     JOY1
        ldy     #$00
        sty     JOY1
LD693:  sty     $00
        ldy     #$08
LD697:  lda     JOY1,x
        and     #$03
        cmp     #$01
        ror     $00
        dey
        bne     LD697
        lda     Joy1Held,x
        eor     #$FF
        and     $00
        sta     Joy1Pressed,x
        lda     $00
        sta     Joy1Held,x
        dex
        bpl     LD693
        rts

; Добавляет в PPU-очередь один тайл и зеркалит его в теневую nametable.
QueueTileAtCoordinates:  jsr     LD5FB
        sta     AuxPtrHi
        clc
        adc     $05
        ldx     PpuBufferPos
        sta     PpuUpdateBuffer,x
        inx
        tya
        sta     PpuUpdateBuffer,x
        inx
        sta     AuxPtrLo
        ldy     #$00
LD6CA:  lda     (ScratchPtrLo),y
        sta     PpuUpdateBuffer,x
        inx
        cmp     #$FF
        beq     LD6DA
        sta     (AuxPtrLo),y
        iny
        jmp     LD6CA

LD6DA:  stx     PpuBufferPos
        rts

LD6DD:  jsr     LD5FB
        clc
        adc     $05
        ldx     PpuBufferPos
        sta     PpuUpdateBuffer,x
        inx
        tya
        sta     PpuUpdateBuffer,x
        inx
        ldy     #$00
LD6F0:  lda     (ScratchPtrLo),y
        bmi     LD6F7
        clc
        adc     $60
LD6F7:  sta     PpuUpdateBuffer,x
        inx
        cmp     #$FF
        beq     LD703
        iny
        jmp     LD6F0

LD703:  stx     PpuBufferPos
        rts

LD706:  jsr     LD713
LD709:  jsr     LD5FB
        sta     ScratchPtrHi
        sty     ScratchPtrLo
        ldy     #$00
        rts

LD713:  tya
        lsr     a
        lsr     a
        lsr     a
        tay
        txa
        lsr     a
        lsr     a
        lsr     a
        tax
        rts

LD71E:  stx     $47
        sty     $48
        jsr     LD706
LD725:  lda     #$01
        sta     $00
        lda     $48
        and     #$04
        beq     LD733
        asl     $00
        asl     $00
LD733:  lda     $47
        and     #$04
        beq     LD73B
        asl     $00
LD73B:  rts

LD73C:  lda     $00
        ora     #$F0
        and     (ScratchPtrLo),y
        rts

LD743:  lda     $00
        eor     #$FF
        and     (ScratchPtrLo),y
        jsr     LD784
        rts

LD74D:  lda     (ScratchPtrLo),y
        and     #$F0
        bne     LD75B
        lda     $00
        eor     #$FF
        and     (ScratchPtrLo),y
        sta     (ScratchPtrLo),y
LD75B:  rts

LD75C:  lda     $00
        ora     (ScratchPtrLo),y
        jsr     LD784
        rts
LD764:  lda     (ScratchPtrLo),y
        and     #$F0
        bne     LD770
        lda     $00
        ora     (ScratchPtrLo),y
        sta     (ScratchPtrLo),y
LD770:  rts

LD771:  lda     ScratchPtrHi
        clc
        adc     $05
        sta     PPU_ADDR
        lda     ScratchPtrLo
        sta     PPU_ADDR
        lda     (ScratchPtrLo),y
        sta     PPU_DATA
        rts

LD784:  sta     (ScratchPtrLo),y
        stx     $47
        ldx     PpuBufferPos
        lda     ScratchPtrHi
        clc
        adc     #$1C
        sta     PpuUpdateBuffer,x
        inx
        lda     ScratchPtrLo
        sta     PpuUpdateBuffer,x
        inx
        lda     (ScratchPtrLo),y
        sta     PpuUpdateBuffer,x
        inx
        lda     #$FF
        sta     PpuUpdateBuffer,x
        inx
        stx     PpuBufferPos
        ldx     $47
        rts

; Прибавляет A к 16-битному указателю $11:$12.
AddAToPointer:  clc
        adc     ScratchPtrLo
        sta     ScratchPtrLo
        bcc     LD7B3
        inc     ScratchPtrHi
LD7B3:  rts

; Передаёт всю теневую nametable $0400-$07FF в PPU.
UploadNametableBuffer:  lda     #$00
        sta     ScratchPtrLo
        tay
        lda     #$04
        sta     ScratchPtrHi
LD7BD:  jsr     LD771
        lda     #$01
        jsr     AddAToPointer
        lda     ScratchPtrHi
        cmp     #$08
        bne     LD7BD
        rts

LD7CC:  ldx     #$00
        lda     #$11
LD7D0:  sta     NametableShadow,x
        sta     $0500,x
        sta     $0600,x
        sta     $0700,x
        inx
        bne     LD7D0
        lda     #$00
        ldx     #$C0
LD7E3:  sta     $0700,x
        inx
        bne     LD7E3
        ldx     $56
        ldy     $57
        jsr     LD5FB
        sta     ScratchPtrHi
        sty     ScratchPtrLo
LD7F4:  ldy     $5B
        dey
LD7F7:  lda     #$00
        sta     (ScratchPtrLo),y
        dey
        bpl     LD7F7
        dec     $5A
        beq     LD80A
        lda     #$20
        jsr     AddAToPointer
        jmp     LD7F4

LD80A:  rts

; Рисует TSA-блок 2x2 тайла и обновляет его атрибут палитры.
DrawMetatile:  pha
        sta     $00
        jsr     LD713
        stx     $47
        sty     $48
        ldy     $00
        lda     LDABB,y
        sta     $04
        ldy     $48
        jsr     LD612
        lda     $48
        and     #$FE
        tay
        lda     $47
        and     #$FE
        tax
        jsr     LD709
        pla
        asl     a
        asl     a
        tax
        lda     LDACB,x
        inx
        jsr     LD784
        lda     #$01
        jsr     AddAToPointer
        lda     LDACB,x
        inx
        jsr     LD784
        lda     #$1F
        jsr     AddAToPointer
        lda     LDACB,x
        inx
        jsr     LD784
        lda     #$01
        jsr     AddAToPointer
        lda     LDACB,x
        inx
        jsr     LD784
        rts

LD85E:  stx     $5D
        tax
        tya
        clc
        adc     #$20
        sta     $5E
        lda     #$00
        sta     ScratchPtrLo
        lda     #$10
        sta     ScratchPtrHi
LD86F:  dex
        bmi     LD87A
        lda     #$10
        jsr     AddAToPointer
        jmp     LD86F

LD87A:  lda     ScratchPtrHi
        sta     PPU_ADDR
        lda     ScratchPtrLo
        sta     PPU_ADDR
        lda     PPU_DATA
        lda     #$08
        sta     $5A
LD88B:  lda     PPU_DATA
        pha
        dec     $5A
        bne     LD88B
        lda     #$08
        sta     $5A
LD897:  pla
        sta     $02
        lda     #$80
        sta     $03
LD89E:  ldx     $5D
        ldy     $5E
        jsr     LD71E
        lda     $02
        and     $03
        beq     LD8B1
        jsr     LD764
        jmp     LD8B4

LD8B1:  jsr     LD74D
LD8B4:  lda     $5D
        clc
        adc     #$04
        sta     $5D
        lsr     $03
        bcc     LD89E
        lda     $5D
        sec
        sbc     #$20
        sta     $5D
        lda     $5E
        sec
        sbc     #$04
        sta     $5E
        dec     $5A
        bne     LD897
        rts

LD8D2:  ldy     #$00
        sty     $5F
LD8D6:  lda     (AuxPtrLo),y
        cmp     #$FF
        beq     LD8F5
        iny
        sty     $5F
        ldx     $56
        ldy     $57
        clc
        adc     $60
        jsr     LD85E
        lda     $56
        clc
        adc     #$20
        sta     $56
        ldy     $5F
        jmp     LD8D6

LD8F5:  rts

; Ожидает изменения счётчика кадров обработчиком NMI.
WaitForNextFrame:  lda     FrameCounter
LD8F8:  cmp     FrameCounter
        beq     LD8F8
        rts

; Выполняет накопленные записи из буфера $0180 в PPU_DATA.
FlushPpuUpdateBuffer:  ldx     PpuBufferPos
        lda     #$00
        sta     PpuUpdateBuffer,x
        tax
LD905:  cpx     PpuBufferPos
        beq     LD92F
        lda     PpuUpdateBuffer,x
        inx
        sta     PPU_ADDR
        lda     PpuUpdateBuffer,x
        inx
        sta     PPU_ADDR
LD917:  lda     PpuUpdateBuffer,x
        inx
        cmp     #$FF
        bne     LD929
        lda     PpuUpdateBuffer,x
        cmp     #$FF
        bne     LD905
        lda     $017F,x
LD929:  sta     PPU_DATA
        jmp     LD917

LD92F:  lda     #$00
        sta     PpuBufferPos
        rts

LD934:  lda     $00,y
        bne     LD93E
        iny
        inx
        jmp     LD934

LD93E:  cmp     #$FF
        bne     LD94A
        lda     $6B
        bne     LD948
        dex
        dey
LD948:  dex
        dey
LD94A:  lda     #$00
        sta     ScratchPtrHi
        sty     ScratchPtrLo
        rts

LD951:  lda     #$10
        sta     $56
        lda     #$64
        sta     $57
        lda     #$30
        sta     $60
        ldy     #$3D
LD95F:  lda     $00,y
        bne     LD96F
        iny
        lda     $56
        clc
        adc     #$20
        sta     $56
        jmp     LD95F

LD96F:  lda     #$00
        sta     AuxPtrHi
        sty     AuxPtrLo
        jsr     LD8D2
        lda     #$00
        sta     $60
        rts

LD97D:  ldx     #$00
        ldy     #$00
LD981:  lda     $15,x
        cmp     $3D,x
        bne     LD98F
        inx
        cpx     #$07
        beq     LD99E
        jmp     LD981

LD98F:  bmi     LD99E
        ldx     #$00
LD993:  lda     $15,x
        sta     $3D,x
        inx
        cpx     #$07
        bne     LD993
        ldy     #$01
LD99E:  ldx     #$00
LD9A0:  lda     $1D,x
        cmp     $3D,x
        bne     LD9AE
        inx
        cpx     #$07
        beq     LD9BD
        jmp     LD9A0

LD9AE:  bmi     LD9BD
        ldx     #$00
LD9B2:  lda     $1D,x
        sta     $3D,x
        inx
        cpx     #$07
        bne     LD9B2
        ldy     #$FF
LD9BD:  rts

LD9BE:  txa
        asl     a
        asl     a
        asl     a
        clc
        adc     #$06
        tax
        ldy     #$06
        clc
LD9C9:  lda     $35,y
        adc     $15,x
        cmp     #$0A
        bmi     LD9D9
        sec
        sbc     #$0A
        sec
        jmp     LD9DA

LD9D9:  clc
LD9DA:  sta     $15,x
        dex
        dey
        bpl     LD9C9
        rts

LD9E1:  sta     $00
        ldx     #$35
        jsr     ResetEightByteRecord
        lda     $00
        beq     LD9F9
        and     #$0F
        sta     $3A
        lda     $00
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        sta     $39
        rts

LD9F9:  lda     #$01
        sta     $38
        rts

; Инициализирует восьмибайтовую запись: семь нулей и завершающий $FF.
ResetEightByteRecord:  lda     #$00
        sta     $00,x
        sta     $01,x
        sta     $02,x
        sta     $03,x
        sta     $04,x
        sta     $05,x
        sta     Joy1Held,x
        lda     #$FF
        sta     Joy2Held,x
        rts

LDA13:  sta     $00
        ldx     #$35
        jsr     ResetEightByteRecord
        jmp     ByteToDecimalDigits

LDA1D:  asl     a
        bcc     LDA27
        sec
        sbc     #$0A
        inc     $3A
        jmp     $DA1C                 ; Хаковый вход внутрь предыдущего JMP.
LDA27:  sta     $3B
        rts
LDA2B:  txa
        sta     $47
        clc
        adc     #$03
        tax
        tya
        sec
        sbc     #$08
        sta     $48
        jsr     LD706
        lda     (ScratchPtrLo),y
        cmp     #$22
        bne     LDA47
        lda     $04
        ora     $6E
        sta     $04
LDA47:  ldx     $0D
        lda     $48
        sta     OamShadow,x
        lda     $53
        sta     $0201,x
        lda     $04
        sta     $0202,x
        lda     $47
        sta     $0203,x
        txa
        clc
        adc     $0E
        sta     $0D
        rts

LDA64:  asl     a
        clc
        adc     $53
        sta     $53
        txa
        sec
        sbc     #$05
        tax
        jsr     LDA2B
        rts

LDA73:  asl     a
        asl     a
        asl     a
        clc
        adc     $53
        sta     $53
LDA7B:  stx     $54
        sty     $55
        txa
        sec
        sbc     #$08
        tax
        jsr     LDA2B
        inc     $53
        inc     $53
        ldx     $54
        ldy     $55
        jsr     LDA2B
        rts

LDA93:  ldx     $0D
        lda     $0E
        eor     #$FF
        clc
        adc     #$01
        sta     $0E
LDA9E:  txa
        clc
        adc     $0E
        tax
        lda     #$F0
        sta     OamShadow,x
        cpx     #$04
        bne     LDA9E
        stx     $0D
        rts

LDAAF:  beq     LDABA
        bcs     LDAB8
        lda     #$FF
        jmp     LDABA

LDAB8:  lda     #$01
LDABA:  rts

LDABB:  .byte   $00,$00,$00,$00,$00,$03,$03,$03
        .byte   $03,$03,$01,$02,$03,$00,$00,$00
LDACB:  .byte   $00,$0F,$00,$0F,$00,$00,$0F,$0F
        .byte   $0F,$00,$0F,$00,$0F,$0F,$00,$00
        .byte   $0F,$0F,$0F,$0F,$20,$10,$20,$10
        .byte   $20,$20,$10,$10,$10,$20,$10,$20
        .byte   $10,$10,$20,$20,$10,$10,$10,$10
        .byte   $12,$12,$12,$12,$22,$22,$22,$22
        .byte   $21,$21,$21,$21,$00,$00,$00,$00
        .byte   $00,$00,$00,$00,$00,$00,$00,$00
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
        and     #$F0
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
        jsr     LE451
        sta     $00
        bpl     LDBB4
LDBA6:  lda     #$80
        jsr     LE420
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
LDBF0:  rts

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
LDC35:  jsr     LDC3D
LDC38:  dec     $5A
        bpl     LDC03
        rts

LDC3D:  lda     ObjectState,x
        lsr     a
        lsr     a
        lsr     a
        and     #$FE
        tay
        lda     LE498,y
        sta     ScratchPtrLo
        lda     LE498+1,y
        sta     ScratchPtrHi
        jmp     (ScratchPtrLo)

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
        jsr     LE420
LDC7B:  rts

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
        lda     LE470,y
        asl     a
        asl     a
        asl     a
        sta     $59
        lda     LE470,y
        clc
        adc     ObjectY,x
        sta     $57
        lda     LE46C,y
        asl     a
        asl     a
        asl     a
        sta     $58
        lda     LE46C,y
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
        jsr     LE420
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
        jsr     LE420
LDD41:  lda     ObjectState,x
        eor     #$02
        sta     ObjectState,x
        rts

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

        lda     ObjectX
        sta     $71
        lda     ObjectY
        sta     $72
        jmp     LDD9C

        lda     $91
        sta     $71
        lda     $99
        sta     $72
        jmp     LDD9C

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

        inc     ObjectState,x
        lda     ObjectState,x
        and     #$0F
        cmp     #$0E
        bne     LDE63
        lda     #$E0
        sta     ObjectState,x
LDE63:  rts

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
LDEA2:  jsr     LE420
        rts

LDEA6:  lda     #$00
        sta     $5A
LDEAA:  ldx     $5A
        jsr     LDEB8
        inc     $5A
        lda     $5A
        cmp     #$08
        bne     LDEAA
        rts

LDEB8:  lda     ObjectState,x
        lsr     a
        lsr     a
        lsr     a
        and     #$FE
        tay
        lda     LE4B8,y
        sta     ScratchPtrLo
        lda     LE4B8+1,y
        sta     ScratchPtrHi
        jmp     (ScratchPtrLo)

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

LE02E:  lda     #$09
        sta     $5A
LE032:  ldx     $5A
        jsr     LE03C
        dec     $5A
        bpl     LE032
        rts

LE03C:  lda     $CC,x
        lsr     a
        lsr     a
        lsr     a
        and     #$FE
        tay
        lda     LE4D8,y
        sta     ScratchPtrLo
        lda     LE4D8+1,y
        sta     ScratchPtrHi
        jmp     (ScratchPtrLo)

        lda     $CC,x
        and     #$03
        tay
        jsr     LE063
        lda     $D6,x
        and     #$01
        beq     LE062
        jsr     LE063
LE062:  rts

LE063:  lda     LE46C,y
        asl     a
        clc
        adc     $B8,x
        sta     $B8,x
        lda     LE470,y
        asl     a
        clc
        adc     $C2,x
        sta     $C2,x
        rts

        dec     $CC,x
        lda     $CC,x
        and     #$0F
        bne     LE08B
        lda     $CC,x
        and     #$F0
        sec
        sbc     #$10
        beq     LE089
        ora     #$03
LE089:  sta     $CC,x
LE08B:  rts

LE08C:  lda     $CC,x
        bne     LE0D7
        cpx     #$02
        bcs     LE099
        lda     #$01
        sta     $030F
LE099:  lda     ObjectState,x
        and     #$03
        tay
        ora     #$40
        sta     $CC,x
        lda     LE46C,y
        asl     a
        asl     a
        asl     a
        clc
        adc     ObjectX,x
        sta     $B8,x
        lda     LE470,y
        asl     a
        asl     a
        asl     a
        clc
        adc     ObjectY,x
        sta     $C2,x
        lda     #$00
        sta     $D6,x
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
        sta     $D6,x
        rts

LE0D3:  lda     #$03
        sta     $D6,x
LE0D7:  rts

LE0D8:  lda     #$09
        sta     $5A
LE0DC:  ldx     $5A
        jsr     LE0E6
        dec     $5A
        bpl     LE0DC
        rts

LE0E6:  lda     $CC,x
        lsr     a
        lsr     a
        lsr     a
        and     #$FE
        tay
        lda     LE4E2,y
        sta     ScratchPtrLo
        lda     LE4E2+1,y
        sta     ScratchPtrHi
        jmp     (ScratchPtrLo)

        lda     $CC,x
        and     #$03
        pha
        ldy     $C2,x
        lda     $B8,x
        tax
        lda     #$02
        sta     $04
        lda     #$B1
        sta     $53
        pla
        jsr     LDA64
        rts

        lda     $CC,x
        pha
        ldy     $C2,x
        lda     $B8,x
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
        lda     $CC,x
        beq     LE15A
        lda     $D4,x
        bne     LE15D
        lda     $CC,x
        sta     $D4,x
        lda     $B8,x
        sta     $C0,x
        lda     $C2,x
        sta     $CA,x
        lda     $D6,x
        sta     $DE,x
        lda     #$00
        sta     $CC,x
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

LE306:  .word   LDBF0, LE312, LE317, LE31C, LE32E, LE336

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
LE409:  ldx     #$09
        lda     #$00
LE40D:  sta     $CC,x
        dex
        bpl     LE40D
        rts

LE413:  lda     #$00
        ldx     #$07
LE417:  sta     ObjectState,x
        sta     $0103,x
        dex
        bpl     LE417
        rts

LE420:  sta     $00
        lda     ObjectState,x
        and     #$0F
        ora     $00
        sta     ObjectState,x
        rts

LE42B:  .byte   $30,$F0,$0C,$74,$F4,$0C,$B8,$F8
        .byte   $0C,$30,$F0,$0C,$74,$F4,$0C,$B8
        .byte   $F8,$0C,$30,$F0,$24,$8B
LE441:  lda     $E579,y
        sta     $8C
        lda     $E57A,y
        sta     $8D
        lda     $E57B,y
        sta     $8E
        rts
LE451:  asl     a
        bcc     LE457
        lda     #$03
        rts

LE457:  asl     a
        bcc     LE45D
        lda     #$01
        rts

LE45D:  asl     a
        bcc     LE463
        lda     #$02
        rts

LE463:  asl     a
        bcc     LE469
        lda     #$00
        rts

LE469:  lda     #$FF
        rts

LE46C:  .byte   $00,$FF,$00,$01
LE470:  .byte   $FF,$00,$01,$00
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
LE498:  .word   $DBF0,$DDEA,$DDEA,$DDEA,$DDEA,$DDEA,$DDEA,$DDEA,$DC52
        .word   $DD48,$DC7C,$DD94,$DD89,$DD7E,$DE64,$DE55
LE4B8:  .word   $DBF0,$DEFD,$DF33,$DF46,$DF46,$DECD,$DECD,$DECD
        .word   $DFB6,$DFB6,$DFB6,$DFB6,$DFB6,$DFB6,$E00B,$E00B
LE4D8:  .word   $DBF0,$E076,$E076,$E076,$E051
LE4E2:  .word   $DBF0,$E112,$E112,$E112,$E0FB

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
        lda     $CC,x
        and     #$F0
        cmp     #$40
        bne     LE68B
        lda     $D6,x
        bne     LE61D
        txa
        eor     FrameCounter
        and     #$01
        beq     LE68B
LE61D:  lda     $CC,x
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
        ldy     $C2,x
        lda     $B8,x
        tax
        jsr     LE693
        beq     LE65F
        ldx     $5A
        lda     $C2,x
        clc
        adc     $64
        sta     $48
        lda     $B8,x
        clc
        adc     $65
        sta     $47
        jsr     LE69A
LE65F:  ldx     $5A
        lda     $C2,x
        sec
        sbc     $54
        tay
        lda     $B8,x
        sec
        sbc     $55
        tax
        jsr     LE693
        beq     LE68B
        ldx     $5A
        lda     $C2,x
        sec
        sbc     $64
        sec
        sbc     $54
        sta     $48
        lda     $B8,x
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
        sta     $CC,x
        jmp     LE709

LE6C6:  lda     (ScratchPtrLo),y
        jmp     LEA12

        .byte   $EA
LE6CC:  ldx     $5A
        lda     #$33
        sta     $CC,x
        lda     (ScratchPtrLo),y
        cmp     #$11
        beq     LE700
        lda     $D6,x
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
        lda     $CC,y
        and     #$F0
        cmp     #$40
        bne     LE772
        lda     $B8,y
        sec
        sbc     ObjectX,x
        bpl     LE739
        eor     #$FF
        clc
        adc     #$01
LE739:  cmp     #$0A
        bcs     LE772
        lda     $C2,y
        sec
        sbc     ObjectY,x
        bpl     LE74A
        eor     #$FF
        clc
        adc     #$01
LE74A:  cmp     #$0A
        bcs     LE772
        lda     #$33
        sta     $CC,y
        lda     $89,x
        beq     LE75F
        lda     #$00
        sta     $CC,y
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
        lda     $CC,y
        and     #$F0
        cmp     #$40
        beq     LE7AA
        jmp     LE82D

LE7AA:  lda     $B8,y
        sec
        sbc     ObjectX,x
        bpl     LE7B7
        eor     #$FF
        clc
        adc     #$01
LE7B7:  cmp     #$0A
        bcs     LE82D
        lda     $C2,y
        sec
        sbc     ObjectY,x
        bpl     LE7C8
        eor     #$FF
        clc
        adc     #$01
LE7C8:  cmp     #$0A
        bcs     LE82D
        lda     #$33
        sta     $CC,y
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
        lda     $CC,x
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
        lda     $CC,y
        and     #$F0
        cmp     #$40
        bne     LE969
        lda     $B8,y
        sec
        sbc     $B8,x
        bpl     LE94D
        eor     #$FF
        clc
        adc     #$01
LE94D:  cmp     #$06
        bcs     LE969
        lda     $C2,y
        sec
        sbc     $C2,x
        bpl     LE95E
        eor     #$FF
        clc
        adc     #$01
LE95E:  cmp     #$06
        bcs     LE969
        lda     #$00
        sta     $CC,x
        sta     $CC,y
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
        lda     LE9E2,y
        sta     ScratchPtrLo
        lda     LE9E2+1,y
        sta     ScratchPtrHi
        pla
        pla
        jmp     (ScratchPtrLo)

LE9DD:  dec     $49
        bpl     LE97E
LE9E1:  rts

LE9E2:  .word   LD3E0,LE3B8,LFDBB,LC5FF,LFE22,LFE78,LC613,LFEA7

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
; Включает каналы APU и очищает записи состояния звуковых потоков.
ResetAudioEngine:
LEA51:  lda     #$0F
        sta     APU_STATUS
        lda     #$C0
        sta     JOY2_FRAME
        lda     #$1C
        sta     AudioStatePtrLo
        lda     #$03
        sta     AudioStatePtrHi
        ldx     #$00
        ldy     #$00
LEA67:  tya
        sta     (AudioStatePtrLo),y
        sta     $0300,x
        clc
        lda     AudioStatePtrLo
        adc     #$08
        sta     AudioStatePtrLo
        bcc     LEA78
        inc     AudioStatePtrHi
LEA78:  inx
        cpx     #$1C
        bne     LEA67
        rts

; Один кадровый шаг интерпретатора музыки и звуковых эффектов.
UpdateAudioEngine:
LEA7E:  lda     $6D
        bne     LEA88
        lda     #$1C
        sta     AudioChannelCount
        bpl     LEA8C
LEA88:  lda     #$01
        sta     AudioChannelCount
LEA8C:  lda     #$00
        ldx     #$03
LEA90:  sta     $F9,x
        dex
        bpl     LEA90
        lda     #$00
        sta     AudioChannel
        lda     #$1C
        sta     AudioStatePtrLo
        lda     #$03
        sta     AudioStatePtrHi
LEAA1:  ldx     AudioChannel
        lda     $0300,x
        beq     LEAE3
        ldy     #$00
        lda     (AudioStatePtrLo),y
        beq     LEAE3
        cmp     #$05
        bcc     LEABD
        sec
        sbc     #$05
        tax
        lda     #$01
        sta     $F9,x
        jmp     LEAE3

LEABD:  tax
        dex
        lda     $F9,x
        bne     LEAE3
        lda     #$01
        sta     $F9,x
        txa
        tay
        clc
        adc     #$05
        ldy     #$00
        sta     (AudioStatePtrLo),y
        txa
        asl     a
        asl     a
        tax
        lda     #$04
        sta     AudioWorkLo
LEAD8:  iny
        lda     (AudioStatePtrLo),y
        sta     APU_PULSE1_CTRL,x
        inx
        dec     AudioWorkLo
        bne     LEAD8
LEAE3:  clc
        lda     AudioStatePtrLo
        adc     #$08
        sta     AudioStatePtrLo
        bcc     LEAEE
        inc     AudioStatePtrHi
LEAEE:  inc     AudioChannel
        lda     AudioChannel
        cmp     AudioChannelCount
        bcc     LEAA1
        ldx     #$00
LEAF8:  stx     AudioWorkLo
        lda     $F9,x
        bne     LEB0A
        txa
        asl     a
        asl     a
        tax
        asl     a
        and     #$10
        eor     #$10
        sta     APU_PULSE1_CTRL,x
LEB0A:  ldx     AudioWorkLo
        inx
        cpx     #$04
        bcc     LEAF8
        ldy     #$00
        sty     AudioChannel
        lda     #$1C
        sta     AudioStatePtrLo
        lda     #$03
        sta     AudioStatePtrHi
LEB1D:  ldx     AudioChannel
        lda     $0300,x
        beq     LEB2E
        cmp     #$01
        bne     LEB42
        inc     $0300,x
        jmp     LEB4F

LEB2E:  clc
        lda     AudioStatePtrLo
        adc     #$08
        sta     AudioStatePtrLo
        bcc     LEB39
        inc     AudioStatePtrHi
LEB39:  inc     AudioChannel
        lda     AudioChannel
        cmp     AudioChannelCount
        bcc     LEB1D
        rts

LEB42:  ldy     #$07
        lda     (AudioStatePtrLo),y
        sec
        sbc     #$01
        sta     (AudioStatePtrLo),y
        beq     LEB85
        bne     LEB2E
LEB4F:  lda     #$00
        ldy     #$05
        sta     (AudioStatePtrLo),y
        jsr     LECAF
        jsr     LECBE
        ldy     #$00
        sta     (AudioStatePtrLo),y
        jsr     LECBE
        ldy     #$01
        sta     (AudioStatePtrLo),y
        jsr     LECBE
        ldy     #$02
        sta     (AudioStatePtrLo),y
        jsr     LECBE
        ldy     #$04
        sta     (AudioStatePtrLo),y
        ldy     #$00
        lda     (AudioStatePtrLo),y
        cmp     #$04
        bne     LEB88
        jsr     LECBE
        ldy     #$03
        sta     (AudioStatePtrLo),y
        bpl     LEB88
LEB85:  jsr     LECAF
LEB88:  jsr     LECBE
        cmp     #$E8
        bcs     LEBE1
        cmp     #$60
        beq     LEBD7
        bcc     LEB9E
        sbc     #$60
        ldy     #$06
        sta     (AudioStatePtrLo),y
        jmp     LEB88

LEB9E:  pha
        and     #$F8
        lsr     a
        lsr     a
        tax
        lda     LECE6,x
        sta     AudioWorkLo
        lda     LECE7,x
        sta     AudioWorkHi
        pla
        and     #$07
        beq     LEBBB
        tax
LEBB4:  lsr     AudioWorkLo
        ror     AudioWorkHi
        dex
        bne     LEBB4
LEBBB:  ldy     #$04
        lda     (AudioStatePtrLo),y
        and     #$F8
        ora     AudioWorkLo
        sta     (AudioStatePtrLo),y
        lda     AudioWorkHi
        dey
        sta     (AudioStatePtrLo),y
        ldy     #$00
        lda     (AudioStatePtrLo),y
        cmp     #$05
        bcc     LEBD7
        sec
        sbc     #$04
        sta     (AudioStatePtrLo),y
LEBD7:  ldy     #$06
        lda     (AudioStatePtrLo),y
        iny
        sta     (AudioStatePtrLo),y
        jmp     LEB2E

LEBE1:  sbc     #$E8
        jsr     LECD0

; LECD0 использует адрес возврата как базу этой inline-таблицы и передаёт
; управление обработчику команды $E8-$F8.
AudioCommandHandlers:
        .word   LEC0A,LEC21,LEC33,LEC45,LEC57,LEC61,LEC6B,LEC75
        .word   LEC81,LEC85,LEC88,LEC99,LEC99,LEC99,LEC99,LEC99,LEC99,LECA5

LEC0A:  ldx     AudioChannel
LEC0C:  lda     #$00
        sta     $0300,x
        ldy     #$00
        sta     (AudioStatePtrLo),y
        ldy     #$05
        lda     (AudioStatePtrLo),y
        sec
        sbc     #$01
        sta     (AudioStatePtrLo),y
        jmp     LEB2E

LEC21:  jsr     LECBE
        sta     AudioWorkLo
        ldy     #$01
        lda     (AudioStatePtrLo),y
        and     #$3F
        ora     AudioWorkLo
        sta     (AudioStatePtrLo),y
        jmp     LEB88

LEC33:  jsr     LECBE
        sta     AudioWorkLo
        ldy     #$01
        lda     (AudioStatePtrLo),y
        and     #$C0
        ora     AudioWorkLo
        sta     (AudioStatePtrLo),y
        jmp     LEB88

LEC45:  jsr     LECBE
        sta     AudioWorkLo
        ldy     #$01
        lda     (AudioStatePtrLo),y
        and     #$F0
        ora     AudioWorkLo
        sta     (AudioStatePtrLo),y
        jmp     LEB88

LEC57:  jsr     LECBE
        ldy     #$02
        sta     (AudioStatePtrLo),y
        jmp     LEB88

LEC61:  jsr     LECBE
        ldy     #$04
        sta     (AudioStatePtrLo),y
        jmp     LEB88

LEC6B:  jsr     LECBE
        ldy     #$01
        sta     (AudioStatePtrLo),y
        jmp     LEB88

LEC75:  lda     #$00
        ldx     #$02
LEC79:  sta     AudioLoopCounters,x
        dex
        bpl     LEC79
        jmp     LEB88

LEC81:  ldx     #$00
        beq     LEC8A
LEC85:  ldx     #$01
        .byte   $2C                    ; BIT abs поглощает следующий LDX #$02.
LEC88:  ldx     #$02
LEC8A:  jsr     LECBE
        inc     AudioLoopCounters,x
        cmp     AudioLoopCounters,x
        bne     LECA5
        lda     #$00
        sta     AudioLoopCounters,x
        beq     LEC99

LEC99:  ldy     #$05
        lda     (AudioStatePtrLo),y
        clc
        adc     #$01
        sta     (AudioStatePtrLo),y
        jmp     LEB88

LECA5:  jsr     LECBE
        ldy     #$05
        sta     (AudioStatePtrLo),y
        jmp     LEB88
LECAF:  lda     AudioChannel
        asl     a
        tax
        lda     AudioSequencePointers,x
        sta     AudioDataPtrLo
        lda     AudioSequencePointers+1,x
        sta     AudioDataPtrHi
        rts

LECBE:  lda     AudioChannel
        ldy     #$05
        lda     (AudioStatePtrLo),y
        tay
        lda     (AudioDataPtrLo),y
        pha
        iny
        tya
        ldy     #$05
        sta     (AudioStatePtrLo),y
        pla
        rts

LECD0:  asl     a
        tay
        iny
        pla
        sta     AudioWorkLo
        pla
        sta     AudioWorkHi
        lda     (AudioWorkLo),y
        tax
        iny
        lda     (AudioWorkLo),y
        sta     AudioWorkHi
        stx     AudioWorkLo
        jmp     (AudioWorkLo)

LECE6:  .byte   $07
LECE7:  .byte   $F2,$07,$80,$07,$14,$06,$AE,$06
        .byte   $43,$05,$F4,$05,$9E,$05,$4E,$05
        .byte   $02,$04,$BA,$04,$76,$04,$36
AudioSequencePointers:
LECFE:  .word   $EE2C,$ED36,$ED5D,$ED88
        .word   $EE9F,$EEAE,$EE19,$EDB3
        .word   $EDD5,$EE48,$EE03,$EDF4
        .word   $EE5E,$EE56,$EE67,$EE12
        .word   $EE95,$EE8C,$EE82,$EE73
        .word   $EE7A,$EEC1,$EEDF,$EF0A
        .word   $EF3C,$EF4F,$EF62,$EE3A

; Потоки байткода музыки и звуковых эффектов. Команды $E8-$F8
; обрабатываются таблицей AudioCommandHandlers.
AudioSequences:
        .byte   $01,$81,$7F,$40,$EF,$68,$1B,$2B,$33
        .byte   $F0,$02,$06,$33,$43,$53,$F0,$02
        .byte   $0C,$43,$53,$04,$F0,$02,$12,$5B
        .byte   $0C,$1C,$F0,$02,$18,$78,$1C,$68
        .byte   $1C,$1C,$1C,$78,$1C,$E8,$03,$10
        .byte   $7F,$08,$78,$1A,$68,$1A,$F1,$03
        .byte   $07,$78,$32,$68,$32,$F1,$03,$0E
        .byte   $78,$42,$68,$42,$F1,$03,$15,$5A
        .byte   $F1,$03,$19,$0B,$F1,$03,$1D,$78
        .byte   $52,$68,$52,$F1,$03,$24,$78,$52
        .byte   $E8,$02,$81,$7F,$40,$78,$51,$68
        .byte   $51,$F2,$03,$07,$78,$0A,$68,$0A
        .byte   $F2,$03,$0E,$78,$1A,$68,$1A,$F2
        .byte   $03,$15,$32,$F2,$03,$19,$42,$F2
        .byte   $03,$1D,$78,$3A,$68,$3A,$F2,$03
        .byte   $24,$78,$3A,$E8,$04,$1F,$7F,$30
        .byte   $0A,$62,$49,$49,$EA,$1E,$49,$49
        .byte   $EA,$1D,$49,$49,$EA,$1C,$49,$49
        .byte   $EA,$1B,$49,$49,$EA,$1A,$49,$EA
        .byte   $19,$49,$EA,$18,$49,$E8,$02,$1F
        .byte   $7F,$30,$62,$00,$01,$00,$EA,$1E
        .byte   $01,$00,$EA,$1D,$01,$00,$01,$00
        .byte   $EA,$1C,$01,$EA,$1B,$00,$EA,$1A
        .byte   $01,$EA,$19,$00,$E8,$02,$20,$7F
        .byte   $30,$63,$1A,$12,$51,$31,$19,$11
        .byte   $50,$30,$18,$E8,$04,$1F,$7F,$40
        .byte   $0A,$62,$51,$EA,$1E,$51,$EA,$08
        .byte   $6A,$51,$E8,$01,$8F,$82,$10,$6F
        .byte   $2C,$E8,$02,$80,$7F,$40,$63,$52
        .byte   $1B,$3B,$53,$4A,$13,$33,$4B,$1B
        .byte   $3B,$53,$1C,$3C,$E8,$02,$82,$7F
        .byte   $40,$64,$1B,$2B,$3B,$1C,$2C,$3C
        .byte   $6C,$53,$E8,$02,$82,$7F,$40,$63
        .byte   $53,$1B,$1C,$3B,$3C,$53,$6A,$54
        .byte   $E8,$02,$60,$7F,$40,$64,$52,$3A
        .byte   $52,$03,$52,$03,$13,$1B,$E8,$02
        .byte   $D5,$7F,$00,$62,$1C,$1D,$E8,$03
        .byte   $07,$7F,$08,$61,$3A,$13,$22,$E8
        .byte   $02,$40,$7F,$00,$61,$3D,$62,$45
        .byte   $EA,$10,$28,$E8,$02,$80,$7F,$18
        .byte   $61,$39,$E8,$04,$00,$7F,$28,$0A
        .byte   $61,$28,$E8,$02,$8C,$94,$40,$61
        .byte   $10,$64,$18,$F9,$05,$02,$80,$94
        .byte   $48,$62,$40,$48,$F9,$05,$01,$1F
        .byte   $7F,$28,$61,$22,$42,$5A,$1B,$E8
        .byte   $01,$A0,$7F,$40,$66,$1C,$3C,$1C
        .byte   $53,$1C,$3C,$05,$72,$54,$E8,$02
        .byte   $90,$7F,$40,$62,$38,$66,$EA,$20
        .byte   $3B,$53,$3B,$1B,$3B,$53,$1C,$6A
        .byte   $14,$E8,$01,$B8,$7F,$40,$EF,$65
        .byte   $0C,$53,$F0,$0C,$05,$0C,$53,$F0
        .byte   $0C,$0B,$34,$24,$F0,$08,$10,$EA
        .byte   $30,$B0,$50,$EA,$20,$9C,$54,$E8
        .byte   $02,$B8,$7F,$40,$65,$43,$33,$F1
        .byte   $0C,$04,$43,$33,$F1,$0C,$0A,$14
        .byte   $4B,$F1,$08,$0F,$EA,$3A,$30,$50
        .byte   $09,$29,$31,$51,$0A,$2A,$32,$52
        .byte   $0B,$2B,$33,$53,$0C,$2C,$9C,$EA
        .byte   $20,$2C,$E8,$03,$00,$7F,$08,$A1
        .byte   $01,$01,$EE,$15,$6A,$0B,$0B,$0B
        .byte   $EE,$22,$6F,$33,$65,$43,$7E,$EE
        .byte   $33,$53,$6A,$EE,$15,$43,$33,$53
        .byte   $6F,$EE,$22,$13,$65,$23,$7E,$EE
        .byte   $33,$33,$6A,$EE,$15,$23,$13,$4A
        .byte   $9C,$EE,$FF,$32,$E8,$01,$42,$7F
        .byte   $40,$66,$1B,$0B,$78,$1B,$68,$52
        .byte   $42,$32,$1A,$1A,$1A,$78,$1A,$E8
        .byte   $02,$82,$7F,$40,$66,$52,$52,$78
        .byte   $52,$68,$32,$2A,$12,$1A,$1A,$1A
        .byte   $78,$1A,$E8,$03,$10,$7F,$08,$66
        .byte   $3B,$33,$78,$3B,$68,$1B,$0B,$52
        .byte   $52,$52,$52,$78,$52,$E8,$FF
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
        lda     LE42B,x
        sta     ScratchPtrLo
        inx
        lda     LE42B,x
        sta     ScratchPtrHi
        inx
        lda     LE42B,x
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

; End of "PRG1_LO" segment
.code

