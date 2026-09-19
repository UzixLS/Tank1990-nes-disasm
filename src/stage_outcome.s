; Рабочие счётчики и условие завершения этапа ($C71E-$C754).

StageEndObjectStartX     = $70
StageEndObjectStartTimer = $11

; Обнуляет восемь байт Player1KillCounts..Player2KillCounts+3.
; Выход: A=0, X=$FF; Y, PPU/OAM/APU и остальная RAM не меняются.
ClearStageWorkBytes:
LC71E:  ldx     #$07
        lda     #$00
ClearNextStageWorkByte:
LC722:  sta     Player1KillCounts,x
        dex
        bpl     ClearNextStageWorkByte
        rts

; Проверяет условие завершения текущего кадрового цикла.
; Возвращает A=0/Z=1, пока BattleState!=0, остались враги и есть хотя бы одна
; жизнь; иначе A=1/Z=0. При BattleState=0 или отсутствии жизней задаёт
; TransitionObjectX/Y/Direction/Timer и сбрасывает FrameCounter. Победа по
; EnemiesRemaining=0 завершает loop без инициализации объекта. X/Y сохраняются;
; PPU/OAM/APU напрямую не меняет, портит флаги.
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
LC737:  lda     #StageEndObjectStartX
        sta     TransitionObjectX
        lda     #OamHiddenY
        sta     TransitionObjectY
        lda     #$00
        sta     TransitionObjectDirection
        lda     #StageEndObjectStartTimer
        sta     TransitionObjectTimer
        lda     #$00
        sta     FrameCounter
ReportStageLoopFinished:
LC74F:  lda     #$01
        rts

ReportStageLoopActive:
LC752:  lda     #$00
        rts
