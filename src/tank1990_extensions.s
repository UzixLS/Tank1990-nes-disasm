; Послекадровая логика и terrain-routing расширений Tank 1990 ($FEAD-$FF65).

ExtensionRenderSlot              = $5A
SpecialStateMarkerLeftTile       = $63
MinimumLivesForLifeTransfer      = 2
SpecialStatePassableShadowCode   = $12
TankPassableShadowCodeMin        = $20
ExtensionStateResetByteCount     = 16

; Послекадровый проход расширения Tank 1990.
;
; Сначала обходит танковые слоты 7..0. Любое ненулевое
; ObjectSpecialState,X добавляет две 8x16 OAM entries с тайлами $63/$65:
; в (ObjectX-8,ObjectY-8) и (ObjectX,ObjectY-8) аппаратных координат.
; Начальные attributes равны номеру слота 0..7: hardware palette=slot&3,
; а bit2 игнорируется PPU. Для terrain-priority emitter пробует точки
; ObjectX-5/ObjectY и ObjectX+3/ObjectY. Над точным shadow-code $22 он
; sticky-OR-ит SpriteBehindTerrainMask в RenderAttributes: если маску получила
; левая entry, правая наследует её. Проверки
; ObjectState нет: stale special-state неактивного слота тоже рисуется
; по stale ObjectX/Y. В худшем случае нужно 16 свободных OAM entries;
; clipping/capacity здесь нет.
;
; После рендера вызывает RunDeferredIntegrityGuard. Если guard вернулся,
; любой ненулевой MenuSelection включает асимметричную передачу жизни:
;   * пока Player2Lives!=0, проверяется только мёртвый P1; его held A
;     забирает жизнь у P2, если у P2 было не менее двух;
;   * только при Player2Lives==0 проверяется held A мёртвого P2 и
;     возможность забрать жизнь у P1.
; Проверяются Joy*Held, а не Joy*Pressed: удерживаемая заранее A
; срабатывает на первом подходящем tick. Донор с MinimumLivesForLifeTransfer
; после декремента сохраняет хотя бы одну жизнь.
;
; Без передачи: ExtensionRenderSlot=$FF; A и flags зависят от ветви,
; X/Y и рабочие поля не определены после OAM/guard. При передаче X=slot
; получателя и хвостовой JMP в SpawnTank использует исходный return address:
; его RTS возвращает caller-у UpdateTank1990Extensions. SpawnTank сразу
; меняет object/spawn-cell и добавляет 20 байт в PPU queue; caller обязан
; оставить ей место. В обоих случаях A/X/Y и scratch не сохраняются.
UpdateTank1990Extensions:
LFEAD:  lda     #(TankSlotCount-1)
        sta     ExtensionRenderSlot
DrawNextTankExtension:
LFEB1:  ldx     ExtensionRenderSlot
        lda     ObjectSpecialState,x
        nop
        nop
        beq     AdvanceExtensionRenderSlot
        txa
        sta     RenderAttributes
        ldy     ObjectY,x
        lda     ObjectX,x
        tax
        lda     #SpecialStateMarkerLeftTile
        sta     OamTile
        jsr     EmitTwoTileOamPair
AdvanceExtensionRenderSlot:
LFEC9:  dec     ExtensionRenderSlot
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
        ldx     #Player1TankSlot
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
        ldx     #Player2TankSlot
        jmp     SpawnTank

FinishTank1990Extensions:
LFF04:  rts

; Маршрутизация первой shadow-пробы при движении танка.
; Вход: A=ненулевой код terrain shadow без occupancy bit7;
; CurrentTankSlot=слот 0..7. X на входе не используется. Штатный caller
; отдельно обрабатывает A=0 и bit7; прямой вызов без этого предусловия
; ошибочно сочтёт любой код >=$80 проходимым.
;
; При ObjectSpecialState[CurrentTankSlot]!=0 дополнительно проходим точно
; SpecialStatePassableShadowCode. Все остальные коды, в том числе при
; special-state, классифицируются порогом: <$20 блокирует, >=$20
; разрешает переход к ProbeSecondTankCorner. Специальное состояние
; не снимает блокировку с других кодов <$20.
;
; Это tail-dispatch: один PHA всегда уравновешивается одним PLA до JMP,
; поэтому цели видят на стеке исходный return address. На входе в цель:
; A=исходный shadow-code, X=CurrentTankSlot, Y сохранён; флаги от
; CMP #$12 для special-pass или CMP #$20 для обычной классификации.
; Восемь NOP — сохранённая цикловая набивка. От входа до цели,
; включая трёхтактовый JMP: 39 cycles для
; special-pass, 40/41 для обычной block/pass без special-state, 44/45 для
; обычной block/pass при special-state (без page-cross branch penalty).
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
        beq     RestoreFirstProbeShadowCode
        pla
        cmp     #SpecialStatePassableShadowCode
        bne     ClassifyFirstProbeShadowCode
AcceptFirstShadowProbe:
LFF1A:  jmp     ProbeSecondTankCorner

RestoreFirstProbeShadowCode:
LFF1D:  pla
ClassifyFirstProbeShadowCode:
LFF1E:  cmp     #TankPassableShadowCodeMin
        bcs     AcceptFirstShadowProbe
        jmp     HandleBlockedTankMovement

; Парный tail-dispatch второй shadow-пробы. Вход, классификация,
; такты, stack balance и A/X/Y/flags те же, что у RouteFirstTerrainProbe.
; Pass-ветвь вместо второй пробы хвостом фиксирует ProposedTankX/Y через
; CommitProposedTankMovement; block-ветвь идёт в HandleBlockedTankMovement.
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
        beq     RestoreSecondProbeShadowCode
        pla
        cmp     #SpecialStatePassableShadowCode
        bne     ClassifySecondProbeShadowCode
AcceptSecondShadowProbe:
LFF3A:  jmp     CommitProposedTankMovement

RestoreSecondProbeShadowCode:
LFF3D:  pla
ClassifySecondProbeShadowCode:
LFF3E:  cmp     #TankPassableShadowCodeMin
        bcs     AcceptSecondShadowProbe
        jmp     HandleBlockedTankMovement

; RESET-entry для extension-диапазона. Точно обнуляет 16 байтов
; $0170..$017F: ObjectSpecialState[0..7], PlayerExtendedUpgrade[0..1] и шесть
; пока неименованных $017A..$017F. Следующий байт $0180 уже является
; PpuUpdateBuffer, поэтому romhack не может просто увеличить byte count.
;
; Затем обычным JSR вызывает InitializeCoreRuntime. Его precondition:
; rendering/NMI выключены, PPU доступен для прямых uploads. Выход:
; A=$FC, X=$1C, Y=0, N=0/Z=1/C=1/V=0; PPU/APU, nametable/OAM shadow,
; audio state, score records и перечисленная InitializeCoreRuntime RAM изменены.
ResetExtensionState:
LFF45:  lda     #$00
        ldx     #(ExtensionStateResetByteCount-1)
ClearNextExtensionResetByte:
LFF49:  sta     ObjectSpecialState,x
        dex
        bpl     ClearNextExtensionResetByte
        jsr     InitializeCoreRuntime
        rts

; Заполняет входным A ровно пять байтов: special-state слотов
; 4..7 ($0174..$0177) и только PlayerExtendedUpgrade[0] ($0178). Слоты
; 4..7 — хвост штатного enemy-диапазона, но слоты 2/3 здесь не трогаются;
; PlayerExtendedUpgrade[1] ($0179) тоже сохраняется.
;
; Затем вызывает InitializeCoreRuntime, который эти пять байтов не
; очищает. Его PPU/NMI precondition, выходные A/X/Y/flags и все side effects
; совпадают с описанными для ResetExtensionState. Статических ссылок нет;
; это не обычный gameplay helper, а альтернативный init-entry.
FillExtensionSlots4To7AndPlayer1UpgradeBeforeRuntimeInit:
FillEnemyExtensionTailAndPlayer1ExtendedUpgrade:
LFF53:  sta     ObjectSpecialState+4
        sta     ObjectSpecialState+5
        sta     ObjectSpecialState+6
        sta     ObjectSpecialState+7
        sta     PlayerExtendedUpgrade
        jsr     InitializeCoreRuntime
        rts
