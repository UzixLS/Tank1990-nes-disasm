; Построение shadow OAM ($DA2B-$DAAE).
; Файл включается из ppu.s в исходной позиции, чтобы сохранять адреса ROM.

OamSavedX = $47
OamSavedY = $48
OamPairX  = $54
OamPairY  = $55

OamEntrySize         = $04
OamHiddenY           = $F0
OamHardwareYBias     = $08
OamTerrainProbeXBias = $03
OamDirectionalXBias  = $05
OamPairLeftXBias      = $08
OamPriorityTerrainTile = $22

; Добавляет одну hardware OAM entry; при штатном PPU_CTRL=$B0 это sprite 8x16.
; Вход: X/Y — логическая опорная позиция, OamTile — tile, RenderAttributes —
; attributes, SpriteBehindTerrainMask — добавочные attribute bits над специальным
; terrain tile $22. Для terrain-проверки используется pixel (X+3,Y), тогда как
; в OAM пишется (Y-8, tile, attributes, X).
;
; Если проверенный shadow byte точно равен $22, маска OR-ится прямо в
; RenderAttributes и остаётся там после возврата; последующие sprites caller-а
; наследуют эти bits, пока он явно не перезапишет attributes. Иные terrain codes,
; включая occupancy-marked $A2, маску не добавляют.
;
; Выход: A=новый OamBufferPos, X=старый OamBufferPos, Y=0, N/Z/C/V от сложения
; cursor+OamBufferStep. OamTile и SpriteBehindTerrainMask сохранены. Меняет
; OamSavedX/Y, ScratchPtr, PpuTileRowBits, OamBufferPos, четыре байта выбранной
; OAM entry и условно RenderAttributes; PPU queue/registers не трогает.
; Clipping/capacity нет: X+3 оборачивается, а Y=240..255 пробует attribute
; storage $07C0..$07FF как будто это terrain. Caller обязан оставить свободную
; entry и держать cursor/step выровненными по четыре байта.
EmitOamSprite:
LDA2B:  txa
        sta     OamSavedX
        clc
        adc     #OamTerrainProbeXBias
        tax
        tya
        sec
        sbc     #OamHardwareYBias
        sta     OamSavedY
        jsr     PixelCoordinatesToShadowPointer
        lda     (ScratchPtrLo),y
        cmp     #OamPriorityTerrainTile
        bne     StoreOamEntry
        lda     RenderAttributes
        ora     SpriteBehindTerrainMask
        sta     RenderAttributes
StoreOamEntry:
LDA47:  ldx     OamBufferPos
        lda     OamSavedY
        sta     OamShadow,x
        lda     OamTile
        sta     OamShadow+1,x
        lda     RenderAttributes
        sta     OamShadow+2,x
        lda     OamSavedX
        sta     OamShadow+3,x
        txa
        clc
        adc     OamBufferStep
        sta     OamBufferPos
        rts

; Выбирает tile=(OamTile+2*A)&$FF, сдвигает X на -5 modulo 256 и выводит одну
; OAM entry. A не маскируется; таблицу кадров задаёт caller. Входы/выходы и
; побочные эффекты после преобразования совпадают с EmitOamSprite; OamTile
; остаётся выбранным tile, исходная координата X не восстанавливается.
EmitDirectionalOamSprite:
LDA64:  asl     a
        clc
        adc     OamTile
        sta     OamTile
        txa
        sec
        sbc     #OamDirectionalXBias
        tax
        jsr     EmitOamSprite
        rts

; Выбирает двухтайловый кадр base=(OamTile+8*A)&$FF и выводит две соседние
; hardware entries в X-8 и X с tiles base/base+2. Вход: A — номер кадра без
; bounds-check, X/Y — опорная позиция;
; OamTile/RenderAttributes/SpriteBehindTerrainMask как у EmitOamSprite.
; Сохраняет исходные X/Y в OamPairX/Y, но по выходу регистры принадлежат второму
; EmitOamSprite: A=новый cursor, X=позиция второй OAM entry, Y=0. Дважды
; применяются terrain probe и sticky RenderAttributes. По выходу OamTile=base+2,
; OamBufferPos продвинут на 2*OamBufferStep; PPU/объектную RAM не меняет.
EmitTwoTileOamObject:
LDA73:  asl     a
        asl     a
        asl     a
        clc
        adc     OamTile
        sta     OamTile
; Альтернативный вход: OamTile уже содержит tile-base, X/Y -- позицию пары.
EmitTwoTileOamPair:
LDA7B:  stx     OamPairX
        sty     OamPairY
        txa
        sec
        sbc     #OamPairLeftXBias
        tax
        jsr     EmitOamSprite
        inc     OamTile
        inc     OamTile
        ldx     OamPairX
        ldy     OamPairY
        jsr     EmitOamSprite
        rts

; Завершает следующий OAM shadow после того, как NMI уже передал предыдущий.
; Сначала меняет знак OamBufferStep, затем по новому направлению пишет Y=$F0
; во все неиспользованные entries от следующей за OamBufferPos до offset $04
; включительно. Entry offset $00 не является общей точкой остановки и в
; зависимости от направления также может быть скрыта. Чередование порядка
; выдачи слотов меняет hardware sprite priority между кадрами.
; Вход: OamBufferStep строго +4/$04 либо -4/$FC, OamBufferPos кратен четырём;
; иначе loop может не завершиться либо скрыть неверные bytes.
; Выход: OamBufferPos=OamEntrySize, OamBufferStep=-OamBufferStep;
; A=OamHiddenY, X=OamEntrySize, Y сохранён. Меняет только Y-байты
; неиспользованных OAM entries; аппаратный OAM/PPU не трогает.
FinishAlternatingOamFrame:
LDA93:  ldx     OamBufferPos
        lda     OamBufferStep
        eor     #$FF
        clc
        adc     #$01
        sta     OamBufferStep
HideNextUnusedOamEntry:
LDA9E:  txa
        clc
        adc     OamBufferStep
        tax
        lda     #OamHiddenY
        sta     OamShadow,x
        cpx     #OamEntrySize
        bne     HideNextUnusedOamEntry
        stx     OamBufferPos
        rts
