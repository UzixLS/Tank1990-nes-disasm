; Общие векторы движения, позиции появления и dispatch-таблицы танков
; ($E46C-$E4D7). DirectionDeltaX/Y используют и танки, и снаряды.

DirectionDeltaX:
; Знаковые единичные векторы для направлений Up,Left,Down,Right.
LE46C:  .byte   0,$FF,0,1
DirectionDeltaY:
LE470:  .byte   $FF,0,1,0
EnemySpawnX:
LE474:  .byte   $18,$78,$D8
EnemySpawnY:
LE477:  .byte   $18,$18,$18
PlayerSpawnX:
LE47A:  .byte   $58,$98
PlayerSpawnY:
LE47C:  .byte   $D8,$D8
InitialTankStateBySlot:
LE47E:  .byte   TankStateActiveClass | DIRECTION_UP
        .byte   TankStateActiveClass | DIRECTION_UP
        .byte   TankStateActiveClass | DIRECTION_DOWN
        .byte   TankStateActiveClass | DIRECTION_DOWN
        .byte   TankStateActiveClass | DIRECTION_DOWN
        .byte   TankStateActiveClass | DIRECTION_DOWN
        .byte   TankStateActiveClass | DIRECTION_DOWN
        .byte   TankStateActiveClass | DIRECTION_DOWN
; Восемнадцать записей состояний $A0..$A3, используемых ИИ для выбора направления.
TankAiDirectionStateTable:
LE486:  .byte   TankStateActiveClass | DIRECTION_UP
        .byte   TankStateActiveClass | DIRECTION_UP
        .byte   TankStateActiveClass | DIRECTION_UP
        .byte   TankStateActiveClass | DIRECTION_LEFT
        .byte   TankStateActiveClass | DIRECTION_UP
        .byte   TankStateActiveClass | DIRECTION_RIGHT
        .byte   TankStateActiveClass | DIRECTION_DOWN
        .byte   TankStateActiveClass | DIRECTION_DOWN
        .byte   TankStateActiveClass | DIRECTION_DOWN
        .byte   TankStateActiveClass | DIRECTION_LEFT
        .byte   TankStateActiveClass | DIRECTION_UP
        .byte   TankStateActiveClass | DIRECTION_RIGHT
        .byte   TankStateActiveClass | DIRECTION_LEFT
        .byte   TankStateActiveClass | DIRECTION_UP
        .byte   TankStateActiveClass | DIRECTION_RIGHT
        .byte   TankStateActiveClass | DIRECTION_LEFT
        .byte   TankStateActiveClass | DIRECTION_DOWN
        .byte   TankStateActiveClass | DIRECTION_RIGHT

; Таблицы адресов обработчиков танков. Индекс — удвоенная старшая тетрада ObjectState;
; выбор между логикой и отрисовкой делает вызывающий диспетчер.
TankLogicHandlers:
LE498:  .word   TankLogicState0
        .word   TankLogicStates1To7,TankLogicStates1To7,TankLogicStates1To7
        .word   TankLogicStates1To7,TankLogicStates1To7,TankLogicStates1To7,TankLogicStates1To7
        .word   TankLogicState8,TankLogicState9,TankLogicStateA,TankLogicStateB
        .word   TankLogicStateC,TankLogicStateD,TankLogicStateE,TankLogicStateF
TankDrawHandlers:
LE4B8:  .word   TankDrawState0,DrawTankDestructionState1,DrawTankDestructionState2
        .word   DrawLargeTankDestructionStates3To4,DrawLargeTankDestructionStates3To4
        .word   DrawTankDestructionStates5To7,DrawTankDestructionStates5To7
        .word   DrawTankDestructionStates5To7
        .word   DrawTankStates8ToD,DrawTankStates8ToD,DrawTankStates8ToD
        .word   DrawTankStates8ToD,DrawTankStates8ToD,DrawTankStates8ToD
        .word   DrawTankSpawnStatesEToF,DrawTankSpawnStatesEToF
