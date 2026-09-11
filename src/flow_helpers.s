; Общие helpers очистки, усилений и границ этапов ($C5D9-$C641).

; Гасит рендеринг, очищает nametable shadow/PPU, снова включает NMI и сбрасывает audio engine.
; Портит A/X/Y, PPU/APU и звуковую RAM.
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
; Подкладывает в StageNumber верхнюю границу для декремента: $76 при ($46&$0F)=6, иначе $32.
; Выход: A — записанное StageNumber; X/Y не меняются.
WrapStageNumberBackward:
LC627:  lda     GameVariant
        and     #$0F
        cmp     #$06
        beq     SelectExtendedStageUpperBound
        lda     #$32
        bne     StoreStageUpperBound
SelectExtendedStageUpperBound:
LC633:  lda     #$76
StoreStageUpperBound:
LC635:  sta     StageNumber
        rts

; Два байта без статических ссылок между RTS и восьмибайтной таблицей.
; Как код они не классифицируются: $20 потребовал бы ещё один байт из RestrictedPowerUpTypeTable.
UnreferencedC638Bytes:
LC638:  .byte   $20,$B4
RestrictedPowerUpTypeTable:
LC63A:  .byte   $00,$01,$02,$03,$03,$04,$05,$06
