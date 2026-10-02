; Управление танками игроков и общие no-op handlers ($DB75-$DBF0).
PlayerDirectionCandidate = $00

; Преобразует удерживаемый D-pad двух игроков в active state $A0..$A3. Слоты
; обходятся в порядке P2, P1. Кадры FrameCounter mod4 = 0,1,3 обслуживаются,
; фаза 2 пропускается целиком. Для каждого слота приоритет проверок такой:
;   1. только ObjectState $80..$DF допускает управление;
;   2. ненулевой stun timer уменьшается и принудительно выбирает idle;
;   3. на льду bit4 PlayerIceState блокирует ввод и также выбирает idle;
;   4. Joy*Held декодируется с приоритетом Right, Left, Down, Up.
; Поэтому несколько направлений не нейтрализуют друг друга: выбирается первое
; по указанному приоритету. Отсутствие направления тоже переводит танк в idle.
;
; Idle формируется как (old state & $0F)|$80|$08: direction и прочие младшие
; phase bits сохраняются, bit3 устанавливается. Принятое направление полностью
; заменяет state на $A0..$A3. Совпадающее и противоположное направления не
; меняют координаты; только поворот на перпендикулярную ось округляет обе
; координаты к ближайшему узлу 8 px как (coord+4)&$F8.
;
; При установленном ice bit7 и нулевых bits0..4 первый принятый direction
; перезагружает PlayerIceState=$9C и запрашивает IceSlideStartAudioState=1.
; При bit4=0 и ненулевой младшей фазе направление принимается без перезагрузки
; и звука; вне льда low bits PlayerIceState здесь игнорируются. Сам ice
; countdown уменьшается не этой процедурой, а TankLogicState8 во время инерции.
;
; Побочно может менять ObjectState/ObjectX/ObjectY, PlayerStunTimer,
; PlayerIceState[0..1] и IceSlideStartAudioState; ObjectFrame, input, RNG,
; PPU/OAM и terrain не меняет. Stun уменьшается только в обслуживаемый кадр и
; только пока state лежит в $80..$DF; значение 1 становится 0, но ввод в тот же
; tick ещё не принимается. На полном проходе X=$FF, Y сохранён, A — результат
; обработки P1; PlayerDirectionCandidate и flags изменены по пройденным ветвям.
; На пропущенной фазе возвращает A=$02, сохраняя входные X/Y и всю RAM.
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
        ; Destruction/no-op $00..$7F и spawn $E0..$FF ввода не получают.
LDB83:  lda     ObjectState,x
        bpl     AdvanceToPreviousPlayer
        cmp     #NonTargetableTankStateMin
        bcs     AdvanceToPreviousPlayer
        lda     PlayerStunTimer,x
        beq     ReadPlayerDirection
        ; Даже последний stun tick принудительно ставит idle state.
        dec     PlayerStunTimer,x
        jmp     SetPlayerTankIdleState

ReadPlayerDirection:
LDB94:  lda     PlayerIceState,x
        bpl     DecodePlayerDirectionButtons
        and     #PlayerIceInputLockFlag
        bne     SetPlayerTankIdleState
DecodePlayerDirectionButtons:
        ; Используется held, поэтому направление действует непрерывно без repeat.
LDB9D:  lda     Joy1Held,x
        jsr     DecodeDirectionButtons
        sta     PlayerDirectionCandidate
        bpl     ApplyPlayerDirection
; Без принятого направления или при stun/ice-lock переводит танк в класс $8,
; сохраняя low nibble старого state и устанавливая в нём bit3.
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
        ; Начало нового участка скольжения: counter/lock=$1C плюс ice bit7.
        lda     #PlayerIceReloadValue
        sta     PlayerIceState,x
        lda     #AudioStateStartRequested
        sta     IceSlideStartAudioState
; Только поворот между вертикальной и горизонтальной осями выравнивает танк;
; продолжение прежнего направления и разворот на 180 градусов не выравнивают.
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
        ; Active state не наследует idle/target phase bits, только direction 0..3.
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
; выставленные до входа processor flags. Для UpdatePlayerTankInput это также
; exit фазы FrameCounter mod4=2; остальные имена — state-class 0 dispatch.
LDBF0:  rts
