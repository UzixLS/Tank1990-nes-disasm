; Расширения обработки попаданий и прохода коллизий ($FF66-$FFC0).

; Обрабатывает попадание снаряда в объект X с нулевым PlayerShieldTimer,X.
; Ненулевой ObjectSpecialState,X поглощается/очищается. Без него объект
; переводится в TankStateDestroyed, кроме PlayerUpgradeLevel,X=$63: тогда
; запрашивается ArmorHitAudioState, а $40 записывается в PlayerUpgradeLevel,
; PlayerExtendedUpgrade и ObjectAttributes. Не возвращается.
HandleProjectileHitOnTank:
LFF66:  lda     ObjectSpecialState,x
        beq     ApplyUnshieldedProjectileHit
        lda     #$00
        sta     ObjectSpecialState,x
        jmp     AdvancePlayerCollisionPassOrBeginEnemyPass

ApplyUnshieldedProjectileHit:
LFF73:  lda     PlayerUpgradeLevel,x
        cmp     #$63
        beq     DowngradeMaximumPlayerArmor
        lda     #TankStateDestroyed
        sta     ObjectState,x
        jmp     ApplyPlayerHitVariantState

DowngradeMaximumPlayerArmor:
LFF81:  lda     #AudioStateStartRequested
        sta     ArmorHitAudioState
        lda     #$40
        sta     PlayerUpgradeLevel,x
        sta     PlayerExtendedUpgrade,x
        sta     ObjectAttributes,x
        jmp     AdvancePlayerCollisionPassOrBeginEnemyPass

; Запрашивает PlayerOrBaseDestructionNoiseAudioState и возвращает в A
; модификатор $20 при отрицательном GameVariant, иначе 0.
; X/Y не меняет; портит флаги.
GetVariantAttributeBits:
LFF93:  lda     #AudioStateStartRequested
        sta     PlayerOrBaseDestructionNoiseAudioState
        lda     GameVariant
        bmi     ReturnExtendedVariantAttributeBits
        lda     #$00
        rts

ReturnExtendedVariantAttributeBits:
LFF9F:  lda     #$20
        rts

; Одиночный байт $01 по $FFA2; статических ссылок нет.
UnreferencedFfa2Byte:
        .byte   $01
; Записывает A в ObjectAttributes,X и переходит в общий хвост прохода столкновений.
StoreAttributesAndContinueCollisionPass:
LFFA3:  sta     ObjectAttributes,x
        jmp     AdvancePlayerCollisionPassOrBeginEnemyPass
; Хвост прохода столкновений по игрокам: очищает ObjectSpecialState,X для
; ObjectState=TankStateDestroyed, затем уменьшает TankCollisionSlot (тот же $5A).
; При TankCollisionSlot>=0 переходит к CheckNextPlayerTank, иначе возвращается.
; Портит A, TankCollisionSlot и флаги.
AdvanceTankCollisionPass:
LFFA8:  lda     ObjectState,x
        cmp     #TankStateDestroyed
        bne     AdvanceTankCollisionSlot
        lda     #$00
        sta     ObjectSpecialState,x
AdvanceTankCollisionSlot:
LFFB3:  dec     TankCollisionSlot
        bpl     ContinueTankCollisionPass
        rts

ContinueTankCollisionPass:
LFFB8:  jmp     CheckNextPlayerTank

; Очищает дополнительное состояние ObjectSpecialState,X.
; Выход: A=0; X/Y сохраняются.
ClearObjectExtensionState:
LFFBB:  lda     #$00
        sta     ObjectSpecialState,x
        rts
