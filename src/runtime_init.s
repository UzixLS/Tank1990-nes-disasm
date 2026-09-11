; Полная инициализация runtime и RAM-маркер перезапуска ($D491-$D501).
; Файл включается из ppu.s в исходной позиции, чтобы сохранять адреса ROM.

; Общая инициализация PPU/OAM-очереди, счётчиков, записей счёта и звука.
; Очищает NametableShadow, загружает палитры и обе nametable ($2000/$2400).
; 16 байт кода от LC040 служат RAM-маркером: при несовпадении однократно
; вызывает BootHook, после чего обновляет маркер. Почти вся рабочая RAM и A/X/Y
; могут измениться; вызывать только из кода сброса/полного перезапуска состояния.
InitializeCoreRuntime:
LD491:
        lda     #$00
        sta     TileTranslationOffset
        sta     DigitBlankMode
        sta     PpuBufferPos
        sta     OamBufferPos
        sta     PauseState
        lda     #$FF
        sta     BackgroundPaletteIndex
        jsr     UploadInitialPalettes
        lda     #$04
        sta     OamBufferStep
        lda     #$20
        sta     SpriteBehindTerrainMask
        jsr     ClearNametableBuffer
        jsr     FinishAlternatingOamFrame
        ldx     #Player1Score
        jsr     ResetEightByteRecord
        ldx     #Player2Score
        jsr     ResetEightByteRecord
        jsr     HasRestartSignature
        bne     UploadInitialNametables
        ldx     #HighScore
        jsr     BootHook
        lda     #$02
        sta     HighScore+2
        lda     #$00
        sta     MenuSelection
UploadInitialNametables:
LD4CE:  lda     #$1C
        sta     NametablePpuOffset
        jsr     UploadNametableBuffer
        lda     #$24
        sta     NametablePpuOffset
        jsr     UploadNametableBuffer
        jsr     StoreRestartSignature
        jsr     ResetAudioEngine
        rts

; Копирует 16-байтный ROM-маркер LC040 в RestartSignature.
; Выход: X=$FF; A=первый байт маркера.
StoreRestartSignature:
LD4E3:  ldx     #$0F
StoreNextRestartSignatureByte:
LD4E5:  lda     LC040,x
        sta     RestartSignature,x
        dex
        bpl     StoreNextRestartSignatureByte
        rts

; Сравнивает RestartSignature с ROM-маркером LC040.
; Возвращает A=1 при полном совпадении, иначе A=0; X указывает на расхождение.
HasRestartSignature:
LD4EF:  ldx     #$0F
CompareNextRestartSignatureByte:
LD4F1:  lda     RestartSignature,x
        cmp     LC040,x
        bne     ReturnRestartSignatureMismatch
        dex
        bpl     CompareNextRestartSignatureByte
        lda     #$01
        rts

ReturnRestartSignatureMismatch:
LD4FF:  lda     #$00
        rts
