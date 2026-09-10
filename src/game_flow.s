; Восемь байтов ASCII "COPYRIGH" перед первой процедурой банка.
Prg1CopyrightPrefix:
        .byte   $43,$4F,$50,$59,$52,$49,$47,$48
BootHook:
; Вход: X — начало восьмибайтной записи. Очищает её и записывает загрузочный маркер $AB в $46.
; Вызывается InitializeCoreRuntime при несовпадении RAM-маркера; портит A/X и флаги.
        jsr     ResetEightByteRecord
        lda     #$AB
        sta     GameVariant
        rts

; Включает NMI и обрабатывает загрузочный маркер $46. Если это $AB, открывает экран выбора варианта.
; Портит A и PPU_CTRL; обработчик маркера может изменить большую часть UI-состояния.
EnableNmiAndHandleBootMarker:
LC010:  jsr     EnableNmiAfterVblank
        lda     GameVariant
        jsr     HandleBootVariantMarker
        rts

; Маршрутизирует ввод огня игрока X в FirePlayerProjectile либо
; AdvancePlayerFiringLoop.
; В обычных режимах A срабатывает по фронту, B — по удержанию; в GameMode=6 любая из A/B — по фронту.
; Не возвращается; портит A и флаги, X остаётся индексом игрока.
DispatchPlayerFireInput:
LC019:  lda     GameMode
        cmp     #$06
        beq     LC031
        lda     Joy1Pressed,x
        and     #BUTTON_A
        bne     LC02B
        lda     Joy1Held,x
        and     #BUTTON_B
        beq     LC02E
LC02B:  jmp     FirePlayerProjectile

LC02E:  jmp     AdvancePlayerFiringLoop

LC031:  lda     Joy1Pressed,x
        and     #(BUTTON_A | BUTTON_B)
        beq     LC02E
        jmp     FirePlayerProjectile

ByteToDecimalInput = $00
ByteToDecimalDigits:
; Вход: ByteToDecimalInput — байт 0..255, DecimalHundreds/Tens заранее обнулены.
; Выход: DecimalHundreds/Tens/Ones — десятичные цифры.
; Портит A и флаги; X/Y не меняет. Не обнуляет $39/$3A самостоятельно.
        lda     ByteToDecimalInput
LC03C:  cmp     #$64
        bcc     LC048
LC040:  sec
        sbc     #$64
        inc     DecimalHundreds
        jmp     LC03C

LC048:  cmp     #$0A
        bcc     LC054
        sec
        sbc     #$0A
        inc     DecimalTens
        jmp     LC048

LC054:  sta     DecimalOnes
        rts

; 25-байтная авторская строка; не завершена $FF и не имеет прямых ссылок.
UnreferencedAuthorText:
        .byte   $49,$20,$48,$59,$4F,$55,$44,$4F
        .byte   $55,$4A,$55,$4E,$4B,$4F,$20,$4F
        .byte   $5A,$41,$57,$41,$20,$20,$20,$20
        .byte   $20

ResetHandler:
; RESET/IRQ entry: запрещает IRQ, отключает NMI/рендеринг, ждёт два vblank, ставит SP=$6F и полностью
; инициализирует рабочее состояние, PPU, OAM и звук. Затем запускает цикл заглавного экрана,
; демо и меню. Не возвращается; все регистры и RAM считаются изменёнными.
        sei
        lda     #$10
        sta     PPU_CTRL
        cld
        ldx     #$02
LC079:  lda     PPU_STATUS
        bpl     LC079
        lda     #$06
        sta     PPU_MASK
        dex
        bne     LC079
        ldx     #$6F
        txs
        jsr     ResetExtensionState
        lda     #$00
        sta     VerticalScroll
        sta     NametableBits
MainFrontendLoop:
; Верхнеуровневый UI-цикл: строит title nametable, прокручивает заставку,
; обслуживает меню и attract mode. Не возвращается; каждый полный перезапуск
; очищает признак Construction-карты. Меняет всё состояние UI/PPU и A/X/Y.
LC092:  jsr     EnableNmiAndHandleBootMarker
RebuildTitleNametable:
LC095:  jsr     BuildTitleNametable
        lda     #$00
        sta     ConstructionMapFlag
RestartTitleAttractCycle:
LC09C:  jsr     ClearPrimaryNametableScreen
        jsr     ScrollIntroUntilInput
EnterTitleMenu:
LC0A2:  jsr     TitleScreen
        jsr     InitializeAttractMode
        jsr     RunAttractMode
        jmp     RestartTitleAttractCycle

; Редактор Construction: перемещает курсор, меняет TSA-блок и затем
; возвращается в общий игровой цикл.
ConstructionMetatileIndex    = $5C
ConstructionMoveRepeatTimer = $7B
ConstructionEditLatch        = $81
ConstructionMode:
; Вход: ConstructionMapFlag=0 для первичной отрисовки. Объект 0 используется как мигающий курсор.
; D-pad двигает его по сетке 16 px; A/B выбирают TSA $00..$0D и вызывают DrawMetatile.
; START поднимает ConstructionMapFlag и
; возвращается в главное меню. Меняет объект 0, тень nametable, PPU-очередь и рабочую RAM; портит A/X/Y.
LC0AE:  lda     ConstructionMapFlag
        bne     LC0BE
        jsr     DisableRenderingForBulkUpdate
        jsr     InitializePlayfieldRectangle
        jsr     UploadNametableBuffer
        jsr     EnableNmiAfterVblank
LC0BE:  jsr     ClearTankStates
        lda     #$10
        sta     ObjectX
        lda     #$18
        sta     ObjectY
        lda     #$84
        sta     ObjectState
        lda     #$00
        sta     ObjectAttributes
        sta     SpriteBehindTerrainMask
        sta     ObjectFrame
        sta     ConstructionEditLatch
        sta     ConstructionMoveRepeatTimer
        sta     ConstructionMetatileIndex
        sta     VerticalScroll
        sta     NametableBits
        sta     PlayerStunTimer
        sta     PlayerStunTimer+1
        lda     ConstructionMapFlag
        bne     LC0EA
        jsr     DrawBrickBaseEnclosure
LC0EA:  jsr     WaitForNextFrame
        jsr     UpdateConstructionCursor
        jsr     ClampConstructionCursor
        lda     FrameCounter
        and     #$10
        beq     LC0FC
        jsr     DrawTanks
LC0FC:  lda     Joy1Held
        and     #BUTTON_DIRECTIONS
        bne     LC13E
        lda     Joy1Pressed
        and     #BUTTON_A
        beq     LC120
        lda     ConstructionEditLatch
        bne     LC111
        inc     ConstructionEditLatch
        jmp     LC144

LC111:  inc     ConstructionMetatileIndex
        lda     ConstructionMetatileIndex
        cmp     #$0E
        bne     LC144
        lda     #$00
        sta     ConstructionMetatileIndex
        jmp     LC144

LC120:  lda     Joy1Pressed
        and     #BUTTON_B
        beq     LC13E
        lda     ConstructionEditLatch
        bne     LC12F
        inc     ConstructionEditLatch
        jmp     LC144

LC12F:  dec     ConstructionMetatileIndex
        lda     ConstructionMetatileIndex
        cmp     #$FF
        bne     LC144
        lda     #$0D
        sta     ConstructionMetatileIndex
        jmp     LC144

LC13E:  lda     Joy1Held
        and     #(BUTTON_A | BUTTON_B)
        beq     LC147
LC144:  jsr     DrawConstructionMetatile
LC147:  lda     Joy1Pressed
        and     #BUTTON_START
        bne     LC150
        jmp     LC0EA

LC150:  lda     #$20
        sta     SpriteBehindTerrainMask
        inc     ConstructionMapFlag
        jmp     EnterTitleMenu

; Экран выбора этапа. Удержание A/B повторяет изменение через
; FrameCounter, START подтверждает StageNumber.
SelectStage:
; Вход: StageNumber — текущий этап, ConstructionMapFlag!=0 обозначает карту Construction.
; A/B листают этапы с автоповтором,
; START подтверждает. Далее загружает/рисует карту, инициализирует объекты и выполняет кадровый цикл до исхода этапа.
; Меняет почти всё игровое состояние, PPU/OAM/APU и A/X/Y; в обычном потоке не возвращается к вызывающему.
LC159:  jsr     WaitForNextFrame
        jsr     ResetAudioEngine
        lda     #$1C
        sta     NametablePpuOffset
        lda     #$00
        sta     VerticalScroll
        sta     NametableBits
        sta     PauseState
        lda     #$04
        sta     BackgroundPaletteIndex
        jsr     CloseNametableCurtain
StageSelectionInputLoop:
; Кадровый цикл выбора: обновляет надпись, A увеличивает StageNumber, B уменьшает;
; удержание повторяется раз в восемь кадров. Обычный диапазон циклически равен
; 1..50. Вариант 6 использует 1..118; его AdvanceStageNumber возвращается сюда
; нестандартно, снимая с аппаратного стека собственный адрес возврата.
; StageSelectionLocked!=0 или START передаёт управление BeginSelectedStage.
; Вход: StageNumber, StageSelectionLocked и Joy1*. Не возвращается самостоятельно.
; Меняет StageNumber, FrameCounter и PPU-очередь; портит A и флаги, X/Y зависят
; от UpdateStageNumberDisplay/AdvanceStageNumber/WrapStageNumberBackward.
LC172:  jsr     UpdateStageNumberDisplay
        lda     StageSelectionLocked
        bne     BeginSelectedStage
        lda     Joy1Pressed
        and     #BUTTON_START
        bne     BeginSelectedStage
        lda     Joy1Pressed
        and     #BUTTON_A
        bne     AdvanceStageSelection
        lda     Joy1Held
        and     #BUTTON_A
        beq     CheckStageSelectionBackward
        lda     FrameCounter
        and     #$07
        bne     CheckStageSelectionBackward
AdvanceStageSelection:
LC191:  lda     #$00
        sta     FrameCounter
        jsr     AdvanceStageNumber
        nop
        cmp     #$33
        bne     StageSelectionInputLoop
        lda     #$01
        sta     StageNumber
        jmp     StageSelectionInputLoop

CheckStageSelectionBackward:
LC1A4:  lda     Joy1Pressed
        and     #BUTTON_B
        bne     RetreatStageSelection
        lda     Joy1Held
        and     #BUTTON_B
        beq     StageSelectionInputLoop
        lda     FrameCounter
        and     #$07
        bne     StageSelectionInputLoop
RetreatStageSelection:
LC1B6:  lda     #$00
        sta     FrameCounter
        dec     StageNumber
        bne     StageSelectionInputLoop
        jsr     WrapStageNumberBackward
        nop
        jmp     StageSelectionInputLoop

; Подтверждён этап: запрашивает три потока вступительной музыки, рисует
; обычную или уже построенную Construction-карту и запускает игру.
; Вход: StageNumber и ConstructionMapFlag. Не возвращается: после подготовки
; переходит в MainGameplayFrameLoop. Меняет PPU/shadow, игровые объекты,
; состояния трёх аудиопотоков и A/X/Y.
BeginSelectedStage:
LC1C5:  lda     #AudioStateStartRequested
        sta     StageIntroPulse1AudioState
        sta     StageIntroTriangleAudioState
        sta     StageIntroPulse2AudioState
        lda     ConstructionMapFlag
        bne     LC1E2
        jsr     InitializePlayfieldRectangle
        lda     StageNumber
        jsr     LoadAndDrawStage
        jsr     DrawBrickBaseEnclosure
        jmp     LC1E5

LC1E2:  jsr     DrawBareBase
LC1E5:  lda     #$00
        sta     PpuBufferPos
        jsr     UploadAttributesGradually
        jsr     OpenNametableCurtain
        lda     #$00
        sta     BackgroundPaletteIndex
        jsr     WaitForNextFrame
        jsr     InitializeStageRuntime
; Основной кадровый цикл. PauseState!=0 приостанавливает игровую логику, но
; оставляет отрисовку; START переключает паузу и её аудиопоток. При завершении
; этапа сбрасывает loop-аудио и входит в TransitionObjectFrameLoop.
; Не возвращается; меняет игровую RAM, PPU/OAM/audio state и A/X/Y.
MainGameplayFrameLoop:
LC1F9:  jsr     WaitForNextFrame
        lda     PauseState
        bne     LC203
        jsr     RunGameplayLogicTick
LC203:  jsr     DrawAndExpirePowerUp
        jsr     DrawProjectiles
        jsr     DrawTanks
        lda     Joy1Pressed
        and     #BUTTON_START
        beq     LC21B
        lda     #$01
        eor     PauseState
        sta     PauseState
        sta     PauseAudioState
LC21B:  jsr     DrawPauseOverlay
        jsr     CheckStageLoopFinished
        beq     LC1F9
        lda     #$00
        sta     SlowFrameCounter
        sta     FrameCounter
        sta     PlayerMovementLoopAudioState
        sta     GameplayLoopAudioState
        lda     TransitionObjectTimer
        beq     LC238
        lda     #$FE
        sta     SlowFrameCounter
; Анимация/задержка после исхода этапа. Продолжает логику и рендеринг, пока
; SlowFrameCounter не станет 2.
TransitionObjectFrameLoop:
LC238:  jsr     WaitForNextFrame
        jsr     SuppressInputOutsideActiveStage
        jsr     RunGameplayLogicTick
        jsr     DrawAndExpirePowerUp
        jsr     DrawTanks
        jsr     DrawProjectiles
        jsr     UpdateHalfSecondPhaseFlag
        lda     SlowFrameCounter
        cmp     #$02
        bne     LC238
        jsr     ResetAudioEngine
        jsr     ShowStageStatistics
        inc     StageNumber
        lda     StageNumber
        cmp     #$FF
        bne     LC265
        lda     #$01
        sta     StageNumber
; После сброса звука и экрана результата выбирает продолжение, секретный continue или возврат в главное меню.
ResolveStageOutcome:
LC265:  lda     Player1Lives
        clc
        adc     Player2Lives
        beq     LC283
        lda     BattleState
        cmp     #BattleStateActive
        bne     LC283
        jmp     HandleSecretContinueChord

; Альтернативный хвост продолжения: ожидает в A жизни P1, добавляет Player2Lives и при $68=$80 переходит в SelectStage.
; Прямых ссылок на LC275 нет; при неуспехе проваливается в общий возврат к главному меню.
UnusedContinueTail:
LC275:  clc
        adc     Player2Lives
        beq     LC283
        lda     BattleState
        cmp     #BattleStateActive
        bne     LC283
        jmp     SelectStage
LC283:  jsr     ClearScreenAndAudio
        jsr     UpdateHighScoreRecord
        tya
        beq     LC292
        jsr     ShowSessionResultScreen
        jsr     ClearScreenAndResumeNmi
LC292:  jmp     RebuildTitleNametable

; Гасит рендеринг, очищает shadow RAM, загружает её в текущую nametable,
; выбранную через $05, и снова включает NMI.
; Портит A/X и PPU state; Y не гарантируется из-за вызываемых процедур.
ClearScreenAndResumeNmi:
LC295:  jsr     DisableRenderingForBulkUpdate
        jsr     ClearNametableBuffer
        jsr     UploadNametableBuffer
        jsr     EnableNmiAfterVblank
        rts

; Обнуляет held/pressed обоих контроллеров, если $68!=$80. Портит A и флаги.
SuppressInputOutsideActiveStage:
LC2A2:  lda     BattleState
        cmp     #BattleStateActive
        beq     LC2B2
        lda     #$00
        sta     Joy1Held
        sta     Joy2Held
        sta     Joy1Pressed
        sta     Joy2Pressed
LC2B2:  rts

; Сбрасывает записи двух игроков и общие счётчики новой игровой сессии.
InitializeGameSession:
; Очищает две восьмибайтные записи игроков, пересчитывает integrity-сумму, сбрасывает session-флаги,
; задаёт обоим игрокам выбранное число жизней, а в single-player обнуляет Player2Lives. StageNumber=1.
; Портит A/X/Y, $11/$12 и перечисленную RAM; PPU/OAM/APU не трогает.
LC2B3:  ldx     #$15
        jsr     ResetEightByteRecord
        ldx     #$1D
        jsr     ResetEightByteRecord
; Альтернативный вход пропускает очистку двух записей счёта; используется attract mode.
InitializeSessionAfterScoreRecords:
LC2BD:  jsr     InitializePlayerVariantAttributes
        jsr     InitializeRuntimeChecksumGuard
        lda     #$00
        sta     PlayerExtraLifeAwarded
        sta     PlayerExtraLifeAwarded+1
        sta     StageSelectionLocked
        jsr     SelectInitialLifeCount
        nop
        sta     Player1Lives
        sta     Player2Lives
        sta     EnemySpawnColumn
        lda     MenuSelection
        bne     LC2DD
        lda     #$00
        sta     Player2Lives
LC2DD:  lda     #$01
        sta     StageNumber
        nop
        nop
        nop
        nop
        rts

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
        beq     LC32C
        cmp     #$20
        bne     LC330
        lda     #$01
        sta     BackgroundPaletteIndex
        rts

LC32C:  lda     #$02
        sta     BackgroundPaletteIndex
LC330:  rts

; Инициализирует рабочее состояние выбранного этапа: очищает танки/снаряды, создаёт танки живых игроков,
; задаёт 20 врагов в $7F/$80, сбрасывает таймеры/флаги, рисует HUD и включает активную фазу $68=$80.
; Для этапов 1..11 выбирает псевдослучайный EnemyActivityInterval из
; EarlyStageSpawnDelayTable, для поздних — 0.
; Меняет объекты, HUD/PPU-очередь, RNG и рабочую RAM; портит A/X/Y.
InitializeStageRuntime:
LC331:  jsr     ClearProjectileStates
        jsr     ClearTankStates
        lda     #$F0
        sta     TransitionObjectY
        lda     #$00
        sta     TransitionObjectTimer
        lda     Player1Lives
        beq     LC34A
        ldx     #$00
        jsr     SpawnTank
LC34A:  lda     Player2Lives
        beq     LC353
        ldx     #$01
        jsr     SpawnTank
LC353:  lda     #$14
        sta     EnemiesToSpawn
        sta     EnemiesRemaining
        lda     #$00
        nop
        nop
        sta     SlowFrameCounter
        sta     ConstructionMapFlag
        sta     BaseFortificationTimer
        sta     PlayerStunTimer
        sta     PlayerStunTimer+1
        sta     PlayerShieldTimer
        sta     PlayerShieldTimer+1
        sta     EnemySpawnTimer
        sta     PowerUpX
        sta     EnemyFreezeTimer
        sta     EnemySpawnColumn
        jsr     ClearStageWorkBytes
        jsr     InitializeRemainingEnemyMarkers
        jsr     WaitForNextFrame
        jsr     DrawPlayerHudLabels
        jsr     DrawStageNumberHud
        nop
        nop
        nop
        lda     #BattleStateActive
        sta     BattleState
        lda     #AudioStateStartRequested
        sta     GameplayLoopAudioState
        sta     StageSelectionLocked
        lda     StageNumber
        cmp     #$0C
        bcc     LC39C
        lda     #$00
        sta     EnemyActivityInterval
        rts

LC39C:  lda     #$0C
        sec
        sbc     StageNumber
        sta     EnemyActivityInterval
        jsr     NextRandomByte
LC3A6:  cmp     EnemyActivityInterval
        bcc     LC3AE
        sbc     EnemyActivityInterval
        bcs     LC3A6
LC3AE:  tax
        lda     EarlyStageSpawnDelayTable,x
        sta     EnemyActivityInterval
        rts

; Готовит демо-этап для attract mode: сбрасывает сессию, загружает служебную карту StageNumber=$FF,
; затем ставит StageNumber=$1E, StageSetLength=2, рисует демо-экран и запускает игру с GameMode=5.
; Меняет всю session/game RAM, PPU/OAM и A/X/Y.
InitializeAttractMode:
LC3B5:  lda     #$01
        sta     PauseState
        lda     #$00
        sta     BackgroundPaletteIndex
        jsr     InitializeSessionAfterScoreRecords
        lda     #$03
        sta     Player2Lives
        lda     #$00
        sta     VerticalScroll
        sta     NametableBits
        sta     SlowFrameCounter
        sta     FrameCounter
        jsr     InitializePlayfieldRectangle
        lda     #$FF
        sta     StageNumber
        jsr     LoadAndDrawStage
        lda     #$1E
        sta     StageNumber
        lda     #$02
        sta     StageSetLength
        jsr     DisableRenderingForBulkUpdate
        ldx     #$1A
        stx     RasterStringX
        ldy     #$46
        sty     RasterStringY
        jsr     DrawVariantTitleData
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        ldx     #$3C
        stx     RasterStringX
        ldy     #$78
        sty     RasterStringY
        lda     #$E5
        sta     AuxPtrHi
        lda     #$E0
        sta     AuxPtrLo
        jsr     RasterizeTileStringToShadow
        jsr     UploadNametableBuffer
        jsr     EnableNmiAfterVblank
        jsr     InitializeStageRuntime
        jsr     DrawBrickBaseEnclosure
        jsr     WaitForNextFrame
        lda     #$05
        sta     GameMode
        rts

; Кадровый цикл демо-режима. Генерирует ввод ботов и выполняет обычные шаги логики/отрисовки до исхода этапа.
; SELECT/START снимают адрес возврата со стека, очищают экран и сразу возвращаются к title. Портит всю game RAM и A/X/Y.
RunAttractMode:
LC41D:  jsr     WaitForNextFrame
        lda     Joy1Pressed
        and     #(BUTTON_SELECT | BUTTON_START)
        bne     LC43F
        jsr     GenerateAttractModeInput
        jsr     RunGameplayLogicTick
        jsr     DrawAndExpirePowerUp
        jsr     DrawTanks
        jsr     DrawProjectiles
        jsr     CheckStageLoopFinished
        beq     LC41D
        lda     #$00
        sta     PpuBufferPos
        rts

LC43F:  pla
        pla
        lda     #$00
        sta     PpuBufferPos
        jsr     ClearPrimaryNametableScreen
        jmp     EnterTitleMenu

; Показывает экран нового рекорда/окончания сессии, запускает три потока
; музыки результата и ждёт завершения pulse-1 потока.
; В цикле меняет $4D от 5 до 8 по младшим битам FrameCounter. Меняет nametable/PPU и рабочую RAM; портит A/X/Y.
ShowSessionResultScreen:
LC44B:  jsr     DisableRenderingForBulkUpdate
        lda     #$1C
        sta     NametablePpuOffset
        lda     #$00
        sta     VerticalScroll
        sta     NametableBits
        jsr     ClearNametableBuffer
        ldx     #$10
        stx     RasterStringX
        ldy     #$32
        sty     RasterStringY
        lda     #$D2
        sta     AuxPtrHi
        lda     #$B5
        sta     AuxPtrLo
        jsr     RasterizeTileStringToShadow
        jsr     RenderLargeScoreRecord
        jsr     UploadNametableBuffer
        jsr     EnableNmiAfterVblank
        lda     #$00
        sta     SlowFrameCounter
        lda     #AudioStateStartRequested
        sta     SessionResultPulse1AudioState
        sta     SessionResultPulse2AudioState
        sta     SessionResultTriangleAudioState
LC486:  jsr     WaitForNextFrame
        lda     FrameCounter
        and     #$03
        clc
        adc     #$05
        sta     BackgroundPaletteIndex
        lda     SessionResultPulse1AudioState
        bne     LC486
        lda     #$00
        sta     BackgroundPaletteIndex
        rts

; Вход: A — $46. Возвращается без изменений, если A!=$AB; иначе открывает модальное меню вариантов.
HandleBootVariantMarker:
LC49C:  cmp     #$AB
        beq     LC4A1
        rts

VariantMenuRow       = TitleSecretInputCode
VariantMenuTextPtrLo = ConstructionMapFlag

; Рисует пункты вариантов, выбирает GameVariant по Up/Down в двух диапазонах 0..6/$80..$86,
; SELECT переключает AllPowerUpsEnabled. START возвращается. Меняет nametable/PPU-очередь,
; FrameCounter, GameVariant, VariantMenuRow/TextPtrLo и UI-флаги; портит A/X/Y.
RunVariantSelectionMenu:
LC4A1:  lda     #$80
        sta     GameVariant
        jsr     DisableRenderingForBulkUpdate
        lda     #$1C
        sta     NametablePpuOffset
        lda     #$00
        sta     VerticalScroll
        sta     NametableBits
        jsr     ClearNametableBuffer
        jsr     UploadNametableBuffer
        jsr     EnableNmiAfterVblank
        lda     #$C5
        sta     ScratchPtrHi
        lda     #$C9
        sta     ScratchPtrLo
        ldy     #$03
        ldx     #$07
        jsr     QueueTileAtCoordinates
        lda     #$E5
        sta     ScratchPtrHi
        lda     #$EF
        sta     ScratchPtrLo
        ldy     #$04
        ldx     #$07
        jsr     QueueTileAtCoordinates
        lda     #$E5
        sta     ScratchPtrHi
        lda     #$EF
        sta     ScratchPtrLo
        ldy     #$01
        ldx     #$07
        jsr     QueueTileAtCoordinates
        lda     #$01
        sta     AllPowerUpsEnabled
        jsr     DrawSelectedMenuOption
        lda     #<VariantMenuTankNames
        sta     VariantMenuTextPtrLo
        lda     #$00
        sta     MenuSelection
        sta     VariantMenuRow
LC4F9:  lda     #>VariantMenuTankNames
        sta     ScratchPtrHi
        lda     VariantMenuTextPtrLo
        sta     ScratchPtrLo
        clc
        adc     #$08
        sta     VariantMenuTextPtrLo
        lda     VariantMenuRow
        clc
        adc     #$09
        tay
        ldx     #$0D
        jsr     QueueTileAtCoordinates
        jsr     WaitForNextFrame
        inc     VariantMenuRow
        lda     VariantMenuRow
        cmp     #$0E
        bcc     LC4F9
LC51C:  lda     #>VariantMenuSelectionCursor
        sta     ScratchPtrHi
        lda     #<VariantMenuSelectionCursor
        sta     ScratchPtrLo
        jsr     QueueVariantMenuText
LC527:  lda     Joy1Held
        and     #BUTTON_DOWN
        beq     LC545
        jsr     WaitVariantMenuRepeatAndEraseCursor
        inc     GameVariant
        lda     GameVariant
        cmp     #$07
        bne     LC53A
        lda     #$80
LC53A:  cmp     #$87
        bne     LC540
        lda     #$00
LC540:  sta     GameVariant
        jmp     LC51C

LC545:  lda     Joy1Held
        and     #BUTTON_UP
        beq     LC563
        jsr     WaitVariantMenuRepeatAndEraseCursor
        dec     GameVariant
        lda     GameVariant
        cmp     #$FF
        bne     LC558
        lda     #$86
LC558:  cmp     #$7F
        bne     LC55E
        lda     #$06
LC55E:  sta     GameVariant
        jmp     LC51C

LC563:  lda     Joy1Pressed
        and     #BUTTON_SELECT
        beq     LC572
        lda     AllPowerUpsEnabled
        eor     #$01
        sta     AllPowerUpsEnabled
        jsr     DrawSelectedMenuOption
LC572:  lda     Joy1Pressed
        and     #BUTTON_START
        beq     LC527
        rts

; Debounce/autorepeat меню: сбрасывает FrameCounter, ждёт фазу mod16=0,
; запрашивает поток RicochetOrMenuStepAudioState
; и помещает строку $E8B2 в позицию текущего пункта. Портит A/X/Y, ScratchPtr и PPU-очередь.
WaitVariantMenuRepeatAndEraseCursor:
LC579:  lda     #$00
        sta     FrameCounter
LC57D:  jsr     WaitForNextFrame
        lda     FrameCounter
        and     #$0F
        bne     LC57D
        lda     #AudioStateStartRequested
        sta     RicochetOrMenuStepAudioState
        lda     #>VariantMenuBlankCursorText
        sta     ScratchPtrHi
        lda     #<VariantMenuBlankCursorText
        sta     ScratchPtrLo
        jsr     QueueVariantMenuText
        rts

; Два статически неиспользуемых дубля: возвращают A=0, RAM и X/Y не меняют.
ReturnZeroStub1:
LC597:  lda     #$00
        rts
ReturnZeroStub2:
LC59A:  lda     #$00
        rts
; Начальный EnemyActivityInterval для этапов 1..11;
; выбирается из первых 12-StageNumber элементов.
EarlyStageSpawnDelayTable:
LC59D:  .byte   $03,$08,$0D,$12,$17,$1C,$21,$26
        .byte   $2B,$30,$35,$3A
; Битовые поля ObjectAttributes для псевдослучайной инициализации вражеских танков.
EnemyTypeAttributeBits:
LC5A9:  .byte   $80,$A0,$C0,$E0
EnemyLowAttributeBits:
LC5AD:  .byte   $02,$00,$01,$00,$01,$00,$01,$00
; Байты $C5B5..$C5BE лежат между двумя восьмиэлементными таблицами.
; Индекс EnemyLowAttributeBits ограничен 0..7; других статических ссылок на этот нулевой промежуток нет.
UnreferencedC5b5Zeros:
        .byte   $00,$00,$00,$00,$00,$00,$00,$00
        .byte   $00,$00
EnemyBonusAttributeBits:
LC5BF:  .byte   $04,$04,$00,$00,$00,$00,$00,$00
; Два нулевых байта без статических ссылок отделяют таблицу от checksum-блока.
UnreferencedC5c7Prefix:
LC5C7:  .byte   $00,$00
; Семь байт входят в runtime XOR и остаются в ScratchPtr как цель аварийного
; JMP при несовпадении $8D/$8C. Первый байт $40 есть RTI: такой переход не возвращается
; по обычной цепочке JSR. Смысл остальных шести байт отдельно не подтверждён.
RuntimeChecksumFailureTarget:
LC5C9:  .byte   $40,$20,$59,$69,$53,$20,$31
; Хвост после checksum-блока не входит в семибайтный XOR и не имеет подтверждённых ссылок.
UnreferencedC5d0Tail:
LC5D0:  .byte   $39,$39,$30,$69,$32
; Четыре $FF заполняют остаток до следующей процедуры $C5D9.
PaddingBeforeClearScreenAndAudio:
LC5D5:  .byte   $FF,$FF,$FF,$FF
; Гасит рендеринг, очищает nametable shadow/PPU, снова включает NMI и сбрасывает audio engine.
; Портит A/X/Y, PPU/APU и звуковую RAM.
ClearScreenAndAudio:
LC5D9:  jsr     DisableRenderingForBulkUpdate
        lda     #$1C
        sta     NametablePpuOffset
        lda     #$00
        sta     VerticalScroll
        sta     NametableBits
        jsr     ClearNametableBuffer
        jsr     UploadNametableBuffer
        jsr     EnableNmiAfterVblank
        jsr     ResetAudioEngine
        rts

; Вход: Y=0..7 — псевдослучайный номер эффекта. При $8E!=0 возвращает его без изменений,
; иначе применяет RestrictedPowerUpTypeTable, исключающую эффект 7. Выход: A — номер; RAM и X/Y не меняются.
SelectPowerUpTypeForVariant:
LC5F3:  lda     AllPowerUpsEnabled
        beq     LC5FB
        lda     LE8FA,y
        rts

LC5FB:  lda     RestrictedPowerUpTypeTable,y
        rts

PowerUpEffect3:
; Для игрока X<2 и $8E!=0 увеличивает $0178,X на $20, затем всегда переходит в ApplyPowerUpEffect3.
; Для X>=2 или $8E=0 сразу идёт в общую часть. Выходного RTS здесь нет; портит A и флаги.
LC5FF:  cpx     #$02
        bcs     LC610
        lda     AllPowerUpsEnabled
        beq     LC610
        lda     PlayerExtendedUpgrade,x
        clc
        adc     #$20
        sta     PlayerExtendedUpgrade,x
LC610:  jmp     ApplyPowerUpEffect3

PowerUpEffect6:
; Для игрока X<2 и $8E!=0 увеличивает $0178,X на $60, затем переходит в SetMaximumObjectUpgrade.
; Для остальных слотов/вариантов только общая часть. Портит A и флаги.
LC613:  cpx     #$02
        bcs     LC624
        lda     AllPowerUpsEnabled
        beq     LC624
        lda     PlayerExtendedUpgrade,x
        clc
        adc     #$60
        sta     PlayerExtendedUpgrade,x
LC624:  jmp     SetMaximumObjectUpgrade
; Подкладывает в StageNumber верхнюю границу для декремента: $76 при ($46&$0F)=6, иначе $32.
; Выход: A — записанное StageNumber; X/Y не меняются.
WrapStageNumberBackward:
LC627:  lda     GameVariant
        and     #$0F
        cmp     #$06
        beq     LC633
        lda     #$32
        bne     LC635
LC633:  lda     #$76
LC635:  sta     StageNumber
        rts

; Два байта без статических ссылок между RTS и восьмибайтной таблицей.
; Как код они не классифицируются: $20 потребовал бы ещё один байт из RestrictedPowerUpTypeTable.
UnreferencedC638Bytes:
LC638:  .byte   $20,$B4
RestrictedPowerUpTypeTable:
LC63A:  .byte   $00,$01,$02,$03,$03,$04,$05,$06
AttractPlayerSlot = $5A
; Генерирует Joy1/Joy2 для attract mode. Для каждого игрока выбирает цель:
; координаты существующего бонуса при PowerUpPickupDisplayTimer=0, иначе первый
; активный танк из слотов
; X+2, X+4, X+3 (для игроков 0/1 это соответственно 2/4/3 и 3/5/4).
; ChooseTankStateTowardTarget возвращает направление; DemoInputByDirection
; добавляет огонь. Меняет Joy*Held/Pressed, AttractPlayerSlot, TankTargetX/Y
; и work RAM; портит A/X/Y.
GenerateAttractModeInput:
LC642:  lda     #$01
        sta     AttractPlayerSlot
LC646:  ldx     AttractPlayerSlot
        lda     PowerUpX
        beq     LC65E
        lda     PowerUpPickupDisplayTimer
        bne     LC65E
        lda     PowerUpX
        sta     TankTargetX
        lda     PowerUpY
        sta     TankTargetY
        jsr     ChooseTankStateTowardTarget
        jmp     LC6A5

LC65E:  lda     ObjectState+2,x
        bpl     LC674
        cmp     #NonTargetableTankStateMin
        bcs     LC674
        lda     ObjectX+2,x
        sta     TankTargetX
        lda     ObjectY+2,x
        sta     TankTargetY
        jsr     ChooseTankStateTowardTarget
        jmp     LC6A5

LC674:  lda     ObjectState+4,x
        bpl     LC68A
        cmp     #NonTargetableTankStateMin
        bcs     LC68A
        lda     ObjectX+4,x
        sta     TankTargetX
        lda     ObjectY+4,x
        sta     TankTargetY
        jsr     ChooseTankStateTowardTarget
        jmp     LC6A5

LC68A:  lda     ObjectState+3,x
        bpl     LC6A0
        cmp     #NonTargetableTankStateMin
        bcs     LC6A0
        lda     ObjectX+3,x
        sta     TankTargetX
        lda     ObjectY+3,x
        sta     TankTargetY
        jsr     ChooseTankStateTowardTarget
        jmp     LC6A5

LC6A0:  lda     #$00
        jmp     LC6AB

LC6A5:  and     #DirectionMask
        tay
        lda     DemoInputByDirection,y
LC6AB:  ldx     AttractPlayerSlot
        sta     Joy1Held,x
        sta     Joy1Pressed,x
        lda     ObjectY,x
        cmp     #$C8
        bcc     LC6BD
        lda     Joy1Pressed,x
        and     #BUTTON_DIRECTIONS
        sta     Joy1Pressed,x
LC6BD:  dec     AttractPlayerSlot
        bpl     LC646
        rts

DemoInputByDirection:
LC6C2:  .byte   $13,$43,$23,$83
; Рисует в Construction метатайл ConstructionMetatileIndex&$0F в координатах курсора ObjectX/ObjectY.
; Портит A/X/Y и nametable shadow/PPU-очередь через DrawMetatile.
DrawConstructionMetatile:
LC6C6:  lda     ConstructionMetatileIndex
        and     #$0F
        ldx     ObjectX
        ldy     ObjectY
        jsr     DrawMetatile
        rts

; Двигает Construction-курсор на 16 px по фронту D-pad; после 20 кадров удержания включает автоповтор,
; оставляя ConstructionMoveRepeatTimer=$0F между шагами. Меняет ObjectX/ObjectY,
; ConstructionMoveRepeatTimer/ConstructionEditLatch; портит A/Y и флаги, X не меняет.
UpdateConstructionCursor:
LC6D2:  lda     Joy1Held
        and     #BUTTON_DIRECTIONS
        beq     LC6E1
        inc     ConstructionMoveRepeatTimer
        lda     #$00
        sta     ConstructionEditLatch
        jmp     LC6E5

LC6E1:  lda     #$00
        sta     ConstructionMoveRepeatTimer
LC6E5:  lda     ConstructionMoveRepeatTimer
        cmp     #$14
        beq     LC6FB
        lda     Joy1Pressed
        and     #BUTTON_DIRECTIONS
        beq     LC71D
        lda     Joy1Pressed
        jsr     DecodeDirectionButtons
        bmi     LC71D
        jmp     LC704

LC6FB:  lda     #$0F
        sta     ConstructionMoveRepeatTimer
        lda     Joy1Held
        jsr     DecodeDirectionButtons
LC704:  tay
        lda     LD3D5,y
        asl     a
        asl     a
        asl     a
        asl     a
        clc
        adc     ObjectX
        sta     ObjectX
        lda     LD3D9,y
        asl     a
        asl     a
        asl     a
        asl     a
        clc
        adc     ObjectY
        sta     ObjectY
LC71D:  rts

; Обнуляет восемь байт $73..$7A. Выход: A=0, X=$FF; Y и остальная RAM не меняются.
ClearStageWorkBytes:
LC71E:  ldx     #$07
        lda     #$00
LC722:  sta     Player1KillCounts,x
        dex
        bpl     LC722
        rts

; Проверяет условие завершения текущего кадрового цикла.
; Возвращает A=0, если $68!=0, остались враги ($80!=0) и есть хотя бы одна жизнь; иначе A=1.
; При запуске переходной анимации задаёт TransitionObjectX..TransitionObjectTimer
; и сбрасывает FrameCounter. Портит A и флаги.
CheckStageLoopFinished:
LC728:  lda     BattleState
        beq     LC737
        lda     EnemiesRemaining
        beq     LC74F
        lda     Player1Lives
        clc
        adc     Player2Lives
        bne     LC752
LC737:  lda     #$70
        sta     TransitionObjectX
        lda     #$F0
        sta     TransitionObjectY
        lda     #$00
        sta     TransitionObjectDirection
        lda     #$11
        sta     TransitionObjectTimer
        lda     #$00
        sta     FrameCounter
LC74F:  lda     #$01
        rts

LC752:  lda     #$00
        rts

; Статически неиспользуемый RAM-инспектор: рисует индекс $0109 и байт $00+index.
; SELECT/B/A меняют индекс на +1/-1/+16. Портит A/X/Y, ScratchPtr, $39..$3B, PPU-очередь и $0109.
UnusedRamInspector:
LC755:  lda     DebugRamIndex
        jsr     PreparePackedScoreIncrement
        lda     #$30
        sta     TileTranslationOffset
        lda     #$00
        sta     ScratchPtrHi
        lda     #$39
        sta     ScratchPtrLo
        ldx     #$09
        ldy     #$02
        jsr     QueueTranslatedTileString
        ldx     DebugRamIndex
        lda     $00,x
        jsr     PreparePackedScoreIncrement
        lda     #$00
        sta     ScratchPtrHi
        lda     #$39
        sta     ScratchPtrLo
        ldx     #$0D
        ldy     #$02
        jsr     QueueTranslatedTileString
        lda     #$00
        sta     TileTranslationOffset
        lda     Joy1Pressed
        and     #BUTTON_SELECT
        beq     LC792
        inc     DebugRamIndex
LC792:  lda     Joy1Pressed
        and     #BUTTON_B
        beq     LC79B
        dec     DebugRamIndex
LC79B:  lda     Joy1Pressed
        and     #BUTTON_A
        beq     LC7AA
        lda     DebugRamIndex
        clc
        adc     #$10
        sta     DebugRamIndex
LC7AA:  rts
; Прокручивает заставку вертикально от 0 до $F0 по одному пикселю за кадр.
; SELECT/START прерывают вызывающую процедуру через PLA/PLA и переходят в главное меню.
; Меняет VerticalScroll/NametableBits; портит A и флаги.
ScrollIntroUntilInput:
LC7AB:  lda     #$00
        sta     VerticalScroll
        sta     NametableBits
LC7B1:  jsr     WaitForNextFrame
        inc     VerticalScroll
        lda     Joy1Pressed
        and     #(BUTTON_SELECT | BUTTON_START)
        bne     LC7C3
        lda     VerticalScroll
        cmp     #$F0
        bne     LC7B1
        rts

LC7C3:  pla
        pla
        jmp     EnterTitleMenu

PlayerHudIndex = $5A
PlayerHudRowOffset = $00
; Перерисовывает HUD жизней. В single-player обходит только P1, в two-player/демо — P2 и P1.
; На экран выводит max(lives-1,0). Меняет PPU-очередь, ScratchPtr,
; $00/$39..$3B, PlayerHudIndex, TileTranslationOffset/DigitBlankMode; портит A/X/Y.
UpdateLivesHud:
LC7C8:  lda     #$01
        sta     PlayerHudIndex
        sta     DigitBlankMode
        lda     #$6E
        sta     TileTranslationOffset
        lda     #>LivesHudIconText
        sta     ScratchPtrHi
        lda     #<LivesHudIconText
        sta     ScratchPtrLo
        ldx     #$1D
        ldy     #$12
        jsr     QueueTileAtCoordinates
        lda     StageSetLength
        cmp     #$02
        beq     LC7F2
        lda     MenuSelection
        bne     LC7F2
        lda     #$00
        sta     PlayerHudIndex
        jmp     LC801

LC7F2:  lda     #>LivesHudIconText
        sta     ScratchPtrHi
        lda     #<LivesHudIconText
        sta     ScratchPtrLo
        ldx     #$1D
        ldy     #$15
        jsr     QueueTileAtCoordinates
LC801:  ldx     PlayerHudIndex
        lda     Player1Lives,x
        sec
        sbc     #$01
        bpl     LC80C
        lda     #$00
LC80C:  jsr     ByteToDisplayDigits
        ldy     #$36
        ldx     #$19
        jsr     SelectVisibleDigits
        lda     PlayerHudIndex
        sta     PlayerHudRowOffset
        asl     a
        clc
        adc     PlayerHudRowOffset
        clc
        adc     #$12
        tay
        jsr     QueueTranslatedTileString
        dec     PlayerHudIndex
        bpl     LC801
        lda     #$00
        sta     TileTranslationOffset
        sta     DigitBlankMode
        rts

; Рисует в HUD заголовки/иконки P1 и, если нужно, P2. Портит ScratchPtr, A, X, Y и PPU-очередь.
DrawPlayerHudLabels:
LC830:  lda     #>PlayerOneCompactMarker
        sta     ScratchPtrHi
        lda     #<PlayerOneCompactMarker
        sta     ScratchPtrLo
        ldx     #$1D
        ldy     #$11
        jsr     QueueTileAtCoordinates
        lda     StageSetLength
        cmp     #$02
        beq     LC849
        lda     MenuSelection
        beq     LC858
LC849:  lda     #>PlayerTwoCompactMarker
        sta     ScratchPtrHi
        lda     #<PlayerTwoCompactMarker
        sta     ScratchPtrLo
        ldx     #$1D
        ldy     #$14
        jsr     QueueTileAtCoordinates
LC858:  rts

; После vblank выводит в HUD маркер и десятичный StageNumber. Меняет PPU-очередь, ScratchPtr, $39..$3B/$60;
; портит A/X/Y и кадровые счётчики WaitForNextFrame.
DrawStageNumberHud:
LC859:  jsr     WaitForNextFrame
        lda     #>StageHudUpperTiles
        sta     ScratchPtrHi
        lda     #<StageHudUpperTiles
        sta     ScratchPtrLo
        ldx     #$1D
        ldy     #$17
        jsr     QueueTileAtCoordinates
        lda     #>StageHudLowerTiles
        sta     ScratchPtrHi
        lda     #<StageHudLowerTiles
        sta     ScratchPtrLo
        ldx     #$1D
        ldy     #$18
        jsr     QueueTileAtCoordinates
        lda     #$6E
        sta     TileTranslationOffset
        lda     StageNumber
        jsr     ByteToDisplayDigits
        ldy     #$36
        ldx     #$19
        jsr     SelectVisibleDigits
        ldy     #$19
        jsr     QueueTranslatedTileString
        lda     #$00
        sta     TileTranslationOffset
        rts

; Преобразует индекс A в HUD-координаты: X=$1D+(A&1), Y=3+(A>>1).
; Выход: A=Y=(вход>>1)+3, X — столбец. RAM не меняет.
EnemyMarkerIndexToHudCoordinates:
LC894:  pha
        and     #$01
        clc
        adc     #$1D
        tax
        pla
        lsr     a
        clc
        adc     #$03
        tay
        rts

; Рисует RemainingEnemyMarkerTiles для индекса A в правой HUD-сетке. Портит A/X/Y, ScratchPtr и PPU-очередь.
DrawRemainingEnemyMarker:
LC8A2:  jsr     EnemyMarkerIndexToHudCoordinates
        lda     #>RemainingEnemyMarkerTiles
        sta     ScratchPtrHi
        lda     #<RemainingEnemyMarkerTiles
        sta     ScratchPtrLo
        jsr     QueueTileAtCoordinates
        rts

; Заменяет HUD-маркер индекса A строкой $D36B. Портит A/X/Y, ScratchPtr и PPU-очередь.
ClearRemainingEnemyMarker:
LC8B1:  jsr     EnemyMarkerIndexToHudCoordinates
        lda     #>BlankTileText
        sta     ScratchPtrHi
        lda     #<BlankTileText
        sta     ScratchPtrLo
        jsr     QueueTileAtCoordinates
        rts

RemainingEnemyMarkerIndex = $5A
; Ставит десять HUD-маркеров с чётными индексами $12..0.
; Выход: RemainingEnemyMarkerIndex=$FE; портит A/X/Y, ScratchPtr и PPU-очередь.
InitializeRemainingEnemyMarkers:
LC8C0:  lda     #$12
        sta     RemainingEnemyMarkerIndex
LC8C4:  lda     RemainingEnemyMarkerIndex
        jsr     DrawRemainingEnemyMarker
        dec     RemainingEnemyMarkerIndex
        dec     RemainingEnemyMarkerIndex
        bpl     LC8C4
        rts

; Ограничивает Construction-курсор прямоугольником $18..$D8 по обеим осям.
; Меняет ObjectX/ObjectY только при выходе за границы; портит A и флаги, X/Y сохраняет.
ClampConstructionCursor:
LC8D0:  lda     ObjectX
        cmp     #$D8
        bcc     LC8DA
        lda     #$D8
        sta     ObjectX
LC8DA:  lda     ObjectX
        cmp     #$18
        bcs     LC8E4
        lda     #$18
        sta     ObjectX
LC8E4:  lda     ObjectY
        cmp     #$D8
        bcc     LC8EE
        lda     #$D8
        sta     ObjectY
LC8EE:  lda     ObjectY
        cmp     #$18
        bcs     LC8F8
        lda     #$18
        sta     ObjectY
LC8F8:  rts

; При $6D!=0 мигает пятью двухтайловыми знаками в центре экрана на фазе FrameCounter&$10.
; На время отрисовки сбрасывает SpriteBehindTerrainMask и затем восстанавливает
; $20; портит A/X/Y, $04/OamTile и OAM shadow.
DrawPauseOverlay:
LC8F9:  lda     PauseState
        beq     LC946
        lda     FrameCounter
        and     #$10
        beq     LC946
        lda     #$03
        sta     RenderAttributes
        lda     #$00
        sta     SpriteBehindTerrainMask
        ldx     #$64
        ldy     #$80
        lda     #$17
        sta     OamTile
        jsr     EmitOamSprite
        ldx     #$6C
        ldy     #$80
        lda     #$19
        sta     OamTile
        jsr     EmitOamSprite
        ldx     #$74
        ldy     #$80
        lda     #$1B
        sta     OamTile
        jsr     EmitOamSprite
        ldx     #$7C
        ldy     #$80
        lda     #$1D
        sta     OamTile
        jsr     EmitOamSprite
        ldx     #$84
        ldy     #$80
        lda     #$1F
        sta     OamTile
        jsr     EmitOamSprite
        lda     #$20
        sta     SpriteBehindTerrainMask
LC946:  rts

; Рисует двухчастный переходный объект по TransitionObjectX/Y и кодам $79/$7D.
; Портит A/X/Y, $04, OamTile, SpriteBehindTerrainMask и OAM shadow;
; восстанавливает SpriteBehindTerrainMask=$20.
DrawTransitionObject:
LC947:  lda     #$03
        sta     RenderAttributes
        lda     #$00
        sta     SpriteBehindTerrainMask
        ldx     TransitionObjectX
        ldy     TransitionObjectY
        lda     #$79
        sta     OamTile
        jsr     EmitTwoTileOamPair
        lda     TransitionObjectX
        clc
        adc     #$10
        tax
        ldy     TransitionObjectY
        lda     #$7D
        sta     OamTile
        jsr     EmitTwoTileOamPair
        lda     #$20
        sta     SpriteBehindTerrainMask
        rts

; Обновляет переходную анимацию TransitionObjectX..TransitionObjectTimer,
; кроме attract mode (StageSetLength=2).
; Каждые 16 кадров уменьшает TransitionObjectTimer; пока он >=$0A, двигает
; объект по TransitionObjectDirection, затем рисует.
; При обнулении прячет объект при Y=$F0. Портит A/X/Y и OAM shadow при отрисовке.
UpdateTransitionObject:
LC972:  lda     TransitionObjectTimer
        beq     LC9AF
        lda     StageSetLength
        cmp     #$02
        beq     LC9AF
        lda     FrameCounter
        and     #$0F
        bne     LC98D
        dec     TransitionObjectTimer
        bne     LC98D
        lda     #$F0
        sta     TransitionObjectY
LC98D:  lda     TransitionObjectTimer
        cmp     #$0A
        bcc     LC9AC
        lda     TransitionObjectDirection
        tay
        lda     LD3D5,y
        clc
        adc     TransitionObjectX
        sta     TransitionObjectX
        lda     LD3D9,y
        clc
        adc     TransitionObjectY
        sta     TransitionObjectY
LC9AC:  jsr     DrawTransitionObject
LC9AF:  rts

; Готовит параметры прямоугольника (2,2), 26x26 тайлов и вызывает InitializePlayfieldShadow.
; Портит A/X/Y, NametableRect* и nametable shadow/PPU work state по контракту вызываемой процедуры.
InitializePlayfieldRectangle:
LC9B0:  lda     #$02
        sta     NametableRectX
        sta     NametableRectY
        lda     #$1A
        sta     NametableRectHeight
        sta     NametableRectWidth
        jsr     InitializePlayfieldShadow
        rts

; Главное меню с тремя вариантами: один игрок, два игрока, Construction.
