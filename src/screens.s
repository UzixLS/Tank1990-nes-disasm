TitleScreen:
LC9C0:  lda     #$03
        sta     $4D
        jsr     ClearTankStates
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
LC9F5:  jsr     DrawTanks
        lda     Joy1Pressed
        and     #BUTTON_SELECT
        beq     LCA04
        inc     MenuSelection
        lda     #$00
        sta     $0A
LCA04:  lda     Joy1Held
        and     #BUTTON_DOWN
        beq     LCA17
        lda     Joy1Pressed
        and     #BUTTON_A
        beq     LCA17
        lda     #$10
        clc
        adc     $4A
        sta     $4A
LCA17:  lda     Joy1Held
        and     #BUTTON_RIGHT
        beq     LCA25
        lda     Joy1Pressed
        and     #BUTTON_B
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
        and     #BUTTON_START
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
PowerUpEffect0:
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
