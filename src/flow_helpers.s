; Общие helpers очистки, усилений и границ этапов ($C5D9-$C641).

; После одного обязательного NMI гасит rendering, выбирает primary nametable,
; обнуляет все 1024 bytes shadow и напрямую загружает их в $2000-$23FF. Затем
; на следующем vblank включает NMI (но оставляет PPU_MASK=$06 и rendering
; выключенным) и сбрасывает audio engine.
;
; Вход: NMI включён и увеличивает FrameCounter, PPU доступен; накопленная
; PPU-очередь корректна для flush. Первый WaitForNextFrame исполняет обычный NMI:
; передаёт OAM, flush-ит очередь, обслуживает palette/input/OAM/audio и двигает
; frame counters. Поэтому это не чистая операция только над экраном/audio.
;
; Выход: NametablePpuOffset=ShadowToPrimaryNametableOffset,
; VerticalScroll=NametableBits=PpuBufferPos=0; NametableShadow и VRAM
; $2000-$23FF заполнены нулями; ScratchPtr=$0800. PPU_CTRL=$B0, PPU_MASK=$06,
; address latch ожидает high write. После ResetAudioEngine: A=$FC, X=$1C, Y=0,
; N=0/Z=1/C=1/V=0, AudioStatePtr=$03FC, все 28 stream states и routes равны 0,
; $4015=$0F, $4017=$C0. Меняет перечисленное PPU/APU/audio state; первый NMI
; также может менять OAM shadow, input, palette state и кадровые счётчики.
ClearScreenAndAudio:
LC5D9:  jsr     DisableRenderingForBulkUpdate
        lda     #ShadowToPrimaryNametableOffset
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
; ExtendedStageUpperBound при точном (GameVariant&GameVariantIndexMask)=
; ExtendedStageVariant, иначе StandardStageUpperBound. Старшая тетрада variant
; игнорируется; индексы 7..15 НЕ считаются extended.
;
; Выход: A=StageNumber=$76 либо $32, N=Z=0; X/Y, стек и прочая RAM сохранены.
; C остаётся от CMP: C=1 iff младший ниббл variant >=6, поэтому это не признак
; выбранной extended-границы; V сохраняется со входа. Romhack должен держать
; обе границы согласованными с фактическим числом доступных уровней.
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
; Ровно восемь записей для Y=0..7: тип 7 исключён, а тип 3 имеет двойной вес.
; Terminator и bounds check нет; порядок type ids связан с effect/OAM tables.
LC63A:  .byte   $00,$01,$02,$03,$03,$04,$05,$06
