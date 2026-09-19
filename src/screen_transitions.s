; Очереди строк и шторка перехода экрана ($CC27-$CCD3).

CurtainRowIndex      = $57
NametableRowFillTile = $63

NametableAttributeByteCount    = $40
NametableRowTileCount          = $20
NametableLastVisibleRow        = $1D
NametableCurtainPairCount      = $10
NametableCurtainTile           = $11

; За 64 кадровые итерации ставит NametableAttributes в PPU-очередь по адресам
; $23C0-$23FF, по одному байту за итерацию. WaitForNextFrame в начале следующей
; итерации передаёт предыдущую команду; последний байт остаётся в очереди до
; следующего NMI. Выход: ScratchPtr=$2400, Y=$40; A/X и PpuBufferPos отражают
; последнюю команду. Меняет input/audio/frame state через ожидания, но shadow не меняет.
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
        cpy     #NametableAttributeByteCount
        bne     UploadNextAttributeByte
        rts

; Ставит в PPU-очередь полную 32-тайловую строку nametable.
; Вход: Y — номер строки; если NametableRowFillTile=0, данные берутся из
; shadow, иначе вся строка заполняется этим тайлом (поэтому заполнить строку
; константой 0 через этот интерфейс нельзя). Адрес назначения всегда относится
; к основной nametable $2000. Выход: A=$FF, Y=$20, X=PpuBufferPos.
; Меняет ScratchPtr, scratch $00 и PPU update buffer; shadow и PPU напрямую не меняет.
QueueNametableRow:
LCC5C:  ldx     #$00
        jsr     TileCoordinatesToShadowAddress
        sta     ScratchPtrHi
        sty     ScratchPtrLo
        ldx     PpuBufferPos
        lda     ScratchPtrHi
        clc
        adc     #ShadowToPrimaryNametableOffset
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
        cpy     #NametableRowTileCount
        bne     QueueNextNametableTile
        lda     #$FF
        sta     PpuUpdateBuffer,x
        inx
        stx     PpuBufferPos
        rts

; Шторка перед выбором этапа: за 16 кадров ставит в очередь парные строки,
; заполненные тайлом $11, двигаясь от краёв 0/29 к центру. Строки 14/15
; ставятся дважды на последних двух итерациях. Последняя пара остаётся в очереди
; до следующего NMI. Выход: CurtainRowIndex=$10, NametableRowFillTile=$11.
; Портит A/X/Y, ScratchPtr и PPU update buffer; shadow не меняет.
CloseNametableCurtain:
LCC90:  lda     #NametableCurtainTile
        sta     NametableRowFillTile
        lda     #$00
        sta     CurtainRowIndex
CloseCurtainNextRowPair:
LCC98:  jsr     WaitForNextFrame
        ldy     CurtainRowIndex
        jsr     QueueNametableRow
        lda     #NametableLastVisibleRow
        sec
        sbc     CurtainRowIndex
        tay
        jsr     QueueNametableRow
        inc     CurtainRowIndex
        lda     CurtainRowIndex
        cmp     #NametableCurtainPairCount
        bne     CloseCurtainNextRowPair
        rts

; Обратная шторка: восстанавливает пары строк из shadow, двигаясь от центра
; к краям. Центральная пара при первых двух проходах записывается дважды.
; Последняя пара остаётся в очереди до следующего NMI. Выход:
; CurtainRowIndex=$FF, NametableRowFillTile=0. Портит A/X/Y, ScratchPtr и
; PPU update buffer; shadow не меняет.
OpenNametableCurtain:
LCCB2:  lda     #$00
        sta     NametableRowFillTile
        lda     #(NametableCurtainPairCount-1)
        sta     CurtainRowIndex
OpenCurtainNextRowPair:
LCCBA:  jsr     WaitForNextFrame
        ldy     CurtainRowIndex
        jsr     QueueNametableRow
        lda     #NametableLastVisibleRow
        sec
        sbc     CurtainRowIndex
        tay
        jsr     QueueNametableRow
        dec     CurtainRowIndex
        lda     CurtainRowIndex
        cmp     #$FF
        bne     OpenCurtainNextRowPair
        rts
