; Настройка свойств снаряда для выбранного варианта игры ($FFC1-$FFF0).

StrongProjectileAttributeClass = $60
StrongProjectileAttributeBit   = $08
VariantNormalProjectileClassMin= $A0
ProjectileClassExclusionBit    = $80

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
        and     #ObjectAttributeClassMask
        jmp     DecodeProjectileFlagsFromAttributes

DecodeExtendedVariantProjectileFlags:
LFFCC:  lda     ObjectAttributes,x
        and     #StrongProjectileAttributeBit
        beq     DecodeProjectileFlagsFromUpgradeClass
        jmp     SetStrongProjectileFlags

DecodeProjectileFlagsFromUpgradeClass:
LFFD5:  lda     ObjectAttributes,x
        and     #ObjectAttributeClassMask
        beq     FinishProjectileFlagInitialization
        cmp     #VariantNormalProjectileClassMin
        bcs     SetVariantNormalProjectileFlags
        cmp     #StrongProjectileAttributeClass
        beq     SetStrongProjectileFlagsDirect
        and     #ProjectileClassExclusionBit
        bne     FinishProjectileFlagInitialization
SetVariantNormalProjectileFlags:
LFFE7:  lda     #ProjectileFlagFast
        sta     ProjectileFlags,x
        rts

SetStrongProjectileFlagsDirect:
LFFEC:  lda     #ProjectileFlagsMaximum
        sta     ProjectileFlags,x
FinishProjectileFlagInitialization:
LFFF0:  rts
