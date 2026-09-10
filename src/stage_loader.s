; Выбор, распаковка и отрисовка карты этапа ($EF76-$F021).
;
; Карта занимает 91 байт: 13 строк по 14 нибблов. Первые 13 нибблов каждой
; строки -- TSA-индексы поля 13x13, последний ниббл -- неиспользуемый заполнитель.

StageSetSelector       = $8F
StageSetLength         = $8F
PackedStageNibbleIndex = $5A
StageDrawX             = $56
StageDrawY             = $57
PackedStageByteSize    = $5B

; Выбирает описатель набора по младшему нибблу $46, вычисляет адрес StageNumber
; и распаковывает поле 13x13 в shadow nametable через DrawMetatile.
; Вход: A=$FF включает специальный режим (StageNumber=$20, дескриптор 6); при ином A
; номер берётся из StageNumber, а дескриптор -- из $46 & $0F.
; Формула адреса точно сохраняет поведение ROM: для длины набора N от StageNumber
; многократно вычитается N; к base добавляются (2*wraps)%6 и
; 91*(normalizedStage-1).
; Побочно: меняет A/X/Y, ScratchPtr, AuxPtr, $00, $5A, $56/$57, $8F, shadow nametable,
; attribute shadow и временно PPU-очередь. После каждого метатайла PpuBufferPos сбрасывается:
; эта процедура строит shadow, а не передаёт всю карту в PPU.
LoadAndDrawStage:
LEF76:  cmp     #$FF
        bne     LEF82
        lda     #$20
        sta     StageNumber
        lda     #$06
        bne     LEF86
SelectStageSetDescriptor:
LEF82:  lda     GameVariant
        and     #$0F
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
        sta     $00
        lda     StageNumber
; $00 считает удвоенное число полных оборотов по набору; A остаётся в диапазоне 1..N.
NormalizeStageWithinSet:
LEFA4:  cmp     StageSetLength
        bcc     LEFB3
        beq     LEFB3
        sec
        sbc     StageSetLength
        inc     $00
        inc     $00
        bne     LEFA4
LEFB3:  pha
        jsr     RemainderBySix
        adc     ScratchPtrLo
        sta     ScratchPtrLo
        bcc     LEFBF
        inc     ScratchPtrHi
LEFBF:  pla
        sta     $00
LEFC2:  dec     $00
        beq     LEFCE
        lda     #PackedStageByteSize
        jsr     AddAToPointer
        jmp     LEFC2

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
LEFDE:  jsr     WaitForNextFrame
        lda     #$10
        sta     StageDrawX
LEFE5:  lda     PackedStageNibbleIndex
        lsr     a
        tay
        lda     PackedStageNibbleIndex ; Чётный индекс -- старший ниббл байта, нечётный -- младший.
        and     #$01
        beq     LEFF6
        lda     (AuxPtrLo),y
        and     #$0F
        jmp     LEFFC

LEFF6:  lda     (AuxPtrLo),y
        lsr     a
        lsr     a
        lsr     a
        lsr     a
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
        bne     LEFE5
        inc     PackedStageNibbleIndex
        lda     StageDrawY
        clc
        adc     #$10
        sta     StageDrawY
        cmp     #$E0
        bne     LEFDE
        rts
