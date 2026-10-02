; Адресация и изменение подобластей terrain shadow ($D706-$D7B3).

ShadowQueueSavedX = $47
TerrainSubcellFirstMask     = $01
TerrainSubcellHalfSelectBit = $04
TerrainWholeTileBitsMask    = $F0

; Переводит беззнаковые пиксельные X/Y в tile coordinates и устанавливает
; ScratchPtr на NametableShadow[floor(Y/8)*32+floor(X/8)]. Функция не знает
; границы игрового поля: Y=240..255 адресует $07C0-$07FF, где проект хранит
; attributes, а не tile rows. Romhack-код обязан ограничить Y<=239 для terrain.
;
; Выход: ScratchPtrHi=$04+(input Y>>6),
; ScratchPtrLo=(input X>>3)+(((input Y>>3)&7)*32), X=input X>>3, Y=0,
; A=ScratchPtrHi, Z=1/N=0. PpuTileRowBits получает row-within-page*32.
; Меняет A/X/Y, ScratchPtr, PpuTileRowBits и flags; shadow/PPU не трогает.
PixelCoordinatesToShadowPointer:
LD706:  jsr     PixelToTileCoordinates
; Альтернативный вход: X/Y=0..31 — уже готовые tile coordinates. Rows 30/31
; так же попадают в attribute storage. Выход совпадает с основным entry,
; кроме формул относительно исходных pixel coordinates.
TileCoordinatesToShadowPointer:
LD709:  jsr     TileCoordinatesToShadowAddress
        sta     ScratchPtrHi
        sty     ScratchPtrLo
        ldy     #$00
        rts

; Делит беззнаковые пиксельные X/Y на 8 без округления. Выход:
; A=X=floor(input X/8), Y=floor(input Y/8), N=0, Z=1 iff result X=0,
; C=input X bit2. RAM и стек сохраняет; V не меняет.
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

; Вычисляет tile shadow и один bit для 4x4-квадранта пиксельной точки:
; top-left=$01, top-right=$02, bottom-left=$04, bottom-right=$08. Выбор
; выполняется по bit2 исходных X/Y; остальные младшие биты внутри квадранта
; значения не имеют.
;
; Вход: X/Y — беззнаковые pixels с теми же Y<=239 ограничениями, если нужен
; terrain tile. Выход: CollisionPointX/Y=input X/Y, ScratchPtr выбранного tile,
; X=floor(input X/8), Y=0, TerrainSubcellMask=один из $01/$02/$04/$08,
; A=input X&4. Меняет A/X/Y, collision/address scratch и flags; shadow/PPU
; queue/registers не трогает.
SelectTerrainSubcell:
LD71E:  stx     CollisionPointX
        sty     CollisionPointY
        jsr     PixelCoordinatesToShadowPointer
; Альтернативный entry: пересчитывает маску из CollisionPointX/Y, не меняя
; ScratchPtr/X/Y. Выход: A=CollisionPointX&4 и та же one-hot mask; Z отражает
; левую/правую половину, N=0, C=0 на правой половине. Меняет только
; TerrainSubcellMask и flags.
RecomputeTerrainSubcellMask:
LD725:  lda     #TerrainSubcellFirstMask
        sta     TerrainSubcellMask
        lda     CollisionPointY
        and     #TerrainSubcellHalfSelectBit
        beq     SelectTerrainSubcellHorizontalHalf
        asl     TerrainSubcellMask
        asl     TerrainSubcellMask
SelectTerrainSubcellHorizontalHalf:
LD733:  lda     CollisionPointX
        and     #TerrainSubcellHalfSelectBit
        beq     FinishTerrainSubcellMask
        asl     TerrainSubcellMask
FinishTerrainSubcellMask:
LD73B:  rts

; Проверяет выбранный квадрант. Вход: (ScratchPtr),Y указывает shadow byte,
; TerrainSubcellMask — one-hot low-nibble mask. Выход:
; A=shadow&($F0|TerrainSubcellMask); Z=1 только когда high nibble и выбранный
; subcell равны нулю, N копирует bit7 shadow. Остальные три subcell bits не
; учитываются. X/Y, указатель, mask и RAM сохраняет; PPU не трогает.
; Формат terrain тем самым резервирует весь high nibble для whole-tile classes:
; любое его ненулевое значение считается занятым независимо от выбранной четверти.
TestTerrainSubcell:
LD73C:  lda     TerrainSubcellMask
        ora     #TerrainWholeTileBitsMask
        and     (ScratchPtrLo),y
        rts

; Безусловно снимает выбранный low-nibble bit — в том числе у whole-tile class —
; и передаёт результат StoreAndQueueShadowTile. Штатные callers предварительно
; классифицируют tile. Вход: Y=0, ScratchPtr=terrain tile, mask one-hot;
; в очереди есть 4 байта под команду и следующий lookahead byte.
; Выход: A=$FF; X/Y, ScratchPtr и mask сохранены. Меняет shadow byte,
; PpuBufferPos/четыре байта очереди и ShadowQueueSavedX/CollisionPointX;
; PPU registers не трогает.
ClearTerrainSubcellQueued:
LD743:  lda     TerrainSubcellMask
        eor     #$FF
        and     (ScratchPtrLo),y
        jsr     StoreAndQueueShadowTile
        rts

; Shadow-only вариант: снимает mask только если high nibble tile равен нулю.
; Whole-tile class, включая временный occupancy bit7, блокирует изменение.
; Выход: для low-nibble terrain A=новый записанный byte, N=0/Z по нему;
; для whole-tile class A=исходный high nibble, N/Z по нему, shadow сохранён.
; X/Y, ScratchPtr, mask и прочую RAM сохраняет; PPU queue/registers не трогает.
ClearTerrainSubcellShadow:
LD74D:  lda     (ScratchPtrLo),y
        and     #TerrainWholeTileBitsMask
        bne     FinishClearTerrainSubcellShadow
        lda     TerrainSubcellMask
        eor     #$FF
        and     (ScratchPtrLo),y
        sta     (ScratchPtrLo),y
FinishClearTerrainSubcellShadow:
LD75B:  rts

; Безусловно ставит выбранный low-nibble bit и передаёт результат в
; StoreAndQueueShadowTile. Предусловия/выход совпадают с queued-clear.
SetTerrainSubcellQueued:
LD75C:  lda     TerrainSubcellMask
        ora     (ScratchPtrLo),y
        jsr     StoreAndQueueShadowTile
        rts
; Shadow-only вариант установки: меняет только low-nibble terrain с high
; nibble=0; whole-tile class не трогает. Выход и сохранность регистров совпадают
; с ClearTerrainSubcellShadow.
SetTerrainSubcellShadow:
LD764:  lda     (ScratchPtrLo),y
        and     #TerrainWholeTileBitsMask
        bne     FinishSetTerrainSubcellShadow
        lda     TerrainSubcellMask
        ora     (ScratchPtrLo),y
        sta     (ScratchPtrLo),y
FinishSetTerrainSubcellShadow:
LD770:  rts

; Немедленно пишет byte (ScratchPtr),Y в PPU-адрес
; (ScratchPtrHi+NametablePpuOffset):ScratchPtrLo. Y участвует только в выборе
; source byte и НЕ прибавляется к VRAM address; штатный полный upload использует
; Y=0. Rendering/NMI должны быть выключены или синхронизированы, никто другой
; не должен касаться PPU, address latch ожидает high write. Для отображения
; shadow high=$04..$07 NametablePpuOffset должен без переполнения переводить
; его в нужный nametable range.
;
; Выход: A=переданный byte, N/Z по нему; X/Y, ScratchPtr, offset и RAM сохранены.
; Меняет PPU_ADDR/PPU_DATA; latch снова ожидает high byte, а внутренний VRAM
; address продвинут на текущее приращение PPU_CTRL (1 либо 32), не обязательно 1.
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

; Пишет A в (ScratchPtr),Y и добавляет четырёхбайтовую команду
; [ScratchPtrHi+$1C, ScratchPtrLo, записанный byte, $FF]. Y НЕ прибавляется к
; queued PPU address, поэтому для синхронного shadow/VRAM update требуется Y=0;
; все штатные callers это соблюдают. Назначение всегда primary nametable
; $2000-$23FF и не зависит от NametablePpuOffset.
;
; Вход: ScratchPtr=$0400..$07FF, PpuBufferPos<=$7B, чтобы команда и lookahead,
; который FlushPpuUpdateBuffer пишет по новому cursor, остались в $0180-$01FF.
; Capacity кодом не проверяется. Выход: A=$FF (input data в регистре не
; сохраняется), X/Y и ScratchPtr сохранены, PpuBufferPos=old+4; N/Z отражают
; восстановленный input X, а для валидного shadow C=0/V=0 после сложения high.
; Перезаписывает
; ShadowQueueSavedX=$47 (alias CollisionPointX), четыре байта PpuUpdateBuffer и
; выбранный shadow byte; PPU registers не трогает.
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

; Прибавляет беззнаковый A к 16-битному ScratchPtr, игнорируя входной carry;
; clipping и защита от переполнения $FFFF->$0000 отсутствуют.
; Выход: A=новый low byte, X/Y сохранены, C=1 iff был переход страницы.
; Без перехода N/Z относятся к новому low byte; при переходе INC заменяет их
; флагами нового high byte. Меняет только ScratchPtr и N/Z/C/V; V отражает
; low-byte ADC и не пересчитывается после INC.
AddAToPointer:  clc
        adc     ScratchPtrLo
        sta     ScratchPtrLo
        bcc     FinishAddAToPointer
        inc     ScratchPtrHi
FinishAddAToPointer:
LD7B3:  rts
