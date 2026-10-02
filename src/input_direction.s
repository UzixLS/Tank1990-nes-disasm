; Декодирование кнопок направления ($E451-$E46B).

NoDirectionSentinel = $FF

; Преобразует первый установленный D-pad bit в индекс direction table.
DecodeDirectionButtons:
; Вход: A — байт формата Joy* с Right/Left/Down/Up в bits7/6/5/4; младшие
; кнопки игнорируются. Четыре ASL задают жёсткий приоритет Right, Left, Down,
; Up при одновременно нажатых направлениях.
; Выход при успехе: A=DIRECTION_RIGHT/LEFT/DOWN/UP (3/1/2/0), C=1; при
; отсутствии D-pad: A=NoDirectionSentinel ($FF), C=0. N/Z соответствуют A
; (в частности Up даёт Z=1, а sentinel N=1); V, X/Y, RAM, стек и SP сохраняются.
; Значения 0..3 обязаны оставаться согласованными с direction tables и low bits
; object state; процедура не проверяет размер таблиц у последующих consumers.
LE451:  asl     a
        bcc     TestLeftDirectionButton
        lda     #DIRECTION_RIGHT
        rts
TestLeftDirectionButton:
LE457:  asl     a
        bcc     TestDownDirectionButton
        lda     #DIRECTION_LEFT
        rts

TestDownDirectionButton:
LE45D:  asl     a
        bcc     TestUpDirectionButton
        lda     #DIRECTION_DOWN
        rts

TestUpDirectionButton:
LE463:  asl     a
        bcc     ReturnNoDirection
        lda     #DIRECTION_UP
        rts

ReturnNoDirection:
LE469:  lda     #NoDirectionSentinel
        rts
