; Таблицы runtime и данные checksum target ($C59D-$C5D8).

; Начальный EnemyActivityInterval для этапов 1..11 выбирается из первых
; 12-StageNumber элементов. Interval управляет и spawn delay, и ветвлением AI.
; Последний $3A штатным StageNumber 1..11 не выбирается.
EarlyStageActivityIntervalTable:
LC59D:  .byte   $03,$08,$0D,$12,$17,$1C,$21,$26
        .byte   $2B,$30,$35,$3A
; Равновероятные классы врага: старшая тетрада задаёт sprite/type и после
; уничтожения преобразуется в индекс статистики/награды 0..3.
EnemyTypeAttributeBits:
LC5A9:  .byte   $80,$A0,$C0,$E0
; Начальное число дополнительных попаданий в bits0..1.
EnemyHitPointAttributeBits:
LC5AD:  .byte   $02,$00,$01,$00,$01,$00,$01,$00
; Байты $C5B5..$C5BE лежат между двумя восьмиэлементными таблицами.
; Индекс EnemyHitPointAttributeBits ограничен 0..7; других статических ссылок
; на этот нулевой промежуток нет.
UnreferencedC5b5Zeros:
        .byte   $00,$00,$00,$00,$00,$00,$00,$00
        .byte   $00,$00
; Bit2 помечает носителя power-up; попадание создаёт бонус, рендер мигает.
EnemyPowerUpCarrierAttributeBits:
LC5BF:  .byte   $04,$04,$00,$00,$00,$00,$00,$00
; Два нулевых байта без статических ссылок отделяют таблицу от checksum-блока.
UnreferencedC5c7Prefix:
LC5C7:  .byte   $00,$00
; Этот $FF-терминированный поток используется как заголовок variant menu и
; продолжается через $C5D0 до первого $FF по $C5D5. Одновременно первые семь
; байтов входят в runtime XOR. Инициализатор оставляет этот адрес в ScratchPtr,
; но позднее volatile pointer перезаписывается; checksum guard прыгает по его
; текущему, а не гарантированно этому значению. Первый байт $40 есть RTI.
; Смысл отдельных тайлов потока сверх экранного использования не уточняется.
VariantMenuHeaderText:
RuntimeChecksumInitialJumpTarget:
LC5C9:  .byte   $40,$20,$59,$69,$53,$20,$31
; Продолжение variant-menu потока; в семибайтный checksum-блок не входит.
VariantMenuHeaderTextTail:
LC5D0:  .byte   $39,$39,$30,$69,$32
; Первый $FF завершает VariantMenuHeaderText, ещё три заполняют остаток до $C5D9.
PaddingBeforeClearScreenAndAudio:
VariantMenuHeaderTextTerminator:
LC5D5:  .byte   $FF
        .byte   $FF,$FF,$FF
