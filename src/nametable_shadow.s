; Передача и инициализация nametable shadow ($D7B4-$D80A).

NametableShadowFirstPage       = $04
NametableShadowPastEndPage     = $08
NametableAttributeStartOffset = $C0
NametableTileRowByteCount      = $20

; Передаёт все 1024 байта shadow $0400-$07FF: 960 tile bytes и 64 attribute
; bytes. Для каждого байта заново задаёт PPU-адрес
; ((shadow_hi+NametablePpuOffset)<<8)|shadow_lo, затем пишет PPU_DATA.
; Обычные смещения: ShadowToPrimaryNametableOffset -> $2000-$23FF,
; $20 -> $2400-$27FF, ShadowToNametable2800Offset -> $2800-$2BFF.
; Вход: NametablePpuOffset без переполнения переводит все четыре shadow-page
; в нужный 1-KiB PPU-диапазон; rendering и NMI выключены, другой код PPU не
; касается, PPU_ADDR latch ожидает high byte. PPU_CTRL должен задавать increment 1
; только для указанного ниже финального VRAM address: размещение каждого байта
; не зависит от increment, потому что адрес задаётся повторно.
; Выход: ScratchPtr=$0800, A=$08, X сохранён, Y=0; Z=1/C=1/N=0 после CMP.
; Перезаписывает выбранные 1024 байта VRAM и меняет PPU_ADDR/PPU_DATA, ScratchPtr
; и flags. Shadow, NametablePpuOffset, PPU queue и остальная RAM сохранены.
; PPU_ADDR latch снова ожидает high byte; при increment 1 внутренний VRAM address
; стоит сразу за последним записанным байтом диапазона.
UploadNametableBuffer:  lda     #$00
        sta     ScratchPtrLo
        tay
        lda     #NametableShadowFirstPage
        sta     ScratchPtrHi
UploadNextNametableShadowByte:
LD7BD:  jsr     UploadShadowByteDirect
        lda     #$01
        jsr     AddAToPointer
        lda     ScratchPtrHi
        cmp     #NametableShadowPastEndPage
        bne     UploadNextNametableShadowByte
        rts

; Готовит shadow игрового поля. Сначала заполняет все $0400-$07FF граничным
; tile TerrainTileBoundary=$11, затем обнуляет attribute table $07C0-$07FF
; и прямоугольник тайлов, обходя его по строкам сверху вниз и внутри строки
; справа налево.
; Вход: NametableRectX=0..31, NametableRectY=0..29, Width/Height ненулевые;
; X+Width<=32 и Y+Height<=30. Эти bounds обязательны: clipping нет, нулевая
; Width начинает запись со смещения $FF, а нулевая Height даёт 256 итераций строк.
; Выход: A=0, X=input NametableRectX, Y=$FF, NametableRectHeight=0;
; ScratchPtr указывает на начало последней очищенной строки, NametableRectX/Y/Width
; сохранены, PpuTileRowBits содержит результат адресации исходной строки.
; Перезаписывает весь NametableShadow и меняет A/X/Y, ScratchPtr,
; NametableRectHeight, PpuTileRowBits и flags; PPU queue/registers и прочую RAM
; не меняет. В tile-части вне прямоугольника остаётся TerrainTileBoundary,
; вся attribute table остаётся нулевой.
InitializePlayfieldShadow:
LD7CC:  ldx     #$00
        lda     #TerrainTileBoundary
FillNextPlayfieldShadowByte:
LD7D0:  sta     NametableShadow,x
        sta     NametableShadowPage1,x
        sta     NametableShadowPage2,x
        sta     NametableShadowPage3,x
        inx
        bne     FillNextPlayfieldShadowByte
        lda     #$00
        ldx     #NametableAttributeStartOffset
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
        lda     #NametableTileRowByteCount
        jsr     AddAToPointer
        jmp     ClearNextNametableRectangleRow

FinishPlayfieldShadowInitialization:
LD80A:  rts
