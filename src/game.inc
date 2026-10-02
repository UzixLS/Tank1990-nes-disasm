; Общие игровые константы. Здесь находятся только значения, смысл которых
; одинаков во всех использующих их подсистемах.

; Object slots 0/1 — игроки, 2..7 — враги. Projectile slots дополнительно
; имеют 8/9 для вторых выстрелов игроков; изменение counts требует менять
; физические размеры параллельных RAM arrays, а не только границы циклов.
Player1TankSlot       = $00
Player2TankSlot       = $01
PlayerTankCount       = $02
FirstEnemyTankSlot    = $02
TankSlotCount         = $08
ProjectileSlotCount   = $0A

; Поле 13x13; packed row хранит 13 nibbles TSA и один padding nibble в 7 bytes.
StageWidthMetatiles   = 13
StageHeightMetatiles  = 13
PackedStageRowSize    = 7
PackedStageByteSize   = StageHeightMetatiles * PackedStageRowSize
FirstStageNumber      = 1
StandardStageUpperBound = $32
ExtendedStageUpperBound = $76
ExtendedStageVariant    = $06

; High-byte delta from shadow $04xx..$07xx to the selected PPU nametable.
ShadowToPrimaryNametableOffset = $1C ; -> $2000..$23FF
ShadowToNametable2800Offset     = $24 ; -> $2800..$2BFF

; Geometry of the 6-tile-wide base/enclosure block in the primary nametable.
BaseEnclosureColumn   = $0C
BaseCoreColumn        = $0E
BaseEnclosureBlankRow = $18
BaseEnclosureTopRow   = $19
BaseCoreUpperRow      = $1A
BaseCoreLowerRow      = $1B

; GameMode одновременно задаёт конфигурацию fire-input и inclusive верхний
; enemy slot: 5/6/7 дают соответственно четыре/пять/шесть enemy objects 2..N.
; Штатное title menu выбирает 5 или 7; точное 6 включает pressed A-or-B path.
OnePlayerGameMode     = $05
CombinedFireGameMode  = $06
TwoPlayerGameMode     = $07
; Специальный протокол attract: sentinel выбирает classic map 32 через
; descriptor 6, после чего StageSetLength=2 остаётся runtime-маркером.
; Маркер включает HUD P2, отключает transition object и начисление очков.
AttractStageLoadSentinel = $FF
AttractMapStageNumber    = $20
AttractMapSetSelector    = $06
AttractStageSetMarker = $02
; Не variant index, а sentinel cold/software reset: frontend открывает
; модальное variant-меню, которое заменяет маркер выбранным значением.
BootVariantMarker     = $AB

; Direction encoding общий для state low bits и всех четырёхэлементных таблиц:
; 0=up, 1=left, 2=down, 3=right (константы DIRECTION_* в hardware.inc).
DirectionMask         = $03
DirectionOppositeXor  = $02
TankGridSubpixelMask  = $07
TankGridAlignmentMask = $F8
TankGridRoundingBias  = $04
TankTrackFrameBit     = $04
TankIdlePhaseStep     = $04
TankIdlePhaseMask     = $0C
PlayerTankScheduleOddFrameMask = $01
PlayerTankScheduleModulo4Mask  = $03
; State dispatch использует high nibble как class и 2*class как word offset.
; DispatchWordIndexMask лишь выравнивает offset, но НЕ ограничивает table bounds.
StateClassMask        = $F0
DispatchWordIndexMask = $FE
; Младшая тетрада state включает не только direction, но и фазу/таймер;
; при замене класса её нельзя сокращать до DirectionMask.
StateLowNibbleMask    = $0F
GameVariantIndexMask  = $0F
ObjectAttributeClassMask = $F0
; Классы E/F продолжают переходную анимацию, но проверки столкновений,
; управления и выбора целей уже исключают их.
NonTargetableTankStateMin= $E0

; BattleState: точный $80 — активный бой; base hit запускает положительный
; countdown $27..0. Многие consumers различают sign/exact value, а не enum.
BattleStateActive               = $80
BattleStateBaseDestructionStart = $27
; Tank state: high nibble $8..$D — targetable logic classes; low nibble хранит
; direction/phase. Destroyed=$73 и spawning=$F0 лежат вне этого диапазона.
TankStateIdleClass    = $80
TankIdlePhaseFlag     = $08
TankStateTurningClass = $90
TankStateActiveClass  = $A0
TankStateTargetBaseClass      = $B0
TankStateTargetPlayerTwoClass = $C0
TankStateTargetPlayerOneClass = $D0
TankStateDestroyed    = $73
TankStateSpawning     = $F0
; Projectile state: $40|direction — active; $33->$23->$13 — impact phases.
ProjectileStateActive = $40
ProjectileStateImpact = $33

; Terrain shadow codes ниже $12 блокируют projectile/tank paths по разным
; правилам; base quadrants $C8..$CF сохраняют orientation в bits1..0.
TerrainTileBrick             = $0F
TerrainTileSteel             = $10
TerrainTileBoundary          = $11
TerrainTileClassMask         = $FC
TerrainTileIntactBaseClass   = $C8
BaseTileIntactUpperLeft      = $C8
BaseTileIntactLowerLeft      = $C9
BaseTileIntactUpperRight     = $CA
BaseTileIntactLowerRight     = $CB
BaseTileDestroyedUpperLeft   = $CC
BaseTileDestroyedLowerLeft   = $CD
BaseTileDestroyedUpperRight  = $CE
BaseTileDestroyedLowerRight  = $CF

; Классические уровни улучшения занимают старшие биты attributes. Значение $63
; — отдельный максимальный режим Tank 1990, а не следующий равномерный шаг.
PlayerUpgradeLevel1   = $20
PlayerUpgradeLevel2   = $40
PlayerUpgradeLevel3   = $60
PlayerUpgradeMaximum  = $63

; Timer constants имеют разные единицы: freeze/shield/base decrement на
; FrameCounter mod64, а stun уменьшается player-input scheduler-ом.
EnemyFreezePowerUpDuration      = $0A
PlayerShieldPowerUpDuration     = $0A
PlayerStunPowerUpDuration       = $C8
BaseFortificationPowerUpDuration = $14

; Младшие два бита enemy attributes — оставшиеся дополнительные попадания;
; bit 2 заставляет подбитого противника создать усиление и включает мигающую палитру.
EnemyHitPointMask       = $03
EnemyPowerUpCarrierFlag = $04
ExtendedVariantPlayerHitAttributeBits = $20

; EmitOamSprite добавляет эту маску только над специальным terrain-тайлом $22.
TerrainPriorityDisabled = $00
TerrainPriorityEnabled  = $20

PlayerIceTile          = $21
PlayerIceActiveFlag    = $80
PlayerIceInactiveMask  = $7F
PlayerIceInputLockFlag = $10
PlayerIcePhaseMask     = $1F
PlayerIceReloadValue   = $9C

AudioStateOff            = $00
AudioStateStartRequested = $01
AudioStateActive         = $02
