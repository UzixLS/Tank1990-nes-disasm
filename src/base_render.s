; Отрисовка базы и окружающего её материала ($CAF5-$CC26).

; Рисует четыре семитайловые строки базы и кирпичного ограждения в ($0C,$18).
; Затем обнуляет часть атрибутов $07F3/$07F4 и ставит два байта в PPU-очередь.
; Меняет A/X/Y, ScratchPtr, shadow nametable/attributes и PPU-очередь.
DrawBrickBaseEnclosure:
LCAF5:  lda     #>BlankBaseRow
        sta     ScratchPtrHi
        lda     #<BlankBaseRow
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$18
        jsr     QueueTileAtCoordinates
        lda     #>BrickBaseTopRow
        sta     ScratchPtrHi
        lda     #<BrickBaseTopRow
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$19
        jsr     QueueTileAtCoordinates
        lda     #>BrickBaseUpperRow
        sta     ScratchPtrHi
        lda     #<BrickBaseUpperRow
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$1A
        jsr     QueueTileAtCoordinates
        lda     #>BrickBaseLowerRow
        sta     ScratchPtrHi
        lda     #<BrickBaseLowerRow
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$1B
        jsr     QueueTileAtCoordinates

; Общий хвост обновления палитры нижней части базы: BaseAttributeUpper=0,
; в BaseAttributeLower сохраняются только биты $CC. Очередь получает адрес $23F3 и два байта.
QueueBrickBaseAttributes:
LCB31:
        ldx     PpuBufferPos
        lda     #$23
        sta     PpuUpdateBuffer,x
        inx
        lda     #$F3
        sta     PpuUpdateBuffer,x
        inx
        lda     #$00
        sta     BaseAttributeUpper
        sta     PpuUpdateBuffer,x
        inx
        lda     BaseAttributeLower
        and     #$CC
        sta     BaseAttributeLower
        sta     PpuUpdateBuffer,x
        inx
        lda     #$FF
        sta     PpuUpdateBuffer,x
        inx
        stx     PpuBufferPos
        rts
; Рисует только две центральные строки целой базы без окружающих стен.
; Очищает верхнюю пару палитр в BaseAttributeUpper маской $3F и ставит атрибут в очередь.
; Меняет A/X/Y, ScratchPtr, shadow nametable/attributes и PPU-очередь.
DrawBareBase:
LCB5D:  lda     #>IntactBaseUpperTiles
        sta     ScratchPtrHi
        lda     #<IntactBaseUpperTiles
        sta     ScratchPtrLo
        ldx     #$0E
        ldy     #$1A
        jsr     QueueTileAtCoordinates
        lda     #>IntactBaseLowerTiles
        sta     ScratchPtrHi
        lda     #<IntactBaseLowerTiles
        sta     ScratchPtrLo
        ldx     #$0E
        ldy     #$1B
        jsr     QueueTileAtCoordinates
        ldx     PpuBufferPos
        lda     #$23
        sta     PpuUpdateBuffer,x
        inx
        lda     #$F3
        sta     PpuUpdateBuffer,x
        inx
        lda     BaseAttributeUpper
        and     #$3F
        sta     BaseAttributeUpper
        sta     PpuUpdateBuffer,x
        inx
        lda     #$FF
        sta     PpuUpdateBuffer,x
        inx
        stx     PpuBufferPos
        rts

; Рисует четыре семитайловые строки базы со стальным ограждением.
; Устанавливает соответствующие палитровые поля BaseAttributeUpper/Lower и ставит их в очередь.
; Вызывается в том числе при мигании заканчивающегося защитного эффекта $45.
; Меняет A/X/Y, ScratchPtr, shadow nametable/attributes и PPU-очередь.
DrawSteelBaseEnclosure:
LCB9E:  lda     #>BlankSteelBaseRow
        sta     ScratchPtrHi
        lda     #<BlankSteelBaseRow
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$18
        jsr     QueueTileAtCoordinates
        lda     #>SteelBaseTopRow
        sta     ScratchPtrHi
        lda     #<SteelBaseTopRow
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$19
        jsr     QueueTileAtCoordinates
        lda     #>SteelBaseUpperRow
        sta     ScratchPtrHi
        lda     #<SteelBaseUpperRow
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$1A
        jsr     QueueTileAtCoordinates
        lda     #>SteelBaseLowerRow
        sta     ScratchPtrHi
        lda     #<SteelBaseLowerRow
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$1B
        jsr     QueueTileAtCoordinates
        ldx     PpuBufferPos
        lda     #$23
        sta     PpuUpdateBuffer,x
        inx
        lda     #$F3
        sta     PpuUpdateBuffer,x
        inx
        lda     #$3F
        sta     BaseAttributeUpper
        sta     PpuUpdateBuffer,x
        inx
        lda     BaseAttributeLower
        and     #$CC
        ora     #$33
        sta     BaseAttributeLower
        sta     PpuUpdateBuffer,x
        inx
        lda     #$FF
        sta     PpuUpdateBuffer,x
        inx
        stx     PpuBufferPos
        rts

; Заменяет центральные две строки базы изображением разрушенного состояния.
; Стены и атрибуты не меняет. Меняет A/X/Y, ScratchPtr, shadow и PPU-очередь.
DrawDestroyedBase:
LCC08:  lda     #>DestroyedBaseUpperTiles
        sta     ScratchPtrHi
        lda     #<DestroyedBaseUpperTiles
        sta     ScratchPtrLo
        ldx     #$0E
        ldy     #$1A
        jsr     QueueTileAtCoordinates
        lda     #>DestroyedBaseLowerTiles
        sta     ScratchPtrHi
        lda     #<DestroyedBaseLowerTiles
        sta     ScratchPtrLo
        ldx     #$0E
        ldy     #$1B
        jsr     QueueTileAtCoordinates
        rts
