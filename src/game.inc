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

DirectionMask         = $03
StateClassMask        = $F0
; Классы E/F продолжают переходную анимацию, но проверки столкновений,
; управления и выбора целей уже исключают их.
NonTargetableTankStateMin= $E0

BattleStateActive     = $80
TankStateDestroyed    = $73
TankStateSpawning     = $F0
ProjectileStateActive = $40
ProjectileStateImpact = $33

PlayerIceTile          = $21
PlayerIceActiveFlag    = $80
PlayerIceInactiveMask  = $7F
PlayerIceInputLockFlag = $10
PlayerIceReloadValue   = $9C

AudioStateOff            = $00
AudioStateStartRequested = $01
AudioStateActive         = $02
