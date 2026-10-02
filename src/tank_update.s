; Главный проход логики танков и dispatch состояний ($DBF1-$DC51).

EnemyEveryFrameAttributeClass = $A0
EnemyFreezeTickFrameMask      = $3F
TankUpdateParityMask          = $01

; Обходит slots 7..0 и диспетчеризует логику их state-классов. Игроки 0/1
; обновляются при FrameCounter mod4 = 0,1,3 и пропускаются только в фазе 2.
; Для разрешённых врагов attribute-class $A0 снимает parity throttling;
; остальные обновляются, когда младшие биты slot и FrameCounter различаются.
;
; Ненулевой EnemyFreezeTimer раз в 64 кадра уменьшается до начала прохода.
; Если он стал нулём, враги размораживаются уже в этом проходе. Пока timer
; остаётся ненулевым, у врагов пропускаются только обычные классы $8..$D;
; no-op/destruction $0..$7 и spawn $E/$F продолжают работать по расписанию.
; Игроков freeze не затрагивает.
;
; Выход: CurrentTankSlot=$FF. A/X/Y, ScratchPtr и flags зависят от последнего
; исполненного handler; при пропуске последнего slot часть регистров может
; сохранять более ранние результаты. Меняет EnemyFreezeTimer только на фазе
; FrameCounter mod64=0. Остальные Object/PPU/OAM/audio side effects полностью
; определяются вызванными handlers.
UpdateTanks:
LDBF1:  lda     #(TankSlotCount-1)
        sta     CurrentTankSlot
        lda     EnemyFreezeTimer
        beq     UpdateNextTank
        lda     FrameCounter
        and     #EnemyFreezeTickFrameMask
        bne     UpdateNextTank
        dec     EnemyFreezeTimer
UpdateNextTank:
LDC03:  ldx     CurrentTankSlot
        cpx     #FirstEnemyTankSlot
        bcs     CheckEnemyTankSchedule
        lda     FrameCounter
        and     #PlayerTankScheduleOddFrameMask
        bne     RunTankLogicForSlot
        lda     FrameCounter
        and     #PlayerTankScheduleModulo4Mask
        bne     SkipTankLogicForSlot
        jmp     RunTankLogicForSlot

CheckEnemyTankSchedule:
LDC18:  lda     EnemyFreezeTimer
        beq     ApplyTankUpdateSchedule
        ; Freeze не задерживает завершение destruction и spawn-анимацию.
        lda     ObjectState,x
        bpl     ApplyTankUpdateSchedule
        cmp     #NonTargetableTankStateMin
        bcc     SkipTankLogicForSlot
ApplyTankUpdateSchedule:
LDC25:  lda     ObjectAttributes,x
        and     #ObjectAttributeClassMask
        cmp     #EnemyEveryFrameAttributeClass
        beq     RunTankLogicForSlot
        lda     CurrentTankSlot
        eor     FrameCounter
        and     #TankUpdateParityMask
        beq     SkipTankLogicForSlot
RunTankLogicForSlot:
LDC35:  jsr     DispatchTankLogic
SkipTankLogicForSlot:
LDC38:  dec     CurrentTankSlot
        bpl     UpdateNextTank
        rts

; Старшая тетрада ObjectState,X выбирает обработчик: $0 no-op, $1..$7
; destruction, $8 idle, $9 turn, $A active movement, $B target base,
; $C target player 2, $D target player 1, $E/$F spawn phases. Индекс таблицы
; равен 2*(state>>4).
; Вход: X=slot 0..7. До tail-JMP портит A/Y, ScratchPtrLo/Hi и flags, сохраняя
; X и Object RAM; итоговые outputs и все дальнейшие side effects задаёт handler.
DispatchTankLogic:
LDC3D:  lda     ObjectState,x
        lsr     a
        lsr     a
        lsr     a
        and     #DispatchWordIndexMask
        tay
        lda     TankLogicHandlers,y
        sta     ScratchPtrLo
        lda     TankLogicHandlers+1,y
        sta     ScratchPtrHi
        jmp     (ScratchPtrLo)
