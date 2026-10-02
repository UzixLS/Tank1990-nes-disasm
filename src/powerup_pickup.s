; Обнаружение подбора усиления и диспетчеризация эффекта ($E972-$E9F1).

; Проверяет объект в (PowerUpX,PowerUpY) против способных подобрать его танков.
;
; Вход:
;   PowerUpX=0 — объекта нет; PowerUpPickupDisplayTimer!=0 — объект уже взят.
;   BeginPowerUpCollectorScan задаёт PowerUpCollectorSlot: 1..0 при беззнаковом
;   GameVariant<8, иначе 7..0. PowerUpType=$FF используется SpawnPowerUp как
;   проба занятого места; настоящий тип обязан быть 0..7.
; Выход при отсутствии подбора:
;   ранние выходы сохраняют X/Y; полный проход оставляет
;   PowerUpCollectorSlot=$FF и X=0. A и флаги зависят от пути.
; Выход при пробе размещения:
;   PowerUpPickupDisplayTimer=$32, X=слот пересёкшегося танка; эффект, очки и
;   звук не запускаются. SpawnPowerUp трактует ненулевой таймер как collision.
; Выход при настоящем подборе:
;   таймер=$32, затем управление передаётся обработчику типа. Диспетчер снимает
;   со стека адрес возврата JSR UpdatePowerUpPickup, поэтому RTS обработчика
;   возвращает сразу вызывающему текущей процедуры gameplay-tick и пропускает
;   оставшиеся в нём обновления этого кадра. Прямой caller обязан иметь именно
;   этот совместимый JSR/RTS stack layout.
;
; Пересечение — |ObjectX-PowerUpX|<12 и |ObjectY-PowerUpY|<12. Модуль берётся
; восьмибитным two's-complement, то есть расстояние фактически циклическое по
; модулю 256; при обычных экранных координатах получается квадрат 23x23.
; Допустимы только состояния ObjectState=$80..$DF.
;
; Обычная награда — упакованные BCD 500 очков; helper начисляет её только
; слотам игроков 0/1. После него проверяются пороги extra life и запрашивается
; pickup-звук, в том числе если в расширенном варианте collector — противник.
; Значение $06 в ProjectileY+4 пропускает очки, проверку порогов и этот звук,
; но не таймер и не эффект. Это не отдельная постоянная RAM-переменная, а
; временно переиспользуемый байт projectile slot 4.
;
; Процедура не вызывает RNG и непосредственно не пишет PPU/OAM. Таймер позднее
; рисует collected marker через OAM: начальное $32 даёт 49 видимых кадров,
; после чего renderer обнуляет PowerUpX. PPU/OAM/audio могут менять обработчики.
PowerUpRewardSuppressionByte     = ProjectileY + 4
PowerUpPickupHalfExtent         = 12
PowerUpPickupDisplayDuration    = $32
PowerUpPackedScoreAward         = $50
PowerUpRewardSuppressionSentinel = $06
UpdatePowerUpPickup:
LE972:  lda     PowerUpX
        beq     FinishPowerUpPickupScan
        lda     PowerUpPickupDisplayTimer
        bne     FinishPowerUpPickupScan
        jmp     BeginPowerUpCollectorScan

; Недостижимый NOP между trampoline LE55B и циклом проверки.
UnreferencedE97dNop:
LE97D:  .byte   $EA
CheckPowerUpTankOverlap:
LE97E:  ldx     PowerUpCollectorSlot
        ; Только живой/активный диапазон состояний $80..$DF.
        lda     ObjectState,x
        bpl     AdvancePowerUpCollectorScan
        cmp     #NonTargetableTankStateMin
        bcs     AdvancePowerUpCollectorScan
        ; Восьмибитный модуль dx; >=12 исключает слот до проверки dy.
        lda     ObjectX,x
        sec
        sbc     PowerUpX
        bpl     PowerUpXDistanceReady
        eor     #$FF
        clc
        adc     #$01
PowerUpXDistanceReady:
LE994:  cmp     #PowerUpPickupHalfExtent
        bcs     AdvancePowerUpCollectorScan
        ; Восьмибитный модуль dy; обе оси должны быть строго меньше 12.
        lda     ObjectY,x
        sec
        sbc     PowerUpY
        bpl     PowerUpYDistanceReady
        eor     #$FF
        clc
        adc     #$01
PowerUpYDistanceReady:
LE9A4:  cmp     #PowerUpPickupHalfExtent
        bcs     AdvancePowerUpCollectorScan
        ; Один байт служит и countdown маркера, и флагом неудачной placement probe.
        lda     #PowerUpPickupDisplayDuration
        sta     PowerUpPickupDisplayTimer
        lda     PowerUpType
        bmi     FinishPowerUpPickupScan
        ; Волатильный sentinel отменяет reward/audio, но не сам handler.
        lda     PowerUpRewardSuppressionByte
        cmp     #PowerUpRewardSuppressionSentinel
        beq     DispatchCollectedPowerUp
        lda     #PowerUpPackedScoreAward
        jsr     PreparePackedScoreIncrement
        ldx     PowerUpCollectorSlot
        ; Для X>=2 helper не меняет счёт; threshold scan всё равно выполняется.
        jsr     AddPreparedScoreForPlayerSlot
        jsr     AwardScoreThresholdLives
        ldx     PowerUpCollectorSlot
        lda     #AudioStateStartRequested
        sta     PowerUpPickupAudioState
DispatchCollectedPowerUp:
LE9CA:  lda     PowerUpType
        ; Тип обязан быть 0..7: проверки верхней границы перед таблицей нет.
        asl     a
        tay
        lda     PowerUpEffectHandlers,y
        sta     ScratchPtrLo
        lda     PowerUpEffectHandlers+1,y
        sta     ScratchPtrHi
        ; Отбросить return address UpdatePowerUpPickup и tail-dispatch handler.
        pla
        pla
        jmp     (ScratchPtrLo)

AdvancePowerUpCollectorScan:
LE9DD:  dec     PowerUpCollectorSlot
        bpl     CheckPowerUpTankOverlap
FinishPowerUpPickupScan:
LE9E1:  rts

; Формат: ровно восемь little-endian адресов, индекс PowerUpType*2. Проверки
; границ нет: неотрицательное значение >7 читает за концом таблицы. Порядок
; обязан совпадать с SelectPowerUpTypeForVariant и визуальным индексом
; PowerUpFirstTypeTile+4*PowerUpType. Обработчики должны завершаться RTS либо
; эквивалентным tail-call и учитывать, что X — slot collector-а. Номерам не
; назначаются недоказанные игровые названия: ряд эффектов различается для
; игрока и противника, а эффект 2 дополнительно меняет PPU shadow/очередь.
PowerUpEffectHandlers:
LE9E2:  .word   PowerUpEffect0,PowerUpEffect1,PowerUpEffect2,PowerUpEffect3
        .word   PowerUpEffect4,PowerUpEffect5,PowerUpEffect6,PowerUpEffect7
