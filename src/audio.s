; Аудиодвижок и потоки музыки/эффектов ($EA51-$EF75).
;
; Движок ведёт 28 приоритетных потоков. Байт AudioStreamStates+n равен 0
; для неактивного потока, 1 запрашивает запуск, а 2 означает работающий
; поток. Его запись лежит по адресу AudioStreamRecords+n*8:
;   +0  номер канала APU 1..4; временно 5..8, если регистры уже выданы;
;   +1  регистр CTRL ($4000/$4004/$4008/$400C);
;   +2  регистр SWEEP/неиспользуемый ($4001/$4005/$4009/$400D);
;   +3  младший байт периода ($4002/$4006/$400A/$400E);
;   +4  шаблон старшего регистра; нота меняет только биты периода 2..0;
;   +5  позиция в потоке байткода;
;   +6  длительность для следующего события;
;   +7  текущий счётчик кадров.
; Меньший номер потока первым захватывает нужный аппаратный канал.

AudioHardwareOwners  = $F9
AudioStreamCount       = $1C
AudioRecordSize      = $08
AudioHardwareChannels = $04

AudioRecordChannel   = $00
AudioRecordControl   = $01
AudioRecordAux       = $02
AudioRecordPeriodLo  = $03
AudioRecordPeriodHi  = $04
AudioRecordPosition  = $05
AudioRecordDuration  = $06
AudioRecordCountdown = $07

; Включает pulse/triangle/noise в $4015, запрещает frame IRQ через
; $4017 и сбрасывает состояния потоков и поле +0 их записей.
; Входы: нет. Выходы: нет. Портит A, X, Y, AudioStatePtrLo/Hi.
ResetAudioEngine:
LEA51:  lda     #$0F
        sta     APU_STATUS
        lda     #$C0
        sta     JOY2_FRAME
        lda     #<AudioStreamRecords
        sta     AudioStatePtrLo
        lda     #>AudioStreamRecords
        sta     AudioStatePtrHi
        ldx     #$00
        ldy     #$00
ResetNextAudioStream:
LEA67:  tya
        sta     (AudioStatePtrLo),y
        sta     AudioStreamStates,x
        clc
        lda     AudioStatePtrLo
        adc     #AudioRecordSize
        sta     AudioStatePtrLo
        bcc     LEA78
        inc     AudioStatePtrHi
LEA78:  inx
        cpx     #AudioStreamCount
        bne     LEA67
        rts

; Один кадровый шаг интерпретатора музыки и звуковых эффектов.
; Сначала выбирает первый по номеру поток для каждого канала и копирует
; его четыре байта в APU. Затем уменьшает таймеры и декодирует по одному
; событию для истёкших потоков. Такой порядок откладывает запись новой
; ноты в APU до следующего кадра. При ненулевом PauseState обслуживается
; только поток 0.
; Побочные эффекты: запись $4000-$400F; изменение записей потоков,
; AudioHardwareOwners, AudioLoopCounters и временных Audio*; портит A, X, Y.
UpdateAudioEngine:
LEA7E:  lda     PauseState
        bne     LEA88
        lda     #AudioStreamCount
        sta     AudioStreamLimit
        bpl     LEA8C
LEA88:  lda     #$01
        sta     AudioStreamLimit
LEA8C:  lda     #$00
        ldx     #(AudioHardwareChannels-1)
ClearAudioHardwareOwners:
LEA90:  sta     AudioHardwareOwners,x
        dex
        bpl     LEA90
        lda     #$00
        sta     AudioStreamIndex
        lda     #<AudioStreamRecords
        sta     AudioStatePtrLo
        lda     #>AudioStreamRecords
        sta     AudioStatePtrHi

; Первый проход: низкие номера потоков имеют приоритет. Значение +0 от 5
; означает, что данные уже были записаны; канал всё равно помечается занятым.
RouteAudioStreamsToApu:
LEAA1:  ldx     AudioStreamIndex
        lda     AudioStreamStates,x
        beq     LEAE3
        ldy     #AudioRecordChannel
        lda     (AudioStatePtrLo),y
        beq     LEAE3
        cmp     #$05
        bcc     LEABD
        sec
        sbc     #$05
        tax
        lda     #$01
        sta     AudioHardwareOwners,x
        jmp     LEAE3

WriteAudioStreamToApu:
LEABD:  tax
        dex
        lda     AudioHardwareOwners,x
        bne     LEAE3
        lda     #$01
        sta     AudioHardwareOwners,x
        txa
        tay
        clc
        adc     #$05
        ldy     #AudioRecordChannel
        sta     (AudioStatePtrLo),y
        txa
        asl     a
        asl     a
        tax
        lda     #AudioHardwareChannels
        sta     AudioWorkLo
LEAD8:  iny
        lda     (AudioStatePtrLo),y
        sta     APU_PULSE1_CTRL,x
        inx
        dec     AudioWorkLo
        bne     LEAD8
AdvanceAudioOutputStream:
LEAE3:  clc
        lda     AudioStatePtrLo
        adc     #AudioRecordSize
        sta     AudioStatePtrLo
        bcc     LEAEE
        inc     AudioStatePtrHi
LEAEE:  inc     AudioStreamIndex
        lda     AudioStreamIndex
        cmp     AudioStreamLimit
        bcc     LEAA1
; Отключает незахваченные каналы: у pulse ставит нулевую громкость $10,
; у triangle/noise записывает 0 в первый регистр канала.
SilenceUnclaimedAudioChannels:
        ldx     #$00
SilenceNextAudioChannel:
LEAF8:  stx     AudioWorkLo
        lda     AudioHardwareOwners,x
        bne     LEB0A
        txa
        asl     a
        asl     a
        tax
        asl     a
        and     #$10
        eor     #$10
        sta     APU_PULSE1_CTRL,x
LEB0A:  ldx     AudioWorkLo
        inx
        cpx     #AudioHardwareChannels
        bcc     LEAF8
        ldy     #$00
        sty     AudioStreamIndex
        lda     #<AudioStreamRecords
        sta     AudioStatePtrLo
        lda     #>AudioStreamRecords
        sta     AudioStatePtrHi

; Второй проход: запускает запрошенные потоки, отсчитывает кадр у активных и
; читает следующее событие, когда счётчик +7 достиг 0.
AdvanceAudioStreams:
LEB1D:  ldx     AudioStreamIndex
        lda     AudioStreamStates,x
        beq     LEB2E
        cmp     #$01
        bne     LEB42
        inc     AudioStreamStates,x
        jmp     LEB4F

AdvanceToNextAudioStream:
LEB2E:  clc
        lda     AudioStatePtrLo
        adc     #AudioRecordSize
        sta     AudioStatePtrLo
        bcc     LEB39
        inc     AudioStatePtrHi
LEB39:  inc     AudioStreamIndex
        lda     AudioStreamIndex
        cmp     AudioStreamLimit
        bcc     LEB1D
        rts

CountDownAudioEvent:
LEB42:  ldy     #AudioRecordCountdown
        lda     (AudioStatePtrLo),y
        sec
        sbc     #$01
        sta     (AudioStatePtrLo),y
        beq     LEB85
        bne     LEB2E
; При запуске позиция сбрасывается, затем заголовок копируется в +0,+1,+2,+4.
; Для канала 4 (noise) заголовок содержит ещё байт +3.
InitializeAudioStream:
LEB4F:  lda     #$00
        ldy     #AudioRecordPosition
        sta     (AudioStatePtrLo),y
        jsr     LoadAudioSequencePointer
        jsr     ReadAudioArgument
        ldy     #AudioRecordChannel
        sta     (AudioStatePtrLo),y
        jsr     ReadAudioArgument
        ldy     #AudioRecordControl
        sta     (AudioStatePtrLo),y
        jsr     ReadAudioArgument
        ldy     #AudioRecordAux
        sta     (AudioStatePtrLo),y
        jsr     ReadAudioArgument
        ldy     #AudioRecordPeriodHi
        sta     (AudioStatePtrLo),y
        ldy     #AudioRecordChannel
        lda     (AudioStatePtrLo),y
        cmp     #$04
        bne     LEB88
        jsr     ReadAudioArgument
        ldy     #AudioRecordPeriodLo
        sta     (AudioStatePtrLo),y
        bpl     LEB88

; При истечении таймера указатель таблицы восстанавливается по номеру потока.
ResumeAudioStream:
LEB85:  jsr     LoadAudioSequencePointer

; Декодер может прочитать цепочку модификаторов длительности/команд за один вызов.
DecodeNextAudioToken:
LEB88:  jsr     ReadAudioArgument
        cmp     #$E8
        bcs     LEBE1
        cmp     #$60
        beq     LEBD7
        bcc     LEB9E
        sbc     #$60
        ldy     #AudioRecordDuration
        sta     (AudioStatePtrLo),y
        jmp     LEB88

; Нота $00-$5F: биты 7..3 выбирают один из 12 базовых периодов, биты 2..0
; делят его на 2^n. Старшие пять бит +4 сохраняются.
SetAudioNotePeriod:
LEB9E:  pha
        and     #$F8
        lsr     a
        lsr     a
        tax
        lda     AudioBasePeriods,x
        sta     AudioWorkLo
        lda     AudioBasePeriods+1,x
        sta     AudioWorkHi
        pla
        and     #$07
        beq     LEBBB
        tax
ShiftAudioNotePeriod:
LEBB4:  lsr     AudioWorkLo
        ror     AudioWorkHi
        dex
        bne     LEBB4
WriteAudioNotePeriod:
LEBBB:  ldy     #AudioRecordPeriodHi
        lda     (AudioStatePtrLo),y
        and     #$F8
        ora     AudioWorkLo
        sta     (AudioStatePtrLo),y
        lda     AudioWorkHi
        dey
        sta     (AudioStatePtrLo),y
        ldy     #AudioRecordChannel
        lda     (AudioStatePtrLo),y
        cmp     #$05
        bcc     LEBD7
        sec
        sbc     #$04
        sta     (AudioStatePtrLo),y
; $60 оставляет период без изменения; и нота, и $60 переносят +6 в текущий +7.
FinishAudioTimedToken:
LEBD7:  ldy     #AudioRecordDuration
        lda     (AudioStatePtrLo),y
        iny
        sta     (AudioStatePtrLo),y
        jmp     LEB2E

DecodeAudioCommand:
LEBE1:  sbc     #$E8
        jsr     DispatchAudioCommand

; DispatchAudioCommand использует адрес возврата как базу этой inline-таблицы и передаёт
; управление обработчику команды $E8-$F9. Все обработчики продолжают декодирование
; через переход к LEB88 и не возвращаются обычным RTS.
AudioCommandHandlers:
        .word   AudioCommandStop,AudioCommandSetControlHighBits
        .word   AudioCommandSetControlLowBits,AudioCommandSetControlLowNibble
        .word   AudioCommandSetAux,AudioCommandSetPeriodHigh
        .word   AudioCommandSetControl,AudioCommandResetLoopCounters
        .word   AudioCommandLoop0,AudioCommandLoop1,AudioCommandLoop2
        .word   AudioCommandSkipArgument,AudioCommandSkipArgument
        .word   AudioCommandSkipArgument,AudioCommandSkipArgument
        .word   AudioCommandSkipArgument,AudioCommandSkipArgument
        .word   AudioCommandJump

; $E8: останавливает поток, обнуляет +0 и откатывает +5 на маркер $E8.
AudioCommandStop:
AudioCommandE8:
LEC0A:  ldx     AudioStreamIndex
LEC0C:  lda     #$00
        sta     AudioStreamStates,x
        ldy     #AudioRecordChannel
        sta     (AudioStatePtrLo),y
        ldy     #AudioRecordPosition
        lda     (AudioStatePtrLo),y
        sec
        sbc     #$01
        sta     (AudioStatePtrLo),y
        jmp     LEB2E

; $E9 operand: сохраняет биты 5..0 регистра CTRL и подмешивает operand.
AudioCommandSetControlHighBits:
AudioCommandE9:
LEC21:  jsr     ReadAudioArgument
        sta     AudioWorkLo
        ldy     #AudioRecordControl
        lda     (AudioStatePtrLo),y
        and     #$3F
        ora     AudioWorkLo
        sta     (AudioStatePtrLo),y
        jmp     LEB88

; $EA operand: сохраняет биты 7..6 CTRL и подмешивает operand.
AudioCommandSetControlLowBits:
AudioCommandEA:
LEC33:  jsr     ReadAudioArgument
        sta     AudioWorkLo
        ldy     #AudioRecordControl
        lda     (AudioStatePtrLo),y
        and     #$C0
        ora     AudioWorkLo
        sta     (AudioStatePtrLo),y
        jmp     LEB88

; $EB operand: сохраняет биты 7..4 CTRL и подмешивает operand.
AudioCommandSetControlLowNibble:
AudioCommandEB:
LEC45:  jsr     ReadAudioArgument
        sta     AudioWorkLo
        ldy     #AudioRecordControl
        lda     (AudioStatePtrLo),y
        and     #$F0
        ora     AudioWorkLo
        sta     (AudioStatePtrLo),y
        jmp     LEB88

; $EC operand: заменяет второй аппаратный регистр канала (+2).
AudioCommandSetAux:
AudioCommandEC:
LEC57:  jsr     ReadAudioArgument
        ldy     #AudioRecordAux
        sta     (AudioStatePtrLo),y
        jmp     LEB88

; $ED operand: заменяет шаблон старшего регистра периода (+4).
AudioCommandSetPeriodHigh:
AudioCommandED:
LEC61:  jsr     ReadAudioArgument
        ldy     #AudioRecordPeriodHi
        sta     (AudioStatePtrLo),y
        jmp     LEB88

; $EE operand: заменяет CTRL (+1) целиком.
AudioCommandSetControl:
AudioCommandEE:
LEC6B:  jsr     ReadAudioArgument
        ldy     #AudioRecordControl
        sta     (AudioStatePtrLo),y
        jmp     LEB88

; $EF: сбрасывает три общих для всех потоков счётчика циклов $F0-$F2.
AudioCommandResetLoopCounters:
AudioCommandEF:
LEC75:  lda     #$00
        ldx     #$02
LEC79:  sta     AudioLoopCounters,x
        dex
        bpl     LEC79
        jmp     LEB88

; $F0-$F2 count,target: выбирают один из трёх общих счётчиков. Пока он не равен count,
; переходят к абсолютной позиции target внутри потока. При равенстве счётчик
; обнуляется, target пропускается и исполнение идёт дальше.
AudioCommandLoop0:
AudioCommandF0:
LEC81:  ldx     #$00
        beq     LEC8A
AudioCommandLoop1:
AudioCommandF1:
LEC85:  ldx     #$01
        .byte   $2C                    ; BIT abs поглощает следующий LDX #$02.
AudioCommandLoop2:
AudioCommandF2:
LEC88:  ldx     #$02
LEC8A:  jsr     ReadAudioArgument
        inc     AudioLoopCounters,x
        cmp     AudioLoopCounters,x
        bne     LECA5
        lda     #$00
        sta     AudioLoopCounters,x
        beq     LEC99

; $F3-$F8 operand: в этой версии только пропускают один байт.
AudioCommandSkipArgument:
AudioCommandF3ToF8:
LEC99:  ldy     #AudioRecordPosition
        lda     (AudioStatePtrLo),y
        clc
        adc     #$01
        sta     (AudioStatePtrLo),y
        jmp     LEB88

; $F9 target: заменяет позицию +5 абсолютным смещением от начала потока.
AudioCommandJump:
AudioCommandF9:
LECA5:  jsr     ReadAudioArgument
        ldy     #AudioRecordPosition
        sta     (AudioStatePtrLo),y
        jmp     LEB88

; Выбирает базу байткода по AudioStreamIndex.
; Вход: AudioStreamIndex=0..27. Выход: AudioDataPtrLo/Hi.
; Портит A, X; Y не меняет.
LoadAudioSequencePointer:
LECAF:  lda     AudioStreamIndex
        asl     a
        tax
        lda     AudioSequencePointers,x
        sta     AudioDataPtrLo
        lda     AudioSequencePointers+1,x
        sta     AudioDataPtrHi
        rts

; Читает байт AudioDataPtr[record.position] и сдвигает position на 1.
; Входы: AudioDataPtrLo/Hi и AudioStatePtrLo/Hi для текущего потока.
; Выход: A=байт. Портит Y, сохраняет X.
ReadAudioArgument:
LECBE:  lda     AudioStreamIndex
        ldy     #AudioRecordPosition
        lda     (AudioStatePtrLo),y
        tay
        lda     (AudioDataPtrLo),y
        pha
        iny
        tya
        ldy     #AudioRecordPosition
        sta     (AudioStatePtrLo),y
        pla
        rts

; Безвозвратный inline-dispatch. Вход: A=индекс команды 0..17, вызов JSR
; непосредственно перед таблицей адресов. Снимает со стека адрес возврата,
; извлекает адрес обработчика и прыгает на него. Портит A, X, Y, AudioWorkLo/Hi.
DispatchAudioCommand:
LECD0:  asl     a
        tay
        iny
        pla
        sta     AudioWorkLo
        pla
        sta     AudioWorkHi
        lda     (AudioWorkLo),y
        tax
        iny
        lda     (AudioWorkLo),y
        sta     AudioWorkHi
        stx     AudioWorkLo
        jmp     (AudioWorkLo)

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
LECFE:  .word   AudioSequence00,AudioSequence01,AudioSequence02,AudioSequence03
        .word   AudioSequence04,AudioSequence05,AudioSequence06,AudioSequence07
        .word   AudioSequence08,AudioSequence09,AudioSequence10,AudioSequence11
        .word   AudioSequence12,AudioSequence13,AudioSequence14,AudioSequence15
        .word   AudioSequence16,AudioSequence17,AudioSequence18,AudioSequence19
        .word   AudioSequence20,AudioSequence21,AudioSequence22,AudioSequence23
        .word   AudioSequence24,AudioSequence25,AudioSequence26,AudioSequence27

; Потоки байткода музыки и звуковых эффектов. Заголовок состоит из
; channel, control, aux, period-high и дополнительного period-low для channel=4.
; Далее идут токены: $00-$5F — нота, $60 — пауза с текущей длительностью,
; $61-$E7 — новая длительность token-$60, $E8-$F9 — команды. Операнды абсолютных
; переходов отсчитываются от самой AudioSequenceNN, включая байты заголовка.
AudioSequences:
; Поток 01: pulse 1, CTRL=$81, AUX=$7F, period-high=$40.
AudioSequence01:
        .byte   $01,$81,$7F,$40,$EF,$68,$1B,$2B,$33
        .byte   $F0,$02,$06,$33,$43,$53,$F0,$02
        .byte   $0C,$43,$53,$04,$F0,$02,$12,$5B
        .byte   $0C,$1C,$F0,$02,$18,$78,$1C,$68
        .byte   $1C,$1C,$1C,$78,$1C,$E8
; Поток 02: triangle, CTRL=$10, AUX=$7F, period-high=$08.
AudioSequence02:
        .byte   $03,$10
        .byte   $7F,$08,$78,$1A,$68,$1A,$F1,$03
        .byte   $07,$78,$32,$68,$32,$F1,$03,$0E
        .byte   $78,$42,$68,$42,$F1,$03,$15,$5A
        .byte   $F1,$03,$19,$0B,$F1,$03,$1D,$78
        .byte   $52,$68,$52,$F1,$03,$24,$78,$52
        .byte   $E8
; Поток 03: pulse 2, CTRL=$81, AUX=$7F, period-high=$40.
AudioSequence03:
        .byte   $02,$81,$7F,$40,$78,$51,$68
        .byte   $51,$F2,$03,$07,$78,$0A,$68,$0A
        .byte   $F2,$03,$0E,$78,$1A,$68,$1A,$F2
        .byte   $03,$15,$32,$F2,$03,$19,$42,$F2
        .byte   $03,$1D,$78,$3A,$68,$3A,$F2,$03
        .byte   $24,$78,$3A,$E8
; Поток 07: noise, CTRL=$1F, AUX=$7F, period-high=$30, period-low=$0A.
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
AudioSequence11:
        .byte   $02,$20,$7F
        .byte   $30,$63,$1A,$12,$51,$31,$19,$11
        .byte   $50,$30,$18,$E8
; Поток 10: noise, CTRL=$1F, AUX=$7F, period-high=$40, period-low=$0A.
AudioSequence10:
        .byte   $04,$1F,$7F,$40
        .byte   $0A,$62,$51,$EA,$1E,$51,$EA,$08
        .byte   $6A,$51,$E8
; Поток 15: pulse 1, CTRL=$8F, AUX=$82, period-high=$10.
AudioSequence15:
        .byte   $01,$8F,$82,$10,$6F
        .byte   $2C,$E8
; Поток 06: pulse 2, CTRL=$80, AUX=$7F, period-high=$40.
AudioSequence06:
        .byte   $02,$80,$7F,$40,$63,$52
        .byte   $1B,$3B,$53,$4A,$13,$33,$4B,$1B
        .byte   $3B,$53,$1C,$3C,$E8
; Поток 00: pulse 2, CTRL=$82, AUX=$7F, period-high=$40.
AudioSequence00:
        .byte   $02,$82,$7F
        .byte   $40,$64,$1B,$2B,$3B,$1C,$2C,$3C
        .byte   $6C,$53,$E8
; Поток 27: pulse 2, CTRL=$82, AUX=$7F, period-high=$40.
AudioSequence27:
        .byte   $02,$82,$7F,$40,$63
        .byte   $53,$1B,$1C,$3B,$3C,$53,$6A,$54
        .byte   $E8
; Поток 09: pulse 2, CTRL=$60, AUX=$7F, period-high=$40.
AudioSequence09:
        .byte   $02,$60,$7F,$40,$64,$52,$3A
        .byte   $52,$03,$52,$03,$13,$1B,$E8
; Поток 13: pulse 2, CTRL=$D5, AUX=$7F, period-high=$00.
AudioSequence13:
        .byte   $02
        .byte   $D5,$7F,$00,$62,$1C,$1D,$E8
; Поток 12: triangle, CTRL=$07, AUX=$7F, period-high=$08.
AudioSequence12:
        .byte   $03
        .byte   $07,$7F,$08,$61,$3A,$13,$22,$E8
; Поток 14: pulse 2, CTRL=$40, AUX=$7F, period-high=$00.
AudioSequence14:
        .byte   $02,$40,$7F,$00,$61,$3D,$62,$45
        .byte   $EA,$10,$28,$E8
; Поток 19: pulse 2, CTRL=$80, AUX=$7F, period-high=$18.
AudioSequence19:
        .byte   $02,$80,$7F,$18
        .byte   $61,$39,$E8
; Поток 20: noise, CTRL=$00, AUX=$7F, period-high=$28, period-low=$0A.
AudioSequence20:
        .byte   $04,$00,$7F,$28,$0A
        .byte   $61,$28,$E8
; Поток 18: pulse 2, CTRL=$8C, AUX=$94, period-high=$40; $F9 зацикливает тело.
AudioSequence18:
        .byte   $02,$8C,$94,$40,$61
        .byte   $10,$64,$18,$F9,$05
; Поток 17: pulse 2, CTRL=$80, AUX=$94, period-high=$48; $F9 зацикливает тело.
AudioSequence17:
        .byte   $02,$80,$94
        .byte   $48,$62,$40,$48,$F9,$05
; Поток 16: pulse 1, CTRL=$1F, AUX=$7F, period-high=$28.
AudioSequence16:
        .byte   $01,$1F
        .byte   $7F,$28,$61,$22,$42,$5A,$1B,$E8
; Поток 04: pulse 1, CTRL=$A0, AUX=$7F, period-high=$40.
AudioSequence04:
        .byte   $01,$A0,$7F,$40,$66,$1C,$3C,$1C
        .byte   $53,$1C,$3C,$05,$72,$54,$E8
; Поток 05: pulse 2, CTRL=$90, AUX=$7F, period-high=$40.
AudioSequence05:
        .byte   $02
        .byte   $90,$7F,$40,$62,$38,$66,$EA,$20
        .byte   $3B,$53,$3B,$1B,$3B,$53,$1C,$6A
        .byte   $14,$E8
; Поток 21: pulse 1, CTRL=$B8, AUX=$7F, period-high=$40.
AudioSequence21:
        .byte   $01,$B8,$7F,$40,$EF,$65
        .byte   $0C,$53,$F0,$0C,$05,$0C,$53,$F0
        .byte   $0C,$0B,$34,$24,$F0,$08,$10,$EA
        .byte   $30,$B0,$50,$EA,$20,$9C,$54,$E8
; Поток 22: pulse 2, CTRL=$B8, AUX=$7F, period-high=$40.
AudioSequence22:
        .byte   $02,$B8,$7F,$40,$65,$43,$33,$F1
        .byte   $0C,$04,$43,$33,$F1,$0C,$0A,$14
        .byte   $4B,$F1,$08,$0F,$EA,$3A,$30,$50
        .byte   $09,$29,$31,$51,$0A,$2A,$32,$52
        .byte   $0B,$2B,$33,$53,$0C,$2C,$9C,$EA
        .byte   $20,$2C,$E8
; Поток 23: triangle, CTRL=$00, AUX=$7F, period-high=$08.
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
