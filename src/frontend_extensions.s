; Дополнительные данные и обработчики меню Tank 1990 ($FCFC-$FD93).

; $FCFC..$FCFF — хвост неидентифицированного потока данных; статических ссылок нет.
HiBankPrefixData:
        .byte   $20,$D2,$0D,$2D
; Два завершённых $FF тайловых текста пункта меню. Точный читаемый текст зависит от CHR.
MenuOptionText0:
        .byte   $30,$31,$5D,$31,$34,$FF
MenuOptionText1:
        .byte   $31,$35,$5D,$32,$38,$FF

; Выводит один из двух текстов пункта меню в позицию (21,3) и ждёт кадр.
; Вход: AllPowerUpsEnabled=0/!=0 выбирает MenuOptionText0/1.
; Записывает ScratchPtr, ставит строку в PPU-очередь и shadow nametable,
; меняет AuxPtr и синхронизируется с кадром; портит A/X/Y и флаги.
; После возврата кадровое, PPU и input-состояние отражают
; побочные эффекты QueueTileAtCoordinates/WaitForNextFrame.
; Layout constraint: BEQ после загрузки MenuOptionText0 служит безусловным
; переходом только пока младший байт адреса MenuOptionText0 равен нулю; обе
; строки также должны оставаться на одной странице, так как старший байт общий.
DrawSelectedMenuOption:
LFD0C:  lda     AllPowerUpsEnabled
        bne     SelectEnabledPowerUpMenuText
        lda     #<MenuOptionText0
        beq     StoreSelectedPowerUpMenuText
SelectEnabledPowerUpMenuText:
LFD14:  lda     #<MenuOptionText1
StoreSelectedPowerUpMenuText:
LFD16:  sta     ScratchPtrLo
        lda     #>MenuOptionText0
        sta     ScratchPtrHi
        ldx     #$15
        ldy     #$03
        jsr     QueueTileAtCoordinates
        jsr     WaitForNextFrame
        rts

; Помещает переданный в ScratchPtr $FF-терминированный тайловый текст в столбец
; 11 меню; сам текст не меняет.
; Строка вычисляется из GameVariant: 9+GameVariant для неотрицательных значений,
; 16+(GameVariant & $0F) для отрицательных. Портит A/X/Y, AuxPtr, флаги,
; PPU-очередь и соответствующие байты shadow nametable; ScratchPtr сохраняется.
QueueVariantMenuText:
LFD27:  ldx     #$0B
        lda     GameVariant
        clc
        bpl     FinishVariantMenuRow
        and     #$0F
        adc     #$07
FinishVariantMenuRow:
LFD32:  adc     #$09
        tay
        jsr     QueueTileAtCoordinates
        rts

; Данные $FD39..$FD45 без статических ссылок; назначение не установлено.
UnreferencedFd39Data:
        .byte   $9D,$DD,$DD,$DD,$86,$DD,$DD,$9D
        .byte   $DD,$DD,$D9,$99,$DD

; Выбирает начальное число жизней по состоянию меню/ввода.
; Приоритет условий: TitleSecretInputCode=$0F, удержание Down, удержание Up,
; значение по умолчанию. Выход: соответственно A=$15/$08/$0B/$03.
; RAM и X/Y не меняет; портит флаги.
SelectInitialLifeCount:
LFD46:  lda     TitleSecretInputCode
        cmp     #$0F
        bne     CheckInitialLivesDown
        lda     #$15
        rts

CheckInitialLivesDown:
LFD4F:  lda     Joy1Held
        and     #BUTTON_DOWN
        beq     CheckInitialLivesUp
        lda     #$08
        rts

CheckInitialLivesUp:
LFD58:  lda     Joy1Held
        and     #BUTTON_UP
        beq     ReturnDefaultInitialLives
        lda     #$0B
        rts

ReturnDefaultInitialLives:
LFD61:  lda     #$03
        rts

; Секретная комбинация продолжения: P1 A и P2 A+B. Если P1 выбыл, ему
; восстанавливаются 3 жизни; иначе то же делается для выбывшего P2. Только после
; восстановления включает двух игроков и GameMode=$07. Если оба живы или chord
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
        lda     #$03
        sta     Player1Lives
        bne     EnableSecretContinue
        nop
RestorePlayer2ForSecretContinue:
LFD81:  lda     Player2Lives
        bne     FinishSecretContinue
        lda     #$03
        sta     Player2Lives
EnableSecretContinue:
LFD89:  lda     #$01
        sta     MenuSelection
        lda     #$07
        sta     GameMode
FinishSecretContinue:
LFD91:  jmp     SelectStage
