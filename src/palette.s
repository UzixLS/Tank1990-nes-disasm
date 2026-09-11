; Загрузка палитр и ожидание vblank ($D502-$D5FA).

; Дожидается vblank и пишет обе 16-байтные палитры. Фон выбирает набор 0.
; Меняет A/X/Y, PPU_ADDR/PPU_DATA и ставит $4D=$FF.
UploadInitialPalettes:
LD502:  jsr     WaitForVblankStart
        jsr     UploadSpritePalette
        lda     #$00
        jsr     UploadBackgroundPalette
        rts

; A выбирает один из 16-байтовых наборов фоновой палитры.
; Выход: X на байте сразу за набором, Y=0, A=0, $4D=$FF.
; Побочно: перезаписывает $3F00-$3F0F; заключительная последовательность адресов
; оставляет внутренний VRAM-адрес PPU равным $0000.
UploadBackgroundPalette:
LD50E:  asl     a
        asl     a
        asl     a
        asl     a
        tax
        ldy     #$10
        lda     #$3F
        sta     PPU_ADDR
        lda     #$00
        sta     PPU_ADDR
UploadNextBackgroundPaletteByte:
LD51F:  lda     BackgroundPaletteSets,x
        sta     PPU_DATA
        inx
        dey
        bne     UploadNextBackgroundPaletteByte
        lda     #$FF
        sta     BackgroundPaletteIndex
        lda     #$3F
        sta     PPU_ADDR
        lda     #$00
        sta     PPU_ADDR
        sta     PPU_ADDR
        sta     PPU_ADDR
        rts

; Загружает постоянную 16-байтовую палитру спрайтов в $3F10.
; Выход: X=$10, Y=0; A равен последнему байту палитры. Меняет PPU address latch/data.
UploadSpritePalette:
LD53E:  ldx     #$00
        ldy     #$10
        lda     #$3F
        sta     PPU_ADDR
        sty     PPU_ADDR
UploadNextSpritePaletteByte:
LD54A:  lda     SpritePalette,x
        sta     PPU_DATA
        inx
        dey
        bne     UploadNextSpritePaletteByte
        rts

SpritePalette:
LD555:  .incbin "../build/sprite-palette.bin"
BackgroundPaletteSets:
LD565:  .incbin "../build/background-palettes.bin"
; Активно ждёт установки vblank в PPU_STATUS.
; Выход: A с установленным битом 7; X/Y не меняются. Чтение сбрасывает vblank и latch.
WaitForVblankStart:
WaitForVblankPoll:
LD5F5:  lda     PPU_STATUS
        bpl     WaitForVblankPoll
        rts
