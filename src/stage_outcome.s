; Рабочие счётчики и условие завершения этапа ($C71E-$C754).

GameOverObjectStartX       = $70
GameOverObjectInitialTimer = $11
GameOverObjectDirection    = DIRECTION_UP

; Обнуляет ровно восемь счётчиков убийств: четыре типа P1 и следующие четыре
; типа P2 ($73..$7A). Payload статистики/score/lives не затрагивает.
; Выход: A=0, X=$FF, N=1/Z=0; Y и C/V сохраняются. PPU/OAM/APU не меняет.
ClearStageWorkBytes:
LC71E:  ldx     #$07
        lda     #$00
ClearNextStageWorkByte:
LC722:  sta     Player1KillCounts,x
        dex
        bpl     ClearNextStageWorkByte
        rts

; Проверяет исход после отрисовки текущего gameplay frame. Приоритет условий:
;   1. BattleState=0 -- поражение после завершившегося countdown базы;
;   2. EnemiesRemaining=0 -- немедленное завершение без GAME OVER объекта;
;   3. (Player1Lives+Player2Lives)&$FF=0 -- поражение игроков;
;   4. иначе бой продолжается.
; Поэтому положительный destruction countdown считается временно активным, но
; последний уничтоженный враг может закончить loop до его нуля; поздний
; ResolveStageOutcome всё равно отличит такое состояние от точного $80.
;
; Поражение создаёт GAME OVER: X=$70, скрытый Y=$F0, direction=UP, timer=$11,
; FrameCounter=0. При штатном длинном TransitionObjectFrameLoop объект движется
; вверх первые 127 logic ticks до Y=$71, затем стоит; цикл заканчивается через
; 256 NMI с timer=1, не дожидаясь его естественного нуля. Победа не меняет ни
; TransitionObject*, ни FrameCounter.
;
; Выход: A=0/Z=1 для продолжения, A=1/Z=0 при завершении; X/Y сохраняются.
; Сумма жизней восьмибитная, поэтому ромхак должен исключить ненулевую сумму,
; кратную 256. PPU/OAM/audio напрямую не меняются.
CheckStageLoopFinished:
LC728:  lda     BattleState
        beq     StartGameOverTransition
        lda     EnemiesRemaining
        beq     ReportStageLoopFinished
        lda     Player1Lives
        clc
        adc     Player2Lives
        bne     ReportStageLoopActive
StartGameOverTransition:
LC737:  lda     #GameOverObjectStartX
        sta     TransitionObjectX
        lda     #OamHiddenY
        sta     TransitionObjectY
        lda     #GameOverObjectDirection
        sta     TransitionObjectDirection
        lda     #GameOverObjectInitialTimer
        sta     TransitionObjectTimer
        lda     #$00
        sta     FrameCounter
ReportStageLoopFinished:
LC74F:  lda     #$01
        rts

ReportStageLoopActive:
LC752:  lda     #$00
        rts
