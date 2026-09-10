; Заключительная часть кода и векторы ($FCFC-$FFFF).

.segment "PRG1_HI": absolute

; Проверка использует абсолютную индексацию с X=5/4, поэтому её база на
; четыре байта ниже RuntimeChecksumExpected.
IntegrityWorkBase = RuntimeChecksumExpected - $04

; Локальные роли $5A в непересекающихся проходах high-bank.
PowerUpTargetSlot    = $5A
ExtensionObjectSlot = $5A
TerrainObjectSlot   = $5A

; $FCFC..$FCFF — хвост неидентифицированного потока данных; статических ссылок нет.
HiBankPrefixData:
        .byte   $20,$D2,$0D,$2D
; Два завершённых $FF тайловых текста пункта меню. Точный читаемый текст зависит от CHR.
MenuOptionText0:
        .byte   $30,$31,$5D,$31,$34,$FF
MenuOptionText1:
        .byte   $31,$35,$5D,$32,$38,$FF

; Выводит один из двух текстов пункта меню в позицию (21,3) и ждёт кадр.
; Вход: AllPowerUpsEnabled=0/!=0 выбирает MenuOptionText0/1. Портит
; ScratchPtr, A, X, Y;
; QueueTileAtCoordinates/WaitForNextFrame меняют PPU-очередь и кадровое состояние.
DrawSelectedMenuOption:
LFD0C:  lda     AllPowerUpsEnabled
        bne     LFD14
        lda     #<MenuOptionText0
        beq     LFD16
LFD14:  lda     #<MenuOptionText1
LFD16:  sta     ScratchPtrLo
        lda     #$FD
        sta     ScratchPtrHi
        ldx     #$15
        ldy     #$03
        jsr     QueueTileAtCoordinates
        jsr     WaitForNextFrame
        rts

; Помещает переданный в ScratchPtr тайловый текст в столбец 11 меню.
; Строка вычисляется из $46: 9+$46 для неотрицательных значений, 16+($46 & $0F) для отрицательных.
; Портит A, X, Y и PPU-очередь.
QueueVariantMenuText:
LFD27:  ldx     #$0B
        lda     GameVariant
        clc
        bpl     LFD32
        and     #$0F
        adc     #$07
LFD32:  adc     #$09
        tay
        jsr     QueueTileAtCoordinates
        rts

; Данные $FD39..$FD45 без статических ссылок; назначение не установлено.
UnreferencedFd39Data:
        .byte   $9D,$DD,$DD,$DD,$86,$DD,$DD,$9D
        .byte   $DD,$DD,$D9,$99,$DD

; Выбирает начальное число жизней по состоянию меню/ввода.
; Выход: A=$15 при TitleSecretInputCode=$0F, $08 при Down, $0B при Up, иначе $03.
; RAM не меняет; X/Y сохраняет.
SelectInitialLifeCount:
LFD46:  lda     TitleSecretInputCode
        cmp     #$0F
        bne     LFD4F
        lda     #$15
        rts

LFD4F:  lda     Joy1Held
        and     #BUTTON_DOWN
        beq     LFD58
        lda     #$08
        rts

LFD58:  lda     Joy1Held
        and     #BUTTON_UP
        beq     LFD61
        lda     #$0B
        rts

LFD61:  lda     #$03
        rts

; Секретная комбинация продолжения: P1 A и P2 A+B. Если один из игроков выбыл,
; восстанавливает ему 3 жизни, включает двух игроков и GameMode=$07.
; Всегда переходит в SelectStage; портит A и флаги.
HandleSecretContinueChord:
LFD64:  lda     Joy1Held
        and     #BUTTON_A
        beq     LFD91
        lda     Joy2Held
        and     #BUTTON_B
        beq     LFD91
        lda     Joy2Held
        and     #BUTTON_A
        beq     LFD91
        lda     Player1Lives
        bne     LFD81
        lda     #$03
        sta     Player1Lives
        bne     LFD89
        nop
LFD81:  lda     Player2Lives
        bne     LFD91
        lda     #$03
        sta     Player2Lives
LFD89:  lda     #$01
        sta     MenuSelection
        lda     #$07
        sta     GameMode
LFD91:  jmp     SelectStage

; Отложенная проверка runtime-контрольной суммы.
; При StageNumber<26 и в большинстве кадров только вызывает
; UpdateHalfSecondPhaseFlag. Начиная с 26-го этапа с вероятностью 1/8
; сравнивает RuntimeChecksumActual с RuntimeChecksumExpected. При несовпадении
; переходит по ScratchPtr.
; Важно: этот путь не возвращается к вызывающему коду. Возвращающийся путь
; Портит A; при выполнении сравнения оставляет X=4, иначе X сохраняется.
; При StageNumber>=26 может также изменить состояние RNG.
MaybeEnforceRuntimeChecksum:
LFD94:
        lda     StageNumber
        cmp     #$1A
        bcc     LFDAD
        jsr     NextRandomByte
        and     #$0E
        bne     LFDAD
        ldx     #$05
        lda     IntegrityWorkBase,x
        dex
        cmp     IntegrityWorkBase,x
        beq     LFDAD
        jmp     (ScratchPtrLo)

LFDAD:  jsr     UpdateHalfSecondPhaseFlag
        rts

; Адаптер для слотов игроков: при X<2 записывает $0A в $0100 и возвращается;
; при X>=2 проваливается в PowerUpEffect2. Портит A и флаги.
InitializePlayerExtensionOrApplyEffect2:
LFDB1:  cpx     #FirstEnemyTankSlot
        bcs     LFDBB
        lda     #$0A
        sta     EnemyFreezeTimer
        rts

; Вход: X — слот подобравшего усиление. Для X>=2 заменяет три блока вокруг базы и
; обнуляет атрибуты через QueueBrickBaseAttributes. Для X<2 при активном
; BattleState обновляет стальное ограждение и ставит BaseFortificationTimer=$14.
; Портит ScratchPtr, A, X, Y; меняет nametable shadow и PPU-очередь через
; вызываемые процедуры. Ветка противника не возвращается самостоятельно, а
; хвостовым переходом возвращается из QueueBrickBaseAttributes.
PowerUpEffect2:
LFDBB:  cpx     #FirstEnemyTankSlot
        bcc     LFDEF
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$6D
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$19
        jsr     QueueTileAtCoordinates
        lda     #$E5
        sta     ScratchPtrHi
        lda     #$E8
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$1A
        jsr     QueueTileAtCoordinates
        lda     #$D2
        sta     ScratchPtrHi
        lda     #$99
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$1B
        jsr     QueueTileAtCoordinates
        jmp     QueueBrickBaseAttributes

LFDEF:  lda     BattleState
        bpl     LFDFA
        jsr     DrawSteelBaseEnclosure
        lda     #$14
        sta     BaseFortificationTimer
LFDFA:  rts

; Обработчик эффекта 3. Для X>=2 ставит bit3 в ObjectAttributes слотов 2..7.
; Для X<2 увеличивает PlayerUpgradeLevel,X на $20 до предела $60 и зеркалит
; его в ObjectAttributes,X. Сохраняет исходный X и Y; портит A и флаги.
ApplyPowerUpEffect3:
LFDFB:  cpx     #FirstEnemyTankSlot
        bcc     LFE12
        txa
        pha
        ldx     #(TankSlotCount-1)
LFE03:  lda     ObjectAttributes,x
        ora     #$08
        sta     ObjectAttributes,x
        nop
        dex
        cpx     #$01
        bne     LFE03
        pla
        tax
        rts

LFE12:  lda     PlayerUpgradeLevel,x
        cmp     #$60
        bcs     LFE21
        clc
        adc     #$20
        sta     PlayerUpgradeLevel,x
        sta     ObjectAttributes,x
LFE21:  rts

; Поражает танки противоположной стороны: для X<2 — слоты 2..7, для X>=2 — игроков 0..1,
; если их ObjectState активен. Записывает TankStateDestroyed, attributes=0;
; для игроков также PlayerUpgradeLevel=$20.
; Запрашивает аудиопоток уничтожения танка. X сохраняет; портит A/Y,
; PowerUpTargetSlot и флаги.
PowerUpEffect4:
LFE22:  cpx     #FirstEnemyTankSlot
        bcc     LFE51
        lda     #$01
        sta     PowerUpTargetSlot
        sta     TankDestructionAudioState
LFE2D:  ldy     PowerUpTargetSlot
        lda     ObjectState,y
        bpl     LFE4C
        cmp     #NonTargetableTankStateMin
        bcs     LFE4C
        lda     PlayerStunTimer,y
        bne     LFE4C
        lda     #$20
        sta     PlayerUpgradeLevel,y
        lda     #TankStateDestroyed
        sta     ObjectState,y
        lda     #$00
        sta     ObjectAttributes,y
LFE4C:  dec     PowerUpTargetSlot
        bpl     LFE2D
        rts

LFE51:  lda     #(TankSlotCount-1)
        sta     PowerUpTargetSlot
        lda     #AudioStateStartRequested
        sta     TankDestructionAudioState
LFE5A:  ldy     PowerUpTargetSlot
        lda     ObjectState,y
        bpl     LFE6F
        cmp     #NonTargetableTankStateMin
        bcs     LFE6F
        lda     #TankStateDestroyed
        sta     ObjectState,y
        lda     #$00
        sta     ObjectAttributes,y
LFE6F:  dec     PowerUpTargetSlot
        lda     PowerUpTargetSlot
        cmp     #$01
        bne     LFE5A
        rts

; Для игрока X<2 добавляет жизнь и запрашивает два аудиопотока звука
; дополнительной жизни. Для X>=2 преобразует
; младшие биты ObjectAttributes всех слотов 2..7. Сохраняет исходный X; портит A и флаги.
PowerUpEffect5:
LFE78:  cpx     #FirstEnemyTankSlot
        bcs     LFE87
        inc     Player1Lives,x
        lda     #AudioStateStartRequested
        sta     ExtraLifePulse1AudioState
        sta     ExtraLifePulse2AudioState
        rts

LFE87:  txa
        pha
        ldx     #(TankSlotCount-1)
LFE8B:  lda     ObjectAttributes,x
        ora     #$03
        eor     #$04
        sta     ObjectAttributes,x
        dex
        cpx     #$01
        bne     LFE8B
        pla
        tax
        rts

; Устанавливает ObjectAttributes,X=$63; для игроков X<2 также зеркалит $63 в $0101,X.
; Выход: A=$63; X/Y и остальная RAM не меняются.
SetMaximumObjectUpgrade:
LFE9B:  lda     #$63
        cpx     #FirstEnemyTankSlot
        bcs     LFEA4
        sta     PlayerUpgradeLevel,x
LFEA4:  sta     ObjectAttributes,x
        rts

; Активирует дополнительную способность объекта X через $0170,X=$FF.
; Наблюдаемые эффекты: дополнительная двухспрайтовая метка, проход через TSA $12
; и поглощение следующего попадания с очисткой флага. Точное игровое имя не
; закреплено. Выход: A=$FF; X/Y и остальные поля сохраняет.
PowerUpEffect7:
LFEA7:  lda     #$FF
        sta     ObjectSpecialState,x
        rts

; Послекадровый проход расширения Tank 1990.
; Для каждого слота 7..0 с ненулевым $0170,X рисует двухспрайтовый объект
; с координатами танка и кодом $63,
; затем запускает integrity guard и обрабатывает передачу жизни между игроками.
; Портит A, X, Y, RenderAttributes, OamTile, ExtensionObjectSlot и рабочие поля
; вызываемых процедур; может изменить Player*Lives.
UpdateTank1990Extensions:
LFEAD:  lda     #(TankSlotCount-1)
        sta     ExtensionObjectSlot
LFEB1:  ldx     ExtensionObjectSlot
        lda     ObjectSpecialState,x
        nop
        nop
        beq     LFEC9
        txa
        sta     RenderAttributes
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        lda     #$63
        sta     OamTile
        jsr     EmitTwoTileOamPair
LFEC9:  dec     ExtensionObjectSlot
        bpl     LFEB1
        jsr     RunDeferredIntegrityGuard
        lda     MenuSelection
        beq     LFF04
        lda     Player2Lives
        beq     LFEEF
        cmp     #$02
        bcc     LFF04
        lda     Player1Lives
        bne     LFF04
        lda     Joy1Held
        and     #BUTTON_A
        beq     LFF04
        inc     Player1Lives
        dec     Player2Lives
        ldx     #$00
        jmp     SpawnTank

LFEEF:  lda     Player1Lives
        cmp     #$02
        bcc     LFF04
        lda     Joy2Held
        and     #BUTTON_A
        beq     LFF04
        inc     Player2Lives
        dec     Player1Lives
        ldx     #$01
        jmp     SpawnTank

LFF04:  rts

; Маршрутизация первой проверки TSA при движении.
; Вход: A — код TSA первой точки, TerrainObjectSlot — слот объекта. X на входе
; не используется. При ObjectSpecialState слота !=0 код $12 считается проходимым;
; в остальных случаях TSA<$20 блокирует движение, TSA>=$20 разрешает проверку
; второй точки. Хвостом уходит в ProbeSecondTankCorner либо
; HandleBlockedTankMovement и самостоятельно не возвращается. Портит A/X и флаги;
; Y сохраняется до выбранного обработчика.
RouteFirstTerrainProbe:
LFF05:  pha
        nop
        nop
        nop
        nop
        nop
        ldx     TerrainObjectSlot
        lda     ObjectSpecialState,x
        nop
        nop
        nop
        beq     RestoreFirstTerrainCode
        pla
        cmp     #$12
        bne     ClassifyFirstTerrainCode
AcceptFirstTerrainProbe:
LFF1A:  jmp     ProbeSecondTankCorner

RestoreFirstTerrainCode:
LFF1D:  pla
ClassifyFirstTerrainCode:
LFF1E:  cmp     #$20
        bcs     AcceptFirstTerrainProbe
        jmp     HandleBlockedTankMovement

; Парный RouteFirstTerrainProbe маршрутизатор второй проверки TSA.
; Контракт и классификация TSA те же, но разрешённый проход хвостом переходит в
; CommitProposedTankMovement. Не возвращается самостоятельно; портит A/X и флаги,
; Y сохраняется до выбранного обработчика.
RouteSecondTerrainProbe:
LFF25:  pha
        nop
        nop
        nop
        nop
        nop
        ldx     TerrainObjectSlot
        lda     ObjectSpecialState,x
        nop
        nop
        nop
        beq     RestoreSecondTerrainCode
        pla
        cmp     #$12
        bne     ClassifySecondTerrainCode
AcceptSecondTerrainProbe:
LFF3A:  jmp     CommitProposedTankMovement

RestoreSecondTerrainCode:
LFF3D:  pla
ClassifySecondTerrainCode:
LFF3E:  cmp     #$20
        bcs     AcceptSecondTerrainProbe
        jmp     HandleBlockedTankMovement

; Сбрасывает 16 байт состояния расширения $0170..$017F, затем вызывает
; InitializeCoreRuntime. После полной инициализации возвращает A=$FC, X=$1C, Y=0;
; почти вся рабочая RAM и состояние PPU/APU могут измениться.
ResetExtensionState:
LFF45:  lda     #$00
        ldx     #$0F
LFF49:  sta     ObjectSpecialState,x
        dex
        bpl     LFF49
        jsr     InitializeCoreRuntime
        rts

; Заполняет ObjectSpecialState+4..+7 и PlayerExtendedUpgrade значением A, затем вызывает
; InitializeCoreRuntime. Входные A/X/Y этой процедурой не сохраняются.
FillExtensionSlots4Through8:
LFF53:  sta     ObjectSpecialState+4
        sta     ObjectSpecialState+5
        sta     ObjectSpecialState+6
        sta     ObjectSpecialState+7
        sta     PlayerExtendedUpgrade
        jsr     InitializeCoreRuntime
        rts
; Обрабатывает попадание снаряда в объект X с нулевым PlayerShieldTimer,X.
; Ненулевой ObjectSpecialState,X поглощается/очищается. Без него объект
; переводится в TankStateDestroyed, кроме PlayerUpgradeLevel,X=$63: тогда
; запрашивается ArmorHitAudioState, а $40 записывается в PlayerUpgradeLevel,
; PlayerExtendedUpgrade и ObjectAttributes. Не возвращается.
HandleProjectileHitOnTank:
LFF66:  lda     ObjectSpecialState,x
        beq     LFF73
        lda     #$00
        sta     ObjectSpecialState,x
        jmp     AdvancePlayerCollisionPassOrBeginEnemyPass

LFF73:  lda     PlayerUpgradeLevel,x
        cmp     #$63
        beq     LFF81
        lda     #TankStateDestroyed
        sta     ObjectState,x
        jmp     ApplyPlayerHitVariantState

LFF81:  lda     #AudioStateStartRequested
        sta     ArmorHitAudioState
        lda     #$40
        sta     PlayerUpgradeLevel,x
        sta     PlayerExtendedUpgrade,x
        sta     ObjectAttributes,x
        jmp     AdvancePlayerCollisionPassOrBeginEnemyPass

; Запрашивает PlayerOrBaseDestructionNoiseAudioState и возвращает в A
; модификатор $20 при отрицательном GameVariant, иначе 0.
; X/Y не меняет; портит флаги.
GetVariantAttributeBits:
LFF93:  lda     #AudioStateStartRequested
        sta     PlayerOrBaseDestructionNoiseAudioState
        lda     GameVariant
        bmi     LFF9F
        lda     #$00
        rts

LFF9F:  lda     #$20
        rts

; Одиночный байт $01 по $FFA2; статических ссылок нет.
UnreferencedFfa2Byte:
        .byte   $01
; Записывает A в ObjectAttributes,X и переходит в общий хвост прохода столкновений.
StoreAttributesAndContinueCollisionPass:
LFFA3:  sta     ObjectAttributes,x
        jmp     AdvancePlayerCollisionPassOrBeginEnemyPass
; Хвост прохода столкновений по игрокам: очищает ObjectSpecialState,X для
; ObjectState=TankStateDestroyed, затем уменьшает TankCollisionSlot (тот же $5A).
; При TankCollisionSlot>=0 переходит к CheckNextPlayerTank, иначе возвращается.
; Портит A, TankCollisionSlot и флаги.
AdvanceTankCollisionPass:
LFFA8:  lda     ObjectState,x
        cmp     #TankStateDestroyed
        bne     LFFB3
        lda     #$00
        sta     ObjectSpecialState,x
LFFB3:  dec     TankCollisionSlot
        bpl     LFFB8
        rts

LFFB8:  jmp     CheckNextPlayerTank

; Очищает дополнительное состояние $0170,X. Выход: A=0; X/Y сохраняются.
ClearObjectExtensionState:
LFFBB:  lda     #$00
        sta     ObjectSpecialState,x
        rts
; Настраивает ProjectileFlags,X по режиму $46 и ObjectAttributes,X.
; В базовом режиме передаёт старшую тетраду атрибутов в
; DecodeProjectileFlagsFromAttributes. В расширенном режиме ($46<0)
; бит $08 или класс $60 дают flags=3, часть прочих ненулевых классов — flags=1. Портит A и флаги.
InitializeProjectileFlagsForVariant:
LFFC1:  lda     GameVariant
        bmi     LFFCC
        lda     ObjectAttributes,x
        and     #$F0
        jmp     DecodeProjectileFlagsFromAttributes

LFFCC:  lda     ObjectAttributes,x
        and     #$08
        beq     LFFD5
        jmp     SetStrongProjectileFlags

LFFD5:  lda     ObjectAttributes,x
        and     #$F0
        beq     LFFF0
        cmp     #$A0
        bcs     LFFE7
        cmp     #$60
        beq     LFFEC
        and     #$80
        bne     LFFF0
LFFE7:  lda     #$01
        sta     ProjectileFlags,x
        rts

LFFEC:  lda     #$03
        sta     ProjectileFlags,x
LFFF0:  rts

; $FFF1..$FFF9 — заполнение $FF перед аппаратными векторами.
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF

; NROM использует ResetHandler и как RESET-, и как IRQ/BRK-вектор.
        .word   NmiHandler
        .word   ResetHandler
        .word   ResetHandler
