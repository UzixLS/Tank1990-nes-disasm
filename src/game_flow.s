; Восемь байтов ASCII "COPYRIGH" перед первой процедурой банка.
Prg1CopyrightPrefix:
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
        and     #BUTTON_A
        bne     LC02B
        lda     Joy1Held,x
        and     #BUTTON_B
        beq     LC02E
LC02B:  jmp     LE136

LC02E:  jmp     LE15D

LC031:  lda     Joy1Pressed,x
        and     #(BUTTON_A | BUTTON_B)
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
LC0BE:  jsr     ClearTankStates
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
        jsr     DrawTanks
LC0FC:  lda     Joy1Held
        and     #BUTTON_DIRECTIONS
        bne     LC13E
        lda     Joy1Pressed
        and     #BUTTON_A
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
        and     #BUTTON_B
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
        and     #(BUTTON_A | BUTTON_B)
        beq     LC147
LC144:  jsr     LC6C6
LC147:  lda     Joy1Pressed
        and     #BUTTON_START
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
        and     #BUTTON_START
        bne     LC1C5
        lda     Joy1Pressed
        and     #BUTTON_A
        bne     LC191
        lda     Joy1Held
        and     #BUTTON_A
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
        and     #BUTTON_B
        bne     LC1B6
        lda     Joy1Held
        and     #BUTTON_B
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
        jsr     LoadAndDrawStage
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
        jsr     DrawProjectiles
        jsr     DrawTanks
        lda     Joy1Pressed
        and     #BUTTON_START
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
        jsr     DrawTanks
        jsr     DrawProjectiles
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
        jsr     UpdateTanks
        jsr     LE1FA
        jsr     UpdateProjectiles
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

LC331:  jsr     ClearProjectileStates
        jsr     ClearTankStates
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
        jsr     LoadAndDrawStage
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
        and     #(BUTTON_SELECT | BUTTON_START)
        bne     LC43F
        jsr     LC642
        jsr     LC2E6
        jsr     LE23B
        jsr     DrawTanks
        jsr     DrawProjectiles
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
        and     #BUTTON_DOWN
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
        and     #BUTTON_UP
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
        and     #BUTTON_SELECT
        beq     LC572
        lda     $8E
        eor     #$01
        sta     $8E
        jsr     LFD0C
LC572:  lda     Joy1Pressed
        and     #BUTTON_START
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

PowerUpEffect3:
LC5FF:  cpx     #$02
        bcs     LC610
        lda     $8E
        beq     LC610
        lda     $0178,x
        clc
        adc     #$20
        sta     $0178,x
LC610:  jmp     LFDFB

PowerUpEffect6:
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
        and     #BUTTON_DIRECTIONS
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
        and     #BUTTON_DIRECTIONS
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
        and     #BUTTON_DIRECTIONS
        beq     LC71D
        lda     Joy1Pressed
        jsr     DecodeDirectionButtons
        bmi     LC71D
        jmp     LC704

LC6FB:  lda     #$0F
        sta     $7B
        lda     Joy1Held
        jsr     DecodeDirectionButtons
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
        and     #BUTTON_SELECT
        beq     LC792
        inc     $0109
LC792:  lda     Joy1Pressed
        and     #BUTTON_B
        beq     LC79B
        dec     $0109
LC79B:  lda     Joy1Pressed
        and     #BUTTON_A
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
        and     #(BUTTON_SELECT | BUTTON_START)
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
