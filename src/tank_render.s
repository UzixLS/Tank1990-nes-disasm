; Проход отрисовки и render-handlers танков ($DEA6-$E02D).
LargeTankQuadrantTileBase = $00

; Рисует восемь танков через отдельную таблицу состояний отображения.
; Портит A/X/Y, CurrentTankSlot, ScratchPtr и рабочие поля OAM-процедур.
DrawTanks:
LDEA6:  lda     #$00
        sta     CurrentTankSlot
DrawNextTank:
LDEAA:  ldx     CurrentTankSlot
        jsr     DispatchTankDraw
        inc     CurrentTankSlot
        lda     CurrentTankSlot
        cmp     #TankSlotCount
        bne     DrawNextTank
        rts

; Старшая тетрада ObjectState,X выбирает обработчик из TankDrawHandlers.
; Не возвращается самостоятельно; контракт определяется обработчиком.
DispatchTankDraw:
LDEB8:  lda     ObjectState,x
        lsr     a
        lsr     a
        lsr     a
        and     #$FE
        tay
        lda     TankDrawHandlers,y
        sta     ScratchPtrLo
        lda     TankDrawHandlers+1,y
        sta     ScratchPtrHi
        jmp     (ScratchPtrLo)

; Классы $5-$7: двухспрайтовая фазовая анимация с палитрой 3. На время вывода
; отключает SpriteBehindTerrainMask и восстанавливает его в $20 после вызова.
DrawTankStates5To7:
        lda     #$00
        sta     SpriteBehindTerrainMask
        lda     ObjectState,x
        pha
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        pla
        jsr     ComputeAndDrawTankTransitionFrame
        lda     #$20
        sta     SpriteBehindTerrainMask
        rts

ComputeAndDrawTankTransitionFrame:
; Вход: A — ObjectState класса $5-$7, X/Y — экранные координаты пары спрайтов.
; Преобразует класс в tile $F9/$F5/$F1, задаёт RenderAttributes=3 и выводит
; пару через EmitTwoTileOamPair. Портит A/X/Y, OamTile, RenderAttributes,
; OAM cursor/shadow и scratch-поля EmitTwoTileOamPair.
LDEE2:  lsr     a
        lsr     a
        lsr     a
        lsr     a
        sec
        sbc     #$07
        eor     #$FF
        clc
        adc     #$01
        asl     a
        asl     a
; Альтернативный вход: A уже содержит смещение кадра относительно tile $F1.
DrawTankTransitionFrameFromOffset:
LDEF0:  clc
        adc     #$F1
        sta     OamTile
        lda     #$03
        sta     RenderAttributes
        jsr     EmitTwoTileOamPair
        rts

; Класс $1: вариант финальной анимации зависит от ObjectAttributes,X; при нуле
; используется первый кадр общей переходной последовательности.
DrawTankState1:
        lda     #$00
        sta     SpriteBehindTerrainMask
        lda     ObjectAttributes,x
        beq     DrawDefaultTankState1Frame
        lda     ObjectAttributes,x
        lsr     a
        lsr     a
        lsr     a
        and     #$FC
        sec
        sbc     #$10
        clc
        adc     #$B9
        sta     OamTile
        lda     #$03
        sta     RenderAttributes
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        jsr     EmitTwoTileOamPair
        jmp     RestoreTankSpritePriority

DrawDefaultTankState1Frame:
LDF23:  lda     ObjectY,x
        tay
        lda     ObjectX,x
        tax
        lda     #$00
        jsr     DrawTankTransitionFrameFromOffset
RestoreTankSpritePriority:
LDF2E:  lda     #$20
        sta     SpriteBehindTerrainMask
        rts

; Класс $2: выводит кадр 8 общей переходной последовательности.
DrawTankState2:
        lda     #$00
        sta     SpriteBehindTerrainMask
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        lda     #$08
        jsr     DrawTankTransitionFrameFromOffset
        lda     #$20
        sta     SpriteBehindTerrainMask
        rts

; Классы $3-$4: выводят четыре двухспрайтовых элемента вокруг центра танка,
; формируя объект 32x32. LDF99 выбирает tile-base по классу и номеру квадранта.
DrawTankStates3To4:
        lda     #$03
        sta     RenderAttributes
        lda     #$00
        sta     SpriteBehindTerrainMask
        jsr     PrepareLargeTankQuadrant
        txa
        sec
        sbc     #$08
        tax
        tya
        sec
        sbc     #$08
        tay
        jsr     EmitTwoTileOamPair
        lda     #$01
        jsr     PrepareLargeTankQuadrant
        txa
        clc
        adc     #$08
        tax
        tya
        sec
        sbc     #$08
        tay
        jsr     EmitTwoTileOamPair
        lda     #$02
        jsr     PrepareLargeTankQuadrant
        txa
        sec
        sbc     #$08
        tax
        tya
        clc
        adc     #$08
        tay
        jsr     EmitTwoTileOamPair
        lda     #$03
        jsr     PrepareLargeTankQuadrant
        txa
        clc
        adc     #$08
        tax
        tya
        clc
        adc     #$08
        tay
        jsr     EmitTwoTileOamPair
        lda     #$20
        sta     SpriteBehindTerrainMask
        rts

PrepareLargeTankQuadrant:
; Вход: A=номер квадранта 0..3, CurrentTankSlot — рисуемый танк класса $3/$4.
; Вычисляет OamTile для квадранта, затем возвращает его координаты одновременно
; как A=X=ObjectX и Y=ObjectY. Меняет LargeTankQuadrantTileBase и OamTile;
; Object/RAM кроме этих scratch-полей не меняет.
LDF99:  ldx     CurrentTankSlot
        asl     a
        asl     a
        clc
        adc     #$D1
        sta     LargeTankQuadrantTileBase
        lda     ObjectState,x
        and     #StateClassMask
        sec
        sbc     #$30
        eor     #$10
        clc
        adc     LargeTankQuadrantTileBase
        sta     OamTile
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        rts

; Классы $8-$D: обычный танк. Палитра игроков равна номеру слота, палитра противника
; анимируется по ObjectAttributes/FrameCounter. Направление выбирает один из четырёх
; кадров, ObjectFrame добавляется к старшей тетраде tile-base.
DrawTankStates8ToD:
        cpx     #FirstEnemyTankSlot
        bcc     DrawPlayerTank
        lda     ObjectAttributes,x
        and     #$04
        beq     SelectEnemyPaletteCycle
        lda     FrameCounter
        lsr     a
        lsr     a
        lsr     a
        and     #$01
        clc
        adc     #$02
        jmp     DrawTankWithSelectedPalette

SelectEnemyPaletteCycle:
LDFCD:  lda     FrameCounter
        asl     a
        asl     a
        clc
        adc     ObjectAttributes,x
        and     #$07
        tay
        lda     LE003,y
        jmp     DrawTankWithSelectedPalette

DrawPlayerTank:
LDFDD:  lda     PlayerStunTimer,x
        beq     UsePlayerTankPalette
        lda     FrameCounter
        and     #$08
        beq     UsePlayerTankPalette
        rts

UsePlayerTankPalette:
LDFE8:  txa
DrawTankWithSelectedPalette:
LDFE9:  sta     RenderAttributes
        lda     ObjectState,x
        and     #DirectionMask
        pha
        lda     ObjectAttributes,x
        and     #$F0
        clc
        adc     ObjectFrame,x
        sta     OamTile
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        pla
        jsr     EmitTwoTileOamObject
        rts

EnemyTankPaletteCycle:
LE003:  .byte   $02,$00,$00,$01,$02,$01,$02,$02
; Классы $E-$F: симметричная переходная анимация вокруг фазы 7.
DrawTankStatesEToF:
LE00B:  lda     ObjectState,x
        and     #$0F
        sec
        sbc     #$07
        bpl     ConvertTankTransitionPhaseToTile
        eor     #$FF
        clc
        adc     #$01
ConvertTankTransitionPhaseToTile:
LE019:  asl     a
        and     #$FC
        clc
        adc     #$A1
        sta     OamTile
        lda     #$03
        sta     RenderAttributes
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        jsr     EmitTwoTileOamPair
        rts
