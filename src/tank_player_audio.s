; Аудиосостояние движения игроков ($DB0B-$DB47).

; Поддерживает циклический audio stream 17, пока хотя бы у одного игрока есть
; held D-pad и ненулевой ObjectState. Приоритет проверки P1, затем P2; класс
; state, GameMode, stun/ice и фактическое изменение координат не проверяются.
;
; Если stream state=0 и найдено движение, пишет start request=1. Любое уже
; ненулевое значение сохраняет, пока движение продолжается; когда оба игрока
; не движутся, пишет off=0. Поэтому нестандартное ненулевое состояние тоже
; удерживается, а не нормализуется к active=2.
; Выход: A=1/Z=0 при найденном игроке, иначе A=0/Z=1; N=0, C/V и Y сохранены.
; X=0, если первым подошёл P1, иначе X=1. Меняет только
; PlayerMovementLoopAudioState; APU, OAM, PPU и прочую RAM не трогает.
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

; Вход: X=0/1. Возвращает A=1/Z=0, если ObjectState игрока ненулевой и нажат
; хотя бы один D-pad bit; иначе A=0/Z=1. N=0, C/V, X/Y, RAM и стек сохраняются.
; Bounds check нет: X вне 0..1 одновременно читает несвязанные input/object slots.
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
