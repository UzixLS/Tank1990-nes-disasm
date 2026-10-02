; Полная инициализация runtime и RAM-маркер перезапуска ($D491-$D501).
; Файл включается из ppu.s в исходной позиции, чтобы сохранять адреса ROM.

InitialOamBufferStep       = $04
InitialHighScoreTenThousandsDigit = $02
RestartSignatureMismatch  = $00
RestartSignatureMatch     = $01

; Общая reset-инициализация display, score records и audio engine. Это
; не полная очистка RAM. Явно обнуляются TileTranslationOffset,
; DigitBlankMode, PpuBufferPos, OamBufferPos, PauseState, NametableShadow и обе
; score records. Остальные gameplay/session/input/RNG/object/projectile bytes
; по общему правилу сохраняются.
;
; HasRestartSignature сравнивает только $0110..$011F с 16-byte
; RestartSignatureCodeWindow, а не checksum всего ROM. При совпадении HighScore,
; MenuSelection и GameVariant не трогаются. При несовпадении
; InitializeColdBootPersistentState создаёт HighScore=0020000,
; GameVariant=BootVariantMarker и MenuSelection=0. Случайное совпадение
; неинициализированной RAM тоже выберет warm path: отдельного validity bit нет.
;
; Вход: rendering/NMI выключены, PPU доступен для прямых операций. Процедура
; ждёт vblank для palette upload, очищает весь shadow, загружает его в
; $2000-$23FF и $2800-$2BFF, но не в две остальные nametable. OAM setup меняет
; направление на -4 и пишет только Y=$F0 в entries offsets $FC..$04.
; Offset $00, а также tile/attributes/X всех entries, остаются stale до
; первого построения кадра. ResetAudioEngine обнуляет 28 stream states
; и route bytes, но сохраняет остальные audio-record fields и loop counters.
;
; Выход: A=$FC, X=$1C, Y=0, N=0/Z=1/C=1/V=0; PpuBufferPos=0,
; OamBufferPos=4, OamBufferStep=$FC, SpriteBehindTerrainMask=$20,
; BackgroundPaletteIndex=$FF, TileTranslationOffset=DigitBlankMode=PauseState=0,
; NametablePpuOffset=ShadowToNametable2800Offset, ScratchPtr=$0800. P1/P2 score
; равны семи нулям+$FF, restart signature обновлена, audio engine reset.
; PPU queue/OAM/nametable shadow, PPU/APU registers и названная RAM меняются;
; прямые uploads оставляют PPU address latch готовым к high-byte write.
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
        lda     #TerrainPriorityEnabled
        sta     SpriteBehindTerrainMask
        jsr     ClearNametableBuffer
        jsr     FinishAlternatingOamFrame
        ldx     #Player1Score
        jsr     ResetEightByteRecord
        ldx     #Player2Score
        jsr     ResetEightByteRecord
        jsr     HasRestartSignature
        bne     FinishCoreRuntimeInitialization
        ldx     #HighScore
        jsr     InitializeColdBootPersistentState
        lda     #InitialHighScoreTenThousandsDigit
        sta     HighScore+2
        lda     #$00
        sta     MenuSelection
FinishCoreRuntimeInitialization:
LD4CE:  lda     #ShadowToPrimaryNametableOffset
        sta     NametablePpuOffset
        jsr     UploadNametableBuffer
        lda     #ShadowToNametable2800Offset
        sta     NametablePpuOffset
        jsr     UploadNametableBuffer
        jsr     StoreRestartSignature
        jsr     ResetAudioEngine
        rts

; Копирует 16-байтное окно машинного кода RestartSignatureCodeWindow в
; RestartSignature обратным обходом. Выход: X=$FF,
; A=RestartSignatureCodeWindow[0], N=1/Z=0; Y и C/V сохранены. Меняет только
; RestartSignature; bounds определяются RestartSignatureByteCount и должны
; оставаться согласованными с обоими 16-байтными диапазонами.
StoreRestartSignature:
LD4E3:  ldx     #(RestartSignatureByteCount-1)
StoreNextRestartSignatureByte:
LD4E5:  lda     RestartSignatureCodeWindow,x
        sta     RestartSignature,x
        dex
        bpl     StoreNextRestartSignatureByte
        rts

; Сравнивает RestartSignature с RestartSignatureCodeWindow обратным обходом 15..0.
; При полном совпадении: A=1, X=$FF, N=0/Z=0/C=1. При несовпадении: A=0,
; X=наибольший отличающийся индекс, N=0/Z=1, C остаётся unsigned-результатом
; CMP различавшихся bytes. V, Y, RAM и стек сохраняются.
HasRestartSignature:
LD4EF:  ldx     #(RestartSignatureByteCount-1)
CompareNextRestartSignatureByte:
LD4F1:  lda     RestartSignature,x
        cmp     RestartSignatureCodeWindow,x
        bne     ReturnRestartSignatureMismatch
        dex
        bpl     CompareNextRestartSignatureByte
        lda     #RestartSignatureMatch
        rts

ReturnRestartSignatureMismatch:
LD4FF:  lda     #RestartSignatureMismatch
        rts
