; Рисование и движение курсора Construction ($C6C6-$C71D).

ConstructionMoveInitialDelay = $14
ConstructionMoveRepeatReload = $0F

; Рисует метатайл ConstructionMetatileIndex&$0F в координатах ObjectX/ObjectY.
; Входные RAM-поля не меняет; портит A/X/Y и ScratchPtr, изменяет shadow
; nametable/атрибуты и PPU-очередь через DrawMetatile.
DrawConstructionMetatile:
LC6C6:  lda     ConstructionMetatileIndex
        and     #$0F
        ldx     ObjectX
        ldy     ObjectY
        jsr     DrawMetatile
        rts

; Двигает Construction-курсор на 16 px по фронту D-pad. После 20 вызовов
; удержания включает повтор с периодом 5 вызовов: после каждого шага таймер
; перезагружается значением 15. Любой удерживаемый D-pad обнуляет
; ConstructionEditLatch. Портит A/Y и флаги, X сохраняет; PPU/OAM не меняет.
UpdateConstructionCursor:
LC6D2:  lda     Joy1Held
        and     #BUTTON_DIRECTIONS
        beq     ResetConstructionMoveRepeat
        inc     ConstructionMoveRepeatTimer
        lda     #$00
        sta     ConstructionEditLatch
        jmp     CheckConstructionMoveStep

ResetConstructionMoveRepeat:
LC6E1:  lda     #$00
        sta     ConstructionMoveRepeatTimer
CheckConstructionMoveStep:
LC6E5:  lda     ConstructionMoveRepeatTimer
        cmp     #ConstructionMoveInitialDelay
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
        sta     ConstructionMoveRepeatTimer
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
