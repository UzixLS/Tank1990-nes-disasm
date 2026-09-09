; Заключительная часть кода и векторы ($FCFC-$FFFF).

.segment "PRG1_HI": absolute

; $FCFC..$FCFF — хвост неидентифицированного потока данных; статических ссылок нет.
HiBankPrefixData:
        .byte   $20,$D2,$0D,$2D
; Два завершённых $FF тайловых текста пункта меню. Точный читаемый текст зависит от CHR.
MenuOptionText0:
        .byte   $30,$31,$5D,$31,$34,$FF
MenuOptionText1:
        .byte   $31,$35,$5D,$32,$38,$FF

; Выводит один из двух текстов пункта меню в позицию (21,3) и ждёт кадр.
; Вход: $8E=0/!=0 выбирает MenuOptionText0/1. Портит ScratchPtr, A, X, Y;
; QueueTileAtCoordinates/WaitForNextFrame меняют PPU-очередь и кадровое состояние.
DrawSelectedMenuOption:
LFD0C:  lda     $8E
        bne     LFD14
        lda     #<MenuOptionText0
        beq     LFD16
LFD14:  lda     #<MenuOptionText1
LFD16:  sta     ScratchPtrLo
        lda     #$FD
        sta     ScratchPtrHi
        ldx     #$15
        ldy     #$03
        jsr     QueueTileAtCoordinates
        jsr     WaitForNextFrame
        rts

; Помещает переданный в ScratchPtr тайловый текст в столбец 11 меню.
; Строка вычисляется из $46: 9+$46 для неотрицательных значений, 16+($46 & $0F) для отрицательных.
; Портит A, X, Y и PPU-очередь.
QueueVariantMenuText:
LFD27:  ldx     #$0B
        lda     $46
        clc
        bpl     LFD32
        and     #$0F
        adc     #$07
LFD32:  adc     #$09
        tay
        jsr     QueueTileAtCoordinates
        rts

; Неидентифицированные данные $FD39..$FD45; прямых ссылок нет.
UnidentifiedFd39Data:
        .byte   $9D,$DD,$DD,$DD,$86,$DD,$DD,$9D
        .byte   $DD,$DD,$D9,$99,$DD

; Выбирает начальное число жизней по состоянию меню/ввода.
; Выход: A=$15 при $4A=$0F, $08 при Down, $0B при Up, иначе $03.
; RAM не меняет; X/Y сохраняет.
SelectInitialLifeCount:
LFD46:  lda     $4A
        cmp     #$0F
        bne     LFD4F
        lda     #$15
        rts

LFD4F:  lda     Joy1Held
        and     #BUTTON_DOWN
        beq     LFD58
        lda     #$08
        rts

LFD58:  lda     Joy1Held
        and     #BUTTON_UP
        beq     LFD61
        lda     #$0B
        rts

LFD61:  lda     #$03
        rts

; Секретная комбинация продолжения: P1 A и P2 A+B. Если один из игроков выбыл,
; восстанавливает ему 3 жизни, включает двух игроков и GameMode=$07.
; Всегда переходит в SelectStage; портит A и флаги.
HandleSecretContinueChord:
LFD64:  lda     Joy1Held
        and     #BUTTON_A
        beq     LFD91
        lda     Joy2Held
        and     #BUTTON_B
        beq     LFD91
        lda     Joy2Held
        and     #BUTTON_A
        beq     LFD91
        lda     Player1Lives
        bne     LFD81
        lda     #$03
        sta     Player1Lives
        bne     LFD89
        nop
LFD81:  lda     Player2Lives
        bne     LFD91
        lda     #$03
        sta     Player2Lives
LFD89:  lda     #$01
        sta     MenuSelection
        lda     #$07
        sta     GameMode
LFD91:  jmp     SelectStage

; Отложенная проверка runtime-контрольной суммы.
; При StageNumber<26 и в большинстве кадров только вызывает LC31D. Начиная с 26-го этапа с вероятностью 1/8
; сравнивает вычисленный XOR в $8D с эталоном $8C. При несовпадении переходит по ScratchPtr.
; Важно: этот путь не возвращается к вызывающему коду. Обычный путь портит A/X и состояние RNG.
MaybeEnforceRuntimeChecksum:
LFD94:
        lda     StageNumber
        cmp     #$1A
        bcc     LFDAD
        jsr     NextRandomByte
        and     #$0E
        bne     LFDAD
        ldx     #$05
        lda     $88,x
        dex
        cmp     $88,x
        beq     LFDAD
        jmp     (ScratchPtrLo)

LFDAD:  jsr     LC31D
        rts

; Адаптер для слотов игроков: при X<2 записывает $0A в $0100 и возвращается;
; при X>=2 проваливается в PowerUpEffect2. Портит A и флаги.
InitializePlayerExtensionOrApplyEffect2:
LFDB1:  cpx     #$02
        bcs     LFDBB
        lda     #$0A
        sta     $0100
        rts

PowerUpEffect2:
; Вход: X — слот подобравшего усиление. Для X>=2 заменяет три блока вокруг базы и
; обнуляет атрибуты через LCB31. Для X<2 при активном $68 обновляет ограждение и ставит $45=$14.
; Портит ScratchPtr, A, X, Y; меняет nametable shadow/PPU-очередь через вызываемые процедуры.
LFDBB:  cpx     #$02
        bcc     LFDEF
        lda     #$D3
        sta     ScratchPtrHi
        lda     #$6D
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$19
        jsr     QueueTileAtCoordinates
        lda     #$E5
        sta     ScratchPtrHi
        lda     #$E8
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$1A
        jsr     QueueTileAtCoordinates
        lda     #$D2
        sta     ScratchPtrHi
        lda     #$99
        sta     ScratchPtrLo
        ldx     #$0C
        ldy     #$1B
        jsr     QueueTileAtCoordinates
        jmp     LCB31

LFDEF:  lda     $68
        bpl     LFDFA
        jsr     LCB9E
        lda     #$14
        sta     $45
LFDFA:  rts

; Обработчик эффекта 3. Для X>=2 ставит бит $08 в ObjectAttributes слотов 2..7.
; Для X<2 увеличивает $0101,X на $20 пока значение меньше $60 и зеркалит его в ObjectAttributes,X.
; Сохраняет исходный X; портит A и флаги.
ApplyPowerUpEffect3:
LFDFB:  cpx     #$02
        bcc     LFE12
        txa
        pha
        ldx     #$07
LFE03:  lda     ObjectAttributes,x
        ora     #$08
        sta     ObjectAttributes,x
        nop
        dex
        cpx     #$01
        bne     LFE03
        pla
        tax
        rts

LFE12:  lda     $0101,x
        cmp     #$60
        bcs     LFE21
        clc
        adc     #$20
        sta     $0101,x
        sta     ObjectAttributes,x
LFE21:  rts

PowerUpEffect4:
; Поражает танки противоположной стороны: для X<2 — слоты 2..7, для X>=2 — игроков 0..1,
; если их ObjectState активен. Записывает state=$73, attributes=0; для игроков также $0101=$20.
; Поднимает флаг эффекта $030A; портит A, Y, $5A, флаги.
LFE22:  cpx     #$02
        bcc     LFE51
        lda     #$01
        sta     $5A
        sta     $030A
LFE2D:  ldy     $5A
        lda     ObjectState,y
        bpl     LFE4C
        cmp     #$E0
        bcs     LFE4C
        lda     $6F,y
        bne     LFE4C
        lda     #$20
        sta     $0101,y
        lda     #$73
        sta     ObjectState,y
        lda     #$00
        sta     ObjectAttributes,y
LFE4C:  dec     $5A
        bpl     LFE2D
        rts

LFE51:  lda     #$07
        sta     $5A
        lda     #$01
        sta     $030A
LFE5A:  ldy     $5A
        lda     ObjectState,y
        bpl     LFE6F
        cmp     #$E0
        bcs     LFE6F
        lda     #$73
        sta     ObjectState,y
        lda     #$00
        sta     ObjectAttributes,y
LFE6F:  dec     $5A
        lda     $5A
        cmp     #$01
        bne     LFE5A
        rts

PowerUpEffect5:
; Для игрока X<2 добавляет жизнь и поднимает UI-флаги $0304/$0305. Для X>=2 преобразует
; младшие биты ObjectAttributes всех слотов 2..7. Сохраняет исходный X; портит A и флаги.
LFE78:  cpx     #$02
        bcs     LFE87
        inc     Player1Lives,x
        lda     #$01
        sta     $0304
        sta     $0305
        rts

LFE87:  txa
        pha
        ldx     #$07
LFE8B:  lda     ObjectAttributes,x
        ora     #$03
        eor     #$04
        sta     ObjectAttributes,x
        dex
        cpx     #$01
        bne     LFE8B
        pla
        tax
        rts

; Устанавливает ObjectAttributes,X=$63; для игроков X<2 также зеркалит $63 в $0101,X.
; Выход: A=$63; X/Y и остальная RAM не меняются.
SetMaximumObjectUpgrade:
LFE9B:  lda     #$63
        cpx     #$02
        bcs     LFEA4
        sta     $0101,x
LFEA4:  sta     ObjectAttributes,x
        rts

PowerUpEffect7:
; Активирует дополнительную способность объекта X через $0170,X=$FF.
; Её наблюдаемые эффекты: дополнительная отрисовка и проход через TSA $12; точное игровое имя не закреплено.
LFEA7:  lda     #$FF
        sta     $0170,x
        rts

; Послекадровый проход расширения Tank 1990.
; Для каждого слота 7..0 с ненулевым $0170,X вызывает LDA7B с координатами объекта и кодом $63,
; затем запускает integrity guard и обрабатывает передачу жизни между игроками.
; Портит A, X, Y, $04, $53, $5A и рабочие поля вызываемых процедур; может изменить Player*Lives.
UpdateTank1990Extensions:
LFEAD:  lda     #$07
        sta     $5A
LFEB1:  ldx     $5A
        lda     $0170,x
        nop
        nop
        beq     LFEC9
        txa
        sta     $04
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        lda     #$63
        sta     $53
        jsr     LDA7B
LFEC9:  dec     $5A
        bpl     LFEB1
        jsr     RunDeferredIntegrityGuard
        lda     MenuSelection
        beq     LFF04
        lda     Player2Lives
        beq     LFEEF
        cmp     #$02
        bcc     LFF04
        lda     Player1Lives
        bne     LFF04
        lda     Joy1Held
        and     #BUTTON_A
        beq     LFF04
        inc     Player1Lives
        dec     Player2Lives
        ldx     #$00
        jmp     LE363

LFEEF:  lda     Player1Lives
        cmp     #$02
        bcc     LFF04
        lda     Joy2Held
        and     #BUTTON_A
        beq     LFF04
        inc     Player2Lives
        dec     Player1Lives
        ldx     #$01
        jmp     LE363

LFF04:  rts

; Маршрутизация первой проверки TSA при движении.
; Вход: A — код TSA, $5A — слот объекта. При $0170,X!=0 код $12 направляется в проходимую ветвь LDCDF;
; иначе TSA<$20 идёт в ветвь столкновения LDD11, TSA>=$20 — в LDCDF. Не возвращается.
RouteFirstTerrainProbe:
LFF05:  pha
        nop
        nop
        nop
        nop
        nop
        ldx     $5A
        lda     $0170,x
        nop
        nop
        nop
        beq     LFF1D
        pla
        cmp     #$12
        bne     LFF1E
LFF1A:  jmp     LDCDF

LFF1D:  pla
LFF1E:  cmp     #$20
        bcs     LFF1A
        jmp     LDD11

; Парный RouteFirstTerrainProbe маршрутизатор второй проверки TSA.
; При разрешённом проходе переходит в LDD04, при столкновении — в LDD11. Не возвращается.
RouteSecondTerrainProbe:
LFF25:  pha
        nop
        nop
        nop
        nop
        nop
        ldx     $5A
        lda     $0170,x
        nop
        nop
        nop
        beq     LFF3D
        pla
        cmp     #$12
        bne     LFF3E
LFF3A:  jmp     LDD04

LFF3D:  pla
LFF3E:  cmp     #$20
        bcs     LFF3A
        jmp     LDD11

; Сбрасывает 16 байт состояния расширения $0170..$017F, затем вызывает LD491.
; Выход: A=0, X=$FF; побочные эффекты LD491 не ограничены.
ResetExtensionState:
LFF45:  lda     #$00
        ldx     #$0F
LFF49:  sta     $0170,x
        dex
        bpl     LFF49
        jsr     LD491
        rts

; Заполняет пять байт $0174..$0178 значением A, затем вызывает LD491.
; A и X/Y перед LD491 сохраняются, но сам LD491 может их изменить.
FillExtensionSlots4Through8:
LFF53:  sta     $0174
        sta     $0175
        sta     $0176
        sta     $0177
        sta     $0178
        jsr     LD491
        rts
; Обрабатывает попадание снаряда в объект X с нулевым $89,X.
; Ненулевой $0170,X поглощается/очищается. Без него объект переводится в state=$73, кроме случая $0101,X=$63:
; тогда ставится $030E=1 и значение $40 в $0101,X, $0178,X и ObjectAttributes,X. Не возвращается.
HandleProjectileHitOnTank:
LFF66:  lda     $0170,x
        beq     LFF73
        lda     #$00
        sta     $0170,x
        jmp     LE77A

LFF73:  lda     $0101,x
        cmp     #$63
        beq     LFF81
        lda     #$73
        sta     ObjectState,x
        jmp     LE763

LFF81:  lda     #$01
        sta     $030E
        lda     #$40
        sta     $0101,x
        sta     $0178,x
        sta     ObjectAttributes,x
        jmp     LE77A

; Поднимает $0307 и возвращает в A модификатор $20 при отрицательном $46, иначе 0.
; X/Y не меняет; портит флаги.
GetVariantAttributeBits:
LFF93:  lda     #$01
        sta     $0307
        lda     $46
        bmi     LFF9F
        lda     #$00
        rts

LFF9F:  lda     #$20
        rts

; Одиночный байт $01 по $FFA2; статических ссылок нет.
UnidentifiedFfa2Byte:
        .byte   $01
; Записывает A в ObjectAttributes,X и переходит в общий хвост LE77A.
StoreAttributesAndContinueCollisionPass:
LFFA3:  sta     ObjectAttributes,x
        jmp     LE77A
; Хвост итерации по объектам: очищает $0170,X для ObjectState=$73, затем уменьшает $5A.
; При $5A>=0 переходит к LE710, иначе возвращается. Портит A, $5A и флаги.
AdvanceTankCollisionPass:
LFFA8:  lda     ObjectState,x
        cmp     #$73
        bne     LFFB3
        lda     #$00
        sta     $0170,x
LFFB3:  dec     $5A
        bpl     LFFB8
        rts

LFFB8:  jmp     LE710

; Очищает дополнительное состояние $0170,X. Выход: A=0; X/Y сохраняются.
ClearObjectExtensionState:
LFFBB:  lda     #$00
        sta     $0170,x
        rts
; Настраивает ProjectileFlags,X по режиму $46 и ObjectAttributes,X.
; В базовом режиме передаёт старшую тетраду атрибутов в LE0C0. В расширенном режиме ($46<0)
; бит $08 или класс $60 дают flags=3, часть прочих ненулевых классов — flags=1. Портит A и флаги.
InitializeProjectileFlagsForVariant:
LFFC1:  lda     $46
        bmi     LFFCC
        lda     ObjectAttributes,x
        and     #$F0
        jmp     LE0C0

LFFCC:  lda     ObjectAttributes,x
        and     #$08
        beq     LFFD5
        jmp     LE0D3

LFFD5:  lda     ObjectAttributes,x
        and     #$F0
        beq     LFFF0
        cmp     #$A0
        bcs     LFFE7
        cmp     #$60
        beq     LFFEC
        and     #$80
        bne     LFFF0
LFFE7:  lda     #$01
        sta     ProjectileFlags,x
        rts

LFFEC:  lda     #$03
        sta     ProjectileFlags,x
LFFF0:  rts

; $FFF1..$FFF9 — заполнение $FF перед аппаратными векторами.
        .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
        .byte   $FF

; NROM использует ResetHandler и как RESET-, и как IRQ/BRK-вектор.
        .word   NmiHandler
        .word   ResetHandler
        .word   ResetHandler

