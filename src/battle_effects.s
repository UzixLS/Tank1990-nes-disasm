; Отрисовка усиления, щита игроков и эффектов базы ($E23B-$E362).

ShieldPlayerSlot     = $5A
BaseSpriteTileOffset = $69

PowerUpRenderPalette       = $02
CollectedPowerUpMarkerTile = $3B
PowerUpVisibleFrameBit     = $08
PowerUpFirstTypeTile       = $81
ShieldTimerTickFrameMask   = $3F
ShieldRenderPalette        = $02
ShieldAnimationFrameBit    = $02
ShieldFirstTile            = $29
BaseEnclosureUpdateFrameMask   = $0F
BaseFortificationTimerTickMask = $3F
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

; Рендерит бонус один раз за отображаемый battle-frame; вызывается также при
; pause. PowerUpX=0 -- sentinel отсутствующего объекта. При ненулевом
; PowerUpPickupDisplayTimer функция сначала делает DEC: значения N..2 дают
; N-1 кадров CollectedPowerUpMarkerTile, входное 1 сразу очищает PowerUpX и
; ничего не рисует. Поэтому штатное начальное $32 выводит marker 49 раз.
;
; Неподобранный бонус (timer=0) виден 8 из каждых 16 кадров, когда bit3
; FrameCounter установлен; tile-base равен PowerUpFirstTypeTile+4*PowerUpType.
; Каждый видимый вариант расходует две OAM entries и не проверяет capacity;
; PPU queue/shadow не меняются. Ранние выходы сохраняют X/Y и дают A=0.
; Отрисовка портит A/X/Y, ScratchPtr, terrain/OAM scratch, OamTile,
; RenderAttributes и OamBufferPos.
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
; Общий хвост обоих вариантов. Вход: OamTile/RenderAttributes заданы. Выводит
; два hardware sprites с центром пары в PowerUpX/Y: первый получает X-8,
; второй X, оба аппаратный Y=PowerUpY-8. На время terrain probes устанавливает
; SpriteBehindTerrainMask=0, после пары безусловно оставляет её равной $20,
; а не восстанавливает вход. OamTile по выходу увеличен на 2, OamBufferPos --
; на 2*OamBufferStep (две entries); A=$20, X/Y оставлены вторым EmitOamSprite.
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

; Обходит игроков 1..0 независимо от ObjectState. Каждый ненулевой на входе
; PlayerShieldTimer,X рисует пару shield sprites и уменьшается только при
; FrameCounter mod64=0; полученный DEC-ом ноль всё ещё рисуется на этом tick.
; FrameCounter bit1 выбирает tile-base $29/$2D, то есть кадр меняется каждые
; два frame-counter шага. На каждого защищённого игрока расходуются две OAM
; entries; максимум четыре, capacity не проверяется.
;
; Выход: ShieldPlayerSlot=$FF. Портит A/X/Y, ScratchPtr, terrain/OAM scratch,
; OamTile, RenderAttributes, OamBufferPos и условно PlayerShieldTimer[0..1].
; Использует текущую SpriteBehindTerrainMask, но сам её не меняет. PPU queue,
; nametable shadow и audio не затрагивает.
UpdatePlayerShieldEffects:
LE27C:  lda     #(PlayerTankCount-1)
        sta     ShieldPlayerSlot
DrawNextPlayerShield:
LE280:  ldx     ShieldPlayerSlot
        lda     PlayerShieldTimer,x
        beq     AdvanceShieldPlayer
        lda     FrameCounter
        and     #ShieldTimerTickFrameMask
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

; Последовательно обслуживает стальное ограждение, затем destruction sequence;
; обе части могут сработать за один вызов. Fortification рассматривается только
; при FrameCounter mod16=0 и уменьшается при mod64=0. Пока timer>=4, уже
; нарисованная сталь не обновляется. Значения 3,2,1 перерисовывают enclosure
; каждые 16 кадров, чередуя brick при bit4=0 и steel при bit4=1. DEC 1->0
; немедленно оставляет brick. Каждая перерисовка добавляет ровно 41 byte в PPU
; queue и меняет четыре строки shadow плюс два attribute bytes; capacity не
; проверяется.
;
; BattleState=0 и отрицательные состояния, включая штатный active=$80,
; destruction не обслуживают. Положительное значение уменьшается на каждом
; вызове, и OAM handler выбирается по уже уменьшенному значению. Портит
; A/X/Y/ScratchPtr, render/terrain/OAM scratch; условно меняет timer, BattleState,
; shadow, PPU queue и OAM shadow/cursor. Прямых записей PPU нет.
UpdateBaseEffects:
LE2A9:  lda     BaseFortificationTimer
        beq     UpdateBaseDestructionSequence
        lda     FrameCounter
        and     #BaseEnclosureUpdateFrameMask
        bne     UpdateBaseDestructionSequence
        lda     FrameCounter
        and     #BaseFortificationTimerTickMask
        bne     SelectBaseEnclosureMaterial
        dec     BaseFortificationTimer
        beq     DrawBrickBaseEnclosureNow
SelectBaseEnclosureMaterial:
LE2BD:  lda     BaseFortificationTimer
        cmp     #BaseWarningTimerThreshold
        bcs     UpdateBaseDestructionSequence
        lda     FrameCounter
        and     #BaseWarningBlinkFrameBit
        beq     DrawBrickBaseEnclosureNow
        jsr     DrawSteelBaseEnclosure
        jmp     UpdateBaseDestructionSequence

DrawBrickBaseEnclosureNow:
LE2CF:  jsr     DrawBrickBaseEnclosure
; Намеренный fallthrough после brick-render. Альтернативный entry без обработки
; ограждения: уменьшает положительный BattleState и диспетчеризует кадр базы/
; взрыва хвостовым JMP; RTS handler-а возвращается caller-у UpdateBaseEffects.
UpdateBaseDestructionSequence:
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
        lda     BaseDestructionFrameHandlers,y
        sta     ScratchPtrLo
        lda     BaseDestructionFrameHandlers+1,y
        sta     ScratchPtrHi
        jmp     (ScratchPtrLo)

FinishBaseEffects:
LE305:  rts

; Для штатного старта BattleState=$27 post-DEC значения и OAM-стоимость таковы:
;   38..36: explosion 1 (2 entries)   35..32: explosion 2 (2)
;   31..28: explosion 3 (2)           27..24: intact overlay (8)
;   23..20: destroyed overlay (8)      19..16: intact overlay (8)
;   15..12: explosion 3 (2)            11..8 : explosion 2 (2)
;    7..4 : explosion 1 (2)             3..0 : no-op (0)
; Индекс 0..5 получается как abs(abs((BattleState>>2)-5)-5). Background базы
; уже заменён DrawDestroyedBase при попадании; intact/destroyed здесь -- только
; временные OAM overlays. Перед dispatch всегда задаётся RenderAttributes=3.
BaseDestructionFrameHandlers:
LE306:  .word   NoOpHandler
        .word   DrawBaseExplosionFrame1,DrawBaseExplosionFrame2,DrawBaseExplosionFrame3
        .word   DrawIntactBaseSpriteOverlay,DrawDestroyedBaseSpriteOverlay

; Три входа выбирают OAM tile-base $F1/$F5/$F9 и рисуют пару в ($78,$D8):
; hardware sprites оказываются в X=$70/$78, Y=$D0. Каждый кадр расходует две
; OAM entries, не проверяя capacity; PPU/shadow не меняет. RenderAttributes=3
; подготовлен dispatcher-ом, SpriteBehindTerrainMask наследуется без изменения.
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
; Альтернативный вход: A=tile-base, X/Y=центр пары. Выводит две OAM entries.
; Выходы/side effects совпадают с EmitTwoTileOamPair; OamTile=входной tile+2.
EmitBaseSpritePair:
LE322:  sta     OamTile
        jsr     EmitTwoTileOamPair
        rts

; Прибавляет к tile-base A смещение BaseSpriteTileOffset и хвостом рисует пару
; в X/Y. C принудительно очищается, поэтому offset складывается без входного carry.
DrawBaseSpriteWithOffset:
LE328:  clc
        adc     BaseSpriteTileOffset
        jmp     EmitBaseSpritePair

; Обнуляет BaseSpriteTileOffset и рисует sprite overlay целой базы: четыре пары,
; восемь OAM entries. RenderAttributes должен быть заранее задан dispatcher-ом.
; Nametable shadow/PPU queue не меняются; capacity OAM не проверяется.
DrawIntactBaseSpriteOverlay:
LE32E:  lda     #$00
        sta     BaseSpriteTileOffset
        jsr     DrawBaseSpriteOverlayGrid
        rts

; Ставит BaseSpriteTileOffset=$10 и рисует альтернативный восьмиспрайтовый OAM
; overlay разрушенной базы. Требования и side effects те же, что выше.
DrawDestroyedBaseSpriteOverlay:
LE336:  lda     #DestroyedBaseTileOffset
        sta     BaseSpriteTileOffset
        jsr     DrawBaseSpriteOverlayGrid
        rts

; Рисует сетку 2x2 двухспрайтовых пар с центрами ($70,$D0)..($80,$E0).
; Фактические hardware X равны $68,$70,$78,$80, Y -- $C8/$D8.
; BaseSpriteTileOffset прибавляется к bases $D1/$D5/$D9/$DD. Расходует восемь
; OAM entries (OamBufferPos += 8*OamBufferStep), портит A/X/Y, ScratchPtr,
; terrain/OAM scratch, OamTile и RenderAttributes; PPU/shadow не меняет.
DrawBaseSpriteOverlayGrid:
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
