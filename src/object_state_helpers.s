; Общие операции над состоянием танков и снарядов ($E3EF-$E42A).

TankStateClassCandidate          = $00
SpecialMergedTankAttributes      = $E7
NormalizedSpecialTankAttributes  = $E4

; Переводит танк X в TankStateDestroyed и очищает ObjectSpecialState,X.
; Выход: A=0; X/Y не меняются.
DestroyTankAndClearExtension:
LE3EF:  lda     #TankStateDestroyed
        sta     ObjectState,x
        lda     #$00
        sta     ObjectSpecialState,x
        rts
; Сохранённый байт между RTS и следующим entry point; статических ссылок нет.
UnreferencedE3f9Byte:
LE3F9:  .byte   $03
; Объединяет входные биты A с ObjectAttributes,X. Единственная специальная
; комбинация SpecialMergedTankAttributes нормализуется в
; NormalizedSpecialTankAttributes.
; Записывает результат, обнуляет ObjectFrame,X; выход A=0, X/Y сохраняются.
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
; Обнуляет ProjectileState всех 10 слотов. Выход: A=0, X=$FF; Y и остальные поля снарядов не меняются.
LE409:  ldx     #(ProjectileSlotCount-1)
        lda     #$00
ClearNextProjectileState:
LE40D:  sta     ProjectileState,x
        dex
        bpl     ClearNextProjectileState
        rts

ClearTankStates:
; Обнуляет ObjectState и восемь байтов от PlayerIceState. Только первые два
; принадлежат игрокам; следующие шесть перекрывают transition/debug RAM и служат общим сбросом.
; Выход: A=0, X=$FF; Y и остальные поля не меняются.
LE413:  lda     #$00
        ldx     #(TankSlotCount-1)
ClearNextTankState:
LE417:  sta     ObjectState,x
        sta     PlayerIceState,x
        dex
        bpl     ClearNextTankState
        rts

; Заменяет старшую тетраду ObjectState, сохраняя направление в младшей.
SetTankStateClass:
; Вход: A — новые биты класса (обычно старшая тетрада), X — слот. Выход: A — новый ObjectState;
; портит TankStateClassCandidate и флаги, X/Y не меняет. Вход A здесь не маскируется.
LE420:  sta     TankStateClassCandidate
        lda     ObjectState,x
        and     #StateLowNibbleMask
        ora     TankStateClassCandidate
        sta     ObjectState,x
        rts
