; Выбор, распаковка и отрисовка карты этапа ($EF76-$F021).
;
; Карта занимает 91 байт: 13 строк по 14 нибблов. Первые 13 нибблов каждой
; строки -- TSA-индексы поля 13x13, последний ниббл -- неиспользуемый заполнитель.

; Выбирает описатель набора по младшему нибблу $46, вычисляет адрес StageNumber
; и распаковывает поле 13x13 в shadow nametable через DrawMetatile.
; Вход: A=$FF включает специальный режим (StageNumber=$20, дескриптор 6); при ином A
; номер берётся из StageNumber, а дескриптор -- из $46 & $0F.
; Формула адреса точно сохраняет поведение ROM: для длины набора N от StageNumber
; многократно вычитается N; к base добавляются (2*wraps)%6 и 91*remainder.
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
LEF82:  lda     $46
        and     #$0F
LEF86:  sta     $8F
        asl     a
        clc
        adc     $8F
        tax
        lda     ClassicLevelSetDescriptors,x
        sta     ScratchPtrLo
        inx
        lda     ClassicLevelSetDescriptors,x
        sta     ScratchPtrHi
        inx
        lda     ClassicLevelSetDescriptors,x
        sta     $8F
        lda     #$00
        sta     $00
        lda     StageNumber
; $00 считает удвоенное число полных оборотов по набору; A остаётся в диапазоне 1..N.
NormalizeStageWithinSet:
LEFA4:  cmp     $8F
        bcc     LEFB3
        beq     LEFB3
        sec
        sbc     $8F
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
        lda     #$5B
        jsr     AddAToPointer
        jmp     LEFC2

; ScratchPtr теперь указывает на 91-байтную упакованную карту; AuxPtr сохраняет её для чтения.
BuildStageShadow:
LEFCE:  lda     #$00
        sta     $5A
        lda     ScratchPtrLo
        sta     AuxPtrLo
        lda     ScratchPtrHi
        sta     AuxPtrHi
        lda     #$10
        sta     $57
; Одна строка поля строится за кадр. X/Y идут от $10 до $D0 с шагом $10.
LEFDE:  jsr     WaitForNextFrame
        lda     #$10
        sta     $56
LEFE5:  lda     $5A
        lsr     a
        tay
        lda     $5A                ; Чётный индекс -- старший ниббл байта, нечётный -- младший.
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
LEFFC:  ldx     $56
        ldy     $57
        jsr     DrawMetatile
        lda     #$00
        sta     PpuBufferPos       ; DrawMetatile нужен здесь для shadow; его PPU-команды отбрасываются.
        inc     $5A                ; Пропуск ниббла-заполнителя после 13-го метатайла строки.
        lda     $56
        clc
        adc     #$10
        sta     $56
        cmp     #$E0
        bne     LEFE5
        inc     $5A
        lda     $57
        clc
        adc     #$10
        sta     $57
        cmp     #$E0
        bne     LEFDE
        rts
