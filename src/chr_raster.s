; Растеризация CHR-тайлов в collision shadow ($D85E-$D8F5).

RasterPixelX      = $5D
RasterPixelY      = $5E
RasterRowCount    = $5A
RasterPlaneByte   = $02
RasterBitMask     = $03
RasterStringIndex = $5F

ChrTileByteSize   = $10
ChrPatternTableBaseHi = $10
ChrPlaneRowCount  = $08
RasterPixelStep   = $04
RasterTileSpan    = $20
RasterStringTerminator = $FF

; Растрирует первую bitplane одного 8x8 CHR-тайла из pattern table $1000 в
; low-nibble subcells nametable shadow. Каждый входной бит масштабируется в
; квадрат 4x4; нулевой bit очищает, единичный ставит соответствующий subcell.
; Вторая bitplane не читается, поэтому цветовой индекс схлопывается в 1 bpp.
;
; Вход: A=tile $00..$80, X/Y=беззнаковая опорная pixel-позиция. Ограничение
; $80 включительно принципиально: линейный seek использует DEX/BMI, поэтому
; исходные $81..$FF после первого DEX выглядят отрицательными и ошибочно читают
; tile 0. Адрес вычисляется за O(A) сложений по 16, без таблицы/умножения.
; Rendering и NMI должны быть выключены: процедура напрямую меняет PPU_ADDR и
; читает PPU_DATA. Dummy read заполняет PPU read buffer; следующие восемь чтений
; возвращают rows 0..7 первой plane и оставляют внутренний VRAM address=start+9.
;
; Восемь row bytes кладутся на стек и затем снимаются обратно, поэтому rows
; обрабатываются 7..0 в точках Y+32,Y+28,...,Y+4. X-точки идут X..X+28;
; покрытая область subcells соответствует pixels X..X+31 и Y+4..Y+35. Все
; координаты восьмибитные и оборачиваются. Shadow-only helpers изменяют лишь
; bytes с нулевым high nibble; whole-tile terrain/occupancy блокирует пиксель.
;
; Выход: RasterPixelX=input X, RasterPixelY=input Y, RasterRowCount=0,
; RasterBitMask=0, CollisionPointX=input X+28, CollisionPointY=input Y+4,
; Y=0, A=input Y; X указывает 8x8 tile последней точки. ScratchPtr указывает
; тот же последний shadow byte. Z=1/N=0 от финального DEC; C/V зависят от
; координатной арифметики. Меняет raster/collision/address scratch и выбранные
; low-nibble shadow bits; PPU queue не трогает. Восемь PHA/PLA сбалансированы.
RasterizeChrTileToShadow:
LD85E:  stx     RasterPixelX
        tax
        tya
        clc
        adc     #RasterTileSpan
        sta     RasterPixelY
        lda     #$00
        sta     ScratchPtrLo
        lda     #ChrPatternTableBaseHi
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

; Рисует в shadow строку крупных 32x32 монохромных знаков через описанный выше
; 4x raster. Вход: AuxPtr указывает на поток raw tile ids с достижимым $FF в
; пределах 256-byte Y-index, RasterStringX/Y задают начало,
; TileTranslationOffset прибавляется modulo 256 к каждому id уже после проверки
; terminator. Итоговый id каждого знака обязан остаться $00..$80.
;
; После знака RasterStringX увеличивается на 32 modulo 256; clipping строк,
; экрана и attribute storage отсутствует. AuxPtr, RasterStringY и translation
; сохраняются. Меняет RasterStringX/RasterStringIndex, PPU read address/buffer,
; shadow и весь scratch RasterizeChrTileToShadow; PPU queue не трогает.
;
; Выход: A=$FF, Y=offset terminator, RasterStringIndex=тот же offset,
; RasterStringX=input X+32*length modulo 256, Z=1/C=1/N=0; X принадлежит
; последнему знаку (для пустой строки сохраняет вход). Сам $FF отрисовать
; невозможно как raw id, а translation в $FF создаёт недопустимый tile seek.
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
