; Настройка свойств снаряда для выбранного варианта игры ($FFC1-$FFF0).

StrongProjectileAttributeClass     = $60
ExtendedStrongProjectileBit        = $08
ExtendedFastProjectileClassMin     = $A0

; Настраивает скорость/разрушение стали ProjectileFlags,X по GameVariant и
; ObjectAttributes,X. Базовые варианты (GameVariant<128) передают старшую
; тетраду общему DecodeProjectileFlagsFromAttributes.
;
; В расширенных вариантах bit3 всегда даёт flags=Fast|BreakSteel. Без него:
; class $60 тоже даёт оба флага; $10..$50/$70 и $A0..$F0 дают только Fast;
; $00/$80/$90 оставляют предварительно очищенные flags=0. Это сравнения классов,
; а не непрерывная шкала мощности.
;
; Вход: X=слот снаряда/танка; ProjectileFlags,X=0 — обязательное предусловие,
; потому что ветви $00/$80/$90 ничего не записывают. Выход: X/Y сохранены,
; A зависит от ветви (0/$80/1/3). Для extended bit3 и class $60 результат A=3;
; classes $A0..$F0 дают A=1/C=1, $10..$50 — A=1/C=0, $70 — A=1/C=1,
; $80/$90 — A=$80/C=1, class0 — A=0; V сохраняется, N/Z соответствуют A.
; Базовый путь наследует более неоднородные flags DecodeProjectileFlagsFromAttributes.
; Меняет только ProjectileFlags,X и flags CPU.
; Координаты/state снаряда, объект, PPU/OAM/audio не меняет.
InitializeProjectileFlagsForVariant:
LFFC1:  lda     GameVariant
        bmi     DecodeExtendedVariantProjectileFlags
        lda     ObjectAttributes,x
        and     #ObjectAttributeClassMask
        jmp     DecodeProjectileFlagsFromAttributes

DecodeExtendedVariantProjectileFlags:
LFFCC:  lda     ObjectAttributes,x
        and     #ExtendedStrongProjectileBit
        beq     DecodeExtendedProjectileClass
        jmp     SetStrongProjectileFlags

DecodeExtendedProjectileClass:
LFFD5:  lda     ObjectAttributes,x
        and     #ObjectAttributeClassMask
        beq     FinishProjectileFlagInitialization
        cmp     #ExtendedFastProjectileClassMin
        bcs     SetExtendedFastProjectileFlags
        cmp     #StrongProjectileAttributeClass
        beq     SetExtendedStrongProjectileFlags
        and     #ProjectileAttributeClassHighBit
        bne     FinishProjectileFlagInitialization
SetExtendedFastProjectileFlags:
LFFE7:  lda     #ProjectileFlagFast
        sta     ProjectileFlags,x
        rts

SetExtendedStrongProjectileFlags:
LFFEC:  lda     #ProjectileFlagsMaximum
        sta     ProjectileFlags,x
FinishProjectileFlagInitialization:
LFFF0:  rts
