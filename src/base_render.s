; Отрисовка базы и окружающего её материала ($CAF5-$CC26).

BaseAttributePpuAddressHi    = $23
BaseAttributePpuAddressLo    = $F3
BaseRightAttributePreserveMask    = $CC
BareBaseLeftAttributePreserveMask = $3F
SteelBaseLeftAttributeValue       = $3F
SteelBaseRightAttributeBits       = $33

; Все tile routines ниже требуют
; NametablePpuOffset=ShadowToPrimaryNametableOffset: QueueTileAtCoordinates
; использует переменный offset, но attribute commands жёстко адресуют $23F3.
; Они меняют ScratchPtr/AuxPtr/PpuTileRowBits, shadow и PPU queue; capacity
; update buffer не проверяется вызываемыми helpers.

; Рисует четыре $FF-терминированные шеститайловые строки базы и кирпичного
; ограждения, начиная с (BaseEnclosureColumn,BaseEnclosureBlankRow).
; Затем полностью записывает BaseAttributeLeft=0, а в BaseAttributeRight
; очищает palette quadrants columns 16..17, сохраняя внешние columns 18..19
; маской BaseRightAttributePreserveMask. Добавляет 41 byte в PPU queue.
; DrawBrickBaseEnclosure намеренно проваливается в QueueBrickBaseAttributes.
; Входов/регистровых результатов нет; прямых записей PPU нет.
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
; в BaseAttributeRight сохраняются только биты BaseRightAttributePreserveMask. Очередь
; получает адрес $23F3 и два последовательных байта. Это также самостоятельный
; continuation-вход из PowerUpEffect2. Требует 5 свободных bytes. Выход:
; A=$FF, X=PpuBufferPos, Y сохраняется; меняет attributes и PPU queue.
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
        and     #BaseRightAttributePreserveMask
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
; Добавляет 14 bytes в PPU queue, capacity не проверяет.
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
; Добавляет 41 byte в PPU queue, capacity не проверяет.
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
        and     #BaseRightAttributePreserveMask
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
; Стены и атрибуты не меняет. Добавляет 10 bytes в PPU queue, capacity не
; проверяет; прямых записей PPU нет.
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
