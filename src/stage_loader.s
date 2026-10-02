; Выбор, распаковка и отрисовка карты этапа ($EF76-$F021).
;
; Карта занимает 91 байт: 13 строк по 14 нибблов. Первые 13 нибблов каждой
; строки -- TSA-индексы поля 13x13, последний ниббл -- неиспользуемый заполнитель.

StageWrapOffset        = $00
PackedStageNibbleIndex = $5A
StageDrawX             = $56
StageDrawY             = $57

PackedStageNibblesPerRow       = PackedStageRowSize * 2
PackedStageLowNibbleSelectMask = $01
PackedStageTsaIndexMask        = $0F
StageFirstMetatilePixel        = $10
StageMetatilePixelStep         = $10
StagePastLastMetatilePixel     = $E0
PackedStageNibbleCount          = StageHeightMetatiles * PackedStageNibblesPerRow

; StageSetSelector нужен только до чтения дескриптора. Затем тот же байт
; становится StageSetLength; эти два имени описывают непересекающиеся времена жизни.
; StageWrapOffset сначала считает 2*число полных оборотов по набору, затем хранит
; нормализованный номер карты для цикла прибавления PackedStageByteSize. После
; начала DrawMetatile тот же $00 уже является PpuTileRowBits, а не wrap state.

; Выбирает описатель набора по младшему нибблу $46, вычисляет адрес StageNumber
; и распаковывает поле 13x13 в shadow nametable через DrawMetatile.
; Вход: A=AttractStageLoadSentinel включает специальный режим
; (StageNumber=AttractMapStageNumber, descriptor AttractMapSetSelector); при ином A
; номер берётся из StageNumber, а дескриптор -- из $46 & $0F.
; Допустимы selector 0..6 и StageNumber>=1; bounds checks нет. Любой другой
; selector читает pointer/length за ClassicLevelSetDescriptors. StageNumber=0
; нормализуется в 0, затем DEC даёт $FF и выполняются 255 шагов по 91 byte.
; Нулевая длина descriptor-а делает до 128 бесполезных итераций SBC #0 и может
; продолжить с произвольным указателем/номером.
;
; Для descriptor length N и stage S>=1 число вычитаний
; wraps=floor((S-1)/N), normalized=((S-1) mod N)+1. Реальная формула pointer:
;   base + ((2*wraps) mod 6) + 91*(normalized-1).
; Код хранит 2*wraps в восьмибитном $00 и лишь затем берёт mod 6; при штатных
; N=12/36 и S<=255 переполнения нет. Фазовый +2/+4 сдвигает начало внутрь packed
; stream: это не простое повторение карты, и окно последней записи может читать
; до четырёх bytes сразу после номинального ClassicLevels catalog.
;
; Декодирует high nibble, затем low; после 13-го high nibble седьмого byte
; low padding пропускается. 13 NMI — по одному перед каждой строкой — обслуживают
; OAM/input/audio/frame counters. Первый также исполняет входную PPU queue.
; Каждый DrawMetatile создаёт 20-byte primary-nametable queue, но cursor сразу
; обнуляется: PPU-команды карты намеренно отбрасываются, остаются только shadow
; tiles/attributes. NMI не должен прервать отдельный DrawMetatile до немедленного
; сброса cursor; штатно вся строка успевает до следующего кадрового NMI.
;
; Выход: A=StageDrawX=StageDrawY=$E0, Y=0,
; X=4*bottom-right TSA index+4 (4..64), N=0/Z=1/C=1/V=0;
; PackedStageNibbleIndex=PackedStageNibbleCount=$B6, PpuBufferPos=0,
; AuxPtr=вычисленный map pointer, ScratchPtr=$077B, $00/PpuTileRowBits=$40.
; StageSetLength=N; StageNumber сохраняется, кроме sentinel-path, где он=$20.
; Меняет raster/address/metatile scratch, RenderAttributes, 26x26 tile field и
; его attribute shadow; PPU VRAM карты напрямую не обновляет. Физические bytes
; последней отброшенной команды остаются в PpuUpdateBuffer при cursor=0.
LoadAndDrawStage:
LEF76:  cmp     #AttractStageLoadSentinel
        bne     SelectStageSetDescriptor
        lda     #AttractMapStageNumber
        sta     StageNumber
        lda     #AttractMapSetSelector
        bne     UseSelectedStageSet
SelectStageSetDescriptor:
LEF82:  lda     GameVariant
        and     #GameVariantIndexMask
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
; StageWrapOffset считает удвоенное число полных оборотов; при валидном S
; A остаётся в диапазоне 1..N.
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

; ScratchPtr теперь указывает на начало 91-byte окна; AuxPtr сохраняет его,
; пока ScratchPtr будет переиспользован DrawMetatile для nametable shadow.
BuildStageShadow:
LEFCE:  lda     #$00
        sta     PackedStageNibbleIndex
        lda     ScratchPtrLo
        sta     AuxPtrLo
        lda     ScratchPtrHi
        sta     AuxPtrHi
        lda     #StageFirstMetatilePixel
        sta     StageDrawY
; Одна строка поля строится за кадр. X/Y идут от $10 до $D0 с шагом $10;
; DrawMetatile выравнивает эти centers в tile rows/columns 2..27.
BeginStageRow:
LEFDE:  jsr     WaitForNextFrame
        lda     #StageFirstMetatilePixel
        sta     StageDrawX
DecodeNextStageMetatile:
LEFE5:  lda     PackedStageNibbleIndex
        lsr     a
        tay
        lda     PackedStageNibbleIndex ; Чётный индекс -- старший ниббл байта, нечётный -- младший.
        and     #PackedStageLowNibbleSelectMask
        beq     ExtractHighStageNibble
        lda     (AuxPtrLo),y
        and     #PackedStageTsaIndexMask
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
        inc     PackedStageNibbleIndex ; Следующий nibble; после 13-го это low padding.
        lda     StageDrawX
        clc
        adc     #StageMetatilePixelStep
        sta     StageDrawX
        cmp     #StagePastLastMetatilePixel
        bne     DecodeNextStageMetatile
        inc     PackedStageNibbleIndex ; Пропустить low padding и перейти к high nibble следующей строки.
        lda     StageDrawY
        clc
        adc     #StageMetatilePixelStep
        sta     StageDrawY
        cmp     #StagePastLastMetatilePixel
        bne     BeginStageRow
        rts
