; Неиспользуемые прототипы обработчиков расширения ($BF84-$BFFF).

ExtensionPrototypeSavedA = $00
ExtensionPrototypeSlot   = $5A

; Ниже лежат неиспользуемые копии/заготовки обработчиков расширения. Статических
; вызовов нет. $BF93..$BFBA побайтно совпадает с активным кодом $FF93..$FFBA;
; $BF86..$BF92 — с $FF86..$FF92, но перед копией добавлено STA $00.

; Вход: A сохраняется в $00, X — объект. Инициализирует три поля объекта значением $40,
; затем переходит в общий обработчик LE77A. Портит A и флаги; X сохраняет до перехода.
InitializeObjectExtensionPrototype:
LBF84:  sta     ExtensionPrototypeSavedA
        lda     #$40
        sta     PlayerUpgradeLevel,x
        sta     PlayerExtendedUpgrade,x
        sta     ObjectAttributes,x
        jmp     AdvancePlayerCollisionPassOrBeginEnemyPass

; Возвращает A=$20, если GameVariant отрицателен, иначе A=0; всегда
; запрашивает PlayerOrBaseDestructionNoiseAudioState.
GetModeExtensionBitsPrototype:
LBF93:  lda     #AudioStateStartRequested
        sta     PlayerOrBaseDestructionNoiseAudioState
        lda     GameVariant
        bmi     ReturnEnabledModeExtensionBits
        lda     #$00
        rts
ReturnEnabledModeExtensionBits:
LBF9F:  lda     #$20
        rts

        .byte   $01
; Записывает A в ObjectAttributes,X и переходит к общему хвосту столкновений.
StoreObjectAttributesPrototype:
LBFA3:  sta     ObjectAttributes,x
        jmp     AdvancePlayerCollisionPassOrBeginEnemyPass

; Очищает поле $0170,X для состояния $73, затем продолжает обход по $5A.
; Выход: $5A уменьшен; портит A и флаги, X не меняет до перехода.
AdvanceExtensionObjectLoopPrototype:
LBFA8:  lda     ObjectState,x
        cmp     #TankStateDestroyed
        bne     AdvancePrototypeExtensionSlot
        lda     #$00
        sta     ObjectSpecialState,x
AdvancePrototypeExtensionSlot:
LBFB3:  dec     ExtensionPrototypeSlot
        bpl     ContinuePrototypeExtensionLoop
        rts
ContinuePrototypeExtensionLoop:
LBFB8:  jmp     CheckNextPlayerTank

; Первые пять байт совпадают с ClearObjectExtensionState по $FFBB, но вместо
; завершающего RTS по $BFC0 начинается заполнение $FF.
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
