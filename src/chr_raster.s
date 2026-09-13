; Растеризация CHR-тайлов в collision shadow ($D85E-$D8F5).

RasterPixelX      = $5D
RasterPixelY      = $5E
RasterRowCount    = $5A
RasterPlaneByte   = $02
RasterBitMask     = $03
RasterStringIndex = $5F

ChrTileByteSize   = $10
ChrPlaneRowCount  = $08
RasterPixelStep   = $04
RasterTileSpan    = $20
RasterStringTerminator = $FF

; Растрирует первую bitplane 8x8 CHR-тайла в маску низкого ниббла shadow nametable.
; Каждый CHR-пиксель превращается в подобласть 4x4 в shadow; строки обрабатываются
; в обратном порядке из-за временного стека. Вход: A -- номер CHR-тайла в pattern table $1000,
; X/Y -- пиксельная позиция. Читает только first bitplane через
; PPU_DATA; вызывать при отключённом рендеринге. Меняет A/X/Y, ScratchPtr,
; raster/collision scratch и shadow. Перед первым чтением выполняет dummy read,
; затем читает 8 байтов первой bitplane. Покрывает X..X+31 и Y+4..Y+32.
; Стек сбалансирован восемью PHA/PLA. PPU queue не меняет; PPU_ADDR/DATA и
; внутренний VRAM address меняются, write latch после двух PPU_ADDR готов к high byte.
RasterizeChrTileToShadow:
LD85E:  stx     RasterPixelX
        tax
        tya
        clc
        adc     #RasterTileSpan
        sta     RasterPixelY
        lda     #$00
        sta     ScratchPtrLo
        lda     #ChrTileByteSize
        sta     ScratchPtrHi
SeekChrTileAddress:
LD86F:  dex
        bmi     BeginChrTileRead
        lda     #ChrTileByteSize
        jsr     AddAToPointer
        jmp     SeekChrTileAddress

BeginChrTileRead:
LD87A:  lda     ScratchPtrHi
        sta     PPU_ADDR
        lda     ScratchPtrLo
        sta     PPU_ADDR
        lda     PPU_DATA
        lda     #ChrPlaneRowCount
        sta     RasterRowCount
ReadChrPlaneRow:
LD88B:  lda     PPU_DATA
        pha
        dec     RasterRowCount
        bne     ReadChrPlaneRow
        lda     #ChrPlaneRowCount
        sta     RasterRowCount
RasterizeNextChrRow:
LD897:  pla
        sta     RasterPlaneByte
        lda     #$80
        sta     RasterBitMask
RasterizeNextChrPixel:
LD89E:  ldx     RasterPixelX
        ldy     RasterPixelY
        jsr     SelectTerrainSubcell
        lda     RasterPlaneByte
        and     RasterBitMask
        beq     ClearRasterizedSubcell
        jsr     SetTerrainSubcellShadow
        jmp     AdvanceRasterizedPixel

ClearRasterizedSubcell:
LD8B1:  jsr     ClearTerrainSubcellShadow
AdvanceRasterizedPixel:
LD8B4:  lda     RasterPixelX
        clc
        adc     #RasterPixelStep
        sta     RasterPixelX
        lsr     RasterBitMask
        bcc     RasterizeNextChrPixel
        lda     RasterPixelX
        sec
        sbc     #RasterTileSpan
        sta     RasterPixelX
        lda     RasterPixelY
        sec
        sbc     #RasterPixelStep
        sta     RasterPixelY
        dec     RasterRowCount
        bne     RasterizeNextChrRow
        rts

; Рисует в shadow строку крупных 32x32-знаков, растрируя CHR-тайлы.
; Вход: AuxPtr -> $FF-терминированная строка номеров,
; RasterStringX/Y -- позиция, TileTranslationOffset -- смещение номера CHR-тайла.
; Каждый знак сдвигает RasterStringX на $20. Меняет A/X/Y,
; RasterStringX/RasterStringIndex и все
; побочные области RasterizeChrTileToShadow. AuxPtr/RasterStringY и PPU queue
; сохраняются. Выход: A=$FF; Y указывает терминатор, RasterStringX стоит сразу
; после последнего знака; X не определён.
RasterizeTileStringToShadow:
LD8D2:  ldy     #$00
        sty     RasterStringIndex
RasterizeNextStringTile:
LD8D6:  lda     (AuxPtrLo),y
        cmp     #RasterStringTerminator
        beq     FinishRasterizedString
        iny
        sty     RasterStringIndex
        ldx     RasterStringX
        ldy     RasterStringY
        clc
        adc     TileTranslationOffset
        jsr     RasterizeChrTileToShadow
        lda     RasterStringX
        clc
        adc     #RasterTileSpan
        sta     RasterStringX
        ldy     RasterStringIndex
        jmp     RasterizeNextStringTile

FinishRasterizedString:
LD8F5:  rts
