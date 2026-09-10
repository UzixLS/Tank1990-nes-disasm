; Подтверждённые области RAM. Неизученные игровые переменные пока оставлены
; числовыми адресами, чтобы не закреплять за ними ошибочную семантику.

; Рабочий байт palette/attributes для DrawMetatile и OAM emitters.
; Индексированные обращения $00,X..$07,X используют тот же адрес как часть scratch-записи.
RenderAttributes  = $04
NametablePpuOffset = $05
Joy1Held        = $06
Joy2Held        = $07
Joy1Pressed     = $08
Joy2Pressed     = $09
SlowFrameCounter= $0A
FrameCounter    = $0B
PpuBufferPos    = $0C
OamBufferPos    = $0D
OamBufferStep   = $0E
RandomState     = $0F
RandomIndex     = $10

ScratchPtrLo    = $11
ScratchPtrHi    = $12
AuxPtrLo        = $13
AuxPtrHi        = $14

; Интерфейс terrain-процедур: пиксельная точка сохраняется в $47/$48,
; а выбранная 4x4-подобласть — одной из масок $01/$02/$04/$08 в $00.
TerrainSubcellMask = $00
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

Player1Score    = $15
Player2Score    = $1D
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
BackgroundPaletteIndex = $4D

VerticalScroll  = $4F
NametableBits   = $50
Player1Lives    = $51
Player2Lives    = $52
OamTile         = $53
TileTranslationOffset = $60
; После подбора удерживает короткую экранную индикацию. Во время поиска
; позиции нового бонуса временно используется как признак пересечения.
PowerUpPickupDisplayTimer = $62
PlayerExtraLifeAwarded = $66
BattleState     = $68
EnemySpawnColumn= $6A
DigitBlankMode  = $6B
GameMode        = $6C
PauseState      = $6D
SpriteBehindTerrainMask = $6E
PlayerStunTimer = $6F
TankTargetX     = $71
TankTargetY     = $72
Player1KillCounts = $73
Player2KillCounts = $77
EnemiesToSpawn  = $7F
EnemiesRemaining= $80
EnemySpawnTimer = $82
MenuSelection   = $83
; Темп одновременно задаёт период появления противников и ветвление AI.
EnemyActivityInterval = $84
StageNumber     = $85
PowerUpX        = $86
PowerUpY        = $87
PowerUpType     = $88
PlayerShieldTimer = $89
RuntimeChecksumExpected = $8C
RuntimeChecksumActual = $8D
AllPowerUpsEnabled = $8E
; До выбора карты хранит индекс набора; после чтения дескриптора — его длину.
StageSetSelector = $8F
StageSetLength   = $8F

ObjectX         = $90
ObjectY         = $98
ObjectState     = $A0
ObjectAttributes= $A8
ObjectFrame     = $B0

ProjectileX     = $B8
ProjectileY     = $C2
ProjectileState = $CC
ProjectileFlags = $D6

EnemyFreezeTimer = $0100
PlayerUpgradeLevel = $0101
; Два байта игроков. Bit7 показывает нахождение на льду (тайл $21);
; младшие биты ведут фазу/задержку скольжения и блокировки нового ввода.
PlayerIceState   = $0103
; Маленький движущийся объект создаётся при выбытии одного из игроков,
; пока второй продолжает бой; точное экранное значение графики не установлено.
TransitionObjectX    = $0105
TransitionObjectY    = $0106
TransitionObjectDirection = $0107
TransitionObjectTimer= $0108
DebugRamIndex   = $0109
RestartSignature = $0110

; Восемь расширений танков лежат в $0170-$0177; соседние $0178-$0179
; переиспользуются как дополнительные уровни улучшения игроков.
ObjectSpecialState = $0170
PlayerExtendedUpgrade = ObjectSpecialState + $08

; 28 состояний аудиопотоков: 0=выключен, 1=запрошен запуск, 2=активен.
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
SessionResultPulse1AudioState = AudioStreamStates + $15
SessionResultPulse2AudioState = AudioStreamStates + $16
SessionResultTriangleAudioState = AudioStreamStates + $17
StatisticsWinnerBonusAudioState = AudioStreamStates + $1B
AudioStreamRecords= $031C

AudioStatePtrLo = $F0
AudioStatePtrHi = $F1
AudioDataPtrLo  = $F2
AudioDataPtrHi  = $F3
AudioStreamIndex    = $F4
AudioStreamLimit = $F5
AudioLoopCounters = $F6
AudioWorkLo     = $FD
AudioWorkHi     = $FE

PpuUpdateBuffer = $0180
OamShadow       = $0200
NametableShadow = $0400
NametableShadowPage1 = NametableShadow + $0100
NametableShadowPage2 = NametableShadow + $0200
NametableShadowPage3 = NametableShadow + $0300
NametableAttributes  = NametableShadow + $03C0
BaseAttributeUpper   = NametableAttributes + $33
BaseAttributeLower   = NametableAttributes + $34
