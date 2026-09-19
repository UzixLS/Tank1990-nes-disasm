; Общие игровые константы. Здесь находятся только значения, смысл которых
; одинаков во всех использующих их подсистемах.

PlayerTankCount       = $02
FirstEnemyTankSlot    = $02
TankSlotCount         = $08
ProjectileSlotCount   = $0A

StageWidthMetatiles   = 13
StageHeightMetatiles  = 13
PackedStageRowSize    = 7
PackedStageByteSize   = StageHeightMetatiles * PackedStageRowSize
FirstStageNumber      = 1
StandardStageUpperBound = $32
ExtendedStageUpperBound = $76
ExtendedStageVariant    = $06

; GameMode одновременно задаёт конфигурацию игроков и верхний enemy-slot.
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
BootVariantMarker     = $AB

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

BattleStateActive     = $80
TankStateIdleClass    = $80
TankIdlePhaseFlag     = $08
TankStateTurningClass = $90
TankStateActiveClass  = $A0
TankStateTargetBaseClass      = $B0
TankStateTargetPlayerTwoClass = $C0
TankStateTargetPlayerOneClass = $D0
TankStateDestroyed    = $73
TankStateSpawning     = $F0
ProjectileStateActive = $40
ProjectileStateImpact = $33

; Классические уровни улучшения занимают старшие биты attributes. Значение $63
; — отдельный максимальный режим Tank 1990, а не следующий равномерный шаг.
PlayerUpgradeLevel1   = $20
PlayerUpgradeLevel2   = $40
PlayerUpgradeLevel3   = $60
PlayerUpgradeMaximum  = $63

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
