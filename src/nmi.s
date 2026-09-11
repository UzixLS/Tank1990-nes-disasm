; Кадровый NMI и обслуживание кадровых подсистем ($D400-$D44C).

; Кадровый NMI:
;   1. копирует OAM shadow страницы $02 через DMA;
;   2. исполняет накопленную PPU-очередь и, если $4D >= 0, меняет фоновую палитру;
;   3. восстанавливает PPU_CTRL/scroll/mask, читает ввод, обновляет OAM и звук;
;   4. увеличивает FrameCounter и медленный счётчик $0A раз в 64 кадра.
; Сохраняет A/X/Y и флаги прерванного кода. Меняет PPU/APU/OAM и указанные
; кадровые переменные; буфер PPU после сброса считается свободным.
NmiHandler:
        pha
        txa
        pha
        tya
        pha
        php
        lda     #$00
        sta     OAM_ADDR
        lda     #$02
        sta     OAM_DMA
        lda     PPU_STATUS
        jsr     FlushPpuUpdateBuffer
        lda     BackgroundPaletteIndex
        bmi     RestoreNmiDisplayState
        jsr     UploadBackgroundPalette
RestoreNmiDisplayState:
LD41D:  lda     NametableBits
        ora     #$B0
        sta     PPU_CTRL
        lda     #$00
        sta     PPU_SCROLL
        lda     VerticalScroll
        sta     PPU_SCROLL
        lda     #$1E
        sta     PPU_MASK
        jsr     ReadControllers
        jsr     FinishAlternatingOamFrame
        jsr     UpdateAudioEngine
        inc     FrameCounter
        lda     FrameCounter
        and     #$3F
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
