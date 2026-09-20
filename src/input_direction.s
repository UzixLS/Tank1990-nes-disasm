; Декодирование кнопок направления ($E451-$E46B).

NoDirectionSentinel = $FF

; Преобразует первый установленный бит Right/Left/Down/Up в направление 3/1/2/0.
DecodeDirectionButtons:
; Вход: A — байт кнопок; биты вне D-pad игнорируются. Приоритет: Right, Left,
; Down, Up. Выход: A=direction 3/1/2/0 и C=1 либо A=NoDirectionSentinel и
; C=0. N/Z соответствуют A; V, X, Y и RAM сохраняются.
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
