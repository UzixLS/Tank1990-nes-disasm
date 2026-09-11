; Периоды нот, таблица потоков и музыкальный байткод ($ECE6-$EF75).

; 12 базовых 11-битных периодов по полутонам. Каждая пара хранится
; в порядке high,low, удобном для 16-битного сдвига LSR/ROR.
AudioBasePeriods:
LECE6:  .byte   $07
LECE7:  .byte   $F2,$07,$80,$07,$14,$06,$AE,$06
        .byte   $43,$05,$F4,$05,$9E,$05,$4E,$05
        .byte   $02,$04,$BA,$04,$76,$04,$36
; Номер потока одновременно служит индексом в этой таблице и задаёт
; приоритет при конкуренции за один канал: 0 — высший, 27 — низший.
AudioSequencePointers:
LECFE:  .word   PauseSequence,StageIntroPulse1Sequence
        .word   StageIntroTriangleSequence,StageIntroPulse2Sequence
        .word   ExtraLifePulse1Sequence,ExtraLifePulse2Sequence
        .word   PowerUpPickupSequence,PlayerOrBaseDestructionNoiseSequence
        .word   AudioSequence08,PowerUpSpawnSequence
        .word   TankDestructionSequence,BaseDestructionToneSequence
        .word   BrickHitSequence,RicochetOrMenuStepSequence
        .word   ArmorHitSequence,PlayerFireSequence
        .word   IceSlideStartSequence,PlayerMovementLoopSequence
        .word   GameplayLoopSequence,StatisticsCountPulseSequence
        .word   StatisticsCountNoiseSequence,SessionResultPulse1Sequence
        .word   SessionResultPulse2Sequence,SessionResultTriangleSequence
        .word   AudioSequence24,AudioSequence25,AudioSequence26,StatisticsWinnerBonusSequence

; Потоки байткода музыки и звуковых эффектов. Заголовок состоит из
; channel, control, aux, period-high и дополнительного period-low для channel=4.
; Далее идут токены: $00-$5F — нота, $60 — пауза с текущей длительностью,
; $61-$E7 — новая длительность token-$60, $E8-$F9 — команды. Операнды абсолютных
; переходов отсчитываются от самой AudioSequenceNN, включая байты заголовка.
AudioSequences:
; Поток 01: pulse 1, CTRL=$81, AUX=$7F, period-high=$40.
StageIntroPulse1Sequence:
AudioSequence01:
        .byte   $01,$81,$7F,$40,$EF,$68,$1B,$2B,$33
        .byte   $F0,$02,$06,$33,$43,$53,$F0,$02
        .byte   $0C,$43,$53,$04,$F0,$02,$12,$5B
        .byte   $0C,$1C,$F0,$02,$18,$78,$1C,$68
        .byte   $1C,$1C,$1C,$78,$1C,$E8
; Поток 02: triangle, CTRL=$10, AUX=$7F, period-high=$08.
StageIntroTriangleSequence:
AudioSequence02:
        .byte   $03,$10
        .byte   $7F,$08,$78,$1A,$68,$1A,$F1,$03
        .byte   $07,$78,$32,$68,$32,$F1,$03,$0E
        .byte   $78,$42,$68,$42,$F1,$03,$15,$5A
        .byte   $F1,$03,$19,$0B,$F1,$03,$1D,$78
        .byte   $52,$68,$52,$F1,$03,$24,$78,$52
        .byte   $E8
; Поток 03: pulse 2, CTRL=$81, AUX=$7F, period-high=$40.
StageIntroPulse2Sequence:
AudioSequence03:
        .byte   $02,$81,$7F,$40,$78,$51,$68
        .byte   $51,$F2,$03,$07,$78,$0A,$68,$0A
        .byte   $F2,$03,$0E,$78,$1A,$68,$1A,$F2
        .byte   $03,$15,$32,$F2,$03,$19,$42,$F2
        .byte   $03,$1D,$78,$3A,$68,$3A,$F2,$03
        .byte   $24,$78,$3A,$E8
; Поток 07: noise, CTRL=$1F, AUX=$7F, period-high=$30, period-low=$0A.
PlayerOrBaseDestructionNoiseSequence:
AudioSequence07:
        .byte   $04,$1F,$7F,$30
        .byte   $0A,$62,$49,$49,$EA,$1E,$49,$49
        .byte   $EA,$1D,$49,$49,$EA,$1C,$49,$49
        .byte   $EA,$1B,$49,$49,$EA,$1A,$49,$EA
        .byte   $19,$49,$EA,$18,$49,$E8
; Поток 08: pulse 2, CTRL=$1F, AUX=$7F, period-high=$30.
AudioSequence08:
        .byte   $02,$1F
        .byte   $7F,$30,$62,$00,$01,$00,$EA,$1E
        .byte   $01,$00,$EA,$1D,$01,$00,$01,$00
        .byte   $EA,$1C,$01,$EA,$1B,$00,$EA,$1A
        .byte   $01,$EA,$19,$00,$E8
; Поток 11: pulse 2, CTRL=$20, AUX=$7F, period-high=$30.
BaseDestructionToneSequence:
AudioSequence11:
        .byte   $02,$20,$7F
        .byte   $30,$63,$1A,$12,$51,$31,$19,$11
        .byte   $50,$30,$18,$E8
; Поток 10: noise, CTRL=$1F, AUX=$7F, period-high=$40, period-low=$0A.
TankDestructionSequence:
AudioSequence10:
        .byte   $04,$1F,$7F,$40
        .byte   $0A,$62,$51,$EA,$1E,$51,$EA,$08
        .byte   $6A,$51,$E8
; Поток 15: pulse 1, CTRL=$8F, AUX=$82, period-high=$10.
PlayerFireSequence:
AudioSequence15:
        .byte   $01,$8F,$82,$10,$6F
        .byte   $2C,$E8
; Поток 06: pulse 2, CTRL=$80, AUX=$7F, period-high=$40.
PowerUpPickupSequence:
AudioSequence06:
        .byte   $02,$80,$7F,$40,$63,$52
        .byte   $1B,$3B,$53,$4A,$13,$33,$4B,$1B
        .byte   $3B,$53,$1C,$3C,$E8
; Поток 00: pulse 2, CTRL=$82, AUX=$7F, period-high=$40.
PauseSequence:
AudioSequence00:
        .byte   $02,$82,$7F
        .byte   $40,$64,$1B,$2B,$3B,$1C,$2C,$3C
        .byte   $6C,$53,$E8
; Поток 27: pulse 2, CTRL=$82, AUX=$7F, period-high=$40.
StatisticsWinnerBonusSequence:
AudioSequence27:
        .byte   $02,$82,$7F,$40,$63
        .byte   $53,$1B,$1C,$3B,$3C,$53,$6A,$54
        .byte   $E8
; Поток 09: pulse 2, CTRL=$60, AUX=$7F, period-high=$40.
PowerUpSpawnSequence:
AudioSequence09:
        .byte   $02,$60,$7F,$40,$64,$52,$3A
        .byte   $52,$03,$52,$03,$13,$1B,$E8
; Поток 13: pulse 2, CTRL=$D5, AUX=$7F, period-high=$00.
RicochetOrMenuStepSequence:
AudioSequence13:
        .byte   $02
        .byte   $D5,$7F,$00,$62,$1C,$1D,$E8
; Поток 12: triangle, CTRL=$07, AUX=$7F, period-high=$08.
BrickHitSequence:
AudioSequence12:
        .byte   $03
        .byte   $07,$7F,$08,$61,$3A,$13,$22,$E8
; Поток 14: pulse 2, CTRL=$40, AUX=$7F, period-high=$00.
ArmorHitSequence:
AudioSequence14:
        .byte   $02,$40,$7F,$00,$61,$3D,$62,$45
        .byte   $EA,$10,$28,$E8
; Поток 19: pulse 2, CTRL=$80, AUX=$7F, period-high=$18.
StatisticsCountPulseSequence:
AudioSequence19:
        .byte   $02,$80,$7F,$18
        .byte   $61,$39,$E8
; Поток 20: noise, CTRL=$00, AUX=$7F, period-high=$28, period-low=$0A.
StatisticsCountNoiseSequence:
AudioSequence20:
        .byte   $04,$00,$7F,$28,$0A
        .byte   $61,$28,$E8
; Поток 18: pulse 2, CTRL=$8C, AUX=$94, period-high=$40; $F9 зацикливает тело.
GameplayLoopSequence:
AudioSequence18:
        .byte   $02,$8C,$94,$40,$61
        .byte   $10,$64,$18,$F9,$05
; Поток 17: pulse 2, CTRL=$80, AUX=$94, period-high=$48; $F9 зацикливает тело.
PlayerMovementLoopSequence:
AudioSequence17:
        .byte   $02,$80,$94
        .byte   $48,$62,$40,$48,$F9,$05
; Поток 16: pulse 1, CTRL=$1F, AUX=$7F, period-high=$28.
IceSlideStartSequence:
AudioSequence16:
        .byte   $01,$1F
        .byte   $7F,$28,$61,$22,$42,$5A,$1B,$E8
; Поток 04: pulse 1, CTRL=$A0, AUX=$7F, period-high=$40.
ExtraLifePulse1Sequence:
AudioSequence04:
        .byte   $01,$A0,$7F,$40,$66,$1C,$3C,$1C
        .byte   $53,$1C,$3C,$05,$72,$54,$E8
; Поток 05: pulse 2, CTRL=$90, AUX=$7F, period-high=$40.
ExtraLifePulse2Sequence:
AudioSequence05:
        .byte   $02
        .byte   $90,$7F,$40,$62,$38,$66,$EA,$20
        .byte   $3B,$53,$3B,$1B,$3B,$53,$1C,$6A
        .byte   $14,$E8
; Поток 21: pulse 1, CTRL=$B8, AUX=$7F, period-high=$40.
SessionResultPulse1Sequence:
AudioSequence21:
        .byte   $01,$B8,$7F,$40,$EF,$65
        .byte   $0C,$53,$F0,$0C,$05,$0C,$53,$F0
        .byte   $0C,$0B,$34,$24,$F0,$08,$10,$EA
        .byte   $30,$B0,$50,$EA,$20,$9C,$54,$E8
; Поток 22: pulse 2, CTRL=$B8, AUX=$7F, period-high=$40.
SessionResultPulse2Sequence:
AudioSequence22:
        .byte   $02,$B8,$7F,$40,$65,$43,$33,$F1
        .byte   $0C,$04,$43,$33,$F1,$0C,$0A,$14
        .byte   $4B,$F1,$08,$0F,$EA,$3A,$30,$50
        .byte   $09,$29,$31,$51,$0A,$2A,$32,$52
        .byte   $0B,$2B,$33,$53,$0C,$2C,$9C,$EA
        .byte   $20,$2C,$E8
; Поток 23: triangle, CTRL=$00, AUX=$7F, period-high=$08.
SessionResultTriangleSequence:
AudioSequence23:
        .byte   $03,$00,$7F,$08,$A1
        .byte   $01,$01,$EE,$15,$6A,$0B,$0B,$0B
        .byte   $EE,$22,$6F,$33,$65,$43,$7E,$EE
        .byte   $33,$53,$6A,$EE,$15,$43,$33,$53
        .byte   $6F,$EE,$22,$13,$65,$23,$7E,$EE
        .byte   $33,$33,$6A,$EE,$15,$23,$13,$4A
        .byte   $9C,$EE,$FF,$32,$E8
; Поток 24: pulse 1, CTRL=$42, AUX=$7F, period-high=$40.
AudioSequence24:
        .byte   $01,$42,$7F
        .byte   $40,$66,$1B,$0B,$78,$1B,$68,$52
        .byte   $42,$32,$1A,$1A,$1A,$78,$1A,$E8
; Поток 25: pulse 2, CTRL=$82, AUX=$7F, period-high=$40.
AudioSequence25:
        .byte   $02,$82,$7F,$40,$66,$52,$52,$78
        .byte   $52,$68,$32,$2A,$12,$1A,$1A,$1A
        .byte   $78,$1A,$E8
; Поток 26: triangle, CTRL=$10, AUX=$7F, period-high=$08.
AudioSequence26:
        .byte   $03,$10,$7F,$08,$66
        .byte   $3B,$33,$78,$3B,$68,$1B,$0B,$52
        .byte   $52,$52,$52,$78,$52,$E8,$FF
