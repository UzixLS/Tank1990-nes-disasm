; Отрисовка усиления, щита игроков и эффектов базы ($E23B-$E362).

ShieldPlayerSlot     = $5A
BaseSpriteTileOffset = $69

PowerUpRenderPalette       = $02
CollectedPowerUpMarkerTile = $3B
PowerUpVisibleFrameBit     = $08
PowerUpFirstTypeTile       = $81
ShieldTickFrameMask        = $3F
ShieldRenderPalette        = $02
ShieldAnimationFrameBit    = $02
ShieldFirstTile            = $29
BaseEffectUpdateFrameMask  = $0F
BaseFortificationTickMask  = $3F
BaseWarningTimerThreshold  = $04
BaseWarningBlinkFrameBit   = $10
BaseRenderPalette          = $03
BaseExplosionFoldPivot     = $05
BaseExplosionTile1         = $F1
BaseExplosionTile2         = $F5
BaseExplosionTile3         = $F9
BaseExplosionX             = $78
BaseExplosionY             = $D8
DestroyedBaseTileOffset    = $10
BaseSpriteLeftX            = $70
BaseSpriteRightX           = $80
BaseSpriteTopY             = $D0
BaseSpriteBottomY          = $E0
BaseSpriteTopLeftTile      = $D1
BaseSpriteTopRightTile     = $D5
BaseSpriteBottomLeftTile   = $D9
BaseSpriteBottomRightTile  = $DD

; Рисует лежащее усиление с миганием либо короткий маркер уже подобранного
; усиления. При ненулевом pickup timer сначала уменьшает его: новое значение 0
; удаляет объект (PowerUpX=0), иначе выводится marker tile. Лежащее усиление
; видно только при установленном PowerUpVisibleFrameBit. Меняет pickup timer,
; при истечении PowerUpX, а при выводе — A/X/Y, OAM shadow/cursor и render scratch.
DrawAndExpirePowerUp:
LE23B:  lda     PowerUpX
        beq     FinishPowerUpDraw
        lda     PowerUpPickupDisplayTimer
        beq     DrawBlinkingPowerUp
        dec     PowerUpPickupDisplayTimer
        bne     DrawCollectedPowerUpMarker
        lda     #$00
        sta     PowerUpX
        jmp     FinishPowerUpDraw

DrawCollectedPowerUpMarker:
LE24E:  lda     #PowerUpRenderPalette
        sta     RenderAttributes
        lda     #CollectedPowerUpMarkerTile
        sta     OamTile
        jmp     EmitPowerUpSprites

DrawBlinkingPowerUp:
LE259:  lda     FrameCounter
        and     #PowerUpVisibleFrameBit
        beq     FinishPowerUpDraw
        lda     #PowerUpRenderPalette
        sta     RenderAttributes
        lda     PowerUpType
        asl     a
        asl     a
        clc
        adc     #PowerUpFirstTypeTile
        sta     OamTile
; Общий хвост обоих вариантов усиления. Вход: OamTile/RenderAttributes заданы;
; выводит пару в PowerUpX/Y без terrain-priority, затем всегда устанавливает
; TerrainPriorityEnabled, а не восстанавливает входную маску.
EmitPowerUpSprites:
LE26C:  ldx     PowerUpX
        ldy     PowerUpY
        lda     #TerrainPriorityDisabled
        sta     SpriteBehindTerrainMask
        jsr     EmitTwoTileOamPair
        lda     #TerrainPriorityEnabled
        sta     SpriteBehindTerrainMask
FinishPowerUpDraw:
LE27B:  rts

; Обходит игроков 1..0 и рисует мигающую защитную анимацию пока
; PlayerShieldTimer,X != 0; раз в 64 кадра уменьшает таймер.
; Код кадра $29/$2D выбирается FrameCounter bit1. Выход: ShieldPlayerSlot=$FF;
; портит A/X/Y, ScratchPtr, render/OAM scratch, PlayerShieldTimer и OAM shadow.
; Нулевое значение, полученное после DEC, всё ещё рисуется в текущем кадре.
UpdatePlayerShieldEffects:
LE27C:  lda     #(PlayerTankCount-1)
        sta     ShieldPlayerSlot
DrawNextPlayerShield:
LE280:  ldx     ShieldPlayerSlot
        lda     PlayerShieldTimer,x
        beq     AdvanceShieldPlayer
        lda     FrameCounter
        and     #ShieldTickFrameMask
        bne     DrawPlayerShield
        dec     PlayerShieldTimer,x
DrawPlayerShield:
LE28E:  lda     #ShieldRenderPalette
        sta     RenderAttributes
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        lda     FrameCounter
        and     #ShieldAnimationFrameBit
        asl     a
        clc
        adc     #ShieldFirstTile
        sta     OamTile
        jsr     EmitTwoTileOamPair
AdvanceShieldPlayer:
LE2A4:  dec     ShieldPlayerSlot
        bpl     DrawNextPlayerShield
        rts

; Обновляет таймер укрепления базы BaseFortificationTimer и фазу
; взрыва/поражения базы BattleState. Таймер уменьшается раз в 64 кадра;
; на последних трёх шагах ограждение мигает между сталью и кирпичом.
; Положительный BattleState уменьшается каждый вызов и диспетчеризует кадр
; через BaseExplosionFrameHandlers; ноль и отрицательные состояния пропускаются.
; Портит A/X/Y/ScratchPtr, рабочие байты рендера, shadow/PPU-очередь и OAM shadow.
UpdateBaseEffects:
LE2A9:  lda     BaseFortificationTimer
        beq     UpdateBaseExplosion
        lda     FrameCounter
        and     #BaseEffectUpdateFrameMask
        bne     UpdateBaseExplosion
        lda     FrameCounter
        and     #BaseFortificationTickMask
        bne     SelectBaseEnclosureMaterial
        dec     BaseFortificationTimer
        beq     DrawBrickBaseEnclosureNow
SelectBaseEnclosureMaterial:
LE2BD:  lda     BaseFortificationTimer
        cmp     #BaseWarningTimerThreshold
        bcs     UpdateBaseExplosion
        lda     FrameCounter
        and     #BaseWarningBlinkFrameBit
        beq     DrawBrickBaseEnclosureNow
        jsr     DrawSteelBaseEnclosure
        jmp     UpdateBaseExplosion

DrawBrickBaseEnclosureNow:
LE2CF:  jsr     DrawBrickBaseEnclosure
; Альтернативный вход после обработки ограждения: уменьшает положительный
; BattleState и диспетчеризует соответствующий кадр базы/взрыва.
UpdateBaseExplosion:
LE2D2:  lda     BattleState
        beq     FinishBaseEffects
        bmi     FinishBaseEffects
        lda     #BaseRenderPalette
        sta     RenderAttributes
        dec     BattleState
        lda     BattleState
        lsr     a
        lsr     a
        sec
        sbc     #BaseExplosionFoldPivot
        bpl     FoldBaseExplosionPhaseOnce
        eor     #$FF
        clc
        adc     #$01
FoldBaseExplosionPhaseOnce:
LE2EC:  sec
        sbc     #BaseExplosionFoldPivot
        bpl     DispatchBaseExplosionFrame
        eor     #$FF
        clc
        adc     #$01
DispatchBaseExplosionFrame:
LE2F6:  asl     a
        tay
        lda     BaseExplosionFrameHandlers,y
        sta     ScratchPtrLo
        lda     BaseExplosionFrameHandlers+1,y
        sta     ScratchPtrHi
        jmp     (ScratchPtrLo)

FinishBaseEffects:
LE305:  rts

; Шесть обработчиков результата двойного симметричного fold BattleState/4:
; no-op, три кадра взрыва, целая и разрушенная база.
BaseExplosionFrameHandlers:
LE306:  .word   NoOpHandler
        .word   DrawBaseExplosionFrame1,DrawBaseExplosionFrame2,DrawBaseExplosionFrame3
        .word   DrawIntactBaseFrame,DrawDestroyedBaseFrame

; Три входа выбирают OAM tile-base $F1/$F5/$F9 и рисуют пару в ($78,$D8).
; Меняют A/X/Y, OamTile, RenderAttributes и всё состояние EmitTwoTileOamPair.
DrawBaseExplosionFrame1:
LE312:  lda     #BaseExplosionTile1
        jmp     PositionBaseExplosionFrame

DrawBaseExplosionFrame2:
LE317:  lda     #BaseExplosionTile2
        jmp     PositionBaseExplosionFrame

DrawBaseExplosionFrame3:
LE31C:  lda     #BaseExplosionTile3
; Общий хвост трёх кадров: A=tile-base; задаёт координаты центра базы.
PositionBaseExplosionFrame:
LE31E:  ldx     #BaseExplosionX
        ldy     #BaseExplosionY
; Альтернативный вход: A=tile, X/Y=координаты. Выводит двухспрайтовую пару.
EmitBaseSpritePair:
LE322:  sta     OamTile
        jsr     EmitTwoTileOamPair
        rts

; Прибавляет к номеру кадра A смещение BaseSpriteTileOffset и рисует
; двухспрайтовую пару в X/Y.
DrawBaseSpriteWithOffset:
LE328:  clc
        adc     BaseSpriteTileOffset
        jmp     EmitBaseSpritePair

; Обнуляет BaseSpriteTileOffset и рисует четыре пары — восемь OAM-спрайтов базы.
; RenderAttributes должен быть заранее задан вызывающим UpdateBaseExplosion.
; Портит A/X/Y, ScratchPtr, рабочие байты рендера и OAM shadow.
DrawIntactBaseFrame:
LE32E:  lda     #$00
        sta     BaseSpriteTileOffset
        jsr     DrawBaseSpriteGrid
        rts

; Ставит BaseSpriteTileOffset=$10 и рисует альтернативные четыре пары —
; восемь OAM-спрайтов базы. Требование к RenderAttributes то же, что выше.
DrawDestroyedBaseFrame:
LE336:  lda     #DestroyedBaseTileOffset
        sta     BaseSpriteTileOffset
        jsr     DrawBaseSpriteGrid
        rts

; Рисует сетку 2x2 двухспрайтовых пар в ($70,$D0)..($80,$E0);
; BaseSpriteTileOffset прибавляется к кодам $D1/$D5/$D9/$DD.
DrawBaseSpriteGrid:
LE33E:  ldx     #BaseSpriteLeftX
        ldy     #BaseSpriteTopY
        lda     #BaseSpriteTopLeftTile
        jsr     DrawBaseSpriteWithOffset
        ldx     #BaseSpriteRightX
        ldy     #BaseSpriteTopY
        lda     #BaseSpriteTopRightTile
        jsr     DrawBaseSpriteWithOffset
        ldx     #BaseSpriteLeftX
        ldy     #BaseSpriteBottomY
        lda     #BaseSpriteBottomLeftTile
        jsr     DrawBaseSpriteWithOffset
        ldx     #BaseSpriteRightX
        ldy     #BaseSpriteBottomY
        lda     #BaseSpriteBottomRightTile
        jsr     DrawBaseSpriteWithOffset
        rts
