; Общие операции над состоянием танков и снарядов ($E3EF-$E42A).

TankStateClassCandidate          = $00
SpecialMergedTankAttributes      = $E7
NormalizedSpecialTankAttributes  = $E4

; Переводит танк X в TankStateDestroyed и очищает его расширенное состояние.
; Вход: X=0..TankSlotCount-1; bounds check нет. Выход: A=0, N=0/Z=1;
; X/Y, C/V, стек и SP сохраняются. Меняет только ObjectState,X и
; ObjectSpecialState,X: attributes/frame/coordinates и occupancy cache остаются.
DestroyTankAndClearExtension:
LE3EF:  lda     #TankStateDestroyed
        sta     ObjectState,x
        lda     #$00
        sta     ObjectSpecialState,x
        rts
; Сохранённый байт между RTS и следующим entry point; статических ссылок нет.
UnreferencedE3f9Byte:
LE3F9:  .byte   $03
; Вычисляет raw=(input A)|ObjectAttributes,X. Только точный raw=$E7 заменяется
; на $E4; любое иное значение сохраняется без нормализации. OR означает, что
; обычный путь умеет лишь устанавливать bits, но special conversion очищает
; bits1..0.
; Вход: X=0..TankSlotCount-1; bounds check нет. Выход: A=0, N=0/Z=1, X/Y
; сохранены; C=1 iff raw >= $E7 unsigned (не iff special conversion сработал),
; V сохраняется. Меняет ObjectAttributes,X и обнуляет ObjectFrame,X; входной A
; и raw не сохраняются, прочая object RAM/stack не меняется.
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
; Обнуляет ProjectileState слотов 9..0; координаты, flags и прочий payload не
; очищает, но нулевой state делает их неактивными. Выход: A=0, X=$FF, N=1/Z=0;
; Y, C/V, стек и вся остальная RAM сохраняются. Число проходов связано с
; ProjectileSlotCount и физическим размером массива ProjectileState.
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
; служат общим сбросом: очищается точный диапазон $0103-$010A. Attributes,
; frame, coordinates и ObjectSpecialState не очищаются; state=0 деактивирует
; slots. Выход: A=0, X=$FF, N=1/Z=0; Y, C/V и стек сохраняются.
; TankSlotCount одновременно задаёт длину обоих очищаемых диапазонов, поэтому
; его romhack-изменение требует проверить layout общей RAM после PlayerIceState.
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
; TankStateClassCandidate=$00 (по выходу он равен input A, несмотря на имя);
; N/Z соответствуют результату, C/V, стек и SP сохраняются. Bounds check нет.
; StateLowNibbleMask должен оставаться согласованным с class/direction/phase
; encoding всех callers.
LE420:  sta     TankStateClassCandidate
        lda     ObjectState,x
        and     #StateLowNibbleMask
        ora     TankStateClassCandidate
        sta     ObjectState,x
        rts
