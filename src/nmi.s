; Кадровый NMI и обслуживание кадровых подсистем ($D400-$D44C).

NmiOamDmaPage       = $02
NmiPpuCtrlValue     = $B0
NmiPpuMaskValue     = $1E
SlowFrameCounterMask = $3F

; Кадровый NMI:
;   1. копирует OAM shadow страницы $02 через DMA;
;   2. исполняет накопленную PPU-очередь и, если BackgroundPaletteIndex>=0,
;      меняет фоновую палитру;
;   3. восстанавливает PPU_CTRL/scroll/mask, читает ввод, готовит следующий OAM
;      shadow и обновляет звук;
;   4. увеличивает FrameCounter и медленный счётчик $0A раз в 64 кадра.
; Сохраняет A/X/Y; исходные flags/PC восстанавливает финальный RTI из аппаратного
; NMI-frame. OAM DMA передаёт текущий OamShadow до построения следующего кадра.
; FlushPpuUpdateBuffer обнуляет PpuBufferPos; palette upload может также сбросить
; BackgroundPaletteIndex в $FF. NametableBits должен содержать только bits0..1:
; он OR-ится с $B0, выбирая nametable при включённых NMI, 8x16 sprites и pattern
; table background $1000. Горизонтальный scroll всегда 0, VerticalScroll задаёт
; второй PPU_SCROLL. FrameCounter увеличивается после audio, поэтому input/audio
; видят старое значение; SlowFrameCounter растёт после новых значений
; FrameCounter $00/$40/$80/$C0, то есть раз в 64 NMI с восьмибитным wrap.
NmiHandler:
        pha
        txa
        pha
        tya
        pha
        php
        lda     #$00
        sta     OAM_ADDR
        lda     #NmiOamDmaPage
        sta     OAM_DMA
        lda     PPU_STATUS
        jsr     FlushPpuUpdateBuffer
        lda     BackgroundPaletteIndex
        bmi     RestoreNmiDisplayState
        jsr     UploadBackgroundPalette
RestoreNmiDisplayState:
LD41D:  lda     NametableBits
        ora     #NmiPpuCtrlValue
        sta     PPU_CTRL
        lda     #$00
        sta     PPU_SCROLL
        lda     VerticalScroll
        sta     PPU_SCROLL
        lda     #NmiPpuMaskValue
        sta     PPU_MASK
        jsr     ReadControllers
        jsr     FinishAlternatingOamFrame
        jsr     UpdateAudioEngine
        inc     FrameCounter
        lda     FrameCounter
        and     #SlowFrameCounterMask
        bne     RestoreNmiRegisters
        inc     SlowFrameCounter
RestoreNmiRegisters:
LD446:  plp
        pla
        tay
        pla
        tax
        pla
        rti
