; Обнаружение подбора усиления и диспетчеризация эффекта ($E972-$E9F1).

; Проверяет power-up в (PowerUpX,PowerUpY) против активных танков.
; PowerUpX=0 означает отсутствие объекта; ненулевой PowerUpPickupDisplayTimer
; запрещает повторную проверку. BeginPowerUpCollectorScan выбирает слоты 1..0
; при GameVariant<=7 или 7..0 при GameVariant>7. Квадрат захвата:
; |dx| и |dy| меньше PowerUpPickupHalfExtent. Отрицательный PowerUpType
; используется SpawnPowerUp как проверка свободного места без применения эффекта.
; При настоящем подборе обычно начисляет игроку 500 очков и запускает звук;
; PowerUpScoreSuppressionValue в PowerUpScoreSuppressionState пропускает
; награду и звук, но не сам эффект.
; Dispatch снимает со стека адрес возврата UpdatePowerUpPickup: RTS обработчика
; возвращает вызывающему её caller-а и тем самым пропускает остаток caller-а.
; Вне короткого прохода pickup этот адрес является ProjectileY+4; отдельного
; постоянного поля для suppression state в RAM нет.
PowerUpScoreSuppressionState = $C6
PowerUpPickupHalfExtent      = 12
PowerUpPickupDisplayDuration = $32
PowerUpPackedScoreAward      = $50
PowerUpScoreSuppressionValue = $06
UpdatePowerUpPickup:
LE972:  lda     PowerUpX
        beq     FinishPowerUpPickupScan
        lda     PowerUpPickupDisplayTimer
        bne     FinishPowerUpPickupScan
        jmp     BeginPowerUpCollectorScan

; Недостижимый NOP между trampoline LE55B и циклом проверки.
UnreferencedE97dNop:
LE97D:  .byte   $EA
CheckPowerUpTankOverlap:
LE97E:  ldx     PowerUpCollectorSlot
        lda     ObjectState,x
        bpl     AdvancePowerUpCollectorScan
        cmp     #NonTargetableTankStateMin
        bcs     AdvancePowerUpCollectorScan
        lda     ObjectX,x
        sec
        sbc     PowerUpX
        bpl     PowerUpXDistanceReady
        eor     #$FF
        clc
        adc     #$01
PowerUpXDistanceReady:
LE994:  cmp     #PowerUpPickupHalfExtent
        bcs     AdvancePowerUpCollectorScan
        lda     ObjectY,x
        sec
        sbc     PowerUpY
        bpl     PowerUpYDistanceReady
        eor     #$FF
        clc
        adc     #$01
PowerUpYDistanceReady:
LE9A4:  cmp     #PowerUpPickupHalfExtent
        bcs     AdvancePowerUpCollectorScan
        lda     #PowerUpPickupDisplayDuration
        sta     PowerUpPickupDisplayTimer
        lda     PowerUpType
        bmi     FinishPowerUpPickupScan
        lda     PowerUpScoreSuppressionState
        cmp     #PowerUpScoreSuppressionValue
        beq     DispatchCollectedPowerUp
        lda     #PowerUpPackedScoreAward
        jsr     PreparePackedScoreIncrement
        ldx     PowerUpCollectorSlot
        ; AddPreparedScoreForPlayerSlot работает только для слотов игроков 0/1.
        jsr     AddPreparedScoreForPlayerSlot
        jsr     AwardScoreThresholdLives
        ldx     PowerUpCollectorSlot
        lda     #AudioStateStartRequested
        sta     PowerUpPickupAudioState
DispatchCollectedPowerUp:
LE9CA:  lda     PowerUpType
        asl     a
        tay
        lda     PowerUpEffectHandlers,y
        sta     ScratchPtrLo
        lda     PowerUpEffectHandlers+1,y
        sta     ScratchPtrHi
        pla
        pla
        jmp     (ScratchPtrLo)

AdvancePowerUpCollectorScan:
LE9DD:  dec     PowerUpCollectorSlot
        bpl     CheckPowerUpTankOverlap
FinishPowerUpPickupScan:
LE9E1:  rts

; Восемь адресов обработчиков, индекс PowerUpType*2. Номера намеренно не
; получают предположительных игровых имён: комментарии самих обработчиков
; описывают различное действие для игрока и противника.
PowerUpEffectHandlers:
LE9E2:  .word   PowerUpEffect0,PowerUpEffect1,PowerUpEffect2,PowerUpEffect3
        .word   PowerUpEffect4,PowerUpEffect5,PowerUpEffect6,PowerUpEffect7
