; Адресация и изменение подобластей terrain shadow ($D706-$D7B3).

ShadowQueueSavedX = $47

; Переводит пиксельные X/Y в координаты 8x8-тайла, затем устанавливает
; ScratchPtr на соответствующий байт shadow. Выход: ScratchPtr, Y=0;
; X=floor(input X/8), A=старший байт shadow. Меняет PpuTileRowBits и flags;
; shadow/PPU queue/registers не трогает.
PixelCoordinatesToShadowPointer:
LD706:  jsr     PixelToTileCoordinates
; Альтернативный вход для уже переведённых 8x8-координат X/Y.
TileCoordinatesToShadowPointer:
LD709:  jsr     TileCoordinatesToShadowAddress
        sta     ScratchPtrHi
        sty     ScratchPtrLo
        ldy     #$00
        rts

; Делит беззнаковые пиксельные X/Y на 8. Выход в X/Y, A=X; RAM сохраняет,
; flags соответствуют последнему LSR.
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
; TerrainSubcellMask; исходные координаты сохранены в CollisionPointX/Y.
; X=floor(input X/8), A=(CollisionPointX & $04); shadow/PPU не меняет.
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

; Проверяет выбранную подобласть. Возвращает
; A=(shadow & ($F0|TerrainSubcellMask)); Z=1 только
; для пустого низкобитного тайла. ScratchPtr, Y и TerrainSubcellMask заданы ранее.
TestTerrainSubcell:
LD73C:  lda     TerrainSubcellMask
        ora     #$F0
        and     (ScratchPtrLo),y
        rts

; Сбрасывает выбранный бит в shadow и ставит изменённый тайл в PPU-очередь.
; Выход: A=$FF; X/Y и ScratchPtr сохраняются. Меняет shadow, PPU queue,
; ShadowQueueSavedX и flags; PPU registers не трогает.
ClearTerrainSubcellQueued:
LD743:  lda     TerrainSubcellMask
        eor     #$FF
        and     (ScratchPtrLo),y
        jsr     StoreAndQueueShadowTile
        rts

; Теневой вариант сброса: меняет бит только у тайла с нулевым старшим нибблом;
; PPU-очередь не трогает. Выход: для low-nibble terrain A=записанный байт;
; для прочих классов A=исходный старший ниббл, shadow без изменений.
; X/Y/ScratchPtr сохраняются; PPU queue/registers не меняются.
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
; Контракт выхода и побочные эффекты совпадают с ClearTerrainSubcellQueued.
SetTerrainSubcellQueued:
LD75C:  lda     TerrainSubcellMask
        ora     (ScratchPtrLo),y
        jsr     StoreAndQueueShadowTile
        rts
; Теневой вариант установки: меняет бит только у тайла с нулевым старшим нибблом;
; PPU-очередь не трогает. Контракт выхода совпадает с
; ClearTerrainSubcellShadow; устанавливается, а не сбрасывается выбранный бит.
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
; рендеринг и write latch в состоянии первого PPU_ADDR write.
; Выход: A=переданный byte, X/Y/ScratchPtr и RAM сохранены. Меняет PPU_ADDR/
; PPU_DATA; внутренний VRAM address после записи указывает на следующий байт.
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
; из shadow-адреса прибавлением ShadowToPrimaryNametableOffset к high byte.
; Формат команды: hi, lo, data, $FF.
; Выход: A=$FF; X/Y и ScratchPtr сохраняются. Меняет выбранный shadow-байт,
; ShadowQueueSavedX и PPU queue; PPU registers не трогает. Capacity не проверяет.
StoreAndQueueShadowTile:
LD784:  sta     (ScratchPtrLo),y
        stx     ShadowQueueSavedX
        ldx     PpuBufferPos
        lda     ScratchPtrHi
        clc
        adc     #ShadowToPrimaryNametableOffset
        sta     PpuUpdateBuffer,x
        inx
        lda     ScratchPtrLo
        sta     PpuUpdateBuffer,x
        inx
        lda     (ScratchPtrLo),y
        sta     PpuUpdateBuffer,x
        inx
        lda     #PpuQueueTerminator
        sta     PpuUpdateBuffer,x
        inx
        stx     PpuBufferPos
        ldx     ShadowQueueSavedX
        rts

; Прибавляет беззнаковый A к 16-битному ScratchPtrHi:ScratchPtrLo.
; Выход: A=новый младший байт указателя, C=1 при переходе страницы; X/Y
; сохраняются. Меняет ScratchPtr и N/Z/C.
AddAToPointer:  clc
        adc     ScratchPtrLo
        sta     ScratchPtrLo
        bcc     FinishAddAToPointer
        inc     ScratchPtrHi
FinishAddAToPointer:
LD7B3:  rts
