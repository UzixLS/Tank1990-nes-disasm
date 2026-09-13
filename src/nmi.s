; Кадровый NMI и обслуживание кадровых подсистем ($D400-$D44C).

NmiOamDmaPage       = $02
NmiPpuCtrlValue     = $B0
NmiPpuMaskValue     = $1E
SlowFrameCounterMask = $3F

; Кадровый NMI:
;   1. копирует OAM shadow страницы $02 через DMA;
;   2. исполняет накопленную PPU-очередь и, если BackgroundPaletteIndex>=0,
;      меняет фоновую палитру;
;   3. восстанавливает PPU_CTRL/scroll/mask, читает ввод, обновляет OAM и звук;
;   4. увеличивает FrameCounter и медленный счётчик $0A раз в 64 кадра.
; Сохраняет A/X/Y; исходные flags/PC восстанавливает финальный RTI из аппаратного
; NMI-frame. OAM DMA передаёт текущий OamShadow до построения следующего кадра.
; FlushPpuUpdateBuffer обнуляет PpuBufferPos; palette upload может также сбросить
; BackgroundPaletteIndex в $FF. Восстанавливает PPU_CTRL, обе записи PPU_SCROLL
; и PPU_MASK, читает controllers, завершает следующий OAM shadow и обновляет APU.
; FrameCounter растёт каждый NMI, SlowFrameCounter — при его младших 6 битах=0.
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
