; Аудиодвижок и потоки музыки/эффектов ($EA51-$EF75).

; Включает каналы APU и очищает записи состояния звуковых потоков.
ResetAudioEngine:
LEA51:  lda     #$0F
        sta     APU_STATUS
        lda     #$C0
        sta     JOY2_FRAME
        lda     #$1C
        sta     AudioStatePtrLo
        lda     #$03
        sta     AudioStatePtrHi
        ldx     #$00
        ldy     #$00
LEA67:  tya
        sta     (AudioStatePtrLo),y
        sta     $0300,x
        clc
        lda     AudioStatePtrLo
        adc     #$08
        sta     AudioStatePtrLo
        bcc     LEA78
        inc     AudioStatePtrHi
LEA78:  inx
        cpx     #$1C
        bne     LEA67
        rts

; Один кадровый шаг интерпретатора музыки и звуковых эффектов.
UpdateAudioEngine:
LEA7E:  lda     $6D
        bne     LEA88
        lda     #$1C
        sta     AudioChannelCount
        bpl     LEA8C
LEA88:  lda     #$01
        sta     AudioChannelCount
LEA8C:  lda     #$00
        ldx     #$03
LEA90:  sta     $F9,x
        dex
        bpl     LEA90
        lda     #$00
        sta     AudioChannel
        lda     #$1C
        sta     AudioStatePtrLo
        lda     #$03
        sta     AudioStatePtrHi
LEAA1:  ldx     AudioChannel
        lda     $0300,x
        beq     LEAE3
        ldy     #$00
        lda     (AudioStatePtrLo),y
        beq     LEAE3
        cmp     #$05
        bcc     LEABD
        sec
        sbc     #$05
        tax
        lda     #$01
        sta     $F9,x
        jmp     LEAE3

LEABD:  tax
        dex
        lda     $F9,x
        bne     LEAE3
        lda     #$01
        sta     $F9,x
        txa
        tay
        clc
        adc     #$05
        ldy     #$00
        sta     (AudioStatePtrLo),y
        txa
        asl     a
        asl     a
        tax
        lda     #$04
        sta     AudioWorkLo
LEAD8:  iny
        lda     (AudioStatePtrLo),y
        sta     APU_PULSE1_CTRL,x
        inx
        dec     AudioWorkLo
        bne     LEAD8
LEAE3:  clc
        lda     AudioStatePtrLo
        adc     #$08
        sta     AudioStatePtrLo
        bcc     LEAEE
        inc     AudioStatePtrHi
LEAEE:  inc     AudioChannel
        lda     AudioChannel
        cmp     AudioChannelCount
        bcc     LEAA1
        ldx     #$00
LEAF8:  stx     AudioWorkLo
        lda     $F9,x
        bne     LEB0A
        txa
        asl     a
        asl     a
        tax
        asl     a
        and     #$10
        eor     #$10
        sta     APU_PULSE1_CTRL,x
LEB0A:  ldx     AudioWorkLo
        inx
        cpx     #$04
        bcc     LEAF8
        ldy     #$00
        sty     AudioChannel
        lda     #$1C
        sta     AudioStatePtrLo
        lda     #$03
        sta     AudioStatePtrHi
LEB1D:  ldx     AudioChannel
        lda     $0300,x
        beq     LEB2E
        cmp     #$01
        bne     LEB42
        inc     $0300,x
        jmp     LEB4F

LEB2E:  clc
        lda     AudioStatePtrLo
        adc     #$08
        sta     AudioStatePtrLo
        bcc     LEB39
        inc     AudioStatePtrHi
LEB39:  inc     AudioChannel
        lda     AudioChannel
        cmp     AudioChannelCount
        bcc     LEB1D
        rts

LEB42:  ldy     #$07
        lda     (AudioStatePtrLo),y
        sec
        sbc     #$01
        sta     (AudioStatePtrLo),y
        beq     LEB85
        bne     LEB2E
LEB4F:  lda     #$00
        ldy     #$05
        sta     (AudioStatePtrLo),y
        jsr     LoadAudioSequencePointer
        jsr     ReadAudioArgument
        ldy     #$00
        sta     (AudioStatePtrLo),y
        jsr     ReadAudioArgument
        ldy     #$01
        sta     (AudioStatePtrLo),y
        jsr     ReadAudioArgument
        ldy     #$02
        sta     (AudioStatePtrLo),y
        jsr     ReadAudioArgument
        ldy     #$04
        sta     (AudioStatePtrLo),y
        ldy     #$00
        lda     (AudioStatePtrLo),y
        cmp     #$04
        bne     LEB88
        jsr     ReadAudioArgument
        ldy     #$03
        sta     (AudioStatePtrLo),y
        bpl     LEB88
LEB85:  jsr     LoadAudioSequencePointer
LEB88:  jsr     ReadAudioArgument
        cmp     #$E8
        bcs     LEBE1
        cmp     #$60
        beq     LEBD7
        bcc     LEB9E
        sbc     #$60
        ldy     #$06
        sta     (AudioStatePtrLo),y
        jmp     LEB88

LEB9E:  pha
        and     #$F8
        lsr     a
        lsr     a
        tax
        lda     LECE6,x
        sta     AudioWorkLo
        lda     LECE7,x
        sta     AudioWorkHi
        pla
        and     #$07
        beq     LEBBB
        tax
LEBB4:  lsr     AudioWorkLo
        ror     AudioWorkHi
        dex
        bne     LEBB4
LEBBB:  ldy     #$04
        lda     (AudioStatePtrLo),y
        and     #$F8
        ora     AudioWorkLo
        sta     (AudioStatePtrLo),y
        lda     AudioWorkHi
        dey
        sta     (AudioStatePtrLo),y
        ldy     #$00
        lda     (AudioStatePtrLo),y
        cmp     #$05
        bcc     LEBD7
        sec
        sbc     #$04
        sta     (AudioStatePtrLo),y
LEBD7:  ldy     #$06
        lda     (AudioStatePtrLo),y
        iny
        sta     (AudioStatePtrLo),y
        jmp     LEB2E

LEBE1:  sbc     #$E8
        jsr     DispatchAudioCommand

; DispatchAudioCommand использует адрес возврата как базу этой inline-таблицы и передаёт
; управление обработчику команды $E8-$F9.
AudioCommandHandlers:
        .word   AudioCommandE8,AudioCommandE9,AudioCommandEA,AudioCommandEB
        .word   AudioCommandEC,AudioCommandED,AudioCommandEE,AudioCommandEF
        .word   AudioCommandF0,AudioCommandF1,AudioCommandF2
        .word   AudioCommandF3ToF8,AudioCommandF3ToF8,AudioCommandF3ToF8
        .word   AudioCommandF3ToF8,AudioCommandF3ToF8,AudioCommandF3ToF8
        .word   AudioCommandF9

AudioCommandE8:
LEC0A:  ldx     AudioChannel
LEC0C:  lda     #$00
        sta     $0300,x
        ldy     #$00
        sta     (AudioStatePtrLo),y
        ldy     #$05
        lda     (AudioStatePtrLo),y
        sec
        sbc     #$01
        sta     (AudioStatePtrLo),y
        jmp     LEB2E

AudioCommandE9:
LEC21:  jsr     ReadAudioArgument
        sta     AudioWorkLo
        ldy     #$01
        lda     (AudioStatePtrLo),y
        and     #$3F
        ora     AudioWorkLo
        sta     (AudioStatePtrLo),y
        jmp     LEB88

AudioCommandEA:
LEC33:  jsr     ReadAudioArgument
        sta     AudioWorkLo
        ldy     #$01
        lda     (AudioStatePtrLo),y
        and     #$C0
        ora     AudioWorkLo
        sta     (AudioStatePtrLo),y
        jmp     LEB88

AudioCommandEB:
LEC45:  jsr     ReadAudioArgument
        sta     AudioWorkLo
        ldy     #$01
        lda     (AudioStatePtrLo),y
        and     #$F0
        ora     AudioWorkLo
        sta     (AudioStatePtrLo),y
        jmp     LEB88

AudioCommandEC:
LEC57:  jsr     ReadAudioArgument
        ldy     #$02
        sta     (AudioStatePtrLo),y
        jmp     LEB88

AudioCommandED:
LEC61:  jsr     ReadAudioArgument
        ldy     #$04
        sta     (AudioStatePtrLo),y
        jmp     LEB88

AudioCommandEE:
LEC6B:  jsr     ReadAudioArgument
        ldy     #$01
        sta     (AudioStatePtrLo),y
        jmp     LEB88

AudioCommandEF:
LEC75:  lda     #$00
        ldx     #$02
LEC79:  sta     AudioLoopCounters,x
        dex
        bpl     LEC79
        jmp     LEB88

AudioCommandF0:
LEC81:  ldx     #$00
        beq     LEC8A
AudioCommandF1:
LEC85:  ldx     #$01
        .byte   $2C                    ; BIT abs поглощает следующий LDX #$02.
AudioCommandF2:
LEC88:  ldx     #$02
LEC8A:  jsr     ReadAudioArgument
        inc     AudioLoopCounters,x
        cmp     AudioLoopCounters,x
        bne     LECA5
        lda     #$00
        sta     AudioLoopCounters,x
        beq     LEC99

AudioCommandF3ToF8:
LEC99:  ldy     #$05
        lda     (AudioStatePtrLo),y
        clc
        adc     #$01
        sta     (AudioStatePtrLo),y
        jmp     LEB88

AudioCommandF9:
LECA5:  jsr     ReadAudioArgument
        ldy     #$05
        sta     (AudioStatePtrLo),y
        jmp     LEB88
LoadAudioSequencePointer:
LECAF:  lda     AudioChannel
        asl     a
        tax
        lda     AudioSequencePointers,x
        sta     AudioDataPtrLo
        lda     AudioSequencePointers+1,x
        sta     AudioDataPtrHi
        rts

ReadAudioArgument:
LECBE:  lda     AudioChannel
        ldy     #$05
        lda     (AudioStatePtrLo),y
        tay
        lda     (AudioDataPtrLo),y
        pha
        iny
        tya
        ldy     #$05
        sta     (AudioStatePtrLo),y
        pla
        rts

DispatchAudioCommand:
LECD0:  asl     a
        tay
        iny
        pla
        sta     AudioWorkLo
        pla
        sta     AudioWorkHi
        lda     (AudioWorkLo),y
        tax
        iny
        lda     (AudioWorkLo),y
        sta     AudioWorkHi
        stx     AudioWorkLo
        jmp     (AudioWorkLo)

LECE6:  .byte   $07
LECE7:  .byte   $F2,$07,$80,$07,$14,$06,$AE,$06
        .byte   $43,$05,$F4,$05,$9E,$05,$4E,$05
        .byte   $02,$04,$BA,$04,$76,$04,$36
AudioSequencePointers:
LECFE:  .word   AudioSequence00,AudioSequence01,AudioSequence02,AudioSequence03
        .word   AudioSequence04,AudioSequence05,AudioSequence06,AudioSequence07
        .word   AudioSequence08,AudioSequence09,AudioSequence10,AudioSequence11
        .word   AudioSequence12,AudioSequence13,AudioSequence14,AudioSequence15
        .word   AudioSequence16,AudioSequence17,AudioSequence18,AudioSequence19
        .word   AudioSequence20,AudioSequence21,AudioSequence22,AudioSequence23
        .word   AudioSequence24,AudioSequence25,AudioSequence26,AudioSequence27

; Потоки байткода музыки и звуковых эффектов. Команды $E8-$F9
; обрабатываются таблицей AudioCommandHandlers. Некоторые потоки используют
; общие хвосты, поэтому метка означает точку входа, а не отдельный блок данных.
AudioSequences:
AudioSequence01:
        .byte   $01,$81,$7F,$40,$EF,$68,$1B,$2B,$33
        .byte   $F0,$02,$06,$33,$43,$53,$F0,$02
        .byte   $0C,$43,$53,$04,$F0,$02,$12,$5B
        .byte   $0C,$1C,$F0,$02,$18,$78,$1C,$68
        .byte   $1C,$1C,$1C,$78,$1C,$E8
AudioSequence02:
        .byte   $03,$10
        .byte   $7F,$08,$78,$1A,$68,$1A,$F1,$03
        .byte   $07,$78,$32,$68,$32,$F1,$03,$0E
        .byte   $78,$42,$68,$42,$F1,$03,$15,$5A
        .byte   $F1,$03,$19,$0B,$F1,$03,$1D,$78
        .byte   $52,$68,$52,$F1,$03,$24,$78,$52
        .byte   $E8
AudioSequence03:
        .byte   $02,$81,$7F,$40,$78,$51,$68
        .byte   $51,$F2,$03,$07,$78,$0A,$68,$0A
        .byte   $F2,$03,$0E,$78,$1A,$68,$1A,$F2
        .byte   $03,$15,$32,$F2,$03,$19,$42,$F2
        .byte   $03,$1D,$78,$3A,$68,$3A,$F2,$03
        .byte   $24,$78,$3A,$E8
AudioSequence07:
        .byte   $04,$1F,$7F,$30
        .byte   $0A,$62,$49,$49,$EA,$1E,$49,$49
        .byte   $EA,$1D,$49,$49,$EA,$1C,$49,$49
        .byte   $EA,$1B,$49,$49,$EA,$1A,$49,$EA
        .byte   $19,$49,$EA,$18,$49,$E8
AudioSequence08:
        .byte   $02,$1F
        .byte   $7F,$30,$62,$00,$01,$00,$EA,$1E
        .byte   $01,$00,$EA,$1D,$01,$00,$01,$00
        .byte   $EA,$1C,$01,$EA,$1B,$00,$EA,$1A
        .byte   $01,$EA,$19,$00,$E8
AudioSequence11:
        .byte   $02,$20,$7F
        .byte   $30,$63,$1A,$12,$51,$31,$19,$11
        .byte   $50,$30,$18,$E8
AudioSequence10:
        .byte   $04,$1F,$7F,$40
        .byte   $0A,$62,$51,$EA,$1E,$51,$EA,$08
        .byte   $6A,$51,$E8
AudioSequence15:
        .byte   $01,$8F,$82,$10,$6F
        .byte   $2C,$E8
AudioSequence06:
        .byte   $02,$80,$7F,$40,$63,$52
        .byte   $1B,$3B,$53,$4A,$13,$33,$4B,$1B
        .byte   $3B,$53,$1C,$3C,$E8
AudioSequence00:
        .byte   $02,$82,$7F
        .byte   $40,$64,$1B,$2B,$3B,$1C,$2C,$3C
        .byte   $6C,$53,$E8
AudioSequence27:
        .byte   $02,$82,$7F,$40,$63
        .byte   $53,$1B,$1C,$3B,$3C,$53,$6A,$54
        .byte   $E8
AudioSequence09:
        .byte   $02,$60,$7F,$40,$64,$52,$3A
        .byte   $52,$03,$52,$03,$13,$1B,$E8
AudioSequence13:
        .byte   $02
        .byte   $D5,$7F,$00,$62,$1C,$1D,$E8
AudioSequence12:
        .byte   $03
        .byte   $07,$7F,$08,$61,$3A,$13,$22,$E8
AudioSequence14:
        .byte   $02,$40,$7F,$00,$61,$3D,$62,$45
        .byte   $EA,$10,$28,$E8
AudioSequence19:
        .byte   $02,$80,$7F,$18
        .byte   $61,$39,$E8
AudioSequence20:
        .byte   $04,$00,$7F,$28,$0A
        .byte   $61,$28,$E8
AudioSequence18:
        .byte   $02,$8C,$94,$40,$61
        .byte   $10,$64,$18,$F9,$05
AudioSequence17:
        .byte   $02,$80,$94
        .byte   $48,$62,$40,$48,$F9,$05
AudioSequence16:
        .byte   $01,$1F
        .byte   $7F,$28,$61,$22,$42,$5A,$1B,$E8
AudioSequence04:
        .byte   $01,$A0,$7F,$40,$66,$1C,$3C,$1C
        .byte   $53,$1C,$3C,$05,$72,$54,$E8
AudioSequence05:
        .byte   $02
        .byte   $90,$7F,$40,$62,$38,$66,$EA,$20
        .byte   $3B,$53,$3B,$1B,$3B,$53,$1C,$6A
        .byte   $14,$E8
AudioSequence21:
        .byte   $01,$B8,$7F,$40,$EF,$65
        .byte   $0C,$53,$F0,$0C,$05,$0C,$53,$F0
        .byte   $0C,$0B,$34,$24,$F0,$08,$10,$EA
        .byte   $30,$B0,$50,$EA,$20,$9C,$54,$E8
AudioSequence22:
        .byte   $02,$B8,$7F,$40,$65,$43,$33,$F1
        .byte   $0C,$04,$43,$33,$F1,$0C,$0A,$14
        .byte   $4B,$F1,$08,$0F,$EA,$3A,$30,$50
        .byte   $09,$29,$31,$51,$0A,$2A,$32,$52
        .byte   $0B,$2B,$33,$53,$0C,$2C,$9C,$EA
        .byte   $20,$2C,$E8
AudioSequence23:
        .byte   $03,$00,$7F,$08,$A1
        .byte   $01,$01,$EE,$15,$6A,$0B,$0B,$0B
        .byte   $EE,$22,$6F,$33,$65,$43,$7E,$EE
        .byte   $33,$53,$6A,$EE,$15,$43,$33,$53
        .byte   $6F,$EE,$22,$13,$65,$23,$7E,$EE
        .byte   $33,$33,$6A,$EE,$15,$23,$13,$4A
        .byte   $9C,$EE,$FF,$32,$E8
AudioSequence24:
        .byte   $01,$42,$7F
        .byte   $40,$66,$1B,$0B,$78,$1B,$68,$52
        .byte   $42,$32,$1A,$1A,$1A,$78,$1A,$E8
AudioSequence25:
        .byte   $02,$82,$7F,$40,$66,$52,$52,$78
        .byte   $52,$68,$32,$2A,$12,$1A,$1A,$1A
        .byte   $78,$1A,$E8
AudioSequence26:
        .byte   $03,$10,$7F,$08,$66
        .byte   $3B,$33,$78,$3B,$68,$1B,$0B,$52
        .byte   $52,$52,$52,$78,$52,$E8,$FF
