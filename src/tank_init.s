; Инициализация активного состояния танка ($E4EC-$E55A).
; Файл включается из projectiles.s в исходной позиции для сохранения адресов ROM.

InitialPlayerShieldTimer          = $03
LateEnemyAttributeDistributionFirstStage = 12
EnemyAttributeFourEntryIndexMask = $03
EnemyAttributeEightEntryIndexMask = $07

; Завершает spawn-переход и заполняет активное состояние танка.
; Вход: X=slot 0..7; ObjectAttributes,X обычно заранее обнулён SpawnTank, но
; альтернативный spawn может оставить предустановленные bits. Без bounds-check
; читает InitialTankStateBySlot[X]: игроки 0/1 становятся $A0 (Up), враги 2..7
; — $A2 (Down).
;
; Игроку записывает shield timer=3, объединяет PlayerUpgradeLevel,X с исходными
; attributes через OR и обнуляет animation frame; RNG не вызывается. Shield
; timer затем уменьшается UpdatePlayerShieldEffects только на FrameCounter mod64=0.
;
; Враг всегда делает ровно три последовательных NextRandomByte: для type,
; carrier и дополнительных hit points. Это отдельные продвижения одного PRNG,
; поэтому статистическая независимость результатов здесь не предполагается.
; Маски и кратности таблиц дают следующие номинальные распределения при
; равномерных младших RNG-битах:
;   type: index random&3 -> $80/$A0/$C0/$E0, по одной записи каждого типа;
;   StageNumber < 12:
;     carrier index random&7 -> bit2 в 2 из 8 записей;
;     HP index random&3 -> {0:2/4, 1:1/4, 2:1/4};
;   StageNumber >= 12:
;     carrier index random&3 -> bit2 в 2 из 4 записей;
;     HP index random&7 -> {0:4/8, 1:3/8, 2:1/8}.
; Все три значения OR-ятся с исходными attributes, а не заменяют их; указанные
; распределения итогового байта верны только если соответствующие входные bits
; были нулевыми, как после штатного SpawnTank.
;
; Выход: ObjectState,X и ObjectFrame,X=0, A=0, Z=1/N=0, X сохранён. Для игрока
; входной Y сохраняется; для врага Y равен финальному HP-index 0..3 до stage 12
; либо 0..7 начиная со stage 12. Меняет attributes выбранного slot, shield timer
; игрока либо RandomState/RandomIndex врага. PPU/OAM/audio, координаты и другие
; slots не меняет.
InitializeTankState:
LE4EC:  lda     InitialTankStateBySlot,x
        sta     ObjectState,x
        cpx     #FirstEnemyTankSlot
        bcs     InitializeEnemyTankAttributes
        lda     #InitialPlayerShieldTimer
        sta     PlayerShieldTimer,x
        lda     PlayerUpgradeLevel,x
        ora     ObjectAttributes,x
        sta     ObjectAttributes,x
        lda     #$00
        sta     ObjectFrame,x
        rts

InitializeEnemyTankAttributes:
        ; Первый RNG-byte всегда выбирает один из четырёх sprite/type classes.
LE505:  jsr     NextRandomByte
        and     #EnemyAttributeFourEntryIndexMask
        tay
        lda     EnemyTypeAttributeBits,y
        ora     ObjectAttributes,x
        sta     ObjectAttributes,x
        lda     StageNumber
        cmp     #LateEnemyAttributeDistributionFirstStage
        bcc     SelectEarlyStageCarrierAttributeIndex
        jsr     NextRandomByte
        and     #EnemyAttributeFourEntryIndexMask
        jmp     ApplyEnemyCarrierAttributeBits

SelectEarlyStageCarrierAttributeIndex:
LE520:  jsr     NextRandomByte
        and     #EnemyAttributeEightEntryIndexMask
ApplyEnemyCarrierAttributeBits:
LE525:  tay
        lda     EnemyPowerUpCarrierAttributeBits,y
        ora     ObjectAttributes,x
        sta     ObjectAttributes,x
        lda     StageNumber
        cmp     #LateEnemyAttributeDistributionFirstStage
        bcc     SelectEarlyStageHitPointAttributeIndex
        jsr     NextRandomByte
        and     #EnemyAttributeEightEntryIndexMask
        jmp     ApplyEnemyHitPointAttributeBits

SelectEarlyStageHitPointAttributeIndex:
LE53B:  jsr     NextRandomByte
        and     #EnemyAttributeFourEntryIndexMask
ApplyEnemyHitPointAttributeBits:
LE540:  tay
        lda     EnemyHitPointAttributeBits,y
        ora     ObjectAttributes,x
        sta     ObjectAttributes,x
        lda     #$00
        sta     ObjectFrame,x
        rts

; Два сохранённых байта после RTS и перед отдельным entry point $E54F.
; Статических ссылок на $E54D нет; исполняемым блоком не классифицируются.
UnreferencedE54dBytes:
LE54D:  .byte   $E0,$A0

; Статически неиспользуемый вход: читает байт упакованных level-данных по
; TankLevels+$56+Y, объединяет его с ObjectAttributes,X и обнуляет frame.
; Намеренная связь level-byte с tank attributes не установлена; bounds-check Y
; отсутствует. Вход: X=slot 0..7, Y=смещение. Выход: A=0, Z=1/N=0, X/Y
; сохранены. Меняет только ObjectAttributes,X и ObjectFrame,X; PPU/OAM/RNG
; не трогает.
ApplyLevelByteToTankAttributesStub:
LE54F:  lda     TankLevels+$56,y
        ora     ObjectAttributes,x
        sta     ObjectAttributes,x
        lda     #$00
        sta     ObjectFrame,x
        rts
