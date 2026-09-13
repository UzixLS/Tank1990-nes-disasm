; Снаряды, эффекты поля, создание танков и общие таблицы ($E02E-$E603).

; Локальные роли общего loop-байта $5A; времена жизни проходов не пересекаются.
ProjectileUpdateSlot = $5A
ProjectileDrawSlot   = $5A
PlayerFiringSlot     = $5A

ProjectileFlagFast       = $01
ProjectileFlagBreakSteel = $02
ProjectileFlagsMaximum   = ProjectileFlagFast + ProjectileFlagBreakSteel
PlayerDoubleShotClass    = $40
PlayerProjectileSlotMask = $06

UpdateProjectiles:
; Обновляет все 10 слотов снарядов от 9 до 0 через DispatchProjectileLogic.
; Вход: нет. Выход: ProjectileUpdateSlot=$FF, X=0.
; Портит A/X/Y, ScratchPtr; активные снаряды меняют ProjectileX/Y, фазы
; попадания — ProjectileState. PPU/OAM и счёт здесь не затрагиваются.
LE02E:  lda     #(ProjectileSlotCount-1)
        sta     ProjectileUpdateSlot
UpdateNextProjectile:
LE032:  ldx     ProjectileUpdateSlot
        jsr     DispatchProjectileLogic
        dec     ProjectileUpdateSlot
        bpl     UpdateNextProjectile
        rts

DispatchProjectileLogic:
; Вход: X — слот 0..9. Выбирает обработчик класса 0..4 по старшей
; тетраде ProjectileState,X. Выход определяется обработчиком; X сохраняется.
; Хвостовой JMP: на стеке не появляется дополнительный адрес возврата.
; Портит A/Y, ScratchPtr и флаги.
LE03C:  lda     ProjectileState,x
        lsr     a
        lsr     a
        lsr     a
        and     #$FE
        tay
        lda     ProjectileLogicHandlers,y
        sta     ScratchPtrLo
        lda     ProjectileLogicHandlers+1,y
        sta     ScratchPtrHi
        jmp     (ScratchPtrLo)

ProjectileLogicState4:
; Активный снаряд: двигает на 2 px в направлении из младших двух битов state; при ProjectileFlags bit0 повторяет шаг,
; то есть двигает на 4 px. Вход: X — слот. Выход: X сохранён;
; меняет ProjectileX/Y,X, портит A/Y и флаги.
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
; Выход: X/Y сохранены; меняет ProjectileX/Y,X, портит A и флаги.
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
; Обратный отсчёт фаз взрыва 1..3. Когда младшая тетрада доходит до 0, уменьшает фазу на $10;
; ненулевые промежуточные фазы получают таймер 3, последняя переходит в state=0.
; Вход: X — слот. Выход: X/Y сохранены; меняет ProjectileState,X,
; портит A и флаги. Координаты и остальные поля снаряда не меняются.
        dec     ProjectileState,x
        lda     ProjectileState,x
        and     #$0F
        bne     FinishProjectileExplosionTick
        lda     ProjectileState,x
        and     #StateClassMask
        sec
        sbc     #$10
        beq     StoreProjectileExplosionState
        ora     #$03
StoreProjectileExplosionState:
LE089:  sta     ProjectileState,x
FinishProjectileExplosionTick:
LE08B:  rts

; Создаёт снаряд в слоте X, только если ProjectileState,X=0.
; Начальное state=$40|direction; координаты смещены на 8 px от ObjectX/Y,X, flags затем вычисляются по attributes/варианту.
; Для игрока X<2 запрашивает PlayerFireAudioState. Хвостовой JMP в
; InitializeProjectileFlagsForVariant.
; Вход: X — слот танка 0..7, одновременно основной слот его снаряда.
; Выход: X сохранён; при занятом слоте ничего не меняет. Портит A/Y и флаги;
; при создании меняет ProjectileState/X/Y/Flags,X и, для игрока, audio state.
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
; Ноль и остальные классы с bit7 оставляют предварительно очищенный ProjectileFlags,X без изменения.
DecodeProjectileFlagsFromAttributes:
LE0C0:
        beq     FinishProjectileInitialization
        cmp     #$C0
        beq     SetNormalProjectileFlags
        cmp     #$60
        beq     SetStrongProjectileFlags
        and     #$80
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
; Вход: нет. Выход: ProjectileDrawSlot=$FF, X зависит от последнего обработчика.
; Портит A/X/Y, ScratchPtr, render/OAM scratch и OAM shadow; игровое состояние
; снарядов и PPU-очередь не меняет.
LE0D8:  lda     #(ProjectileSlotCount-1)
        sta     ProjectileDrawSlot
DrawNextProjectile:
LE0DC:  ldx     ProjectileDrawSlot
        jsr     DispatchProjectileDraw
        dec     ProjectileDrawSlot
        bpl     DrawNextProjectile
        rts

DispatchProjectileDraw:
; Вход: X — слот 0..9. Диспетчер по классу 0..4 старшей тетрады
; ProjectileState,X. Хвостовой JMP; выход определяется обработчиком.
; Портит A/Y, ScratchPtr и флаги ещё до входа в него.
LE0E6:  lda     ProjectileState,x
        lsr     a
        lsr     a
        lsr     a
        and     #$FE
        tay
        lda     ProjectileDrawHandlers,y
        sta     ScratchPtrLo
        lda     ProjectileDrawHandlers+1,y
        sta     ScratchPtrHi
        jmp     (ScratchPtrLo)

ProjectileDrawState4:
; Рисует активный снаряд в его ProjectileX/Y с кадром по direction. Портит
; A/X/Y, ScratchPtr, $00, $04/$53, $0D, $47/$48 и OAM shadow.
; ProjectileState/X/Y/Flags и PPU-очередь не меняет.
        lda     ProjectileState,x
        and     #DirectionMask
        pha
        ldy     ProjectileY,x
        lda     ProjectileX,x
        tax
        lda     #$02
        sta     RenderAttributes
        lda     #$B1
        sta     OamTile
        pla
        jsr     EmitDirectionalOamSprite
        rts

ProjectileDrawStates1To3:
; Рисует фазу взрыва снаряда по ProjectileState+$40 в ProjectileX/Y. Портит
; A/X/Y, ScratchPtr, $00, $04/$53, $0D, $47/$48, $54/$55 и OAM shadow.
; ProjectileState/X/Y/Flags и PPU-очередь не меняет.
        lda     ProjectileState,x
        pha
        ldy     ProjectileY,x
        lda     ProjectileX,x
        tax
        pla
        clc
        adc     #$40
        jsr     ComputeAndDrawTankTransitionFrame
        rts

; Обходит игроков X=1..0, и для активных танков передаёт ввод в DispatchPlayerFireInput.
; Может создать или переложить снаряд; выход: PlayerFiringSlot=$FF.
; Вход: Joy1Pressed/Joy2Pressed и состояния игроков. Выход: X=0,
; PlayerFiringSlot=$FF. Портит A/X/Y, projectile RAM и при выстреле
; PlayerFireAudioState; PPU/OAM и счёт не меняет.
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
; Ветвь стрельбы игрока X. Для класса attributes $40 и занятого первого снаряда пытается использовать второй:
; если его второй слот свободен, копирует туда state/position/flags первого,
; очищает первый и создаёт новый.
; Иначе просто пытается инициализировать первый слот. Портит A/Y и projectile RAM; X сохраняет индекс игрока до хвоста цикла.
FirePlayerProjectile:
; Вход из DispatchPlayerFireInput: X=PlayerFiringSlot (0 или 1).
; Это continuation прохода, а не самостоятельная JSR-процедура: завершает
; обработку переходом к AdvancePlayerFiringLoop.
LE136:  lda     ObjectAttributes,x
        and     #$C0
        cmp     #PlayerDoubleShotClass
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
; с вероятностью 1/32 пытается выстрелить.
; Вход: нет. Выход: при выполненном проходе X=1; при заморозке X/Y сохранены.
; Портит A/Y, RNG, projectile RAM и флаги; успешный вражеский выстрел не
; запускает PlayerFireAudioState. PPU/OAM и счёт не меняет.
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
        and     #$1F
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
; Пять записей для классов состояния 0..4; классы 1..3 делят обработчик анимации взрыва.
LE4D8:  .word   ProjectileLogicState0
        .word   ProjectileLogicStates1To3,ProjectileLogicStates1To3,ProjectileLogicStates1To3
        .word   ProjectileLogicState4
ProjectileDrawHandlers:
; Пять записей в том же формате для отрисовки.
LE4E2:  .word   ProjectileDrawState0
        .word   ProjectileDrawStates1To3,ProjectileDrawStates1To3,ProjectileDrawStates1To3
        .word   ProjectileDrawState4

.include "tank_init.s"
.include "powerup_pickup_entry.s"
.include "score_awards.s"

.include "variant_ui_data.s"
