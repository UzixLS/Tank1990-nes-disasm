; Обработка boot marker и меню выбора варианта ($C49C-$C59C).

VariantStandardPastLast    = $07
VariantStandardFirst       = $00
VariantExtendedFirst       = $80
VariantExtendedPastLast    = $87
VariantExtendedBeforeFirst = $7F
VariantMenuRowCount        = $0E
VariantMenuTextStride      = $08
VariantMenuRepeatFrameMask = $0F
VariantStandardBeforeFirst = $FF
VariantMenuNameColumn      = $0D
VariantMenuFirstTextRow    = $09
VariantMenuHeaderColumn    = $07
VariantMenuHeaderRow       = $03
VariantMenuUpperDividerRow = $01
VariantMenuLowerDividerRow = $04
VariantMenuPowerUpsEnabled = $01
VariantMenuPowerUpToggleMask = $01
VariantMenuInitialQueueByteCount = $45
VariantMenuNameQueueByteCount    = $0A
VariantMenuCursorQueueByteCount  = $04

; Обрабатывает маркер первого запуска без дополнительного stack frame: ветка
; маркера проваливается в RunVariantSelectionMenu, и его RTS возвращает caller-у.
; Вход: A=GameVariant, NMI включён. Если A!=BootVariantMarker, A/X/Y и RAM
; сохраняются; N/Z/C заданы CMP #BootVariantMarker, V сохраняется. При равенстве
; синхронно запускает меню и возвращается только после START с его состоянием
; регистров, RAM, shadow/PPU и flags.
HandleBootVariantMarker:
LC49C:  cmp     #BootVariantMarker
        beq     RunVariantSelectionMenu
        rts

VariantMenuRow       = TitleSecretInputCode
VariantMenuTextPtrLo = ConstructionMapFlag

; Модальное меню четырнадцати вариантов. Всегда начинает с GameVariant=$80,
; AllPowerUpsEnabled=1 и MenuSelection=0. DOWN циклически проходит
; 0..6,$80..$86,0; UP — тот же порядок назад. Проверки общего диапазона нет:
; корректное wrap-поведение гарантировано только для этих четырнадцати значений.
;
; Приоритет ввода в одной итерации: held DOWN, held UP, pressed SELECT,
; pressed START. Первые два вызывают блокирующую задержку ровно 16 NMI перед
; каждым изменением; helper не перепроверяет held после ожидания, поэтому даже
; отпущенное во время задержки направление даёт один шаг. SELECT/START работают
; по фронту. SELECT переключает bit0 AllPowerUpsEnabled и ждёт кадр внутри
; DrawPowerUpMenuOption; последующая проверка START видит уже новый input-frame,
; поэтому одновременный с SELECT старый START-edge обычно теряется.
;
; Выход по START: A=BUTTON_START, N=0/Z=0; X/Y, C/V и ScratchPtr зависят от
; предшествующего пути. Cursor ставится в очередь до проверки ввода, но после
; него ожидания нет: PpuBufferPos может содержать ещё не исполненную cursor-
; команду (VariantMenuCursorQueueByteCount=4 байта). После шага это могут быть
; blank старой позиции и cursor новой (всего 8 байт).
; Caller должен дать NMI исполнить остаток либо намеренно отбросить его перед
; заменой экрана.
;
; Меняет shadow nametable, PPU queue/registers, input/audio через ожидания,
; FrameCounter, GameVariant, AllPowerUpsEnabled, MenuSelection, scroll/nametable
; state, A/X/Y, ScratchPtr/AuxPtr и PpuTileRowBits. После отрисовки списка
; overlay-алиасы не восстанавливаются: VariantMenuRow/TitleSecretInputCode=$0E,
; VariantMenuTextPtrLo/ConstructionMapFlag=$B0 (текущий адрес сразу после
; четырнадцатой записи VariantMenuTankNames).
;
; Экран строится в nametable $2000: ShadowToPrimaryNametableOffset прибавляется
; к high byte $04 shadow-буфера, а NametableBits=0 выбирает ту же nametable.
; DisableRenderingForBulkUpdate сначала исполняет прежнюю очередь, поэтому batch
; начинается с PpuBufferPos=0. До первого ожидания очередь получает
; VariantMenuInitialQueueByteCount (69) байтов: header, два divider и power-up
; option; расширение строк не должно превысить 127-байтный buffer с lookahead.
; Затем каждая VariantMenuNameQueueByteCount-байтная (10) name-команда передаётся
; отдельным NMI. NMI не должен прервать построение отдельной команды. Меню само
; не выбирает background palette: первый NMI использует уже загруженную palette
; либо внешний pending BackgroundPaletteIndex. Все 14 восьмибайтных записей имён
; обязаны оставаться на странице VariantMenuTankNames: цикл увеличивает только
; low byte. Координаты layout: имена columns 13..19/rows 9..22, cursor column 11;
; производная разметка должна оставаться в пределах строк nametable.
RunVariantSelectionMenu:
LC4A1:  lda     #VariantExtendedFirst
        sta     GameVariant
        jsr     DisableRenderingForBulkUpdate
        lda     #ShadowToPrimaryNametableOffset
        sta     NametablePpuOffset
        lda     #$00
        sta     VerticalScroll
        sta     NametableBits
        jsr     ClearNametableBuffer
        jsr     UploadNametableBuffer
        jsr     EnableNmiAfterVblank
        lda     #>VariantMenuHeaderText
        sta     ScratchPtrHi
        lda     #<VariantMenuHeaderText
        sta     ScratchPtrLo
        ldy     #VariantMenuHeaderRow
        ldx     #VariantMenuHeaderColumn
        jsr     QueueTileAtCoordinates
        lda     #>VariantMenuDividerText
        sta     ScratchPtrHi
        lda     #<VariantMenuDividerText
        sta     ScratchPtrLo
        ldy     #VariantMenuLowerDividerRow
        ldx     #VariantMenuHeaderColumn
        jsr     QueueTileAtCoordinates
        lda     #>VariantMenuDividerText
        sta     ScratchPtrHi
        lda     #<VariantMenuDividerText
        sta     ScratchPtrLo
        ldy     #VariantMenuUpperDividerRow
        ldx     #VariantMenuHeaderColumn
        jsr     QueueTileAtCoordinates
        lda     #VariantMenuPowerUpsEnabled
        sta     AllPowerUpsEnabled
        jsr     DrawPowerUpMenuOption
        lda     #<VariantMenuTankNames
        sta     VariantMenuTextPtrLo
        lda     #$00
        sta     MenuSelection
        sta     VariantMenuRow
DrawNextVariantMenuRow:
LC4F9:  lda     #>VariantMenuTankNames
        sta     ScratchPtrHi
        lda     VariantMenuTextPtrLo
        sta     ScratchPtrLo
        clc
        adc     #VariantMenuTextStride
        sta     VariantMenuTextPtrLo
        lda     VariantMenuRow
        clc
        adc     #VariantMenuFirstTextRow
        tay
        ldx     #VariantMenuNameColumn
        jsr     QueueTileAtCoordinates
        jsr     WaitForNextFrame
        inc     VariantMenuRow
        lda     VariantMenuRow
        cmp     #VariantMenuRowCount
        bcc     DrawNextVariantMenuRow
DrawVariantMenuCursor:
LC51C:  lda     #>VariantMenuSelectionCursor
        sta     ScratchPtrHi
        lda     #<VariantMenuSelectionCursor
        sta     ScratchPtrLo
        jsr     QueueVariantMenuText
        ; Cursor — continuation общего цикла: после постановки строки в очередь
        ; выполнение намеренно проваливается прямо в обработку ввода.
VariantMenuInputLoop:
LC527:  lda     Joy1Held
        and     #BUTTON_DOWN
        beq     CheckVariantMenuUp
        jsr     WaitVariantMenuRepeatAndEraseCursor
        inc     GameVariant
        lda     GameVariant
        ; 6+1 переходит к первому extended-варианту.
        cmp     #VariantStandardPastLast
        bne     CheckVariantMenuExtendedUpperBound
        lda     #VariantExtendedFirst
CheckVariantMenuExtendedUpperBound:
LC53A:  cmp     #VariantExtendedPastLast
        bne     CommitVariantMenuSelection
        ; $86+1 завершает полный цикл на standard 0.
        lda     #VariantStandardFirst
CommitVariantMenuSelection:
LC540:  sta     GameVariant
        jmp     DrawVariantMenuCursor

CheckVariantMenuUp:
LC545:  lda     Joy1Held
        and     #BUTTON_UP
        beq     CheckVariantMenuPowerUps
        jsr     WaitVariantMenuRepeatAndEraseCursor
        dec     GameVariant
        lda     GameVariant
        cmp     #VariantStandardBeforeFirst
        bne     CheckVariantMenuExtendedLowerBound
        ; 0-1 переходит к последнему extended-варианту.
        lda     #(VariantExtendedPastLast-1)
CheckVariantMenuExtendedLowerBound:
LC558:  cmp     #VariantExtendedBeforeFirst
        bne     CommitPreviousVariantSelection
        ; $80-1 переходит к последнему standard-варианту.
        lda     #(VariantStandardPastLast-1)
CommitPreviousVariantSelection:
LC55E:  sta     GameVariant
        jmp     DrawVariantMenuCursor

CheckVariantMenuPowerUps:
LC563:  lda     Joy1Pressed
        and     #BUTTON_SELECT
        beq     CheckVariantMenuExit
        ; Штатный вход всегда начинает с 1, поэтому bit toggle даёт только 0/1.
        lda     AllPowerUpsEnabled
        eor     #VariantMenuPowerUpToggleMask
        sta     AllPowerUpsEnabled
        jsr     DrawPowerUpMenuOption
CheckVariantMenuExit:
LC572:  lda     Joy1Pressed
        and     #BUTTON_START
        beq     VariantMenuInputLoop
        rts

; Блокирующий debounce/autorepeat одного шага.
; Сбрасывает FrameCounter=0 и всегда выполняет 16 WaitForNextFrame до первого
; следующего значения, для которого FrameCounter&$0F=0. Joy1Held после ожидания
; не проверяет: caller безусловно меняет GameVariant. Первый NMI также исполняет
; ранее queued cursor. После 16-го NMI запрашивает menu-step sound и добавляет
; четырёхбайтную команду blank в старую позицию cursor; shadow меняется сразу,
; PPU исполнит её только следующим NMI.
; Вход: NMI включён, GameVariant в одном из menu-диапазонов, в buffer есть место
; для команды и lookahead. Выход: FrameCounter=$10, A=$FF, X=PpuBufferPos=4,
; Y=1, N=0/Z=1/C=1; ScratchPtr=VariantMenuBlankCursorText. Меняет input/OAM/
; audio через NMI, RicochetOrMenuStepAudioState, AuxPtr/PpuTileRowBits, shadow и
; PPU queue; V не определён контрактом. Проверяется масочная фаза
; FrameCounter&$0F=0; сделанный здесь reset гарантирует первый match на $10,
; а внешний writer FrameCounter может сократить или удлинить задержку.
WaitVariantMenuRepeatAndEraseCursor:
LC579:  lda     #$00
        sta     FrameCounter
WaitForVariantMenuRepeatPhase:
LC57D:  jsr     WaitForNextFrame
        lda     FrameCounter
        and     #VariantMenuRepeatFrameMask
        bne     WaitForVariantMenuRepeatPhase
        lda     #AudioStateStartRequested
        sta     RicochetOrMenuStepAudioState
        lda     #>VariantMenuBlankCursorText
        sta     ScratchPtrHi
        lda     #<VariantMenuBlankCursorText
        sta     ScratchPtrLo
        jsr     QueueVariantMenuText
        rts

; Два статически неиспользуемых дубля: возвращают A=0, N=0/Z=1; C/V, RAM и
; X/Y не меняют.
ReturnZeroStub1:
LC597:  lda     #$00
        rts
ReturnZeroStub2:
LC59A:  lda     #$00
        rts
