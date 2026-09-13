; PAUSE, переходный объект и прямоугольник поля ($C8F9-$C9BF).

PauseVisibleFrameBit          = $10
TransitionMoveTimerThreshold = $0A
TransitionUpdateFrameMask    = $0F
PlayfieldRectangleOrigin     = $02
PlayfieldRectangleSize       = $1A

; При PauseState!=0 рисует пять однотайловых OAM-знаков в центре экрана на
; фазе FrameCounter&PauseVisibleFrameBit.
; На время отрисовки сбрасывает SpriteBehindTerrainMask и затем восстанавливает
; его в $20 (не прежнее значение). На невидимой фазе ничего не меняет кроме
; A/флагов; при отрисовке портит A/X/Y, ScratchPtr, render/OAM scratch и OAM shadow.
DrawPauseOverlay:
LC8F9:  lda     PauseState
        beq     FinishPauseOverlay
        lda     FrameCounter
        and     #PauseVisibleFrameBit
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

; Рисует переходный объект из двух двухспрайтовых пар по TransitionObjectX/Y
; с базовыми тайлами $79/$7D. Координаты и timer не меняет. Портит A/X/Y,
; ScratchPtr, render/OAM scratch, SpriteBehindTerrainMask и OAM shadow;
; в конце устанавливает SpriteBehindTerrainMask=$20 независимо от входа.
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
; кроме attract mode (StageSetLength=AttractStageSetMarker).
; Каждые 16 кадров уменьшает TransitionObjectTimer; пока он >=$0A, двигает
; объект на один пиксель по TransitionObjectDirection, затем рисует.
; При обнулении ставит Y=$F0 и последний раз рисует за экраном. При timer=0
; либо attract-маркере возвращается без отрисовки. Портит A/X/Y, ScratchPtr,
; transition/render scratch и OAM shadow при активной анимации; PPU не меняет.
UpdateTransitionObject:
LC972:  lda     TransitionObjectTimer
        beq     FinishTransitionObjectUpdate
        lda     StageSetLength
        cmp     #AttractStageSetMarker
        beq     FinishTransitionObjectUpdate
        lda     FrameCounter
        and     #TransitionUpdateFrameMask
        bne     UpdateTransitionObjectPosition
        dec     TransitionObjectTimer
        bne     UpdateTransitionObjectPosition
        lda     #StageEndObjectHiddenY
        sta     TransitionObjectY
UpdateTransitionObjectPosition:
LC98D:  lda     TransitionObjectTimer
        cmp     #TransitionMoveTimerThreshold
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

; Готовит параметры прямоугольника (2,2), 26x26 тайлов и вызывает
; InitializePlayfieldShadow. Портит A/X/Y, NametableRect*,
; ScratchPtr и shadow/PPU work state по контракту вызываемой процедуры.
InitializePlayfieldRectangle:
LC9B0:  lda     #PlayfieldRectangleOrigin
        sta     NametableRectX
        sta     NametableRectY
        lda     #PlayfieldRectangleSize
        sta     NametableRectHeight
        sta     NametableRectWidth
        jsr     InitializePlayfieldShadow
        rts
