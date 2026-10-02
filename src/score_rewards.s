; Дополнительные жизни за порог счёта ($D138-$D169).

ExtraLifeScoreDigitOffset = $02
ExtraLifeScoreDigitMin    = $02

; Однократно выдаёт extra life при точном BattleStateActive. Проверяется только
; digit десятков тысяч (record offset 2) >=2, а не полное семизначное число.
; Поэтому обычное последовательное начисление срабатывает при переходе 20000,
; но искусственно заданный score с ненулевыми старшими digits и offset2=0/1
; порог не проходит. Digits должны оставаться 0..9.
;
; P1 проверяется первым и независимо от MenuSelection. P2 проверяется только
; если P1 на этом вызове не получил жизнь, MenuSelection!=0 и его award flag=0.
; Если оба одновременно eligible, P1 получает награду сейчас, P2 — не раньше
; следующего вызова. Любое ненулевое PlayerExtraLifeAwarded подавляет повтор.
; PlayerLives увеличивается восьмибитно без saturation и может wrap.
;
; При награде оба pulse audio state получают AudioStateStartRequested.
; X/Y, score records, PPU/OAM/RNG сохраняются; A/flags на путях без награды
; зависят от последней проверки. На пути награды A=1, N=0/Z=0/C=1;
; V сохраняется на всех путях.
AwardScoreThresholdLives:
LD138:  lda     BattleState
        cmp     #BattleStateActive
        bne     ReturnFromExtraLifeCheck
        lda     PlayerExtraLifeAwarded
        bne     CheckPlayerTwoExtraLife
        lda     Player1Score+ExtraLifeScoreDigitOffset
        cmp     #ExtraLifeScoreDigitMin
        bcc     CheckPlayerTwoExtraLife
        inc     Player1Lives
        inc     PlayerExtraLifeAwarded
        jmp     RequestExtraLifeAudio

CheckPlayerTwoExtraLife:
LD14F:  lda     MenuSelection
        beq     ReturnFromExtraLifeCheck
        lda     PlayerExtraLifeAwarded+1
        bne     ReturnFromExtraLifeCheck
        lda     Player2Score+ExtraLifeScoreDigitOffset
        cmp     #ExtraLifeScoreDigitMin
        bcc     ReturnFromExtraLifeCheck
        inc     Player2Lives
        inc     PlayerExtraLifeAwarded+1
; Самостоятельный общий хвост: запрашивает restart двух pulse-потоков.
; Выход: A=AudioStateStartRequested, N=0/Z=0; C/V и X/Y сохраняются. Lives,
; award flags, score, PPU/OAM/RNG не меняет.
RequestExtraLifeAudio:
LD161:  lda     #AudioStateStartRequested
        sta     ExtraLifePulse1AudioState
        sta     ExtraLifePulse2AudioState
ReturnFromExtraLifeCheck:
LD169:  rts
