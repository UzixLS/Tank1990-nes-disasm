; Обработчики усилений и улучшений объектов ($FDB1-$FEAC).

PowerUpTargetSlot = $5A
EnemyUpgradeAttributeBit = $08
ObjectSpecialStateEnabled= $FF
EnemyBaseDamageQueueBytes = $20
EnemyBaseDamageQueueMaxStartPos = $5F

; Статически неиспользуемый адаптер: при X<2 замораживает врагов через
; EnemyFreezeTimer=EnemyFreezePowerUpDuration; при X>=2 проваливается в
; PowerUpEffect2 без дополнительного stack frame.
; Ветка X<2: A=$0A, N=0/Z=0/C=0, V и X/Y сохраняются; меняет только timer.
; Ветка X>=2 наследует все предусловия/эффекты PowerUpEffect2. Bounds check
; верхней границы X нет; статических callers у entry не найдено.
UnreferencedFreezeEnemiesOrApplyPowerUpEffect2:
LFDB1:  cpx     #FirstEnemyTankSlot
        bcs     PowerUpEffect2
        lda     #EnemyFreezePowerUpDuration
        sta     EnemyFreezeTimer
        rts

; Вход: X — слот подобравшего усиление. Для любого X>=2 рисует голую целую базу без
; ограждения только в rows25..27 (row24 не трогает) и через
; QueueBrickBaseAttributes обнуляет левый attribute byte, сохраняя внешние
; quadrants правого. Эта ветка не сбрасывает BaseFortificationTimer, поэтому
; активный warning/blink позднее может снова нарисовать enclosure. Добавляет
; EnemyBaseDamageQueueBytes=32 bytes; нужны primary NametablePpuOffset,
; PpuBufferPos<=$5F и отсутствие NMI во время построения. Выход enemy-ветки:
; A=$FF, X=PpuBufferPos=old+32, Y=6, ScratchPtr=IntactBaseLowerRow,
; AuxPtr=$076C; PPU registers/OAM/audio напрямую не меняются.
;
; Для X<2 только отрицательный BattleState (штатно $80=active) обновляет
; стальное ограждение и перезагружает BaseFortificationTimer=$14; любой
; неотрицательный state возвращается без изменения. Player-ветка сохраняет X,
; но active path портит Y/ScratchPtr/AuxPtr и добавляет 41 byte в PPU queue.
; Обе ветки меняют shadow/attributes через helpers; enemy path хвостом возвращается
; из QueueBrickBaseAttributes. X вне 0..7 отдельно не отвергается.
PowerUpEffect2:
LFDBB:  cpx     #FirstEnemyTankSlot
        bcc     ApplyPlayerBaseFortification
        lda     #>BlankBaseRow
        sta     ScratchPtrHi
        lda     #<BlankBaseRow
        sta     ScratchPtrLo
        ldx     #BaseEnclosureColumn
        ldy     #BaseEnclosureTopRow
        jsr     QueueTileAtCoordinates
        lda     #>IntactBaseUpperRow
        sta     ScratchPtrHi
        lda     #<IntactBaseUpperRow
        sta     ScratchPtrLo
        ldx     #BaseEnclosureColumn
        ldy     #BaseCoreUpperRow
        jsr     QueueTileAtCoordinates
        lda     #>IntactBaseLowerRow
        sta     ScratchPtrHi
        lda     #<IntactBaseLowerRow
        sta     ScratchPtrLo
        ldx     #BaseEnclosureColumn
        ldy     #BaseCoreLowerRow
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

; Обработчик эффекта 3. Для X>=2 ставит bit3 в ObjectAttributes всех слотов 2..7,
; включая неактивные, независимо от конкретного collector slot.
; Для X<2 увеличивает PlayerUpgradeLevel,X на один уровень до
; PlayerUpgradeLevel3 и зеркалит его в ObjectAttributes,X. Сохраняет исходный
; X и Y; PlayerExtendedUpgrade не меняется. На уже достигнутом/нестандартном
; уровне >=$60 значение не нормализуется. Enemy-ветка возвращает A=X=входной
; slot, C=1, N/Z по X; player-ветка возвращает A=старый либо новый level,
; C=1 при исходном level >=$60, иначе C=0. V сохраняется; PPU/OAM/audio/RNG
; напрямую не меняются. Bounds check X нет.
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

; Поражает танки противоположной стороны: для X<2 — targetable state $80..$DF
; слотов 7..2; для X>=2 — targetable игроков 1..0 только при
; PlayerStunTimer,Y=0. Верхняя граница collector X не проверяется.
; Записывает TankStateDestroyed, attributes=0; для игроков также
; PlayerUpgradeLevel=PlayerUpgradeLevel1, но PlayerExtendedUpgrade и
; ObjectSpecialState не очищает. Kill counters/score/bonus carrier logic не
; вызываются. TankDestructionAudioState=1 запрашивается безусловно, даже если
; подходящих целей нет. X сохраняется, Y заканчивает на player0 либо enemy2;
; PowerUpTargetSlot=$FF для enemy collector и 1 для player collector.
; PPU/OAM/RNG не меняются.
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

; Для игрока X<2 добавляет жизнь modulo 256 и запрашивает два аудиопотока звука
; дополнительной жизни. Для X>=2 преобразует
; младшие биты ObjectAttributes всех слотов 2..7: устанавливает bits0..1 и
; инвертирует carrier bit2; остальные bits сохраняет. Слоты обрабатываются
; независимо от активности, исходный collector X восстанавливается.
; Player path: A=1, C=0, N=0/Z=0. Enemy path: A=X=input collector, C=1,
; N/Z по X. V и Y сохраняются; PPU/OAM/RNG не меняются.
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
        ora     #EnemyHitPointMask
        eor     #EnemyPowerUpCarrierFlag
        sta     ObjectAttributes,x
        dex
        cpx     #(FirstEnemyTankSlot-1)
        bne     TransformNextEnemyUpgrade
        pla
        tax
        rts

; Устанавливает ObjectAttributes,X=PlayerUpgradeMaximum; для игроков X<2 также
; зеркалит значение в PlayerUpgradeLevel,X. Выход: A=PlayerUpgradeMaximum;
; X/Y и остальная RAM не меняются. Flags остаются от CPX #2: player C=0/N=1,
; slot2 C=1/Z=1, прочие штатные enemy slots C=1/N=Z=0; V сохраняется.
; PlayerExtendedUpgrade не меняется, bounds check верхней границы X отсутствует.
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
; закреплено. Выход: A=$FF, N=1/Z=0; C/V и X/Y сохраняются. Меняет только
; ObjectSpecialState,X, bounds check нет; PPU/OAM/audio/RNG напрямую не трогает.
PowerUpEffect7:
LFEA7:  lda     #ObjectSpecialStateEnabled
        sta     ObjectSpecialState,x
        rts
