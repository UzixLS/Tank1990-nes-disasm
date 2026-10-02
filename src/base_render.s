; Отрисовка базы и окружающего её материала ($CAF5-$CC26).

BaseAttributePpuAddressHi    = $23
BaseAttributePpuAddressLo    = $F3
BaseRightOuterQuadrantsPreserveMask = $CC
BareBaseLeftAttributePreserveMask = $3F
SteelBaseLeftAttributeValue       = $3F
SteelBaseRightAttributeBits       = $33
BaseAttributePairQueueBytes       = $05
BaseFullRenderQueueBytes          = $29
BaseBareRenderQueueBytes          = $0E
BaseDestroyedRenderQueueBytes     = $0A
BaseAttributePairQueueMaxStartPos = $7A
BaseFullRenderQueueMaxStartPos    = $56
BaseBareRenderQueueMaxStartPos    = $71
BaseDestroyedQueueMaxStartPos     = $75

; Все tile routines ниже требуют
; NametablePpuOffset=ShadowToPrimaryNametableOffset: QueueTileAtCoordinates
; использует переменный offset, но attribute commands жёстко адресуют $23F3.
; Attribute $23F3/$07F3 покрывает tile columns12..15, rows24..27, а следующий
; byte $23F4/$07F4 — columns16..19 тех же rows. Перенос базы в romhack требует
; согласованно менять geometry constants, адрес обоих attribute bytes, aliases
; BaseAttributeLeft/Right и quadrant masks/values.
;
; Процедуры меняют ScratchPtr/AuxPtr/PpuTileRowBits, shadow и PPU queue;
; capacity кодом не проверяется. Указанные ниже max start positions оставляют
; внутри $0180-$01FF и всю команду, и следующий lookahead flush. NMI не должен
; исполнять очередь посреди построения составного обновления.

; Рисует четыре $FF-терминированные шеститайловые строки базы и кирпичного
; ограждения, начиная с (BaseEnclosureColumn,BaseEnclosureBlankRow).
; Затем полностью записывает BaseAttributeLeft=0, а в BaseAttributeRight
; очищает palette quadrants columns 16..17, сохраняя внешние columns 18..19
; маской BaseRightOuterQuadrantsPreserveMask. Добавляет
; BaseFullRenderQueueBytes (41) byte; на входе PpuBufferPos<=$56.
; DrawBrickBaseEnclosure намеренно проваливается в QueueBrickBaseAttributes.
; Выход: A=$FF, X=PpuBufferPos=old+41, Y=6, N=Z=0/C=1/V=0;
; ScratchPtr=BrickBaseLowerRow, AuxPtr адресует shadow (12,27). Прямых записей
; PPU нет.
DrawBrickBaseEnclosure:
LCAF5:  lda     #>BlankBaseRow
        sta     ScratchPtrHi
        lda     #<BlankBaseRow
        sta     ScratchPtrLo
        ldx     #BaseEnclosureColumn
        ldy     #BaseEnclosureBlankRow
        jsr     QueueTileAtCoordinates
        lda     #>BrickBaseTopRow
        sta     ScratchPtrHi
        lda     #<BrickBaseTopRow
        sta     ScratchPtrLo
        ldx     #BaseEnclosureColumn
        ldy     #BaseEnclosureTopRow
        jsr     QueueTileAtCoordinates
        lda     #>BrickBaseUpperRow
        sta     ScratchPtrHi
        lda     #<BrickBaseUpperRow
        sta     ScratchPtrLo
        ldx     #BaseEnclosureColumn
        ldy     #BaseCoreUpperRow
        jsr     QueueTileAtCoordinates
        lda     #>BrickBaseLowerRow
        sta     ScratchPtrHi
        lda     #<BrickBaseLowerRow
        sta     ScratchPtrLo
        ldx     #BaseEnclosureColumn
        ldy     #BaseCoreLowerRow
        jsr     QueueTileAtCoordinates

; Общий хвост обновления палитры базы: BaseAttributeLeft=0,
; в BaseAttributeRight сохраняются только внешние top-right/bottom-right pairs
; маски BaseRightOuterQuadrantsPreserveMask. Очередь получает [$23,$F3,left,
; right,$FF]. Это также самостоятельный continuation-вход из PowerUpEffect2.
; Вход: PpuBufferPos<=BaseAttributePairQueueMaxStartPos ($7A), C/V передаются
; вызывающим кодом и сохраняются. Выход: A=$FF,
; X=PpuBufferPos=old+BaseAttributePairQueueBytes, Y сохранён; N/Z по итоговому X.
; Меняет оба attribute shadow bytes и пять bytes PPU queue; PPU registers нет.
QueueBrickBaseAttributes:
LCB31:
        ldx     PpuBufferPos
        lda     #BaseAttributePpuAddressHi
        sta     PpuUpdateBuffer,x
        inx
        lda     #BaseAttributePpuAddressLo
        sta     PpuUpdateBuffer,x
        inx
        lda     #$00
        sta     BaseAttributeLeft
        sta     PpuUpdateBuffer,x
        inx
        lda     BaseAttributeRight
        and     #BaseRightOuterQuadrantsPreserveMask
        sta     BaseAttributeRight
        sta     PpuUpdateBuffer,x
        inx
        lda     #$FF
        sta     PpuUpdateBuffer,x
        inx
        stx     PpuBufferPos
        rts
; Рисует только две центральные строки целой базы без окружающих стен.
; В BaseAttributeLeft сохраняет bits0..5, очищая bits7..6 — palette quadrant
; core x14..15/y26..27. Ставит этот byte по $23F3; BaseAttributeRight не меняет.
; Добавляет BaseBareRenderQueueBytes (14) bytes; PpuBufferPos<=$71.
; Выход: A=$FF, X=PpuBufferPos=old+14, Y=2, N=Z=0/C=1/V=0;
; ScratchPtr=IntactBaseLowerTiles, AuxPtr адресует shadow (14,27).
DrawBareBase:
LCB5D:  lda     #>IntactBaseUpperTiles
        sta     ScratchPtrHi
        lda     #<IntactBaseUpperTiles
        sta     ScratchPtrLo
        ldx     #BaseCoreColumn
        ldy     #BaseCoreUpperRow
        jsr     QueueTileAtCoordinates
        lda     #>IntactBaseLowerTiles
        sta     ScratchPtrHi
        lda     #<IntactBaseLowerTiles
        sta     ScratchPtrLo
        ldx     #BaseCoreColumn
        ldy     #BaseCoreLowerRow
        jsr     QueueTileAtCoordinates
        ldx     PpuBufferPos
        lda     #BaseAttributePpuAddressHi
        sta     PpuUpdateBuffer,x
        inx
        lda     #BaseAttributePpuAddressLo
        sta     PpuUpdateBuffer,x
        inx
        lda     BaseAttributeLeft
        and     #BareBaseLeftAttributePreserveMask
        sta     BaseAttributeLeft
        sta     PpuUpdateBuffer,x
        inx
        lda     #$FF
        sta     PpuUpdateBuffer,x
        inx
        stx     PpuBufferPos
        rts

; Рисует четыре $FF-терминированные шеститайловые строки базы со стальным ограждением.
; Записывает BaseAttributeLeft=$3F: три enclosure quadrants получают palette3,
; а core quadrant остаётся palette0. В BaseAttributeRight сохраняет внешние
; quadrants columns18..19 и устанавливает $33 для enclosure columns16..17.
; Оба bytes ставятся в PPU-очередь по адресу $23F3.
; Вызывается в том числе при мигании BaseFortificationTimer.
; Добавляет BaseFullRenderQueueBytes (41) byte; PpuBufferPos<=$56.
; Выход: A=$FF, X=PpuBufferPos=old+41, Y=6, N=Z=0/C=1/V=0;
; ScratchPtr=SteelBaseLowerRow, AuxPtr адресует shadow (12,27).
DrawSteelBaseEnclosure:
LCB9E:  lda     #>BlankSteelBaseRow
        sta     ScratchPtrHi
        lda     #<BlankSteelBaseRow
        sta     ScratchPtrLo
        ldx     #BaseEnclosureColumn
        ldy     #BaseEnclosureBlankRow
        jsr     QueueTileAtCoordinates
        lda     #>SteelBaseTopRow
        sta     ScratchPtrHi
        lda     #<SteelBaseTopRow
        sta     ScratchPtrLo
        ldx     #BaseEnclosureColumn
        ldy     #BaseEnclosureTopRow
        jsr     QueueTileAtCoordinates
        lda     #>SteelBaseUpperRow
        sta     ScratchPtrHi
        lda     #<SteelBaseUpperRow
        sta     ScratchPtrLo
        ldx     #BaseEnclosureColumn
        ldy     #BaseCoreUpperRow
        jsr     QueueTileAtCoordinates
        lda     #>SteelBaseLowerRow
        sta     ScratchPtrHi
        lda     #<SteelBaseLowerRow
        sta     ScratchPtrLo
        ldx     #BaseEnclosureColumn
        ldy     #BaseCoreLowerRow
        jsr     QueueTileAtCoordinates
        ldx     PpuBufferPos
        lda     #BaseAttributePpuAddressHi
        sta     PpuUpdateBuffer,x
        inx
        lda     #BaseAttributePpuAddressLo
        sta     PpuUpdateBuffer,x
        inx
        lda     #SteelBaseLeftAttributeValue
        sta     BaseAttributeLeft
        sta     PpuUpdateBuffer,x
        inx
        lda     BaseAttributeRight
        and     #BaseRightOuterQuadrantsPreserveMask
        ora     #SteelBaseRightAttributeBits
        sta     BaseAttributeRight
        sta     PpuUpdateBuffer,x
        inx
        lda     #$FF
        sta     PpuUpdateBuffer,x
        inx
        stx     PpuBufferPos
        rts

; Заменяет центральные две строки базы изображением разрушенного состояния.
; Стены и attributes не меняет. Добавляет BaseDestroyedRenderQueueBytes (10)
; bytes; PpuBufferPos<=BaseDestroyedQueueMaxStartPos ($75).
; Выход: A=$FF, X=PpuBufferPos=old+10, Y=2, N=0/Z=1/C=1/V=0;
; ScratchPtr=DestroyedBaseLowerTiles, AuxPtr адресует shadow (14,27).
; Прямых записей PPU нет.
DrawDestroyedBase:
LCC08:  lda     #>DestroyedBaseUpperTiles
        sta     ScratchPtrHi
        lda     #<DestroyedBaseUpperTiles
        sta     ScratchPtrLo
        ldx     #BaseCoreColumn
        ldy     #BaseCoreUpperRow
        jsr     QueueTileAtCoordinates
        lda     #>DestroyedBaseLowerTiles
        sta     ScratchPtrHi
        lda     #<DestroyedBaseLowerTiles
        sta     ScratchPtrLo
        ldx     #BaseCoreColumn
        ldy     #BaseCoreLowerRow
        jsr     QueueTileAtCoordinates
        rts
