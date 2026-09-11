; PAUSE, переходный объект и прямоугольник поля ($C8F9-$C9BF).

; При $6D!=0 мигает пятью двухтайловыми знаками в центре экрана на фазе FrameCounter&$10.
; На время отрисовки сбрасывает SpriteBehindTerrainMask и затем восстанавливает
; $20; портит A/X/Y, $04/OamTile и OAM shadow.
DrawPauseOverlay:
LC8F9:  lda     PauseState
        beq     FinishPauseOverlay
        lda     FrameCounter
        and     #$10
        beq     FinishPauseOverlay
        lda     #$03
        sta     RenderAttributes
        lda     #$00
        sta     SpriteBehindTerrainMask
        ldx     #$64
        ldy     #$80
        lda     #$17
        sta     OamTile
        jsr     EmitOamSprite
        ldx     #$6C
        ldy     #$80
        lda     #$19
        sta     OamTile
        jsr     EmitOamSprite
        ldx     #$74
        ldy     #$80
        lda     #$1B
        sta     OamTile
        jsr     EmitOamSprite
        ldx     #$7C
        ldy     #$80
        lda     #$1D
        sta     OamTile
        jsr     EmitOamSprite
        ldx     #$84
        ldy     #$80
        lda     #$1F
        sta     OamTile
        jsr     EmitOamSprite
        lda     #$20
        sta     SpriteBehindTerrainMask
FinishPauseOverlay:
LC946:  rts

; Рисует двухчастный переходный объект по TransitionObjectX/Y и кодам $79/$7D.
; Портит A/X/Y, $04, OamTile, SpriteBehindTerrainMask и OAM shadow;
; восстанавливает SpriteBehindTerrainMask=$20.
DrawTransitionObject:
LC947:  lda     #$03
        sta     RenderAttributes
        lda     #$00
        sta     SpriteBehindTerrainMask
        ldx     TransitionObjectX
        ldy     TransitionObjectY
        lda     #$79
        sta     OamTile
        jsr     EmitTwoTileOamPair
        lda     TransitionObjectX
        clc
        adc     #$10
        tax
        ldy     TransitionObjectY
        lda     #$7D
        sta     OamTile
        jsr     EmitTwoTileOamPair
        lda     #$20
        sta     SpriteBehindTerrainMask
        rts

; Обновляет переходную анимацию TransitionObjectX..TransitionObjectTimer,
; кроме attract mode (StageSetLength=2).
; Каждые 16 кадров уменьшает TransitionObjectTimer; пока он >=$0A, двигает
; объект по TransitionObjectDirection, затем рисует.
; При обнулении прячет объект при Y=$F0. Портит A/X/Y и OAM shadow при отрисовке.
UpdateTransitionObject:
LC972:  lda     TransitionObjectTimer
        beq     FinishTransitionObjectUpdate
        lda     StageSetLength
        cmp     #$02
        beq     FinishTransitionObjectUpdate
        lda     FrameCounter
        and     #$0F
        bne     UpdateTransitionObjectPosition
        dec     TransitionObjectTimer
        bne     UpdateTransitionObjectPosition
        lda     #$F0
        sta     TransitionObjectY
UpdateTransitionObjectPosition:
LC98D:  lda     TransitionObjectTimer
        cmp     #$0A
        bcc     DrawCurrentTransitionObject
        lda     TransitionObjectDirection
        tay
        lda     DirectionStepX,y
        clc
        adc     TransitionObjectX
        sta     TransitionObjectX
        lda     DirectionStepY,y
        clc
        adc     TransitionObjectY
        sta     TransitionObjectY
DrawCurrentTransitionObject:
LC9AC:  jsr     DrawTransitionObject
FinishTransitionObjectUpdate:
LC9AF:  rts

; Готовит параметры прямоугольника (2,2), 26x26 тайлов и вызывает InitializePlayfieldShadow.
; Портит A/X/Y, NametableRect* и nametable shadow/PPU work state по контракту вызываемой процедуры.
InitializePlayfieldRectangle:
LC9B0:  lda     #$02
        sta     NametableRectX
        sta     NametableRectY
        lda     #$1A
        sta     NametableRectHeight
        sta     NametableRectWidth
        jsr     InitializePlayfieldShadow
        rts
