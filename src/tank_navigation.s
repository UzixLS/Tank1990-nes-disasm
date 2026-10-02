; Движение, terrain probes и смена направления танка ($DC52-$DD7D).
ProposedTankX    = $56
ProposedTankY    = $57
TankProbeXOffset = $58
TankProbeYOffset = $59
EnemyGridDecisionRandomMask = $0F
BlockedEnemyActionRandomMask = $03
EnemyTurnCoinMask           = $01
DirectionQuarterTurnStep    = $01
TankProbeHighEdgeAdjustment = $01

; Класс $8 совмещает короткую остановку и инерционное движение игрока по льду.
; Вход: X=CurrentTankSlot. Если X=0/1, PlayerIceState имеет bit7 и ненулевые
; bits0..6, счётчик уменьшается и танк пытается пройти 1 px в прежнем направлении,
; оставаясь в классе $8. ObjectFrame перед этим переключается, но общий
; Commit/blocked-хвост переключает его второй раз, поэтому итоговая фаза гусениц
; при скольжении не меняется.
;
; Без активного скольжения low-nibble state уменьшается по $04. Обычное состояние
; $88..$8B проходит через $84..$87 и на следующем обслуживании становится
; $A0..$A3 с сохранением direction. Финальный переход также пишет scratch
; TankStateBitsToMerge. X/Y сохраняются на idle-пути; ice-путь меняет
; PlayerIceState, может изменить ObjectX/Y и портит movement/terrain scratch.
TankLogicState8:
        cpx     #FirstEnemyTankSlot
        bcs     AdvanceTankIdlePhase
        lda     PlayerIceState,x
        bpl     AdvanceTankIdlePhase
        and     #PlayerIceInactiveMask
        beq     AdvanceTankIdlePhase
        dec     PlayerIceState,x
        lda     ObjectFrame,x
        eor     #TankTrackFrameBit
        sta     ObjectFrame,x
        jmp     AdvanceTankMovement

AdvanceTankIdlePhase:
LDC6B:  lda     ObjectState,x
        sec
        sbc     #TankIdlePhaseStep
        sta     ObjectState,x
        and     #TankIdlePhaseMask
        bne     ReturnFromTankIdlePhase
        lda     #TankStateActiveClass
        jsr     SetTankStateClass
ReturnFromTankIdlePhase:
LDC7B:  rts

; Класс $A: попытка движения на 1 px по direction. Вход: X=CurrentTankSlot.
; Враг, уже стоящий обеими координатами на сетке 8 px, с вероятностью 1/16
; выбирает новый AI-mode и завершает tick без движения и смены ObjectFrame.
; Иначе проверяются две точки передней границы: свободный проход фиксирует новые
; ObjectX/Y и переключает фазу гусениц; блокировка игрока переключает только фазу,
; а враг выбирает остановку либо разворот.
;
; Портит A/X/Y, ProposedTankX/Y, TankProbeX/YOffset и ScratchPtrLo/Hi. Может
; продвинуть RNG и изменить ObjectState/ObjectFrame; terrain shadow и PPU queue
; только читает. Итоговый X восстанавливается из CurrentTankSlot на movement-пути.
TankLogicStateA:
        cpx     #FirstEnemyTankSlot
        bcc     AdvanceTankMovement
        lda     ObjectX,x
        and     #TankGridSubpixelMask
        bne     AdvanceTankMovement
        lda     ObjectY,x
        and     #TankGridSubpixelMask
        bne     AdvanceTankMovement
        jsr     NextRandomByte
        and     #EnemyGridDecisionRandomMask
        bne     AdvanceTankMovement
        jsr     ChooseEnemyTankAiMode
        rts

; Общий хвост классов $8/$A. Вход: X=CurrentTankSlot, direction в ObjectState.
; ProposedTankX/Y получает центр после шага на 1 px, TankProbeX/YOffset --
; знаковые компоненты direction, умноженные на 8. Относительно нового центра
; проверяются два угла включительной границы 16x16:
;   Up    (-8,-8), (+7,-8)       Left  (-8,-8), (-8,+7)
;   Down  (+7,+7), (-8,+7)       Right (+7,+7), (+7,-8)
; Bit7 shadow-байта (временная занятость другим танком) блокирует сразу; ноль
; пропускает к следующему углу/commit, остальные коды классифицируют
; RouteFirstTerrainProbe/RouteSecondTerrainProbe. Портит A/X/Y и ScratchPtr.
AdvanceTankMovement:
LDC97:  lda     ObjectState,x
        and     #DirectionMask
        tay
        lda     DirectionDeltaY,y
        asl     a
        asl     a
        asl     a
        sta     TankProbeYOffset
        lda     DirectionDeltaY,y
        clc
        adc     ObjectY,x
        sta     ProposedTankY
        lda     DirectionDeltaX,y
        asl     a
        asl     a
        asl     a
        sta     TankProbeXOffset
        lda     DirectionDeltaX,y
        clc
        adc     ObjectX,x
        sta     ProposedTankX
        clc
        adc     TankProbeXOffset
        clc
        adc     TankProbeYOffset
        jsr     AdjustTankProbeXForHighEdge
        tax
        lda     ProposedTankY
        clc
        adc     TankProbeXOffset
        clc
        adc     TankProbeYOffset
        jsr     AdjustTankProbeYForHighEdge
        tay
        jsr     PixelCoordinatesToShadowPointer
        lda     (ScratchPtrLo),y
        bmi     HandleBlockedTankMovement
        beq     ProbeSecondTankCorner
        jmp     RouteFirstTerrainProbe

        .byte   $EA
ProbeSecondTankCorner:
; Continuation первой успешной пробы. Проверяет второй угол передней границы.
; Shadow byte с bit7 передаёт управление HandleBlockedTankMovement, нулевой --
; CommitProposedTankMovement, прочий -- RouteSecondTerrainProbe. Ни один путь
; сюда не возвращается; портит A/X/Y и ScratchPtrLo/Hi.
LDCDF:  lda     ProposedTankX
        clc
        adc     TankProbeXOffset
        sec
        sbc     TankProbeYOffset
        jsr     AdjustTankProbeXForHighEdge
        tax
        lda     ProposedTankY
        clc
        adc     TankProbeYOffset
        sec
        sbc     TankProbeXOffset
        jsr     AdjustTankProbeYForHighEdge
        tay
        jsr     PixelCoordinatesToShadowPointer
        lda     (ScratchPtrLo),y
        bmi     HandleBlockedTankMovement
        beq     CommitProposedTankMovement
        jmp     RouteSecondTerrainProbe

        .byte   $EA
CommitProposedTankMovement:
; Фиксирует предложенный центр для CurrentTankSlot и переключает bit2 ObjectFrame
; как фазу гусениц. Выход: X=CurrentTankSlot, A=новый ObjectFrame,X; Y сохраняется.
; Меняет только ObjectX/Y и ObjectFrame выбранного танка. При входе из ice-пути
; это второе переключение кадра, поэтому его итоговое значение восстанавливается.
LDD04:  ldx     CurrentTankSlot
        lda     ProposedTankX
        sta     ObjectX,x
        lda     ProposedTankY
        sta     ObjectY,x
        jmp     ToggleTankAnimationFrame

HandleBlockedTankMovement:
; Отменяет предложенное перемещение, ObjectX/Y не меняются. Игрок только
; переключает фазу гусениц (на ice-пути -- обратно к исходной). Враг с
; вероятностью 1/4 разворачивается через ReverseEnemyTankDirection; в остальных
; 3/4 случаев получает state $88..$8B и переключает ObjectFrame.
; Выход: X=CurrentTankSlot, Y сохраняется, A зависит от хвоста. Вражеский путь
; продвигает RNG; idle-ветвь также пишет bits-to-merge scratch
; TankStateBitsToMerge.
LDD11:  ldx     CurrentTankSlot
        cpx     #FirstEnemyTankSlot
        bcc     ToggleTankAnimationFrame
        jsr     NextRandomByte
        and     #BlockedEnemyActionRandomMask
        beq     ReverseEnemyTankDirection
        lda     #TankStateIdleClass
        jsr     SetTankStateClass
        lda     #TankIdlePhaseFlag
        ora     ObjectState,x
        sta     ObjectState,x
; Переключает bit2 ObjectFrame,X как фазу гусениц.
; Вход/выход: X=слот, A=новый ObjectFrame; Y сохраняется.
ToggleTankAnimationFrame:
LDD29:  lda     ObjectFrame,x
        eor     #TankTrackFrameBit
        sta     ObjectFrame,x
        rts

; Разворачивает direction противника на 180 градусов. Если обе координаты лежат
; на сетке 8 px, предварительно заменяет класс на $9, сохраняя low nibble; вне
; узла класс не меняется. Вход: X=слот противника. Выход: A=новый ObjectState,X;
; X/Y сохраняются. Выровненная ветвь пишет bits-to-merge scratch
; TankStateBitsToMerge, остальные
; поля объекта и координаты не меняются.
ReverseEnemyTankDirection:
LDD30:  lda     ObjectX,x
        and     #TankGridSubpixelMask
        bne     CommitReversedEnemyDirection
        lda     ObjectY,x
        and     #TankGridSubpixelMask
        bne     CommitReversedEnemyDirection
        lda     #TankStateTurningClass
        jsr     SetTankStateClass
CommitReversedEnemyDirection:
LDD41:  lda     ObjectState,x
        eor     #DirectionOppositeXor
        sta     ObjectState,x
        rts

; Класс $9 выбирает продолжение после разворота у препятствия. Первый RNG-bit
; в половине вызовов передаёт выбор ChooseEnemyTankAiMode. Вторая половина
; расходует ещё один RNG-byte: по 1/4 всех вызовов поворачивает на 90 градусов
; по либо против часовой стрелки и сразу возвращает класс $A.
; Вход: X=слот противника. Выход: ObjectState,X изменён, X/Y сохраняются.
; RNG продвигается минимум один раз и дважды на adjacent-turn пути; AI-путь
; условно пишет bits-to-merge scratch TankStateBitsToMerge при выборе
; target-класса.
TankLogicState9:
        jsr     NextRandomByte
        and     #EnemyTurnCoinMask
        beq     ChooseEnemyAiModeFromTurningState
        jsr     NextRandomByte
        and     #EnemyTurnCoinMask
        beq     TurnEnemyClockwise
TurnEnemyCounterclockwise:
        lda     ObjectState,x
        clc
        adc     #DirectionQuarterTurnStep
        jmp     CommitAdjacentEnemyTurn

TurnEnemyClockwise:
LDD5E:  lda     ObjectState,x
        sec
        sbc     #DirectionQuarterTurnStep
CommitAdjacentEnemyTurn:
LDD63:  and     #DirectionMask
        ora     #TankStateActiveClass
        sta     ObjectState,x
        rts

ChooseEnemyAiModeFromTurningState:
LDD6A:  jsr     ChooseEnemyTankAiMode
        rts

; Делает положительную половину 16-pixel hitbox включительной: если беззнаковая
; probe-X не меньше ProposedTankX, вычитает 1 (обычно +8 превращается в +7);
; отрицательная половина -8 остаётся без изменения. X/Y и RAM сохраняются.
AdjustTankProbeXForHighEdge:
LDD6E:  cmp     ProposedTankX
        bcc     ReturnAdjustedTankProbeX
        sec
        sbc     #TankProbeHighEdgeAdjustment
ReturnAdjustedTankProbeX:
LDD75:  rts

AdjustTankProbeYForHighEdge:
; Аналог AdjustTankProbeXForHighEdge для A=probe-Y и ProposedTankY.
LDD76:  cmp     ProposedTankY
        bcc     ReturnAdjustedTankProbeY
        sec
        sbc     #TankProbeHighEdgeAdjustment
ReturnAdjustedTankProbeY:
LDD7D:  rts
