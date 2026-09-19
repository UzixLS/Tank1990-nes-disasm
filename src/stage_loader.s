; Выбор, распаковка и отрисовка карты этапа ($EF76-$F021).
;
; Карта занимает 91 байт: 13 строк по 14 нибблов. Первые 13 нибблов каждой
; строки -- TSA-индексы поля 13x13, последний ниббл -- неиспользуемый заполнитель.

StageWrapOffset        = $00
PackedStageNibbleIndex = $5A
StageDrawX             = $56
StageDrawY             = $57

; StageSetSelector нужен только до чтения дескриптора. Затем тот же байт
; становится StageSetLength; эти два имени описывают непересекающиеся времена жизни.
; StageWrapOffset сначала считает 2*число полных оборотов по набору, затем хранит
; нормализованный номер карты для цикла прибавления PackedStageByteSize.

; Выбирает описатель набора по младшему нибблу $46, вычисляет адрес StageNumber
; и распаковывает поле 13x13 в shadow nametable через DrawMetatile.
; Вход: A=AttractStageLoadSentinel включает специальный режим
; (StageNumber=AttractMapStageNumber, descriptor AttractMapSetSelector); при ином A
; номер берётся из StageNumber, а дескриптор -- из $46 & $0F.
; Формула адреса точно сохраняет поведение ROM: для длины набора N от StageNumber
; многократно вычитается N; к base добавляются (2*wraps)%6 и
; 91*(normalizedStage-1).
; Побочно: меняет A/X/Y, ScratchPtr, AuxPtr, StageWrapOffset, PackedStageNibbleIndex,
; StageDrawX/Y, StageSetSelector/Length, shadow nametable,
; attribute shadow и временно PPU-очередь. После каждого метатайла PpuBufferPos сбрасывается:
; эта процедура строит shadow, а не передаёт всю карту в PPU.
LoadAndDrawStage:
LEF76:  cmp     #AttractStageLoadSentinel
        bne     SelectStageSetDescriptor
        lda     #AttractMapStageNumber
        sta     StageNumber
        lda     #AttractMapSetSelector
        bne     UseSelectedStageSet
SelectStageSetDescriptor:
LEF82:  lda     GameVariant
        and     #$0F
UseSelectedStageSet:
LEF86:  sta     StageSetSelector
        asl     a
        clc
        adc     StageSetSelector
        tax
        lda     ClassicLevelSetDescriptors,x
        sta     ScratchPtrLo
        inx
        lda     ClassicLevelSetDescriptors,x
        sta     ScratchPtrHi
        inx
        lda     ClassicLevelSetDescriptors,x
        sta     StageSetLength
        lda     #$00
        sta     StageWrapOffset
        lda     StageNumber
; StageWrapOffset считает удвоенное число полных оборотов; A остаётся в диапазоне 1..N.
NormalizeStageWithinSet:
LEFA4:  cmp     StageSetLength
        bcc     StageNumberNormalized
        beq     StageNumberNormalized
        sec
        sbc     StageSetLength
        inc     StageWrapOffset
        inc     StageWrapOffset
        bne     NormalizeStageWithinSet
StageNumberNormalized:
LEFB3:  pha
        jsr     RemainderBySix
        adc     ScratchPtrLo
        sta     ScratchPtrLo
        bcc     StageDataBaseAdjusted
        inc     ScratchPtrHi
StageDataBaseAdjusted:
LEFBF:  pla
        sta     StageWrapOffset
; Продвигает ScratchPtr на StageWrapOffset-1 записей по 91 байту.
; Вход: StageWrapOffset>=1; выход: указатель выбранной карты, A изменён.
AdvanceToSelectedStage:
LEFC2:  dec     StageWrapOffset
        beq     BuildStageShadow
        lda     #PackedStageByteSize
        jsr     AddAToPointer
        jmp     AdvanceToSelectedStage

; ScratchPtr теперь указывает на 91-байтную упакованную карту; AuxPtr сохраняет её для чтения.
BuildStageShadow:
LEFCE:  lda     #$00
        sta     PackedStageNibbleIndex
        lda     ScratchPtrLo
        sta     AuxPtrLo
        lda     ScratchPtrHi
        sta     AuxPtrHi
        lda     #$10
        sta     StageDrawY
; Одна строка поля строится за кадр. X/Y идут от $10 до $D0 с шагом $10.
BeginStageRow:
LEFDE:  jsr     WaitForNextFrame
        lda     #$10
        sta     StageDrawX
DecodeNextStageMetatile:
LEFE5:  lda     PackedStageNibbleIndex
        lsr     a
        tay
        lda     PackedStageNibbleIndex ; Чётный индекс -- старший ниббл байта, нечётный -- младший.
        and     #$01
        beq     ExtractHighStageNibble
        lda     (AuxPtrLo),y
        and     #$0F
        jmp     DrawDecodedStageMetatile

ExtractHighStageNibble:
LEFF6:  lda     (AuxPtrLo),y
        lsr     a
        lsr     a
        lsr     a
        lsr     a
; Общий хвост половин байта: A=индекс TSA, StageDrawX/Y=позиция.
; Обновляет shadow через DrawMetatile и намеренно отбрасывает PPU-команды.
DrawDecodedStageMetatile:
LEFFC:  ldx     StageDrawX
        ldy     StageDrawY
        jsr     DrawMetatile
        lda     #$00
        sta     PpuBufferPos       ; DrawMetatile нужен здесь для shadow; его PPU-команды отбрасываются.
        inc     PackedStageNibbleIndex ; Пропуск ниббла-заполнителя после 13-го метатайла строки.
        lda     StageDrawX
        clc
        adc     #$10
        sta     StageDrawX
        cmp     #$E0
        bne     DecodeNextStageMetatile
        inc     PackedStageNibbleIndex
        lda     StageDrawY
        clc
        adc     #$10
        sta     StageDrawY
        cmp     #$E0
        bne     BeginStageRow
        rts
