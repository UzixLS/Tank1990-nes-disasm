; Очереди строк и шторка перехода экрана ($CC27-$CCD3).

CurtainRowIndex      = $57
NametableRowFillTile = $63

PrimaryNametableAttributePpuAddress = $23C0
NametableAttributeByteCount    = $40
NametableRowTileCount          = $20
NametableLastVisibleRow        = $1D
NametableCurtainPairCount      = $10
NametableCurtainTile           = $11
NametableRowQueueByteCount     = $23
NametableCurtainQueueByteCount = $46

; За 64 ожидания формирует команды [$23,$C0+i,attribute_i,$FF] для всего
; NametableAttributes=$07C0..$07FF. Первый WaitForNextFrame сначала исполняет
; ранее накопленную очередь; каждый следующий — предыдущую 4-byte команду.
; Последняя команда [$23,$FF,shadow[$07FF],$FF] остаётся до следующего NMI.
; Адрес всегда относится к primary nametable и не зависит от
; NametablePpuOffset. Shadow только читается; data=$FF корректно экранируется
; соседним command terminator.
;
; Вход: включённый NMI с обычным handler; он должен менять FrameCounter и
; flush-ить PPU queue. Выход: ScratchPtr=$2400, A=0, X=PpuBufferPos=4, Y=$40,
; N=0/Z=C=1/V=0. Меняет ScratchPtr, PPU queue и через 64 NMI — VRAM attributes,
; OAM/input/audio/palette/frame state; tile shadow и OAM напрямую не меняет.
UploadAttributesGradually:
LCC27:  ldy     #$00
        lda     #>PrimaryNametableAttributePpuAddress
        sta     ScratchPtrHi
        lda     #<PrimaryNametableAttributePpuAddress
        sta     ScratchPtrLo
UploadNextAttributeByte:
LCC31:  jsr     WaitForNextFrame
        ldx     PpuBufferPos
        lda     ScratchPtrHi
        sta     PpuUpdateBuffer,x
        inx
        lda     ScratchPtrLo
        sta     PpuUpdateBuffer,x
        inx
        lda     NametableAttributes,y
        iny
        sta     PpuUpdateBuffer,x
        inx
        lda     #$FF
        sta     PpuUpdateBuffer,x
        inx
        stx     PpuBufferPos
        lda     #$01
        jsr     AddAToPointer
        cpy     #NametableAttributeByteCount
        bne     UploadNextAttributeByte
        rts

; Ставит в PPU-очередь полную 32-тайловую строку как
; [addr_hi,addr_lo,32 data bytes,$FF], всего 35 bytes.
; Вход: Y — номер строки; если NametableRowFillTile=0, данные берутся из
; shadow, иначе вся строка заполняется этим тайлом (поэтому заполнить строку
; константой 0 через этот интерфейс нельзя). Y=0..29 адресует tile rows;
; 30/31 уже читают attribute storage как 32 data bytes. X-coordinate всегда 0,
; адрес назначения $2000+32*Y относится к primary nametable и не зависит от
; NametablePpuOffset. При чтении shadow нет escaping: run из tile $FF внутри
; строки, после которого идёт не-$FF, нарушит command stream; trailing run
; корректен благодаря terminator, как и заполнение всей строки tile $FF.
;
; Требуются PpuBufferPos<=$5C (35 bytes плюс NMI lookahead) и отсутствие NMI
; во время построения. Выход: A=$FF, Y=$20,
; X=PpuBufferPos=old+NametableRowQueueByteCount, ScratchPtr указывает начало
; строки, PpuTileRowBits=(input Y&7)*32; flags соответствуют финальному INX.
; Меняет ScratchPtr, scratch $00 и PPU update buffer; shadow, PPU registers,
; OAM и audio не меняет. Bounds/capacity кодом не проверяются.
QueueNametableRow:
LCC5C:  ldx     #$00
        jsr     TileCoordinatesToShadowAddress
        sta     ScratchPtrHi
        sty     ScratchPtrLo
        ldx     PpuBufferPos
        lda     ScratchPtrHi
        clc
        adc     #ShadowToPrimaryNametableOffset
        sta     PpuUpdateBuffer,x
        inx
        lda     ScratchPtrLo
        sta     PpuUpdateBuffer,x
        inx
        ldy     #$00
QueueNextNametableTile:
LCC78:  lda     NametableRowFillTile
        bne     StoreNametableTile
        lda     (ScratchPtrLo),y
StoreNametableTile:
LCC7E:  sta     PpuUpdateBuffer,x
        inx
        iny
        cpy     #NametableRowTileCount
        bne     QueueNextNametableTile
        lda     #$FF
        sta     PpuUpdateBuffer,x
        inx
        stx     PpuBufferPos
        rts

; Шторка перед выбором этапа: за 16 кадров ставит в очередь парные строки,
; заполненные тайлом $11, двигаясь от краёв 0/29 к центру. Строки 14/15
; ставятся дважды на последних двух итерациях. Последняя пара остаётся в очереди
; до следующего NMI. Каждый Wait сначала flush-ит предыдущие 70 bytes, поэтому
; после него обе новые команды безопасно строятся с позиции 0. Это временная
; VRAM-маска: shadow не меняется и затем служит источником OpenNametableCurtain.
; Вход: включённый обычный NMI/FrameCounter; PPU_CTRL increment=1.
; Выход: CurtainRowIndex=$10, NametableRowFillTile=$11, A=$10, X=PpuBufferPos=$46,
; Y=$20, ScratchPtr=$05C0, PpuTileRowBits=$C0, Z=C=1/N=0. Портит A/X/Y,
; ScratchPtr, aliases $57/$63 и PPU queue; через ожидания меняет PPU/OAM/input/
; audio/palette/frame state. Последняя пара VRAM ещё не применена.
CloseNametableCurtain:
LCC90:  lda     #NametableCurtainTile
        sta     NametableRowFillTile
        lda     #$00
        sta     CurtainRowIndex
CloseCurtainNextRowPair:
LCC98:  jsr     WaitForNextFrame
        ldy     CurtainRowIndex
        jsr     QueueNametableRow
        lda     #NametableLastVisibleRow
        sec
        sbc     CurtainRowIndex
        tay
        jsr     QueueNametableRow
        inc     CurtainRowIndex
        lda     CurtainRowIndex
        cmp     #NametableCurtainPairCount
        bne     CloseCurtainNextRowPair
        rts

; Обратная шторка: восстанавливает пары строк из shadow, двигаясь от центра
; к краям. Центральная пара при первых двух проходах записывается дважды.
; Последняя пара остаётся в очереди до следующего NMI. Выход:
; CurtainRowIndex=$FF, NametableRowFillTile=0, A=$FF, X=PpuBufferPos=$46,
; Y=$20, ScratchPtr=$07A0, PpuTileRowBits=$A0, Z=C=1/N=0. Preconditions и
; косвенные NMI-side effects совпадают с CloseNametableCurtain. Shadow не
; меняется; его rows должны удовлетворять ограничению QueueNametableRow на
; внутренние runs tile $FF. Последняя восстановленная пара ещё не применена.
OpenNametableCurtain:
LCCB2:  lda     #$00
        sta     NametableRowFillTile
        lda     #(NametableCurtainPairCount-1)
        sta     CurtainRowIndex
OpenCurtainNextRowPair:
LCCBA:  jsr     WaitForNextFrame
        ldy     CurtainRowIndex
        jsr     QueueNametableRow
        lda     #NametableLastVisibleRow
        sec
        sbc     CurtainRowIndex
        tay
        jsr     QueueNametableRow
        dec     CurtainRowIndex
        lda     CurtainRowIndex
        cmp     #$FF
        bne     OpenCurtainNextRowPair
        rts
