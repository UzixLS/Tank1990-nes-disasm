; Общие векторы движения, позиции появления и dispatch-таблицы танков
; ($E46C-$E4D7). DirectionDeltaX/Y используют и танки, и снаряды.

EnemyLeftSpawnX          = $18
EnemyCenterSpawnX        = $78
EnemyRightSpawnX         = $D8
EnemyTopSpawnY           = $18
PlayerOneSpawnX          = $58
PlayerTwoSpawnX          = $98
PlayerBottomSpawnY       = $D8

DirectionDeltaX:
; Четыре знаковых единичных вектора в обязательном порядке direction-кодов
; Up, Left, Down, Right. Consumers индексируют 0..3 без bounds-check и сами
; масштабируют шаг: танк на 1 px, снаряд на 2/4 px, spawn projectile на 8 px.
LE46C:  .byte   0,$FF,0,1
DirectionDeltaY:
LE470:  .byte   $FF,0,1,0

; Три верхних центра spawn-ячеек: left, center, right. SpawnTank делает
; pre-increment общего индекса, поэтому после штатного EnemySpawnColumn=0
; фактическая последовательность — center, right, left. Обе таблицы обязаны
; оставаться параллельными и содержать ровно три записи: loop bound находится
; в отдельной константе EnemySpawnPointCount процедуры SpawnTank.
EnemySpawnX:
LE474:  .byte   EnemyLeftSpawnX,EnemyCenterSpawnX,EnemyRightSpawnX
EnemySpawnY:
LE477:  .byte   EnemyTopSpawnY,EnemyTopSpawnY,EnemyTopSpawnY

; Нижние центры P1/P2 индексируются непосредственно slot 0/1. Изменение числа
; записей требует одновременно менять PlayerTankCount и всех slot consumers.
PlayerSpawnX:
LE47A:  .byte   PlayerOneSpawnX,PlayerTwoSpawnX
PlayerSpawnY:
LE47C:  .byte   PlayerBottomSpawnY,PlayerBottomSpawnY

; По одному полному active state на каждый object slot: P1/P2 начинают вверх,
; все шесть enemy slots — вниз. InitializeTankState индексирует X без проверки,
; поэтому таблица должна сохранять восемь записей и slot order 0..7.
InitialTankStateBySlot:
LE47E:  .byte   TankStateActiveClass | DIRECTION_UP
        .byte   TankStateActiveClass | DIRECTION_UP
        .byte   TankStateActiveClass | DIRECTION_DOWN
        .byte   TankStateActiveClass | DIRECTION_DOWN
        .byte   TankStateActiveClass | DIRECTION_DOWN
        .byte   TankStateActiveClass | DIRECTION_DOWN
        .byte   TankStateActiveClass | DIRECTION_DOWN
        .byte   TankStateActiveClass | DIRECTION_DOWN
; Две последовательные матрицы 3x3 для relation index 3*y+x: target coordinate
; меньше=0, совпадает=1, больше=2 (x: left/same/right; y: above/same/below).
; Первая матрица, offsets 0..8, выбирает вертикаль при различии Y и горизонталь
; только при совпавшем Y. Вторая, offsets 9..17, симметрично предпочитает X.
; Таким образом строки полного active-state имеют вид:
;   vertical priority:    UUU / LUR / DDD
;   horizontal priority:  LUR / LUR / LDR
; Центральный relation same/same в обеих матрицах задаёт Up.
; ChooseTankStateTowardTarget напрямую записывает выбранный byte в ObjectState,
; поэтому entries должны быть полными states $A0..$A3, не direction 0..3.
; Код вычисляет horizontal offset как разность двух labels; обе матрицы должны
; оставаться смежными, по девять bytes каждая, и в одном порядке relations.
TankAiDirectionStateTable:
TankAiVerticalPriorityDirectionStates:
LE486:  .byte   TankStateActiveClass | DIRECTION_UP
        .byte   TankStateActiveClass | DIRECTION_UP
        .byte   TankStateActiveClass | DIRECTION_UP
        .byte   TankStateActiveClass | DIRECTION_LEFT
        .byte   TankStateActiveClass | DIRECTION_UP
        .byte   TankStateActiveClass | DIRECTION_RIGHT
        .byte   TankStateActiveClass | DIRECTION_DOWN
        .byte   TankStateActiveClass | DIRECTION_DOWN
        .byte   TankStateActiveClass | DIRECTION_DOWN
TankAiHorizontalPriorityDirectionStates:
        .byte   TankStateActiveClass | DIRECTION_LEFT
        .byte   TankStateActiveClass | DIRECTION_UP
        .byte   TankStateActiveClass | DIRECTION_RIGHT
        .byte   TankStateActiveClass | DIRECTION_LEFT
        .byte   TankStateActiveClass | DIRECTION_UP
        .byte   TankStateActiveClass | DIRECTION_RIGHT
        .byte   TankStateActiveClass | DIRECTION_LEFT
        .byte   TankStateActiveClass | DIRECTION_DOWN
        .byte   TankStateActiveClass | DIRECTION_RIGHT

; Две таблицы по 16 little-endian адресов в порядке state class $0..$F. Оба
; диспетчера вычисляют byte offset 2*(ObjectState>>4) без bounds-check, поэтому
; нельзя менять порядок, число записей или заменять .word однобайтными индексами
; без синхронной переделки DispatchTankLogic/DispatchTankDraw. Повторы адресов
; намеренны: несколько классов используют общий handler.
;
; Logic layout: 0 no-op; 1..7 destruction lifecycle; 8 idle/ice; 9 turn;
; A move; B target base; C target P2; D target P1; E/F spawn halves. B..D лишь
; переводят state в $A0..$A3; movement handler будет вызван на следующем
; разрешённом для слота logic tick, а не тем же dispatch-вызовом.
TankLogicHandlers:
LE498:  .word   TankLogicState0
        .word   TankLogicStates1To7,TankLogicStates1To7,TankLogicStates1To7
        .word   TankLogicStates1To7,TankLogicStates1To7,TankLogicStates1To7,TankLogicStates1To7
        .word   TankLogicState8,TankLogicState9,TankLogicStateA,TankLogicTargetBase
        .word   TankLogicTargetPlayerTwo,TankLogicTargetPlayerOne,TankLogicStateE,TankLogicStateF
; Draw layout: 0 no-op; 1/2 отдельные destruction pairs; 3/4 large explosion;
; 5..7 small explosion; 8..D normal tank; E/F spawn animation.
TankDrawHandlers:
LE4B8:  .word   TankDrawState0,DrawTankDestructionState1,DrawTankDestructionState2
        .word   DrawLargeTankDestructionStates3To4,DrawLargeTankDestructionStates3To4
        .word   DrawTankDestructionStates5To7,DrawTankDestructionStates5To7
        .word   DrawTankDestructionStates5To7
        .word   DrawTankStates8ToD,DrawTankStates8ToD,DrawTankStates8ToD
        .word   DrawTankStates8ToD,DrawTankStates8ToD,DrawTankStates8ToD
        .word   DrawTankSpawnStatesEToF,DrawTankSpawnStatesEToF
