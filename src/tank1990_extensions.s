; Послекадровая логика и terrain-routing расширений Tank 1990 ($FEAD-$FF65).

ExtensionObjectSlot = $5A
TankExtensionMarkerTile       = $63
MinimumLivesForLifeTransfer   = 2
SpecialPassableTerrainTile    = $12
TankPassableTerrainCodeMin    = $20
ExtensionStateByteCount       = 16

; Послекадровый проход расширения Tank 1990.
; Для каждого слота 7..0 с ненулевым ObjectSpecialState,X рисует
; двухспрайтовую метку TankExtensionMarkerTile в координатах танка. Затем
; запускает integrity guard. В двухпользовательской игре игрок без жизней может
; нажать A и получить одну жизнь от партнёра, если у донора осталось хотя бы
; MinimumLivesForLifeTransfer; получатель немедленно появляется через SpawnTank.
; Портит A, X, Y, RenderAttributes, OamTile, ExtensionObjectSlot и рабочие поля
; вызываемых процедур; может изменить Player*Lives и поля появившегося танка.
; При передаче жизни хвостовой JMP в SpawnTank возвращает сразу caller-у этой
; процедуры; без передачи обычный выход оставляет ExtensionObjectSlot=$FF.
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
        lda     #TankExtensionMarkerTile
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
        cmp     #MinimumLivesForLifeTransfer
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
        cmp     #MinimumLivesForLifeTransfer
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
; Вход: A — код TSA первой точки, CurrentTankSlot — слот объекта. X на входе
; не используется. При ObjectSpecialState слота !=0
; SpecialPassableTerrainTile считается проходимым; в остальных случаях коды
; ниже TankPassableTerrainCodeMin блокируют движение, остальные разрешают
; проверку второй точки. Хвостом уходит в ProbeSecondTankCorner либо
; HandleBlockedTankMovement и самостоятельно не возвращается. Портит A/X и флаги;
; Y сохраняется до выбранного обработчика.
RouteFirstTerrainProbe:
LFF05:  pha
        nop
        nop
        nop
        nop
        nop
        ldx     CurrentTankSlot
        lda     ObjectSpecialState,x
        nop
        nop
        nop
        beq     RestoreFirstTerrainCode
        pla
        cmp     #SpecialPassableTerrainTile
        bne     ClassifyFirstTerrainCode
AcceptFirstTerrainProbe:
LFF1A:  jmp     ProbeSecondTankCorner

RestoreFirstTerrainCode:
LFF1D:  pla
ClassifyFirstTerrainCode:
LFF1E:  cmp     #TankPassableTerrainCodeMin
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
        ldx     CurrentTankSlot
        lda     ObjectSpecialState,x
        nop
        nop
        nop
        beq     RestoreSecondTerrainCode
        pla
        cmp     #SpecialPassableTerrainTile
        bne     ClassifySecondTerrainCode
AcceptSecondTerrainProbe:
LFF3A:  jmp     CommitProposedTankMovement

RestoreSecondTerrainCode:
LFF3D:  pla
ClassifySecondTerrainCode:
LFF3E:  cmp     #TankPassableTerrainCodeMin
        bcs     AcceptSecondTerrainProbe
        jmp     HandleBlockedTankMovement

; Сбрасывает ExtensionStateByteCount байтов $0170..$017F, включая восемь
; ObjectSpecialState и соседние PlayerExtendedUpgrade/неименованные байты, затем вызывает
; InitializeCoreRuntime. После полной инициализации возвращает A=$FC, X=$1C, Y=0;
; почти вся рабочая RAM и состояние PPU/APU могут измениться.
ResetExtensionState:
LFF45:  lda     #$00
        ldx     #(ExtensionStateByteCount-1)
ClearNextExtensionStateByte:
LFF49:  sta     ObjectSpecialState,x
        dex
        bpl     ClearNextExtensionStateByte
        jsr     InitializeCoreRuntime
        rts

; Заполняет хвост ObjectSpecialState+4..+7 и PlayerExtendedUpgrade первого
; игрока входным A, затем вызывает InitializeCoreRuntime. Инициализатор не
; очищает эти пять байтов. Входные A/X/Y не сохраняются; прочие побочные эффекты
; совпадают с InitializeCoreRuntime.
FillEnemyExtensionTailAndPlayer1ExtendedUpgrade:
LFF53:  sta     ObjectSpecialState+4
        sta     ObjectSpecialState+5
        sta     ObjectSpecialState+6
        sta     ObjectSpecialState+7
        sta     PlayerExtendedUpgrade
        jsr     InitializeCoreRuntime
        rts
