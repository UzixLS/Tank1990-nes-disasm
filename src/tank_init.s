; Инициализация активного состояния танка ($E4EC-$E55A).
; Файл включается из projectiles.s в исходной позиции для сохранения адресов ROM.

InitialPlayerShieldTimer          = $03
EnemyAttributeStageThreshold     = 12
EnemyAttributeWideTableIndexMask = $07

; Завершает spawn-переход и заполняет активное состояние танка.
; Вход: X — слот. Начальное состояние берётся из InitialTankStateBySlot.
; Для игроков ставит shield timer=3, OR-ит PlayerUpgradeLevel,X в уже имеющиеся
; attributes и обнуляет frame; RNG не вызывается.
;
; Для противника три независимых RNG-вызова выбирают type $80/$A0/$C0/$E0,
; carrier bit2 и hit points bits0..1. До stage 12 carrier имеет вероятность 2/8,
; HP распределены {0:2/4,1:1/4,2:1/4}; с stage 12 carrier=2/4, HP
; {0:4/8,1:3/8,2:1/8}. Значения OR-ятся с исходными attributes, а не заменяют их.
; Выход: X сохранён, ObjectFrame,X=0; A=0. Y — последний случайный индекс у
; врага, входное Y у игрока сохраняется. Меняет state/attributes выбранного
; объекта, shield timer игрока либо RandomState/RandomIndex для врага;
; PPU/OAM/audio и другие объекты не меняет.
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
LE505:  jsr     NextRandomByte
        and     #DirectionMask
        tay
        lda     EnemyTypeAttributeBits,y
        ora     ObjectAttributes,x
        sta     ObjectAttributes,x
        lda     StageNumber
        cmp     #EnemyAttributeStageThreshold
        bcc     SelectEarlyStageCarrierAttributeIndex
        jsr     NextRandomByte
        and     #DirectionMask
        jmp     ApplyEnemyCarrierAttributeBits

SelectEarlyStageCarrierAttributeIndex:
LE520:  jsr     NextRandomByte
        and     #EnemyAttributeWideTableIndexMask
ApplyEnemyCarrierAttributeBits:
LE525:  tay
        lda     EnemyPowerUpCarrierAttributeBits,y
        ora     ObjectAttributes,x
        sta     ObjectAttributes,x
        lda     StageNumber
        cmp     #EnemyAttributeStageThreshold
        bcc     SelectEarlyStageHitPointAttributeIndex
        jsr     NextRandomByte
        and     #EnemyAttributeWideTableIndexMask
        jmp     ApplyEnemyHitPointAttributeBits

SelectEarlyStageHitPointAttributeIndex:
LE53B:  jsr     NextRandomByte
        and     #DirectionMask
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

; Статически неиспользуемый вход: объединяет байт TankLevels+$56+Y с
; ObjectAttributes,X и обнуляет ObjectFrame,X. Вход: X — слот, Y — смещение;
; выход: A — новые attributes. Формат исходного байта не установлен.
ApplyLevelByteToTankAttributesStub:
LE54F:  lda     TankLevels+$56,y
        ora     ObjectAttributes,x
        sta     ObjectAttributes,x
        lda     #$00
        sta     ObjectFrame,x
        rts
