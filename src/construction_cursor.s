; Рисование и движение курсора Construction ($C6C6-$C71D).

; Рисует в Construction метатайл ConstructionMetatileIndex&$0F в координатах курсора ObjectX/ObjectY.
; Портит A/X/Y и nametable shadow/PPU-очередь через DrawMetatile.
DrawConstructionMetatile:
LC6C6:  lda     ConstructionMetatileIndex
        and     #$0F
        ldx     ObjectX
        ldy     ObjectY
        jsr     DrawMetatile
        rts

; Двигает Construction-курсор на 16 px по фронту D-pad; после 20 кадров удержания включает автоповтор,
; оставляя ConstructionMoveRepeatTimer=$0F между шагами. Меняет ObjectX/ObjectY,
; ConstructionMoveRepeatTimer/ConstructionEditLatch; портит A/Y и флаги, X не меняет.
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
        cmp     #$14
        beq     RepeatConstructionCursorMove
        lda     Joy1Pressed
        and     #BUTTON_DIRECTIONS
        beq     FinishConstructionCursorUpdate
        lda     Joy1Pressed
        jsr     DecodeDirectionButtons
        bmi     FinishConstructionCursorUpdate
        jmp     ApplyConstructionCursorMove

RepeatConstructionCursorMove:
LC6FB:  lda     #$0F
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
