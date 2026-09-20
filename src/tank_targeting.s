; Выбор направления танка к цели ($DD7E-$DDE9).
; Scratch $64 сначала хранит X-relation 0..2, затем общий индекс 0..8.
TankTargetRelationIndex       = $64
TankTargetYRelationIndex      = $65
BaseTargetCenterX             = $78
BaseTargetCenterY             = $D8
TargetRelationBias            = 1
HorizontalPriorityTableOffset = 9
PlayerAxisPriorityPhaseBit    = $02
EnemyAxisPriorityRandomBit    = $01

; Классы $B-$D выбирают цель и сразу сводятся к классу $A с направлением из
; TankAiDirectionStateTable. Target player handlers не проверяют активность цели:
; выбор живого игрока выполняет ChooseEnemyTankAiMode. Координата базы — центр
; спрайта над её двумя нижними строками. Портят A/Y, TankTargetX/Y и targeting
; scratch; enemy path также продвигает RNG. X сохраняется.
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

; Выбирает активный state направления к TankTargetX/Y. NormalizeSubtractionSign
; даёт -1/0/+1; после bias значения 0/1/2 означают target left/same/right и
; above/same/below. Индекс 3*y+x выбирает одну из двух матриц 3x3:
; первая предпочитает вертикальное движение, вторая — горизонтальное.
; Игроки меняют приоритет по bit1 SlowFrameCounter в противофазе; противник
; выбирает матрицу по младшему случайному bit на каждом вызове.
; Вход: X=слот 0..7, TankTargetX/Y заданы. Выход: A=$A0..$A3, N/Z по A;
; X сохраняется, Y=индекс 0..17. Портит targeting scratch и flags; enemy path
; также RandomState/RandomIndex. Объект, PPU/OAM и audio не меняет.
ChooseTankStateTowardTarget:
LDDA2:  lda     TankTargetX
        sec
        sbc     ObjectX,x
        jsr     NormalizeSubtractionSign
        clc
        adc     #TargetRelationBias
        sta     TankTargetRelationIndex
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
        adc     TankTargetRelationIndex
        sta     TankTargetRelationIndex
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
LDDDB:  lda     #HorizontalPriorityTableOffset
        clc
        adc     TankTargetRelationIndex
        tay
        jmp     LoadTargetDirectionState

UseVerticalPriorityDirection:
LDDE4:  ldy     TankTargetRelationIndex
LoadTargetDirectionState:
LDDE6:  lda     TankAiDirectionStateTable,y
        rts
