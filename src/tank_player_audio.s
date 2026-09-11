; Аудиосостояние движения игроков ($DB0B-$DB47).

; Поддерживает циклический аудиопоток 17, пока хотя бы у одного игрока нажатое
; направление и его ObjectState ненулевой. Класс состояния не проверяется.
; Побочный эффект: PlayerMovementLoopAudioState принимает 0, 1 (запрос)
; или 2 (поток уже запущен).
; Портит A, X; Y не меняет.
UpdatePlayerMovementAudio:
LDB0B:  lda     PlayerMovementLoopAudioState
        beq     StartPlayerMovementAudioIfNeeded
        ldx     #$00
        jsr     IsPlayerTankMoving
        bne     ReturnFromPlayerMovementAudioUpdate
        ldx     #$01
        jsr     IsPlayerTankMoving
        bne     ReturnFromPlayerMovementAudioUpdate
        lda     #AudioStateOff
        sta     PlayerMovementLoopAudioState
        rts

StartPlayerMovementAudioIfNeeded:
LDB24:  ldx     #$00
        jsr     IsPlayerTankMoving
        bne     RequestPlayerMovementAudio
        ldx     #$01
        jsr     IsPlayerTankMoving
        beq     ReturnFromPlayerMovementAudioUpdate
RequestPlayerMovementAudio:
LDB32:  lda     #AudioStateStartRequested
        sta     PlayerMovementLoopAudioState
ReturnFromPlayerMovementAudioUpdate:
LDB37:  rts

; Вход: X=0/1. Возвращает A=1/Z=0, если ObjectState игрока ненулевой и нажато
; направление; иначе A=0/Z=1. X/Y и RAM не меняет.
IsPlayerTankMoving:
LDB38:  lda     Joy1Held,x
        and     #BUTTON_DIRECTIONS
        beq     ReturnPlayerNotMoving
        lda     ObjectState,x
        beq     ReturnPlayerNotMoving
        lda     #$01
        rts

ReturnPlayerNotMoving:
LDB45:  lda     #$00
        rts
