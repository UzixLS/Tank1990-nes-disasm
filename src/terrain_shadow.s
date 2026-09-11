; Адресация и изменение подобластей terrain shadow ($D706-$D7B3).

PpuQueueSavedX = $47

; Переводит пиксельные X/Y в координаты 8x8-тайла, затем устанавливает
; ScratchPtr на соответствующий байт shadow. Выход: ScratchPtr, Y=0; A/X и $00 изменены.
PixelCoordinatesToShadowPointer:
LD706:  jsr     PixelToTileCoordinates
; Альтернативный вход для уже переведённых 8x8-координат X/Y.
TileCoordinatesToShadowPointer:
LD709:  jsr     TileCoordinatesToShadowAddress
        sta     ScratchPtrHi
        sty     ScratchPtrLo
        ldy     #$00
        rts

; Делит пиксельные X/Y на 8. Выход в X/Y; A и флаги изменены.
PixelToTileCoordinates:
LD713:  tya
        lsr     a
        lsr     a
        lsr     a
        tay
        txa
        lsr     a
        lsr     a
        lsr     a
        tax
        rts

; Вычисляет shadow-адрес и один из битов $01/$02/$04/$08 для 4x4-подобласти
; вокруг пиксельной точки X/Y. Вход: X/Y пиксели. Выход: ScratchPtr, Y=0,
; TerrainSubcellMask; исходные координаты сохранены в CollisionPointX/Y. A/X изменены.
SelectTerrainSubcell:
LD71E:  stx     CollisionPointX
        sty     CollisionPointY
        jsr     PixelCoordinatesToShadowPointer
; Вход после SelectTerrainSubcell или прямой: пересчитывает TerrainSubcellMask
; из сохранённых CollisionPointX/Y. ScratchPtr не меняет; портит A и флаги.
RecomputeTerrainSubcellMask:
LD725:  lda     #$01
        sta     TerrainSubcellMask
        lda     CollisionPointY
        and     #$04
        beq     SelectTerrainSubcellXHalf
        asl     TerrainSubcellMask
        asl     TerrainSubcellMask
SelectTerrainSubcellXHalf:
LD733:  lda     CollisionPointX
        and     #$04
        beq     FinishTerrainSubcellMask
        asl     TerrainSubcellMask
FinishTerrainSubcellMask:
LD73B:  rts

; Проверяет выбранную подобласть. Возвращает A=(shadow & ($F0|$00)); Z=1 только
; для пустого низкобитного тайла. ScratchPtr, Y и TerrainSubcellMask заданы ранее.
TestTerrainSubcell:
LD73C:  lda     TerrainSubcellMask
        ora     #$F0
        and     (ScratchPtrLo),y
        rts

; Сбрасывает выбранный бит в shadow и ставит изменённый тайл в PPU-очередь.
; Меняет A и PpuUpdateBuffer/PpuBufferPos; X сохраняется.
ClearTerrainSubcellQueued:
LD743:  lda     TerrainSubcellMask
        eor     #$FF
        and     (ScratchPtrLo),y
        jsr     StoreAndQueueShadowTile
        rts

; Теневой вариант сброса: меняет бит только у тайла с нулевым старшим нибблом;
; PPU-очередь не трогает. Выход A=исходный или изменённый байт.
ClearTerrainSubcellShadow:
LD74D:  lda     (ScratchPtrLo),y
        and     #$F0
        bne     FinishClearTerrainSubcellShadow
        lda     TerrainSubcellMask
        eor     #$FF
        and     (ScratchPtrLo),y
        sta     (ScratchPtrLo),y
FinishClearTerrainSubcellShadow:
LD75B:  rts

; Устанавливает выбранный бит в shadow и ставит изменённый тайл в PPU-очередь.
SetTerrainSubcellQueued:
LD75C:  lda     TerrainSubcellMask
        ora     (ScratchPtrLo),y
        jsr     StoreAndQueueShadowTile
        rts
; Теневой вариант установки: меняет бит только у тайла с нулевым старшим нибблом;
; PPU-очередь не трогает. Выход A=исходный или изменённый байт.
SetTerrainSubcellShadow:
LD764:  lda     (ScratchPtrLo),y
        and     #$F0
        bne     FinishSetTerrainSubcellShadow
        lda     TerrainSubcellMask
        ora     (ScratchPtrLo),y
        sta     (ScratchPtrLo),y
FinishSetTerrainSubcellShadow:
LD770:  rts

; Немедленно копирует один байт (ScratchPtr),Y в PPU-адрес
; (ScratchPtrHi+NametablePpuOffset):ScratchPtrLo. Предполагает отключённый
; рендеринг; меняет A и PPU latch/data.
UploadShadowByteDirect:
LD771:  lda     ScratchPtrHi
        clc
        adc     NametablePpuOffset
        sta     PPU_ADDR
        lda     ScratchPtrLo
        sta     PPU_ADDR
        lda     (ScratchPtrLo),y
        sta     PPU_DATA
        rts

; Пишет A в (ScratchPtr),Y и ставит тот же байт в PPU-очередь. Адрес PPU получается
; из shadow-адреса прибавлением $1C к старшему байту. Формат команды: hi, lo, data, $FF.
; Сохраняет X через PpuQueueSavedX; меняет A и
; PpuUpdateBuffer/PpuBufferPos. Y, ScratchPtr и shadow-байт не меняет.
StoreAndQueueShadowTile:
LD784:  sta     (ScratchPtrLo),y
        stx     PpuQueueSavedX
        ldx     PpuBufferPos
        lda     ScratchPtrHi
        clc
        adc     #$1C
        sta     PpuUpdateBuffer,x
        inx
        lda     ScratchPtrLo
        sta     PpuUpdateBuffer,x
        inx
        lda     (ScratchPtrLo),y
        sta     PpuUpdateBuffer,x
        inx
        lda     #$FF
        sta     PpuUpdateBuffer,x
        inx
        stx     PpuBufferPos
        ldx     PpuQueueSavedX
        rts

; Прибавляет беззнаковый A к 16-битному ScratchPtrHi:ScratchPtrLo.
; Выход: A=новый младший байт указателя; X/Y не меняются.
AddAToPointer:  clc
        adc     ScratchPtrLo
        sta     ScratchPtrLo
        bcc     FinishAddAToPointer
        inc     ScratchPtrHi
FinishAddAToPointer:
LD7B3:  rts
