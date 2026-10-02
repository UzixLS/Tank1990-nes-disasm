; Приоритетный интерпретатор потоков и маршрутизация APU ($EA51-$ECE5).

; Движок ведёт 28 потоков. Состояния занимают $0300-$031B, следующие за ними
; записи размером 8 байтов — $031C-$03FB; обе области имеют одинаковый индекс n.
; Штатные состояния: 0 — выключен, 1 — запрос запуска, 2 — активен; любое иное
; ненулевое значение, кроме 1, код также обработает как уже активное.
;
; Формат записи:
;   +0 route: 0 — канала нет; 1..4 — логический канал ждёт выдачи в APU;
;             5..8 — регистры уже выдавались, значение равно channel+4;
;   +1 register 0 -> $4000/$4004/$4008/$400C;
;   +2 register 1 -> $4001/$4005/$4009/$400D;
;   +3 register 2 -> $4002/$4006/$400A/$400E;
;   +4 register 3 -> $4003/$4007/$400B/$400F;
;   +5 абсолютное 8-битное смещение байткода от начала последовательности;
;   +6 длительность, которую загрузит следующее timed-событие;
;   +7 оставшееся число кадров текущего события.
;
; Смысл register 0..3 зависит от канала: это точный кеш четырёх подряд идущих
; аппаратных адресов, включая неиспользуемые $4009/$400D. Нотный декодер
; заменяет register 2 и только bits2..0 register 3. Меньший индекс потока имеет
; приоритет. Четыре байта AudioHardwareClaimFlags — лишь кадровые флаги
; занятости pulse1/pulse2/triangle/noise, а не номера владельцев.

AudioHardwareClaimFlags      = $F9
AudioStreamCount             = $1C
AudioRecordSize              = $08
AudioHardwareChannels        = $04
AudioNoiseChannel            = $04
AudioRoutedChannelBase       = $05
AudioRoutedChannelOffset     = $04
AudioHoldToken               = $60
AudioFirstCommandToken       = $E8
AudioLastCommandToken        = $F9
AudioHardwareClaimed         = $01
AudioLoopCounterLastIndex    = $02
ApuSynthChannelsEnabledValue = $0F
ApuFiveStepNoIrqValue        = $C0
AudioPulseSilentControl      = $10
AudioNotePeriodIndexMask     = $F8
AudioNoteOctaveShiftMask     = $07
AudioRegister0Low6Mask       = $3F
AudioRegister0High2Mask      = $C0
AudioRegister0High4Mask      = $F0
AudioRegister3UpperBitsMask  = $F8

AudioRecordRoute             = $00
AudioRecordRegister0         = $01
AudioRecordRegister1         = $02
AudioRecordRegister2         = $03
AudioRecordRegister3         = $04
AudioRecordBytecodeOffset    = $05
AudioRecordDurationReload    = $06
AudioRecordFramesRemaining   = $07

; Записывает APU_STATUS=$0F: включает четыре синтезируемых канала и выключает
; DMC. JOY2_FRAME=$C0 выбирает пятишаговый frame sequencer и запрещает его IRQ.
; Затем обнуляет 28 состояний и только поле route каждой записи. Register0..3,
; bytecode offset, duration/countdown и три глобальных loop counter намеренно
; сохраняются: состояние 0 исключает чтение записей до нового запуска.
;
; Выход: AudioStreamStates[0..27]=0, route всех записей=0,
; AudioStatePtr=$03FC, A=$FC, X=$1C, Y=0, Z=1/C=1/N=0; APU_STATUS=$0F,
; JOY2_FRAME=$C0. Меняет flags; PPU/OAM и прочую RAM не трогает.
ResetAudioEngine:
LEA51:  lda     #ApuSynthChannelsEnabledValue
        sta     APU_STATUS
        lda     #ApuFiveStepNoIrqValue
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

; Один вызов кадрового интерпретатора. Первый проход маршрутизирует кеши в APU,
; второй запускает потоки и отсчитывает события. Поэтому первый звук нового
; потока и регистры новой ноты попадут в APU только на следующем вызове.
; Штатный вызов идёт из NMI после чтения контроллеров/завершения OAM shadow и
; до увеличения FrameCounter; сам движок FrameCounter не читает и не меняет.
;
; Для каждого канала выигрывает наименьший индекс. Route 1..4 победителя
; превращается в 5..8 и register0..3 копируются в четыре адреса APU; route 5..8
; только удерживает claim без повторной записи. Проигравшие потоки продолжают
; отсчёт независимо от слышимости. Незахваченный pulse получает register0=$10,
; triangle/noise — register0=0.
;
; При PauseState!=0 оба прохода ограничены потоком 0, остальные состояния,
; записи и countdown заморожены, а не занятые им каналы заглушены. Поток с уже
; установленным route 5..8 сохраняет его; после снятия паузы он снова захватит
; канал без восстановления заглушённых регистров и зазвучит лишь после ноты,
; которая вернёт route в 1..4. Attract mode использует это как полное mute.
;
; Выход: AudioStreamLimit=AudioStreamIndex=1 при паузе, иначе $1C;
; AudioStatePtr=$0324 либо $03FC, A=AudioStreamLimit, Z=1/C=1/N=0. X/Y и рабочие
; Audio* испорчены. Может менять все записи обработанных потоков, три общих
; AudioLoopCounters, AudioHardwareClaimFlags и $4000-$400F; $4015/$4017,
; PPU/OAM и стек вызывающего сохраняет.
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
ClearAudioHardwareClaimFlags:
LEA90:  sta     AudioHardwareClaimFlags,x
        dex
        bpl     ClearAudioHardwareClaimFlags
        lda     #$00
        sta     AudioStreamIndex
        lda     #<AudioStreamRecords
        sta     AudioStatePtrLo
        lda     #>AudioStreamRecords
        sta     AudioStatePtrHi

; Первый проход. Инвариант route=0/1..4/5..8 обязателен: routed-значение >8
; индексировало бы RAM за четырьмя claim flags. Маркер 5..8 безусловно ставит
; claim, но ничего не пишет в APU; значение 1..4 пишет кеш только если более
; приоритетный поток ещё не поставил claim.
RouteAudioStreamsToApu:
LEAA1:  ldx     AudioStreamIndex
        lda     AudioStreamStates,x
        beq     AdvanceAudioOutputStream
        ldy     #AudioRecordRoute
        lda     (AudioStatePtrLo),y
        beq     AdvanceAudioOutputStream
        cmp     #AudioRoutedChannelBase
        bcc     WriteAudioStreamToApu
        sec
        sbc     #AudioRoutedChannelBase
        tax
        lda     #AudioHardwareClaimed
        sta     AudioHardwareClaimFlags,x
        jmp     AdvanceAudioOutputStream

WriteAudioStreamToApu:
LEABD:  tax
        dex
        lda     AudioHardwareClaimFlags,x
        bne     AdvanceAudioOutputStream
        lda     #AudioHardwareClaimed
        sta     AudioHardwareClaimFlags,x
        txa
        tay
        clc
        adc     #AudioRoutedChannelBase
        ldy     #AudioRecordRoute
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
; Отключает незахваченные каналы одной записью register0: pulse1/2 получают
; constant-volume 0 ($10), triangle/noise — 0. Остальные три регистра канала
; остаются как были; claims и записи потоков этот участок не меняет.
SilenceUnclaimedAudioChannels:
        ldx     #$00
SilenceNextAudioChannel:
LEAF8:  stx     AudioWorkLo
        lda     AudioHardwareClaimFlags,x
        bne     RestoreAudioHardwareIndex
        txa
        asl     a
        asl     a
        tax
        asl     a
        and     #AudioPulseSilentControl
        eor     #AudioPulseSilentControl
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

; Второй проход: state=1 становится 2 и переинициализирует поток; у любого
; другого ненулевого state countdown сначала уменьшается. При результате 0
; декодируется следующее timed-событие, иначе запись больше не меняется.
; Активный поток с исходным countdown=0 получит $FF и задержится на 256 вызовов,
; поэтому корректный байткод обязан задать duration 1..$87 до первой ноты/$60.
; Переходы из декодера возвращаются сюда хвостом; это не отдельная процедура.
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
LEB42:  ldy     #AudioRecordFramesRemaining
        lda     (AudioStatePtrLo),y
        sec
        sbc     #$01
        sta     (AudioStatePtrLo),y
        beq     ResumeAudioStream
        bne     AdvanceToNextAudioStream
; Запуск сбрасывает bytecode offset и читает четырёхбайтовый заголовок:
; route, register0, register1, register3. Для route=4 (noise) пятый байт задаёт
; register2; для pulse/triangle register2 впервые задаст нотный токен. Остальные
; поля записи не сбрасываются, поэтому до первого timed-события поток обязан
; задать duration token, а первым timed-событием tonal-потока должна быть нота:
; начальный $60 выдал бы в APU старый register2. Вход: AudioStreamIndex/
; AudioStatePtr выбраны вторым проходом. Не возвращается самостоятельно:
; декодер уйдёт в общий хвост.
InitializeAudioStream:
LEB4F:  lda     #$00
        ldy     #AudioRecordBytecodeOffset
        sta     (AudioStatePtrLo),y
        jsr     LoadAudioSequencePointer
        jsr     ReadAudioArgument
        ldy     #AudioRecordRoute
        sta     (AudioStatePtrLo),y
        jsr     ReadAudioArgument
        ldy     #AudioRecordRegister0
        sta     (AudioStatePtrLo),y
        jsr     ReadAudioArgument
        ldy     #AudioRecordRegister1
        sta     (AudioStatePtrLo),y
        jsr     ReadAudioArgument
        ldy     #AudioRecordRegister3
        sta     (AudioStatePtrLo),y
        ldy     #AudioRecordRoute
        lda     (AudioStatePtrLo),y
        cmp     #AudioNoiseChannel
        bne     DecodeNextAudioToken
        jsr     ReadAudioArgument
        ldy     #AudioRecordRegister2
        sta     (AudioStatePtrLo),y
        ; LDY #AudioRecordRegister2 гарантирует N=0: это безусловный переход.
        bpl     DecodeNextAudioToken

; При истечении таймера указатель байткода восстанавливается по номеру потока;
; позиция +5 уже указывает на следующий токен.
ResumeAudioStream:
LEB85:  jsr     LoadAudioSequencePointer

; За один вызов декодер читает произвольную цепочку duration/command tokens.
; Завершается только на ноте/$60 либо $E8; обычного RTS у участка нет.
; Допустимые command opcodes — $E8-$F9. Значения $FA-$FF как opcode выходят за
; inline-таблицу dispatch и прыгают по адресу из машинного кода; $FF допустим
; только как operand (так он и используется штатными данными).
DecodeNextAudioToken:
LEB88:  jsr     ReadAudioArgument
        cmp     #AudioFirstCommandToken
        bcs     DecodeAudioCommand
        cmp     #AudioHoldToken
        beq     FinishAudioTimedToken
        bcc     SetAudioNotePeriod
        sbc     #AudioHoldToken
        ldy     #AudioRecordDurationReload
        sta     (AudioStatePtrLo),y
        jmp     DecodeNextAudioToken

; Нота $00-$5F: bits7..3 выбирают одну из 12 пар AudioBasePeriods, bits2..0
; делят 16-битное значение на 2^n. В register3 сохраняются старшие пять бит,
; его bits2..0 получают high периода, register2 — low. Если route был 5..8,
; он уменьшается на 4 до 1..4: так нота разрешает запись кеша в APU на следующем
; вызове. Уже логический route остаётся без изменений.
SetAudioNotePeriod:
LEB9E:  pha
        and     #AudioNotePeriodIndexMask
        lsr     a
        lsr     a
        tax
        lda     AudioBasePeriods,x
        sta     AudioWorkLo
        lda     AudioBasePeriods+1,x
        sta     AudioWorkHi
        pla
        and     #AudioNoteOctaveShiftMask
        beq     WriteAudioNotePeriod
        tax
ShiftAudioNotePeriod:
LEBB4:  lsr     AudioWorkLo
        ror     AudioWorkHi
        dex
        bne     ShiftAudioNotePeriod
WriteAudioNotePeriod:
LEBBB:  ldy     #AudioRecordRegister3
        lda     (AudioStatePtrLo),y
        and     #AudioRegister3UpperBitsMask
        ora     AudioWorkLo
        sta     (AudioStatePtrLo),y
        lda     AudioWorkHi
        dey
        sta     (AudioStatePtrLo),y
        ldy     #AudioRecordRoute
        lda     (AudioStatePtrLo),y
        cmp     #AudioRoutedChannelBase
        bcc     FinishAudioTimedToken
        sec
        sbc     #AudioRoutedChannelOffset
        sta     (AudioStatePtrLo),y
; $60 не заглушает канал, не меняет кеш и не возвращает route 5..8 в логическое
; состояние: он лишь перезагружает countdown. И нота, и $60 копируют +6 в +7.
FinishAudioTimedToken:
LEBD7:  ldy     #AudioRecordDurationReload
        lda     (AudioStatePtrLo),y
        iny
        sta     (AudioStatePtrLo),y
        jmp     AdvanceToNextAudioStream

DecodeAudioCommand:
LEBE1:  sbc     #AudioFirstCommandToken
        jsr     DispatchAudioCommand

; DispatchAudioCommand использует снятый адрес возврата как базу inline-таблицы.
; Общий вход: A=opcode-$E8 в диапазоне 0..17, AudioStatePtr — текущая запись,
; AudioDataPtr — начало последовательности, bytecode offset стоит после opcode.
; Команды с operand читают его через ReadAudioArgument. Обработчики продолжают
; декодирование либо уходят в общий хвост UpdateAudioEngine; обычного RTS нет.
; Команды $E9-$EE меняют только кеш записи: сами они не пишут APU и не переводят
; route 5..8 обратно в 1..4. A/X/Y и AudioWorkLo/Hi испорчены.
AudioCommandHandlers:
        .word   AudioCommandStop,AudioCommandOrRegister0PreserveLow6
        .word   AudioCommandOrRegister0PreserveHigh2,AudioCommandOrRegister0PreserveHigh4
        .word   AudioCommandSetRegister1,AudioCommandSetRegister3
        .word   AudioCommandSetRegister0,AudioCommandResetLoopCounters
        .word   AudioCommandLoop0,AudioCommandLoop1,AudioCommandLoop2
        .word   AudioCommandSkipArgument,AudioCommandSkipArgument
        .word   AudioCommandSkipArgument,AudioCommandSkipArgument
        .word   AudioCommandSkipArgument,AudioCommandSkipArgument
        .word   AudioCommandJump

; $E8: state=0, route=0, bytecode offset откатывается на сам opcode $E8.
; A=предыдущее смещение opcode, X=AudioStreamIndex, Y=offset field; затем общий
; хвост сразу переходит к следующему потоку. В текущем кадре канал уже мог быть
; выдан/захвачен первым проходом и будет заглушён не раньше следующего вызова.
AudioCommandStop:
AudioCommandE8:
LEC0A:  ldx     AudioStreamIndex
DeactivateAudioStream:
LEC0C:  lda     #AudioStateOff
        sta     AudioStreamStates,x
        ldy     #AudioRecordRoute
        sta     (AudioStatePtrLo),y
        ldy     #AudioRecordBytecodeOffset
        lda     (AudioStatePtrLo),y
        sec
        sbc     #$01
        sta     (AudioStatePtrLo),y
        jmp     AdvanceToNextAudioStream

; $E9 operand: register0=(register0&$3F)|operand. Operand не маскируется, поэтому
; корректный поток сам ограничивает его нужными битами.
AudioCommandOrRegister0PreserveLow6:
AudioCommandE9:
LEC21:  jsr     ReadAudioArgument
        sta     AudioWorkLo
        ldy     #AudioRecordRegister0
        lda     (AudioStatePtrLo),y
        and     #AudioRegister0Low6Mask
        ora     AudioWorkLo
        sta     (AudioStatePtrLo),y
        jmp     DecodeNextAudioToken

; $EA operand: register0=(register0&$C0)|operand; operand не маскируется.
AudioCommandOrRegister0PreserveHigh2:
AudioCommandEA:
LEC33:  jsr     ReadAudioArgument
        sta     AudioWorkLo
        ldy     #AudioRecordRegister0
        lda     (AudioStatePtrLo),y
        and     #AudioRegister0High2Mask
        ora     AudioWorkLo
        sta     (AudioStatePtrLo),y
        jmp     DecodeNextAudioToken

; $EB operand: register0=(register0&$F0)|operand; operand не маскируется.
AudioCommandOrRegister0PreserveHigh4:
AudioCommandEB:
LEC45:  jsr     ReadAudioArgument
        sta     AudioWorkLo
        ldy     #AudioRecordRegister0
        lda     (AudioStatePtrLo),y
        and     #AudioRegister0High4Mask
        ora     AudioWorkLo
        sta     (AudioStatePtrLo),y
        jmp     DecodeNextAudioToken

; $EC operand: заменяет register1 (+2) целиком.
AudioCommandSetRegister1:
AudioCommandEC:
LEC57:  jsr     ReadAudioArgument
        ldy     #AudioRecordRegister1
        sta     (AudioStatePtrLo),y
        jmp     DecodeNextAudioToken

; $ED operand: заменяет register3 (+4) целиком; следующая нота сохранит bits7..3.
AudioCommandSetRegister3:
AudioCommandED:
LEC61:  jsr     ReadAudioArgument
        ldy     #AudioRecordRegister3
        sta     (AudioStatePtrLo),y
        jmp     DecodeNextAudioToken

; $EE operand: заменяет register0 (+1) целиком.
AudioCommandSetRegister0:
AudioCommandEE:
LEC6B:  jsr     ReadAudioArgument
        ldy     #AudioRecordRegister0
        sta     (AudioStatePtrLo),y
        jmp     DecodeNextAudioToken

; $EF: синхронно обнуляет все три общих, не принадлежащих отдельной записи,
; счётчика команд $F0-$F2. Низкий индекс ведущего музыкального потока позволяет
; выполнить этот reset раньше инициализации следующих дорожек в том же NMI.
AudioCommandResetLoopCounters:
AudioCommandEF:
LEC75:  lda     #$00
        ldx     #AudioLoopCounterLastIndex
ClearNextAudioLoopCounter:
LEC79:  sta     AudioLoopCounters,x
        dex
        bpl     ClearNextAudioLoopCounter
        jmp     DecodeNextAudioToken

; $F0-$F2 count,target используют соответствующий глобальный counter. На каждом
; достижении команды counter сначала увеличивается. Если он не равен count,
; target читается и становится абсолютным bytecode offset; при равенстве counter
; сбрасывается, target только пропускается. Поэтому участок до команды исполняется
; count раз, включая первый проход; count=0 даёт 256 проходов. Одновременное
; использование одного counter разными потоками взаимно влияет на их циклы.
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
LEC88:  ldx     #AudioLoopCounterLastIndex
ExecuteAudioLoopCommand:
LEC8A:  jsr     ReadAudioArgument
        inc     AudioLoopCounters,x
        cmp     AudioLoopCounters,x
        bne     AudioCommandJump
        lda     #$00
        sta     AudioLoopCounters,x
        beq     AudioCommandSkipArgument

; $F3-$F8 operand: шесть различных opcode сведены к пропуску ровно одного байта;
; дополнительный эффект в этой версии отсутствует, семантика operand неизвестна.
AudioCommandSkipArgument:
AudioCommandF3ToF8:
LEC99:  ldy     #AudioRecordBytecodeOffset
        lda     (AudioStatePtrLo),y
        clc
        adc     #$01
        sta     (AudioStatePtrLo),y
        jmp     DecodeNextAudioToken

; $F9 target: читает один байт и заменяет bytecode offset этим абсолютным
; смещением от начала последовательности, включая её заголовок.
AudioCommandJump:
AudioCommandF9:
LECA5:  jsr     ReadAudioArgument
        ldy     #AudioRecordBytecodeOffset
        sta     (AudioStatePtrLo),y
        jmp     DecodeNextAudioToken

; Выбирает начало последовательности по AudioStreamIndex.
; Вход: AudioStreamIndex=0..27. Выход: AudioDataPtr указывает на первый байт
; заголовка, A=его high byte, X=2*AudioStreamIndex, Y сохранён. Меняет flags;
; записи потоков и прочую RAM сохраняет.
LoadAudioSequencePointer:
LECAF:  lda     AudioStreamIndex
        asl     a
        tax
        lda     AudioSequencePointers,x
        sta     AudioDataPtrLo
        lda     AudioSequencePointers+1,x
        sta     AudioDataPtrHi
        rts

; Читает AudioDataPtr[bytecode offset] и увеличивает offset по модулю 256.
; Индексная адресация корректно пересекает физическую страницу ROM, но формат
; не способен обратиться дальше +$FF и после этого оборачивается к заголовку.
; Вход: AudioDataPtr и AudioStatePtr текущего потока валидны. Выход: A=прочитанный
; байт, Y=AudioRecordBytecodeOffset ($05), X и оба указателя сохранены; поле +5
; увеличено. Временно использует один байт стека и восстанавливает SP; flags
; соответствуют A после PLA. Начальная загрузка AudioStreamIndex результата не
; имеет и немедленно перекрывается чтением offset.
ReadAudioArgument:
LECBE:  lda     AudioStreamIndex
        ldy     #AudioRecordBytecodeOffset
        lda     (AudioStatePtrLo),y
        tay
        lda     (AudioDataPtrLo),y
        pha
        iny
        tya
        ldy     #AudioRecordBytecodeOffset
        sta     (AudioStatePtrLo),y
        pla
        rts

; Безвозвратный inline-dispatch. Вход: A=индекс 0..17; JSR обязан непосредственно
; предшествовать таблице 18 little-endian адресов. Снимает двухбайтовый адрес
; возврата, индексирует таблицу относительно него и прыгает к обработчику.
; Адрес намеренно не возвращается на стек: общий RTS обработчика завершит весь
; UpdateAudioEngine. Индекс >17 прочитает псевдоадрес из следующего машинного
; кода. Портит A/X/Y, AudioWorkLo/Hi и flags; сам не меняет записи/APU.
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
