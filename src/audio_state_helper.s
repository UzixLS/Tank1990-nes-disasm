; Сохранённый адаптер состояния аудиопотока ($EA45-$EA48).

; Небольшой адаптер без статических ссылок: пишет A в состояние второго
; pulse-потока звука дополнительной жизни.
; RAM кроме ExtraLifePulse2AudioState и регистры X/Y не меняет.
StoreExtraLifePulse2AudioState:
LEA45:  sta     ExtraLifePulse2AudioState
        rts
