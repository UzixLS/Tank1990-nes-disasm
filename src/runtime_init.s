; Полная инициализация runtime и RAM-маркер перезапуска ($D491-$D501).
; Файл включается из ppu.s в исходной позиции, чтобы сохранять адреса ROM.

RestartSignatureByteCount = $10
InitialOamBufferStep       = $04
InitialSpritePriorityMask  = $20

; Общая инициализация PPU/OAM-очереди, счётчиков, записей счёта и звука.
; Очищает NametableShadow, загружает палитры и nametable $2000/$2800.
; 16 байт кода от LC040 служат RAM-маркером: при несовпадении однократно
; вызывает BootHook, после чего обновляет маркер. Почти вся рабочая RAM и A/X/Y
; могут измениться; вызывать только из кода сброса/полного перезапуска состояния.
; Прямые uploads требуют уже отключённого rendering. По выходу PpuBufferPos=0,
; обе score-записи сброшены, restart signature обновлена, audio engine reset;
; ScratchPtr=$0800 после второй nametable, A/X/Y не определены.
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
        lda     #InitialOamBufferStep
        sta     OamBufferStep
        lda     #InitialSpritePriorityMask
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
LD4CE:  lda     #ShadowToPrimaryNametableOffset
        sta     NametablePpuOffset
        jsr     UploadNametableBuffer
        lda     #ShadowToNametable2800Offset
        sta     NametablePpuOffset
        jsr     UploadNametableBuffer
        jsr     StoreRestartSignature
        jsr     ResetAudioEngine
        rts

; Копирует 16-байтный ROM-маркер LC040 в RestartSignature.
; Выход: X=$FF; A=первый байт маркера, Y сохранён. Меняет только
; RestartSignature и flags.
StoreRestartSignature:
LD4E3:  ldx     #(RestartSignatureByteCount-1)
StoreNextRestartSignatureByte:
LD4E5:  lda     LC040,x
        sta     RestartSignature,x
        dex
        bpl     StoreNextRestartSignatureByte
        rts

; Сравнивает RestartSignature с ROM-маркером LC040.
; Возвращает A=1 и X=$FF при полном совпадении, иначе A=0 и X указывает на
; первый найденный при обратном обходе индекс расхождения; Y и RAM сохраняются.
HasRestartSignature:
LD4EF:  ldx     #(RestartSignatureByteCount-1)
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
