; NMI, PPU-очередь, OAM и отрисовка метатайлов ($D400-$DB0A).
;
; Теневая nametable занимает $0400-$07FF. Для игрового поля
; её байты одновременно служат номерами фоновых тайлов и битовой
; маской четырёх подобластей 4x4 пикселя. Это позволяет одним байтом
; обслуживать и коллизии, и частичное разрушение кирпича.

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
        bmi     LD41D
        jsr     UploadBackgroundPalette
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
        jsr     LDA93
        jsr     UpdateAudioEngine
        inc     FrameCounter
        lda     FrameCounter
        and     #$3F
        bne     LD446
        inc     SlowFrameCounter
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
LD481:  sta     NametableShadow,x
        sta     $0500,x
        sta     $0600,x
        sta     $0700,x
        inx
        bne     LD481
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
        jsr     LDA93
        ldx     #$15
        jsr     ResetEightByteRecord
        ldx     #$1D
        jsr     ResetEightByteRecord
        jsr     HasRestartSignature
        bne     LD4CE
        ldx     #$3D
        jsr     BootHook
        lda     #$02
        sta     $3F
        lda     #$00
        sta     MenuSelection
LD4CE:  lda     #$1C
        sta     NametablePpuOffset
        jsr     UploadNametableBuffer
        lda     #$24
        sta     NametablePpuOffset
        jsr     UploadNametableBuffer
        jsr     StoreRestartSignature
        jsr     ResetAudioEngine
        rts

; Копирует 16-байтный ROM-маркер LC040 в $0110-$011F.
; Выход: X=$FF; A=первый байт маркера.
StoreRestartSignature:
LD4E3:  ldx     #$0F
LD4E5:  lda     LC040,x
        sta     $0110,x
        dex
        bpl     LD4E5
        rts

; Сравнивает $0110-$011F с ROM-маркером LC040.
; Возвращает A=1 при полном совпадении, иначе A=0; X указывает на место расхождения.
HasRestartSignature:
LD4EF:  ldx     #$0F
LD4F1:  lda     $0110,x
        cmp     LC040,x
        bne     LD4FF
        dex
        bpl     LD4F1
        lda     #$01
        rts

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
LD51F:  lda     BackgroundPaletteSets,x
        sta     PPU_DATA
        inx
        dey
        bne     LD51F
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
LD54A:  lda     SpritePalette,x
        sta     PPU_DATA
        inx
        dey
        bne     LD54A
        rts

SpritePalette:
LD555:  .incbin "../build/sprite-palette.bin"
BackgroundPaletteSets:
LD565:  .incbin "../build/background-palettes.bin"
; Активно ждёт установки vblank в PPU_STATUS.
; Выход: A с установленным битом 7; X/Y не меняются. Чтение сбрасывает vblank и latch.
WaitForVblankStart:
LD5F5:  lda     PPU_STATUS
        bpl     LD5F5
        rts

; Преобразует координаты тайла X=0..31, Y=0..31 в адрес shadow nametable:
;   A = $04 + Y / 8, Y = X + (Y & 7) * 32.
; Меняет A/Y и scratch $00; X сохраняет.
TileCoordinatesToShadowAddress:
LD5FB:  lda     #$00
        sta     $00
        tya
        lsr     a
        ror     $00
        lsr     a
        ror     $00
        lsr     a
        ror     $00
        pha
        txa
        ora     $00
        tay
        pla
        ora     #$04
        rts

; Обновляет атрибут палитры для тайла X/Y и добавляет однобайтовую
; запись $23C0+index в PPU-очередь. Вход: X/Y -- координаты 8x8-тайла, $04 -- палитра 0..3.
; Побочно: меняет $00-$02, $07C0-$07FF, PpuUpdateBuffer/PpuBufferPos; A/X/Y изменены.
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
        lda     $07C0,y
        sta     PpuUpdateBuffer,x
        inx
        lda     #$FF
        sta     PpuUpdateBuffer,x
        inx
        stx     PpuBufferPos
        rts

; Вставляет два бита палитры $04 в нужный квадрант attribute byte.
; Вход: X/Y -- координаты 8x8-тайла. Выход: Y -- индекс attribute table, A -- новый байт.
UpdateAttributeShadow:
LD635:  lda     $04
        jsr     ExpandPaletteBits
        jsr     ExpandPaletteBits
        jsr     ExpandPaletteBits
        sta     $02
        tya
        and     #$02
        bne     LD656
        txa
        and     #$02
        beq     LD651
        lda     #$F3
        jmp     LD662

LD651:  lda     #$FC
        jmp     LD662

LD656:  txa
        and     #$02
        beq     LD660
        lda     #$3F
        jmp     LD662

LD660:  lda     #$CF
LD662:  sta     $01
        tya
        asl     a
        and     #$F8
        sta     $00
        txa
        lsr     a
        lsr     a
        clc
        adc     $00
        tay
        lda     $01
        eor     #$FF
        and     $02
        sta     $02
        lda     $07C0,y
        and     $01
        ora     $02
        sta     $07C0,y
        rts

; Один шаг A=(A*4)|$04. Три вызова размножают двухбитовую палитру $04
; по всем четырём квадрантам attribute byte. Меняет A/флаги.
ExpandPaletteBits:
LD684:  asl     a
        asl     a
        ora     $04
        rts

; Последовательно читает оба контроллера. $06/$07 -- текущее состояние,
; $08/$09 -- фронты вновь нажатых кнопок. Биты собираются в NES-порядке A..Right через ROR.
; Меняет A/X/Y, scratch $00 и strobes JOY1; по выходу X=$FF, Y=0.
ReadControllers:  ldx     #$01
        stx     JOY1
        ldy     #$00
        sty     JOY1
LD693:  sty     $00
        ldy     #$08
LD697:  lda     JOY1,x
        and     #$03
        cmp     #$01
        ror     $00
        dey
        bne     LD697
        lda     Joy1Held,x
        eor     #$FF
        and     $00
        sta     Joy1Pressed,x
        lda     $00
        sta     Joy1Held,x
        dex
        bpl     LD693
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
LD6CA:  lda     (ScratchPtrLo),y
        sta     PpuUpdateBuffer,x
        inx
        cmp     #$FF
        beq     LD6DA
        sta     (AuxPtrLo),y
        iny
        jmp     LD6CA

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
LD6F0:  lda     (ScratchPtrLo),y
        bmi     LD6F7
        clc
        adc     TileTranslationOffset
LD6F7:  sta     PpuUpdateBuffer,x
        inx
        cmp     #$FF
        beq     LD703
        iny
        jmp     LD6F0

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
; вокруг пиксельной точки X/Y. Вход: X/Y пиксели. Выход: ScratchPtr, Y=0, $00=маска;
; исходные координаты сохранены в $47/$48. A/X изменены.
SelectTerrainSubcell:
LD71E:  stx     $47
        sty     $48
        jsr     PixelCoordinatesToShadowPointer
; Вход после SelectTerrainSubcell или прямой: пересчитывает $00 из сохранённых $47/$48.
RecomputeTerrainSubcellMask:
LD725:  lda     #$01
        sta     $00
        lda     $48
        and     #$04
        beq     LD733
        asl     $00
        asl     $00
LD733:  lda     $47
        and     #$04
        beq     LD73B
        asl     $00
LD73B:  rts

; Проверяет выбранную подобласть. Возвращает A=(shadow & ($F0|$00)); Z=1 только
; для пустого низкобитного тайла. ScratchPtr, Y и $00 заданы ранее.
TestTerrainSubcell:
LD73C:  lda     $00
        ora     #$F0
        and     (ScratchPtrLo),y
        rts

; Сбрасывает выбранный бит в shadow и ставит изменённый тайл в PPU-очередь.
; Меняет A и PpuUpdateBuffer/PpuBufferPos; X сохраняется.
ClearTerrainSubcellQueued:
LD743:  lda     $00
        eor     #$FF
        and     (ScratchPtrLo),y
        jsr     StoreAndQueueShadowTile
        rts

; Теневой вариант сброса: меняет бит только у тайла с нулевым старшим нибблом;
; PPU-очередь не трогает. Выход A=исходный или изменённый байт.
ClearTerrainSubcellShadow:
LD74D:  lda     (ScratchPtrLo),y
        and     #$F0
        bne     LD75B
        lda     $00
        eor     #$FF
        and     (ScratchPtrLo),y
        sta     (ScratchPtrLo),y
LD75B:  rts

; Устанавливает выбранный бит в shadow и ставит изменённый тайл в PPU-очередь.
SetTerrainSubcellQueued:
LD75C:  lda     $00
        ora     (ScratchPtrLo),y
        jsr     StoreAndQueueShadowTile
        rts
; Теневой вариант установки: меняет бит только у тайла с нулевым старшим нибблом;
; PPU-очередь не трогает. Выход A=исходный или изменённый байт.
SetTerrainSubcellShadow:
LD764:  lda     (ScratchPtrLo),y
        and     #$F0
        bne     LD770
        lda     $00
        ora     (ScratchPtrLo),y
        sta     (ScratchPtrLo),y
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
; Сохраняет X; меняет A, $47 и PpuUpdateBuffer/PpuBufferPos.
StoreAndQueueShadowTile:
LD784:  sta     (ScratchPtrLo),y
        stx     $47
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
        ldx     $47
        rts

; Прибавляет беззнаковый A к 16-битному ScratchPtrHi:ScratchPtrLo.
; Выход: A=новый младший байт указателя; X/Y не меняются.
AddAToPointer:  clc
        adc     ScratchPtrLo
        sta     ScratchPtrLo
        bcc     LD7B3
        inc     ScratchPtrHi
LD7B3:  rts

; Передаёт всю теневую nametable $0400-$07FF в PPU. NametablePpuOffset задаёт
; смещение старшего байта (обычно $1C для $2000 или $20 для $2400).
; Предполагает отключённый рендеринг. Выход: ScratchPtr=$0800, Y=0; A и PPU latch/data изменены.
UploadNametableBuffer:  lda     #$00
        sta     ScratchPtrLo
        tay
        lda     #$04
        sta     ScratchPtrHi
LD7BD:  jsr     UploadShadowByteDirect
        lda     #$01
        jsr     AddAToPointer
        lda     ScratchPtrHi
        cmp     #$08
        bne     LD7BD
        rts

; Готовит shadow nametable для игрового поля: заполняет её тайлом $11,
; обнуляет attribute table $07C0-$07FF и затем очищает прямоугольник по нулевым тайлам.
; Вход: $56/$57 -- X/Y в тайлах, $5A -- высота, $5B -- ширина. Нулевая высота
; или ширина не поддерживаются. Меняет A/X/Y, ScratchPtr, $00, $5A.
InitializePlayfieldShadow:
LD7CC:  ldx     #$00
        lda     #$11
LD7D0:  sta     NametableShadow,x
        sta     $0500,x
        sta     $0600,x
        sta     $0700,x
        inx
        bne     LD7D0
        lda     #$00
        ldx     #$C0
LD7E3:  sta     $0700,x
        inx
        bne     LD7E3
        ldx     $56
        ldy     $57
        jsr     TileCoordinatesToShadowAddress
        sta     ScratchPtrHi
        sty     ScratchPtrLo
LD7F4:  ldy     $5B
        dey
LD7F7:  lda     #$00
        sta     (ScratchPtrLo),y
        dey
        bpl     LD7F7
        dec     $5A
        beq     LD80A
        lda     #$20
        jsr     AddAToPointer
        jmp     LD7F4

LD80A:  rts

; Рисует TSA-блок 2x2 тайла и обновляет его атрибут палитры.
; Вход: A -- индекс метатайла 0..15, X/Y -- пиксельные координаты. Процедура
; сама выравнивает полученные тайловые координаты на ячейку 16x16 пикселей.
; Пишет четыре тайла в shadow и четыре PPU-команды, а также одну команду атрибута.
; Меняет A/X/Y, ScratchPtr, $00-$04, $47/$48, attribute shadow и PPU-очередь.
DrawMetatile:  pha
        sta     $00
        jsr     PixelToTileCoordinates
        stx     $47
        sty     $48
        ldy     $00
        lda     MetatilePalettes,y
        sta     $04
        ldy     $48
        jsr     QueueAttributeByteForTile
        lda     $48
        and     #$FE
        tay
        lda     $47
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
; X/Y -- пиксельная позиция. Читает PPU_DATA напрямую; меняет A/X/Y, ScratchPtr, $00/$02/$03,
; $47/$48, $5A/$5D/$5E и shadow. PPU-очередь не меняет.
RasterizeChrTileToShadow:
LD85E:  stx     $5D
        tax
        tya
        clc
        adc     #$20
        sta     $5E
        lda     #$00
        sta     ScratchPtrLo
        lda     #$10
        sta     ScratchPtrHi
LD86F:  dex
        bmi     LD87A
        lda     #$10
        jsr     AddAToPointer
        jmp     LD86F

LD87A:  lda     ScratchPtrHi
        sta     PPU_ADDR
        lda     ScratchPtrLo
        sta     PPU_ADDR
        lda     PPU_DATA
        lda     #$08
        sta     $5A
LD88B:  lda     PPU_DATA
        pha
        dec     $5A
        bne     LD88B
        lda     #$08
        sta     $5A
LD897:  pla
        sta     $02
        lda     #$80
        sta     $03
LD89E:  ldx     $5D
        ldy     $5E
        jsr     SelectTerrainSubcell
        lda     $02
        and     $03
        beq     LD8B1
        jsr     SetTerrainSubcellShadow
        jmp     LD8B4

LD8B1:  jsr     ClearTerrainSubcellShadow
LD8B4:  lda     $5D
        clc
        adc     #$04
        sta     $5D
        lsr     $03
        bcc     LD89E
        lda     $5D
        sec
        sbc     #$20
        sta     $5D
        lda     $5E
        sec
        sbc     #$04
        sta     $5E
        dec     $5A
        bne     LD897
        rts

; Рисует в shadow строку крупных 32x32-знаков, растрируя CHR-тайлы.
; Вход: AuxPtr -> $FF-терминированная строка номеров, $56/$57 -- позиция, $60 -- смещение
; номера CHR-тайла. Каждый знак сдвигает $56 на $20. Меняет A/X/Y, $56, $5F и все
; побочные области RasterizeChrTileToShadow.
RasterizeTileStringToShadow:
LD8D2:  ldy     #$00
        sty     $5F
LD8D6:  lda     (AuxPtrLo),y
        cmp     #$FF
        beq     LD8F5
        iny
        sty     $5F
        ldx     $56
        ldy     $57
        clc
        adc     TileTranslationOffset
        jsr     RasterizeChrTileToShadow
        lda     $56
        clc
        adc     #$20
        sta     $56
        ldy     $5F
        jmp     LD8D6

LD8F5:  rts

; Ожидает изменения FrameCounter обработчиком NMI. Требует включённые NMI;
; иначе цикл не завершится. Выход: A=новое значение FrameCounter; X/Y не меняются.
WaitForNextFrame:  lda     FrameCounter
LD8F8:  cmp     FrameCounter
        beq     LD8F8
        rts

; Выполняет накопленные записи из PpuUpdateBuffer. Команда имеет вид
; [addr_hi, addr_lo, data..., $FF]; следующий байт после $FF -- адрес новой команды.
; Пара $FF,$FF позволяет записать один литеральный $FF и тут же закончить команду.
; После выполнения обнуляет PpuBufferPos. Меняет A/X и PPU_ADDR/PPU_DATA; Y сохраняет.
FlushPpuUpdateBuffer:  ldx     PpuBufferPos
        lda     #$00
        sta     PpuUpdateBuffer,x
        tax
LD905:  cpx     PpuBufferPos
        beq     LD92F
        lda     PpuUpdateBuffer,x
        inx
        sta     PPU_ADDR
        lda     PpuUpdateBuffer,x
        inx
        sta     PPU_ADDR
LD917:  lda     PpuUpdateBuffer,x
        inx
        cmp     #$FF
        bne     LD929
        lda     PpuUpdateBuffer,x
        cmp     #$FF
        bne     LD905
        lda     PpuUpdateBuffer-1,x
LD929:  sta     PPU_DATA
        jmp     LD917

LD92F:  lda     #$00
        sta     PpuBufferPos
        rts

; Подавляет ведущие нули в нулевой странице и готовит указатель на печатаемую
; часть цифровой $FF-терминированной записи. Вход: Y -- адрес первой цифры,
; X -- начальная колонка, $6B -- режим сдвига пустого числа. Выход: ScratchPtr=$00:Y,
; X сдвинут на число пропущенных знаков, A=0. Саму запись не меняет.
SelectVisibleDigits:
LD934:  lda     $00,y
        bne     LD93E
        iny
        inx
        jmp     LD934

LD93E:  cmp     #$FF
        bne     LD94A
        lda     DigitBlankMode
        bne     LD948
        dex
        dey
LD948:  dex
        dey
LD94A:  lda     #$00
        sta     ScratchPtrHi
        sty     ScratchPtrLo
        rts

; Рисует текущую семизначную запись $3D-$43 крупными CHR-знаками.
; Ведущие нули смещают начало на $20 пикселей. Использует CHR bias $30 и позицию ($10,$64).
; Меняет A/X/Y, AuxPtr, $56/$57/$60 и области RasterizeTileStringToShadow.
RenderLargeScoreRecord:
LD951:  lda     #$10
        sta     $56
        lda     #$64
        sta     $57
        lda     #$30
        sta     TileTranslationOffset
        ldy     #$3D
LD95F:  lda     $00,y
        bne     LD96F
        iny
        lda     $56
        clc
        adc     #$20
        sta     $56
        jmp     LD95F

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
LD981:  lda     Player1Score,x
        cmp     HighScore,x
        bne     LD98F
        inx
        cpx     #$07
        beq     LD99E
        jmp     LD981

LD98F:  bmi     LD99E
        ldx     #$00
LD993:  lda     Player1Score,x
        sta     HighScore,x
        inx
        cpx     #$07
        bne     LD993
        ldy     #$01
LD99E:  ldx     #$00
LD9A0:  lda     Player2Score,x
        cmp     HighScore,x
        bne     LD9AE
        inx
        cpx     #$07
        beq     LD9BD
        jmp     LD9A0

LD9AE:  bmi     LD9BD
        ldx     #$00
LD9B2:  lda     Player2Score,x
        sta     HighScore,x
        inx
        cpx     #$07
        bne     LD9B2
        ldy     #$FF
LD9BD:  rts

; Прибавляет семизначное десятичное число $35-$3B к записи игрока.
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
LD9C9:  lda     $35,y
        adc     Player1Score,x
        cmp     #$0A
        bmi     LD9D9
        sec
        sbc     #$0A
        sec
        jmp     LD9DA

LD9D9:  clc
LD9DA:  sta     Player1Score,x
        dex
        dey
        bpl     LD9C9
        rts

; Готовит в $35-$3C приращение счёта из упакованного десятичного A:
; старший ниббл -> $39, младший -> $3A. Для A=0 специально записывает 1 в $38.
; Меняет A/X, $00, $35-$3C; Y не меняет.
PreparePackedScoreIncrement:
LD9E1:  sta     $00
        ldx     #$35
        jsr     ResetEightByteRecord
        lda     $00
        beq     LD9F9
        and     #$0F
        sta     DecimalTens
        lda     $00
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        sta     DecimalHundreds
        rts

LD9F9:  lda     #$01
        sta     $38
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
; предварительно обнуляя запись $35-$3C. Выход A=единицы, X=$35; Y не меняется.
ByteToDisplayDigits:
LDA13:  sta     $00
        ldx     #$35
        jsr     ResetEightByteRecord
        jmp     ByteToDecimalDigits

; Отдельных ссылок на этот вход не найдено. Он удваивает A и пытается вычесть 10
; с накоплением $3A. JMP $DA1C попадает на последний байт предыдущей JMP-инструкции;
; смысл этого намеренного входа в середину инструкции не подтверждён.
LDA1D:  asl     a
        bcc     LDA28
        sec
        sbc     #$0A
        inc     DecimalTens
        jmp     $DA1C                 ; Хаковый вход внутрь предыдущего JMP.
LDA28:  sta     DecimalOnes
        rts
; Добавляет один 8x8-спрайт в OamShadow через курсор $0D и шаг $0E.
; Вход: X/Y -- экранные X и базовый Y, OamTile -- tile, $04 -- attributes,
; SpriteBehindTerrainMask -- добавочные
; attributes для тайла $22 в shadow под спрайтом. В OAM пишутся (Y-8, tile, attributes, X).
; Побочно: $47/$48, ScratchPtr, $00, $0D; для shadow-тайла $22 также меняет
; $04. A/X/Y изменены.
EmitOamSprite:
LDA2B:  txa
        sta     $47
        clc
        adc     #$03
        tax
        tya
        sec
        sbc     #$08
        sta     $48
        jsr     PixelCoordinatesToShadowPointer
        lda     (ScratchPtrLo),y
        cmp     #$22
        bne     LDA47
        lda     $04
        ora     SpriteBehindTerrainMask
        sta     $04
LDA47:  ldx     OamBufferPos
        lda     $48
        sta     OamShadow,x
        lda     OamTile
        sta     OamShadow+1,x
        lda     $04
        sta     OamShadow+2,x
        lda     $47
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
; OamTile/$04/SpriteBehindTerrainMask как EmitOamSprite.
; Сохраняет исходные X/Y в $54/$55, но по выходу регистры изменены вторым вызовом.
EmitTwoTileOamObject:
LDA73:  asl     a
        asl     a
        asl     a
        clc
        adc     OamTile
        sta     OamTile
; Альтернативный вход: $53 уже содержит tile-base, X/Y -- позицию пары.
EmitTwoTileOamPair:
LDA7B:  stx     $54
        sty     $55
        txa
        sec
        sbc     #$08
        tax
        jsr     EmitOamSprite
        inc     OamTile
        inc     OamTile
        ldx     $54
        ldy     $55
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
LDA9E:  txa
        clc
        adc     OamBufferStep
        tax
        lda     #$F0
        sta     OamShadow,x
        cpx     #$04
        bne     LDA9E
        stx     OamBufferPos
        rts

; Нормализует результат предшествующего SEC/SBC: A=0 при Z=1, A=1 при C=1,
; A=$FF при заёме. Флаги должны поступать сразу от вычитания; X/Y не меняются.
NormalizeSubtractionSign:
LDAAF:  beq     LDABA
        bcs     LDAB8
        lda     #$FF
        jmp     LDABA

LDAB8:  lda     #$01
LDABA:  rts

MetatilePalettes:
LDABB:  .incbin "../build/background-metatiles.bin", 0, 16
MetatileTiles:
LDACB:  .incbin "../build/background-metatiles.bin", 16, 64
