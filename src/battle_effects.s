; Отрисовка усиления, щита игроков и эффектов базы ($E23B-$E362).

ShieldPlayerSlot     = $5A
BaseSpriteTileOffset = $69

; Рисует лежащее усиление с миганием либо короткий маркер уже подобранного
; усиления. По окончании PowerUpPickupDisplayTimer удаляет объект (PowerUpX=0).
; Портит A/X/Y и рабочее состояние OAM-рендера.
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
LE24E:  lda     #$02
        sta     RenderAttributes
        lda     #$3B
        sta     OamTile
        jmp     EmitPowerUpSprites

DrawBlinkingPowerUp:
LE259:  lda     FrameCounter
        and     #$08
        beq     FinishPowerUpDraw
        lda     #$02
        sta     RenderAttributes
        lda     PowerUpType
        asl     a
        asl     a
        clc
        adc     #$81
        sta     OamTile
; Общий хвост обоих вариантов усиления. Вход: OamTile/RenderAttributes заданы;
; выводит пару в PowerUpX/Y без terrain-priority, затем ставит маску $20.
EmitPowerUpSprites:
LE26C:  ldx     PowerUpX
        ldy     PowerUpY
        lda     #$00
        sta     SpriteBehindTerrainMask
        jsr     EmitTwoTileOamPair
        lda     #$20
        sta     SpriteBehindTerrainMask
FinishPowerUpDraw:
LE27B:  rts

; Обходит игроков 1..0 и рисует мигающую защитную анимацию пока
; PlayerShieldTimer,X != 0; раз в 64 кадра уменьшает таймер.
; Код кадра $29/$2D выбирается FrameCounter bit1. Выход: ShieldPlayerSlot=$FF;
; портит A/X/Y, ScratchPtr, render/OAM scratch, PlayerShieldTimer и OAM shadow.
UpdatePlayerShieldEffects:
LE27C:  lda     #$01
        sta     ShieldPlayerSlot
DrawNextPlayerShield:
LE280:  ldx     ShieldPlayerSlot
        lda     PlayerShieldTimer,x
        beq     AdvanceShieldPlayer
        lda     FrameCounter
        and     #$3F
        bne     DrawPlayerShield
        dec     PlayerShieldTimer,x
DrawPlayerShield:
LE28E:  lda     #$02
        sta     RenderAttributes
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
AdvanceShieldPlayer:
LE2A4:  dec     ShieldPlayerSlot
        bpl     DrawNextPlayerShield
        rts

; Обновляет таймер укрепления базы BaseFortificationTimer и фазу
; взрыва/поражения базы BattleState. Таймер уменьшается раз в 64 кадра;
; на последних трёх шагах ограждение мигает между сталью и кирпичом.
; Положительный BattleState уменьшается каждый вызов и диспетчеризует кадр
; через BaseExplosionFrameHandlers. Портит A/X/Y/ScratchPtr, рабочие байты
; рендера, shadow/PPU-очередь и OAM shadow.
UpdateBaseEffects:
LE2A9:  lda     BaseFortificationTimer
        beq     UpdateBaseExplosion
        lda     FrameCounter
        and     #$0F
        bne     UpdateBaseExplosion
        lda     FrameCounter
        and     #$3F
        bne     SelectBaseEnclosureMaterial
        dec     BaseFortificationTimer
        beq     DrawBrickBaseEnclosureNow
SelectBaseEnclosureMaterial:
LE2BD:  lda     BaseFortificationTimer
        cmp     #$04
        bcs     UpdateBaseExplosion
        lda     FrameCounter
        and     #$10
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
        lda     #$03
        sta     RenderAttributes
        dec     BattleState
        lda     BattleState
        lsr     a
        lsr     a
        sec
        sbc     #$05
        bpl     FoldBaseExplosionPhaseOnce
        eor     #$FF
        clc
        adc     #$01
FoldBaseExplosionPhaseOnce:
LE2EC:  sec
        sbc     #$05
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

; Шесть обработчиков: no-op, три кадра взрыва, целая и разрушенная база.
BaseExplosionFrameHandlers:
LE306:  .word   NoOpHandler
        .word   DrawBaseExplosionFrame1,DrawBaseExplosionFrame2,DrawBaseExplosionFrame3
        .word   DrawIntactBaseFrame,DrawDestroyedBaseFrame

; Три входа выбирают OAM tile-base $F1/$F5/$F9 и рисуют пару в ($78,$D8).
; Меняют A/X/Y, OamTile, RenderAttributes и всё состояние EmitTwoTileOamPair.
DrawBaseExplosionFrame1:
LE312:  lda     #$F1
        jmp     PositionBaseExplosionFrame

DrawBaseExplosionFrame2:
LE317:  lda     #$F5
        jmp     PositionBaseExplosionFrame

DrawBaseExplosionFrame3:
LE31C:  lda     #$F9
; Общий хвост трёх кадров: A=tile-base; задаёт координаты центра базы.
PositionBaseExplosionFrame:
LE31E:  ldx     #$78
        ldy     #$D8
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
; Портит A/X/Y, ScratchPtr, рабочие байты рендера и OAM shadow.
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
; BaseSpriteTileOffset прибавляется к кодам $D1/$D5/$D9/$DD.
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
