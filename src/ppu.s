; NMI, PPU-очередь, OAM и отрисовка метатайлов ($D400-$DB0A).
;
; Теневая nametable занимает $0400-$07FF. Для игрового поля
; её байты одновременно служат номерами фоновых тайлов и битовой
; маской четырёх подобластей 4x4 пикселя. Это позволяет одним байтом
; обслуживать и коллизии, и частичное разрушение кирпича.

MetatileIndex       = $00
MetatileTileX       = $47
MetatileTileY       = $48

; Те же scratch-байты имеют разные непересекающиеся времена жизни.
PpuTileRowBits            = $00
PpuAttributeRowOffset     = $00
PpuAttributePreserveMask  = $01
PpuAttributePaletteBits   = $02
PpuControllerBits         = $00
PpuQueueSavedX            = $47
RasterPixelX              = $5D
RasterPixelY              = $5E
RasterRowCount            = $5A
RasterPlaneByte           = $02
RasterBitMask             = $03
RasterStringIndex         = $5F
OamSavedX                 = $47
OamSavedY                 = $48
OamPairX                  = $54
OamPairY                  = $55

; Кадровый NMI:
;   1. копирует OAM shadow страницы $02 через DMA;
;   2. исполняет накопленную PPU-очередь и, если $4D >= 0, меняет фоновую палитру;
;   3. восстанавливает PPU_CTRL/scroll/mask, читает ввод, обновляет OAM и звук;
;   4. увеличивает FrameCounter и медленный счётчик $0A раз в 64 кадра.
; Сохраняет A/X/Y и флаги прерванного кода. Меняет PPU/APU/OAM и указанные
; кадровые переменные; буфер PPU после сброса считается свободным.
NmiHandler:
        pha
        txa
        pha
        tya
        pha
        php
        lda     #$00
        sta     OAM_ADDR
        lda     #$02
        sta     OAM_DMA
        lda     PPU_STATUS
        jsr     FlushPpuUpdateBuffer
        lda     BackgroundPaletteIndex
        bmi     RestoreNmiDisplayState
        jsr     UploadBackgroundPalette
RestoreNmiDisplayState:
LD41D:  lda     NametableBits
        ora     #$B0
        sta     PPU_CTRL
        lda     #$00
        sta     PPU_SCROLL
        lda     VerticalScroll
        sta     PPU_SCROLL
        lda     #$1E
        sta     PPU_MASK
        jsr     ReadControllers
        jsr     FinishAlternatingOamFrame
        jsr     UpdateAudioEngine
        inc     FrameCounter
        lda     FrameCounter
        and     #$3F
        bne     RestoreNmiRegisters
        inc     SlowFrameCounter
RestoreNmiRegisters:
LD446:  plp
        pla
        tay
        pla
        tax
        pla
        rti

; Обновляет псевдослучайное состояние в $0F/$10, сохраняя X.
; Возвращает новый байт в A; Y не меняет. Подмешивает $0A и байт
; нулевой страницы с индексом из растущего $10.
NextRandomByte:  txa
        pha
        lda     RandomState
        asl     a
        asl     a
        asl     a
        sec
        sbc     RandomState
        clc
        adc     SlowFrameCounter
        inc     RandomIndex
        ldx     RandomIndex
        adc     $00,x
        sta     RandomState
        pla
        tax
        lda     RandomState
        rts

; Дожидается vblank и включает NMI с pattern table $1000.
; Побочно: чтение PPU_STATUS сбрасывает latch $2005/$2006; A и флаги изменены.
EnableNmiAfterVblank:
LD467:  jsr     WaitForVblankStart
        lda     #$B0
        sta     PPU_CTRL
        rts

; На границе кадра отключает NMI и основной рендеринг. Это режим для
; длинных прямых записей в PPU. Меняет A и PPU_CTRL/PPU_MASK.
DisableRenderingForBulkUpdate:
LD470:  jsr     WaitForNextFrame
        lda     #$10
        sta     PPU_CTRL
        lda     #$06
        sta     PPU_MASK
        rts

; Очищает теневую nametable в RAM $0400-$07FF.
; Выход: A=0, X=0; Y не меняет.
ClearNametableBuffer:  lda     #$00
        tax
ClearNextNametableShadowByte:
LD481:  sta     NametableShadow,x
        sta     NametableShadowPage1,x
        sta     NametableShadowPage2,x
        sta     NametableShadowPage3,x
        inx
        bne     ClearNextNametableShadowByte
        rts

; Общая инициализация PPU/OAM-очереди, счётчиков, записей счёта и звука.
; Очищает $0400-$07FF, загружает палитры и обе nametable ($2000 и $2400).
; 16 байт кода от LC040 служат RAM-маркером: при несовпадении однократно
; вызывает BootHook, после чего обновляет маркер. Почти вся рабочая RAM и A/X/Y
; могут измениться; вызывать только из кода сброса/полного перезапуска состояния.
InitializeCoreRuntime:
LD491:
        lda     #$00
        sta     TileTranslationOffset
        sta     DigitBlankMode
        sta     PpuBufferPos
        sta     OamBufferPos
        sta     PauseState
        lda     #$FF
        sta     BackgroundPaletteIndex
        jsr     UploadInitialPalettes
        lda     #$04
        sta     OamBufferStep
        lda     #$20
        sta     SpriteBehindTerrainMask
        jsr     ClearNametableBuffer
        jsr     FinishAlternatingOamFrame
        ldx     #$15
        jsr     ResetEightByteRecord
        ldx     #$1D
        jsr     ResetEightByteRecord
        jsr     HasRestartSignature
        bne     UploadInitialNametables
        ldx     #$3D
        jsr     BootHook
        lda     #$02
        sta     HighScore+2
        lda     #$00
        sta     MenuSelection
UploadInitialNametables:
LD4CE:  lda     #$1C
        sta     NametablePpuOffset
        jsr     UploadNametableBuffer
        lda     #$24
        sta     NametablePpuOffset
        jsr     UploadNametableBuffer
        jsr     StoreRestartSignature
        jsr     ResetAudioEngine
        rts

; Копирует 16-байтный ROM-маркер LC040 в RestartSignature.
; Выход: X=$FF; A=первый байт маркера.
StoreRestartSignature:
LD4E3:  ldx     #$0F
StoreNextRestartSignatureByte:
LD4E5:  lda     LC040,x
        sta     RestartSignature,x
        dex
        bpl     StoreNextRestartSignatureByte
        rts

; Сравнивает RestartSignature с ROM-маркером LC040.
; Возвращает A=1 при полном совпадении, иначе A=0; X указывает на место расхождения.
HasRestartSignature:
LD4EF:  ldx     #$0F
CompareNextRestartSignatureByte:
LD4F1:  lda     RestartSignature,x
        cmp     LC040,x
        bne     ReturnRestartSignatureMismatch
        dex
        bpl     CompareNextRestartSignatureByte
        lda     #$01
        rts

ReturnRestartSignatureMismatch:
LD4FF:  lda     #$00
        rts

; Дожидается vblank и пишет обе 16-байтные палитры. Фон выбирает набор 0.
; Меняет A/X/Y, PPU_ADDR/PPU_DATA и ставит $4D=$FF.
UploadInitialPalettes:
LD502:  jsr     WaitForVblankStart
        jsr     UploadSpritePalette
        lda     #$00
        jsr     UploadBackgroundPalette
        rts

; A выбирает один из 16-байтовых наборов фоновой палитры.
; Выход: X на байте сразу за набором, Y=0, A=0, $4D=$FF.
; Побочно: перезаписывает $3F00-$3F0F; заключительная последовательность адресов
; оставляет внутренний VRAM-адрес PPU равным $0000.
UploadBackgroundPalette:
LD50E:  asl     a
        asl     a
        asl     a
        asl     a
        tax
        ldy     #$10
        lda     #$3F
        sta     PPU_ADDR
        lda     #$00
        sta     PPU_ADDR
UploadNextBackgroundPaletteByte:
LD51F:  lda     BackgroundPaletteSets,x
        sta     PPU_DATA
        inx
        dey
        bne     UploadNextBackgroundPaletteByte
        lda     #$FF
        sta     BackgroundPaletteIndex
        lda     #$3F
        sta     PPU_ADDR
        lda     #$00
        sta     PPU_ADDR
        sta     PPU_ADDR
        sta     PPU_ADDR
        rts

; Загружает постоянную 16-байтовую палитру спрайтов в $3F10.
; Выход: X=$10, Y=0; A равен последнему байту палитры. Меняет PPU address latch/data.
UploadSpritePalette:
LD53E:  ldx     #$00
        ldy     #$10
        lda     #$3F
        sta     PPU_ADDR
        sty     PPU_ADDR
UploadNextSpritePaletteByte:
LD54A:  lda     SpritePalette,x
        sta     PPU_DATA
        inx
        dey
        bne     UploadNextSpritePaletteByte
        rts

SpritePalette:
LD555:  .incbin "../build/sprite-palette.bin"
BackgroundPaletteSets:
LD565:  .incbin "../build/background-palettes.bin"
; Активно ждёт установки vblank в PPU_STATUS.
; Выход: A с установленным битом 7; X/Y не меняются. Чтение сбрасывает vblank и latch.
WaitForVblankStart:
WaitForVblankPoll:
LD5F5:  lda     PPU_STATUS
        bpl     WaitForVblankPoll
        rts

; Преобразует координаты тайла X=0..31, Y=0..31 в адрес shadow nametable:
;   A = $04 + Y / 8, Y = X + (Y & 7) * 32.
; Меняет A/Y и PpuTileRowBits; X сохраняет.
TileCoordinatesToShadowAddress:
LD5FB:  lda     #$00
        sta     PpuTileRowBits
        tya
        lsr     a
        ror     PpuTileRowBits
        lsr     a
        ror     PpuTileRowBits
        lsr     a
        ror     PpuTileRowBits
        pha
        txa
        ora     PpuTileRowBits
        tay
        pla
        ora     #$04
        rts

; Обновляет атрибут палитры для тайла X/Y и добавляет однобайтовую
; запись $23C0+index в PPU-очередь. Вход: X/Y -- координаты 8x8-тайла,
; RenderAttributes -- палитра 0..3.
; Побочно: меняет attribute scratch, NametableAttributes,
; PpuUpdateBuffer/PpuBufferPos; A/X/Y изменены.
QueueAttributeByteForTile:
LD612:  jsr     UpdateAttributeShadow
        ldx     PpuBufferPos
        lda     #$23
        sta     PpuUpdateBuffer,x
        inx
        tya
        clc
        adc     #$C0
        sta     PpuUpdateBuffer,x
        inx
        lda     NametableAttributes,y
        sta     PpuUpdateBuffer,x
        inx
        lda     #$FF
        sta     PpuUpdateBuffer,x
        inx
        stx     PpuBufferPos
        rts

; Вставляет два бита RenderAttributes в нужный квадрант attribute byte.
; Вход: X/Y -- координаты 8x8-тайла. Выход: Y -- индекс attribute table, A -- новый байт.
UpdateAttributeShadow:
LD635:  lda     RenderAttributes
        jsr     ExpandPaletteBits
        jsr     ExpandPaletteBits
        jsr     ExpandPaletteBits
        sta     PpuAttributePaletteBits
        tya
        and     #$02
        bne     SelectBottomAttributeQuadrant
        txa
        and     #$02
        beq     SelectTopLeftAttributeQuadrant
        lda     #$F3
        jmp     ApplyAttributeQuadrant

SelectTopLeftAttributeQuadrant:
LD651:  lda     #$FC
        jmp     ApplyAttributeQuadrant

SelectBottomAttributeQuadrant:
LD656:  txa
        and     #$02
        beq     SelectBottomLeftAttributeQuadrant
        lda     #$3F
        jmp     ApplyAttributeQuadrant

SelectBottomLeftAttributeQuadrant:
LD660:  lda     #$CF
ApplyAttributeQuadrant:
LD662:  sta     PpuAttributePreserveMask
        tya
        asl     a
        and     #$F8
        sta     PpuAttributeRowOffset
        txa
        lsr     a
        lsr     a
        clc
        adc     PpuAttributeRowOffset
        tay
        lda     PpuAttributePreserveMask
        eor     #$FF
        and     PpuAttributePaletteBits
        sta     PpuAttributePaletteBits
        lda     NametableAttributes,y
        and     PpuAttributePreserveMask
        ora     PpuAttributePaletteBits
        sta     NametableAttributes,y
        rts

; Один шаг A=(A*4)|RenderAttributes. Три вызова размножают двухбитовую палитру
; по всем четырём квадрантам attribute byte. Меняет A/флаги.
ExpandPaletteBits:
LD684:  asl     a
        asl     a
        ora     RenderAttributes
        rts

; Последовательно читает оба контроллера. $06/$07 -- текущее состояние,
; $08/$09 -- фронты вновь нажатых кнопок. Биты собираются в NES-порядке A..Right через ROR.
; Меняет A/X/Y, PpuControllerBits и strobes JOY1;
; по выходу X=$FF, Y=0.
ReadControllers:  ldx     #$01
        stx     JOY1
        ldy     #$00
        sty     JOY1
ReadNextController:
LD693:  sty     PpuControllerBits
        ldy     #$08
ReadNextControllerBit:
LD697:  lda     JOY1,x
        and     #$03
        cmp     #$01
        ror     PpuControllerBits
        dey
        bne     ReadNextControllerBit
        lda     Joy1Held,x
        eor     #$FF
        and     PpuControllerBits
        sta     Joy1Pressed,x
        lda     PpuControllerBits
        sta     Joy1Held,x
        dex
        bpl     ReadNextController
        rts

; Копирует $FF-терминированную строку тайлов в PPU-очередь и зеркалит её
; в shadow nametable. Вход: ScratchPtr -> строка, X/Y -- колонка/строка;
; NametablePpuOffset — разность между старшим байтом shadow ($04..) и PPU
; ($20..). Терминатор в shadow не пишется.
; Побочно: AuxPtr становится адресом shadow; меняет A/X/Y, $00, PpuUpdateBuffer/PpuBufferPos.
QueueTileAtCoordinates:  jsr     TileCoordinatesToShadowAddress
        sta     AuxPtrHi
        clc
        adc     NametablePpuOffset
        ldx     PpuBufferPos
        sta     PpuUpdateBuffer,x
        inx
        tya
        sta     PpuUpdateBuffer,x
        inx
        sta     AuxPtrLo
        ldy     #$00
QueueNextShadowedStringByte:
LD6CA:  lda     (ScratchPtrLo),y
        sta     PpuUpdateBuffer,x
        inx
        cmp     #$FF
        beq     FinishShadowedStringQueue
        sta     (AuxPtrLo),y
        iny
        jmp     QueueNextShadowedStringByte

FinishShadowedStringQueue:
LD6DA:  stx     PpuBufferPos
        rts

; Добавляет в PPU-очередь строку без изменения shadow nametable.
; Для каждого байта < $80 прибавляет tile bias $60; управляющие байты >= $80,
; включая $FF-терминатор, копируются без сдвига. Вход: ScratchPtr, X/Y,
; NametablePpuOffset и TileTranslationOffset.
; Побочно: A/X/Y, $00, PpuUpdateBuffer/PpuBufferPos.
QueueTranslatedTileString:
LD6DD:  jsr     TileCoordinatesToShadowAddress
        clc
        adc     NametablePpuOffset
        ldx     PpuBufferPos
        sta     PpuUpdateBuffer,x
        inx
        tya
        sta     PpuUpdateBuffer,x
        inx
        ldy     #$00
QueueNextTranslatedStringByte:
LD6F0:  lda     (ScratchPtrLo),y
        bmi     StoreTranslatedStringByte
        clc
        adc     TileTranslationOffset
StoreTranslatedStringByte:
LD6F7:  sta     PpuUpdateBuffer,x
        inx
        cmp     #$FF
        beq     FinishTranslatedStringQueue
        iny
        jmp     QueueNextTranslatedStringByte

FinishTranslatedStringQueue:
LD703:  stx     PpuBufferPos
        rts

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

; Передаёт всю теневую nametable $0400-$07FF в PPU. NametablePpuOffset задаёт
; смещение старшего байта (обычно $1C для $2000 или $20 для $2400).
; Предполагает отключённый рендеринг. Выход: ScratchPtr=$0800, Y=0; A и PPU latch/data изменены.
UploadNametableBuffer:  lda     #$00
        sta     ScratchPtrLo
        tay
        lda     #$04
        sta     ScratchPtrHi
UploadNextNametableShadowByte:
LD7BD:  jsr     UploadShadowByteDirect
        lda     #$01
        jsr     AddAToPointer
        lda     ScratchPtrHi
        cmp     #$08
        bne     UploadNextNametableShadowByte
        rts

; Готовит shadow nametable для игрового поля: заполняет её тайлом $11,
; обнуляет NametableAttributes и затем очищает прямоугольник по нулевым тайлам.
; Вход: NametableRectX/Y -- начало в тайлах, NametableRectHeight/Width -- размер.
; Нулевая высота или ширина не поддерживаются. Меняет A/X/Y, ScratchPtr,
; MetatileIndex и NametableRectHeight.
InitializePlayfieldShadow:
LD7CC:  ldx     #$00
        lda     #$11
FillNextPlayfieldShadowByte:
LD7D0:  sta     NametableShadow,x
        sta     NametableShadowPage1,x
        sta     NametableShadowPage2,x
        sta     NametableShadowPage3,x
        inx
        bne     FillNextPlayfieldShadowByte
        lda     #$00
        ldx     #$C0
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
        lda     #$20
        jsr     AddAToPointer
        jmp     ClearNextNametableRectangleRow

FinishPlayfieldShadowInitialization:
LD80A:  rts

; Рисует TSA-блок 2x2 тайла и обновляет его атрибут палитры.
; Вход: A -- индекс метатайла 0..15, X/Y -- пиксельные координаты. Процедура
; сама выравнивает полученные тайловые координаты на ячейку 16x16 пикселей.
; Пишет четыре тайла в shadow и четыре PPU-команды, а также одну команду атрибута.
; Меняет A/X/Y, ScratchPtr, MetatileIndex/MetatileTileX/Y, RenderAttributes,
; прочую scratch-RAM $01-$03, attribute shadow и PPU-очередь.
DrawMetatile:  pha
        sta     MetatileIndex
        jsr     PixelToTileCoordinates
        stx     MetatileTileX
        sty     MetatileTileY
        ldy     MetatileIndex
        lda     MetatilePalettes,y
        sta     RenderAttributes
        ldy     MetatileTileY
        jsr     QueueAttributeByteForTile
        lda     MetatileTileY
        and     #$FE
        tay
        lda     MetatileTileX
        and     #$FE
        tax
        jsr     TileCoordinatesToShadowPointer
        pla
        asl     a
        asl     a
        tax
        lda     MetatileTiles,x
        inx
        jsr     StoreAndQueueShadowTile
        lda     #$01
        jsr     AddAToPointer
        lda     MetatileTiles,x
        inx
        jsr     StoreAndQueueShadowTile
        lda     #$1F
        jsr     AddAToPointer
        lda     MetatileTiles,x
        inx
        jsr     StoreAndQueueShadowTile
        lda     #$01
        jsr     AddAToPointer
        lda     MetatileTiles,x
        inx
        jsr     StoreAndQueueShadowTile
        rts

; Растрирует первую bitplane 8x8 CHR-тайла в маску низкого ниббла shadow nametable.
; Каждый CHR-пиксель превращается в подобласть 4x4 в shadow; строки обрабатываются
; в обратном порядке из-за временного стека. Вход: A -- номер CHR-тайла в pattern table $1000,
; X/Y -- пиксельная позиция. Читает только first bitplane через
; PPU_DATA; вызывать при отключённом рендеринге. Меняет A/X/Y, ScratchPtr,
; raster/collision scratch и shadow. PPU-очередь не меняет.
RasterizeChrTileToShadow:
LD85E:  stx     RasterPixelX
        tax
        tya
        clc
        adc     #$20
        sta     RasterPixelY
        lda     #$00
        sta     ScratchPtrLo
        lda     #$10
        sta     ScratchPtrHi
SeekChrTileAddress:
LD86F:  dex
        bmi     BeginChrTileRead
        lda     #$10
        jsr     AddAToPointer
        jmp     SeekChrTileAddress

BeginChrTileRead:
LD87A:  lda     ScratchPtrHi
        sta     PPU_ADDR
        lda     ScratchPtrLo
        sta     PPU_ADDR
        lda     PPU_DATA
        lda     #$08
        sta     RasterRowCount
ReadChrPlaneRow:
LD88B:  lda     PPU_DATA
        pha
        dec     RasterRowCount
        bne     ReadChrPlaneRow
        lda     #$08
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
        adc     #$04
        sta     RasterPixelX
        lsr     RasterBitMask
        bcc     RasterizeNextChrPixel
        lda     RasterPixelX
        sec
        sbc     #$20
        sta     RasterPixelX
        lda     RasterPixelY
        sec
        sbc     #$04
        sta     RasterPixelY
        dec     RasterRowCount
        bne     RasterizeNextChrRow
        rts

; Рисует в shadow строку крупных 32x32-знаков, растрируя CHR-тайлы.
; Вход: AuxPtr -> $FF-терминированная строка номеров,
; RasterStringX/Y -- позиция, TileTranslationOffset -- смещение номера CHR-тайла.
; Каждый знак сдвигает RasterStringX на $20. Меняет A/X/Y,
; RasterStringX/RasterStringIndex и все
; побочные области RasterizeChrTileToShadow.
RasterizeTileStringToShadow:
LD8D2:  ldy     #$00
        sty     RasterStringIndex
RasterizeNextStringTile:
LD8D6:  lda     (AuxPtrLo),y
        cmp     #$FF
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
        adc     #$20
        sta     RasterStringX
        ldy     RasterStringIndex
        jmp     RasterizeNextStringTile

FinishRasterizedString:
LD8F5:  rts

; Ожидает изменения FrameCounter обработчиком NMI. Требует включённые NMI;
; иначе цикл не завершится. Выход: A=новое значение FrameCounter; X/Y не меняются.
WaitForNextFrame:  lda     FrameCounter
WaitForFrameCounterChange:
LD8F8:  cmp     FrameCounter
        beq     WaitForFrameCounterChange
        rts

; Выполняет накопленные записи из PpuUpdateBuffer. Команда имеет вид
; [addr_hi, addr_lo, data..., $FF]; следующий байт после $FF -- адрес новой команды.
; Пара $FF,$FF позволяет записать один литеральный $FF и тут же закончить команду.
; После выполнения обнуляет PpuBufferPos. Меняет A/X и PPU_ADDR/PPU_DATA; Y сохраняет.
FlushPpuUpdateBuffer:  ldx     PpuBufferPos
        lda     #$00
        sta     PpuUpdateBuffer,x
        tax
FlushNextPpuCommand:
LD905:  cpx     PpuBufferPos
        beq     FinishPpuBufferFlush
        lda     PpuUpdateBuffer,x
        inx
        sta     PPU_ADDR
        lda     PpuUpdateBuffer,x
        inx
        sta     PPU_ADDR
FlushNextPpuDataByte:
LD917:  lda     PpuUpdateBuffer,x
        inx
        cmp     #$FF
        bne     WritePpuDataByte
        lda     PpuUpdateBuffer,x
        cmp     #$FF
        bne     FlushNextPpuCommand
        lda     PpuUpdateBuffer-1,x
WritePpuDataByte:
LD929:  sta     PPU_DATA
        jmp     FlushNextPpuDataByte

FinishPpuBufferFlush:
LD92F:  lda     #$00
        sta     PpuBufferPos
        rts

; Подавляет ведущие нули в нулевой странице и готовит указатель на печатаемую
; часть цифровой $FF-терминированной записи. Вход: Y -- адрес первой цифры,
; X -- начальная колонка, $6B -- режим сдвига пустого числа. Выход: ScratchPtr=$00:Y,
; X сдвинут на число пропущенных знаков, A=0. Саму запись не меняет.
SelectVisibleDigits:
SkipNextLeadingZero:
LD934:  lda     $00,y
        bne     HandleFirstVisibleDigit
        iny
        inx
        jmp     SkipNextLeadingZero

HandleFirstVisibleDigit:
LD93E:  cmp     #$FF
        bne     StoreVisibleDigitsPointer
        lda     DigitBlankMode
        bne     AdjustBlankDigitPosition
        dex
        dey
AdjustBlankDigitPosition:
LD948:  dex
        dey
StoreVisibleDigitsPointer:
LD94A:  lda     #$00
        sta     ScratchPtrHi
        sty     ScratchPtrLo
        rts

; Рисует текущую семизначную запись $3D-$43 крупными CHR-знаками.
; Ведущие нули смещают начало на $20 пикселей. Использует CHR bias $30 и позицию ($10,$64).
; Меняет A/X/Y, AuxPtr, RasterStringX/Y, TileTranslationOffset и области RasterizeTileStringToShadow.
RenderLargeScoreRecord:
LD951:  lda     #$10
        sta     RasterStringX
        lda     #$64
        sta     RasterStringY
        lda     #$30
        sta     TileTranslationOffset
        ldy     #$3D
SkipNextHighScoreLeadingZero:
LD95F:  lda     $00,y
        bne     RasterizeVisibleHighScore
        iny
        lda     RasterStringX
        clc
        adc     #$20
        sta     RasterStringX
        jmp     SkipNextHighScoreLeadingZero

RasterizeVisibleHighScore:
LD96F:  lda     #$00
        sta     AuxPtrHi
        sty     AuxPtrLo
        jsr     RasterizeTileStringToShadow
        lda     #$00
        sta     TileTranslationOffset
        rts

; Сравнивает две семизначные записи $15-$1B и $1D-$23 с рекордом $3D-$43.
; Сравнение лексикографическое от старшей цифры; большая запись копируется в $3D-$43.
; Возвращает Y=1, если рекорд обновила первая запись; Y=$FF -- вторая; Y=0 -- ни одна.
; A/X и флаги содержат промежуточный результат последнего сравнения/копирования и не являются выходом.
UpdateHighScoreRecord:
LD97D:  ldx     #$00
        ldy     #$00
ComparePlayer1ScoreDigit:
LD981:  lda     Player1Score,x
        cmp     HighScore,x
        bne     EvaluatePlayer1ScoreDifference
        inx
        cpx     #$07
        beq     ComparePlayer2Score
        jmp     ComparePlayer1ScoreDigit

EvaluatePlayer1ScoreDifference:
LD98F:  bmi     ComparePlayer2Score
        ldx     #$00
CopyNextPlayer1ScoreDigit:
LD993:  lda     Player1Score,x
        sta     HighScore,x
        inx
        cpx     #$07
        bne     CopyNextPlayer1ScoreDigit
        ldy     #$01
ComparePlayer2Score:
LD99E:  ldx     #$00
ComparePlayer2ScoreDigit:
LD9A0:  lda     Player2Score,x
        cmp     HighScore,x
        bne     EvaluatePlayer2ScoreDifference
        inx
        cpx     #$07
        beq     FinishHighScoreUpdate
        jmp     ComparePlayer2ScoreDigit

EvaluatePlayer2ScoreDifference:
LD9AE:  bmi     FinishHighScoreUpdate
        ldx     #$00
CopyNextPlayer2ScoreDigit:
LD9B2:  lda     Player2Score,x
        sta     HighScore,x
        inx
        cpx     #$07
        bne     CopyNextPlayer2ScoreDigit
        ldy     #$FF
FinishHighScoreUpdate:
LD9BD:  rts

; Прибавляет семизначное десятичное число ScoreIncrementDigits к записи игрока.
; Вход: X -- индекс записи (0 -> $15, 1 -> $1D и т. д.). Сложение идёт от младшей цифры
; с переносом по основанию 10; переполнение за семь цифр теряется. Выход X указывает
; на байт перед записью, Y=$FF; A/флаги изменены.
AddScoreDigitsToRecord:
LD9BE:  txa
        asl     a
        asl     a
        asl     a
        clc
        adc     #$06
        tax
        ldy     #$06
        clc
AddNextScoreDigit:
LD9C9:  lda     ScoreIncrementDigits,y
        adc     Player1Score,x
        cmp     #$0A
        bmi     ClearScoreDigitCarry
        sec
        sbc     #$0A
        sec
        jmp     StoreScoreDigit

ClearScoreDigitCarry:
LD9D9:  clc
StoreScoreDigit:
LD9DA:  sta     Player1Score,x
        dex
        dey
        bpl     AddNextScoreDigit
        rts

; Готовит в ScoreIncrementDigits приращение счёта из упакованного десятичного A:
; старший ниббл -> DecimalHundreds, младший -> DecimalTens. Для A=0 специально
; записывает 1 в ScoreIncrementThousands. Меняет A/X, ByteToDecimalInput и
; ScoreIncrementDigits; Y не меняет.
PreparePackedScoreIncrement:
LD9E1:  sta     ByteToDecimalInput
        ldx     #ScoreIncrementDigits
        jsr     ResetEightByteRecord
        lda     ByteToDecimalInput
        beq     PrepareOneThousandPointIncrement
        and     #$0F
        sta     DecimalTens
        lda     ByteToDecimalInput
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        sta     DecimalHundreds
        rts

PrepareOneThousandPointIncrement:
LD9F9:  lda     #$01
        sta     ScoreIncrementThousands
        rts

; Инициализирует восьмибайтовую запись: семь нулей и завершающий $FF.
; Вход: X -- базовый адрес в нулевой странице. Выход A=$FF; X/Y не меняются.
ResetEightByteRecord:  lda     #$00
        sta     $00,x
        sta     $01,x
        sta     $02,x
        sta     $03,x
        sta     $04,x
        sta     $05,x
        sta     Joy1Held,x
        lda     #$FF
        sta     Joy2Held,x
        rts

; Преобразует беззнаковый байт A в десятичные сотни/$39, десятки/$3A и единицы/$3B,
; предварительно обнуляя ScoreIncrementDigits. Выход A=единицы,
; X=ScoreIncrementDigits; Y не меняется.
ByteToDisplayDigits:
LDA13:  sta     ByteToDecimalInput
        ldx     #ScoreIncrementDigits
        jsr     ResetEightByteRecord
        jmp     ByteToDecimalDigits

; Отдельных ссылок на этот вход не найдено. Он удваивает A и пытается вычесть 10
; с накоплением $3A. JMP $DA1C попадает на последний байт предыдущей JMP-инструкции;
; смысл этого намеренного входа в середину инструкции не подтверждён.
LDA1D:  asl     a
        bcc     StoreDecimalOnes
        sec
        sbc     #$0A
        inc     DecimalTens
        jmp     $DA1C                 ; Хаковый вход внутрь предыдущего JMP.
StoreDecimalOnes:
LDA28:  sta     DecimalOnes
        rts
; Добавляет один 8x8-спрайт в OamShadow через курсор $0D и шаг $0E.
; Вход: X/Y -- экранные X и базовый Y, OamTile -- tile, RenderAttributes -- attributes,
; SpriteBehindTerrainMask -- добавочные
; attributes для тайла $22 в shadow под спрайтом. В OAM пишутся (Y-8, tile, attributes, X).
; Побочно: OamSavedX/Y, ScratchPtr, TerrainSubcellMask,
; OamBufferPos; для shadow-тайла $22 также меняет RenderAttributes.
; A/X/Y изменены.
EmitOamSprite:
LDA2B:  txa
        sta     OamSavedX
        clc
        adc     #$03
        tax
        tya
        sec
        sbc     #$08
        sta     OamSavedY
        jsr     PixelCoordinatesToShadowPointer
        lda     (ScratchPtrLo),y
        cmp     #$22
        bne     StoreOamEntry
        lda     RenderAttributes
        ora     SpriteBehindTerrainMask
        sta     RenderAttributes
StoreOamEntry:
LDA47:  ldx     OamBufferPos
        lda     OamSavedY
        sta     OamShadow,x
        lda     OamTile
        sta     OamShadow+1,x
        lda     RenderAttributes
        sta     OamShadow+2,x
        lda     OamSavedX
        sta     OamShadow+3,x
        txa
        clc
        adc     OamBufferStep
        sta     OamBufferPos
        rts

; Выбирает тайл $53 + 2*A, сдвигает X на -5 и выводит один спрайт.
; Используется для направленных однотайловых объектов. Входы и побочные эффекты как у EmitOamSprite.
EmitDirectionalOamSprite:
LDA64:  asl     a
        clc
        adc     OamTile
        sta     OamTile
        txa
        sec
        sbc     #$05
        tax
        jsr     EmitOamSprite
        rts

; Выбирает двухтайловый кадр $53 + 8*A и выводит два соседних по X спрайта
; с тайлами base и base+2. Вход: A -- кадр, X/Y -- позиция;
; OamTile/RenderAttributes/SpriteBehindTerrainMask как EmitOamSprite.
; Сохраняет исходные X/Y в OamPairX/Y, но по выходу регистры
; изменены вторым вызовом; дважды применяются все side effects EmitOamSprite.
EmitTwoTileOamObject:
LDA73:  asl     a
        asl     a
        asl     a
        clc
        adc     OamTile
        sta     OamTile
; Альтернативный вход: $53 уже содержит tile-base, X/Y -- позицию пары.
EmitTwoTileOamPair:
LDA7B:  stx     OamPairX
        sty     OamPairY
        txa
        sec
        sbc     #$08
        tax
        jsr     EmitOamSprite
        inc     OamTile
        inc     OamTile
        ldx     OamPairX
        ldy     OamPairY
        jsr     EmitOamSprite
        rts

; Завершает OAM-кадр: меняет знак шага $0E и пишет Y=$F0 в неиспользованные
; записи между текущим $0D и слотом 1. Чередование направления выдачи OAM-слотов
; меняет приоритет спрайтов между кадрами и снижает заметность переполнения строки растра.
; Выход: $0D=4, $0E=-$0E; A=$F0, X=4; Y не меняет.
FinishAlternatingOamFrame:
LDA93:  ldx     OamBufferPos
        lda     OamBufferStep
        eor     #$FF
        clc
        adc     #$01
        sta     OamBufferStep
HideNextUnusedOamEntry:
LDA9E:  txa
        clc
        adc     OamBufferStep
        tax
        lda     #$F0
        sta     OamShadow,x
        cpx     #$04
        bne     HideNextUnusedOamEntry
        stx     OamBufferPos
        rts

; Нормализует результат предшествующего SEC/SBC: A=0 при Z=1, A=1 при C=1,
; A=$FF при заёме. Флаги должны поступать сразу от вычитания; X/Y не меняются.
NormalizeSubtractionSign:
LDAAF:  beq     ReturnNormalizedSubtractionSign
        bcs     ReturnPositiveSubtractionSign
        lda     #$FF
        jmp     ReturnNormalizedSubtractionSign

ReturnPositiveSubtractionSign:
LDAB8:  lda     #$01
ReturnNormalizedSubtractionSign:
LDABA:  rts

MetatilePalettes:
LDABB:  .incbin "../build/background-metatiles.bin", 0, 16
MetatileTiles:
LDACB:  .incbin "../build/background-metatiles.bin", 16, 64
