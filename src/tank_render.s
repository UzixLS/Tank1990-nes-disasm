; Проход отрисовки и render-handlers танков ($DEA6-$E02D).
; Scratch: базовый tile очередного квадранта крупного взрыва.
LargeDestructionQuadrantTileBase = $00

TankEffectPalette              = $03
SmallExplosionClassPivot       = $07
SmallExplosionTileBase         = $F1
SmallExplosionF9TileOffset     = $08
FinalDestructionTileOffsetMask = $FC
FinalDestructionTileOffsetBias = $10
FinalDestructionTileBase       = $B9
LargeDestructionHalfSize       = $08
LargeDestructionFirstTile      = $D1
LargeDestructionFirstClass     = $30
LargeDestructionClass3TileOffset = $10
LargeDestructionLastQuadrant   = $03
EnemyCarrierPaletteBase        = $02
EnemyCarrierPaletteIndexMask   = $01
EnemyPaletteCycleIndexMask     = $07
PlayerStunHiddenFrameBit       = $08
TankSpawnPhaseCenter           = $07
TankSpawnTileOffsetMask        = $FC
TankSpawnTileBase              = $A1

; Рисует slots 0..7 через отдельную таблицу классов отображения. Один slot
; добавляет 0 entries для класса $0/скрытого оглушённого игрока, 8 entries для
; классов $3/$4 и 2 entries для остальных классов. Максимум прохода — все 64
; аппаратных OAM entries. Проверки оставшейся ёмкости нет: OamBufferPos —
; 8-битный cursor, поэтому суммарный render-pass свыше 64 entries оборачивается
; внутри OamShadow и перезаписывает ранее выданные спрайты.
;
; Вход: ObjectState/X/Y/Attributes/Frame для восьми slots, PlayerStunTimer,
; FrameCounter и terrain shadow; OamBufferPos выровнен на 4, OamBufferStep
; равен +4 или -4. SpriteBehindTerrainMask задаёт поведение обычных танков и
; spawn-анимации над terrain $22. Классы разрушения $1-$7
; временно используют маску 0, затем оставляют её равной $20; если таких
; классов нет, входная маска сохраняется.
; Выход: CurrentTankSlot=8, A=8, N=0, Z=C=1; X/Y и V зависят от последнего
; handler. Состояние объектов и terrain не меняет. Портит ScratchPtr,
; TerrainSubcellMask, RenderAttributes/OamTile, OAM cursor/pair/coordinate
; scratch и записанные entries OamShadow в зависимости от обработанных классов.
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

; Старшая тетрада ObjectState,X выбирает один из 16 обработчиков:
; $0 — no-op; $1/$2 — отдельные двухспрайтовые destruction frames; $3/$4 —
; крупный восьмиспрайтовый взрыв; $5-$7 — малый взрыв; $8-$D — обычный танк;
; $E/$F — spawn-анимация. Индекс таблицы равен 2*(state>>4).
; Вход: X=slot 0..7; для handler классов $3/$4 CurrentTankSlot должен указывать
; на тот же slot. До tail-JMP портит A/Y, ScratchPtr и flags, сохраняя X;
; итоговый выход и дальнейшие побочные эффекты определяет handler.
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

; Классы разрушения $5/$6/$7: добавляет два OAM entries с tile-base
; $F9/$F5/$F1 и палитрой 3. На время вывода отключает terrain-priority, затем
; всегда устанавливает SpriteBehindTerrainMask=$20 — входную маску не
; восстанавливает. Вход: X=slot нужного класса. Выход: A=$20, N=Z=0; X/Y,
; OamTile, RenderAttributes, OAM cursor/scratch/shadow и flags отрисовки
; изменены. Object/terrain RAM не меняет; свободные OAM entries не проверяет.
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
; Вход: старшая тетрада A — класс $5-$7 (tank state либо преобразованный
; projectile state), X/Y — экранные координаты пары. Преобразует класс в
; tile $F9/$F5/$F1, задаёт RenderAttributes=3 и выводит
; два OAM entries через EmitTwoTileOamPair. Младшая тетрада A игнорируется.
; Использует текущий SpriteBehindTerrainMask и не меняет саму маску.
; Выход как у DrawSmallExplosionFrameFromOffset. Object/terrain RAM не меняет;
; свободную OAM capacity не проверяет.
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
; Альтернативный вход: A уже содержит смещение tile-base относительно $F1
; (штатно 0, 4 или 8), X/Y — координаты пары. Добавляет два OAM entries.
; Выход: OamTile=input A+$F3; A=новый OamBufferPos, X=позиция второго
; записанного entry, Y=0. Портит flags, RenderAttributes, ScratchPtr,
; TerrainSubcellMask, OAM coordinate/pair scratch и OamShadow. Текущая
; SpriteBehindTerrainMask может добавить bit5 в RenderAttributes над tile $22.
DrawSmallExplosionFrameFromOffset:
LDEF0:  clc
        adc     #SmallExplosionTileBase
        sta     OamTile
        lda     #TankEffectPalette
        sta     RenderAttributes
        jsr     EmitTwoTileOamPair
        rts

; Финальный класс разрушения $1. Добавляет два OAM entries с палитрой 3.
; При attributes=0 использует tile-base $F1; иначе base вычисляется с
; 8-битной арифметикой как $B9+(((attributes>>3)&$FC)-$10).
; Вход: X=slot класса $1. На время вывода ставит terrain-priority mask=0,
; по выходу всегда оставляет SpriteBehindTerrainMask=$20, A=$20, N=Z=0.
; Портит X/Y, RenderAttributes/OamTile, ScratchPtr, TerrainSubcellMask,
; OAM cursor/scratch/shadow и прочие flags; Object/terrain RAM не меняет.
; Свободную OAM capacity не проверяет.
DrawTankDestructionState1:
        lda     #TerrainPriorityDisabled
        sta     SpriteBehindTerrainMask
        lda     ObjectAttributes,x
        beq     DrawDefaultDestructionState1Frame
        lda     ObjectAttributes,x
        lsr     a
        lsr     a
        lsr     a
        and     #FinalDestructionTileOffsetMask
        sec
        sbc     #FinalDestructionTileOffsetBias
        clc
        adc     #FinalDestructionTileBase
        sta     OamTile
        lda     #TankEffectPalette
        sta     RenderAttributes
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        jsr     EmitTwoTileOamPair
        jmp     EnableTerrainPriorityAfterTankDestruction

DrawDefaultDestructionState1Frame:
; Вход из handler: X=slot с attributes=0, terrain-priority уже отключён.
; Рисует default tile-base $F1 и переходит в общий восстанавливающий хвост.
LDF23:  lda     ObjectY,x
        tay
        lda     ObjectX,x
        tax
        lda     #$00
        jsr     DrawSmallExplosionFrameFromOffset
EnableTerrainPriorityAfterTankDestruction:
; Общий хвост класса $1: входной A/X/Y не сохраняет; возвращает A=$20,
; SpriteBehindTerrainMask=$20, N=Z=0.
LDF2E:  lda     #TerrainPriorityEnabled
        sta     SpriteBehindTerrainMask
        rts

; Класс разрушения $2: добавляет два OAM entries с tile-base $F9 и палитрой 3.
; Вход: X=slot класса $2. На время вывода ставит terrain-priority mask=0;
; по выходу всегда SpriteBehindTerrainMask=$20, A=$20, N=Z=0. Портит X/Y,
; OamTile/RenderAttributes, ScratchPtr, TerrainSubcellMask, OAM
; cursor/scratch/shadow и прочие flags; Object/terrain RAM не меняет.
; Свободную OAM capacity не проверяет.
DrawTankDestructionState2:
        lda     #TerrainPriorityDisabled
        sta     SpriteBehindTerrainMask
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        lda     #SmallExplosionF9TileOffset
        jsr     DrawSmallExplosionFrameFromOffset
        lda     #TerrainPriorityEnabled
        sta     SpriteBehindTerrainMask
        rts

; Классы разрушения $3/$4: добавляют четыре двухспрайтовых квадранта, то есть
; восемь OAM entries, вокруг ObjectX/Y. Для класса $3 tile-base квадрантов
; равны $E1/$E5/$E9/$ED, для $4 — $D1/$D5/$D9/$DD; каждая пара также использует
; base+2. Координаты, передаваемые EmitTwoTileOamPair, равны
; (X-8,Y-8), (X+8,Y-8), (X-8,Y+8), (X+8,Y+8); восьмибитная арифметика не
; ограничивает выход за край экрана.
; Вход: CurrentTankSlot указывает slot класса $3/$4; входные A/X/Y не нужны
; (первый номер квадранта получается из записанного перед вызовом A=0).
; На время вывода terrain-priority mask=0; по выходу всегда
; SpriteBehindTerrainMask=$20, A=$20, N=Z=0. Портит X/Y,
; LargeDestructionQuadrantTileBase/TerrainSubcellMask, OamTile,
; RenderAttributes, ScratchPtr, OAM cursor/scratch/shadow и прочие flags;
; Object/terrain RAM не меняет. Свободную OAM capacity не проверяет.
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
; Вход: A=номер квадранта 0..3, CurrentTankSlot — slot класса $3/$4; входной X
; игнорируется. Вычисляет OamTile=$D1+4*A+(class==$3 ? $10 : 0).
; Выход: A=X=ObjectX, Y=ObjectY выбранного slot;
; LargeDestructionQuadrantTileBase=$D1+4*quadrant. Меняет OamTile и flags;
; RenderAttributes, SpriteBehindTerrainMask, OAM cursor/shadow и Object RAM
; сохраняет. Последующий OAM emitter переиспользует scratch $00 как
; TerrainSubcellMask, поэтому tile-base в нём не сохраняется.
LDF99:  ldx     CurrentTankSlot
        asl     a
        asl     a
        clc
        adc     #LargeDestructionFirstTile
        sta     LargeDestructionQuadrantTileBase
        lda     ObjectState,x
        and     #StateClassMask
        sec
        sbc     #LargeDestructionFirstClass
        eor     #LargeDestructionClass3TileOffset
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
; Оглушённый игрок восемь кадров виден и восемь скрыт по FrameCounter bit3.
; Видимый путь добавляет два OAM entries. Его tile-base перед выбором
; направления равен (ObjectAttributes&$F0)+ObjectFrame; direction из младших
; двух битов state добавляет 0/8/16/24.
; Вход: X=slot класса $8-$D. SpriteBehindTerrainMask используется как есть и
; сохраняется. Видимый путь портит A/X/Y, RenderAttributes/OamTile, ScratchPtr,
; TerrainSubcellMask, OAM cursor/scratch/shadow и flags, не меняя Object/terrain
; RAM; свободную OAM capacity не проверяет. Скрытый player-путь ничего не
; добавляет и сохраняет X/Y, render/OAM scratch и RAM; возвращает A=$08,
; N=Z=C=0, V без изменения.
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
; Вход: X=enemy slot без carrier bit. Выбирает таблицу по
; (4*FrameCounter+ObjectAttributes,X)&7 и хвостом рисует танк.
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
; Вход: X=player slot 0/1. При активном stun timer и FrameCounter bit3=1
; возвращается без записи OAM; иначе передаёт номер slot как palette.
LDFDD:  lda     PlayerStunTimer,x
        beq     UsePlayerTankPalette
        lda     FrameCounter
        and     #PlayerStunHiddenFrameBit
        beq     UsePlayerTankPalette
        rts

UsePlayerTankPalette:
LDFE8:  txa
; Общий хвост обычного танка. Вход: A=палитра 0..3, X=slot класса $8-$D.
; Добавляет два OAM entries через EmitTwoTileOamObject.
; Выход: A=новый OamBufferPos, X=позиция второго записанного entry, Y=0;
; OamTile=(attributes&$F0)+frame+8*direction+2. RenderAttributes начинает с
; выбранной палитры; каждый terrain probe может OR-нуть bit5, причём результат
; первого probe наследуется вторым entry. Портит ScratchPtr, TerrainSubcellMask,
; OAM coordinate/pair scratch, OAM cursor/shadow и flags; Object/terrain RAM и
; SpriteBehindTerrainMask сохраняет.
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
; Классы появления $E/$F: две последовательные 14-фазные половины lifecycle.
; Для штатной младшей фазы 0..13 tile-base равен
; $A1+((2*abs(phase-7))&$FC), то есть проходит ряд
; AD,AD,A9,A9,A5,A5,A1,A1,A1,A5,A5,A9,A9,AD.
; Вход: X=spawn slot. Добавляет два OAM entries с палитрой 3, используя текущую
; SpriteBehindTerrainMask и сохраняя её. Выход: A=новый OamBufferPos,
; X=позиция второго записанного entry, Y=0; OamTile=tile-base+2.
; Портит RenderAttributes, ScratchPtr, TerrainSubcellMask, OAM
; cursor/scratch/shadow и flags; Object/terrain RAM не меняет. Свободную OAM
; capacity не проверяет.
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
; Вход блока: A=abs((state&$0F)-7). Округляет удвоенное расстояние вниз до
; кратного 4, формирует tile-base и выводит пару в координатах slot X.
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
