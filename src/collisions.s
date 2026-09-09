; Столкновения снарядов с местностью/танками, бонусы и диспетчеризация ($E604-$EA50).

; Проверяет активные снаряды 9..0 против местности в теневой nametable.
; Активен state-class $40. Снаряды с нулевым ProjectileFlags проверяются
; через кадр по чётности slot^FrameCounter, остальные — каждый кадр.
; Для направления из младших двух битов ProjectileState вычисляются две
; передние стороны снаряда; каждая сторона может затронуть две соседние
; 4x4-подобласти местности. Это позволяет разрушать соответствующую часть кирпича.
; Побочно меняет A/X/Y, ScratchPtr, $00, $47/$48, $54/$55, $64/$65,
; $5A, состояние базы $68, shadow/PPU-очередь, состояния снарядов и
; флаги событий $0307/$030B/$030C/$030D.
UpdateProjectileTerrainCollisions:
LE604:  lda     #$09
        sta     $5A
LE608:  ldx     $5A
        lda     ProjectileState,x
        and     #$F0
        cmp     #$40
        bne     LE68B
        lda     ProjectileFlags,x
        bne     LE61D
        txa
        eor     FrameCounter
        and     #$01
        beq     LE68B
; Абсолютные компоненты направления: $54=|dx|, $55=|dy|;
; $64/$65 — те же компоненты, умноженные на 4 для второй точки стороны.
PrepareProjectileTerrainOffsets:
LE61D:  lda     ProjectileState,x
        and     #$03
        tay
        lda     ProjectileDirectionStepX,y
        bpl     LE62C
        eor     #$FF
        clc
        adc     #$01
LE62C:  sta     $54
        asl     a
        asl     a
        sta     $64
        lda     ProjectileDirectionStepY,y
        bpl     LE63C
        eor     #$FF
        clc
        adc     #$01
LE63C:  sta     $55
        asl     a
        asl     a
        sta     $65
        ldy     ProjectileY,x
        lda     ProjectileX,x
        tax
        jsr     ProbeProjectileTerrainAtPixel
        beq     LE65F
        ldx     $5A
        lda     ProjectileY,x
        clc
        adc     $64
        sta     $48
        lda     ProjectileX,x
        clc
        adc     $65
        sta     $47
        jsr     ResolveProjectileTerrainHit
LE65F:  ldx     $5A
        lda     ProjectileY,x
        sec
        sbc     $54
        tay
        lda     ProjectileX,x
        sec
        sbc     $55
        tax
        jsr     ProbeProjectileTerrainAtPixel
        beq     LE68B
        ldx     $5A
        lda     ProjectileY,x
        sec
        sbc     $64
        sec
        sbc     $54
        sta     $48
        lda     ProjectileX,x
        sec
        sbc     $65
        sec
        sbc     $55
        sta     $47
        jsr     ResolveProjectileTerrainHit
LE68B:  dec     $5A
        bmi     LE692
        jmp     LE608

LE692:  rts

; Проверяет terrain в пиксельной точке X/Y.
; Сохраняет координаты в $47/$48, вычисляет ScratchPtr и маску подобласти,
; затем проваливается в ResolveProjectileTerrainHit.
; Возвращает A=1 только при частичном разрушении обычного terrain; A=0 для
; отсутствия столкновения, целого уничтожения тайла, стали/границы и базы.
ProbeProjectileTerrainAtPixel:
LE693:  stx     $47
        sty     $48
        jsr     PixelCoordinatesToShadowPointer
ResolveProjectileTerrainHit:
LE69A:  jsr     RecomputeTerrainSubcellMask
        jsr     TestTerrainSubcell
        beq     LE709
        lda     (ScratchPtrLo),y
        and     #$FC
        cmp     #$C8
        bne     LE6C6
        ; $C8-$CB — четыре тайла целой базы.
        lda     $68
        beq     LE6C6
        lda     #$27
        sta     $68
        lda     #$01
        sta     $030B
        sta     $0307
        jsr     DrawDestroyedBase
        ldx     $5A
        lda     #$33
        sta     ProjectileState,x
        jmp     LE709

ClassifyProjectileTerrainTile:
LE6C6:  lda     (ScratchPtrLo),y
        jmp     ClassifyTerrainForProjectile

; Недостижимый NOP между безусловным JMP и следующим обработчиком.
UnreferencedE6cbNop:
LE6CB:  .byte   $EA
; Общий путь попадания в непроходимый terrain: переводит снаряд в state $33.
; $11 — неразрушаемая граница; $10 — сталь, которую разрушает только флаг $02.
; Остальные значения < $12 теряют выбранный бит 4x4-подобласти.
DestroyProjectileOnTerrain:
LE6CC:  ldx     $5A
        lda     #$33
        sta     ProjectileState,x
        lda     (ScratchPtrLo),y
        cmp     #$11
        beq     LE700
        lda     ProjectileFlags,x
        and     #$02
        beq     LE6EB
; Очищает весь байт terrain и ставит событие $030C. Сам ProjectileState не
; меняет: обычный усиленный выстрел приходит сюда уже со state $33, а особый
; путь tile $22 входит напрямую и потому сохраняет летящий снаряд.
DestroyWholeTerrainTile:
LE6DE:  lda     #$00
        jsr     StoreAndQueueShadowTile
        lda     #$01
        sta     $030C
        jmp     LE709

LE6EB:  lda     (ScratchPtrLo),y
        cmp     #$10
        beq     LE700
        cpx     #$02
        bcs     LE6FA
        lda     #$01
        sta     $030C
DestroyTerrainSubcell:
LE6FA:  jsr     ClearTerrainSubcellQueued
        lda     #$01
        rts

LE700:  cpx     #$02
        bcs     LE709
        lda     #$01
        sta     $030D
LE709:  lda     #$00
        rts

; Общий проход снарядов по танкам.
; Фаза 1 проверяет игроков Object 1..0 против активных вражеских снарядов 7..2.
; Попадание определяется квадратом |dx|<10, |dy|<10. Таймер $89,X поглощает
; снаряд без взрыва; иначе управление передаётся HandleProjectileHitOnTank.
; AdvanceTankCollisionPass из high-bank возвращает сюда для следующего игрока.
; Фаза 2 проверяет врагов Object 7..2 против логических снарядов игроков
; в слотах 0,1,8,9, начисляет уничтожения и очки.
; Побочно меняет A/X/Y, $47, $5A/$5B, ProjectileState, состояния/атрибуты
; танков, статистику $73-$7A, записи счёта и звуковые/bonus-флаги. Условное
; создание бонуса также меняет RNG, $0309, $49, $62 и $86-$88.
UpdateProjectileTankCollisions:
LE70C:  lda     #$01
        sta     $5A
CheckNextPlayerTank:
LE710:
        ldx     $5A
        lda     ObjectState,x
        bpl     LE71A
        cmp     #$E0
        bcc     LE71D
LE71A:  jmp     LE77A

CheckEnemyProjectilesAgainstPlayer:
LE71D:  lda     #$07
        sta     $5B
LE721:  ldy     $5B
        lda     ProjectileState,y
        and     #$F0
        cmp     #$40
        bne     LE772
        lda     ProjectileX,y
        sec
        sbc     ObjectX,x
        bpl     LE739
        eor     #$FF
        clc
        adc     #$01
LE739:  cmp     #$0A
        bcs     LE772
        lda     ProjectileY,y
        sec
        sbc     ObjectY,x
        bpl     LE74A
        eor     #$FF
        clc
        adc     #$01
LE74A:  cmp     #$0A
        bcs     LE772
        lda     #$33
        sta     ProjectileState,y
        lda     $89,x
        beq     LE75F
        lda     #$00
        sta     ProjectileState,y
        jmp     LE772

LE75F:  jmp     HandleProjectileHitOnTank

; Недостижимый NOP после безусловного JMP.
UnreferencedE762Nop:
LE762:  .byte   $EA
; Хвост реакции игрока на попадание: получает variant bits,
; зеркалит их в $0178/$0101/ObjectAttributes и продолжает общий проход.
ApplyPlayerHitVariantState:
LE763:
        jsr     GetVariantAttributeBits
        nop
        sta     $0178,x
        sta     $0101,x
        sta     ObjectAttributes,x
        jmp     LE77A

LE772:  dec     $5B
        lda     $5B
        cmp     #$01
        bne     LE721
; JSR вызывает проход игроков повторно через внутренний JMP из
; AdvanceTankCollisionPass. Первый
; переход сохраняет адрес возврата на стеке, второй вызов при $5A<0 возвращается
; сюда и запускает проход врагов. Его RTS разматывает сохранённый адрес и тем же
; способом запускает проход врагов второй раз, после чего следующий RTS выходит
; к исходному вызывающему. Это намеренная стековая схема, а не обычный цикл.
AdvancePlayerCollisionPassOrBeginEnemyPass:
LE77A:  jsr     AdvanceTankCollisionPass
        nop
        lda     #$07
        sta     $5A
LE782:  ldx     $5A
        lda     ObjectState,x
        bpl     LE78C
        cmp     #$E0
        bcc     LE78F
LE78C:  jmp     LE834

CheckPlayerProjectilesAgainstEnemy:
LE78F:  lda     #$09
        sta     $5B
LE793:  lda     $5B
        and     #$06
        beq     LE79C
        ; Только слоты 0,1,8,9 принадлежат логическим выстрелам игроков.
        jmp     LE82D

LE79C:  ldy     $5B
        lda     ProjectileState,y
        and     #$F0
        cmp     #$40
        beq     LE7AA
        jmp     LE82D

LE7AA:  lda     ProjectileX,y
        sec
        sbc     ObjectX,x
        bpl     LE7B7
        eor     #$FF
        clc
        adc     #$01
LE7B7:  cmp     #$0A
        bcs     LE82D
        lda     ProjectileY,y
        sec
        sbc     ObjectY,x
        bpl     LE7C8
        eor     #$FF
        clc
        adc     #$01
LE7C8:  cmp     #$0A
        bcs     LE82D
        lda     #$33
        sta     ProjectileState,y
        lda     ObjectAttributes,x
        and     #$04
        beq     LE7E2
        jsr     SpawnPowerUp
        lda     ObjectAttributes,x
        cmp     #$E4
        bne     LE7E2
        dec     ObjectAttributes,x
; Низкие два бита атрибутов работают как дополнительные hit points.
DamageOrDestroyEnemyTank:
LE7E2:  lda     ObjectAttributes,x
        and     #$03
        beq     LE7F2
        dec     ObjectAttributes,x
        lda     #$01
        sta     $030E
        jmp     LE82D

; Полное уничтожение: state $73, событие $030A, статистика типа/владельца
; и, кроме специального режима $8F=2, награда 100..400 очков.
DestroyEnemyTankAndAwardScore:
LE7F2:  jsr     DestroyTankAndClearExtension
        nop
        lda     #$01
        sta     $030A
        lda     ObjectAttributes,x
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        sec
        sbc     #$04
        tax
        lda     $5B
        and     #$01
        sta     $47
        bne     LE813
        inc     $73,x
        jmp     LE815

LE813:  inc     $77,x
LE815:  lda     $8F
        cmp     #$02
        beq     LE834
        lda     EnemyTypeScoreAwards,x
        jsr     PreparePackedScoreIncrement
        lda     $47
        tax
        jsr     AddScoreDigitsToRecord
        jsr     AwardScoreThresholdLives
        jmp     LE834

LE82D:  dec     $5B
        bmi     LE834
        jmp     LE793

LE834:  dec     $5A
        lda     $5A
        cmp     #$01
        beq     LE83F
        jmp     LE782

LE83F:  rts

; Четырнадцать фиксированных восьмибайтных строк скрытого variant-меню.
; LC4F9 выбирает запись младшим байтом $40+index*8 при старшем $E8.
VariantMenuTankNames:
LE840:  .byte   $54,$41,$4E,$4B,$20,$20,$41,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$42,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$43,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$44,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$45,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$46,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$47,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$48,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$49,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$4A,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$4B,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$4C,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$4D,$FF
        .byte   $54,$41,$4E,$4B,$20,$20,$4E,$FF
; Дубликат строки-курсора из screens.s; статических ссылок на эту копию нет.
VariantMenuCursorText:
LE8B0:  .byte   $5D,$FF
; Строка с пробелом используется при стирании курсора variant-меню.
VariantMenuBlankCursorText:
LE8B2:  .byte   $20,$FF
; Шесть байтов заполнения между строкой стирания курсора и таблицей очков.
; Все равны $FF; статических ссылок внутрь диапазона $E8B4-$E8B9 нет.
UnreferencedE8b4Fill:
LE8B4:  .byte   $FF,$FF,$FF,$FF,$FF,$FF

; Упакованные десятичные награды за типы врагов; фактически 100..400 очков.
EnemyTypeScoreAwards:
LE8BA:  .byte   $10,$20,$30,$40

; Выбирает свободную позицию и тип появляющегося power-up.
; $86/$87 получают одну из координат 48,96,144,192. Пока кандидат пересекается
; с активным танком, CheckPowerUpTankOverlap ставит $62 и генерация повторяется.
; Во время проверки $88=$FF служит sentinel «ещё не создано». После успешной
; позиции случайный индекс 0..7 проходит через SelectPowerUpTypeForVariant,
; результат сохраняется в $88, $62 обнуляется.
; В конце восстанавливает X/Y из caller-owned $5A/$5B; меняет A, RNG,
; $0309, $49, $62, $86-$88.
SpawnPowerUp:
LE8BE:  lda     #$01
        sta     $0309
LE8C3:  jsr     NextRandomByte
        and     #$03
        jsr     GridIndexToPowerUpCoordinate
        sta     $86
        jsr     NextRandomByte
        and     #$03
        jsr     GridIndexToPowerUpCoordinate
        sta     $87
        lda     #$FF
        sta     $88
        lda     #$00
        sta     $62
        jsr     UpdatePowerUpPickup
        lda     $62
        bne     LE8C3
        jsr     NextRandomByte
        and     #$07
        tay
        jsr     SelectPowerUpTypeForVariant
        sta     $88
        lda     #$00
        sta     $62
        ldx     $5A
        ldy     $5B
        rts

; Полный вариант разрешает все восемь типов без преобразования.
AllPowerUpTypes:
LE8FA:  .byte   $00,$01,$02,$03,$04,$05,$06,$07

; Преобразует A=0..3 в координату (A*6+6)*8: 48,96,144,192.
; Выход A; меняет scratch $00 и флаги, X/Y сохраняет.
GridIndexToPowerUpCoordinate:
LE902:  sta     $00
        asl     a
        clc
        adc     $00
        asl     a
        clc
        adc     #$06
        asl     a
        asl     a
        asl     a
        rts

; Проверяет столкновения активных снарядов друг с другом.
; Внешний цикл рассматривает только логические player slots 0,1,8,9;
; внутренний — все 10 слотов. Пары с одинаковым индексом modulo 8 исключаются,
; поэтому основные и дополнительные слоты одного владельца не гасят друг друга.
; При |dx|<6 и |dy|<6 оба ProjectileState обнуляются без взрывного state $33.
; Побочно меняет A/X/Y, $00, $5A/$5B и ProjectileState; прочую RAM не меняет.
UpdateProjectileProjectileCollisions:
LE910:  lda     #$09
        sta     $5A
LE914:  lda     $5A
        and     #$06
        bne     LE96D
        ldx     $5A
        lda     ProjectileState,x
        and     #$F0
        cmp     #$40
        bne     LE96D
        lda     #$09
        sta     $5B
LE928:  lda     $5B
        tay
        and     #$07
        sta     $00
        lda     $5A
        and     #$07
        cmp     $00
        beq     LE969
        lda     ProjectileState,y
        and     #$F0
        cmp     #$40
        bne     LE969
        lda     ProjectileX,y
        sec
        sbc     ProjectileX,x
        bpl     LE94D
        eor     #$FF
        clc
        adc     #$01
LE94D:  cmp     #$06
        bcs     LE969
        lda     ProjectileY,y
        sec
        sbc     ProjectileY,x
        bpl     LE95E
        eor     #$FF
        clc
        adc     #$01
LE95E:  cmp     #$06
        bcs     LE969
        lda     #$00
        sta     ProjectileState,x
        sta     ProjectileState,y
LE969:  dec     $5B
        bpl     LE928
LE96D:  dec     $5A
        bpl     LE914
        rts

; Проверяет power-up в ($86,$87) против активных танков.
; $86=0 означает отсутствие power-up; $62!=0 запрещает повторную проверку.
; Scan helper LE55B выбирает через $49 слоты 1..0 при $46<=7 или 7..0 при
; $46>7, затем передаёт управление CheckPowerUpTankOverlap.
; Квадрат захвата: |dx|<12, |dy|<12.
; При $88=$FF процедура используется SpawnPowerUp только как проверка свободного
; места: ставит $62=$32 и возвращается без эффекта. При $88=0..7 выполняет pickup:
; при $C6!=$06 добавляет 500 очков сборщику X<2 и ставит $0306; для X>=2
; счёт не меняется. Значение $C6=$06 пропускает оба действия, но всё равно
; dispatch'ит выбранный эффект.
; Побочно меняет A/X/Y, $49/$62, счёт/жизни/audio flags; обработчик эффекта
; может менять произвольное игровое состояние. При dispatch снимает со стека
; собственный адрес возврата. Поэтому RTS обработчика разматывает ещё один уровень
; стека и пропускает остаток процедуры, которая вызвала UpdatePowerUpPickup.
UpdatePowerUpPickup:
LE972:  lda     $86
        beq     LE9E1
        lda     $62
        bne     LE9E1
        jmp     BeginPowerUpCollectorScan

; Недостижимый NOP между trampoline LE55B и циклом проверки.
UnreferencedE97dNop:
LE97D:  .byte   $EA
CheckPowerUpTankOverlap:
LE97E:  ldx     $49
        lda     ObjectState,x
        bpl     LE9DD
        cmp     #$E0
        bcs     LE9DD
        lda     ObjectX,x
        sec
        sbc     $86
        bpl     LE994
        eor     #$FF
        clc
        adc     #$01
LE994:  cmp     #$0C
        bcs     LE9DD
        lda     ObjectY,x
        sec
        sbc     $87
        bpl     LE9A4
        eor     #$FF
        clc
        adc     #$01
LE9A4:  cmp     #$0C
        bcs     LE9DD
        lda     #$32
        sta     $62
        lda     $88
        bmi     LE9E1
        lda     $C6
        cmp     #$06
        beq     LE9CA
        lda     #$50
        jsr     PreparePackedScoreIncrement
        ldx     $49
        ; AddPreparedScoreForPlayerSlot работает только для слотов игроков 0/1.
        jsr     AddPreparedScoreForPlayerSlot
        jsr     AwardScoreThresholdLives
        ldx     $49
        lda     #$01
        sta     $0306
DispatchCollectedPowerUp:
LE9CA:  lda     $88
        asl     a
        tay
        lda     PowerUpEffectHandlers,y
        sta     ScratchPtrLo
        lda     PowerUpEffectHandlers+1,y
        sta     ScratchPtrHi
        pla
        pla
        jmp     (ScratchPtrLo)

LE9DD:  dec     $49
        bpl     LE97E
LE9E1:  rts

; Восемь 16-битных адресов обработчиков, индекс $88*2. Номера здесь намеренно
; не получают игровые имена, но наблюдаемые действия таковы:
; 0 — таймер защиты игрока / преобразование атрибутов врагов;
; 1 — общий таймер либо таймеры игроков; 2 — блоки вокруг базы;
; 3 — повышение атрибутов; 4 — уничтожение танков противоположной стороны;
; 5 — жизнь игроку / преобразование атрибутов врагов; 6 — максимум атрибутов;
; 7 — включение дополнительного состояния $0170,X.
PowerUpEffectHandlers:
LE9E2:  .word   PowerUpEffect0,PowerUpEffect1,PowerUpEffect2,PowerUpEffect3
        .word   PowerUpEffect4,PowerUpEffect5,PowerUpEffect6,PowerUpEffect7

; Увеличивает StageNumber. Обычно возвращает новое значение в A.
; Для variant ($46&$0F)=6 диапазон равен 1..$76: $77 заменяется на 1. В этом
; variant процедура всегда снимает адрес возврата и безвозвратно переходит в
; цикл обновления номера LC172, даже когда переход через границу не понадобился.
; Меняет A, StageNumber и флаги; X/Y сохраняются.
AdvanceStageNumber:
LE9F2:  inc     StageNumber
        lda     $46
        and     #$0F
        cmp     #$06
        beq     LE9FF
        lda     StageNumber
        rts

LE9FF:  lda     StageNumber
        cmp     #$77
        bne     LEA09
        lda     #$01
        sta     StageNumber
LEA09:  pla
        pla
        jmp     StageSelectionInputLoop

; Сохранённый недостижимый байт после безусловного перехода StageSelectionInputLoop.
; Статических ссылок на него и следующий trampoline не найдено.
UnreferencedEa0eByte:
LEA0E:  .byte   $01
UnreferencedMaximumUpgradeTrampoline:
LEA0F:
        jmp     SetMaximumObjectUpgrade

; Классифицирует tile, прочитанный ProbeProjectileTerrainAtPixel.
; Вход: A=tile, $5A=projectile slot, ScratchPtr/Y/$00 указывают подобласть.
; Для player slots 0,1,8,9 и улучшения $0178,owner >= $A0 tile $22 может быть
; полностью очищен без остановки снаряда. Tile >=$12 в остальных случаях
; пропускает снаряд; tile <$12 передаётся DestroyProjectileOnTerrain.
; Выход и побочные эффекты совпадают с ResolveProjectileTerrainHit.
ClassifyTerrainForProjectile:
LEA12:  pha
        lda     $5A
        and     #$06
        bne     LEA2E
        lda     $5A
        and     #$01
        tax
        lda     $0178,x
        cmp     #$A0
        bcc     LEA2E
        nop
        pla
        cmp     #$22
        bne     LEA2F
        jmp     DestroyWholeTerrainTile

LEA2E:  pla
LEA2F:  cmp     #$12
        bcc     LEA36
        jmp     LE709

LEA36:  jmp     DestroyProjectileOnTerrain

; Неиспользуемый напрямую адаптер: очищает $0178,X, загружает $0101,X
; и передаёт управление MergeTankAttributeBits.
; Меняет A, ObjectAttributes/ObjectFrame и $0178,X; X/Y сохраняются.
ClearUpgradeExtensionAndRefreshAttributes:
LEA39:  lda     #$00
        sta     $0178,x
        lda     $0101,x
        jmp     MergeTankAttributeBits

; Сохранённый недостижимый байт после хвостового JMP MergeTankAttributeBits;
; следующий адрес $EA45 является самостоятельным entry point. Ссылок нет.
UnreferencedEa44Byte:
LEA44:  .byte   $03
; Небольшой адаптер без статических ссылок: пишет A в audio/event flag $0305.
; RAM кроме $0305 и регистры X/Y не меняет.
StoreEventFlag0305:
LEA45:  sta     $0305
        rts
; Знаковые единичные векторы для направлений Up,Left,Down,Right.
ProjectileDirectionStepX:
LEA49:  .byte   $00,$FF,$00,$01
ProjectileDirectionStepY:
LEA4D:  .byte   $FF,$00,$01,$00
