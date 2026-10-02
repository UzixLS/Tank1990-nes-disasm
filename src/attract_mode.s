; Подготовка и кадровый цикл attract mode ($C3B5-$C44A).

AttractRuntimeStageNumber      = $1E
AttractAudioMutePauseState     = $01
AttractBackgroundPalette       = $00
AttractForcedPlayer2Lives      = $03
AttractVariantTitleRasterX     = $1A
AttractVariantTitleRasterY     = $46
AttractEditionYearRasterX      = $3C
AttractEditionYearRasterY      = $78
AttractExitButtonMask          = BUTTON_SELECT | BUTTON_START

; Готовит демо-этап: сохраняет обе score records и лишь частично переинициализирует
; сессию. Sentinel-path LoadAndDrawStage строит classic map 32 из полного
; 36-stage descriptor, после чего здесь устанавливается отдельный логический
; StageNumber=30. На экране поэтому показан stage 30; значение >=12 выбирает
; позднее распределение attributes врагов и нулевой EnemyActivityInterval, а
; значение >=26 допускает вероятностный runtime integrity guard в demo-loop.
;
; StageSetLength=2 после загрузки уже не длина набора, а attract-маркер: он
; включает P2 HUD, запрещает начисление очков за врагов и transition object.
; InitializeSessionPreservingScores в single-player обнуляет жизни P2, поэтому
; здесь принудительно возвращаются три жизни: InitializeStageRuntime создаёт оба
; управляемых demo-AI танка. Жизни P1 остаются результатом SelectInitialLifeCount.
;
; PauseState=1 ограничивает audio engine только потоком pause. При штатном входе
; этот поток выключен, поэтому demo беззвучно; запросы остальных потоков могут
; оставаться выставленными, но не обрабатываются. Сам demo-loop PauseState не проверяет и
; продолжает игровую логику. Процедура рисует заголовок варианта и год, строит
; runtime/HUD, передаёт последнюю очередь ограждения базы через NMI и только
; затем устанавливает GameMode=OnePlayerGameMode.
; Предусловие штатного frontend-вызова:
; NametablePpuOffset=ShadowToPrimaryNametableOffset, оставленный
; ClearPrimaryNametableScreen; здесь offset перед upload не задаётся.
; Сохраняет score records, но прочая session RAM переинициализируется не полностью:
; жизни P1 всё ещё зависят от SelectInitialLifeCount. Выход:
; A=GameMode=OnePlayerGameMode, PauseState=AttractAudioMutePauseState,
; StageNumber=AttractRuntimeStageNumber, StageSetLength=AttractStageSetMarker;
; оба player-объекта находятся в spawn state, X/Y не определены. Меняет
; session/game RAM, audio requests, shadow/PPU/OAM и кадровые счётчики.
InitializeAttractMode:
LC3B5:  lda     #AttractAudioMutePauseState
        sta     PauseState
        lda     #AttractBackgroundPalette
        sta     BackgroundPaletteIndex
        jsr     InitializeSessionPreservingScores
        lda     #AttractForcedPlayer2Lives
        sta     Player2Lives
        lda     #$00
        sta     VerticalScroll
        sta     NametableBits
        sta     SlowFrameCounter
        sta     FrameCounter
        jsr     InitializePlayfieldRectangle
        lda     #AttractStageLoadSentinel
        sta     StageNumber
        jsr     LoadAndDrawStage
        lda     #AttractRuntimeStageNumber
        sta     StageNumber
        lda     #AttractStageSetMarker
        sta     StageSetLength
        jsr     DisableRenderingForBulkUpdate
        ldx     #AttractVariantTitleRasterX
        stx     RasterStringX
        ldy     #AttractVariantTitleRasterY
        sty     RasterStringY
        jsr     DrawVariantTitleData
; Восемь исполняемых NOP не меняют состояние и не имеют внутренних entry points.
; Их исходное назначение неизвестно; они сохранены для byte identity и адресов.
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        ldx     #AttractEditionYearRasterX
        stx     RasterStringX
        ldy     #AttractEditionYearRasterY
        sty     RasterStringY
        lda     #>EditionYearText
        sta     AuxPtrHi
        lda     #<EditionYearText
        sta     AuxPtrLo
        jsr     RasterizeTileStringToShadow
        jsr     UploadNametableBuffer
        jsr     EnableNmiAfterVblank
        jsr     InitializeStageRuntime
        jsr     DrawBrickBaseEnclosure
        jsr     WaitForNextFrame
        lda     #OnePlayerGameMode
        sta     GameMode
        rts

; Кадровый цикл демо: после NMI сначала проверяет реальный P1 input. Только
; SELECT/START выходят; физические A/B/D-pad затем полностью перезаписываются
; GenerateAttractModeInput для обоих игроков. Выполняются обычный полный logic
; tick и render passes независимо от PauseState.
;
; Любой исход CheckStageLoopFinished немедленно завершает demo: победа по нулю
; врагов не создаёт transition object, а поражение успевает его инициализировать,
; но отдельный transition loop здесь не запускается. Ещё не исполненная
; PPU-очередь отбрасывается, A=0 возвращается frontend caller, который начнёт
; следующий title/attract cycle; этот обычный путь сам экран/audio не очищает.
; SELECT/START снимают со стека двухбайтный адрес возврата от JSR RunAttractMode,
; отбрасывают PPU-очередь, очищают экран и хвостом переходят в EnterTitleMenu;
; этот путь не возвращается и допустим только из штатного frontend continuation.
; Портит игровую RAM, shadow/PPU/OAM/audio state и A/X/Y.
RunAttractMode:
LC41D:  jsr     WaitForNextFrame
        lda     Joy1Pressed
        and     #AttractExitButtonMask
        bne     ExitAttractModeToTitle
        jsr     GenerateAttractModeInput
        jsr     RunGameplayLogicTick
        jsr     DrawAndExpirePowerUp
        jsr     DrawTanks
        jsr     DrawProjectiles
        jsr     CheckStageLoopFinished
        beq     RunAttractMode
        lda     #$00
        sta     PpuBufferPos
        rts

ExitAttractModeToTitle:
LC43F:  pla
        pla
        lda     #$00
        sta     PpuBufferPos
        jsr     ClearPrimaryNametableScreen
        jmp     EnterTitleMenu
