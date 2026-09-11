; Жизни, подписи, номер этапа и маркеры врагов HUD ($C7C8-$C8CF).

PlayerHudIndex = $5A
PlayerHudRowOffset = $00
; Перерисовывает HUD жизней. В single-player обходит только P1, в two-player/демо — P2 и P1.
; На экран выводит max(lives-1,0). Меняет PPU-очередь, ScratchPtr,
; $00/$39..$3B, PlayerHudIndex, TileTranslationOffset/DigitBlankMode; портит A/X/Y.
UpdateLivesHud:
LC7C8:  lda     #$01
        sta     PlayerHudIndex
        sta     DigitBlankMode
        lda     #$6E
        sta     TileTranslationOffset
        lda     #>LivesHudIconText
        sta     ScratchPtrHi
        lda     #<LivesHudIconText
        sta     ScratchPtrLo
        ldx     #$1D
        ldy     #$12
        jsr     QueueTileAtCoordinates
        lda     StageSetLength
        cmp     #$02
        beq     DrawSecondPlayerLivesIcon
        lda     MenuSelection
        bne     DrawSecondPlayerLivesIcon
        lda     #$00
        sta     PlayerHudIndex
        jmp     DrawNextPlayerLivesCount

DrawSecondPlayerLivesIcon:
LC7F2:  lda     #>LivesHudIconText
        sta     ScratchPtrHi
        lda     #<LivesHudIconText
        sta     ScratchPtrLo
        ldx     #$1D
        ldy     #$15
        jsr     QueueTileAtCoordinates
DrawNextPlayerLivesCount:
LC801:  ldx     PlayerHudIndex
        lda     Player1Lives,x
        sec
        sbc     #$01
        bpl     ConvertPlayerLivesCount
        lda     #$00
ConvertPlayerLivesCount:
LC80C:  jsr     ByteToDisplayDigits
        ldy     #$36
        ldx     #$19
        jsr     SelectVisibleDigits
        lda     PlayerHudIndex
        sta     PlayerHudRowOffset
        asl     a
        clc
        adc     PlayerHudRowOffset
        clc
        adc     #$12
        tay
        jsr     QueueTranslatedTileString
        dec     PlayerHudIndex
        bpl     DrawNextPlayerLivesCount
        lda     #$00
        sta     TileTranslationOffset
        sta     DigitBlankMode
        rts

; Рисует в HUD заголовки/иконки P1 и, если нужно, P2. Портит ScratchPtr, A, X, Y и PPU-очередь.
DrawPlayerHudLabels:
LC830:  lda     #>PlayerOneCompactMarker
        sta     ScratchPtrHi
        lda     #<PlayerOneCompactMarker
        sta     ScratchPtrLo
        ldx     #$1D
        ldy     #$11
        jsr     QueueTileAtCoordinates
        lda     StageSetLength
        cmp     #$02
        beq     DrawSecondPlayerHudLabel
        lda     MenuSelection
        beq     FinishPlayerHudLabels
DrawSecondPlayerHudLabel:
LC849:  lda     #>PlayerTwoCompactMarker
        sta     ScratchPtrHi
        lda     #<PlayerTwoCompactMarker
        sta     ScratchPtrLo
        ldx     #$1D
        ldy     #$14
        jsr     QueueTileAtCoordinates
FinishPlayerHudLabels:
LC858:  rts

; После vblank выводит в HUD маркер и десятичный StageNumber. Меняет PPU-очередь, ScratchPtr, $39..$3B/$60;
; портит A/X/Y и кадровые счётчики WaitForNextFrame.
DrawStageNumberHud:
LC859:  jsr     WaitForNextFrame
        lda     #>StageHudUpperTiles
        sta     ScratchPtrHi
        lda     #<StageHudUpperTiles
        sta     ScratchPtrLo
        ldx     #$1D
        ldy     #$17
        jsr     QueueTileAtCoordinates
        lda     #>StageHudLowerTiles
        sta     ScratchPtrHi
        lda     #<StageHudLowerTiles
        sta     ScratchPtrLo
        ldx     #$1D
        ldy     #$18
        jsr     QueueTileAtCoordinates
        lda     #$6E
        sta     TileTranslationOffset
        lda     StageNumber
        jsr     ByteToDisplayDigits
        ldy     #$36
        ldx     #$19
        jsr     SelectVisibleDigits
        ldy     #$19
        jsr     QueueTranslatedTileString
        lda     #$00
        sta     TileTranslationOffset
        rts

; Преобразует индекс A в HUD-координаты: X=$1D+(A&1), Y=3+(A>>1).
; Выход: A=Y=(вход>>1)+3, X — столбец. RAM не меняет.
EnemyMarkerIndexToHudCoordinates:
LC894:  pha
        and     #$01
        clc
        adc     #$1D
        tax
        pla
        lsr     a
        clc
        adc     #$03
        tay
        rts

; Рисует RemainingEnemyMarkerTiles для индекса A в правой HUD-сетке. Портит A/X/Y, ScratchPtr и PPU-очередь.
DrawRemainingEnemyMarker:
LC8A2:  jsr     EnemyMarkerIndexToHudCoordinates
        lda     #>RemainingEnemyMarkerTiles
        sta     ScratchPtrHi
        lda     #<RemainingEnemyMarkerTiles
        sta     ScratchPtrLo
        jsr     QueueTileAtCoordinates
        rts

; Заменяет HUD-маркер индекса A строкой $D36B. Портит A/X/Y, ScratchPtr и PPU-очередь.
ClearRemainingEnemyMarker:
LC8B1:  jsr     EnemyMarkerIndexToHudCoordinates
        lda     #>BlankTileText
        sta     ScratchPtrHi
        lda     #<BlankTileText
        sta     ScratchPtrLo
        jsr     QueueTileAtCoordinates
        rts

RemainingEnemyMarkerIndex = $5A
; Ставит десять HUD-маркеров с чётными индексами $12..0.
; Выход: RemainingEnemyMarkerIndex=$FE; портит A/X/Y, ScratchPtr и PPU-очередь.
InitializeRemainingEnemyMarkers:
LC8C0:  lda     #$12
        sta     RemainingEnemyMarkerIndex
DrawNextRemainingEnemyMarker:
LC8C4:  lda     RemainingEnemyMarkerIndex
        jsr     DrawRemainingEnemyMarker
        dec     RemainingEnemyMarkerIndex
        dec     RemainingEnemyMarkerIndex
        bpl     DrawNextRemainingEnemyMarker
        rts
