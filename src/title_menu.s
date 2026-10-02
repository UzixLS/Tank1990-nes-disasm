; Логика заглавного меню и курсора ($C9C0-$CA90).

TitleMenuItemCount       = $03
TitleAttractDelayTicks   = $0A
TitleVariantMenuCode     = $2E
TitleSecretHighStep      = $10
TitleBackgroundPalette   = $03
TitleExitBackgroundPalette = $00
TitleNametableBits       = $02
TitleCursorX             = $48
TitleCursorFirstY        = $8B
TitleCursorAnimationFrameMask = $03
; Активный экран заголовка и главного меню.
; Использует слот танка 0 как анимированный курсор; SELECT циклически выбирает
; 1 PLAYER / 2 PLAYERS / CONSTRUCTION, START передаёт управление через таблицу.
; Каждый цикл ждёт NMI, который передаёт прежний OAM shadow, исполняет PPU queue,
; читает новый input и обновляет audio/frame counters; после него DrawTanks
; строит OAM следующего кадра. Cursor frame меняет bit2 раз в четыре значения
; FrameCounter. Прямых записей PPU и новых PPU-команд здесь нет.
;
; Порядок действий в одном input-frame: SELECT; Down-held+A-pressed;
; Right-held+B-pressed; нормализация MenuSelection; timeout; START. Поэтому
; SELECT+START запускает уже следующий пункт и сбрасывает timeout, обе secret-
; пары вместе дают +$10-1=$0F, а START видит обновлённый в этом же кадре код.
; Secret arithmetic восьмибитная без saturation: +$10 и DEC оборачиваются.
;
; При ConstructionMapFlag=0 точное SlowFrameCounter=$0A имеет приоритет над
; START и возвращает caller-у для attract mode. Счётчик растёт раз в 64 NMI,
; но фаза FrameCounter не сбрасывается; SELECT начинает интервал заново с нуля.
; При ненулевом ConstructionMapFlag автоматический выход полностью запрещён.
;
; Вход штатно из JSR EnterTitleMenu, MenuSelection=0..2, NMI включён и OAM
; frame имеет место для двух entries cursor tank. Фактически WaitForNextFrame
; перед каждой отрисовкой сам завершает предыдущий OAM frame, ставит cursor в
; OamBufferPos=4 и меняет направление выдачи entries; DrawTanks затем добавляет
; ровно две entries, поскольку stun timers курсора очищены. START-пути намеренно
; снимают именно двухбайтовый return address этого JSR и не возвращаются; прямой
; JMP-вход нарушит стек. Обычный timeout-выход:
; A=0, N=0/Z=1/C=1/V=0; X/Y принадлежат последнему DrawTanks. Побочно очищает
; tank states и общий диапазон PlayerIceState..$010A, настраивает slot 0,
; MenuSelection, secret/slow counters, scroll/nametable, palette request и OAM;
; CurrentTankSlot после каждого DrawTanks равен TankSlotCount, ScratchPtr и
; render/OAM scratch volatile.
TitleScreen:
LC9C0:  lda     #TitleBackgroundPalette
        sta     BackgroundPaletteIndex
        jsr     ClearTankStates
        lda     #TitleCursorX
        sta     ObjectX
        jsr     UpdateTitleCursor
        lda     #(TankStateIdleClass | DIRECTION_RIGHT)
        sta     ObjectState
        lda     #$00
        sta     SlowFrameCounter
        sta     ObjectAttributes
        sta     ObjectFrame
        sta     PlayerStunTimer
        sta     PlayerStunTimer+1
        sta     VerticalScroll
        sta     TitleSecretInputCode
        lda     #TitleNametableBits
        sta     NametableBits
TitleMenuLoop:
LC9E6:  jsr     WaitForNextFrame
        lda     FrameCounter
        and     #TitleCursorAnimationFrameMask
        bne     DrawTitleCursorAndReadInput
        lda     ObjectFrame
        eor     #TankTrackFrameBit
        sta     ObjectFrame
DrawTitleCursorAndReadInput:
LC9F5:  jsr     DrawTanks
        lda     Joy1Pressed
        and     #BUTTON_SELECT
        beq     CheckTitleSecretDownA
        inc     MenuSelection
        lda     #$00
        sta     SlowFrameCounter
CheckTitleSecretDownA:
LCA04:  lda     Joy1Held
        and     #BUTTON_DOWN
        beq     CheckTitleSecretRightB
        lda     Joy1Pressed
        and     #BUTTON_A
        beq     CheckTitleSecretRightB
        ; Down-held+A-edge: code=(code+$10) mod 256.
        lda     #TitleSecretHighStep
        clc
        adc     TitleSecretInputCode
        sta     TitleSecretInputCode
CheckTitleSecretRightB:
LCA17:  lda     Joy1Held
        and     #BUTTON_RIGHT
        beq     NormalizeTitleMenuSelection
        lda     Joy1Pressed
        and     #BUTTON_B
        beq     NormalizeTitleMenuSelection
        ; Right-held+B-edge: code=(code-1) mod 256.
        dec     TitleSecretInputCode
NormalizeTitleMenuSelection:
LCA25:  lda     MenuSelection
        cmp     #TitleMenuItemCount
        bcc     UpdateTitleMenuCursor
        lda     #$00
        sta     MenuSelection
UpdateTitleMenuCursor:
LCA2F:  jsr     UpdateTitleCursor
        lda     SlowFrameCounter
        cmp     #TitleAttractDelayTicks
        bne     CheckTitleStartInput
        lda     ConstructionMapFlag
        bne     CheckTitleStartInput
        ; Exact equality wins over a simultaneous START edge.
        rts
CheckTitleStartInput:
LCA3D:  lda     Joy1Pressed
        and     #BUTTON_START
        beq     TitleMenuLoop
        lda     TitleSecretInputCode
        cmp     #TitleVariantMenuCode
        bne     DispatchTitleMenuSelection
        jsr     RunVariantSelectionMenu
        ; Variant menu вернулось по START. Снять return address TitleScreen и
        ; полностью перестроить frontend; pending cursor queue исполнит первый
        ; NMI следующего BuildTitleNametable, после чего экран будет очищен.
        pla
        pla
        jmp     MainFrontendLoop

; Недостижимый байт между безусловным JMP и отдельным входом dispatch.
UnreferencedCa51Nop:
LCA51:  .byte   $EA
DispatchTitleMenuSelection:
LCA52:  lda     #TitleExitBackgroundPalette
        sta     BackgroundPaletteIndex
        ; Удалить return address TitleScreen: handler продолжает верхний
        ; сценарий и не должен попасть в attract continuation после JSR.
        pla
        pla
        lda     MenuSelection
        asl     a
        tay
        lda     MenuSelectionHandlers,y
        sta     ScratchPtrLo
        lda     MenuSelectionHandlers+1,y
        sta     ScratchPtrHi
        jmp     (ScratchPtrLo)

; Три little-endian адреса безвозвратной диспетчеризации по MenuSelection=0..2.
; Bounds check здесь уже нет: TitleMenuItemCount, таблица, cursor layout и
; семантика MenuSelection в InitializeGameSession должны меняться согласованно.
MenuSelectionHandlers:
LCA69:  .word   StartOnePlayer, StartTwoPlayers, StartConstruction

; GameMode=OnePlayerGameMode, новая игровая сессия и переход к выбору этапа.
StartOnePlayer:
        lda     #OnePlayerGameMode
        jmp     StartSelectedGameMode

; GameMode=TwoPlayerGameMode, новая игровая сессия и переход к выбору этапа.
StartTwoPlayers:
        lda     #TwoPlayerGameMode
StartSelectedGameMode:
LCA76:  sta     GameMode
        jsr     InitializeGameSession
        jmp     SelectStage

; Переходит в редактор Construction с TwoPlayerGameMode; сессию не инициализирует.
StartConstruction:
        lda     #TwoPlayerGameMode
        sta     GameMode
        jmp     ConstructionMode

; Преобразует MenuSelection=0..2 в Y курсора:
; ObjectY=TitleCursorFirstY+MenuSelection*16. Множитель зашит четырьмя ASL,
; поэтому это layout-ограничение, а не настраиваемая константа.
; Выход для валидного input: A=ObjectY=$8B/$9B/$AB, N=1/Z=0/C=0/V=0;
; X/Y, MenuSelection, стек и прочая RAM сохраняются. Для произвольного byte
; умножение и сложение выполняются modulo 256, clipping нет.
UpdateTitleCursor:
LCA85:  lda     MenuSelection
        asl     a
        asl     a
        asl     a
        asl     a
        clc
        adc     #TitleCursorFirstY
        sta     ObjectY
        rts
