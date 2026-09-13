; Обработчики усилений и улучшений объектов ($FDB1-$FEAC).

PowerUpTargetSlot = $5A
PowerUpEffect2BaseColumn = 12
PowerUpEffect2BlankRow   = 25
PowerUpEffect2UpperRow   = 26
PowerUpEffect2LowerRow   = 27
EnemyUpgradeAttributeBit = $08
ObjectSpecialStateEnabled= $FF

; Статически неиспользуемый адаптер: при X<2 замораживает врагов через
; EnemyFreezeTimer=EnemyFreezePowerUpDuration; при X>=2 проваливается в
; PowerUpEffect2 без дополнительного stack frame.
; Портит A и флаги.
UnreferencedFreezeEnemiesOrApplyPowerUpEffect2:
LFDB1:  cpx     #FirstEnemyTankSlot
        bcs     PowerUpEffect2
        lda     #EnemyFreezePowerUpDuration
        sta     EnemyFreezeTimer
        rts

; Вход: X — слот подобравшего усиление. Для X>=2 рисует голую целую базу без
; ограждения и через QueueBrickBaseAttributes обнуляет верхний атрибут, сохраняя
; разрешённые биты нижнего. Для X<2 при активном BattleState обновляет стальное
; ограждение и перезагружает BaseFortificationTimer.
; Портит ScratchPtr, A, X, Y; меняет nametable shadow и PPU-очередь через
; вызываемые процедуры. Ветка противника не возвращается самостоятельно, а
; хвостовым переходом возвращается из QueueBrickBaseAttributes.
PowerUpEffect2:
LFDBB:  cpx     #FirstEnemyTankSlot
        bcc     ApplyPlayerBaseFortification
        lda     #>BlankBaseRow
        sta     ScratchPtrHi
        lda     #<BlankBaseRow
        sta     ScratchPtrLo
        ldx     #PowerUpEffect2BaseColumn
        ldy     #PowerUpEffect2BlankRow
        jsr     QueueTileAtCoordinates
        lda     #>IntactBaseUpperRow
        sta     ScratchPtrHi
        lda     #<IntactBaseUpperRow
        sta     ScratchPtrLo
        ldx     #PowerUpEffect2BaseColumn
        ldy     #PowerUpEffect2UpperRow
        jsr     QueueTileAtCoordinates
        lda     #>IntactBaseLowerRow
        sta     ScratchPtrHi
        lda     #<IntactBaseLowerRow
        sta     ScratchPtrLo
        ldx     #PowerUpEffect2BaseColumn
        ldy     #PowerUpEffect2LowerRow
        jsr     QueueTileAtCoordinates
        jmp     QueueBrickBaseAttributes

ApplyPlayerBaseFortification:
LFDEF:  lda     BattleState
        bpl     FinishPowerUpEffect2
        jsr     DrawSteelBaseEnclosure
        lda     #BaseFortificationPowerUpDuration
        sta     BaseFortificationTimer
FinishPowerUpEffect2:
LFDFA:  rts

; Обработчик эффекта 3. Для X>=2 ставит bit3 в ObjectAttributes слотов 2..7.
; Для X<2 увеличивает PlayerUpgradeLevel,X на один уровень до
; PlayerUpgradeLevel3 и зеркалит его в ObjectAttributes,X. Сохраняет исходный
; X и Y; портит A и флаги, PPU/OAM/audio напрямую не меняет.
ApplyPowerUpEffect3:
LFDFB:  cpx     #FirstEnemyTankSlot
        bcc     UpgradeCollectingPlayer
        txa
        pha
        ldx     #(TankSlotCount-1)
UpgradeNextEnemyTank:
LFE03:  lda     ObjectAttributes,x
        ora     #EnemyUpgradeAttributeBit
        sta     ObjectAttributes,x
        nop
        dex
        cpx     #(FirstEnemyTankSlot-1)
        bne     UpgradeNextEnemyTank
        pla
        tax
        rts

UpgradeCollectingPlayer:
LFE12:  lda     PlayerUpgradeLevel,x
        cmp     #PlayerUpgradeLevel3
        bcs     FinishPowerUpEffect3
        clc
        adc     #PlayerUpgradeLevel1
        sta     PlayerUpgradeLevel,x
        sta     ObjectAttributes,x
FinishPowerUpEffect3:
LFE21:  rts

; Поражает танки противоположной стороны: для X<2 — активные слоты 2..7;
; для X>=2 — активных игроков 0..1 только при PlayerStunTimer,Y=0.
; Записывает TankStateDestroyed, attributes=0; для игроков также
; PlayerUpgradeLevel=PlayerUpgradeLevel1.
; Запрашивает аудиопоток уничтожения танка. X сохраняет; портит A/Y,
; PowerUpTargetSlot и флаги.
PowerUpEffect4:
LFE22:  cpx     #FirstEnemyTankSlot
        bcc     DestroyOpposingEnemies
        ; Значение AudioStateStartRequested одновременно равно последнему
        ; индексу игрока, поэтому один A инициализирует обе независимые роли.
        lda     #AudioStateStartRequested
        sta     PowerUpTargetSlot
        sta     TankDestructionAudioState
CheckNextOpposingPlayer:
LFE2D:  ldy     PowerUpTargetSlot
        lda     ObjectState,y
        bpl     AdvanceOpposingPlayerTarget
        cmp     #NonTargetableTankStateMin
        bcs     AdvanceOpposingPlayerTarget
        lda     PlayerStunTimer,y
        bne     AdvanceOpposingPlayerTarget
        lda     #PlayerUpgradeLevel1
        sta     PlayerUpgradeLevel,y
        lda     #TankStateDestroyed
        sta     ObjectState,y
        lda     #$00
        sta     ObjectAttributes,y
AdvanceOpposingPlayerTarget:
LFE4C:  dec     PowerUpTargetSlot
        bpl     CheckNextOpposingPlayer
        rts

DestroyOpposingEnemies:
LFE51:  lda     #(TankSlotCount-1)
        sta     PowerUpTargetSlot
        lda     #AudioStateStartRequested
        sta     TankDestructionAudioState
CheckNextOpposingEnemy:
LFE5A:  ldy     PowerUpTargetSlot
        lda     ObjectState,y
        bpl     AdvanceOpposingEnemyTarget
        cmp     #NonTargetableTankStateMin
        bcs     AdvanceOpposingEnemyTarget
        lda     #TankStateDestroyed
        sta     ObjectState,y
        lda     #$00
        sta     ObjectAttributes,y
AdvanceOpposingEnemyTarget:
LFE6F:  dec     PowerUpTargetSlot
        lda     PowerUpTargetSlot
        cmp     #(FirstEnemyTankSlot-1)
        bne     CheckNextOpposingEnemy
        rts

; Для игрока X<2 добавляет жизнь и запрашивает два аудиопотока звука
; дополнительной жизни. Для X>=2 преобразует
; младшие биты ObjectAttributes всех слотов 2..7: устанавливает bits0..1 и
; инвертирует bit2. Слоты обрабатываются независимо от активности.
; Сохраняет исходный X/Y; портит A и флаги, PPU/OAM не меняет.
PowerUpEffect5:
LFE78:  cpx     #FirstEnemyTankSlot
        bcs     TransformEnemyUpgradeBits
        inc     Player1Lives,x
        lda     #AudioStateStartRequested
        sta     ExtraLifePulse1AudioState
        sta     ExtraLifePulse2AudioState
        rts

TransformEnemyUpgradeBits:
LFE87:  txa
        pha
        ldx     #(TankSlotCount-1)
TransformNextEnemyUpgrade:
LFE8B:  lda     ObjectAttributes,x
        ora     #EnemyAttributeTransformSetBits
        eor     #EnemyAttributeTransformToggleBit
        sta     ObjectAttributes,x
        dex
        cpx     #(FirstEnemyTankSlot-1)
        bne     TransformNextEnemyUpgrade
        pla
        tax
        rts

; Устанавливает ObjectAttributes,X=PlayerUpgradeMaximum; для игроков X<2 также
; зеркалит значение в PlayerUpgradeLevel,X. Выход: A=PlayerUpgradeMaximum;
; X/Y и остальная RAM не меняются.
SetMaximumObjectUpgrade:
LFE9B:  lda     #PlayerUpgradeMaximum
        cpx     #FirstEnemyTankSlot
        bcs     StoreMaximumObjectUpgrade
        sta     PlayerUpgradeLevel,x
StoreMaximumObjectUpgrade:
LFEA4:  sta     ObjectAttributes,x
        rts

; Активирует дополнительную способность объекта X через ObjectSpecialState,X.
; Наблюдаемые эффекты: дополнительная двухспрайтовая метка, проход через TSA $12
; и поглощение следующего попадания с очисткой флага. Точное игровое имя не
; закреплено. Выход: A=ObjectSpecialStateEnabled; X/Y и остальные поля сохраняет.
PowerUpEffect7:
LFEA7:  lda     #ObjectSpecialStateEnabled
        sta     ObjectSpecialState,x
        rts
