; Логика заглавного меню и курсора ($C9C0-$CA90).

TitleMenuItemCount       = $03
TitleAttractDelayTicks   = $0A
TitleVariantMenuCode     = $2E
TitleSecretHighStep      = $10
TitleCursorX             = $48
TitleCursorFirstY        = $8B
TitleCursorRowStep       = $10
; Активный экран заголовка и главного меню.
; Использует слот танка 0 как мигающий курсор; SELECT циклически выбирает
; 1 PLAYER / 2 PLAYERS / CONSTRUCTION, START передаёт управление через таблицу.
; Если ConstructionMapFlag=0, после TitleAttractDelayTicks приращений
; SlowFrameCounter (одно приращение на 64 кадра) возвращается для запуска демо.
; Скрытая комбинация меняет TitleSecretInputCode; TitleVariantMenuCode при START
; открывает variant-меню. Побочно меняет слот Object 0, MenuSelection,
; SlowFrameCounter/TitleSecretInputCode, scroll/nametable, палитру и OAM.
; Обычный выход по тайм-ауту портит A/X/Y. Ветви START снимают со стека адрес
; вызова TitleScreen и передают управление верхнему сценарию без обычного RTS.
TitleScreen:
LC9C0:  lda     #$03
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
        lda     #$02
        sta     NametableBits
TitleMenuLoop:
LC9E6:  jsr     WaitForNextFrame
        lda     FrameCounter
        and     #$03
        bne     DrawTitleCursorAndReadInput
        lda     ObjectFrame
        eor     #$04
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
        ; Down удерживается, A нажата в этом кадре: старший ниббл TitleSecretInputCode растёт.
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
        ; Right удерживается, B нажата в этом кадре: TitleSecretInputCode уменьшается на единицу.
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
        rts
CheckTitleStartInput:
LCA3D:  lda     Joy1Pressed
        and     #BUTTON_START
        beq     TitleMenuLoop
        lda     TitleSecretInputCode
        cmp     #TitleVariantMenuCode
        bne     DispatchTitleMenuSelection
        jsr     RunVariantSelectionMenu
        pla
        pla
        jmp     MainFrontendLoop

; Недостижимый байт между безусловным JMP и отдельным входом dispatch.
UnreferencedCa51Nop:
LCA51:  .byte   $EA
DispatchTitleMenuSelection:
LCA52:  lda     #$00
        sta     BackgroundPaletteIndex
        ; Удалить адрес возврата TitleScreen: выбранный обработчик продолжает
        ; верхнеуровневый сценарий и не должен вернуться к его вызывающему коду.
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
; ObjectY=TitleCursorFirstY+MenuSelection*TitleCursorRowStep.
; Выход: A=ObjectY; X/Y и прочая RAM сохраняются.
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
