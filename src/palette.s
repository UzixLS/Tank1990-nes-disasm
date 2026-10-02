; Загрузка палитр и ожидание vblank ($D502-$D5FA).

PaletteByteCount       = $10
PalettePpuAddressHigh  = $3F
SpritePaletteAddressLo = $10
BackgroundPaletteSetCount = $09

; Дожидается vblank и пишет сначала 16-byte sprite palette в $3F10-$3F1F,
; затем background set 0 в $3F00-$3F0F. Из-за palette mirroring записи
; $3F10/$14/$18/$1C также попадают в $3F00/$04/$08/$0C, но следующий background
; upload окончательно задаёт эти четыре bytes.
; Вход: PPU_ADDR latch ожидает high write; PPU_CTRL increment=1. Rendering
; должен быть выключен либо обе загрузки должны завершиться в доступном vblank.
; Выход соответствует UploadBackgroundPalette(0): A=0, X=$10, Y=0,
; BackgroundPaletteIndex=$FF, N=0/Z=1/C=0; V сохраняется. Меняет palette RAM,
; PPU_ADDR/PPU_DATA и write latch; после финальной адресной последовательности
; внутренний VRAM address=$0000, latch снова ожидает high write.
UploadInitialPalettes:
LD502:  jsr     WaitForVblankStart
        jsr     UploadSpritePalette
        lda     #$00
        jsr     UploadBackgroundPalette
        rts

; A выбирает один из девяти 16-byte background sets 0..8. Index умножается на
; 16 восьмибитными ASL без bounds check: 9..15 читают следующие ROM bytes,
; >=16 повторяют адреса по младшему нибблу. NMI считает любой неотрицательный
; BackgroundPaletteIndex запросом, поэтому romhack обязан ограничить его 0..8
; либо расширить таблицу и контракт.
;
; Вход: PPU_ADDR latch ожидает high write, PPU_CTRL increment=1; вызывать в NMI/
; vblank либо при выключенном rendering. Каждый table byte пишется без маски и
; должен быть допустимым NES palette value. Выход для valid input i:
; X=16*(i+1), Y=0, A=0, BackgroundPaletteIndex=$FF, N=0/Z=1/C=0; V сохраняется.
; Перезаписывает $3F00-$3F0F; заключительные две пары PPU_ADDR writes оставляют
; внутренний VRAM address=$0000 и latch в high-write phase. PPU queue/OAM/audio
; и сами ROM tables не меняет.
UploadBackgroundPalette:
LD50E:  asl     a
        asl     a
        asl     a
        asl     a
        tax
        ldy     #PaletteByteCount
        lda     #PalettePpuAddressHigh
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
        lda     #PalettePpuAddressHigh
        sta     PPU_ADDR
        lda     #$00
        sta     PPU_ADDR
        sta     PPU_ADDR
        sta     PPU_ADDR
        rts

; Загружает постоянную 16-byte таблицу SpritePalette в $3F10-$3F1F.
; Palette mirroring одновременно затрагивает background entries
; $3F00/$04/$08/$0C. Вход: PPU_ADDR latch ожидает high write, increment=1;
; требования к rendering/vblank те же, что у background upload.
; Выход: X=PaletteByteCount, Y=0, A=SpritePalette[15], N=0/Z=1; C/V сохранены.
; Меняет palette RAM и PPU address/data; внутренний VRAM address после
; записи=$3F20, latch ожидает high write. PPU queue/OAM/audio не меняет.
UploadSpritePalette:
LD53E:  ldx     #$00
        ldy     #SpritePaletteAddressLo
        lda     #PalettePpuAddressHigh
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
; 16 raw PPU color values: четыре последовательные sprite palettes по 4 bytes.
LD555:  .incbin "../build/sprite-palette.bin"
BackgroundPaletteSets:
; Девять последовательных background sets по 16 raw PPU color values; внутри
; каждого set лежат четыре palette records по 4 bytes. Доказанные назначения:
; 0 — gameplay/attract и возврат с frontend; 1/2 — две полусекундные gameplay
; фазы; 3 — title/statistics; 4 — stage selection; 5..8 — четырёхкадровый цикл
; экрана нового рекорда.
LD565:  .incbin "../build/background-palettes.bin"
; Активно ждёт установки vblank в PPU_STATUS.
; Каждый poll сбрасывает общий write latch PPU_SCROLL/PPU_ADDR; чтение с bit7=1
; также очищает vblank flag. Если NMI handler параллельно читает PPU_STATUS,
; ожидание может пропустить текущий vblank, поэтому штатные callers используют
; его при выключенном NMI. Выход: A=$80..$FF (bit7=1, остальные status/open-bus),
; N=1/Z=0; X/Y и C/V сохраняются. RAM и остальные PPU registers не меняет.
WaitForVblankStart:
WaitForVblankPoll:
LD5F5:  lda     PPU_STATUS
        bpl     WaitForVblankPoll
        rts
