; Очереди строк и шторка перехода экрана ($CC27-$CCD3).

CurtainRowIndex      = $57
NametableRowFillTile = $63

; За 64 кадра переносит NametableAttributes в PPU $23C0-$23FF,
; по одному байту за кадр. Меняет A/X/Y, ScratchPtr и PPU-очередь.
UploadAttributesGradually:
LCC27:  ldy     #$00
        lda     #$23
        sta     ScratchPtrHi
        lda     #$C0
        sta     ScratchPtrLo
UploadNextAttributeByte:
LCC31:  jsr     WaitForNextFrame
        ldx     PpuBufferPos
        lda     ScratchPtrHi
        sta     PpuUpdateBuffer,x
        inx
        lda     ScratchPtrLo
        sta     PpuUpdateBuffer,x
        inx
        lda     NametableAttributes,y
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
        bne     UploadNextAttributeByte
        rts

; Ставит в PPU-очередь полную 32-тайловую строку nametable.
; Вход: Y — номер строки; если NametableRowFillTile=0, данные берутся из
; shadow, иначе вся строка заполняется этим тайлом. Меняет A/X/Y, ScratchPtr,
; scratch $00 и PPU-очередь.
QueueNametableRow:
LCC5C:  ldx     #$00
        jsr     TileCoordinatesToShadowAddress
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
QueueNextNametableTile:
LCC78:  lda     NametableRowFillTile
        bne     StoreNametableTile
        lda     (ScratchPtrLo),y
StoreNametableTile:
LCC7E:  sta     PpuUpdateBuffer,x
        inx
        iny
        cpy     #$20
        bne     QueueNextNametableTile
        lda     #$FF
        sta     PpuUpdateBuffer,x
        inx
        stx     PpuBufferPos
        rts

; Шторка перед выбором этапа: за 16 кадров заполняет тайлом $11 парные строки,
; двигаясь от верхнего/нижнего краёв к центру. Меняет
; CurtainRowIndex/NametableRowFillTile и PPU-очередь.
CloseNametableCurtain:
LCC90:  lda     #$11
        sta     NametableRowFillTile
        lda     #$00
        sta     CurtainRowIndex
CloseCurtainNextRowPair:
LCC98:  jsr     WaitForNextFrame
        ldy     CurtainRowIndex
        jsr     QueueNametableRow
        lda     #$1D
        sec
        sbc     CurtainRowIndex
        tay
        jsr     QueueNametableRow
        inc     CurtainRowIndex
        lda     CurtainRowIndex
        cmp     #$10
        bne     CloseCurtainNextRowPair
        rts

; Обратная шторка: восстанавливает пары строк из shadow, двигаясь от центра
; к краям. Центральная пара при первых двух проходах записывается дважды.
; Меняет CurtainRowIndex/NametableRowFillTile и PPU-очередь.
OpenNametableCurtain:
LCCB2:  lda     #$00
        sta     NametableRowFillTile
        lda     #$0F
        sta     CurtainRowIndex
OpenCurtainNextRowPair:
LCCBA:  jsr     WaitForNextFrame
        ldy     CurtainRowIndex
        jsr     QueueNametableRow
        lda     #$1D
        sec
        sbc     CurtainRowIndex
        tay
        jsr     QueueNametableRow
        dec     CurtainRowIndex
        lda     CurtainRowIndex
        cmp     #$FF
        bne     OpenCurtainNextRowPair
        rts
