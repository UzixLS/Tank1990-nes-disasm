; Дополнительные данные и обработчики меню Tank 1990 ($FCFC-$FD93).

VariantMenuTextColumn       = $0B
StandardVariantMenuFirstRow = $09
ExtendedVariantMenuRowBias  = $07
VariantPowerUpOptionColumn  = $15
SecretInitialLivesCode      = $0F
SecretInitialLifeCount      = $15
DownInitialLifeCount        = $08
UpInitialLifeCount          = $0B
DefaultInitialLifeCount     = $03
TwoPlayerMenuSelection      = $01

; $FCFC..$FCFF — хвост неидентифицированного потока данных; статических ссылок нет.
HiBankPrefixData:
        .byte   $20,$D2,$0D,$2D
; Два пятитайловых $FF-терминированных текста feature flag. Точный читаемый
; текст зависит от CHR. RestrictedPowerUpsMenuText намеренно начинается по
; адресу $FD00: DrawPowerUpMenuOption использует его low byte 0 как branch trick.
RestrictedPowerUpsMenuText:
        .byte   $30,$31,$5D,$31,$34,$FF
AllPowerUpsMenuText:
        .byte   $31,$35,$5D,$32,$38,$FF

; Выводит один из двух пятитайловых текстов в (column 21,row 3) и ждёт NMI.
; Вход: AllPowerUpsEnabled=0/!=0 выбирает restricted/all-power-ups строку.
; Требует NMI и не более $77 в PpuBufferPos: восьмибайтная команда и следующий
; lookahead должны поместиться в $0180-$01FF. QueueTileAtCoordinates немедленно
; зеркалит текст в shadow, а внутренний WaitForNextFrame передаёт всю текущую
; очередь PPU и обнуляет PpuBufferPos; NMI также обновляет input/OAM/audio.
;
; Выход: ScratchPtr=выбранная строка, AuxPtr=$0475, X=позиция конца команды до
; flush (input PpuBufferPos+8), Y=5, PpuBufferPos=0. A — FrameCounter до
; ожидания, flags соответствуют успешному CMP WaitForNextFrame. PPU register
; state отражает NMI; RNG не вызывается.
; Layout constraint: BEQ после загрузки RestrictedPowerUpsMenuText служит
; безусловным переходом только пока low byte её адреса равен 0; обе строки
; также должны оставаться на одной странице, так как high byte общий. Пять
; тайлов обязаны помещаться в columns 21..25 без нежелательного row wrap.
DrawPowerUpMenuOption:
LFD0C:  lda     AllPowerUpsEnabled
        bne     SelectEnabledPowerUpMenuText
        lda     #<RestrictedPowerUpsMenuText
        beq     StoreSelectedPowerUpMenuText
SelectEnabledPowerUpMenuText:
LFD14:  lda     #<AllPowerUpsMenuText
StoreSelectedPowerUpMenuText:
LFD16:  sta     ScratchPtrLo
        lda     #>RestrictedPowerUpsMenuText
        sta     ScratchPtrHi
        ldx     #VariantPowerUpOptionColumn
        ldy     #VariantMenuHeaderRow
        jsr     QueueTileAtCoordinates
        jsr     WaitForNextFrame
        rts

; Добавляет переданный в ScratchPtr $FF-терминированный текст в column 11.
; Row = 9+GameVariant для любого неотрицательного значения без masking;
; для отрицательного row=16+(GameVariant&$0F). Валидные menu-диапазоны дают
; rows 9..15 и 16..22. Bounds/clipping и переход строки не проверяются.
; PpuBufferPos и длина N требуют N+3 байта команды и ещё один lookahead;
; NMI не должен прерывать построение. Shadow меняется немедленно, команда PPU
; остаётся pending до следующего NMI.
; Выход: A=$FF, X=PpuBufferPos=input+N+3, Y=длина, flags N=0/Z=1/C=1; ScratchPtr
; сохранён, AuxPtr указывает на начало строки в shadow. Меняет PpuTileRowBits,
; shadow и PPU buffer; PPU registers/OAM/audio/RNG напрямую не трогает.
QueueVariantMenuText:
LFD27:  ldx     #VariantMenuTextColumn
        lda     GameVariant
        clc
        bpl     FinishVariantMenuRow
        and     #GameVariantIndexMask
        adc     #ExtendedVariantMenuRowBias
FinishVariantMenuRow:
LFD32:  adc     #StandardVariantMenuFirstRow
        tay
        jsr     QueueTileAtCoordinates
        rts

; Данные $FD39..$FD45 без статических ссылок; назначение не установлено.
UnreferencedFd39Data:
        .byte   $9D,$DD,$DD,$DD,$86,$DD,$DD,$9D
        .byte   $DD,$DD,$D9,$99,$DD

; Выбирает начальное число жизней по состоянию меню/ввода.
; Приоритет условий: TitleSecretInputCode=SecretInitialLivesCode, удержание
; Down, удержание Up, значение по умолчанию. Выход: соответственно
; SecretInitialLifeCount, DownInitialLifeCount, UpInitialLifeCount или
; DefaultInitialLifeCount.
; Все результаты ненулевые: N=0/Z=0. C остаётся результатом первоначального
; CMP TitleSecretInputCode,#$0F, V сохраняется; RAM и X/Y не меняются.
; Используется только P1 input, PPU/OAM/audio/RNG не затрагиваются.
SelectInitialLifeCount:
LFD46:  lda     TitleSecretInputCode
        cmp     #SecretInitialLivesCode
        bne     CheckInitialLivesDown
        lda     #SecretInitialLifeCount
        rts

CheckInitialLivesDown:
LFD4F:  lda     Joy1Held
        and     #BUTTON_DOWN
        beq     CheckInitialLivesUp
        lda     #DownInitialLifeCount
        rts

CheckInitialLivesUp:
LFD58:  lda     Joy1Held
        and     #BUTTON_UP
        beq     ReturnDefaultInitialLives
        lda     #UpInitialLifeCount
        rts

ReturnDefaultInitialLives:
LFD61:  lda     #DefaultInitialLifeCount
        rts

; Секретная комбинация продолжения: held P1 A и held P2 A+B. При полном chord
; первым проверяется P1: если его lives=0, восстанавливаются только его три
; жизни; иначе проверяется и при нуле восстанавливается P2. После восстановления
; MenuSelection=1 и GameMode=TwoPlayerGameMode. Если оба живы либо chord
; неполон, эти поля не меняются. Всегда tail-jump в SelectStage и сама не
; возвращается; до перехода X/Y сохраняются, A/flags изменены. PPU/OAM/audio/RNG
; непосредственно не трогает, дальнейшие эффекты принадлежат SelectStage.
HandleSecretContinueChord:
LFD64:  lda     Joy1Held
        and     #BUTTON_A
        beq     FinishSecretContinue
        lda     Joy2Held
        and     #BUTTON_B
        beq     FinishSecretContinue
        lda     Joy2Held
        and     #BUTTON_A
        beq     FinishSecretContinue
        lda     Player1Lives
        bne     RestorePlayer2ForSecretContinue
        lda     #DefaultInitialLifeCount
        sta     Player1Lives
        bne     EnableSecretContinue
        nop
RestorePlayer2ForSecretContinue:
LFD81:  lda     Player2Lives
        bne     FinishSecretContinue
        lda     #DefaultInitialLifeCount
        sta     Player2Lives
EnableSecretContinue:
LFD89:  lda     #TwoPlayerMenuSelection
        sta     MenuSelection
        lda     #TwoPlayerGameMode
        sta     GameMode
FinishSecretContinue:
LFD91:  jmp     SelectStage
