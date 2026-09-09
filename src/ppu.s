; NMI, PPU-очередь, OAM и отрисовка метатайлов ($D400-$DB0A).

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
LD555:  .incbin "../build/sprite-palette.bin"
BackgroundPaletteSets:
LD565:  .incbin "../build/background-palettes.bin"
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
        lda     MetatilePalettes,y
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
        lda     MetatileTiles,x
        inx
        jsr     LD784
        lda     #$01
        jsr     AddAToPointer
        lda     MetatileTiles,x
        inx
        jsr     LD784
        lda     #$1F
        jsr     AddAToPointer
        lda     MetatileTiles,x
        inx
        jsr     LD784
        lda     #$01
        jsr     AddAToPointer
        lda     MetatileTiles,x
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

MetatilePalettes:
LDABB:  .incbin "../build/background-metatiles.bin", 0, 16
MetatileTiles:
LDACB:  .incbin "../build/background-metatiles.bin", 16, 64
