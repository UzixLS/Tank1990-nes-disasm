; Отрисовка базы и окружающего её материала ($CAF5-$CC26).

BaseEnclosureColumn          = $0C
BaseCoreColumn               = $0E
BaseEnclosureBlankRow        = $18
BaseEnclosureTopRow          = $19
BaseCoreUpperRow             = $1A
BaseCoreLowerRow             = $1B
BaseAttributePpuAddressHi    = $23
BaseAttributePpuAddressLo    = $F3
BaseLowerPreserveMask        = $CC
BareBaseUpperPreserveMask    = $3F
SteelBaseUpperAttribute      = $3F
SteelBaseLowerAttributeBits  = $33

; Рисует четыре $FF-терминированные шеститайловые строки базы и кирпичного
; ограждения, начиная с (BaseEnclosureColumn,BaseEnclosureBlankRow).
; Затем обнуляет часть атрибутов $07F3/$07F4 и ставит два байта в PPU-очередь.
; Входов/регистровых результатов нет. Меняет A/X/Y, ScratchPtr, shadow
; nametable/attributes, PpuBufferPos и PPU update buffer; прямых записей PPU нет.
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

; Общий хвост обновления палитры нижней части базы: BaseAttributeUpper=0,
; в BaseAttributeLower сохраняются только биты BaseLowerPreserveMask. Очередь
; получает адрес $23F3 и два последовательных байта. Это также самостоятельный
; continuation-вход из PowerUpEffect2. Портит A/X и PpuBufferPos; Y сохраняет.
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
        sta     BaseAttributeUpper
        sta     PpuUpdateBuffer,x
        inx
        lda     BaseAttributeLower
        and     #BaseLowerPreserveMask
        sta     BaseAttributeLower
        sta     PpuUpdateBuffer,x
        inx
        lda     #$FF
        sta     PpuUpdateBuffer,x
        inx
        stx     PpuBufferPos
        rts
; Рисует только две центральные строки целой базы без окружающих стен.
; В BaseAttributeUpper сохраняет биты 0..5 маской BareBaseUpperPreserveMask,
; очищая только palette bits 7..6, и ставит этот атрибут в очередь.
; Меняет A/X/Y, ScratchPtr, shadow nametable/attributes и PPU update buffer.
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
        lda     BaseAttributeUpper
        and     #BareBaseUpperPreserveMask
        sta     BaseAttributeUpper
        sta     PpuUpdateBuffer,x
        inx
        lda     #$FF
        sta     PpuUpdateBuffer,x
        inx
        stx     PpuBufferPos
        rts

; Рисует четыре $FF-терминированные шеститайловые строки базы со стальным ограждением.
; Записывает BaseAttributeUpper=$3F; в BaseAttributeLower сохраняет биты $CC
; и устанавливает $33. Оба байта ставятся в PPU-очередь по адресу $23F3.
; Вызывается в том числе при мигании BaseFortificationTimer.
; Меняет A/X/Y, ScratchPtr, shadow nametable/attributes и PPU update buffer.
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
        lda     #SteelBaseUpperAttribute
        sta     BaseAttributeUpper
        sta     PpuUpdateBuffer,x
        inx
        lda     BaseAttributeLower
        and     #BaseLowerPreserveMask
        ora     #SteelBaseLowerAttributeBits
        sta     BaseAttributeLower
        sta     PpuUpdateBuffer,x
        inx
        lda     #$FF
        sta     PpuUpdateBuffer,x
        inx
        stx     PpuBufferPos
        rts

; Заменяет центральные две строки базы изображением разрушенного состояния.
; Стены и атрибуты не меняет. Меняет A/X/Y, ScratchPtr, shadow nametable,
; PpuBufferPos и PPU update buffer; прямых записей PPU нет.
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
