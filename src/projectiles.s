; Снаряды, эффекты поля, создание танков и общие таблицы ($E02E-$E603).

; Локальные роли общего loop-байта $5A; времена жизни проходов не пересекаются.
ProjectileUpdateSlot = $5A
ProjectileDrawSlot   = $5A
PlayerFiringSlot     = $5A

ProjectileFlagFast       = $01
ProjectileFlagBreakSteel = $02
ProjectileFlagsMaximum   = ProjectileFlagFast + ProjectileFlagBreakSteel
PlayerDoubleShotAttributeClass = $40
PlayerProjectileSlotMask = $06
ProjectileExplosionClassStep       = $10
ProjectileExplosionPhaseDelay      = $03
ProjectileExplosionRenderClassBias = $40
ActiveProjectileRenderPalette      = $02
ActiveProjectileTileBase           = $B1
BaseFastProjectileAttributeClass   = $C0
ProjectileStrongAttributeClass     = $60
ProjectileAttributeClassHighBit    = $80
PlayerProjectileClassMask          = $C0
EnemyFireRandomMask                = $1F

; Формат десяти projectile slots:
;   0/1 — основные выстрелы P1/P2;
;   2..7 — по одному выстрелу enemy object slots 2..7;
;   8/9 — дополнительные выстрелы P1/P2, создаваемые только переносом из 0/1.
; Условие (slot & PlayerProjectileSlotMask)=0 тем самым выбирает 0,1,8,9;
; logical owner player-shot определяется slot&1. State high nibble: 0=free,
; 1..3=три explosion classes, 4=active flight; low bits active state содержат
; direction 0..3, а explosion state — countdown. Dispatch tables ниже имеют
; только классы 0..4: другие high nibbles невалидны и не проверяются.

UpdateProjectiles:
; Обновляет все 10 слотов снарядов от 9 до 0 через DispatchProjectileLogic.
; Вход: каждый ProjectileState должен иметь class 0..4. Выход:
; ProjectileUpdateSlot=$FF, X=0, N=1/Z=0; A/Y/C/V зависят от slot 0 handler,
; ScratchPtr содержит адрес его handler-а.
; Портит A/X/Y, ScratchPtr; активные снаряды меняют ProjectileX/Y, фазы
; попадания — ProjectileState. Координаты движутся modulo 256 без clipping.
; PPU/OAM, flags снарядов, объекты, audio и счёт здесь не затрагиваются.
LE02E:  lda     #(ProjectileSlotCount-1)
        sta     ProjectileUpdateSlot
UpdateNextProjectile:
LE032:  ldx     ProjectileUpdateSlot
        jsr     DispatchProjectileLogic
        dec     ProjectileUpdateSlot
        bpl     UpdateNextProjectile
        rts

DispatchProjectileLogic:
; Вход: X — слот 0..9, state class 0..4. Индекс равен 2*(state>>4); mask $FE
; выравнивает word, но НЕ ограничивает его пятью entries. Classes 5..9 случайно
; читают соседнюю ProjectileDrawHandlers как logic handlers, >=A — следующие
; code/data bytes как адреса. Romhack обязан расширять таблицу синхронно с
; форматами state, иначе получится косвенный переход по произвольному адресу.
; Для valid class выход определяется обработчиком; X сохраняется.
; Хвостовой JMP: на стеке не появляется дополнительный адрес возврата.
; Портит A/Y, ScratchPtr=handler address и флаги.
LE03C:  lda     ProjectileState,x
        lsr     a
        lsr     a
        lsr     a
        and     #DispatchWordIndexMask
        tay
        lda     ProjectileLogicHandlers,y
        sta     ScratchPtrLo
        lda     ProjectileLogicHandlers+1,y
        sta     ScratchPtrHi
        jmp     (ScratchPtrLo)

ProjectileLogicState4:
; Активный снаряд: двигает на 2 px в направлении из младших двух битов state;
; ProjectileFlagFast повторяет тот же шаг и даёт 4 px за tick. Прочие state
; low bits игнорируются. Вход: X — slot, state class=$4. Выход: X сохранён,
; Y=direction. Для slow shot A=0, N=0/Z=1; для fast A=новый ProjectileY,X,
; flags от второго шага. Меняет ProjectileX/Y,X modulo 256; state/flags и
; collision/PPU/OAM/audio state не меняет.
        lda     ProjectileState,x
        and     #DirectionMask
        tay
        jsr     MoveProjectileTwoPixels
        lda     ProjectileFlags,x
        and     #ProjectileFlagFast
        beq     FinishActiveProjectileStep
        jsr     MoveProjectileTwoPixels
FinishActiveProjectileStep:
LE062:  rts

; Один шаг снаряда X на 2 px. Вход: X — слот, Y — direction 0..3.
; Использует общие DirectionDeltaX/Y; bounds check Y нет. Выход:
; A=новый ProjectileY,X, X/Y сохранены, N/Z/C/V от Y-сложения. Меняет обе
; координаты modulo 256 (в том числе прибавляет ноль к поперечной), clipping нет.
MoveProjectileTwoPixels:
LE063:  lda     DirectionDeltaX,y
        asl     a
        clc
        adc     ProjectileX,x
        sta     ProjectileX,x
        lda     DirectionDeltaY,y
        asl     a
        clc
        adc     ProjectileY,x
        sta     ProjectileY,x
        rts

ProjectileLogicStates1To3:
; Обратный отсчёт explosion classes 1..3. Штатная цепочка начинается с $33:
; $33,$32,$31 -> $23,$22,$21 -> $13,$12,$11 -> $00, то есть по три draw-frame
; на class. DEC выполняется раньше проверки: переход класса происходит только
; из state с low nibble 1. Нестандартный $x0 сначала заимствует в $(x-1)F и не
; использует normal transition, поэтому romhack должен создавать phases как $x3.
; Вход: X — слот. Выход: X/Y сохранены; меняет ProjectileState,X,
; A/flags зависят от timer/transition. Координаты, ProjectileFlags, PPU/OAM/audio
; и остальные slots не меняются.
        dec     ProjectileState,x
        lda     ProjectileState,x
        and     #StateLowNibbleMask
        bne     FinishProjectileExplosionTick
        lda     ProjectileState,x
        and     #StateClassMask
        sec
        sbc     #ProjectileExplosionClassStep
        beq     StoreProjectileExplosionState
        ora     #ProjectileExplosionPhaseDelay
StoreProjectileExplosionState:
LE089:  sta     ProjectileState,x
FinishProjectileExplosionTick:
LE08B:  rts

; Создаёт снаряд в слоте X, только если ProjectileState,X=0.
; Начальное state=$40|direction; координаты смещены на 8 px от ObjectX/Y,X
; общими signed unit vectors и заворачиваются modulo 256. Flags сначала
; обнуляются, затем вычисляются по ObjectAttributes,X/GameVariant.
; Для игрока X<2 запрашивает PlayerFireAudioState. Хвостовой JMP в
; InitializeProjectileFlagsForVariant.
; Вход: X — слот танка 0..7, одновременно основной слот его снаряда.
; ObjectState direction должен быть 0..3 после mask; вызов с X=8/9 невалиден,
; потому что соответствующих Object fields нет. Выход: X сохранён. При занятом
; slot возвращает A=его ненулевой state, Y/RAM сохраняются, N/Z по A. При
; создании Y=direction, A/flags задаёт variant decoder; меняет только четыре
; projectile fields X и для player — PlayerFireAudioState. PPU/OAM не трогает.
InitializeProjectileForTank:
LE08C:  lda     ProjectileState,x
        bne     FinishProjectileInitialization
        cpx     #FirstEnemyTankSlot
        bcs     CreateProjectileFromTank
        lda     #AudioStateStartRequested
        sta     PlayerFireAudioState
CreateProjectileFromTank:
LE099:  lda     ObjectState,x
        and     #DirectionMask
        tay
        ora     #ProjectileStateActive
        sta     ProjectileState,x
        lda     DirectionDeltaX,y
        asl     a
        asl     a
        asl     a
        clc
        adc     ObjectX,x
        sta     ProjectileX,x
        lda     DirectionDeltaY,y
        asl     a
        asl     a
        asl     a
        clc
        adc     ObjectY,x
        sta     ProjectileY,x
        lda     #$00
        sta     ProjectileFlags,x
        jmp     InitializeProjectileFlagsForVariant

; Сохранённый байт в недостижимом промежутке: предыдущий путь заканчивается
; безусловным JMP, а $E0C0 используется как отдельный вход. Ссылок на $E0BF нет;
; как самостоятельная инструкция байт не интерпретируется.
UnreferencedE0bfByte:
LE0BF:  .byte   $F0
; Базовая декодировка мощности снаряда из старшей тетрады ObjectAttributes.
; Вход: A=attributes&$F0, X — слот. $60 даёт flags=3; $C0 и прочие ненулевые
; классы без bit7, кроме $60, дают flags=1.
; Ноль и остальные классы с bit7 оставляют предварительно очищенный
; ProjectileFlags,X без изменения. Полная mapping: $00 ->0; $60 ->Fast|BreakSteel;
; $10..$50/$70/$C0 ->Fast; $80/$90/$A0/$B0/$D0/$E0/$F0 ->0.
; Входной ProjectileFlags,X=0 обязателен для no-write ветвей. Выход: X/Y
; сохранены, A=0/$80/1/3, N/Z по A, V сохранён. C сохраняется для $00,
; равен 0 для $10..$50 и 1 для $60..$F0.
DecodeProjectileFlagsFromAttributes:
LE0C0:
        beq     FinishProjectileInitialization
        cmp     #BaseFastProjectileAttributeClass
        beq     SetNormalProjectileFlags
        cmp     #ProjectileStrongAttributeClass
        beq     SetStrongProjectileFlags
        and     #ProjectileAttributeClassHighBit
        bne     FinishProjectileInitialization
SetNormalProjectileFlags:
LE0CE:  lda     #ProjectileFlagFast
        sta     ProjectileFlags,x
        rts

SetStrongProjectileFlags:
LE0D3:  lda     #ProjectileFlagsMaximum
        sta     ProjectileFlags,x
FinishProjectileInitialization:
LE0D7:  rts

DrawProjectiles:
; Отрисовывает все 10 слотов снарядов от 9 до 0.
; Class0 не выдаёт OAM, active class4 — одну entry, explosion classes1..3 — две;
; максимум этого прохода 20 entries/80 bytes, но свободная общая OAM capacity
; не проверяется. Требуются OamBufferPos, выровненный на 4, OamBufferStep=+4/-4
; и terrain shadow, безопасный для probes EmitOamSprite.
; Вход: valid state classes0..4. Выход: ProjectileDrawSlot=$FF, N=1/Z=0;
; A/X/Y/C/V и ScratchPtr зависят от slot0 handler.
; Портит A/X/Y, ScratchPtr, render/OAM scratch и OAM shadow; игровое состояние
; снарядов, PPU queue/registers, audio и счёт не меняет.
LE0D8:  lda     #(ProjectileSlotCount-1)
        sta     ProjectileDrawSlot
DrawNextProjectile:
LE0DC:  ldx     ProjectileDrawSlot
        jsr     DispatchProjectileDraw
        dec     ProjectileDrawSlot
        bpl     DrawNextProjectile
        rts

DispatchProjectileDraw:
; Вход: X — slot 0..9, state class0..4. Индекс вычисляется как у logic dispatch;
; bounds check нет. Class>=5 читает words за концом ProjectileDrawHandlers
; (начиная с кода tank_init) и выполняет произвольный indirect jump.
; Хвостовой JMP; выход определяется обработчиком. Портит A/Y,
; ScratchPtr=handler address и flags ещё до входа в него.
LE0E6:  lda     ProjectileState,x
        lsr     a
        lsr     a
        lsr     a
        and     #DispatchWordIndexMask
        tay
        lda     ProjectileDrawHandlers,y
        sta     ScratchPtrLo
        lda     ProjectileDrawHandlers+1,y
        sta     ScratchPtrHi
        jmp     (ScratchPtrLo)

ProjectileDrawState4:
; Рисует active shot одной 8x16 hardware entry: direction 0..3 выбирает tile
; $B1/$B3/$B5/$B7, palette attributes=2. EmitDirectionalOamSprite записывает
; hardware position (ProjectileX-5, ProjectileY-8) и проверяет terrain point
; (ProjectileX-2,ProjectileY); над точным tile $22 может OR-ить текущую
; SpriteBehindTerrainMask. Все координаты 8-битно заворачиваются. Портит
; A/X/Y, ScratchPtr, TerrainSubcellMask, RenderAttributes/OamTile,
; OamBufferPos, OamSavedX/Y и OAM shadow.
; ProjectileState/X/Y/Flags и PPU-очередь не меняет.
        lda     ProjectileState,x
        and     #DirectionMask
        pha
        ldy     ProjectileY,x
        lda     ProjectileX,x
        tax
        lda     #ActiveProjectileRenderPalette
        sta     RenderAttributes
        lda     #ActiveProjectileTileBase
        sta     OamTile
        pla
        jsr     EmitDirectionalOamSprite
        rts

ProjectileDrawStates1To3:
; Прибавляет $40 к classes1..3 и использует общий small-explosion renderer:
; projectile classes3/2/1 дают пары tiles $F1/$F3, $F5/$F7, $F9/$FB.
; Две 8x16 entries получают palette=3 и positions
; (ProjectileX-8,ProjectileY-8)/(ProjectileX,ProjectileY-8); terrain probes
; выполняются в X-5 и X+3 при исходном Y. Текущая SpriteBehindTerrainMask может
; добавить priority bit отдельно/липко через EmitOamSprite. Портит
; A/X/Y, ScratchPtr, TerrainSubcellMask, RenderAttributes/OamTile,
; OamBufferPos, OamSavedX/Y, OamPairX/Y и OAM shadow.
; ProjectileState/X/Y/Flags, сама priority mask и PPU queue/registers не меняет.
        lda     ProjectileState,x
        pha
        ldy     ProjectileY,x
        lda     ProjectileX,x
        tax
        pla
        clc
        adc     #ProjectileExplosionRenderClassBias
        jsr     ComputeAndDrawSmallExplosionFrame
        rts

; Обходит игроков X=1..0, и для активных танков передаёт ввод в DispatchPlayerFireInput.
; Targetable states — $80..$DF. В обычных GameMode fire даёт pressed A либо
; held B; CombinedFireGameMode — pressed A или B. Эта фаза идёт после движения
; существующих shots: новый shot уже участвует в collisions/draw текущего tick,
; но впервые движется на следующем.
; Вход: Joy held/pressed, GameMode и player object/projectile state. Выход:
; X=0, PlayerFiringSlot=$FF, N=1/Z=0; A/Y/C/V зависят от P1 path. Портит
; projectile RAM и при успешном создании PlayerFireAudioState; RNG, PPU/OAM,
; объекты и счёт не меняет.
UpdatePlayerFiring:
LE122:  lda     #$01
        sta     PlayerFiringSlot
CheckNextPlayerFire:
LE126:  ldx     PlayerFiringSlot
        lda     ObjectState,x
        bpl     AdvancePlayerFiringLoop
        cmp     #NonTargetableTankStateMin
        bcs     AdvancePlayerFiringLoop
        jmp     DispatchPlayerFireInput

; Недостижимые сохранённые байты после хвостового JMP в dispatch ввода.
; Dispatch возвращает управление только в $E136/$E15D; ссылок на $E133 нет.
UnreferencedE133Bytes:
LE133:  .byte   $03,$F0,$27
; Ветвь стрельбы игрока X. Условие (ObjectAttributes&$C0)=$40 охватывает
; high classes $40..$7F. Если основной shot занят, а дополнительный slot X+8
; свободен, туда дословно копируются state/position/flags первого, первый
; освобождается и в нём создаётся новый shot. Переносится любой ненулевой state,
; включая explosion countdown. Если extra slot занят, fire полностью
; пропускается без audio; если основной свободен, extra вообще не проверяется.
; Для остальных attribute classes используется только основной slot.
; P1 maps 0<->8, P2 1<->9.
FirePlayerProjectile:
; Вход из DispatchPlayerFireInput: X=PlayerFiringSlot (0 или 1).
; Это continuation прохода, а не самостоятельная JSR-процедура: завершает
; обработку переходом к AdvancePlayerFiringLoop. Прямой JSR с произвольным
; PlayerFiringSlot нарушит loop contract. X сохраняется до общего хвоста;
; портит A/Y, main/extra projectile fields и при создании fire audio.
LE136:  lda     ObjectAttributes,x
        and     #PlayerProjectileClassMask
        cmp     #PlayerDoubleShotAttributeClass
        bne     InitializeCurrentPlayerProjectile
        lda     ProjectileState,x
        beq     InitializeCurrentPlayerProjectile
        lda     ProjectileState+8,x
        bne     AdvancePlayerFiringLoop
        lda     ProjectileState,x
        sta     ProjectileState+8,x
        lda     ProjectileX,x
        sta     ProjectileX+8,x
        lda     ProjectileY,x
        sta     ProjectileY+8,x
        lda     ProjectileFlags,x
        sta     ProjectileFlags+8,x
        lda     #$00
        sta     ProjectileState,x
InitializeCurrentPlayerProjectile:
LE15A:  jsr     InitializeProjectileForTank
AdvancePlayerFiringLoop:
LE15D:  dec     PlayerFiringSlot
        bpl     CheckNextPlayerFire
        rts

; При EnemyFreezeTimer=0 обходит врагов X=7..2. Каждый активный танк
; в state $80..$DF расходует ровно один RNG byte и с условием (random&$1F)=0
; пытается выстрелить (1/32 при равномерном RNG). RNG расходуется даже когда
; projectile slot занят и InitializeProjectileForTank затем ничего не создаёт.
; Заморозка запрещает и RNG calls, и попытки. Новые enemy shots, как player
; shots, сталкиваются/рисуются в текущем tick, но движутся со следующего.
; Вход: нет. Выход: при незамороженном проходе X=1, N=0/Z=C=1 после CPX,
; A/Y/V зависят от slot2 path; при EnemyFreezeTimer!=0 A=timer, X/Y сохранены,
; N/Z по timer, C/V сохранены. Меняет RNG и при успешной попытке primary
; projectile slot 2..7; fire audio, PPU/OAM, объекты и счёт не меняет.
UpdateEnemyFiring:
LE162:  lda     EnemyFreezeTimer
        bne     FinishEnemyFiringPass
        ldx     #(TankSlotCount-1)
CheckNextEnemyFire:
LE169:  lda     ObjectState,x
        bpl     AdvanceEnemyFiringSlot
        cmp     #NonTargetableTankStateMin
        bcs     AdvanceEnemyFiringSlot
        jsr     NextRandomByte
        and     #EnemyFireRandomMask
        bne     AdvanceEnemyFiringSlot
        jsr     InitializeProjectileForTank
AdvanceEnemyFiringSlot:
LE17B:  dex
        cpx     #$01
        bne     CheckNextEnemyFire
FinishEnemyFiringPass:
LE180:  rts

.include "tank_occupancy.s"

.include "battle_effects.s"
.include "tank_spawn.s"

.include "powerup_effect1.s"
.include "variant_ui_logic.s"
.include "object_state_helpers.s"
.include "stage_catalog.s"
.include "variant_metadata_helpers.s"
.include "input_direction.s"
.include "tank_tables.s"
ProjectileLogicHandlers:
; Ровно пять little-endian words для state classes0..4: no-op, три общих
; explosion entries и active movement. Таблица непосредственно примыкает к draw
; table, поэтому logic classes5..9 ошибочно попадают в draw handlers.
LE4D8:  .word   ProjectileLogicState0
        .word   ProjectileLogicStates1To3,ProjectileLogicStates1To3,ProjectileLogicStates1To3
        .word   ProjectileLogicState4
ProjectileDrawHandlers:
; Ровно пять words в том же class order: no-op, три small-explosion entries и
; active sprite. Следующие bytes уже являются кодом включённого tank_init.s.
LE4E2:  .word   ProjectileDrawState0
        .word   ProjectileDrawStates1To3,ProjectileDrawStates1To3,ProjectileDrawStates1To3
        .word   ProjectileDrawState4

.include "tank_init.s"
.include "powerup_pickup_entry.s"
.include "score_awards.s"

.include "variant_ui_data.s"
