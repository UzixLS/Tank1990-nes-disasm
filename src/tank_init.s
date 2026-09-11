; Инициализация активного состояния танка ($E4EC-$E55A).
; Файл включается из projectiles.s в исходной позиции для сохранения адресов ROM.

; Заполняет начальное состояние танка. Для противников дополнительные свойства
; выбираются псевдослучайно из таблиц типа, bonus-флага и младших битов
; атрибутов; точная игровая трактовка каждого младшего бита не предполагается.
; Вход: X — слот. Начальное состояние берётся из InitialTankStateBySlot.
; Для игроков ставит PlayerShieldTimer,X=3, объединяет PlayerUpgradeLevel,X с
; attributes и обнуляет frame. Для противников RNG выбирает три группы bits.
; До этапа 12 вторая таблица индексируется 0..7, третья 0..3; затем наоборот.
; Меняет ObjectState/Attributes/Frame, shield timer игроков и RNG;
; портит A/Y, X сохраняет.
InitializeTankState:
LE4EC:  lda     InitialTankStateBySlot,x
        sta     ObjectState,x
        cpx     #FirstEnemyTankSlot
        bcs     InitializeEnemyTankAttributes
        lda     #$03
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
        cmp     #$0C
        bcc     SelectEarlyStageBonusAttributeIndex
        jsr     NextRandomByte
        and     #DirectionMask
        jmp     ApplyEnemyBonusAttributeBits

SelectEarlyStageBonusAttributeIndex:
LE520:  jsr     NextRandomByte
        and     #$07
ApplyEnemyBonusAttributeBits:
LE525:  tay
        lda     EnemyBonusAttributeBits,y
        ora     ObjectAttributes,x
        sta     ObjectAttributes,x
        lda     StageNumber
        cmp     #$0C
        bcc     SelectEarlyStageLowAttributeIndex
        jsr     NextRandomByte
        and     #$07
        jmp     ApplyEnemyLowAttributeBits

SelectEarlyStageLowAttributeIndex:
LE53B:  jsr     NextRandomByte
        and     #DirectionMask
ApplyEnemyLowAttributeBits:
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
