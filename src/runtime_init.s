; Полная инициализация runtime и RAM-маркер перезапуска ($D491-$D501).
; Файл включается из ppu.s в исходной позиции, чтобы сохранять адреса ROM.

RestartSignatureByteCount = $10
InitialOamBufferStep       = $04
InitialSpritePriorityMask  = $20
InitialHighScoreTenThousandsDigit = $02

; Общая reset-инициализация отображения, записей счёта и звука. Это не полная
; очистка RAM: явно сбрасываются перечисленные поля, NametableShadow и P1/P2
; score; HighScore, MenuSelection и GameVariant сохраняются при совпавшем
; restart signature. При несовпадении 16 bytes с ROM-маркером BootHook создаёт
; HighScore=0020000, GameVariant=BootVariantMarker и MenuSelection=0.
;
; Вход: rendering/NMI выключены, PPU доступен для прямых операций. Процедура
; ждёт vblank для palette upload, очищает весь shadow, загружает его в
; $2000-$23FF и $2800-$2BFF, но не в две остальные nametable. OAM setup меняет
; направление заполнения на -4, скрывает entries offsets $FC..$04 и оставляет
; offset $00 нетронутым до первого построения кадра.
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
        lda     #InitialHighScoreTenThousandsDigit
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

; Копирует 16-байтный ROM-маркер LC040 в RestartSignature обратным обходом.
; Выход: X=$FF, A=LC040[0], N=1/Z=0; Y и C/V сохранены. Меняет только
; RestartSignature; bounds определяются RestartSignatureByteCount и должны
; оставаться согласованными с обоими 16-байтными диапазонами.
StoreRestartSignature:
LD4E3:  ldx     #(RestartSignatureByteCount-1)
StoreNextRestartSignatureByte:
LD4E5:  lda     LC040,x
        sta     RestartSignature,x
        dex
        bpl     StoreNextRestartSignatureByte
        rts

; Сравнивает RestartSignature с ROM-маркером LC040 обратным обходом 15..0.
; При полном совпадении: A=1, X=$FF, N=0/Z=0/C=1. При несовпадении: A=0,
; X=наибольший отличающийся индекс, N=0/Z=1, C остаётся unsigned-результатом
; CMP различавшихся bytes. V, Y, RAM и стек сохраняются.
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
