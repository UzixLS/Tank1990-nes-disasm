; Создание и позиционирование усиления на поле ($E8BE-$E90F).

PowerUpGridIndexScratch     = $00
PowerUpGridIndexMask        = $03
PowerUpTypeIndexMask        = $07
PowerUpPlacementProbeSentinel = $FF
PowerUpGridOriginUnits      = 6

; Создаёт или заменяет power-up в случайном узле сетки 4x4. Каждая координата
; независимо выбирается из 48,96,144,192 двумя вызовами NextRandomByte. Затем
; UpdatePowerUpPickup используется как проба занятости квадрата |dx|,|dy|<12:
; для GameVariant 0..7 проверяются только игроки 1..0, для 8..255 — все танки
; 7..0 в состояниях $80..$DF. Отрицательный PowerUpType=$FF запрещает реальное
; применение эффекта, но при пересечении pickup-код ставит display timer; такой
; кандидат отбрасывается, timer снова очищается и пара координат генерируется заново.
; После успешной пробы третий случайный байт даёт индекс типа 0..7. При
; AllPowerUpsEnabled=0 RestrictedPowerUpTypeTable исключает тип 7 и удваивает
; вероятность типа 3; иначе AllPowerUpTypes возвращает индекс без преобразования.
;
; Штатный вход — из projectile/tank collision: TankCollisionSlot и
; ProjectileCollisionSlot должны содержать текущие индексы. Процедура не
; сохраняет входные регистры, а в конце загружает X/Y из этих двух alias-байтов.
; Выход: A=0, X=TankCollisionSlot, Y=ProjectileCollisionSlot,
; PowerUpPickupDisplayTimer=0, PowerUpCollectorSlot=$FF; PowerUpX/Y — выбранный
; узел, PowerUpType — итоговый тип. Запрашивает PowerUpSpawnAudioState и меняет
; RandomState/RandomIndex, PowerUpGridIndexScratch и флаги. PPU/OAM, terrain,
; танки, снаряды и счёт не меняет. Число попыток и RNG-вызовов не ограничено;
; успешная первая попытка расходует ровно три случайных байта.
SpawnPowerUp:
LE8BE:  lda     #AudioStateStartRequested
        sta     PowerUpSpawnAudioState
ChoosePowerUpCandidateCoordinates:
LE8C3:  jsr     NextRandomByte
        and     #PowerUpGridIndexMask
        jsr     PowerUpGridIndexToPixelCoordinate
        sta     PowerUpX
        jsr     NextRandomByte
        and     #PowerUpGridIndexMask
        jsr     PowerUpGridIndexToPixelCoordinate
        sta     PowerUpY
        lda     #PowerUpPlacementProbeSentinel
        sta     PowerUpType
        lda     #$00
        sta     PowerUpPickupDisplayTimer
        jsr     UpdatePowerUpPickup
        lda     PowerUpPickupDisplayTimer
        bne     ChoosePowerUpCandidateCoordinates
        jsr     NextRandomByte
        and     #PowerUpTypeIndexMask
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

; Преобразует индекс A=0..3 в пиксельную координату (A*6+6)*8:
; 48,96,144,192. Вход вне 0..3 не поддерживается: 8-битная арифметика
; переполняется без проверки. Выход: A=координата, PowerUpGridIndexScratch=вход;
; X/Y и остальная RAM сохраняются, N/Z/C отражают последний ASL.
PowerUpGridIndexToPixelCoordinate:
LE902:  sta     PowerUpGridIndexScratch
        asl     a
        clc
        adc     PowerUpGridIndexScratch
        asl     a
        clc
        adc     #PowerUpGridOriginUnits
        asl     a
        asl     a
        asl     a
        rts
