; Выбор направления танка к цели ($DD7E-$DDE9).
; В первой фазе хранит отношение цели по X, затем индекс направления 0..8.
TankTargetDirectionIndex = $64
TankTargetYRelation       = $65
BaseTargetX                    = $78
BaseTargetY                    = $D8
TargetRelationIndexBias        = 1
TargetDirectionAlternateOffset = 9
PlayerTargetAxisPhaseBit       = $02
EnemyTargetAxisRandomMask      = $01

; Классы $B-$D выбирают цель и сразу сводятся к классу $A с направлением из
; TankAiDirectionStateTable. $D целится в игрока 1 (слот 0), $C — в игрока 2
; (слот 1), $B — в базу в точке BaseTargetX/BaseTargetY. Портят A/Y,
; TankTargetX/Y и рабочие
; поля выбора направления; X сохраняется.
TankLogicStateD:
        lda     ObjectX
        sta     TankTargetX
        lda     ObjectY
        sta     TankTargetY
        jmp     ChooseDirectionTowardSelectedTarget

TankLogicStateC:
        lda     ObjectX+1
        sta     TankTargetX
        lda     ObjectY+1
        sta     TankTargetY
        jmp     ChooseDirectionTowardSelectedTarget

TankLogicStateB:
        lda     #BaseTargetX
        sta     TankTargetX
        lda     #BaseTargetY
        sta     TankTargetY
ChooseDirectionTowardSelectedTarget:
LDD9C:  jsr     ChooseTankStateTowardTarget
        sta     ObjectState,x
        rts

; Выбирает направление к TankTargetX/Y. Знаки разностей X/Y кодируются значениями
; 0..2, образуют индекс 0..8, а альтернативная половина таблицы со смещением
; TargetDirectionAlternateOffset используется по кадровому/случайному условию.
; Выход: A — готовое состояние из
; TankAiDirectionStateTable. Портит A/Y, TankTargetDirectionIndex и
; TankTargetYRelation; для противника также RNG. X сохраняет.
ChooseTankStateTowardTarget:
LDDA2:  lda     TankTargetX
        sec
        sbc     ObjectX,x
        jsr     NormalizeSubtractionSign
        clc
        adc     #TargetRelationIndexBias
        sta     TankTargetDirectionIndex
        lda     TankTargetY
        sec
        sbc     ObjectY,x
        jsr     NormalizeSubtractionSign
        clc
        adc     #TargetRelationIndexBias
        sta     TankTargetYRelation
        asl     a
        clc
        adc     TankTargetYRelation
        clc
        adc     TankTargetDirectionIndex
        sta     TankTargetDirectionIndex
        cpx     #FirstEnemyTankSlot
        bcs     ChooseRandomEnemyAxisPriority
        txa
        asl     a
        eor     SlowFrameCounter
        and     #PlayerTargetAxisPhaseBit
        beq     UsePrimaryTargetDirection
        jmp     UseAlternateTargetDirection

ChooseRandomEnemyAxisPriority:
LDDD4:  jsr     NextRandomByte
        and     #EnemyTargetAxisRandomMask
        beq     UsePrimaryTargetDirection
UseAlternateTargetDirection:
LDDDB:  lda     #TargetDirectionAlternateOffset
        clc
        adc     TankTargetDirectionIndex
        tay
        jmp     LoadTargetDirectionState

UsePrimaryTargetDirection:
LDDE4:  ldy     TankTargetDirectionIndex
LoadTargetDirectionState:
LDDE6:  lda     TankAiDirectionStateTable,y
        rts
