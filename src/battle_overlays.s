; PAUSE, переходный объект и прямоугольник поля ($C8F9-$C9BF).

OverlaySpriteAttributes          = $03
PauseBlinkVisiblePhaseBit        = $10
PauseOverlayFirstX               = $64
PauseOverlayY                    = $80
PauseOverlayGlyphSpacing         = $08
PauseOverlayTileP                = $17
PauseOverlayTileA                = $19
PauseOverlayTileU                = $1B
PauseOverlayTileS                = $1D
PauseOverlayTileE                = $1F
TransitionMovingTimerMinimum     = $0A
TransitionTimerTickFrameMask     = $0F
GameOverLeftPairFirstTile        = $79
GameOverRightPairFirstTile       = $7D
GameOverRightPairAnchorOffset    = $10
PlayfieldRectangleOriginTile     = $02
PlayfieldRectangleExtentTiles    = $1A

; Если PauseState!=0, в видимую половину 32-кадрового периода выводит слово
; PAUSE пятью 8x16-спрайтами. Записи имеют Y=$78, X=$64,$6C,$74,$7C,$84,
; tiles $17,$19,$1B,$1D,$1F и attributes=$03. Требуется OamBufferStep=+4/-4
; и место для пяти записей: проверки переполнения OAM shadow нет.
;
; В невидимой половине (FrameCounter bit4=0) и при PauseState=0 сохраняет
; X/Y и всю RAM; возвращает A=0, Z=1. На видимом пути временно задаёт
; TerrainPriorityDisabled, поэтому слово остаётся перед специальным terrain
; tile $22, а после пяти записей безусловно оставляет
; SpriteBehindTerrainMask=TerrainPriorityEnabled (входное значение не
; восстанавливается). Выход видимого пути: A=$20, X=индекс пятой OAM-записи,
; Y=0, OamTile=$1F, RenderAttributes=$03; OamBufferPos продвинут на пять
; записей. Меняет ScratchPtr/PpuTileRowBits, terrain/render/OAM scratch и
; соответствующие байты OamShadow; PPU queue/registers не трогает.
DrawPauseOverlay:
LC8F9:  lda     PauseState
        beq     FinishPauseOverlay
        lda     FrameCounter
        and     #PauseBlinkVisiblePhaseBit
        beq     FinishPauseOverlay
        lda     #OverlaySpriteAttributes
        sta     RenderAttributes
        lda     #TerrainPriorityDisabled
        sta     SpriteBehindTerrainMask
        ldx     #PauseOverlayFirstX
        ldy     #PauseOverlayY
        lda     #PauseOverlayTileP
        sta     OamTile
        jsr     EmitOamSprite
        ldx     #(PauseOverlayFirstX+PauseOverlayGlyphSpacing)
        ldy     #PauseOverlayY
        lda     #PauseOverlayTileA
        sta     OamTile
        jsr     EmitOamSprite
        ldx     #(PauseOverlayFirstX+2*PauseOverlayGlyphSpacing)
        ldy     #PauseOverlayY
        lda     #PauseOverlayTileU
        sta     OamTile
        jsr     EmitOamSprite
        ldx     #(PauseOverlayFirstX+3*PauseOverlayGlyphSpacing)
        ldy     #PauseOverlayY
        lda     #PauseOverlayTileS
        sta     OamTile
        jsr     EmitOamSprite
        ldx     #(PauseOverlayFirstX+4*PauseOverlayGlyphSpacing)
        ldy     #PauseOverlayY
        lda     #PauseOverlayTileE
        sta     OamTile
        jsr     EmitOamSprite
        lda     #TerrainPriorityEnabled
        sta     SpriteBehindTerrainMask
FinishPauseOverlay:
LC946:  rts

; Рисует переходную надпись GAME/OVER четырьмя соседними 8x16-спрайтами:
; верхние половины образуют GAME, нижние — OVER. Логическая точка
; TransitionObjectX/Y даёт OAM-координаты X-8,X,X+8,X+16 и Y-8; tile bytes
; идут как $79,$7B,$7D,$7F, attributes=$03. Сложение X выполняется по модулю
; 256. Требуются OamBufferStep=+4/-4 и место для четырёх OAM-записей.
;
; На время всех terrain probes задаёт TerrainPriorityDisabled, поэтому объект
; остаётся перед tile $22. По выходу безусловно оставляет
; SpriteBehindTerrainMask=TerrainPriorityEnabled (не восстанавливает вход),
; A=$20, X=индекс четвёртой записи, Y=0, OamTile=$7F,
; RenderAttributes=$03, OamPairX=TransitionObjectX+$10 и
; OamPairY=TransitionObjectY. TransitionObjectX/Y/Direction/Timer сохраняет,
; OamBufferPos продвигает на четыре записи. Меняет ScratchPtr/PpuTileRowBits,
; terrain/render/OAM scratch и OamShadow; PPU queue/registers не трогает.
DrawTransitionObject:
LC947:  lda     #OverlaySpriteAttributes
        sta     RenderAttributes
        lda     #TerrainPriorityDisabled
        sta     SpriteBehindTerrainMask
        ldx     TransitionObjectX
        ldy     TransitionObjectY
        lda     #GameOverLeftPairFirstTile
        sta     OamTile
        jsr     EmitTwoTileOamPair
        lda     TransitionObjectX
        clc
        adc     #GameOverRightPairAnchorOffset
        tax
        ldy     TransitionObjectY
        lda     #GameOverRightPairFirstTile
        sta     OamTile
        jsr     EmitTwoTileOamPair
        lda     #TerrainPriorityEnabled
        sta     SpriteBehindTerrainMask
        rts

; Обновляет таймер, положение и четыре OAM-записи переходного объекта.
; Вход: TransitionObjectDirection=0..3, когда timer>=$0A; OamBufferStep=+4/-4
; и в shadow свободны четыре записи. Attract-маркер StageSetLength=2 полностью
; запрещает обновление, даже если timer ненулевой.
;
; На фазе FrameCounter&$0F=0 сначала уменьшает ненулевой timer. Пока полученное
; (или ещё не уменьшенное на прочих кадрах) значение >=$0A, прибавляет к X/Y
; один знаковый пиксельный шаг DirectionStepX/Y; координаты оборачиваются по
; модулю 256. При timer 1..9 объект остаётся неподвижным, но рисуется каждый
; кадр. При переходе 1->0 записывает TransitionObjectY=$F0 и выполняет последнюю
; отрисовку: EmitOamSprite поместит в записи OAM Y=$E8. Следующий вызов с нулём
; уже ничего не рисует.
;
; Нулевой timer возвращает A=0/Z=1, X/Y и RAM сохранены. Attract-путь
; возвращает A=AttractStageSetMarker/Z=1 и также сохраняет RAM. Активный путь
; имеет выход и побочные эффекты DrawTransitionObject; дополнительно может
; менять TransitionObjectTimer и X/Y. Direction, FrameCounter и StageSetLength
; сохраняет; PPU queue/registers не трогает.
UpdateTransitionObject:
LC972:  lda     TransitionObjectTimer
        beq     FinishTransitionObjectUpdate
        lda     StageSetLength
        cmp     #AttractStageSetMarker
        beq     FinishTransitionObjectUpdate
        lda     FrameCounter
        and     #TransitionTimerTickFrameMask
        bne     CheckTransitionObjectMovement
        dec     TransitionObjectTimer
        bne     CheckTransitionObjectMovement
        lda     #OamHiddenY
        sta     TransitionObjectY
CheckTransitionObjectMovement:
LC98D:  lda     TransitionObjectTimer
        cmp     #TransitionMovingTimerMinimum
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

; Заполняет весь 32x32 shadow граничным tile $11, обнуляет 64 attribute bytes
; и очищает игровое поле 26x26 tiles: X=2..27, Y=2..27. В пределах видимых
; 32x30 tiles остаются две граничные строки сверху/снизу, два столбца слева и
; четыре столбца справа (область HUD). PPU и очередь не затрагивает.
;
; Выход: A=0, X=$02, Y=$FF, NametableRectX/Y=$02,
; NametableRectWidth=$1A, NametableRectHeight=0, ScratchPtr=$0762,
; PpuTileRowBits=$40, Z=1. Перезаписывает NametableShadow $0400-$07FF и
; rectangle/address scratch; остальную RAM сохраняет.
InitializePlayfieldRectangle:
LC9B0:  lda     #PlayfieldRectangleOriginTile
        sta     NametableRectX
        sta     NametableRectY
        lda     #PlayfieldRectangleExtentTiles
        sta     NametableRectHeight
        sta     NametableRectWidth
        jsr     InitializePlayfieldShadow
        rts
