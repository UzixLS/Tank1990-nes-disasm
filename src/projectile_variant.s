; Настройка свойств снаряда для выбранного варианта игры ($FFC1-$FFF0).

; Настраивает ProjectileFlags,X по режиму $46 и ObjectAttributes,X.
; В базовом режиме передаёт старшую тетраду атрибутов в
; DecodeProjectileFlagsFromAttributes. В расширенном режиме ($46<0)
; бит $08 или класс $60 дают flags=3, часть прочих ненулевых классов — flags=1.
; Предусловие: ProjectileFlags,X уже обнулён; некоторые ветки намеренно не
; записывают его. Портит A и флаги.
InitializeProjectileFlagsForVariant:
LFFC1:  lda     GameVariant
        bmi     DecodeExtendedVariantProjectileFlags
        lda     ObjectAttributes,x
        and     #$F0
        jmp     DecodeProjectileFlagsFromAttributes

DecodeExtendedVariantProjectileFlags:
LFFCC:  lda     ObjectAttributes,x
        and     #$08
        beq     DecodeProjectileFlagsFromUpgradeClass
        jmp     SetStrongProjectileFlags

DecodeProjectileFlagsFromUpgradeClass:
LFFD5:  lda     ObjectAttributes,x
        and     #$F0
        beq     FinishProjectileFlagInitialization
        cmp     #$A0
        bcs     SetVariantNormalProjectileFlags
        cmp     #$60
        beq     SetStrongProjectileFlagsDirect
        and     #$80
        bne     FinishProjectileFlagInitialization
SetVariantNormalProjectileFlags:
LFFE7:  lda     #$01
        sta     ProjectileFlags,x
        rts

SetStrongProjectileFlagsDirect:
LFFEC:  lda     #$03
        sta     ProjectileFlags,x
FinishProjectileFlagInitialization:
LFFF0:  rts
