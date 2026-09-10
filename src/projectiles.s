; Снаряды, эффекты поля, создание танков и общие таблицы ($E02E-$E603).

TankShadowPtrLo         = $E0
TankShadowPtrHiAndFlags = $E8
BaseSpriteTileOffset    = $69

UpdateProjectiles:
; Обновляет все 10 слотов снарядов от 9 до 0 через DispatchProjectileLogic.
; Выход: $5A=$FF; портит A/X/Y, ScratchPtr и поля снарядов по контракту обработчика.
LE02E:  lda     #(ProjectileSlotCount-1)
        sta     $5A
LE032:  ldx     $5A
        jsr     DispatchProjectileLogic
        dec     $5A
        bpl     LE032
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
        beq     LE062
        jsr     MoveProjectileTwoPixels
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
        bne     LE08B
        lda     ProjectileState,x
        and     #StateClassMask
        sec
        sbc     #$10
        beq     LE089
        ora     #$03
LE089:  sta     ProjectileState,x
LE08B:  rts

; Создаёт снаряд в слоте X, только если ProjectileState,X=0.
; Начальное state=$40|direction; координаты смещены на 8 px от ObjectX/Y,X, flags затем вычисляются по attributes/варианту.
; Для игрока X<2 запрашивает PlayerFireAudioState. Хвостовой JMP в
; InitializeProjectileFlagsForVariant; портит A/Y и флаги.
InitializeProjectileForTank:
LE08C:  lda     ProjectileState,x
        bne     LE0D7
        cpx     #FirstEnemyTankSlot
        bcs     LE099
        lda     #$01
        sta     PlayerFireAudioState
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
        beq     LE0D7
        cmp     #$C0
        beq     LE0CE
        cmp     #$60
        beq     LE0D3
        and     #$80
        bne     LE0D7
LE0CE:  lda     #$01
        sta     ProjectileFlags,x
        rts

SetStrongProjectileFlags:
LE0D3:  lda     #$03
        sta     ProjectileFlags,x
LE0D7:  rts

DrawProjectiles:
; Отрисовывает все 10 слотов снарядов от 9 до 0. Выход: $5A=$FF; портит
; A/X/Y, ScratchPtr, $00, $04/$53, $0D, $47/$48 и OAM shadow.
LE0D8:  lda     #(ProjectileSlotCount-1)
        sta     $5A
LE0DC:  ldx     $5A
        jsr     DispatchProjectileDraw
        dec     $5A
        bpl     LE0DC
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
        sta     $04
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
; Может создать или переложить снаряд; выход: $5A=$FF. Портит A/X/Y и projectile RAM.
UpdatePlayerFiring:
LE122:  lda     #$01
        sta     $5A
LE126:  ldx     $5A
        lda     ObjectState,x
        bpl     LE15D
        cmp     #NonTargetableTankStateMin
        bcs     LE15D
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
        bne     LE15A
        lda     ProjectileState,x
        beq     LE15A
        lda     ProjectileState+8,x
        bne     LE15D
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
LE15A:  jsr     InitializeProjectileForTank
LE15D:  dec     $5A
        bpl     LE126
        rts

; При $0100=0 обходит врагов X=7..2. Каждый активный танк с вероятностью 1/32 пытается выстрелить.
; Портит A/X/Y, RNG и projectile RAM; при ненулевом $0100 ничего не меняет.
UpdateEnemyFiring:
LE162:  lda     EnemyFreezeTimer
        bne     LE180
        ldx     #(TankSlotCount-1)
LE169:  lda     ObjectState,x
        bpl     LE17B
        cmp     #NonTargetableTankStateMin
        bcs     LE17B
        jsr     NextRandomByte
        and     #$1F
        bne     LE17B
        jsr     InitializeProjectileForTank
LE17B:  dex
        cpx     #$01
        bne     LE169
LE180:  rts

; Перед движением помечает в nametable shadow клетки, занятые активными танками 7..0.
; PixelCoordinatesToShadowPointer возвращает указатель для точки (ObjectX-8,ObjectY-8);
; адрес и признаки дополнительных клеток кэшируются в $E0,X/$E8,X.
; Бит 7 тайла служит occupancy-маркером. Для игрока также обновляет bit7
; $0103,X по тайлу $21. Портит A/X/Y/ScratchPtr/$00/$5A.
MarkTankOccupiedTiles:
LE181:  lda     #(TankSlotCount-1)
        sta     $5A
LE185:  ldx     $5A
        lda     ObjectState,x
        bpl     LE1EE
        cmp     #NonTargetableTankStateMin
        bcs     LE1EE
        lda     ObjectY,x
        sec
        sbc     #$08
        tay
        lda     ObjectX,x
        sec
        sbc     #$08
        tax
        jsr     PixelCoordinatesToShadowPointer
        ldx     $5A
        lda     ScratchPtrLo
        sta     TankShadowPtrLo,x
        lda     ScratchPtrHi
        and     #$03
        sta     TankShadowPtrHiAndFlags,x
        ldy     #$21
        cpx     #FirstEnemyTankSlot
        bcs     LE1C9
        lda     (ScratchPtrLo),y
        cmp     #$21
        bne     LE1C1
        lda     #$80
        ora     $0103,x
        sta     $0103,x
        jmp     LE1C9

LE1C1:  lda     $0103,x
        and     #$7F
        sta     $0103,x
LE1C9:  jsr     SetTileOccupiedFlag
        lda     ObjectX,x
        and     #$07
        bne     LE1DD
        lda     TankShadowPtrHiAndFlags,x
        ora     #$80
        sta     TankShadowPtrHiAndFlags,x
        ldy     #$20
        jsr     SetTileOccupiedFlag
LE1DD:  lda     ObjectY,x
        and     #$07
        bne     LE1EE
        lda     TankShadowPtrHiAndFlags,x
        ora     #$40
        sta     TankShadowPtrHiAndFlags,x
        ldy     #$01
        jsr     SetTileOccupiedFlag
LE1EE:  dec     $5A
        bpl     LE185
        rts

; Вход: ScratchPtr+Y — байт nametable shadow. Ставит в нём bit7; портит A и флаги.
SetTileOccupiedFlag:
LE1F3:  lda     (ScratchPtrLo),y
        ora     #$80
        sta     (ScratchPtrLo),y
        rts

; После движения снимает occupancy-bit7 с тех же клеток по кэшу $E0,X/$E8,X. Обходит активные танки 7..0.
; Портит A/X/Y/ScratchPtr/$5A и меняет nametable shadow.
ClearTankOccupiedTiles:
LE1FA:  lda     #(TankSlotCount-1)
        sta     $5A
LE1FE:  ldx     $5A
        lda     ObjectState,x
        bpl     LE22F
        cmp     #NonTargetableTankStateMin
        bcs     LE22F
        lda     TankShadowPtrLo,x
        sta     ScratchPtrLo
        lda     TankShadowPtrHiAndFlags,x
        and     #$03
        ora     #$04
        sta     ScratchPtrHi
        ldy     #$21
        jsr     ClearTileOccupiedFlag
        lda     TankShadowPtrHiAndFlags,x
        and     #$80
        beq     LE224
        ldy     #$20
        jsr     ClearTileOccupiedFlag
LE224:  lda     TankShadowPtrHiAndFlags,x
        and     #$40
        beq     LE22F
        ldy     #$01
        jsr     ClearTileOccupiedFlag
LE22F:  dec     $5A
        bpl     LE1FE
        rts

; Вход: ScratchPtr+Y — байт nametable shadow. Снимает bit7; портит A и флаги.
ClearTileOccupiedFlag:
LE234:  lda     (ScratchPtrLo),y
        and     #$7F
        sta     (ScratchPtrLo),y
        rts

; Рисует объект усиления в PowerUpX/Y. При нулевом
; PowerUpPickupDisplayTimer он мигает по FrameCounter&8, а код спрайта равен
; $81+4*PowerUpType. При ненулевом таймере обратно отсчитывает его и рисует
; код $3B; по достижении 0 скрывает объект, обнуляя PowerUpX.
; Меняет таймер, PowerUpX, SpriteBehindTerrainMask, ScratchPtr, $00,
; $04/OamTile, OamBufferPos, $47/$48, $54/$55 и OAM shadow; портит A/X/Y,
; восстанавливает SpriteBehindTerrainMask=$20 после отрисовки.
DrawAndExpirePowerUp:
LE23B:  lda     PowerUpX
        beq     LE27B
        lda     PowerUpPickupDisplayTimer
        beq     LE259
        dec     PowerUpPickupDisplayTimer
        bne     LE24E
        lda     #$00
        sta     PowerUpX
        jmp     LE27B

LE24E:  lda     #$02
        sta     $04
        lda     #$3B
        sta     OamTile
        jmp     LE26C

LE259:  lda     FrameCounter
        and     #$08
        beq     LE27B
        lda     #$02
        sta     $04
        lda     PowerUpType
        asl     a
        asl     a
        clc
        adc     #$81
        sta     OamTile
LE26C:  ldx     PowerUpX
        ldy     PowerUpY
        lda     #$00
        sta     SpriteBehindTerrainMask
        jsr     EmitTwoTileOamPair
        lda     #$20
        sta     SpriteBehindTerrainMask
LE27B:  rts

; Обходит игроков 1..0 и рисует мигающую защитную анимацию пока $89,X!=0; раз в 64 кадра уменьшает таймер.
; Код кадра $29/$2D выбирается FrameCounter bit1. Выход: $5A=$FF; портит
; A/X/Y, ScratchPtr, $00, $04/$53, $0D, $47/$48, $54/$55, $89..$8A и OAM shadow.
UpdatePlayerShieldEffects:
LE27C:  lda     #$01
        sta     $5A
LE280:  ldx     $5A
        lda     PlayerShieldTimer,x
        beq     LE2A4
        lda     FrameCounter
        and     #$3F
        bne     LE28E
        dec     PlayerShieldTimer,x
LE28E:  lda     #$02
        sta     $04
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        lda     FrameCounter
        and     #$02
        asl     a
        clc
        adc     #$29
        sta     OamTile
        jsr     EmitTwoTileOamPair
LE2A4:  dec     $5A
        bpl     LE280
        rts

; Обновляет таймер укрепления базы $45 и фазу взрыва/поражения базы $68.
; $45 уменьшается раз в 64 кадра; на последних трёх шагах ограждение мигает между сталью и кирпичом.
; Положительный $68 уменьшается каждый вызов и диспетчеризует кадр BaseExplosionFrameHandlers.
; Портит A/X/Y/ScratchPtr, $00-$04, $0D, $47/$48, $54/$55, $69,
; shadow/PPU-очередь и OAM shadow.
UpdateBaseEffects:
LE2A9:  lda     BaseFortificationTimer
        beq     LE2D2
        lda     FrameCounter
        and     #$0F
        bne     LE2D2
        lda     FrameCounter
        and     #$3F
        bne     LE2BD
        dec     BaseFortificationTimer
        beq     LE2CF
LE2BD:  lda     BaseFortificationTimer
        cmp     #$04
        bcs     LE2D2
        lda     FrameCounter
        and     #$10
        beq     LE2CF
        jsr     DrawSteelBaseEnclosure
        jmp     LE2D2

LE2CF:  jsr     DrawBrickBaseEnclosure
LE2D2:  lda     BattleState
        beq     LE305
        bmi     LE305
        lda     #$03
        sta     $04
        dec     BattleState
        lda     BattleState
        lsr     a
        lsr     a
        sec
        sbc     #$05
        bpl     LE2EC
        eor     #$FF
        clc
        adc     #$01
LE2EC:  sec
        sbc     #$05
        bpl     LE2F6
        eor     #$FF
        clc
        adc     #$01
LE2F6:  asl     a
        tay
        lda     BaseExplosionFrameHandlers,y
        sta     ScratchPtrLo
        lda     BaseExplosionFrameHandlers+1,y
        sta     ScratchPtrHi
        jmp     (ScratchPtrLo)

LE305:  rts

BaseExplosionFrameHandlers:
; Шесть обработчиков: no-op, три кадра взрыва, целая и разрушенная композиции базы.
LE306:  .word   NoOpHandler
        .word   DrawBaseExplosionFrame1,DrawBaseExplosionFrame2,DrawBaseExplosionFrame3
        .word   DrawIntactBaseFrame,DrawDestroyedBaseFrame

DrawBaseExplosionFrame1:
LE312:  lda     #$F1
        jmp     LE31E

DrawBaseExplosionFrame2:
LE317:  lda     #$F5
        jmp     LE31E

DrawBaseExplosionFrame3:
LE31C:  lda     #$F9
LE31E:  ldx     #$78
        ldy     #$D8
LE322:  sta     OamTile
        jsr     EmitTwoTileOamPair
        rts

; Прибавляет к номеру кадра A смещение BaseSpriteTileOffset и рисует
; двухспрайтовую пару в X/Y.
DrawBaseSpriteWithOffset:
LE328:  clc
        adc     BaseSpriteTileOffset
        jmp     LE322

; Обнуляет BaseSpriteTileOffset и рисует четыре пары — восемь OAM-спрайтов базы.
; Портит A/X/Y, ScratchPtr, $00, $04/$53/$69, $0D, $47/$48, $54/$55 и OAM shadow.
DrawIntactBaseFrame:
LE32E:  lda     #$00
        sta     BaseSpriteTileOffset
        jsr     DrawBaseSpriteGrid
        rts

; Ставит BaseSpriteTileOffset=$10 и рисует альтернативные четыре пары —
; восемь OAM-спрайтов базы.
DrawDestroyedBaseFrame:
LE336:  lda     #$10
        sta     BaseSpriteTileOffset
        jsr     DrawBaseSpriteGrid
        rts

; Рисует сетку 2x2 двухспрайтовых пар в ($70,$D0)..($80,$E0);
; BaseSpriteTileOffset
; прибавляется к кодам $D1/$D5/$D9/$DD. Портит A/X/Y, ScratchPtr, $00,
; $04/$53, $0D, $47/$48, $54/$55 и OAM shadow; $69 не меняет.
DrawBaseSpriteGrid:
LE33E:  ldx     #$70
        ldy     #$D0
        lda     #$D1
        jsr     DrawBaseSpriteWithOffset
        ldx     #$80
        ldy     #$D0
        lda     #$D5
        jsr     DrawBaseSpriteWithOffset
        ldx     #$70
        ldy     #$E0
        lda     #$D9
        jsr     DrawBaseSpriteWithOffset
        ldx     #$80
        ldy     #$E0
        lda     #$DD
        jsr     DrawBaseSpriteWithOffset
        rts
; Создаёт танк в слоте X в spawn-state $F0. Игроки 0/1 ставятся в PlayerSpawnX/Y; враги циклически используют три EnemySpawnX/Y.
; Обнуляет attributes, для игроков также PlayerStunTimer,X; рисует
; spawn-метатайл $0F.
; Портит A/X/Y, ScratchPtr, $00-$04, $47/$48, $6A для врагов,
; nametable/attribute shadow и PPU-очередь.
SpawnTank:
LE363:  lda     #$00
        sta     ObjectAttributes,x
        cpx     #FirstEnemyTankSlot
        bcs     LE37C
        lda     PlayerSpawnX,x
        sta     ObjectX,x
        lda     PlayerSpawnY,x
        sta     ObjectY,x
        lda     #$00
        sta     PlayerStunTimer,x
        jmp     LE393

LE37C:  inc     EnemySpawnColumn
        ldy     EnemySpawnColumn
        cpy     #$03
        bne     LE389
        lda     #$00
        sta     EnemySpawnColumn
        tay
LE389:  lda     EnemySpawnX,y
        sta     ObjectX,x
        lda     EnemySpawnY,y
        sta     ObjectY,x
LE393:  lda     #TankStateSpawning
        sta     ObjectState,x
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        lda     #$0F
        jsr     DrawMetatile
        rts

; Сохранённый байт между RTS и отдельным альтернативным spawn-entry.
; Статических ссылок на $E3A2 нет; назначение исходного заполнения неизвестно.
UnreferencedE3a2Byte:
LE3A2:  .byte   $04
; Альтернативный spawn entry: вход A записывает в ObjectAttributes,X, обнуляет $86, ставит state=$F0 и рисует spawn-метатайл.
; Статических ссылок нет; портит A/X/Y, ScratchPtr, $00-$04, $47/$48,
; nametable/attribute shadow и PPU-очередь.
SpawnTankWithAttributes:
LE3A3:  sta     ObjectAttributes,x
        lda     #$00
        sta     PowerUpX
        lda     #TankStateSpawning
        sta     ObjectState,x
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        lda     #$0F
        jsr     DrawMetatile
        rts

PowerUpEffect1:
; Вход: X — слот подобравшего. Для игрока X<2 ставит EnemyFreezeTimer=$0A;
; для X>=2 — оба PlayerStunTimer=$C8.
; Портит A и флаги; X/Y не меняет.
LE3B8:  cpx     #FirstEnemyTankSlot
        bcs     LE3C2
        lda     #$0A
        sta     EnemyFreezeTimer
        rts

LE3C2:  lda     #$C8
        sta     PlayerStunTimer
        sta     PlayerStunTimer+1
        rts
; Инициализирует $0101/$0102 значением $20, если $46 отрицателен либо в его
; неотрицательном значении установлен bit5; иначе записывает 0.
; Выход: A — записанное значение; X/Y и остальная RAM не меняются.
InitializePlayerVariantAttributes:
LE3C9:  lda     GameVariant
        bpl     LE3CF
        lda     #$20
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
        bcc     LE3E4
        clc
        adc     #$0E
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
        bne     LE402
        lda     #$E4
LE402:  sta     ObjectAttributes,x
        lda     #$00
        sta     ObjectFrame,x
        rts
ClearProjectileStates:
; Обнуляет ProjectileState всех 10 слотов. Выход: A=0, X=$FF; Y и остальные поля снарядов не меняются.
LE409:  ldx     #(ProjectileSlotCount-1)
        lda     #$00
LE40D:  sta     ProjectileState,x
        dex
        bpl     LE40D
        rts

ClearTankStates:
; Обнуляет ObjectState и $0103 всех 8 танковых слотов. Выход: A=0, X=$FF; Y и остальные поля не меняются.
LE413:  lda     #$00
        ldx     #(TankSlotCount-1)
LE417:  sta     ObjectState,x
        sta     $0103,x
        dex
        bpl     LE417
        rts

; Заменяет старшую тетраду ObjectState, сохраняя направление в младшей.
SetTankStateClass:
; Вход: A — новые биты класса (обычно старшая тетрада), X — слот. Выход: A — новый ObjectState;
; портит $00 и флаги, X/Y не меняет. Вход A здесь не маскируется.
LE420:  sta     $00
        lda     ObjectState,x
        and     #$0F
        ora     $00
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
        sta     $8C
        lda     TankVariantLabels+10,y
        sta     $8D
        lda     TankVariantLabels+11,y
        sta     $8E
        rts
; Преобразует первый установленный бит Right/Left/Down/Up в направление 3/1/2/0.
DecodeDirectionButtons:
; Вход: A — байт кнопок. Приоритет Right, Left, Down, Up. Выход: A=direction 3/1/2/0 или $FF, если D-pad не нажат.
; X/Y/RAM не меняет; флаги соответствуют A.
LE451:  asl     a
        bcc     LE457
        lda     #DIRECTION_RIGHT
        rts

LE457:  asl     a
        bcc     LE45D
        lda     #DIRECTION_LEFT
        rts

LE45D:  asl     a
        bcc     LE463
        lda     #DIRECTION_DOWN
        rts

LE463:  asl     a
        bcc     LE469
        lda     #DIRECTION_UP
        rts

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

; Заполняет начальное состояние объекта. Для врагов дополнительные свойства
; (тип, бонусный флаг и скорость) выбираются псевдослучайно.
InitializeTankState:
; Вход: X — слот. Всегда берёт начальное состояние из InitialTankStateBySlot. Для игроков ставит $89,X=3,
; объединяет $0101,X с attributes и обнуляет frame. Для врагов RNG выбирает три группы битов attributes.
; До этапа 12 вторая таблица индексируется 0..7, третья 0..3; начиная с этапа 12 — наоборот.
; Меняет ObjectState/Attributes/Frame, $89,X для игроков и RNG; портит A/Y, X сохраняет.
LE4EC:  lda     InitialTankStateBySlot,x
        sta     ObjectState,x
        cpx     #FirstEnemyTankSlot
        bcs     LE505
        lda     #$03
        sta     PlayerShieldTimer,x
        lda     PlayerUpgradeLevel,x
        ora     ObjectAttributes,x
        sta     ObjectAttributes,x
        lda     #$00
        sta     ObjectFrame,x
        rts

LE505:  jsr     NextRandomByte
        and     #DirectionMask
        tay
        lda     EnemyTypeAttributeBits,y
        ora     ObjectAttributes,x
        sta     ObjectAttributes,x
        lda     StageNumber
        cmp     #$0C
        bcc     LE520
        jsr     NextRandomByte
        and     #DirectionMask
        jmp     LE525

LE520:  jsr     NextRandomByte
        and     #$07
LE525:  tay
        lda     EnemyBonusAttributeBits,y
        ora     ObjectAttributes,x
        sta     ObjectAttributes,x
        lda     StageNumber
        cmp     #$0C
        bcc     LE53B
        jsr     NextRandomByte
        and     #$07
        jmp     LE540

LE53B:  jsr     NextRandomByte
        and     #DirectionMask
LE540:  tay
        lda     EnemyLowAttributeBits,y
        ora     ObjectAttributes,x
        sta     ObjectAttributes,x
        lda     #$00
        sta     ObjectFrame,x
        rts

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
        bcc     LE563
        lda     #$01
LE563:  sta     PowerUpCollectorSlot
        jmp     CheckPowerUpTankOverlap

; Для слотов игроков X=0/1 прибавляет подготовленные цифры $35..$3B к счёту; для врагов ничего не делает.
; При сложении портит A/X/Y и запись счёта выбранного игрока.
AddPreparedScoreForPlayerSlot:
LE568:  cpx     #FirstEnemyTankSlot
        bcs     LE56F
        jsr     AddScoreDigitsToRecord
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
