; Подтверждённые области RAM. Неизученные игровые переменные пока оставлены
; числовыми адресами, чтобы не закреплять за ними ошибочную семантику.

Joy1Held        = $06
Joy2Held        = $07
Joy1Pressed     = $08
Joy2Pressed     = $09
FrameCounter    = $0B
PpuBufferPos    = $0C

ScratchPtrLo    = $11
ScratchPtrHi    = $12
AuxPtrLo        = $13
AuxPtrHi        = $14

VerticalScroll  = $4F
NametableBits   = $50
Player1Lives    = $51
Player2Lives    = $52
GameMode        = $6C
MenuSelection   = $83
StageNumber     = $85

ObjectX         = $90
ObjectY         = $98
ObjectState     = $A0
ObjectAttributes= $A8
ObjectFrame     = $B0

AudioStatePtrLo = $F0
AudioStatePtrHi = $F1
AudioDataPtrLo  = $F2
AudioDataPtrHi  = $F3
AudioChannel    = $F4
AudioChannelCount = $F5
AudioLoopCounters = $F6
AudioWorkLo     = $FD
AudioWorkHi     = $FE

PpuUpdateBuffer = $0180
OamShadow       = $0200
NametableShadow = $0400
