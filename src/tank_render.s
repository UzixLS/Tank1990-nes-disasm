; Проход отрисовки и render-handlers танков ($DEA6-$E02D).
; Scratch: базовый tile очередного квадранта крупного взрыва.
LargeDestructionQuadrantTileBase = $00

TankEffectPalette              = $03
SmallExplosionClassPivot       = $07
SmallExplosionTileBase         = $F1
SmallExplosionLastTileOffset   = $08
DestructionAttributeFrameMask  = $FC
DestructionAttributeFrameBias  = $10
DestructionAttributeTileBase   = $B9
LargeDestructionHalfSize       = $08
LargeDestructionFirstTile      = $D1
LargeDestructionStateBase      = $30
LargeDestructionFrameToggle    = $10
LargeDestructionLastQuadrant   = $03
EnemyCarrierPaletteBase        = $02
EnemyCarrierPaletteIndexMask   = $01
EnemyPaletteCycleIndexMask     = $07
PlayerStunHiddenFrameBit       = $08
TankSpawnPhaseCenter           = $07
TankSpawnTileOffsetMask        = $FC
TankSpawnTileBase              = $A1

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

; Старшая тетрада ObjectState,X выбирает один из 16 обработчиков в
; TankDrawHandlers. Вход: X=слот 0..7. Портит A/Y и ScratchPtr; tail-JMP
; передаёт X и все дальнейшие побочные эффекты выбранному обработчику.
DispatchTankDraw:
LDEB8:  lda     ObjectState,x
        lsr     a
        lsr     a
        lsr     a
        and     #DispatchWordIndexMask
        tay
        lda     TankDrawHandlers,y
        sta     ScratchPtrLo
        lda     TankDrawHandlers+1,y
        sta     ScratchPtrHi
        jmp     (ScratchPtrLo)

; Классы разрушения $5-$7: двухспрайтовые кадры $F9/$F5/$F1 с палитрой 3.
; На время вывода отключает terrain-priority, а затем всегда устанавливает
; TerrainPriorityEnabled — исходное значение маски не сохраняется.
DrawTankDestructionStates5To7:
        lda     #TerrainPriorityDisabled
        sta     SpriteBehindTerrainMask
        lda     ObjectState,x
        pha
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        pla
        jsr     ComputeAndDrawSmallExplosionFrame
        lda     #TerrainPriorityEnabled
        sta     SpriteBehindTerrainMask
        rts

ComputeAndDrawSmallExplosionFrame:
; Вход: A — ObjectState класса $5-$7, X/Y — экранные координаты пары спрайтов.
; Преобразует класс в tile $F9/$F5/$F1, задаёт RenderAttributes=3 и выводит
; пару через EmitTwoTileOamPair. Портит A/X/Y, OamTile, RenderAttributes,
; OAM cursor/shadow и scratch-поля EmitTwoTileOamPair.
LDEE2:  lsr     a
        lsr     a
        lsr     a
        lsr     a
        sec
        sbc     #SmallExplosionClassPivot
        eor     #$FF
        clc
        adc     #$01
        asl     a
        asl     a
; Альтернативный вход: A уже содержит смещение кадра относительно tile $F1.
DrawSmallExplosionFrameFromOffset:
LDEF0:  clc
        adc     #SmallExplosionTileBase
        sta     OamTile
        lda     #TankEffectPalette
        sta     RenderAttributes
        jsr     EmitTwoTileOamPair
        rts

; Финальный класс разрушения $1. При ненулевых ObjectAttributes старшие биты
; через (attributes>>3)&$FC выбирают пару тайлов от $B9; при нуле используется
; малый кадр $F1. Отключает terrain-priority на время вывода и в конце всегда
; включает его, не восстанавливая входное значение.
DrawTankDestructionState1:
        lda     #TerrainPriorityDisabled
        sta     SpriteBehindTerrainMask
        lda     ObjectAttributes,x
        beq     DrawDefaultDestructionState1Frame
        lda     ObjectAttributes,x
        lsr     a
        lsr     a
        lsr     a
        and     #DestructionAttributeFrameMask
        sec
        sbc     #DestructionAttributeFrameBias
        clc
        adc     #DestructionAttributeTileBase
        sta     OamTile
        lda     #TankEffectPalette
        sta     RenderAttributes
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        jsr     EmitTwoTileOamPair
        jmp     RestoreTankTerrainPriority

DrawDefaultDestructionState1Frame:
LDF23:  lda     ObjectY,x
        tay
        lda     ObjectX,x
        tax
        lda     #$00
        jsr     DrawSmallExplosionFrameFromOffset
RestoreTankTerrainPriority:
LDF2E:  lda     #TerrainPriorityEnabled
        sta     SpriteBehindTerrainMask
        rts

; Класс разрушения $2: выводит пару с tile-base $F9.
DrawTankDestructionState2:
        lda     #TerrainPriorityDisabled
        sta     SpriteBehindTerrainMask
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        lda     #SmallExplosionLastTileOffset
        jsr     DrawSmallExplosionFrameFromOffset
        lda     #TerrainPriorityEnabled
        sta     SpriteBehindTerrainMask
        rts

; Классы разрушения $3-$4: выводят четыре двухспрайтовых квадранта вокруг
; координат танка, формируя взрыв 32x32. PrepareLargeDestructionQuadrant
; выбирает tile-base по классу и номеру квадранта. Добавляет восемь OAM entries;
; арифметика координат восьмибитная и не ограничивает выход за край экрана.
DrawLargeTankDestructionStates3To4:
        lda     #TankEffectPalette
        sta     RenderAttributes
        lda     #TerrainPriorityDisabled
        sta     SpriteBehindTerrainMask
        jsr     PrepareLargeDestructionQuadrant
        txa
        sec
        sbc     #LargeDestructionHalfSize
        tax
        tya
        sec
        sbc     #LargeDestructionHalfSize
        tay
        jsr     EmitTwoTileOamPair
        lda     #$01
        jsr     PrepareLargeDestructionQuadrant
        txa
        clc
        adc     #LargeDestructionHalfSize
        tax
        tya
        sec
        sbc     #LargeDestructionHalfSize
        tay
        jsr     EmitTwoTileOamPair
        lda     #$02
        jsr     PrepareLargeDestructionQuadrant
        txa
        sec
        sbc     #LargeDestructionHalfSize
        tax
        tya
        clc
        adc     #LargeDestructionHalfSize
        tay
        jsr     EmitTwoTileOamPair
        lda     #LargeDestructionLastQuadrant
        jsr     PrepareLargeDestructionQuadrant
        txa
        clc
        adc     #LargeDestructionHalfSize
        tax
        tya
        clc
        adc     #LargeDestructionHalfSize
        tay
        jsr     EmitTwoTileOamPair
        lda     #TerrainPriorityEnabled
        sta     SpriteBehindTerrainMask
        rts

PrepareLargeDestructionQuadrant:
; Вход: A=номер квадранта 0..3, CurrentTankSlot — рисуемый танк класса $3/$4.
; Вычисляет OamTile для квадранта, затем возвращает его координаты одновременно
; как A=X=ObjectX и Y=ObjectY. Меняет LargeDestructionQuadrantTileBase и OamTile;
; Object/RAM кроме этих scratch-полей не меняет.
LDF99:  ldx     CurrentTankSlot
        asl     a
        asl     a
        clc
        adc     #LargeDestructionFirstTile
        sta     LargeDestructionQuadrantTileBase
        lda     ObjectState,x
        and     #StateClassMask
        sec
        sbc     #LargeDestructionStateBase
        eor     #LargeDestructionFrameToggle
        clc
        adc     LargeDestructionQuadrantTileBase
        sta     OamTile
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        rts

; Классы $8-$D: обычный танк. Палитра игрока равна номеру слота. Носитель
; усиления мигает палитрами 2/3 каждые восемь кадров; остальные противники
; выбирают палитру из EnemyTankPaletteCycle по (FrameCounter*4+attributes)&7.
; Оглушённый игрок не выводится при установленном PlayerStunHiddenFrameBit.
; Направление выбирает один из четырёх кадров, ObjectFrame добавляется к
; старшей тетраде tile-base из ObjectAttributes.
DrawTankStates8ToD:
        cpx     #FirstEnemyTankSlot
        bcc     DrawPlayerTank
        lda     ObjectAttributes,x
        and     #EnemyPowerUpCarrierFlag
        beq     SelectEnemyPaletteCycle
        lda     FrameCounter
        lsr     a
        lsr     a
        lsr     a
        and     #EnemyCarrierPaletteIndexMask
        clc
        adc     #EnemyCarrierPaletteBase
        jmp     DrawTankWithSelectedPalette

SelectEnemyPaletteCycle:
LDFCD:  lda     FrameCounter
        asl     a
        asl     a
        clc
        adc     ObjectAttributes,x
        and     #EnemyPaletteCycleIndexMask
        tay
        lda     EnemyTankPaletteCycle,y
        jmp     DrawTankWithSelectedPalette

DrawPlayerTank:
LDFDD:  lda     PlayerStunTimer,x
        beq     UsePlayerTankPalette
        lda     FrameCounter
        and     #PlayerStunHiddenFrameBit
        beq     UsePlayerTankPalette
        rts

UsePlayerTankPalette:
LDFE8:  txa
; Общий хвост обычного танка. Вход: A=палитра 0..3, X=слот.
; Выбирает tile по type/frame/direction и передаёт объект в OAM; портит A/X/Y
; и рабочие поля рендера, состояние танка не меняет.
DrawTankWithSelectedPalette:
LDFE9:  sta     RenderAttributes
        lda     ObjectState,x
        and     #DirectionMask
        pha
        lda     ObjectAttributes,x
        and     #ObjectAttributeClassMask
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
; Классы появления $E-$F: две последовательные 14-фазные половины lifecycle
; используют симметричный ряд кадров вокруг младшей фазы 7. Рисует одну
; двухспрайтовую пару с палитрой 3; terrain-priority не переопределяет.
DrawTankSpawnStatesEToF:
LE00B:  lda     ObjectState,x
        and     #StateLowNibbleMask
        sec
        sbc     #TankSpawnPhaseCenter
        bpl     ConvertTankSpawnPhaseToTile
        eor     #$FF
        clc
        adc     #$01
ConvertTankSpawnPhaseToTile:
LE019:  asl     a
        and     #TankSpawnTileOffsetMask
        clc
        adc     #TankSpawnTileBase
        sta     OamTile
        lda     #TankEffectPalette
        sta     RenderAttributes
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        jsr     EmitTwoTileOamPair
        rts
