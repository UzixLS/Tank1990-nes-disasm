; Логика заглавного меню и курсора ($C9C0-$CA90).

; Активный экран заголовка и главного меню.
; Использует слот танка 0 как мигающий курсор; SELECT циклически выбирает
; 1 PLAYER / 2 PLAYERS / CONSTRUCTION, START передаёт управление через таблицу.
; Если ConstructionMapFlag=0, после десяти тиков SlowFrameCounter возвращается для запуска демо-цикла.
; Скрытая комбинация ввода меняет TitleSecretInputCode; значение $2E при START открывает variant-меню.
; Побочно меняет состояние танков, MenuSelection, SlowFrameCounter/TitleSecretInputCode, scroll/nametable,
; палитру и OAM. A/X/Y не сохраняются. Ветви START снимают со стека адрес
; вызова TitleScreen и потому не возвращаются обычным RTS.
TitleScreen:
LC9C0:  lda     #$03
        sta     BackgroundPaletteIndex
        jsr     ClearTankStates
        lda     #$48
        sta     ObjectX
        jsr     UpdateTitleCursor
        lda     #$83
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
        lda     #$10
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
        cmp     #$03
        bcc     UpdateTitleMenuCursor
        lda     #$00
        sta     MenuSelection
UpdateTitleMenuCursor:
LCA2F:  jsr     UpdateTitleCursor
        lda     SlowFrameCounter
        cmp     #$0A
        bne     CheckTitleStartInput
        lda     ConstructionMapFlag
        bne     CheckTitleStartInput
        rts
CheckTitleStartInput:
LCA3D:  lda     Joy1Pressed
        and     #BUTTON_START
        beq     TitleMenuLoop
        lda     TitleSecretInputCode
        cmp     #$2E
        bne     DispatchTitleMenuSelection
        jsr     RunVariantSelectionMenu
        pla
        pla
        jmp     MainFrontendLoop

        .byte   $EA
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

; Три адреса безвозвратной диспетчеризации по MenuSelection=0..2.
MenuSelectionHandlers:
LCA69:  .word   StartOnePlayer, StartTwoPlayers, StartConstruction

; GameMode=$05, новая игровая сессия и переход к выбору этапа.
StartOnePlayer:
        lda     #$05
        jmp     StartSelectedGameMode

; GameMode=$07, новая игровая сессия и переход к выбору этапа.
StartTwoPlayers:
        lda     #$07
StartSelectedGameMode:
LCA76:  sta     GameMode
        jsr     InitializeGameSession
        jmp     SelectStage

; Переходит в редактор Construction с GameMode=$07; сессию не инициализирует.
StartConstruction:
        lda     #$07
        sta     GameMode
        jmp     ConstructionMode

; Преобразует MenuSelection=0..2 в Y курсора:
; ObjectY=$8B+MenuSelection*$10. Возвращает это же значение в A; X/Y сохраняет.
UpdateTitleCursor:
LCA85:  lda     MenuSelection
        asl     a
        asl     a
        asl     a
        asl     a
        clc
        adc     #$8B
        sta     ObjectY
        rts
