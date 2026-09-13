; Обработчики усилений и улучшений объектов ($FDB1-$FEAC).

PowerUpTargetSlot = $5A

; Статически неиспользуемый адаптер: при X<2 замораживает врагов через
; EnemyFreezeTimer=$0A; при X>=2 проваливается в PowerUpEffect2.
; Портит A и флаги.
UnreferencedFreezeEnemiesOrApplyPowerUpEffect2:
LFDB1:  cpx     #FirstEnemyTankSlot
        bcs     PowerUpEffect2
        lda     #$0A
        sta     EnemyFreezeTimer
        rts

; Вход: X — слот подобравшего усиление. Для X>=2 рисует голую целую базу без
; ограждения и через QueueBrickBaseAttributes обнуляет верхний атрибут, сохраняя
; разрешённые биты нижнего. Для X<2 при активном BattleState обновляет стальное
; ограждение и ставит BaseFortificationTimer=$14.
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
        ldx     #$0C
        ldy     #$19
        jsr     QueueTileAtCoordinates
        lda     #>IntactBaseUpperRow
        sta     ScratchPtrHi
        lda     #<IntactBaseUpperRow
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$1A
        jsr     QueueTileAtCoordinates
        lda     #>IntactBaseLowerRow
        sta     ScratchPtrHi
        lda     #<IntactBaseLowerRow
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$1B
        jsr     QueueTileAtCoordinates
        jmp     QueueBrickBaseAttributes

ApplyPlayerBaseFortification:
LFDEF:  lda     BattleState
        bpl     FinishPowerUpEffect2
        jsr     DrawSteelBaseEnclosure
        lda     #$14
        sta     BaseFortificationTimer
FinishPowerUpEffect2:
LFDFA:  rts

; Обработчик эффекта 3. Для X>=2 ставит bit3 в ObjectAttributes слотов 2..7.
; Для X<2 увеличивает PlayerUpgradeLevel,X на $20 до предела $60 и зеркалит
; его в ObjectAttributes,X. Сохраняет исходный X и Y; портит A и флаги.
ApplyPowerUpEffect3:
LFDFB:  cpx     #FirstEnemyTankSlot
        bcc     UpgradeCollectingPlayer
        txa
        pha
        ldx     #(TankSlotCount-1)
UpgradeNextEnemyTank:
LFE03:  lda     ObjectAttributes,x
        ora     #$08
        sta     ObjectAttributes,x
        nop
        dex
        cpx     #$01
        bne     UpgradeNextEnemyTank
        pla
        tax
        rts

UpgradeCollectingPlayer:
LFE12:  lda     PlayerUpgradeLevel,x
        cmp     #$60
        bcs     FinishPowerUpEffect3
        clc
        adc     #$20
        sta     PlayerUpgradeLevel,x
        sta     ObjectAttributes,x
FinishPowerUpEffect3:
LFE21:  rts

; Поражает танки противоположной стороны: для X<2 — активные слоты 2..7;
; для X>=2 — активных игроков 0..1 только при PlayerStunTimer,Y=0.
; Записывает TankStateDestroyed, attributes=0; для игроков также
; PlayerUpgradeLevel=$20.
; Запрашивает аудиопоток уничтожения танка. X сохраняет; портит A/Y,
; PowerUpTargetSlot и флаги.
PowerUpEffect4:
LFE22:  cpx     #FirstEnemyTankSlot
        bcc     DestroyOpposingEnemies
        lda     #$01
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
        lda     #$20
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
        cmp     #$01
        bne     CheckNextOpposingEnemy
        rts

; Для игрока X<2 добавляет жизнь и запрашивает два аудиопотока звука
; дополнительной жизни. Для X>=2 преобразует
; младшие биты ObjectAttributes всех слотов 2..7. Сохраняет исходный X; портит A и флаги.
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
        ora     #$03
        eor     #$04
        sta     ObjectAttributes,x
        dex
        cpx     #$01
        bne     TransformNextEnemyUpgrade
        pla
        tax
        rts

; Устанавливает ObjectAttributes,X=$63; для игроков X<2 также зеркалит $63 в $0101,X.
; Выход: A=$63; X/Y и остальная RAM не меняются.
SetMaximumObjectUpgrade:
LFE9B:  lda     #$63
        cpx     #FirstEnemyTankSlot
        bcs     StoreMaximumObjectUpgrade
        sta     PlayerUpgradeLevel,x
StoreMaximumObjectUpgrade:
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
