; Диспетчер одного logic tick и полусекундная фаза ($C2E6-$C330).

; Один полный шаг игровой логики: игроки, танки, снаряды, столкновения, бонусы,
; появление противников и расширения Tank 1990.
; Хвостовым JMP передаётся UpdateTank1990Extensions. Почти вся игровая RAM и A/X/Y могут измениться;
; PPU-очередь, OAM shadow и состояния аудиопотоков также могут быть обновлены.
RunGameplayLogicTick:
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
        jsr     UpdateProjectileProjectileCollisions
        jsr     UpdateProjectileTankCollisions
        jsr     UpdatePowerUpPickup
        jsr     UpdateTransitionObject
        jsr     UpdatePlayerMovementAudio
        jsr     UpdateLivesHud
        jmp     UpdateTank1990Extensions

; Недостижимый байт RTS между процедурами; статических ссылок нет.
UnreferencedRtsByteC31c:
        .byte   $60
; На фазах FrameCounter mod 64 = 0/32 записывает в $4D значения 2/1; на прочих кадрах не меняет $4D.
; Портит A и флаги; X/Y и прочая RAM не меняются.
UpdateHalfSecondPhaseFlag:
LC31D:  lda     FrameCounter
        and     #$3F
        beq     SelectFirstHalfSecondPhase
        cmp     #$20
        bne     KeepHalfSecondPhase
        lda     #$01
        sta     BackgroundPaletteIndex
        rts

SelectFirstHalfSecondPhase:
LC32C:  lda     #$02
        sta     BackgroundPaletteIndex
KeepHalfSecondPhase:
LC330:  rts
