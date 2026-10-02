; Ограничение координат курсора Construction ($C8D0-$C8F8).

ConstructionCursorMinimumCenter = $18
ConstructionCursorMaximumCenter = $D8

; Ограничивает центр курсора по обеим осям включительным диапазоном $18..$D8.
; При дальнейшем 16-пиксельном шаге это 13 позиций; DrawMetatile сопоставляет
; им пары 8x8-тайлов 2/3..26/27, то есть всё поле, подготовленное как rectangle
; (2,2), 26x26 tiles. Сначала независимо ограничивает X, затем Y.
; Вход: ObjectX/ObjectY — беззнаковые экранные координаты после возможного шага.
; Выход: A=ограниченный ObjectY; X/Y registers и остальная RAM сохраняются.
; N/Z относятся к последней LDA/CMP ветке, C=0 только если входной ObjectY был
; ниже minimum, иначе C=1; V сохраняется. Меняет только вышедшие за диапазон
; ObjectX/ObjectY; PPU queue/registers, OAM, audio и стек не трогает. Оба
; предела и 16-pixel cursor step должны изменяться согласованно с 13x13 layout.
ClampConstructionCursor:
LC8D0:  lda     ObjectX
        cmp     #ConstructionCursorMaximumCenter
        bcc     ClampConstructionCursorLeft
        lda     #ConstructionCursorMaximumCenter
        sta     ObjectX
ClampConstructionCursorLeft:
LC8DA:  lda     ObjectX
        cmp     #ConstructionCursorMinimumCenter
        bcs     ClampConstructionCursorBottom
        lda     #ConstructionCursorMinimumCenter
        sta     ObjectX
ClampConstructionCursorBottom:
LC8E4:  lda     ObjectY
        cmp     #ConstructionCursorMaximumCenter
        bcc     ClampConstructionCursorTop
        lda     #ConstructionCursorMaximumCenter
        sta     ObjectY
ClampConstructionCursorTop:
LC8EE:  lda     ObjectY
        cmp     #ConstructionCursorMinimumCenter
        bcs     FinishConstructionCursorClamp
        lda     #ConstructionCursorMinimumCenter
        sta     ObjectY
FinishConstructionCursorClamp:
LC8F8:  rts
