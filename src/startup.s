; Загрузка, reset и вход в frontend loop ($C000-$C0AD).

; Восемь байтов ASCII "COPYRIGH" перед первой процедурой банка.
Prg1CopyrightPrefix:
        .byte   $43,$4F,$50,$59,$52,$49,$47,$48

ResetStackTop          = $6F
ResetPpuCtrlValue      = $10
ResetPpuMaskValue      = $06
ResetVblankWaitCount   = $02

; Cold-path helper persistent-состояния. Вход: X=начало восьмибайтной
; record. Записывает [0,0,0,0,0,0,0,$FF] и GameVariant=BootVariantMarker.
; InitializeCoreRuntime вызывает с X=HighScore, затем сам записывает цифру 2
; в HighScore+2, получая 0020000. Сам helper MenuSelection и эту цифру
; не меняет. Выход: A=BootVariantMarker, X/Y сохранены, N=1/Z=0;
; C/V и прочая RAM сохранены.
InitializeColdBootPersistentState:
        jsr     ResetEightByteRecord
        lda     #BootVariantMarker
        sta     GameVariant
        rts

; Включает NMI и передаёт GameVariant обработчику загрузочного маркера. При
; BootVariantMarker синхронно открывает меню вариантов и возвращается после START.
; Без маркера X/Y и RAM сохраняются, A=GameVariant, flags от
; CMP #BootVariantMarker; PPU_CTRL уже изменён на $B0. При marker меню
; заменяет GameVariant/MenuSelection/AllPowerUpsEnabled и меняет UI/PPU/input/audio
; state; выходные X/Y/flags зависят от menu path. Штатный вход
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
; AdvancePlayerFiringLoop и самостоятельно не возвращается. Вход: X=0/1;
; иное X читает за двухбайтными Joy arrays. Fire-tail получает A=BUTTON_A
; в normal A-path, A=BUTTON_B в normal B-path или ненулевую маску A|B в
; combined mode. Skip-tail получает A=0, N=0/Z=1. X остаётся player slot;
; Y/RAM и stack depth до хвоста не меняются, C/V остаются от CMP GameMode,#6.
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
; RESET/IRQ/BRK entry: запрещает IRQ, пишет PPU_CTRL=$10 и
; PPU_MASK=$06, отключая NMI/rendering, и опрашивает два vblank. IRQ/BRK
; используют тот же вектор, поэтому их аппаратный frame и прежний стек
; намеренно отбрасываются после TXS.
;
; SP=$6F оставляет $0170.. под extension state/PPU buffer, но даёт только
; 80 bytes глубины до RestartSignature $0110..$011F. Romhack с более глубокими
; call chains должен пересмотреть эту карту page $01.
;
; ResetExtensionState обнуляет $0170..$017F и вызывает частичный
; InitializeCoreRuntime. Поэтому reset не гарантирует нули в gameplay/session/
; object/projectile/input/RNG RAM; warm/cold decision затрагивает лишь
; persistent HighScore/GameVariant/MenuSelection. После init отдельно пишет
; VerticalScroll=NametableBits=0 и падает в frontend. Не возвращается; D=0, I=1.
; Прямо перед MainFrontendLoop: A=0, X=$1C, Y=0, N=0/Z=1/C=1/V=0, SP=$6F.
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
