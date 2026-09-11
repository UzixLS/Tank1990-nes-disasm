; Рабочие счётчики и условие завершения этапа ($C71E-$C754).

; Обнуляет восемь байт $73..$7A. Выход: A=0, X=$FF; Y и остальная RAM не меняются.
ClearStageWorkBytes:
LC71E:  ldx     #$07
        lda     #$00
ClearNextStageWorkByte:
LC722:  sta     Player1KillCounts,x
        dex
        bpl     ClearNextStageWorkByte
        rts

; Проверяет условие завершения текущего кадрового цикла.
; Возвращает A=0, если $68!=0, остались враги ($80!=0) и есть хотя бы одна жизнь; иначе A=1.
; При запуске переходной анимации задаёт TransitionObjectX..TransitionObjectTimer
; и сбрасывает FrameCounter. Портит A и флаги.
CheckStageLoopFinished:
LC728:  lda     BattleState
        beq     StartStageEndTransition
        lda     EnemiesRemaining
        beq     ReportStageLoopFinished
        lda     Player1Lives
        clc
        adc     Player2Lives
        bne     ReportStageLoopActive
StartStageEndTransition:
LC737:  lda     #$70
        sta     TransitionObjectX
        lda     #$F0
        sta     TransitionObjectY
        lda     #$00
        sta     TransitionObjectDirection
        lda     #$11
        sta     TransitionObjectTimer
        lda     #$00
        sta     FrameCounter
ReportStageLoopFinished:
LC74F:  lda     #$01
        rts

ReportStageLoopActive:
LC752:  lda     #$00
        rts
