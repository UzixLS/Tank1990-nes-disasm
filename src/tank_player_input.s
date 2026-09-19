; Управление танками игроков и общие no-op handlers ($DB75-$DBF0).
PlayerDirectionCandidate = $00

; Преобразует ввод двух игроков в направление и класс $A их ObjectState.
; Кадры FrameCounter mod 4 = 2 пропускаются. Ввод принимается только для активного
; танка с классом $8-$D. При повороте не на 180° X/Y привязываются к сетке 8 px.
; PlayerStunTimer+X и отрицательные значения PlayerIceState+X могут временно запретить ввод.
; Побочные эффекты: ObjectState/ObjectX/ObjectY, PlayerStunTimer,
; PlayerIceState[0..1] и состояние аудиопотока начала скольжения. Stun-таймер
; уменьшается только в обслуживаемые вводом кадры. Y сохраняется; при полном
; проходе X=$FF, а на пропущенном кадре X остаётся входным. Портит A,
; PlayerDirectionCandidate и flags; ObjectFrame эта процедура не меняет.
UpdatePlayerTankInput:
LDB75:  lda     FrameCounter
        and     #PlayerTankScheduleOddFrameMask
        bne     ProcessPlayerTankInput
        lda     FrameCounter
        and     #PlayerTankScheduleModulo4Mask
        bne     NoOpHandler
ProcessPlayerTankInput:
LDB81:  ldx     #(PlayerTankCount-1)
UpdatePlayerInputForSlot:
LDB83:  lda     ObjectState,x
        bpl     AdvanceToPreviousPlayer
        cmp     #NonTargetableTankStateMin
        bcs     AdvanceToPreviousPlayer
        lda     PlayerStunTimer,x
        beq     ReadPlayerDirection
        dec     PlayerStunTimer,x
        jmp     SetPlayerTankIdleState

ReadPlayerDirection:
LDB94:  lda     PlayerIceState,x
        bpl     DecodePlayerDirectionButtons
        and     #PlayerIceInputLockFlag
        bne     SetPlayerTankIdleState
DecodePlayerDirectionButtons:
LDB9D:  lda     Joy1Held,x
        jsr     DecodeDirectionButtons
        sta     PlayerDirectionCandidate
        bpl     ApplyPlayerDirection
; Без принятого направления переводит танк в класс $8 с флагом бита 3.
SetPlayerTankIdleState:
LDBA6:  lda     #TankStateIdleClass
        jsr     SetTankStateClass
        lda     #TankIdlePhaseFlag
        ora     ObjectState,x
        sta     ObjectState,x
        jmp     AdvanceToPreviousPlayer

ApplyPlayerDirection:
LDBB4:  lda     PlayerIceState,x
        bpl     AlignPlayerTankForTurn
        and     #PlayerIcePhaseMask
        bne     AlignPlayerTankForTurn
        lda     #PlayerIceReloadValue
        sta     PlayerIceState,x
        lda     #AudioStateStartRequested
        sta     IceSlideStartAudioState
; Перекрёстный поворот выравнивает танк по сетке; разворот на 180° не выравнивает.
AlignPlayerTankForTurn:
LDBC7:  lda     ObjectState,x
        and     #DirectionMask
        cmp     PlayerDirectionCandidate
        beq     CommitPlayerTankDirection
        eor     #DirectionOppositeXor
        cmp     PlayerDirectionCandidate
        beq     CommitPlayerTankDirection
        lda     ObjectX,x
        clc
        adc     #TankGridRoundingBias
        and     #TankGridAlignmentMask
        sta     ObjectX,x
        lda     ObjectY,x
        clc
        adc     #TankGridRoundingBias
        and     #TankGridAlignmentMask
        sta     ObjectY,x
CommitPlayerTankDirection:
LDBE7:  lda     PlayerDirectionCandidate
        ora     #TankStateActiveClass
        sta     ObjectState,x
AdvanceToPreviousPlayer:
LDBED:  dex
        bpl     UpdatePlayerInputForSlot
NoOpHandler:
TankLogicState0:
TankDrawState0:
ProjectileLogicState0:
ProjectileDrawState0:
; Общий пустой обработчик сохраняет A/X/Y/RAM и возвращает вызывающему
; выставленные до входа processor flags.
LDBF0:  rts
