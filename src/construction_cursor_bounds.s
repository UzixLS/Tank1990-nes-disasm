; Ограничение координат курсора Construction ($C8D0-$C8F8).

; Ограничивает Construction-курсор прямоугольником $18..$D8 по обеим осям.
; Меняет ObjectX/ObjectY только при выходе за границы; портит A и флаги, X/Y сохраняет.
ClampConstructionCursor:
LC8D0:  lda     ObjectX
        cmp     #$D8
        bcc     ClampConstructionCursorLeft
        lda     #$D8
        sta     ObjectX
ClampConstructionCursorLeft:
LC8DA:  lda     ObjectX
        cmp     #$18
        bcs     ClampConstructionCursorBottom
        lda     #$18
        sta     ObjectX
ClampConstructionCursorBottom:
LC8E4:  lda     ObjectY
        cmp     #$D8
        bcc     ClampConstructionCursorTop
        lda     #$D8
        sta     ObjectY
ClampConstructionCursorTop:
LC8EE:  lda     ObjectY
        cmp     #$18
        bcs     FinishConstructionCursorClamp
        lda     #$18
        sta     ObjectY
FinishConstructionCursorClamp:
LC8F8:  rts
