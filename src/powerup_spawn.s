; Создание и позиционирование усиления на поле ($E8BE-$E90F).

; Выбирает свободную позицию и тип появляющегося power-up.
; PowerUpX/Y получают одну из координат 48,96,144,192. Пока кандидат пересекается
; с активным танком, UpdatePowerUpPickup ставит PowerUpPickupDisplayTimer и
; генерация повторяется. PowerUpType=$FF служит sentinel «ещё не создано».
; После выбора позиции случайный индекс 0..7 проходит через
; SelectPowerUpTypeForVariant. В конце восстанавливает X/Y из caller-owned
; TankCollisionSlot/ProjectileCollisionSlot; меняет A, RNG, аудиосостояние и поля бонуса.
SpawnPowerUp:
LE8BE:  lda     #AudioStateStartRequested
        sta     PowerUpSpawnAudioState
ChoosePowerUpCoordinates:
LE8C3:  jsr     NextRandomByte
        and     #$03
        jsr     GridIndexToPowerUpCoordinate
        sta     PowerUpX
        jsr     NextRandomByte
        and     #$03
        jsr     GridIndexToPowerUpCoordinate
        sta     PowerUpY
        lda     #$FF
        sta     PowerUpType
        lda     #$00
        sta     PowerUpPickupDisplayTimer
        jsr     UpdatePowerUpPickup
        lda     PowerUpPickupDisplayTimer
        bne     ChoosePowerUpCoordinates
        jsr     NextRandomByte
        and     #$07
        tay
        jsr     SelectPowerUpTypeForVariant
        sta     PowerUpType
        lda     #$00
        sta     PowerUpPickupDisplayTimer
        ldx     TankCollisionSlot
        ldy     ProjectileCollisionSlot
        rts

; Полный вариант разрешает все восемь типов без преобразования.
AllPowerUpTypes:
LE8FA:  .byte   $00,$01,$02,$03,$04,$05,$06,$07

; Преобразует A=0..3 в координату (A*6+6)*8: 48,96,144,192.
; Выход A; меняет PowerUpCoordinateGridIndex и флаги, X/Y сохраняет.
GridIndexToPowerUpCoordinate:
LE902:  sta     PowerUpCoordinateGridIndex
        asl     a
        clc
        adc     PowerUpCoordinateGridIndex
        asl     a
        clc
        adc     #$06
        asl     a
        asl     a
        asl     a
        rts
