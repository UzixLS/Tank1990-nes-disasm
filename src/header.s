.segment "HEADER"

    .byte "NES", $1A
    .byte 2                       ; Два банка PRG по 16 КиБ.
    .byte 1                       ; Один банк CHR на 8 КиБ.
    .byte $00                     ; Mapper 0, horizontal mirroring.
    .byte $00
    .res 8, $00
