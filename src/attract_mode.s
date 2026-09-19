; Подготовка и кадровый цикл attract mode ($C3B5-$C44A).

AttractRuntimeStageNumber      = $1E
AttractAudioMutePauseState     = $01
AttractBackgroundPalette       = $00
AttractPlayer2Lives            = $03
AttractVariantTitleRasterX     = $1A
AttractVariantTitleRasterY     = $46
AttractEditionYearRasterX      = $3C
AttractEditionYearRasterY      = $78
AttractExitButtonMask          = BUTTON_SELECT | BUTTON_START

; Готовит демо-этап: сохраняет score records и частично переинициализирует сессию;
; special-path загрузчика строит карту classic stage 32, после чего процедура
; выставляет логический StageNumber=30 и StageSetLength=2 как attract-маркер.
; Логический номер влияет не только на HUD, но и на stage runtime/checksum guard.
; Принудительные три жизни P2 нужны,
; чтобы InitializeStageRuntime создал оба управляемых demo-AI танка. Ненулевой
; PauseState ограничивает audio engine pause-потоком, но сам demo-loop не
; проверяет паузу и продолжает игровую логику. Рисует заголовок варианта/год,
; инициализирует runtime и возвращает с GameMode=OnePlayerGameMode.
; Предусловие штатного frontend-вызова: NametablePpuOffset=$1C, оставленный
; ClearPrimaryNametableScreen; здесь offset перед UploadNametableBuffer не задаётся.
; Сохраняет score records, но прочая session RAM переинициализируется не полностью:
; жизни P1 всё ещё зависят от SelectInitialLifeCount. Выход:
; A=GameMode=OnePlayerGameMode, PauseState=AttractAudioMutePauseState,
; StageNumber=AttractRuntimeStageNumber, StageSetLength=AttractStageSetMarker;
; два player-объекта созданы, X/Y не определены; меняет session/game RAM и shadow/PPU.
InitializeAttractMode:
LC3B5:  lda     #AttractAudioMutePauseState
        sta     PauseState
        lda     #AttractBackgroundPalette
        sta     BackgroundPaletteIndex
        jsr     InitializeSessionAfterScoreRecords
        lda     #AttractPlayer2Lives
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

; Кадровый цикл демо: после NMI сначала проверяет реальный P1 input для выхода,
; затем GenerateAttractModeInput перезаписывает Joy1/Joy2 синтетическим вводом
; и выполняются обычные logic/render passes. PauseState здесь не проверяется.
; При штатном завершении этапа отбрасывает ещё не исполненные PPU-команды и
; возвращается вызывающему с A=0; экран и audio очищает уже frontend caller.
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
