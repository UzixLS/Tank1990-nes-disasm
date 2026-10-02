; Диспетчер одного logic tick и полусекундная фаза ($C2E6-$C330).

HalfSecondFrameMask        = $3F
SecondHalfSecondFrame      = $20
FirstHalfSecondPhaseValue  = $02
SecondHalfSecondPhaseValue = $01

; Один полный шаг игровой логики: игроки, танки, снаряды, столкновения, бонусы,
; появление противников и расширения Tank 1990.
; Хвостовым JMP передаётся UpdateTank1990Extensions: его RTS возвращает сразу
; вызывающему RunGameplayLogicTick. Почти вся игровая RAM и A/X/Y могут измениться;
; PPU-очередь, OAM shadow и состояния аудиопотоков также могут быть обновлены.
RunGameplayLogicTick:
        ; Между Mark/Clear нельзя вставлять shadow->PPU transfer: bit7 terrain
        ; в этом окне является transient collision occupancy, а не tile data.
LC2E6:  jsr     MarkTankOccupiedTiles
        jsr     UpdatePlayerTankInput
        jsr     UpdateTanks
        jsr     ClearTankOccupiedTiles
        jsr     UpdateProjectiles
        jsr     UpdateBaseEffects
        jsr     UpdatePlayerShieldEffects
        jsr     UpdatePlayerFiring
        jsr     UpdateEnemyFiring
        jsr     SpawnPendingEnemyTank
        jsr     UpdateProjectileTerrainCollisions
        jsr     UpdateProjectilePairCollisions
        jsr     UpdateProjectileTankCollisions
        jsr     UpdatePowerUpPickup
        jsr     UpdateTransitionObject
        jsr     UpdatePlayerMovementAudio
        jsr     UpdateLivesHud
        jmp     UpdateTank1990Extensions

; Недостижимый байт RTS между процедурами; статических ссылок нет.
UnreferencedRtsByteC31c:
        .byte   $60
; На фазах FrameCounter mod 64 = 0/32 записывает в BackgroundPaletteIndex
; значения 2/1; на прочих кадрах не меняет его. Выход: X/Y сохраняются;
; A=2/1 на точных фазах, иначе A=FrameCounter&HalfSecondFrameMask.
; Портит флаги; прочую RAM не меняет.
UpdateHalfSecondPhaseFlag:
LC31D:  lda     FrameCounter
        and     #HalfSecondFrameMask
        beq     SelectFirstHalfSecondPhase
        cmp     #SecondHalfSecondFrame
        bne     KeepHalfSecondPhase
        lda     #SecondHalfSecondPhaseValue
        sta     BackgroundPaletteIndex
        rts

SelectFirstHalfSecondPhase:
LC32C:  lda     #FirstHalfSecondPhaseValue
        sta     BackgroundPaletteIndex
KeepHalfSecondPhase:
LC330:  rts
