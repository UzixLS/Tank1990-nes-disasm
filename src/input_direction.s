; Декодирование кнопок направления ($E451-$E46B).

; Преобразует первый установленный бит Right/Left/Down/Up в направление 3/1/2/0.
DecodeDirectionButtons:
; Вход: A — байт кнопок. Приоритет Right, Left, Down, Up. Выход: A=direction 3/1/2/0 или $FF, если D-pad не нажат.
; X/Y/RAM не меняет; флаги соответствуют A.
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
        bcc     ReturnNoDirectionButton
        lda     #DIRECTION_UP
        rts

ReturnNoDirectionButton:
LE469:  lda     #$FF
        rts
