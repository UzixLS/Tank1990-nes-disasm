; Приоритетный интерпретатор потоков и маршрутизация APU ($EA51-$ECE5).

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

AudioHardwareOwners          = $F9
AudioStreamCount             = $1C
AudioRecordSize              = $08
AudioHardwareChannels        = $04
AudioNoiseChannel            = $04
AudioRoutedChannelBias       = $05
AudioRoutedToLogicalOffset   = $04
AudioDurationTokenBase       = $60
AudioCommandTokenBase        = $E8
AudioChannelClaimed          = $01

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
        bcc     AdvanceResetAudioStream
        inc     AudioStatePtrHi
AdvanceResetAudioStream:
LEA78:  inx
        cpx     #AudioStreamCount
        bne     ResetNextAudioStream
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
        bne     LimitAudioToPauseStream
        lda     #AudioStreamCount
        sta     AudioStreamLimit
        bpl     BeginAudioRoutingPass
LimitAudioToPauseStream:
LEA88:  lda     #$01
        sta     AudioStreamLimit
BeginAudioRoutingPass:
LEA8C:  lda     #$00
        ldx     #(AudioHardwareChannels-1)
ClearAudioHardwareOwners:
LEA90:  sta     AudioHardwareOwners,x
        dex
        bpl     ClearAudioHardwareOwners
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
        beq     AdvanceAudioOutputStream
        ldy     #AudioRecordChannel
        lda     (AudioStatePtrLo),y
        beq     AdvanceAudioOutputStream
        cmp     #AudioRoutedChannelBias
        bcc     WriteAudioStreamToApu
        sec
        sbc     #AudioRoutedChannelBias
        tax
        lda     #AudioChannelClaimed
        sta     AudioHardwareOwners,x
        jmp     AdvanceAudioOutputStream

WriteAudioStreamToApu:
LEABD:  tax
        dex
        lda     AudioHardwareOwners,x
        bne     AdvanceAudioOutputStream
        lda     #AudioChannelClaimed
        sta     AudioHardwareOwners,x
        txa
        tay
        clc
        adc     #AudioRoutedChannelBias
        ldy     #AudioRecordChannel
        sta     (AudioStatePtrLo),y
        txa
        asl     a
        asl     a
        tax
        lda     #AudioHardwareChannels
        sta     AudioWorkLo
CopyNextAudioRegister:
LEAD8:  iny
        lda     (AudioStatePtrLo),y
        sta     APU_PULSE1_CTRL,x
        inx
        dec     AudioWorkLo
        bne     CopyNextAudioRegister
AdvanceAudioOutputStream:
LEAE3:  clc
        lda     AudioStatePtrLo
        adc     #AudioRecordSize
        sta     AudioStatePtrLo
        bcc     AdvanceAudioOutputIndex
        inc     AudioStatePtrHi
AdvanceAudioOutputIndex:
LEAEE:  inc     AudioStreamIndex
        lda     AudioStreamIndex
        cmp     AudioStreamLimit
        bcc     RouteAudioStreamsToApu
; Отключает незахваченные каналы: у pulse ставит нулевую громкость $10,
; у triangle/noise записывает 0 в первый регистр канала.
SilenceUnclaimedAudioChannels:
        ldx     #$00
SilenceNextAudioChannel:
LEAF8:  stx     AudioWorkLo
        lda     AudioHardwareOwners,x
        bne     RestoreAudioHardwareIndex
        txa
        asl     a
        asl     a
        tax
        asl     a
        and     #$10
        eor     #$10
        sta     APU_PULSE1_CTRL,x
RestoreAudioHardwareIndex:
LEB0A:  ldx     AudioWorkLo
        inx
        cpx     #AudioHardwareChannels
        bcc     SilenceNextAudioChannel
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
        beq     AdvanceToNextAudioStream
        cmp     #AudioStateStartRequested
        bne     CountDownAudioEvent
        inc     AudioStreamStates,x
        jmp     InitializeAudioStream

AdvanceToNextAudioStream:
LEB2E:  clc
        lda     AudioStatePtrLo
        adc     #AudioRecordSize
        sta     AudioStatePtrLo
        bcc     AdvanceAudioStreamIndex
        inc     AudioStatePtrHi
AdvanceAudioStreamIndex:
LEB39:  inc     AudioStreamIndex
        lda     AudioStreamIndex
        cmp     AudioStreamLimit
        bcc     AdvanceAudioStreams
        rts

CountDownAudioEvent:
LEB42:  ldy     #AudioRecordCountdown
        lda     (AudioStatePtrLo),y
        sec
        sbc     #$01
        sta     (AudioStatePtrLo),y
        beq     ResumeAudioStream
        bne     AdvanceToNextAudioStream
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
        cmp     #AudioNoiseChannel
        bne     DecodeNextAudioToken
        jsr     ReadAudioArgument
        ldy     #AudioRecordPeriodLo
        sta     (AudioStatePtrLo),y
        bpl     DecodeNextAudioToken

; При истечении таймера указатель таблицы восстанавливается по номеру потока.
ResumeAudioStream:
LEB85:  jsr     LoadAudioSequencePointer

; Декодер может прочитать цепочку модификаторов длительности/команд за один вызов.
DecodeNextAudioToken:
LEB88:  jsr     ReadAudioArgument
        cmp     #AudioCommandTokenBase
        bcs     DecodeAudioCommand
        cmp     #AudioDurationTokenBase
        beq     FinishAudioTimedToken
        bcc     SetAudioNotePeriod
        sbc     #AudioDurationTokenBase
        ldy     #AudioRecordDuration
        sta     (AudioStatePtrLo),y
        jmp     DecodeNextAudioToken

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
        beq     WriteAudioNotePeriod
        tax
ShiftAudioNotePeriod:
LEBB4:  lsr     AudioWorkLo
        ror     AudioWorkHi
        dex
        bne     ShiftAudioNotePeriod
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
        bcc     FinishAudioTimedToken
        sec
        sbc     #AudioRoutedToLogicalOffset
        sta     (AudioStatePtrLo),y
; $60 оставляет период без изменения; и нота, и $60 переносят +6 в текущий +7.
FinishAudioTimedToken:
LEBD7:  ldy     #AudioRecordDuration
        lda     (AudioStatePtrLo),y
        iny
        sta     (AudioStatePtrLo),y
        jmp     AdvanceToNextAudioStream

DecodeAudioCommand:
LEBE1:  sbc     #AudioCommandTokenBase
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
LEC0C:  lda     #AudioStateOff
        sta     AudioStreamStates,x
        ldy     #AudioRecordChannel
        sta     (AudioStatePtrLo),y
        ldy     #AudioRecordPosition
        lda     (AudioStatePtrLo),y
        sec
        sbc     #$01
        sta     (AudioStatePtrLo),y
        jmp     AdvanceToNextAudioStream

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
        jmp     DecodeNextAudioToken

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
        jmp     DecodeNextAudioToken

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
        jmp     DecodeNextAudioToken

; $EC operand: заменяет второй аппаратный регистр канала (+2).
AudioCommandSetAux:
AudioCommandEC:
LEC57:  jsr     ReadAudioArgument
        ldy     #AudioRecordAux
        sta     (AudioStatePtrLo),y
        jmp     DecodeNextAudioToken

; $ED operand: заменяет шаблон старшего регистра периода (+4).
AudioCommandSetPeriodHigh:
AudioCommandED:
LEC61:  jsr     ReadAudioArgument
        ldy     #AudioRecordPeriodHi
        sta     (AudioStatePtrLo),y
        jmp     DecodeNextAudioToken

; $EE operand: заменяет CTRL (+1) целиком.
AudioCommandSetControl:
AudioCommandEE:
LEC6B:  jsr     ReadAudioArgument
        ldy     #AudioRecordControl
        sta     (AudioStatePtrLo),y
        jmp     DecodeNextAudioToken

; $EF: сбрасывает три общих для всех потоков счётчика циклов $F0-$F2.
AudioCommandResetLoopCounters:
AudioCommandEF:
LEC75:  lda     #$00
        ldx     #$02
ClearNextAudioLoopCounter:
LEC79:  sta     AudioLoopCounters,x
        dex
        bpl     ClearNextAudioLoopCounter
        jmp     DecodeNextAudioToken

; $F0-$F2 count,target: выбирают один из трёх общих счётчиков. Пока он не равен count,
; переходят к абсолютной позиции target внутри потока. При равенстве счётчик
; обнуляется, target пропускается и исполнение идёт дальше.
AudioCommandLoop0:
AudioCommandF0:
LEC81:  ldx     #$00
        beq     ExecuteAudioLoopCommand
AudioCommandLoop1:
AudioCommandF1:
LEC85:  ldx     #$01
        .byte   $2C                    ; BIT abs поглощает следующий LDX #$02.
AudioCommandLoop2:
AudioCommandF2:
LEC88:  ldx     #$02
ExecuteAudioLoopCommand:
LEC8A:  jsr     ReadAudioArgument
        inc     AudioLoopCounters,x
        cmp     AudioLoopCounters,x
        bne     AudioCommandJump
        lda     #$00
        sta     AudioLoopCounters,x
        beq     AudioCommandSkipArgument

; $F3-$F8 operand: в этой версии только пропускают один байт.
AudioCommandSkipArgument:
AudioCommandF3ToF8:
LEC99:  ldy     #AudioRecordPosition
        lda     (AudioStatePtrLo),y
        clc
        adc     #$01
        sta     (AudioStatePtrLo),y
        jmp     DecodeNextAudioToken

; $F9 target: заменяет позицию +5 абсолютным смещением от начала потока.
AudioCommandJump:
AudioCommandF9:
LECA5:  jsr     ReadAudioArgument
        ldy     #AudioRecordPosition
        sta     (AudioStatePtrLo),y
        jmp     DecodeNextAudioToken

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
