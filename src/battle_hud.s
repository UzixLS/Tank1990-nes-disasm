; Обновление номера этапа на экране выбора ($CA91-$CAF4).

StageSelectionLabelColumn       = $0C
StageSelectionLabelRow          = $0E
StageSelectionDigitFieldColumn  = $0E
StageSelectionDecimalTileBias   = $6E
StageSelectionLabelTile0        = $23
StageSelectionLabelTile1        = $24
StageSelectionLabelTile2        = $25
StageSelectionLabelTile3        = $26
StageSelectionLabelTile4        = $27
StageSelectionLabelPaddingTile  = $11

; Обновляет номер на экране выбора этапа. WaitForNextFrame сначала даёт NMI
; исполнить прежнюю PPU-очередь и обнулить PpuBufferPos. Затем процедура ставит
; новую десятибайтовую команду из семи фиксированных тайлов и команду из 1..3
; десятичных цифр длиной 4..6 байт. Обе команды обходят nametable shadow и будут
; исполнены только следующим NMI.
; Вход: NMI включён; StageNumber=1..ExtendedStageUpperBound;
; NametablePpuOffset=ShadowToPrimaryNametableOffset. При ненулевом StageNumber
; SelectVisibleDigits не читает DigitBlankMode.
; После ожидания буфер пуст, поэтому для максимум 16 байт команд и lookahead,
; который NMI запишет по итоговому PpuBufferPos, место гарантировано.
; Выход: A=0, X=PpuBufferPos=14..16, Y=число цифр 1..3;
; TileTranslationOffset=0. Меняет PpuTileRowBits, ScratchPtr,
; ByteToDecimalInput, ScoreIncrementDigits/decimal scratch и PpuUpdateBuffer.
; PPU registers и nametable shadow напрямую не меняет. Обслуживший ожидание NMI
; также обновляет OAM, input, audio и кадровые счётчики.
UpdateStageNumberDisplay:
LCA91:  jsr     WaitForNextFrame
        ldx     #StageSelectionLabelColumn
        ldy     #StageSelectionLabelRow
        jsr     TileCoordinatesToShadowAddress
        ldx     PpuBufferPos
        clc
        adc     #ShadowToPrimaryNametableOffset
        sta     PpuUpdateBuffer,x
        inx
        tya
        sta     PpuUpdateBuffer,x
        inx
        lda     #StageSelectionLabelTile0
        sta     PpuUpdateBuffer,x
        inx
        lda     #StageSelectionLabelTile1
        sta     PpuUpdateBuffer,x
        inx
        lda     #StageSelectionLabelTile2
        sta     PpuUpdateBuffer,x
        inx
        lda     #StageSelectionLabelTile3
        sta     PpuUpdateBuffer,x
        inx
        lda     #StageSelectionLabelTile4
        sta     PpuUpdateBuffer,x
        inx
        lda     #StageSelectionLabelPaddingTile
        sta     PpuUpdateBuffer,x
        inx
        lda     #StageSelectionLabelPaddingTile
        sta     PpuUpdateBuffer,x
        inx
        lda     #PpuQueueTerminator
        sta     PpuUpdateBuffer,x
        inx
        stx     PpuBufferPos
        lda     #StageSelectionDecimalTileBias
        sta     TileTranslationOffset
        lda     StageNumber
        jsr     ByteToDisplayDigits
        ldy     #(ScoreIncrementDigits+1)
        ldx     #StageSelectionDigitFieldColumn
        jsr     SelectVisibleDigits
        ldy     #StageSelectionLabelRow
        jsr     QueueTranslatedTileString
        lda     #$00
        sta     TileTranslationOffset
        rts
