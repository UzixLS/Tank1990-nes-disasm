; Снаряды, эффекты поля, создание танков и общие таблицы ($E02E-$E603).

TankShadowPtrLo         = $E0
TankShadowPtrHiAndFlags = $E8
BaseSpriteTileOffset    = $69

; Локальные роли общего loop-байта $5A; времена жизни проходов не пересекаются.
ProjectileUpdateSlot = $5A
ProjectileDrawSlot   = $5A
PlayerFiringSlot     = $5A
OccupancyTankSlot    = $5A
ShieldPlayerSlot     = $5A
TankStateClassCandidate = $00

TankCenterShadowOffset = $21

UpdateProjectiles:
; Обновляет все 10 слотов снарядов от 9 до 0 через DispatchProjectileLogic.
; Выход: ProjectileUpdateSlot=$FF; портит A/X/Y, ScratchPtr и поля снарядов
; по контракту обработчика.
LE02E:  lda     #(ProjectileSlotCount-1)
        sta     ProjectileUpdateSlot
UpdateNextProjectile:
LE032:  ldx     ProjectileUpdateSlot
        jsr     DispatchProjectileLogic
        dec     ProjectileUpdateSlot
        bpl     UpdateNextProjectile
        rts

DispatchProjectileLogic:
; Вход: X — слот. Выбирает пять обработчиков по старшей тетраде ProjectileState,X.
; Хвостовой JMP; портит A/Y/ScratchPtr, X сохраняется до входа в обработчик.
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
; то есть двигает на 4 px. Меняет ProjectileX/Y,X; портит A/Y и флаги.
        lda     ProjectileState,x
        and     #DirectionMask
        tay
        jsr     MoveProjectileTwoPixels
        lda     ProjectileFlags,x
        and     #$01
        beq     FinishActiveProjectileStep
        jsr     MoveProjectileTwoPixels
FinishActiveProjectileStep:
LE062:  rts

; Один шаг снаряда X на 2 px. Вход: Y — direction 0..3; меняет ProjectileX/Y,X, портит A и флаги.
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
; ненулевые промежуточные фазы получают таймер 3, последняя переходит в state=0. Меняет ProjectileState,X; портит A/флаги.
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
; InitializeProjectileFlagsForVariant; портит A/Y и флаги.
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
; Вход: A=attributes&$F0, X — слот. $60 даёт flags=3; $C0 и ненулевые классы без bit7 — flags=1.
; Ноль и остальные классы с bit7 оставляют предварительно очищенный ProjectileFlags,X без изменения.
DecodeProjectileFlagsFromAttributes:
LE0C0:
        beq     FinishProjectileInitialization
        cmp     #$C0
        beq     StoreNormalProjectileFlagsValue
        cmp     #$60
        beq     SetStrongProjectileFlags
        and     #$80
        bne     FinishProjectileInitialization
StoreNormalProjectileFlagsValue:
LE0CE:  lda     #$01
        sta     ProjectileFlags,x
        rts

SetStrongProjectileFlags:
LE0D3:  lda     #$03
        sta     ProjectileFlags,x
FinishProjectileInitialization:
LE0D7:  rts

DrawProjectiles:
; Отрисовывает все 10 слотов снарядов от 9 до 0. Выход: ProjectileDrawSlot=$FF;
; портит A/X/Y, ScratchPtr, render/OAM scratch и OAM shadow.
LE0D8:  lda     #(ProjectileSlotCount-1)
        sta     ProjectileDrawSlot
DrawNextProjectile:
LE0DC:  ldx     ProjectileDrawSlot
        jsr     DispatchProjectileDraw
        dec     ProjectileDrawSlot
        bpl     DrawNextProjectile
        rts

DispatchProjectileDraw:
; Вход: X — слот. Диспетчер по старшей тетраде ProjectileState,X; хвостовой JMP, портит A/Y/ScratchPtr.
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
; Портит A/X/Y и projectile RAM.
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
LE136:  lda     ObjectAttributes,x
        and     #$C0
        cmp     #$40
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

; При $0100=0 обходит врагов X=7..2. Каждый активный танк с вероятностью 1/32 пытается выстрелить.
; Портит A/X/Y, RNG и projectile RAM; при ненулевом $0100 ничего не меняет.
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

; Рисует объект усиления в PowerUpX/Y. При нулевом
; PowerUpPickupDisplayTimer он мигает по FrameCounter&8, а код спрайта равен
; $81+4*PowerUpType. При ненулевом таймере обратно отсчитывает его и рисует
; код $3B; по достижении 0 скрывает объект, обнуляя PowerUpX.
; Меняет таймер, PowerUpX, SpriteBehindTerrainMask, ScratchPtr, $00,
; $04/OamTile, OamBufferPos, $47/$48, $54/$55 и OAM shadow; портит A/X/Y,
; восстанавливает SpriteBehindTerrainMask=$20 после отрисовки.
.include "battle_effects.s"
.include "tank_spawn.s"

PowerUpEffect1:
; Вход: X — слот подобравшего. Для игрока X<2 ставит EnemyFreezeTimer=$0A;
; для X>=2 — оба PlayerStunTimer=$C8.
; Портит A и флаги; X/Y не меняет.
LE3B8:  cpx     #FirstEnemyTankSlot
        bcs     ApplyPowerUpEffect1ToEnemyCollector
        lda     #$0A
        sta     EnemyFreezeTimer
        rts

ApplyPowerUpEffect1ToEnemyCollector:
LE3C2:  lda     #$C8
        sta     PlayerStunTimer
        sta     PlayerStunTimer+1
        rts
; Инициализирует $0101/$0102 значением $20, если $46 отрицателен либо в его
; неотрицательном значении установлен bit5; иначе записывает 0.
; Выход: A — записанное значение; X/Y и остальная RAM не меняются.
InitializePlayerVariantAttributes:
LE3C9:  lda     GameVariant
        bpl     MaskPlayerVariantAttribute
        lda     #$20
MaskPlayerVariantAttribute:
LE3CF:  and     #$20
        sta     PlayerUpgradeLevel
        sta     PlayerUpgradeLevel+1
        rts

; Выбирает одну из строк TankVariantLabels по $46, записывает её адрес в AuxPtr и растрирует по $56/$57.
; Значения 0..6 выбирают TANK A..G, $80..$86 — TANK H..N. Портит A/X/Y/AuxPtr, $56/$5F и nametable shadow.
DrawVariantTitleData:
LE3D8:  lda     #$E5
        sta     AuxPtrHi
        lda     GameVariant
        asl     a
        bcc     ComputeVariantTitleOffset
        clc
        adc     #$0E
ComputeVariantTitleOffset:
LE3E4:  asl     a
        asl     a
        clc
        adc     #$70
        sta     AuxPtrLo
        jsr     RasterizeTileStringToShadow
        rts

; Переводит танк X в state=$73 и очищает его extension $0170,X. Выход: A=0; X/Y не меняются.
DestroyTankAndClearExtension:
LE3EF:  lda     #TankStateDestroyed
        sta     ObjectState,x
        lda     #$00
        sta     ObjectSpecialState,x
        rts

; Сохранённый байт между RTS и следующим entry point; статических ссылок нет.
UnreferencedE3f9Byte:
LE3F9:  .byte   $03
; Объединяет входные биты A с ObjectAttributes,X. Единственная специальная комбинация $E7 заменяется на $E4.
; Записывает результат, обнуляет ObjectFrame,X; выход A=0, X/Y сохраняются.
MergeTankAttributeBits:
LE3FA:  ora     ObjectAttributes,x
        cmp     #$E7
        bne     StoreMergedTankAttributes
        lda     #$E4
StoreMergedTankAttributes:
LE402:  sta     ObjectAttributes,x
        lda     #$00
        sta     ObjectFrame,x
        rts
ClearProjectileStates:
; Обнуляет ProjectileState всех 10 слотов. Выход: A=0, X=$FF; Y и остальные поля снарядов не меняются.
LE409:  ldx     #(ProjectileSlotCount-1)
        lda     #$00
ClearNextProjectileState:
LE40D:  sta     ProjectileState,x
        dex
        bpl     ClearNextProjectileState
        rts

ClearTankStates:
; Обнуляет ObjectState и восемь байтов от PlayerIceState. Только первые два
; принадлежат игрокам; следующие шесть перекрывают transition/debug RAM и служат общим сбросом.
; Выход: A=0, X=$FF; Y и остальные поля не меняются.
LE413:  lda     #$00
        ldx     #(TankSlotCount-1)
ClearNextTankState:
LE417:  sta     ObjectState,x
        sta     PlayerIceState,x
        dex
        bpl     ClearNextTankState
        rts

; Заменяет старшую тетраду ObjectState, сохраняя направление в младшей.
SetTankStateClass:
; Вход: A — новые биты класса (обычно старшая тетрада), X — слот. Выход: A — новый ObjectState;
; портит TankStateClassCandidate и флаги, X/Y не меняет. Вход A здесь не маскируется.
LE420:  sta     TankStateClassCandidate
        lda     ObjectState,x
        and     #$0F
        ora     TankStateClassCandidate
        sta     ObjectState,x
        rts

; Семь записей по 3 байта: word-указатель на первую карту и число карт.
; Для режимов 0..5 доступны группы по 12 классических карт; режим 6 использует все 36.
; Последний $8B не входит в семь описателей; его смысл не установлен.
ClassicLevelSetDescriptors:
LE42B:  .word   ClassicLevels
        .byte   12
        .word   ClassicLevels + 12 * 91
        .byte   12
        .word   ClassicLevels + 24 * 91
        .byte   12
        .word   ClassicLevels
        .byte   12
        .word   ClassicLevels + 12 * 91
        .byte   12
        .word   ClassicLevels + 24 * 91
        .byte   12
        .word   ClassicLevels
        .byte   36
        .byte   $8B
; Статически неиспользуемый копировщик: переносит три байта из TankVariantLabels+9+Y в $8C..$8E.
; Вход: Y — offset; выход: A — третий байт. X/Y не меняет; флаги по последнему LDA.
CopyThreeVariantLabelBytes:
LE441:  lda     TankVariantLabels+9,y
        sta     RuntimeChecksumExpected
        lda     TankVariantLabels+10,y
        sta     RuntimeChecksumActual
        lda     TankVariantLabels+11,y
        sta     AllPowerUpsEnabled
        rts
; Преобразует первый установленный бит Right/Left/Down/Up в направление 3/1/2/0.
DecodeDirectionButtons:
; Вход: A — байт кнопок. Приоритет Right, Left, Down, Up. Выход: A=direction 3/1/2/0 или $FF, если D-pad не нажат.
; X/Y/RAM не меняет; флаги соответствуют A.
LE451:  asl     a
        bcc     TestLeftDirectionButton
        lda     #DIRECTION_RIGHT
        rts

TestLeftDirectionButton:
LE457:  asl     a
        bcc     TestDownDirectionButton
        lda     #DIRECTION_LEFT
        rts

TestDownDirectionButton:
LE45D:  asl     a
        bcc     TestUpDirectionButton
        lda     #DIRECTION_DOWN
        rts

TestUpDirectionButton:
LE463:  asl     a
        bcc     ReturnNoDirectionButton
        lda     #DIRECTION_UP
        rts

ReturnNoDirectionButton:
LE469:  lda     #$FF
        rts

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
LE47E:  .byte   $A0,$A0,$A2,$A2,$A2,$A2,$A2,$A2
; Восемнадцать состояний $A0..$A3, используемых ИИ для выбора направления.
TankAiDirectionStateTable:
LE486:  .byte   $A0,$A0,$A0,$A1,$A0,$A3,$A2,$A2
        .byte   $A2,$A1,$A0,$A3,$A1,$A0,$A3,$A1
        .byte   $A2,$A3

; Таблицы адресов обработчиков танков. Индекс — удвоенная старшая тетрада ObjectState;
; выбор между логикой и отрисовкой делает вызывающий диспетчер.
TankLogicHandlers:
LE498:  .word   TankLogicState0
        .word   TankLogicStates1To7,TankLogicStates1To7,TankLogicStates1To7
        .word   TankLogicStates1To7,TankLogicStates1To7,TankLogicStates1To7,TankLogicStates1To7
        .word   TankLogicState8,TankLogicState9,TankLogicStateA,TankLogicStateB
        .word   TankLogicStateC,TankLogicStateD,TankLogicStateE,TankLogicStateF
TankDrawHandlers:
LE4B8:  .word   TankDrawState0,DrawTankState1,DrawTankState2
        .word   DrawTankStates3To4,DrawTankStates3To4
        .word   DrawTankStates5To7,DrawTankStates5To7,DrawTankStates5To7
        .word   DrawTankStates8ToD,DrawTankStates8ToD,DrawTankStates8ToD
        .word   DrawTankStates8ToD,DrawTankStates8ToD,DrawTankStates8ToD
        .word   DrawTankStatesEToF,DrawTankStatesEToF
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

; Два сохранённых байта после RTS и перед отдельным entry point $E54F.
; Статических ссылок на $E54D нет; исполняемым блоком не классифицируются.
UnreferencedE54dBytes:
LE54D:  .byte   $E0,$A0
; Статически неиспользуемый вход: объединяет байт TankLevels+$56+Y с ObjectAttributes,X и обнуляет ObjectFrame,X.
; Вход: X — слот, Y — смещение; выход: A — новые attributes. Формат исходного байта не установлен.
ApplyLevelByteToTankAttributesStub:
LE54F:  lda     TankLevels+$56,y
        ora     ObjectAttributes,x
        sta     ObjectAttributes,x
        lda     #$00
        sta     ObjectFrame,x
        rts
; Начинает сканирование сборщиков усиления в collision-модуле. При
; GameVariant>7 ставит PowerUpCollectorSlot=7, иначе 1,
; затем хвостовым JMP переходит к CheckPowerUpTankOverlap. Для штатных диапазонов $46 это даёт
; проверку слотов 7..0 в расширенных вариантах и 1..0 в обычных.
; Портит A/X/Y/ScratchPtr и collision work RAM по контракту хвоста.
BeginPowerUpCollectorScan:
LE55B:  lda     #$07
        cmp     GameVariant
        bcc     StorePowerUpCollectorScanStart
        lda     #$01
StorePowerUpCollectorScanStart:
LE563:  sta     PowerUpCollectorSlot
        jmp     CheckPowerUpTankOverlap

; Для слотов игроков X=0/1 прибавляет подготовленные цифры $35..$3B к счёту; для врагов ничего не делает.
; При сложении портит A/X/Y и запись счёта выбранного игрока.
AddPreparedScoreForPlayerSlot:
LE568:  cpx     #FirstEnemyTankSlot
        bcs     FinishPreparedScoreAward
        jsr     AddScoreDigitsToRecord
FinishPreparedScoreAward:
LE56F:  rts

; 14 фиксированных 8-байтных тайловых строк "TANK A".."TANK N", каждая с двумя $FF.
; DrawVariantTitleData выбирает их по двум диапазонам $46; CopyThreeVariantLabelBytes читает три байта из середины.
TankVariantLabels:
        .byte   $54,$41,$4E,$4B,$20,$41,$FF,$FF
        .byte   $54,$41,$4E,$4B,$20,$42,$FF,$FF
        .byte   $54,$41,$4E,$4B,$20,$43,$FF,$FF
        .byte   $54,$41,$4E,$4B,$20,$44,$FF,$FF
        .byte   $54,$41,$4E,$4B,$20,$45,$FF,$FF
        .byte   $54,$41,$4E,$4B,$20,$46,$FF,$FF
        .byte   $54,$41,$4E,$4B,$20,$47,$FF,$FF
        .byte   $54,$41,$4E,$4B,$20,$48,$FF,$FF
        .byte   $54,$41,$4E,$4B,$20,$49,$FF,$FF
        .byte   $54,$41,$4E,$4B,$20,$4A,$FF,$FF
        .byte   $54,$41,$4E,$4B,$20,$4B,$FF,$FF
        .byte   $54,$41,$4E,$4B,$20,$4C,$FF,$FF
        .byte   $54,$41,$4E,$4B,$20,$4D,$FF,$FF
        .byte   $54,$41,$4E,$4B,$20,$4E,$FF,$FF
EditionYearText:
        .byte   $31,$39,$39,$30,$FF
; Девять значений и терминатор $FF непосредственно в пуле тайловых строк.
; Последовательность совместима с их форматом, но статических указателей на
; $E5E5 нет; назначение и предполагаемое изображение не устанавливаются.
UnreferencedTileSequenceE5e5:
LE5E5:  .byte   $01,$0F,$02,$00,$00,$C8,$CA,$00,$00,$FF
; Горизонтальный разделитель variant-меню: два вызова из RunVariantSelectionMenu
; выводят эту строку на строках 1 и 4. Формат — 20 тайлов $5C и терминатор $FF.
VariantMenuDividerText:
LE5EF:  .byte   $5C,$5C,$5C,$5C,$5C,$5C,$5C,$5C
        .byte   $5C,$5C,$5C,$5C,$5C,$5C,$5C,$5C
        .byte   $5C,$5C,$5C,$5C,$FF
