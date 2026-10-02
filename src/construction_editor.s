; Основной цикл редактора Construction ($C0AE-$C158).

; Редактор Construction: перемещает курсор, меняет TSA-блок и затем
; возвращается в общий игровой цикл.
ConstructionMetatileIndex    = $5C
ConstructionMoveHoldCounter = $7B
ConstructionMetatileCycleArmed = $81
ConstructionMetatileCount    = $0E
ConstructionMetatileBeforeFirst = $FF
ConstructionMetatileFirst    = $00
ConstructionCursorStartX     = $10
ConstructionCursorStartY     = $18
ConstructionCursorRenderState = TankStateIdleClass | TankIdlePhaseStep
ConstructionCursorVisibleFrameBit = $10
ConstructionPaintButtonMask  = BUTTON_A | BUTTON_B
ConstructionMode:
; Вход: NMI включён, NametablePpuOffset=ShadowToPrimaryNametableOffset.
; ConstructionMapFlag=0 создаёт поле: весь shadow сначала заполняется boundary,
; прямоугольник tiles (2,2)..(27,27) очищается и напрямую загружается в $2000,
; после чего кирпичная база добавляется в shadow/PPU-очередь. Ненулевой флаг
; пропускает эту инициализацию и повторно использует уже отредактированное поле.
;
; Объект 0 становится мигающим курсором. D-pad двигает его по сетке 16 px;
; после clamp центры ячеек лежат в $18..$D8, что покрывает 13x13 метатайлов.
; A/B выбирают только первые ConstructionMetatileCount записей TSA ($00..$0D;
; $0E/$0F из общей таблицы недоступны). Первый новый A/B после входа или движения
; лишь рисует текущий TSA и вооружает циклический выбор; следующие фронты A/B
; выбирают следующий/предыдущий TSA с кольцевым переходом. Удержание A/B повторно
; рисует выбранный TSA каждый кадр без смены индекса. При одновременном фронте
; A+B имеет приоритет A. Любой удерживаемый D-pad сбрасывает вооружение и
; подавляет обработку фронтов A/B, но удерживаемая A/B всё равно рисует.
;
; START проверяется после возможного рисования, восстанавливает terrain-priority,
; увеличивает ConstructionMapFlag по модулю 256 и хвостом переходит в
; EnterTitleMenu. Процедура сама не возвращается; меняет object slot 0,
; PlayerStunTimer обоих игроков, scroll/nametable state, shadow nametable,
; PPU-очередь, OAM shadow/cursor и рабочую RAM, портит A/X/Y. Каждый проход
; начинается с WaitForNextFrame, поэтому команда рисования обычно передаётся
; следующим NMI.
;
; Начальный X=$10 находится левее диапазона центров, но DrawMetatile всё ещё
; сопоставляет его первой ячейке. Без Right первый clamp переводит X в $18;
; немедленный Right даёт $20 и тем самым выбирает вторую ячейку без пропуска.
LC0AE:  lda     ConstructionMapFlag
        bne     InitializeConstructionEditor
        ; Только первый вход создаёт и напрямую загружает чистое поле $2000.
        jsr     DisableRenderingForBulkUpdate
        jsr     InitializePlayfieldRectangle
        jsr     UploadNametableBuffer
        jsr     EnableNmiAfterVblank
InitializeConstructionEditor:
        ; Object slot 0 переиспользуется как видимый поверх terrain курсор.
LC0BE:  jsr     ClearTankStates
        lda     #ConstructionCursorStartX
        sta     ObjectX
        lda     #ConstructionCursorStartY
        sta     ObjectY
        lda     #ConstructionCursorRenderState
        sta     ObjectState
        lda     #$00
        sta     ObjectAttributes
        ; Тот же ноль отключает terrain-priority курсора.
        sta     SpriteBehindTerrainMask
        sta     ObjectFrame
        sta     ConstructionMetatileCycleArmed
        sta     ConstructionMoveHoldCounter
        sta     ConstructionMetatileIndex
        sta     VerticalScroll
        sta     NametableBits
        sta     PlayerStunTimer
        sta     PlayerStunTimer+1
        lda     ConstructionMapFlag
        bne     ConstructionEditorFrame
        ; Tile/attribute-команды базы исполнит NMI первого прохода цикла.
        jsr     DrawBrickBaseEnclosure
ConstructionEditorFrame:
LC0EA:  jsr     WaitForNextFrame
        jsr     UpdateConstructionCursor
        jsr     ClampConstructionCursor
        lda     FrameCounter
        and     #ConstructionCursorVisibleFrameBit
        beq     ProcessConstructionEditorInput
        ; Bit4 даёт 16 кадров с курсором и 16 без новых cursor OAM entries.
        jsr     DrawTanks
ProcessConstructionEditorInput:
LC0FC:  lda     Joy1Held
        and     #BUTTON_DIRECTIONS
        bne     CheckConstructionPaintHeld
        lda     Joy1Pressed
        and     #BUTTON_A
        beq     CheckConstructionPreviousTile
        lda     ConstructionMetatileCycleArmed
        bne     SelectNextConstructionTile
        inc     ConstructionMetatileCycleArmed
        jmp     PaintConstructionTile

SelectNextConstructionTile:
LC111:  inc     ConstructionMetatileIndex
        lda     ConstructionMetatileIndex
        cmp     #ConstructionMetatileCount
        bne     PaintConstructionTile
        lda     #ConstructionMetatileFirst
        sta     ConstructionMetatileIndex
        jmp     PaintConstructionTile

CheckConstructionPreviousTile:
LC120:  lda     Joy1Pressed
        and     #BUTTON_B
        beq     CheckConstructionPaintHeld
        lda     ConstructionMetatileCycleArmed
        bne     SelectPreviousConstructionTile
        inc     ConstructionMetatileCycleArmed
        jmp     PaintConstructionTile

SelectPreviousConstructionTile:
LC12F:  dec     ConstructionMetatileIndex
        lda     ConstructionMetatileIndex
        cmp     #ConstructionMetatileBeforeFirst
        bne     PaintConstructionTile
        lda     #(ConstructionMetatileCount-1)
        sta     ConstructionMetatileIndex
        jmp     PaintConstructionTile

CheckConstructionPaintHeld:
LC13E:  lda     Joy1Held
        and     #ConstructionPaintButtonMask
        beq     CheckConstructionExit
PaintConstructionTile:
LC144:  jsr     DrawConstructionMetatile
CheckConstructionExit:
LC147:  lda     Joy1Pressed
        and     #BUTTON_START
        bne     ExitConstructionEditor
        jmp     ConstructionEditorFrame

ExitConstructionEditor:
LC150:  lda     #TerrainPriorityEnabled
        sta     SpriteBehindTerrainMask
        inc     ConstructionMapFlag
        jmp     EnterTitleMenu
