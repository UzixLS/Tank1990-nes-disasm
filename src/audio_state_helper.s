; Сохранённый адаптер состояния аудиопотока ($EA45-$EA48).

; Небольшой адаптер без статических ссылок: пишет A в состояние stream 5 —
; второго pulse-потока звука дополнительной жизни. Значение не проверяет:
; штатный протокол использует 0=off, 1=start request, 2=active, а audio engine
; трактует прочее ненулевое (кроме 1) как уже активное.
; Выход: A и все flags без изменений; X/Y, стек и SP сохранены. Меняет только
; ExtraLifePulse2AudioState, APU/остальную audio RAM не трогает.
StoreExtraLifePulse2AudioState:
LEA45:  sta     ExtraLifePulse2AudioState
        rts
