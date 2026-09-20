; Взаимное уничтожение сталкивающихся снарядов ($E910-$E971).

PlayerProjectileScanSlot       = $5A
ComparedProjectileSlot         = $5B
ComparedProjectileOwnerSlot    = $00
ProjectileAxisSeparationLimit  = $06
ProjectileOwnerSlotMask        = $07

; Проверяет столкновения активных снарядов друг с другом.
; Внешний проход идёт 9..0, но маска $06 оставляет только player slots
; 9,8,1,0 (именно в таком порядке); неактивные slots пропускаются. Для каждого
; выбранного снаряда внутренний проход проверяет slots 9..0. Сравнение slot&7
; исключает сам снаряд и второй slot того же владельца: 0/8 и 1/9.
; Поэтому enemy/enemy пары здесь не рассматриваются, а непересекающиеся
; player-1/player-2 пары посещаются в обоих порядках, пока оба state активны.
;
; По каждой оси берётся 8-битный модуль результата вычитания с wraparound.
; Если обе величины строго меньше 6, оба ProjectileState обнуляются без фазы
; попадания $33. Внутренний проход после этого продолжается без перепроверки
; внешнего state: один внешний снаряд может очистить несколько перекрывающихся
; внутренних, а очищенный player slot позднее не начинает свой внешний проход.
;
; Вход: нет; читает ProjectileState/X/Y всех десяти slots.
; Выход: PlayerProjectileScanSlot=$FF, X=0, N=1, Z=0. Если хотя бы один
; активный player slot начал внутренний проход, то ComparedProjectileSlot=$FF,
; ComparedProjectileOwnerSlot=0 и Y=0; иначе эти два scratch-байта и Y
; сохраняются. Пусть class0=ProjectileState[0]&StateClassMask при финальной
; проверке: A=class0 при class0<>$40, иначе A=0; C=(class0 >= $40), а V зависит
; от пути. Меняет только три scratch-байта и ProjectileState попавших снарядов;
; ProjectileX/Y/Flags, PPU/OAM, audio states, танки и счёт не меняет.
UpdateProjectileProjectileCollisions:
LE910:  lda     #(ProjectileSlotCount-1)
        sta     PlayerProjectileScanSlot
; Вход блока: PlayerProjectileScanSlot=9..0. Выбирает активный player slot;
; X получает его индекс и остаётся им на всём внутреннем проходе.
CheckNextPlayerProjectilePair:
LE914:  lda     PlayerProjectileScanSlot
        and     #PlayerProjectileSlotMask
        bne     AdvancePlayerProjectileScan
        ldx     PlayerProjectileScanSlot
        lda     ProjectileState,x
        and     #StateClassMask
        cmp     #ProjectileStateActive
        bne     AdvancePlayerProjectileScan
        lda     #(ProjectileSlotCount-1)
        sta     ComparedProjectileSlot
; Вход блока: X — активный player slot при начале прохода,
; ComparedProjectileSlot=9..0. После попадания ProjectileState,X уже может быть
; нулём, но координаты X продолжают использоваться для оставшихся сравнений.
CheckNextComparedProjectile:
LE928:  lda     ComparedProjectileSlot
        tay
        and     #ProjectileOwnerSlotMask
        sta     ComparedProjectileOwnerSlot
        lda     PlayerProjectileScanSlot
        and     #ProjectileOwnerSlotMask
        cmp     ComparedProjectileOwnerSlot
        beq     AdvanceComparedProjectile
        lda     ProjectileState,y
        and     #StateClassMask
        cmp     #ProjectileStateActive
        bne     AdvanceComparedProjectile
        lda     ProjectileX,y
        sec
        sbc     ProjectileX,x
        bpl     ProjectilePairXDistanceReady
        eor     #$FF
        clc
        adc     #$01
ProjectilePairXDistanceReady:
; A — 8-битный модуль X(inner)-X(outer); значения >=6 отвергают пару.
LE94D:  cmp     #ProjectileAxisSeparationLimit
        bcs     AdvanceComparedProjectile
        lda     ProjectileY,y
        sec
        sbc     ProjectileY,x
        bpl     ProjectilePairYDistanceReady
        eor     #$FF
        clc
        adc     #$01
ProjectilePairYDistanceReady:
; A — 8-битный модуль Y(inner)-Y(outer); значения 0..5 означают попадание.
LE95E:  cmp     #ProjectileAxisSeparationLimit
        bcs     AdvanceComparedProjectile
        lda     #$00
        sta     ProjectileState,x
        sta     ProjectileState,y
; Продолжает тот же проход даже после очистки ProjectileState,X.
AdvanceComparedProjectile:
LE969:  dec     ComparedProjectileSlot
        bpl     CheckNextComparedProjectile
AdvancePlayerProjectileScan:
LE96D:  dec     PlayerProjectileScanSlot
        bpl     CheckNextPlayerProjectilePair
        rts
