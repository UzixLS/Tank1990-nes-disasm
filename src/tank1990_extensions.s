; Послекадровая логика и terrain-routing расширений Tank 1990 ($FEAD-$FF65).

; Послекадровый проход расширения Tank 1990.
; Для каждого слота 7..0 с ненулевым $0170,X рисует двухспрайтовый объект
; с координатами танка и кодом $63,
; затем запускает integrity guard и обрабатывает передачу жизни между игроками.
; Портит A, X, Y, RenderAttributes, OamTile, ExtensionObjectSlot и рабочие поля
; вызываемых процедур; может изменить Player*Lives.
UpdateTank1990Extensions:
LFEAD:  lda     #(TankSlotCount-1)
        sta     ExtensionObjectSlot
DrawNextTankExtension:
LFEB1:  ldx     ExtensionObjectSlot
        lda     ObjectSpecialState,x
        nop
        nop
        beq     AdvanceTankExtensionSlot
        txa
        sta     RenderAttributes
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        lda     #$63
        sta     OamTile
        jsr     EmitTwoTileOamPair
AdvanceTankExtensionSlot:
LFEC9:  dec     ExtensionObjectSlot
        bpl     DrawNextTankExtension
        jsr     RunDeferredIntegrityGuard
        lda     MenuSelection
        beq     FinishTank1990Extensions
        lda     Player2Lives
        beq     TryShareLifeWithPlayer2
        cmp     #$02
        bcc     FinishTank1990Extensions
        lda     Player1Lives
        bne     FinishTank1990Extensions
        lda     Joy1Held
        and     #BUTTON_A
        beq     FinishTank1990Extensions
        inc     Player1Lives
        dec     Player2Lives
        ldx     #$00
        jmp     SpawnTank

TryShareLifeWithPlayer2:
LFEEF:  lda     Player1Lives
        cmp     #$02
        bcc     FinishTank1990Extensions
        lda     Joy2Held
        and     #BUTTON_A
        beq     FinishTank1990Extensions
        inc     Player2Lives
        dec     Player1Lives
        ldx     #$01
        jmp     SpawnTank

FinishTank1990Extensions:
LFF04:  rts

; Маршрутизация первой проверки TSA при движении.
; Вход: A — код TSA первой точки, TerrainObjectSlot — слот объекта. X на входе
; не используется. При ObjectSpecialState слота !=0 код $12 считается проходимым;
; в остальных случаях TSA<$20 блокирует движение, TSA>=$20 разрешает проверку
; второй точки. Хвостом уходит в ProbeSecondTankCorner либо
; HandleBlockedTankMovement и самостоятельно не возвращается. Портит A/X и флаги;
; Y сохраняется до выбранного обработчика.
RouteFirstTerrainProbe:
LFF05:  pha
        nop
        nop
        nop
        nop
        nop
        ldx     TerrainObjectSlot
        lda     ObjectSpecialState,x
        nop
        nop
        nop
        beq     RestoreFirstTerrainCode
        pla
        cmp     #$12
        bne     ClassifyFirstTerrainCode
AcceptFirstTerrainProbe:
LFF1A:  jmp     ProbeSecondTankCorner

RestoreFirstTerrainCode:
LFF1D:  pla
ClassifyFirstTerrainCode:
LFF1E:  cmp     #$20
        bcs     AcceptFirstTerrainProbe
        jmp     HandleBlockedTankMovement

; Парный RouteFirstTerrainProbe маршрутизатор второй проверки TSA.
; Контракт и классификация TSA те же, но разрешённый проход хвостом переходит в
; CommitProposedTankMovement. Не возвращается самостоятельно; портит A/X и флаги,
; Y сохраняется до выбранного обработчика.
RouteSecondTerrainProbe:
LFF25:  pha
        nop
        nop
        nop
        nop
        nop
        ldx     TerrainObjectSlot
        lda     ObjectSpecialState,x
        nop
        nop
        nop
        beq     RestoreSecondTerrainCode
        pla
        cmp     #$12
        bne     ClassifySecondTerrainCode
AcceptSecondTerrainProbe:
LFF3A:  jmp     CommitProposedTankMovement

RestoreSecondTerrainCode:
LFF3D:  pla
ClassifySecondTerrainCode:
LFF3E:  cmp     #$20
        bcs     AcceptSecondTerrainProbe
        jmp     HandleBlockedTankMovement

; Сбрасывает 16 байт состояния расширения $0170..$017F, затем вызывает
; InitializeCoreRuntime. После полной инициализации возвращает A=$FC, X=$1C, Y=0;
; почти вся рабочая RAM и состояние PPU/APU могут измениться.
ResetExtensionState:
LFF45:  lda     #$00
        ldx     #$0F
ClearNextExtensionStateByte:
LFF49:  sta     ObjectSpecialState,x
        dex
        bpl     ClearNextExtensionStateByte
        jsr     InitializeCoreRuntime
        rts

; Заполняет ObjectSpecialState+4..+7 и PlayerExtendedUpgrade значением A, затем вызывает
; InitializeCoreRuntime. Входные A/X/Y этой процедурой не сохраняются.
FillExtensionSlots4Through8:
LFF53:  sta     ObjectSpecialState+4
        sta     ObjectSpecialState+5
        sta     ObjectSpecialState+6
        sta     ObjectSpecialState+7
        sta     PlayerExtendedUpgrade
        jsr     InitializeCoreRuntime
        rts
