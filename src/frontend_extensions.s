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
; Два завершённых $FF тайловых текста пункта меню. Точный читаемый текст зависит от CHR.
RestrictedPowerUpsMenuText:
        .byte   $30,$31,$5D,$31,$34,$FF
AllPowerUpsMenuText:
        .byte   $31,$35,$5D,$32,$38,$FF

; Выводит один из двух текстов пункта меню в позицию (21,3) и ждёт кадр.
; Вход: AllPowerUpsEnabled=0/!=0 выбирает restricted/all-power-ups строку.
; Записывает ScratchPtr, ставит строку в PPU-очередь и shadow nametable,
; меняет AuxPtr и синхронизируется с кадром; портит A/X/Y и флаги.
; После возврата кадровое, PPU и input-состояние отражают
; побочные эффекты QueueTileAtCoordinates/WaitForNextFrame.
; Layout constraint: BEQ после загрузки RestrictedPowerUpsMenuText служит
; безусловным переходом только пока младший байт её адреса равен нулю; обе
; строки также должны оставаться на одной странице, так как старший байт общий.
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

; Помещает переданный в ScratchPtr $FF-терминированный тайловый текст в столбец
; 11 меню; сам текст не меняет.
; Строка вычисляется из GameVariant: 9+GameVariant для неотрицательных значений,
; 16+(GameVariant & $0F) для отрицательных. Портит A/X/Y, AuxPtr, флаги,
; PPU-очередь и соответствующие байты shadow nametable; ScratchPtr сохраняется.
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
; RAM и X/Y не меняет; портит флаги.
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

; Секретная комбинация продолжения: P1 A и P2 A+B. Если P1 выбыл, ему
; восстанавливаются DefaultInitialLifeCount жизней; иначе то же делается для
; выбывшего P2. Только после восстановления включает двух игроков и
; GameMode=TwoPlayerGameMode. Если оба живы или chord
; неполон, состояние не меняется. Всегда хвостом переходит в SelectStage и сама
; не возвращается; портит A и флаги, X/Y сохраняет до перехода.
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
