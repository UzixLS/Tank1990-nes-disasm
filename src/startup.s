; Загрузка, reset и вход в frontend loop ($C000-$C0AD).

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
; RESET/IRQ entry: запрещает IRQ, отключает NMI/рендеринг, ждёт два vblank, ставит SP=$6F и полностью
; инициализирует рабочее состояние, PPU, OAM и звук. Затем запускает цикл заглавного экрана,
; демо и меню. Не возвращается; все регистры и RAM считаются изменёнными.
        sei
        lda     #$10
        sta     PPU_CTRL
        cld
        ldx     #$02
WaitResetVblank:
LC079:  lda     PPU_STATUS
        bpl     WaitResetVblank
        lda     #$06
        sta     PPU_MASK
        dex
        bne     WaitResetVblank
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
