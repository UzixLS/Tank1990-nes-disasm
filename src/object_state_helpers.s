; Общие операции над состоянием танков и снарядов ($E3EF-$E42A).

TankStateClassCandidate          = $00
SpecialMergedTankAttributes      = $E7
NormalizedSpecialTankAttributes  = $E4

; Переводит танк X в TankStateDestroyed и очищает его расширенное состояние.
; Вход: X=0..TankSlotCount-1. Выход: A=0; X/Y сохраняются.
; Меняет только ObjectState,X и ObjectSpecialState,X; C/V сохраняются.
DestroyTankAndClearExtension:
LE3EF:  lda     #TankStateDestroyed
        sta     ObjectState,x
        lda     #$00
        sta     ObjectSpecialState,x
        rts
; Сохранённый байт между RTS и следующим entry point; статических ссылок нет.
UnreferencedE3f9Byte:
LE3F9:  .byte   $03
; Объединяет A с ObjectAttributes,X. Если результат равен
; SpecialMergedTankAttributes, заменяет его на NormalizedSpecialTankAttributes.
; Вход: X=0..TankSlotCount-1. Выход: A=0; X/Y сохраняются.
; Меняет ObjectAttributes,X и обнуляет ObjectFrame,X; C отражает сравнение
; объединённых атрибутов с SpecialMergedTankAttributes, V сохраняется.
MergeTankAttributeBits:
LE3FA:  ora     ObjectAttributes,x
        cmp     #SpecialMergedTankAttributes
        bne     StoreMergedTankAttributes
        lda     #NormalizedSpecialTankAttributes
StoreMergedTankAttributes:
LE402:  sta     ObjectAttributes,x
        lda     #$00
        sta     ObjectFrame,x
        rts
ClearProjectileStates:
; Обнуляет ProjectileState всех десяти слотов. Выход: A=0, X=$FF; Y и
; остальные поля снарядов сохраняются. На выходе N=1, Z=0; C/V сохраняются.
LE409:  ldx     #(ProjectileSlotCount-1)
        lda     #$00
ClearNextProjectileState:
LE40D:  sta     ProjectileState,x
        dex
        bpl     ClearNextProjectileState
        rts

ClearTankStates:
; Обнуляет ObjectState и восемь байтов от PlayerIceState. Только первые два
; принадлежат игрокам; следующие шесть перекрывают transition/debug RAM и
; служат общим сбросом. Выход: A=0, X=$FF; Y и остальные поля сохраняются.
; На выходе N=1, Z=0; C/V сохраняются.
LE413:  lda     #$00
        ldx     #(TankSlotCount-1)
ClearNextTankState:
LE417:  sta     ObjectState,x
        sta     PlayerIceState,x
        dex
        bpl     ClearNextTankState
        rts

; Формирует ObjectState,X как (старое состояние & StateLowNibbleMask) | A.
; Обычно A содержит только старшую тетраду нового класса; младшие биты A не
; маскируются и при наличии также устанавливаются в результате.
SetTankStateClass:
; Вход: A — биты нового класса, X=0..TankSlotCount-1. Выход: A — записанный
; ObjectState,X; X/Y сохраняются. Меняет ObjectState,X и временный байт
; TankStateClassCandidate; N/Z соответствуют результату, C/V сохраняются.
LE420:  sta     TankStateClassCandidate
        lda     ObjectState,x
        and     #StateLowNibbleMask
        ora     TankStateClassCandidate
        sta     ObjectState,x
        rts
