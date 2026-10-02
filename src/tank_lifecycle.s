; Разрушение, удаление, появление и переходные состояния танков ($DDEA-$DE71).

TankDestructionClassStep        = $10
DefaultTankDestructionPhase     = $03
IntermediateDestructionPhase    = $06
PlayerOneGameOverStartX         = $20
PlayerTwoGameOverStartX         = $C0
GameOverSlideY                  = $D8
GameOverSlideTimerStart         = $0D
TankSpawnPhasePastLast          = $0E
TankSpawnSecondHalfInitialState = $E0

; Классы destruction $1..$7 используют младшую тетраду как обратный счётчик.
; Каждый вызов уменьшает весь state; пока новая low phase ненулевая, класс не
; меняется. При нуле класс уменьшается на $10: обычный следующий класс получает
; phase 3, но переход $2->$1 получает удлинённую phase 6. Поэтому штатные
; классы $7..$2 длятся по три обслуженных logic tick, а финальный
; $16..$10 -- шесть: полный штатный цикл от $73 до удаления занимает 24
; обслуживания слота. Это не 24 NMI: реальная длительность зависит от
; player/enemy schedule; enemy freeze destruction-классы не задерживает.
;
; Завершение класса $1 сначала ставит ObjectState=0. У врага уменьшает
; EnemiesRemaining. У игрока уменьшает lives: ненулевой запас немедленно вызывает
; SpawnTank; окончательное выбытие при BattleStateActive и живом партнёре создаёт
; скользящую надпись GAME OVER для стороны выбывшего игрока. DEC не защищены:
; нулевые lives или EnemiesRemaining обернутся в $FF, что для игрока запустит respawn.
; Вход: X=slot класса $1..$7. Если countdown ещё ненулевой, A=новая low phase;
; при переходе класса A=полный следующий state. X/Y сохраняются, меняется только
; ObjectState,X. Завершающие outputs и дополнительные side effects задаются
; ветвями SpawnTank/GAME OVER ниже.
TankLogicStates1To7:
        dec     ObjectState,x
        lda     ObjectState,x
        and     #StateLowNibbleMask
        bne     ReturnFromTankDestructionUpdate
        lda     ObjectState,x
        sec
        sbc     #TankDestructionClassStep
        beq     FinishTankDestruction
        cmp     #TankDestructionClassStep
        bne     SetDefaultDestructionPhase
        ora     #IntermediateDestructionPhase
        jmp     CommitNextDestructionPhase

SetDefaultDestructionPhase:
LDE02:  ora     #DefaultTankDestructionPhase
CommitNextDestructionPhase:
LDE04:  sta     ObjectState,x
        rts

FinishTankDestruction:
LDE07:  sta     ObjectState,x
        cpx     #FirstEnemyTankSlot
        bcs     RemoveDestroyedEnemy
        dec     Player1Lives,x
        beq     PrepareEliminatedPlayerGameOver
        jsr     SpawnTank
        rts

RemoveDestroyedEnemy:
LDE15:  dec     EnemiesRemaining
        rts

; Если при BattleStateActive один игрок окончательно выбыл, но lives партнёра ненулевы,
; готовит четырёхспрайтовую надпись GAME OVER. Для P1 она начинает в X=$20 и
; скользит вправо, для P2 -- в X=$C0 и скользит влево, то есть в сторону центра.
; Текущий ObjectState партнёра не проверяет. При неактивном battle либо нулевых
; lives партнёра ничего не создаёт. Занятость TransitionObject тоже не проверяется:
; успешный путь безусловно перезапишет его координаты/direction/timer.
; Вход: X=выбывший player slot 0/1, его ObjectState уже 0 и lives уже уменьшены
; до 0. X/Y сохраняются; успешный путь меняет TransitionObject*, FrameCounter
; и возвращает A=0, неуспешный оставляет эти поля без изменений.
PrepareEliminatedPlayerGameOver:
LDE18:  lda     BattleState
        cmp     #BattleStateActive
        bne     ReturnFromTankDestructionUpdate
        cpx     #(PlayerTankCount-1)
        beq     PreparePlayerTwoGameOver
        lda     Player2Lives
        beq     ReturnFromTankDestructionUpdate
        lda     #DIRECTION_RIGHT
        sta     TransitionObjectDirection
        lda     #PlayerOneGameOverStartX
        sta     TransitionObjectX
        jsr     InitializeGameOverSlide
        rts

PreparePlayerTwoGameOver:
LDE34:  lda     Player1Lives
        beq     ReturnFromTankDestructionUpdate
        lda     #DIRECTION_LEFT
        sta     TransitionObjectDirection
        lda     #PlayerTwoGameOverStartX
        sta     TransitionObjectX
        jsr     InitializeGameOverSlide
ReturnFromTankDestructionUpdate:
LDE45:  rts

InitializeGameOverSlide:
; Завершает создание GAME OVER: timer=$0D, Y=$D8 и FrameCounter=0. Сброс кадра
; синхронизирует первое уменьшение timer и дальнейшие 16-кадровые фазы.
; Выход: A=0, Z=1; X/Y сохраняет. Меняет только перечисленные поля.
LDE46:  lda     #GameOverSlideTimerStart
        sta     TransitionObjectTimer
        lda     #GameOverSlideY
        sta     TransitionObjectY
        lda     #$00
        sta     FrameCounter
        rts

; Первая половина spawn lifecycle: $F0 инкрементируется через $F1..$FE, после
; чего заменяется на $E0. Render-handler использует low phases 0..13; phase $0E
; служит только порогом перехода и в ObjectState не остаётся. Переход из исходного
; $F0 в $E0 занимает 14 обслуживаний слота; freeze класс $F не останавливает.
; Вход: X=slot класса $F. Меняет только ObjectState,X; выход A=новая low phase
; 1..13 либо $E0, X/Y и остальную RAM сохраняет.
TankLogicStateF:
        inc     ObjectState,x
        lda     ObjectState,x
        and     #StateLowNibbleMask
        cmp     #TankSpawnPhasePastLast
        bne     ReturnFromTankLogicStateF
        lda     #TankSpawnSecondHalfInitialState
        sta     ObjectState,x
ReturnFromTankLogicStateF:
LDE63:  rts

; Вторая половина spawn lifecycle: $E0 проходит low phases 1..13, а на phase
; $0E InitializeTankState заменяет state начальным активным состоянием slot.
; Это ещё 14 обслуживаний, то есть полный $F0->active путь занимает 28 logic ticks
; данного slot; класс $E тоже продолжается при EnemyFreezeTimer.
; Вход: X=slot класса $E. До порога меняет только ObjectState,X и возвращает
; A=phase 1..13, X/Y сохраняет. На пороге outputs/side effects определяет
; InitializeTankState; промежуточное $EE в ObjectState не остаётся.
TankLogicStateE:
        inc     ObjectState,x
        lda     ObjectState,x
        and     #StateLowNibbleMask
        cmp     #TankSpawnPhasePastLast
        bne     ReturnFromTankLogicStateE
        jsr     InitializeTankState
ReturnFromTankLogicStateE:
LDE71:  rts
