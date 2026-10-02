; Рисование и движение курсора Construction ($C6C6-$C71D).

ConstructionMoveRepeatThreshold = $14
ConstructionMoveRepeatReload = $0F
ConstructionMetatileIndexMask = $0F

; Рисует метатайл ConstructionMetatileIndex&$0F в 16x16-блоке, содержащем
; ObjectX/ObjectY. При штатных центрах $18+$10*n это одна из 13 ячеек поля:
; tile pairs 2/3, 4/5, ... 26/27 по каждой оси.
; Вход: ConstructionMetatileIndex штатно $00..$0D; ObjectX/Y уже ограничены;
; PpuBufferPos<=MetatileQueueMaxStartPos ($6B), чтобы в update buffer поместились
; 20 байт команд и следующий lookahead; NMI не прерывает построение очереди.
; Добавляет одну четырёхбайтную attribute-команду
; и четыре четырёхбайтные tile-команды; соответствующие четыре tile bytes и
; один palette quadrant shadow меняются немедленно. Все PPU-адреса жёстко
; относятся к primary nametable и игнорируют NametablePpuOffset; PPU registers
; не трогает.
; Выход: A=$FF, X=4*(ConstructionMetatileIndex&$0F)+4, Y=0,
; PpuBufferPos=old PpuBufferPos+20; ScratchPtr указывает на нижний правый tile
; ячейки, N=Z=C=V=0. ConstructionMetatileIndex и ObjectX/Y сохранены.
; Портит MetatileIndex, MetatileTileX/ShadowQueueSavedX=$47,
; MetatileTileY=$48, RenderAttributes, PpuBufferPos/PpuUpdateBuffer, ScratchPtr
; и временные $01..$03.
DrawConstructionMetatile:
LC6C6:  lda     ConstructionMetatileIndex
        and     #ConstructionMetatileIndexMask
        ldx     ObjectX
        ldy     ObjectY
        jsr     DrawMetatile
        rts

; Двигает Construction-курсор на 16 px. На первом кадре D-pad фронт даёт шаг
; сразу, а ConstructionMoveHoldCounter становится 1. При непрерывном удержании
; первый повтор срабатывает на 20-м вызове (через 19 кадров после первого шага),
; записывает counter=15 и затем повторяется каждые 5 вызовов. Отпускание всего
; D-pad сбрасывает counter=0. При нескольких направлениях DecodeDirectionButtons
; выбирает Right, Left, Down, Up именно в таком порядке.
;
; Любой удерживаемый D-pad каждый кадр сбрасывает ConstructionMetatileCycleArmed,
; даже если шага в этом кадре нет. Четыре ASL масштабируют табличное смещение
; -1/0/+1 до жёсткого шага сетки 16 px; clipping выполняет отдельный следующий
; вызов ClampConstructionCursor. Repeat использует точное равенство counter=$14:
; штатный reset=0 обязателен; произвольное начальное значение выше порога ждёт
; восьмибитного wrap, а не срабатывает немедленно. Меняет ConstructionMoveHoldCounter/
; ConstructionMetatileCycleArmed и, при шаге, ObjectX/ObjectY. На пути шага
; выход: A=новый ObjectY, Y=выбранное direction; без шага A=0, Y сохраняется.
; X всегда сохраняется. Портит flags; PPU/OAM не меняет.
UpdateConstructionCursor:
LC6D2:  lda     Joy1Held
        and     #BUTTON_DIRECTIONS
        beq     ResetConstructionMoveRepeat
        inc     ConstructionMoveHoldCounter
        lda     #$00
        sta     ConstructionMetatileCycleArmed
        jmp     CheckConstructionMoveStep

ResetConstructionMoveRepeat:
LC6E1:  lda     #$00
        sta     ConstructionMoveHoldCounter
CheckConstructionMoveStep:
LC6E5:  lda     ConstructionMoveHoldCounter
        cmp     #ConstructionMoveRepeatThreshold
        beq     RepeatConstructionCursorMove
        lda     Joy1Pressed
        and     #BUTTON_DIRECTIONS
        beq     FinishConstructionCursorUpdate
        lda     Joy1Pressed
        jsr     DecodeDirectionButtons
        bmi     FinishConstructionCursorUpdate
        jmp     ApplyConstructionCursorMove

RepeatConstructionCursorMove:
LC6FB:  lda     #ConstructionMoveRepeatReload
        sta     ConstructionMoveHoldCounter
        lda     Joy1Held
        jsr     DecodeDirectionButtons
ApplyConstructionCursorMove:
LC704:  tay
        lda     DirectionStepX,y
        asl     a
        asl     a
        asl     a
        asl     a
        clc
        adc     ObjectX
        sta     ObjectX
        lda     DirectionStepY,y
        asl     a
        asl     a
        asl     a
        asl     a
        clc
        adc     ObjectY
        sta     ObjectY
FinishConstructionCursorUpdate:
LC71D:  rts
