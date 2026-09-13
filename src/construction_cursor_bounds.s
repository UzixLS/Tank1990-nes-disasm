; Ограничение координат курсора Construction ($C8D0-$C8F8).

ConstructionCursorMinimum = $18
ConstructionCursorMaximum = $D8

; Ограничивает ObjectX/ObjectY включительным диапазоном
; ConstructionCursorMinimum..ConstructionCursorMaximum. Выход: A=итоговый
; ObjectY; меняет координаты только при выходе за границы, портит флаги,
; X/Y и PPU/OAM сохраняет.
ClampConstructionCursor:
LC8D0:  lda     ObjectX
        cmp     #ConstructionCursorMaximum
        bcc     ClampConstructionCursorLeft
        lda     #ConstructionCursorMaximum
        sta     ObjectX
ClampConstructionCursorLeft:
LC8DA:  lda     ObjectX
        cmp     #ConstructionCursorMinimum
        bcs     ClampConstructionCursorBottom
        lda     #ConstructionCursorMinimum
        sta     ObjectX
ClampConstructionCursorBottom:
LC8E4:  lda     ObjectY
        cmp     #ConstructionCursorMaximum
        bcc     ClampConstructionCursorTop
        lda     #ConstructionCursorMaximum
        sta     ObjectY
ClampConstructionCursorTop:
LC8EE:  lda     ObjectY
        cmp     #ConstructionCursorMinimum
        bcs     FinishConstructionCursorClamp
        lda     #ConstructionCursorMinimum
        sta     ObjectY
FinishConstructionCursorClamp:
LC8F8:  rts
