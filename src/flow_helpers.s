; Общие helpers очистки, усилений и границ этапов ($C5D9-$C641).

; Гасит рендеринг, выбирает основной nametable offset, очищает shadow nametable,
; загружает его в PPU, снова включает NMI и сбрасывает audio engine.
; Портит A/X/Y, ScratchPtr, PPU/APU и звуковую RAM; OAM shadow не меняет.
ClearScreenAndAudio:
LC5D9:  jsr     DisableRenderingForBulkUpdate
        lda     #$1C
        sta     NametablePpuOffset
        lda     #$00
        sta     VerticalScroll
        sta     NametableBits
        jsr     ClearNametableBuffer
        jsr     UploadNametableBuffer
        jsr     EnableNmiAfterVblank
        jsr     ResetAudioEngine
        rts

.include "powerup_flow.s"
; Подкладывает в StageNumber верхнюю границу для циклического декремента:
; ExtendedStageUpperBound при (GameVariant&$0F)=ExtendedStageVariant, иначе
; StandardStageUpperBound. Выход: A=StageNumber; X/Y и прочая RAM не меняются.
WrapStageNumberBackward:
LC627:  lda     GameVariant
        and     #GameVariantIndexMask
        cmp     #ExtendedStageVariant
        beq     SelectExtendedStageUpperBound
        lda     #StandardStageUpperBound
        bne     StoreStageUpperBound
SelectExtendedStageUpperBound:
LC633:  lda     #ExtendedStageUpperBound
StoreStageUpperBound:
LC635:  sta     StageNumber
        rts

; Два байта без статических ссылок между RTS и восьмибайтной таблицей.
; Как код они не классифицируются: $20 потребовал бы ещё один байт из RestrictedPowerUpTypeTable.
UnreferencedC638Bytes:
LC638:  .byte   $20,$B4
RestrictedPowerUpTypeTable:
LC63A:  .byte   $00,$01,$02,$03,$03,$04,$05,$06
