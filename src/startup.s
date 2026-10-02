; Загрузка, reset и вход в frontend loop ($C000-$C0AD).

; Восемь байтов ASCII "COPYRIGH" перед первой процедурой банка.
Prg1CopyrightPrefix:
        .byte   $43,$4F,$50,$59,$52,$49,$47,$48

ResetStackTop          = $6F
ResetPpuCtrlValue      = $10
ResetPpuMaskValue      = $06
ResetVblankWaitCount   = $02

BootHook:
; Вход: X — начало восьмибайтной записи. Очищает её и записывает
; BootVariantMarker в GameVariant. Вызывается InitializeCoreRuntime при
; несовпадении RAM-маркера. Выход: A=BootVariantMarker, X/Y сохранены,
; N=1/Z=0, C/V сохраняются; обнуляет семь bytes с X по X+6 и записывает $FF
; в X+7. В штатном вызове X=HighScore; начальные 20000 выставляются caller-ом.
        jsr     ResetEightByteRecord
        lda     #BootVariantMarker
        sta     GameVariant
        rts

; Включает NMI и передаёт GameVariant обработчику загрузочного маркера. При
; BootVariantMarker синхронно открывает меню вариантов и возвращается после START.
; Без маркера X/Y и RAM сохраняются, A=GameVariant, flags от CMP; всегда меняет
; PPU_CTRL и ждёт vblank. Меню может изменить UI/PPU state и X/Y. Штатный вход
; приходит с выключенным NMI; EnableNmiAfterVblank включает его на vblank.
EnableNmiAndHandleBootMarker:
LC010:  jsr     EnableNmiAfterVblank
        lda     GameVariant
        jsr     HandleBootVariantMarker
        rts

; Маршрутизирует ввод огня игрока X в FirePlayerProjectile либо
; AdvancePlayerFiringLoop.
; В обычных режимах A срабатывает по фронту, B — по удержанию; в
; CombinedFireGameMode любая из A/B — по фронту. Это continuation
; UpdatePlayerFiring: хвостом переходит в FirePlayerProjectile либо
; AdvancePlayerFiringLoop и самостоятельно не возвращается. Портит A и флаги;
; X остаётся индексом игрока, Y и RAM до выбранного хвоста не меняются.
DispatchPlayerFireInput:
LC019:  lda     GameMode
        cmp     #CombinedFireGameMode
        beq     CheckCombinedFirePress
        lda     Joy1Pressed,x
        and     #BUTTON_A
        bne     FirePlayerProjectileNow
        lda     Joy1Held,x
        and     #BUTTON_B
        beq     SkipPlayerProjectile
FirePlayerProjectileNow:
LC02B:  jmp     FirePlayerProjectile

SkipPlayerProjectile:
LC02E:  jmp     AdvancePlayerFiringLoop

CheckCombinedFirePress:
LC031:  lda     Joy1Pressed,x
        and     #(BUTTON_A | BUTTON_B)
        beq     SkipPlayerProjectile
        jmp     FirePlayerProjectile

.include "decimal.s"

; 25-байтная авторская строка; не завершена $FF и не имеет прямых ссылок.
UnreferencedAuthorText:
        .byte   $49,$20,$48,$59,$4F,$55,$44,$4F
        .byte   $55,$4A,$55,$4E,$4B,$4F,$20,$4F
        .byte   $5A,$41,$57,$41,$20,$20,$20,$20
        .byte   $20

ResetHandler:
; RESET/IRQ entry: запрещает IRQ, отключает NMI/рендеринг, ждёт два vblank,
; ставит SP=ResetStackTop и полностью инициализирует рабочее состояние, PPU,
; OAM и звук. IRQ/BRK также используют этот вектор, поэтому прежний стек
; намеренно отбрасывается. PPU_MASK=$06 оставляет rendering выключенным;
; PPU_CTRL=$10 отключает NMI. После ResetExtensionState отдельно обнуляет scroll
; и nametable bits, затем запускает frontend loop. Не возвращается; D=0, I=1,
; SP начинается с $6F, все регистры и рабочая RAM считаются изменёнными.
        sei
        lda     #ResetPpuCtrlValue
        sta     PPU_CTRL
        cld
        ldx     #ResetVblankWaitCount
WaitResetVblank:
LC079:  lda     PPU_STATUS
        bpl     WaitResetVblank
        lda     #ResetPpuMaskValue
        sta     PPU_MASK
        dex
        bne     WaitResetVblank
        ldx     #ResetStackTop
        txs
        jsr     ResetExtensionState
        lda     #$00
        sta     VerticalScroll
        sta     NametableBits
MainFrontendLoop:
; Верхнеуровневый UI-цикл: строит title nametable, прокручивает заставку,
; обслуживает меню и attract mode. Не возвращается; каждый полный перезапуск
; очищает ConstructionMapFlag. EnterTitleMenu — общий continuation для
; досрочного выхода из intro/attract/Construction и тоже не является отдельной
; процедурой: эти пути обязаны заранее привести стек к ожидаемой глубине.
; Обычный timeout TitleScreen возвращает сюда и запускает attract; START-ветки
; TitleScreen снимают собственный return address и уходят в выбранный режим.
; Меняет всё состояние UI/PPU и A/X/Y.
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
