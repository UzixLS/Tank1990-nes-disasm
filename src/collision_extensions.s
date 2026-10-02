; Расширения обработки попаданий и прохода коллизий ($FF66-$FFC0).

; Обрабатывает уже подтверждённое попадание enemy projectile в игрока.
; Вход: X строго 0/1, Y=projectile slot, PlayerShieldTimer,X=0;
; caller уже записал ProjectileState,Y=ProjectileStateImpact. Эта процедура
; снаряд больше не меняет. Выход из X=0/1 обязателен: оба
; upgrade-массива и PlayerShieldTimer имеют лишь два байта.
;
; Любое ненулевое ObjectSpecialState,X расходуется как одно поглощённое
; попадание: очищается только special-state, не играет audio и не
; меняются ObjectState/upgrades/attributes. Без special-state точно
; PlayerUpgradeMaximum=$63 понижается до $40 с ArmorHitAudioState=1;
; $40 зеркалируется в PlayerUpgradeLevel, PlayerExtendedUpgrade и
; ObjectAttributes. Любое другое значение upgrade, включая нештатное,
; ставит ObjectState=$73, запрашивает destruction audio и записывает
; variant-bits $00/$20 во все три upgrade/attribute-поля.
;
; Ни одна ветвь не делает RTS: хвостовые JMP сохраняют на стеке
; return address текущего collision pass и передают его сложному
; AdvancePlayerCollisionPassOrBeginEnemyPass. Y до continuation сохранён;
; A/flags портятся, X остаётся player slot. PPU/OAM/RNG напрямую не трогаются.
HandleProjectileHitOnPlayer:
LFF66:  lda     ObjectSpecialState,x
        beq     ApplyProjectileHitWithoutSpecialProtection
        lda     #$00
        sta     ObjectSpecialState,x
        jmp     AdvancePlayerCollisionPassOrBeginEnemyPass

ApplyProjectileHitWithoutSpecialProtection:
LFF73:  lda     PlayerUpgradeLevel,x
        cmp     #PlayerUpgradeMaximum
        beq     DowngradeMaximumPlayerUpgrade
        lda     #TankStateDestroyed
        sta     ObjectState,x
        jmp     ApplyPlayerHitVariantState

DowngradeMaximumPlayerUpgrade:
LFF81:  lda     #AudioStateStartRequested
        sta     ArmorHitAudioState
        lda     #PlayerUpgradeLevel2
        sta     PlayerUpgradeLevel,x
        sta     PlayerExtendedUpgrade,x
        sta     ObjectAttributes,x
        jmp     AdvancePlayerCollisionPassOrBeginEnemyPass

; Запрашивает PlayerOrBaseDestructionNoiseAudioState=1 и возвращает
; attribute bits для destroyed-игрока. Это sign-test, а не lookup варианта:
; любой GameVariant с bit7 даёт A=ExtendedVariantPlayerHitAttributeBits=$20,
; любой неотрицательный — A=0. На выходе N=0, Z=(A==0); C/V сохранены,
; X/Y и вся RAM, кроме audio state, сохранены. APU запишет audio engine позже.
RequestPlayerDestructionAudioAndGetVariantBits:
LFF93:  lda     #AudioStateStartRequested
        sta     PlayerOrBaseDestructionNoiseAudioState
        lda     GameVariant
        bmi     ReturnExtendedVariantHitAttributeBits
        lda     #$00
        rts

ReturnExtendedVariantHitAttributeBits:
LFF9F:  lda     #ExtendedVariantPlayerHitAttributeBits
        rts

; Одиночный байт $01 по $FFA2; статических ссылок нет.
UnreferencedFfa2Byte:
        .byte   $01
; Записывает A в ObjectAttributes,X и tail-JMP-ом передаёт тот же
; return address общему collision continuation. STA/JMP сохраняют A/X/Y и flags
; до его первой инструкции; bounds-check X нет.
StoreAttributesAndContinueCollisionPass:
LFFA3:  sta     ObjectAttributes,x
        jmp     AdvancePlayerCollisionPassOrBeginEnemyPass
; Стековый хвост прохода по игрокам. Вход: X=только что обработанный
; player slot, TankCollisionSlot равен ему, на стеке лежит return address из JSR
; AdvancePlayerTankCollisionPass в общем continuation. Если ObjectState,X точно
; TankStateDestroyed=$73, очищает ObjectSpecialState,X; иные inactive/non-targetable
; states сами по себе special-state не сбрасывают.
;
; После DEC TankCollisionSlot неотрицательное значение tail-JMP-ом входит
; в CheckNextPlayerTank, не снимая стековый кадр. При переходе 0->$FF RTS
; снимает именно этот кадр и попадает в enemy-pass setup после JSR.
; Заменять эту пару JSR/RTS на простой JMP нельзя: проход намеренно
; накапливает continuation-кадры и так запускает два enemy passes.
;
; На ветви RTS: TankCollisionSlot=$FF, X/Y сохранены, N=1/Z=0 от DEC;
; A=0 и C=1, если state был $73, иначе A=ObjectState,X и C=(A>=$73).
; V сохранён со входа. На tail-ветви регистры далее портит caller.
AdvancePlayerTankCollisionPass:
LFFA8:  lda     ObjectState,x
        cmp     #TankStateDestroyed
        bne     AdvancePlayerCollisionSlot
        lda     #$00
        sta     ObjectSpecialState,x
AdvancePlayerCollisionSlot:
LFFB3:  dec     TankCollisionSlot
        bpl     ContinuePlayerCollisionPass
        rts

ContinuePlayerCollisionPass:
LFFB8:  jmp     CheckNextPlayerTank

; Очищает ObjectSpecialState,X без bounds-check. Штатный X=0..7;
; за пределами восьми слотов адресация затронет соседнюю RAM.
; Выход: A=0, N=0/Z=1; C/V и X/Y сохранены; других side effects нет.
ClearObjectSpecialState:
ClearObjectExtensionState:
LFFBB:  lda     #$00
        sta     ObjectSpecialState,x
        rts
