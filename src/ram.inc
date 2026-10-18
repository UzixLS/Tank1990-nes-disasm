; Общие переменные RAM. Адреса неизвестного назначения остаются числовыми.
; Временные байты $00-$05, $47-$48, $54-$5F и $64-$65 имеют локальные имена
; в модулях и могут перезаписываться при вызовах других процедур.

; $00-$03 — общий low-zero-page scratch: terrain subcell, input shift byte,
; арифметический operand, temporary state bits, raster planes и т.п. Некоторые
; indexed record operations также обращаются к $00,X..$07,X.
; $04/$05 — рабочие bytes rendering/nametable API, тоже не persistent.
RenderAttributes  = $04
NametablePpuOffset = $05
; Две двухбайтные записи контроллеров: held[0..1] и rising-edge pressed[0..1].
Joy1Held        = $06
Joy2Held        = $07
Joy1Pressed     = $08
Joy2Pressed     = $09
; FrameCounter растёт каждый NMI; SlowFrameCounter — при FrameCounter mod64=0.
; Оба восьмибитны и могут явно сбрасываться отдельными frontend/gameplay paths.
SlowFrameCounter= $0A
FrameCounter    = $0B
; PPU/OAM cursors — byte offsets, не counts entries; OAM step штатно +/-4.
PpuBufferPos    = $0C
OamBufferPos    = $0D
OamBufferStep   = $0E
; PRNG state и индекс deterministic feedback-read по всей zero page.
RandomState     = $0F
RandomIndex     = $10

; Обе pointer pairs volatile и повсеместно переиспользуются. Ни один общий
; calling convention не обещает сохранять их между subsystem calls.
ScratchPtrLo    = $11
ScratchPtrHi    = $12
AuxPtrLo        = $13
AuxPtrHi        = $14

; Интерфейс terrain-процедур: пиксельная точка сохраняется в $47/$48,
; а выбранная 4x4-подобласть — одной из масок $01/$02/$04/$08 в $00.
; Decimal converter переиспользует тот же $00 как сохраняемый input;
; эти две роли не могут быть одновременно живыми.
; Те же $47/$48 локально служат OAM saved X/Y, metatile tile X/Y, score owner
; и shadow-queue scratch; эти значения взаимно не сохраняются.
TerrainSubcellMask = $00
ByteToDecimalInput = $00
CollisionPointX    = $47
CollisionPointY    = $48

; Параметры InitializePlayfieldShadow. Эти байты перегружены вне вызова процедуры.
NametableRectX      = $56
NametableRectY      = $57
NametableRectHeight = $5A
NametableRectWidth  = $5B
; Координаты raster-строки разделяют те же scratch-байты с rectangle API.
RasterStringX       = $56
RasterStringY       = $57

; Score records — семь unpacked decimal digits (millions..ones) и $FF terminator.
; P1=$15..$1C, P2=$1D..$24, HighScore=$3D..$44. Область $25..$34 временно
; содержит две такие же records статистики и имеет локальные aliases там.
Player1Score    = $15
Player2Score    = $1D
; $35..$3C — ещё одна восьмибайтная decimal record. DecimalHundreds/Tens/Ones
; являются aliases её offsets4..6, а не отдельной памятью.
ScoreIncrementDigits    = $35
ScoreIncrementThousands = ScoreIncrementDigits + $03
DecimalHundreds = $39
DecimalTens     = $3A
DecimalOnes     = $3B
HighScore       = $3D

BaseFortificationTimer = $45
GameVariant     = $46
PowerUpCollectorSlot = $49
; Код скрытой комбинации на title; позднее временно служит счётчиком строк variant-меню.
TitleSecretInputCode = $4A
; Неноль сохраняет построенную Construction-карту; variant-меню временно
; переиспользует байт как младшую часть указателя на строки.
ConstructionMapFlag = $4B
; Ноль разрешает ручной выбор первого этапа, неноль автоматически запускает следующие.
StageSelectionLocked = $4C
; Pending palette-set request: $FF означает «нет запроса». NMI после upload
; возвращает $FF; имя не гарантирует, что RAM хранит уже показанную palette.
BackgroundPaletteIndex = $4D

VerticalScroll  = $4F
; Только bits0..1 выбирают base nametable; NMI OR-ит остальные PPU_CTRL bits.
NametableBits   = $50
; Два соседних счётчика; Player1Lives,X с X=0/1 выбирает игрока.
Player1Lives    = $51
Player2Lives    = $52
OamTile         = $53
; $54/$55 — парные OAM coordinates либо projectile-terrain magnitudes;
; $56..$5F — rectangle/raster/navigation/loop scratch с локальными aliases.
TileTranslationOffset = $60
; После подбора удерживает короткую экранную индикацию. Во время поиска
; позиции нового бонуса временно используется как признак пересечения.
PowerUpPickupDisplayTimer = $62
; Два player flags награды по $66/$67.
PlayerExtraLifeAwarded = $66
; BattleState=$80 активен; положительные значения — base-destruction countdown,
; ноль обозначает завершённое поражение. Иные значения требуют caller-specific
; трактовки, сравнения часто проверяют именно точный $80.
BattleState     = $68
EnemySpawnColumn= $6A
DigitBlankMode  = $6B
; GameMode=5/6/7 также является inclusive upper enemy slot для spawn scan.
GameMode        = $6C
; В основном gameplay loop любое ненулевое значение пропускает logic tick и
; ограничивает audio engine потоком pause; transition loop этот byte не читает,
; а attract использует его как mute flag.
PauseState      = $6D
; OAM attribute bits, условно OR-имые emitter-ом только над shadow tile $22;
; штатные callers используют 0 либо $20. Это render configuration, не cache.
SpriteBehindTerrainMask = $6E
; Два player timers по $6F/$70.
PlayerStunTimer = $6F
TankTargetX     = $71
TankTargetY     = $72
; По четыре счётчика типов врагов: P1=$73..$76, P2=$77..$7A.
Player1KillCounts = $73
Player2KillCounts = $77
EnemiesToSpawn  = $7F
EnemiesRemaining= $80
EnemySpawnTimer = $82
; Title selection штатно 0..2; после старта 0 означает 1P, любое ненулевое
; значение во многих gameplay/HUD paths означает наличие второго игрока.
MenuSelection   = $83
; Темп одновременно задаёт период появления противников и ветвление AI.
EnemyActivityInterval = $84
StageNumber     = $85
; PowerUpX=0 — sentinel отсутствующего объекта; Y/type могут сохранять stale payload.
PowerUpX        = $86
PowerUpY        = $87
PowerUpType     = $88
; Два player timers по $89/$8A; $8B пока не идентифицирован.
PlayerShieldTimer = $89
RuntimeChecksumExpected = $8C
RuntimeChecksumActual = $8D
AllPowerUpsEnabled = $8E
; До выбора карты хранит индекс набора; после чтения дескриптора — его длину.
StageSetSelector = $8F
StageSetLength   = $8F

; Пять параллельных восьмибайтных tank arrays, slots 0..7.
ObjectX         = $90
ObjectY         = $98
ObjectState     = $A0
ObjectAttributes= $A8
ObjectFrame     = $B0

; Четыре параллельных десятибайтных projectile arrays, slots 0..9.
ProjectileX     = $B8
ProjectileY     = $C2
ProjectileState = $CC
ProjectileFlags = $D6

; Per-tank cache transient occupancy snapshot. $E0..$E7 — low byte base
; shadow pointer; $E8..$EF — relative page bits0..1 plus left/above flags
; in bits7/6. Это не полный high byte адреса.
TankOccupancyPtrLo        = $E0
TankOccupancyPageAndFlags = $E8

EnemyFreezeTimer = $0100
; Два player upgrade bytes по $0101/$0102.
PlayerUpgradeLevel = $0101
; Два байта игроков. Bit7 показывает нахождение на льду (тайл $21);
; младшие биты ведут фазу/задержку скольжения и блокировки нового ввода.
PlayerIceState   = $0103
; Движущаяся четырёхспрайтовая надпись GAME/OVER создаётся при выбытии одного
; из игроков, пока второй продолжает бой; direction/timer задают её скольжение.
TransitionObjectX    = $0105
TransitionObjectY    = $0106
TransitionObjectDirection = $0107
TransitionObjectTimer= $0108
DebugRamIndex   = $0109
; 16-byte warm-restart signature occupies $0110..$011F. Она лежит в stack-page
; ниже штатного SP=$6F: глубина стека свыше 80 bytes начнёт её затирать.
RestartSignature          = $0110
RestartSignatureByteCount = $10

; Восемь расширений танков лежат в $0170-$0177; соседние $0178-$0179
; переиспользуются как дополнительные уровни улучшения игроков. Reset extension
; очищает весь $0170..$017F, включая пока неидентифицированный хвост $017A..$017F.
ObjectSpecialState = $0170
PlayerExtendedUpgrade = ObjectSpecialState + $08

; 28 состояний аудиопотоков: 0=выключен, 1=запрошен запуск, 2=активен.
; Любое другое ненулевое значение движок также обрабатывает как active.
; Индекс state соответствует восьмибайтной record в $031C..$03FB.
AudioStreamStates  = $0300
PauseAudioState = AudioStreamStates + $00
StageIntroPulse1AudioState = AudioStreamStates + $01
StageIntroTriangleAudioState = AudioStreamStates + $02
StageIntroPulse2AudioState = AudioStreamStates + $03
ExtraLifePulse1AudioState = AudioStreamStates + $04
ExtraLifePulse2AudioState = AudioStreamStates + $05
PowerUpPickupAudioState = AudioStreamStates + $06
PlayerOrBaseDestructionNoiseAudioState = AudioStreamStates + $07
PowerUpSpawnAudioState = AudioStreamStates + $09
TankDestructionAudioState = AudioStreamStates + $0A
BaseDestructionToneAudioState = AudioStreamStates + $0B
BrickHitAudioState = AudioStreamStates + $0C
RicochetOrMenuStepAudioState = AudioStreamStates + $0D
ArmorHitAudioState = AudioStreamStates + $0E
PlayerFireAudioState = AudioStreamStates + $0F
IceSlideStartAudioState = AudioStreamStates + $10
PlayerMovementLoopAudioState = AudioStreamStates + $11
GameplayLoopAudioState = AudioStreamStates + $12
StatisticsCountPulseAudioState = AudioStreamStates + $13
StatisticsCountNoiseAudioState = AudioStreamStates + $14
NewHighScorePulse1AudioState = AudioStreamStates + $15
NewHighScorePulse2AudioState = AudioStreamStates + $16
NewHighScoreTriangleAudioState = AudioStreamStates + $17
StatisticsWinnerBonusAudioState = AudioStreamStates + $1B
AudioStreamRecords= $031C

AudioStatePtrLo = $F0
AudioStatePtrHi = $F1
AudioDataPtrLo  = $F2
AudioDataPtrHi  = $F3
AudioStreamIndex    = $F4
AudioStreamLimit = $F5
AudioLoopCounters = $F6
; $F6..$F8 — три loop counters; $F9..$FC — четыре frame-local channel claims,
; названные локально в audio engine. $FD/$FE — общий audio scratch/pointer.
AudioWorkLo     = $FD
AudioWorkHi     = $FE

; $0180..$01FF — 128-byte PPU command queue; cursor API дополнительно пишет
; lookahead по индексу PpuBufferPos. $0200..$02FF — полный OAM DMA shadow.
PpuUpdateBuffer = $0180
OamShadow       = $0200
; Четыре страницы $0400..$07FF образуют единый 1 KiB nametable shadow:
; 30 rows*32 tile bytes и attributes $07C0..$07FF.
NametableShadow = $0400
NametableShadowPage1 = NametableShadow + $0100
NametableShadowPage2 = NametableShadow + $0200
NametableShadowPage3 = NametableShadow + $0300
NametableAttributes  = NametableShadow + $03C0
; Соседние attribute bytes одной строки: left покрывает tile columns 12..15,
; right — 16..19 (rows 24..27).
BaseAttributeLeft    = NametableAttributes + $33
BaseAttributeRight   = NametableAttributes + $34
