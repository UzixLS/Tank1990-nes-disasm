; Неиспользуемые прототипы обработчиков расширения ($BF84-$BFFF).
; Статических callers нет. Первые процедуры — почти побайтные предшественники
; active collision extensions по $FF66-$FFC0; это continuation fragments,
; зависящие от stack/counters прохода столкновений, а не самостоятельный API.

ExtensionPrototypeDiscardedA = $00
PrototypeCollisionSlot       = $5A

; Ниже лежат неиспользуемые копии/заготовки обработчиков расширения. Статических
; вызовов нет. $BF93..$BFBA побайтно совпадает с активным кодом $FF93..$FFBA;
; $BF86..$BF92 — с $FF86..$FF92, но перед копией добавлено STA $00.

; Вход: X обязан быть player slot 0/1. Входной A записывается в zero-page $00,
; но ни этот блок, ни continuation его затем не читают как сохранённое значение.
; Записывает PlayerUpgradeLevel2 в PlayerUpgradeLevel/PlayerExtendedUpgrade/
; ObjectAttributes,X и JMP-ом входит в середину projectile/tank collision pass.
; X>=2 повредит соседние, не-player RAM records; прямой JSR вне collision pass
; также нарушит его ожидаемые PrototypeCollisionSlot и stack nesting.
; Самостоятельно не возвращается; дальнейшие outputs/side effects принадлежат
; AdvancePlayerCollisionPassOrBeginEnemyPass.
InitializePlayerUpgradeStatePrototype:
LBF84:  sta     ExtensionPrototypeDiscardedA
        lda     #PlayerUpgradeLevel2
        sta     PlayerUpgradeLevel,x
        sta     PlayerExtendedUpgrade,x
        sta     ObjectAttributes,x
        jmp     AdvancePlayerCollisionPassOrBeginEnemyPass

; Всегда запрашивает destruction-noise stream. Возвращает
; A=ExtendedVariantPlayerHitAttributeBits ($20), N=0/Z=0 при bit7 GameVariant,
; иначе A=0, N=0/Z=1. C/V и X/Y сохраняются; PPU/OAM/RNG не меняет.
RequestPlayerDestructionAudioAndGetVariantBitsPrototype:
LBF93:  lda     #AudioStateStartRequested
        sta     PlayerOrBaseDestructionNoiseAudioState
        lda     GameVariant
        bmi     ReturnEnabledModeExtensionBits
        lda     #$00
        rts
ReturnEnabledModeExtensionBits:
LBF9F:  lda     #ExtendedVariantPlayerHitAttributeBits
        rts

        .byte   $01
; Continuation: записывает входной A в ObjectAttributes,X и JMP-ом уходит в
; общий хвост collision pass. Требует X=player slot и уже существующий stack/
; counter context; отдельно не возвращается и bounds check не выполняет.
StoreAttributesAndContinueCollisionPrototype:
LBFA3:  sta     ObjectAttributes,x
        jmp     AdvancePlayerCollisionPassOrBeginEnemyPass

; Прототип хвоста player-collision pass. Для ObjectState,X=TankStateDestroyed
; очищает ObjectSpecialState,X, затем декрементирует общий slot counter $5A.
; При неотрицательном результате JMP CheckNextPlayerTank; при отрицательном
; делает RTS, которым разматывает сохранённый collision-pass frame. Для
; штатного входа PrototypeCollisionSlot=1 это переход с новым 0, для входа 0 —
; возврат с $FF. X — только что обработанный player slot. Портит A/flags и
; counter; X сохраняется лишь до выбранного continuation/return.
AdvancePlayerCollisionPassPrototype:
LBFA8:  lda     ObjectState,x
        cmp     #TankStateDestroyed
        bne     AdvancePrototypeExtensionSlot
        lda     #$00
        sta     ObjectSpecialState,x
AdvancePrototypeExtensionSlot:
LBFB3:  dec     PrototypeCollisionSlot
        bpl     ContinuePrototypeExtensionLoop
        rts
ContinuePrototypeExtensionLoop:
LBFB8:  jmp     CheckNextPlayerTank

; Усечённый прототип: первые пять bytes совпадают с ClearObjectExtensionState
; по $FFBB и очищают ObjectSpecialState,X, но ожидаемого RTS по $BFC0 нет.
; Следом начинается padding $FF; на 6502 это поток undocumented opcodes, а не
; безопасный возврат. Метку нельзя вызывать как процедуру даже при X=0..7.
ClearObjectExtensionPrototype:
LBFBB:  lda     #$00
        sta     ObjectSpecialState,x
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF
