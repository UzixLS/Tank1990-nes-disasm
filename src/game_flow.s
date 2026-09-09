; Восемь байтов ASCII "COPYRIGH" перед первой процедурой банка.
Prg1CopyrightPrefix:
        .byte   $43,$4F,$50,$59,$52,$49,$47,$48
BootHook:
; Вход: X — начало восьмибайтной записи. Очищает её и записывает загрузочный маркер $AB в $46.
; Вызывается InitializeCoreRuntime при несовпадении RAM-маркера; портит A/X и флаги.
        jsr     ResetEightByteRecord
        lda     #$AB
        sta     $46
        rts

; Включает NMI и обрабатывает загрузочный маркер $46. Если это $AB, открывает экран выбора варианта.
; Портит A и PPU_CTRL; обработчик маркера может изменить большую часть UI-состояния.
EnableNmiAndHandleBootMarker:
LC010:  jsr     EnableNmiAfterVblank
        lda     $46
        jsr     HandleBootVariantMarker
        rts

; Маршрутизирует ввод огня игрока X в обработчики LE136/LE15D.
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
LC02B:  jmp     LE136

LC02E:  jmp     LE15D

LC031:  lda     Joy1Pressed,x
        and     #(BUTTON_A | BUTTON_B)
        beq     LC02E
        jmp     LE136

ByteToDecimalDigits:
; Вход: $00 — байт 0..255, $39/$3A заранее обнулены. Выход: $39/$3A/$3B — сотни/десятки/единицы.
; Портит A и флаги; X/Y не меняет. Не обнуляет $39/$3A самостоятельно.
        lda     $00
LC03C:  cmp     #$64
        bcc     LC048
LC040:  sec
        sbc     #$64
        inc     $39
        jmp     LC03C

LC048:  cmp     #$0A
        bcc     LC054
        sec
        sbc     #$0A
        inc     $3A
        jmp     LC048

LC054:  sta     $3B
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
LC092:  jsr     EnableNmiAndHandleBootMarker
LC095:  jsr     BuildTitleNametable
        lda     #$00
        sta     $4B
LC09C:  jsr     ClearPrimaryNametableScreen
        jsr     ScrollIntroUntilInput
LC0A2:  jsr     TitleScreen
        jsr     InitializeAttractMode
        jsr     RunAttractMode
        jmp     LC09C

; Редактор Construction: перемещает курсор, меняет TSA-блок и затем
; возвращается в общий игровой цикл.
ConstructionMode:
; Вход: $4B=0 для первичной отрисовки. Объект 0 используется как мигающий курсор.
; D-pad двигает его по сетке 16 px; A/B выбирают TSA $00..$0D и вызывают DrawMetatile. START поднимает $4B и
; возвращается в главное меню. Меняет объект 0, тень nametable, PPU-очередь и рабочую RAM; портит A/X/Y.
LC0AE:  lda     $4B
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
        sta     $6E
        sta     ObjectFrame
        sta     $81
        sta     $7B
        sta     $5C
        sta     VerticalScroll
        sta     NametableBits
        sta     $6F
        sta     $70
        lda     $4B
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
        lda     $81
        bne     LC111
        inc     $81
        jmp     LC144

LC111:  inc     $5C
        lda     $5C
        cmp     #$0E
        bne     LC144
        lda     #$00
        sta     $5C
        jmp     LC144

LC120:  lda     Joy1Pressed
        and     #BUTTON_B
        beq     LC13E
        lda     $81
        bne     LC12F
        inc     $81
        jmp     LC144

LC12F:  dec     $5C
        lda     $5C
        cmp     #$FF
        bne     LC144
        lda     #$0D
        sta     $5C
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
        sta     $6E
        inc     $4B
        jmp     LC0A2

; Экран выбора этапа. Удержание направления повторяет изменение через
; FrameCounter, START подтверждает StageNumber.
SelectStage:
; Вход: StageNumber — текущий этап, $4B!=0 обозначает карту Construction. A/B листают этапы с автоповтором,
; START подтверждает. Далее загружает/рисует карту, инициализирует объекты и выполняет кадровый цикл до исхода этапа.
; Меняет почти всё игровое состояние, PPU/OAM/APU и A/X/Y; в обычном потоке не возвращается к вызывающему.
LC159:  jsr     WaitForNextFrame
        jsr     ResetAudioEngine
        lda     #$1C
        sta     $05
        lda     #$00
        sta     VerticalScroll
        sta     NametableBits
        sta     $6D
        lda     #$04
        sta     $4D
        jsr     CloseNametableCurtain
LC172:  jsr     UpdateStageNumberDisplay
        lda     $4C
        bne     LC1C5
        lda     Joy1Pressed
        and     #BUTTON_START
        bne     LC1C5
        lda     Joy1Pressed
        and     #BUTTON_A
        bne     LC191
        lda     Joy1Held
        and     #BUTTON_A
        beq     LC1A4
        lda     FrameCounter
        and     #$07
        bne     LC1A4
LC191:  lda     #$00
        sta     FrameCounter
        jsr     AdvanceStageNumber
        nop
        cmp     #$33
        bne     LC172
        lda     #$01
        sta     StageNumber
        jmp     LC172

LC1A4:  lda     Joy1Pressed
        and     #BUTTON_B
        bne     LC1B6
        lda     Joy1Held
        and     #BUTTON_B
        beq     LC172
        lda     FrameCounter
        and     #$07
        bne     LC172
LC1B6:  lda     #$00
        sta     FrameCounter
        dec     StageNumber
        bne     LC172
        jsr     WrapStageNumberBackward
        nop
        jmp     LC172

; Подтверждён этап: поднимает UI/звуковые флаги, рисует обычную или Construction-карту и запускает игру.
BeginSelectedStage:
LC1C5:  lda     #$01
        sta     $0301
        sta     $0302
        sta     $0303
        lda     $4B
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
        sta     $4D
        jsr     WaitForNextFrame
        jsr     InitializeStageRuntime
; Основной кадровый цикл. $6D!=0 приостанавливает логику, но оставляет отрисовку; START переключает паузу.
MainGameplayFrameLoop:
LC1F9:  jsr     WaitForNextFrame
        lda     $6D
        bne     LC203
        jsr     RunGameplayLogicTick
LC203:  jsr     LE23B
        jsr     DrawProjectiles
        jsr     DrawTanks
        lda     Joy1Pressed
        and     #BUTTON_START
        beq     LC21B
        lda     #$01
        eor     $6D
        sta     $6D
        sta     $0300
LC21B:  jsr     DrawPauseOverlay
        jsr     CheckStageLoopFinished
        beq     LC1F9
        lda     #$00
        sta     $0A
        sta     FrameCounter
        sta     $0311
        sta     $0312
        lda     $0108
        beq     LC238
        lda     #$FE
        sta     $0A
; Анимация/задержка после исхода этапа. Продолжает логику и рендеринг, пока $0A не станет 2.
StageResultFrameLoop:
LC238:  jsr     WaitForNextFrame
        jsr     SuppressInputOutsideActiveStage
        jsr     RunGameplayLogicTick
        jsr     LE23B
        jsr     DrawTanks
        jsr     DrawProjectiles
        jsr     UpdateHalfSecondPhaseFlag
        lda     $0A
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
        lda     $68
        cmp     #$80
        bne     LC283
        jmp     LFD64

; Альтернативный хвост продолжения: ожидает в A жизни P1, добавляет Player2Lives и при $68=$80 переходит в SelectStage.
; Прямых ссылок на LC275 нет; при неуспехе проваливается в общий возврат к главному меню.
UnusedContinueTail:
LC275:  clc
        adc     Player2Lives
        beq     LC283
        lda     $68
        cmp     #$80
        bne     LC283
        jmp     SelectStage
LC283:  jsr     ClearScreenAndAudio
        jsr     UpdateHighScoreRecord
        tya
        beq     LC292
        jsr     ShowSessionResultScreen
        jsr     ClearScreenAndResumeNmi
LC292:  jmp     LC095

; Гасит рендеринг, очищает обе nametable в shadow RAM/PPU и снова включает NMI.
; Портит A/X и PPU state; Y не гарантируется из-за вызываемых процедур.
ClearScreenAndResumeNmi:
LC295:  jsr     DisableRenderingForBulkUpdate
        jsr     ClearNametableBuffer
        jsr     UploadNametableBuffer
        jsr     EnableNmiAfterVblank
        rts

; Обнуляет held/pressed обоих контроллеров, если $68!=$80. Портит A и флаги.
SuppressInputOutsideActiveStage:
LC2A2:  lda     $68
        cmp     #$80
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
LC2BD:  jsr     LE3C9
        jsr     InitializeRuntimeChecksumGuard
        lda     #$00
        sta     $66
        sta     $67
        sta     $4C
        jsr     SelectInitialLifeCount
        nop
        sta     Player1Lives
        sta     Player2Lives
        sta     $6A
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
; PPU-очередь/OAM shadow/APU request flags также могут быть обновлены.
RunGameplayLogicTick:
LC2E6:  jsr     LE181
        jsr     UpdatePlayerTankInput
        jsr     UpdateTanks
        jsr     LE1FA
        jsr     UpdateProjectiles
        jsr     LE2A9
        jsr     LE27C
        jsr     LE122
        jsr     LE162
        jsr     SpawnPendingEnemyTank
        jsr     LE604
        jsr     LE910
        jsr     LE70C
        jsr     LE972
        jsr     UpdateStageResultObject
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
        sta     $4D
        rts

LC32C:  lda     #$02
        sta     $4D
LC330:  rts

; Инициализирует рабочее состояние выбранного этапа: очищает танки/снаряды, создаёт танки живых игроков,
; задаёт 20 врагов в $7F/$80, сбрасывает таймеры/флаги, рисует HUD и включает активную фазу $68=$80.
; Для этапов 1..11 выбирает псевдослучайную величину $84 из EarlyStageSpawnDelayTable, для поздних — 0.
; Меняет объекты, HUD/PPU-очередь, RNG и рабочую RAM; портит A/X/Y.
InitializeStageRuntime:
LC331:  jsr     ClearProjectileStates
        jsr     ClearTankStates
        lda     #$F0
        sta     $0106
        lda     #$00
        sta     $0108
        lda     Player1Lives
        beq     LC34A
        ldx     #$00
        jsr     LE363
LC34A:  lda     Player2Lives
        beq     LC353
        ldx     #$01
        jsr     LE363
LC353:  lda     #$14
        sta     $7F
        sta     $80
        lda     #$00
        nop
        nop
        sta     $0A
        sta     $4B
        sta     $45
        sta     $6F
        sta     $70
        sta     $89
        sta     $8A
        sta     $82
        sta     $86
        sta     $0100
        sta     $6A
        jsr     ClearStageWorkBytes
        jsr     InitializeRemainingEnemyMarkers
        jsr     WaitForNextFrame
        jsr     DrawPlayerHudLabels
        jsr     DrawStageNumberHud
        nop
        nop
        nop
        lda     #$80
        sta     $68
        lda     #$01
        sta     $0312
        sta     $4C
        lda     StageNumber
        cmp     #$0C
        bcc     LC39C
        lda     #$00
        sta     $84
        rts

LC39C:  lda     #$0C
        sec
        sbc     StageNumber
        sta     $84
        jsr     NextRandomByte
LC3A6:  cmp     $84
        bcc     LC3AE
        sbc     $84
        bcs     LC3A6
LC3AE:  tax
        lda     EarlyStageSpawnDelayTable,x
        sta     $84
        rts

; Готовит демо-этап для attract mode: сбрасывает сессию, загружает служебную карту StageNumber=$FF,
; затем ставит StageNumber=$1E, $8F=2, рисует демо-экран и запускает игру с GameMode=5.
; Меняет всю session/game RAM, PPU/OAM и A/X/Y.
InitializeAttractMode:
LC3B5:  lda     #$01
        sta     $6D
        lda     #$00
        sta     $4D
        jsr     InitializeSessionAfterScoreRecords
        lda     #$03
        sta     Player2Lives
        lda     #$00
        sta     VerticalScroll
        sta     NametableBits
        sta     $0A
        sta     FrameCounter
        jsr     InitializePlayfieldRectangle
        lda     #$FF
        sta     StageNumber
        jsr     LoadAndDrawStage
        lda     #$1E
        sta     StageNumber
        lda     #$02
        sta     $8F
        jsr     DisableRenderingForBulkUpdate
        ldx     #$1A
        stx     $56
        ldy     #$46
        sty     $57
        jsr     LE3D8
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        ldx     #$3C
        stx     $56
        ldy     #$78
        sty     $57
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
        jsr     LE23B
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
        jmp     LC0A2

; Показывает экран нового рекорда/окончания сессии, запускает UI-флаги $0315..$0317 и ждёт их сброса.
; В цикле меняет $4D от 5 до 8 по младшим битам FrameCounter. Меняет nametable/PPU и рабочую RAM; портит A/X/Y.
ShowSessionResultScreen:
LC44B:  jsr     DisableRenderingForBulkUpdate
        lda     #$1C
        sta     $05
        lda     #$00
        sta     VerticalScroll
        sta     NametableBits
        jsr     ClearNametableBuffer
        ldx     #$10
        stx     $56
        ldy     #$32
        sty     $57
        lda     #$D2
        sta     AuxPtrHi
        lda     #$B5
        sta     AuxPtrLo
        jsr     RasterizeTileStringToShadow
        jsr     RenderLargeScoreRecord
        jsr     UploadNametableBuffer
        jsr     EnableNmiAfterVblank
        lda     #$00
        sta     $0A
        lda     #$01
        sta     $0315
        sta     $0316
        sta     $0317
LC486:  jsr     WaitForNextFrame
        lda     FrameCounter
        and     #$03
        clc
        adc     #$05
        sta     $4D
        lda     $0315
        bne     LC486
        lda     #$00
        sta     $4D
        rts

; Вход: A — $46. Возвращается без изменений, если A!=$AB; иначе открывает модальное меню вариантов.
HandleBootVariantMarker:
LC49C:  cmp     #$AB
        beq     LC4A1
        rts

; Рисует пункты вариантов, выбирает $46 по Up/Down в двух диапазонах 0..6/$80..$86, SELECT переключает $8E.
; START возвращается. Меняет nametable/PPU-очередь, FrameCounter, $46/$4A/$4B/$8E и UI-флаги; портит A/X/Y.
RunVariantSelectionMenu:
LC4A1:  lda     #$80
        sta     $46
        jsr     DisableRenderingForBulkUpdate
        lda     #$1C
        sta     $05
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
        sta     $8E
        jsr     DrawSelectedMenuOption
        lda     #$40
        sta     $4B
        lda     #$00
        sta     MenuSelection
        sta     $4A
LC4F9:  lda     #$E8
        sta     ScratchPtrHi
        lda     $4B
        sta     ScratchPtrLo
        clc
        adc     #$08
        sta     $4B
        lda     $4A
        clc
        adc     #$09
        tay
        ldx     #$0D
        jsr     QueueTileAtCoordinates
        jsr     WaitForNextFrame
        inc     $4A
        lda     $4A
        cmp     #$0E
        bcc     LC4F9
LC51C:  lda     #$D3
        sta     ScratchPtrHi
        lda     #$B3
        sta     ScratchPtrLo
        jsr     QueueVariantMenuText
LC527:  lda     Joy1Held
        and     #BUTTON_DOWN
        beq     LC545
        jsr     WaitVariantMenuRepeatAndEraseCursor
        inc     $46
        lda     $46
        cmp     #$07
        bne     LC53A
        lda     #$80
LC53A:  cmp     #$87
        bne     LC540
        lda     #$00
LC540:  sta     $46
        jmp     LC51C

LC545:  lda     Joy1Held
        and     #BUTTON_UP
        beq     LC563
        jsr     WaitVariantMenuRepeatAndEraseCursor
        dec     $46
        lda     $46
        cmp     #$FF
        bne     LC558
        lda     #$86
LC558:  cmp     #$7F
        bne     LC55E
        lda     #$06
LC55E:  sta     $46
        jmp     LC51C

LC563:  lda     Joy1Pressed
        and     #BUTTON_SELECT
        beq     LC572
        lda     $8E
        eor     #$01
        sta     $8E
        jsr     DrawSelectedMenuOption
LC572:  lda     Joy1Pressed
        and     #BUTTON_START
        beq     LC527
        rts

; Debounce/autorepeat меню: сбрасывает FrameCounter, ждёт фазу mod16=0, поднимает $030D
; и помещает строку $E8B2 в позицию текущего пункта. Портит A/X/Y, ScratchPtr и PPU-очередь.
WaitVariantMenuRepeatAndEraseCursor:
LC579:  lda     #$00
        sta     FrameCounter
LC57D:  jsr     WaitForNextFrame
        lda     FrameCounter
        and     #$0F
        bne     LC57D
        lda     #$01
        sta     $030D
        lda     #$E8
        sta     ScratchPtrHi
        lda     #$B2
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
; Начальная задержка появления противников $84 для этапов 1..11;
; выбирается из первых 12-StageNumber элементов.
EarlyStageSpawnDelayTable:
LC59D:  .byte   $03,$08,$0D,$12,$17,$1C,$21,$26
        .byte   $2B,$30,$35,$3A
; Битовые поля ObjectAttributes для псевдослучайной инициализации вражеских танков.
EnemyTypeAttributeBits:
LC5A9:  .byte   $80,$A0,$C0,$E0
EnemyLowAttributeBits:
LC5AD:  .byte   $02,$00,$01,$00,$01,$00,$01,$00
; Байты $C5B5..$C5BE лежат сразу после восьмиэлементной таблицы, но её индексы их не достигают.
UnidentifiedC5b5Data:
        .byte   $00,$00,$00,$00,$00,$00,$00,$00
        .byte   $00,$00
EnemyBonusAttributeBits:
LC5BF:  .byte   $04,$04,$00,$00,$00,$00,$00,$00
; Оставшиеся байты $C5C7..$C5D8 не индексируются как часть таблицы; их формат не установлен.
UnidentifiedC5c7Data:
        .byte   $00,$00,$40,$20,$59,$69,$53,$20
        .byte   $31,$39,$39,$30,$69,$32,$FF,$FF
        .byte   $FF,$FF
; Гасит рендеринг, очищает nametable shadow/PPU, снова включает NMI и сбрасывает audio engine.
; Портит A/X/Y, PPU/APU и звуковую RAM.
ClearScreenAndAudio:
LC5D9:  jsr     DisableRenderingForBulkUpdate
        lda     #$1C
        sta     $05
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
LC5F3:  lda     $8E
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
        lda     $8E
        beq     LC610
        lda     $0178,x
        clc
        adc     #$20
        sta     $0178,x
LC610:  jmp     ApplyPowerUpEffect3

PowerUpEffect6:
; Для игрока X<2 и $8E!=0 увеличивает $0178,X на $60, затем переходит в SetMaximumObjectUpgrade.
; Для остальных слотов/вариантов только общая часть. Портит A и флаги.
LC613:  cpx     #$02
        bcs     LC624
        lda     $8E
        beq     LC624
        lda     $0178,x
        clc
        adc     #$60
        sta     $0178,x
LC624:  jmp     SetMaximumObjectUpgrade
; Подкладывает в StageNumber верхнюю границу для декремента: $76 при ($46&$0F)=6, иначе $32.
; Выход: A — записанное StageNumber; X/Y не меняются.
WrapStageNumberBackward:
LC627:  lda     $46
        and     #$0F
        cmp     #$06
        beq     LC633
        lda     #$32
        bne     LC635
LC633:  lda     #$76
LC635:  sta     StageNumber
        rts

; Два байта без прямых ссылок; не интерпретируются как код.
UnidentifiedC638Data:
        .byte   $20,$B4
RestrictedPowerUpTypeTable:
LC63A:  .byte   $00,$01,$02,$03,$03,$04,$05,$06
; Генерирует Joy1/Joy2 для attract mode. Для каждого игрока выбирает цель:
; координаты $86/$87 при активном $62, иначе первый активный танк из слотов 2/4/3.
; LDDA2 возвращает направление; DemoInputByDirection добавляет огонь. Меняет Joy*Held/Pressed, $5A/$71/$72 и work RAM; портит A/X/Y.
GenerateAttractModeInput:
LC642:  lda     #$01
        sta     $5A
LC646:  ldx     $5A
        lda     $86
        beq     LC65E
        lda     $62
        bne     LC65E
        lda     $86
        sta     $71
        lda     $87
        sta     $72
        jsr     ChooseTankStateTowardTarget
        jmp     LC6A5

LC65E:  lda     $A2,x
        bpl     LC674
        cmp     #$E0
        bcs     LC674
        lda     $92,x
        sta     $71
        lda     $9A,x
        sta     $72
        jsr     ChooseTankStateTowardTarget
        jmp     LC6A5

LC674:  lda     $A4,x
        bpl     LC68A
        cmp     #$E0
        bcs     LC68A
        lda     $94,x
        sta     $71
        lda     $9C,x
        sta     $72
        jsr     ChooseTankStateTowardTarget
        jmp     LC6A5

LC68A:  lda     $A3,x
        bpl     LC6A0
        cmp     #$E0
        bcs     LC6A0
        lda     $93,x
        sta     $71
        lda     $9B,x
        sta     $72
        jsr     ChooseTankStateTowardTarget
        jmp     LC6A5

LC6A0:  lda     #$00
        jmp     LC6AB

LC6A5:  and     #$03
        tay
        lda     DemoInputByDirection,y
LC6AB:  ldx     $5A
        sta     Joy1Held,x
        sta     Joy1Pressed,x
        lda     ObjectY,x
        cmp     #$C8
        bcc     LC6BD
        lda     Joy1Pressed,x
        and     #BUTTON_DIRECTIONS
        sta     Joy1Pressed,x
LC6BD:  dec     $5A
        bpl     LC646
        rts

DemoInputByDirection:
LC6C2:  .byte   $13,$43,$23,$83
; Рисует в Construction метатайл $5C&$0F в координатах курсора ObjectX/ObjectY.
; Портит A/X/Y и nametable shadow/PPU-очередь через DrawMetatile.
DrawConstructionMetatile:
LC6C6:  lda     $5C
        and     #$0F
        ldx     ObjectX
        ldy     ObjectY
        jsr     DrawMetatile
        rts

; Двигает Construction-курсор на 16 px по фронту D-pad; после 20 кадров удержания включает автоповтор,
; оставляя $7B=$0F между шагами. Меняет ObjectX/ObjectY, $7B/$81; портит A/Y и флаги, X не меняет.
UpdateConstructionCursor:
LC6D2:  lda     Joy1Held
        and     #BUTTON_DIRECTIONS
        beq     LC6E1
        inc     $7B
        lda     #$00
        sta     $81
        jmp     LC6E5

LC6E1:  lda     #$00
        sta     $7B
LC6E5:  lda     $7B
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
        sta     $7B
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
LC722:  sta     $73,x
        dex
        bpl     LC722
        rts

; Проверяет условие завершения текущего кадрового цикла.
; Возвращает A=0, если $68!=0, остались враги ($80!=0) и есть хотя бы одна жизнь; иначе A=1.
; При запуске финальной анимации задаёт $0105..$0108 и сбрасывает FrameCounter. Портит A и флаги.
CheckStageLoopFinished:
LC728:  lda     $68
        beq     LC737
        lda     $80
        beq     LC74F
        lda     Player1Lives
        clc
        adc     Player2Lives
        bne     LC752
LC737:  lda     #$70
        sta     $0105
        lda     #$F0
        sta     $0106
        lda     #$00
        sta     $0107
        lda     #$11
        sta     $0108
        lda     #$00
        sta     FrameCounter
LC74F:  lda     #$01
        rts

LC752:  lda     #$00
        rts

; Статически неиспользуемый RAM-инспектор: рисует индекс $0109 и байт $00+index.
; SELECT/B/A меняют индекс на +1/-1/+16. Портит A/X/Y, ScratchPtr, $39..$3B, PPU-очередь и $0109.
UnusedRamInspector:
LC755:  lda     $0109
        jsr     PreparePackedScoreIncrement
        lda     #$30
        sta     $60
        lda     #$00
        sta     ScratchPtrHi
        lda     #$39
        sta     ScratchPtrLo
        ldx     #$09
        ldy     #$02
        jsr     QueueTranslatedTileString
        ldx     $0109
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
        sta     $60
        lda     Joy1Pressed
        and     #BUTTON_SELECT
        beq     LC792
        inc     $0109
LC792:  lda     Joy1Pressed
        and     #BUTTON_B
        beq     LC79B
        dec     $0109
LC79B:  lda     Joy1Pressed
        and     #BUTTON_A
        beq     LC7AA
        lda     $0109
        clc
        adc     #$10
        sta     $0109
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
        jmp     LC0A2

; Перерисовывает HUD жизней. В single-player обходит только P1, в two-player/демо — P2 и P1.
; На экран выводит max(lives-1,0). Меняет PPU-очередь, ScratchPtr, $00/$39..$3B/$5A/$60/$6B; портит A/X/Y.
UpdateLivesHud:
LC7C8:  lda     #$01
        sta     $5A
        sta     $6B
        lda     #$6E
        sta     $60
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$41
        sta     ScratchPtrLo
        ldx     #$1D
        ldy     #$12
        jsr     QueueTileAtCoordinates
        lda     $8F
        cmp     #$02
        beq     LC7F2
        lda     MenuSelection
        bne     LC7F2
        lda     #$00
        sta     $5A
        jmp     LC801

LC7F2:  lda     #$D3
        sta     ScratchPtrHi
        lda     #$41
        sta     ScratchPtrLo
        ldx     #$1D
        ldy     #$15
        jsr     QueueTileAtCoordinates
LC801:  ldx     $5A
        lda     Player1Lives,x
        sec
        sbc     #$01
        bpl     LC80C
        lda     #$00
LC80C:  jsr     ByteToDisplayDigits
        ldy     #$36
        ldx     #$19
        jsr     SelectVisibleDigits
        lda     $5A
        sta     $00
        asl     a
        clc
        adc     $00
        clc
        adc     #$12
        tay
        jsr     QueueTranslatedTileString
        dec     $5A
        bpl     LC801
        lda     #$00
        sta     $60
        sta     $6B
        rts

; Рисует в HUD заголовки/иконки P1 и, если нужно, P2. Портит ScratchPtr, A, X, Y и PPU-очередь.
DrawPlayerHudLabels:
LC830:  lda     #$D2
        sta     ScratchPtrHi
        lda     #$AB
        sta     ScratchPtrLo
        ldx     #$1D
        ldy     #$11
        jsr     QueueTileAtCoordinates
        lda     $8F
        cmp     #$02
        beq     LC849
        lda     MenuSelection
        beq     LC858
LC849:  lda     #$D2
        sta     ScratchPtrHi
        lda     #$AE
        sta     ScratchPtrLo
        ldx     #$1D
        ldy     #$14
        jsr     QueueTileAtCoordinates
LC858:  rts

; После vblank выводит в HUD маркер и десятичный StageNumber. Меняет PPU-очередь, ScratchPtr, $39..$3B/$60;
; портит A/X/Y и кадровые счётчики WaitForNextFrame.
DrawStageNumberHud:
LC859:  jsr     WaitForNextFrame
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$65
        sta     ScratchPtrLo
        ldx     #$1D
        ldy     #$17
        jsr     QueueTileAtCoordinates
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$68
        sta     ScratchPtrLo
        ldx     #$1D
        ldy     #$18
        jsr     QueueTileAtCoordinates
        lda     #$6E
        sta     $60
        lda     StageNumber
        jsr     ByteToDisplayDigits
        ldy     #$36
        ldx     #$19
        jsr     SelectVisibleDigits
        ldy     #$19
        jsr     QueueTranslatedTileString
        lda     #$00
        sta     $60
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

; Рисует маркер $D362 для индекса A в правой HUD-сетке. Портит A/X/Y, ScratchPtr и PPU-очередь.
DrawRemainingEnemyMarker:
LC8A2:  jsr     EnemyMarkerIndexToHudCoordinates
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$62
        sta     ScratchPtrLo
        jsr     QueueTileAtCoordinates
        rts

; Заменяет HUD-маркер индекса A строкой $D36B. Портит A/X/Y, ScratchPtr и PPU-очередь.
ClearRemainingEnemyMarker:
LC8B1:  jsr     EnemyMarkerIndexToHudCoordinates
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$6B
        sta     ScratchPtrLo
        jsr     QueueTileAtCoordinates
        rts

; Ставит десять HUD-маркеров с чётными индексами $12..0. Выход: $5A=$FE; портит A/X/Y, ScratchPtr и PPU-очередь.
InitializeRemainingEnemyMarkers:
LC8C0:  lda     #$12
        sta     $5A
LC8C4:  lda     $5A
        jsr     DrawRemainingEnemyMarker
        dec     $5A
        dec     $5A
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
; На время отрисовки сбрасывает $6E и затем восстанавливает $20; портит A/X/Y, $04/$53 и OAM shadow.
DrawPauseOverlay:
LC8F9:  lda     $6D
        beq     LC946
        lda     FrameCounter
        and     #$10
        beq     LC946
        lda     #$03
        sta     $04
        lda     #$00
        sta     $6E
        ldx     #$64
        ldy     #$80
        lda     #$17
        sta     $53
        jsr     EmitOamSprite
        ldx     #$6C
        ldy     #$80
        lda     #$19
        sta     $53
        jsr     EmitOamSprite
        ldx     #$74
        ldy     #$80
        lda     #$1B
        sta     $53
        jsr     EmitOamSprite
        ldx     #$7C
        ldy     #$80
        lda     #$1D
        sta     $53
        jsr     EmitOamSprite
        ldx     #$84
        ldy     #$80
        lda     #$1F
        sta     $53
        jsr     EmitOamSprite
        lda     #$20
        sta     $6E
LC946:  rts

; Рисует двухчастный объект финальной анимации по координатам $0105/$0106 и кодам $79/$7D.
; Портит A/X/Y, $04/$53/$6E и OAM shadow; восстанавливает $6E=$20.
DrawStageResultObject:
LC947:  lda     #$03
        sta     $04
        lda     #$00
        sta     $6E
        ldx     $0105
        ldy     $0106
        lda     #$79
        sta     $53
        jsr     EmitTwoTileOamPair
        lda     $0105
        clc
        adc     #$10
        tax
        ldy     $0106
        lda     #$7D
        sta     $53
        jsr     EmitTwoTileOamPair
        lda     #$20
        sta     $6E
        rts

; Обновляет финальную анимацию $0105..$0108, кроме attract mode ($8F=2).
; Каждые 16 кадров уменьшает $0108; пока он >=$0A, двигает объект по направлению $0107, затем рисует.
; При обнулении прячет объект при Y=$F0. Портит A/X/Y и OAM shadow при отрисовке.
UpdateStageResultObject:
LC972:  lda     $0108
        beq     LC9AF
        lda     $8F
        cmp     #$02
        beq     LC9AF
        lda     FrameCounter
        and     #$0F
        bne     LC98D
        dec     $0108
        bne     LC98D
        lda     #$F0
        sta     $0106
LC98D:  lda     $0108
        cmp     #$0A
        bcc     LC9AC
        lda     $0107
        tay
        lda     LD3D5,y
        clc
        adc     $0105
        sta     $0105
        lda     LD3D9,y
        clc
        adc     $0106
        sta     $0106
LC9AC:  jsr     DrawStageResultObject
LC9AF:  rts

; Вызывает LD7CC для прямоугольника с началом $56/$57=(2,2) и размером $5A/$5B=(26,26).
; Портит A/X/Y, $56/$57/$5A/$5B и nametable shadow/PPU work state по контракту LD7CC.
InitializePlayfieldRectangle:
LC9B0:  lda     #$02
        sta     $56
        sta     $57
        lda     #$1A
        sta     $5A
        sta     $5B
        jsr     InitializePlayfieldShadow
        rts

; Главное меню с тремя вариантами: один игрок, два игрока, Construction.
