; Передача и инициализация nametable shadow ($D7B4-$D80A).

; Передаёт всю теневую nametable $0400-$07FF в PPU. NametablePpuOffset задаёт
; смещение старшего байта (обычно $1C для $2000 или $20 для $2400).
; Предполагает отключённый рендеринг. Выход: ScratchPtr=$0800, Y=0; A и PPU latch/data изменены.
UploadNametableBuffer:  lda     #$00
        sta     ScratchPtrLo
        tay
        lda     #$04
        sta     ScratchPtrHi
UploadNextNametableShadowByte:
LD7BD:  jsr     UploadShadowByteDirect
        lda     #$01
        jsr     AddAToPointer
        lda     ScratchPtrHi
        cmp     #$08
        bne     UploadNextNametableShadowByte
        rts

; Готовит shadow nametable для игрового поля: заполняет её тайлом $11,
; обнуляет NametableAttributes и затем очищает прямоугольник по нулевым тайлам.
; Вход: NametableRectX/Y -- начало в тайлах, NametableRectHeight/Width -- размер.
; Нулевая высота или ширина не поддерживаются. Меняет A/X/Y, ScratchPtr
; и NametableRectHeight.
InitializePlayfieldShadow:
LD7CC:  ldx     #$00
        lda     #$11
FillNextPlayfieldShadowByte:
LD7D0:  sta     NametableShadow,x
        sta     NametableShadowPage1,x
        sta     NametableShadowPage2,x
        sta     NametableShadowPage3,x
        inx
        bne     FillNextPlayfieldShadowByte
        lda     #$00
        ldx     #$C0
ClearNextAttributeShadowByte:
LD7E3:  sta     NametableShadowPage3,x
        inx
        bne     ClearNextAttributeShadowByte
        ldx     NametableRectX
        ldy     NametableRectY
        jsr     TileCoordinatesToShadowAddress
        sta     ScratchPtrHi
        sty     ScratchPtrLo
ClearNextNametableRectangleRow:
LD7F4:  ldy     NametableRectWidth
        dey
ClearNextNametableRectangleByte:
LD7F7:  lda     #$00
        sta     (ScratchPtrLo),y
        dey
        bpl     ClearNextNametableRectangleByte
        dec     NametableRectHeight
        beq     FinishPlayfieldShadowInitialization
        lda     #$20
        jsr     AddAToPointer
        jmp     ClearNextNametableRectangleRow

FinishPlayfieldShadowInitialization:
LD80A:  rts
