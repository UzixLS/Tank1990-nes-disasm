; Выбор направления танка к цели ($DD7E-$DDE9).
; $64 переиспользуется: сначала X-relation 0..2, затем индекс
; 3*y+x внутри матрицы 3x3. Оба scratch-байта перекрываются с другими
; subsystem aliases и живут только до возврата из ChooseTankStateTowardTarget.
TankTargetXRelationIndex        = $64
TankTargetDirectionMatrixIndex = $64
TankTargetYRelationIndex        = $65
BaseTargetCenterX               = $78
BaseTargetCenterY               = $D8
TargetRelationBias              = $01
PlayerAxisPriorityPhaseBit      = $02
EnemyAxisPriorityRandomBit      = $01

; Классы $B-$D — одноразовые routing-states: они выбирают цель и заменяют
; ObjectState,X полным active-state $A0..$A3. Движение начнётся лишь при
; следующей диспетчеризации слота. Target player handlers цель не проверяют:
; предварительный выбор слота выполняет ChooseEnemyTankAiMode, который тоже
; отсеивает лишь точный state=0. Координата базы — центр
; спрайта над её двумя нижними строками. Вход: X=slot 0..7; bounds check нет.
; Выход: A=ObjectState,X=$A0..$A3, X сохранён, Y=matrix index 0..17.
; Меняют TankTargetX/Y, targeting scratch и ObjectState,X; при X>=2 также
; всегда продвигают RNG ровно на один вызов. PPU/OAM/audio не меняют.
TankLogicTargetPlayerOne:
        lda     ObjectX
        sta     TankTargetX
        lda     ObjectY
        sta     TankTargetY
        jmp     CommitTankDirectionTowardTarget

TankLogicTargetPlayerTwo:
        lda     ObjectX+1
        sta     TankTargetX
        lda     ObjectY+1
        sta     TankTargetY
        jmp     CommitTankDirectionTowardTarget

TankLogicTargetBase:
        lda     #BaseTargetCenterX
        sta     TankTargetX
        lda     #BaseTargetCenterY
        sta     TankTargetY
; Общий хвост target-state: заменяет класс $B/$C/$D активным state $A0..$A3.
CommitTankDirectionTowardTarget:
LDD9C:  jsr     ChooseTankStateTowardTarget
        sta     ObjectState,x
        rts

; Выбирает активный state направления к TankTargetX/Y. Беззнаковое
; вычитание сравнивает каждую координату как byte: расстояние и кратчайший
; путь через wrap не учитываются. NormalizeSubtractionSign даёт -1/0/+1;
; после bias значения 0/1/2 означают target left/same/right и
; above/same/below. Индекс 3*y+x выбирает одну из двух матриц 3x3:
; первая предпочитает вертикальное движение, вторая — горизонтальное.
; Игроки меняют приоритет по bit1 SlowFrameCounter в противофазе: P1
; берёт vertical при bit1=0, P2 — при bit1=1. Bit1 переключается раз в
; 128 NMI. Противник всегда вызывает NextRandomByte и выбирает vertical
; при bit0=0, horizontal при bit0=1 (по 1/2 лишь при равномерном RNG).
; RNG расходуется даже когда обе матрицы дают один и тот же direction.
; Вход: X=слот 0..7, TankTargetX/Y заданы. Выход: A=$A0..$A3, N/Z по A;
; X сохраняется, Y=индекс 0..17. Портит targeting scratch и flags; enemy path
; также RandomState/RandomIndex. Объект, PPU/OAM и audio не меняет.
; Вне диапазона X нет защиты: чтение ObjectX/Y уйдёт в соседнюю RAM.
ChooseTankStateTowardTarget:
LDDA2:  lda     TankTargetX
        sec
        sbc     ObjectX,x
        jsr     NormalizeSubtractionSign
        clc
        adc     #TargetRelationBias
        sta     TankTargetXRelationIndex
        lda     TankTargetY
        sec
        sbc     ObjectY,x
        jsr     NormalizeSubtractionSign
        clc
        adc     #TargetRelationBias
        sta     TankTargetYRelationIndex
        asl     a
        clc
        adc     TankTargetYRelationIndex
        clc
        adc     TankTargetXRelationIndex
        sta     TankTargetDirectionMatrixIndex
        cpx     #FirstEnemyTankSlot
        bcs     ChooseEnemyAxisPriority
        txa
        asl     a
        eor     SlowFrameCounter
        and     #PlayerAxisPriorityPhaseBit
        beq     UseVerticalPriorityDirection
        jmp     UseHorizontalPriorityDirection

ChooseEnemyAxisPriority:
LDDD4:  jsr     NextRandomByte
        and     #EnemyAxisPriorityRandomBit
        beq     UseVerticalPriorityDirection
UseHorizontalPriorityDirection:
LDDDB:  lda     #(TankAiHorizontalPriorityDirectionStates-TankAiVerticalPriorityDirectionStates)
        clc
        adc     TankTargetDirectionMatrixIndex
        tay
        jmp     LoadTargetDirectionState

UseVerticalPriorityDirection:
LDDE4:  ldy     TankTargetDirectionMatrixIndex
LoadTargetDirectionState:
LDDE6:  lda     TankAiVerticalPriorityDirectionStates,y
        rts
