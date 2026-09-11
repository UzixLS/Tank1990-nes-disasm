; Сохранённый адаптер состояния улучшения ($EA39-$EA44).

; Неиспользуемый напрямую адаптер: очищает $0178,X, загружает $0101,X
; и передаёт управление MergeTankAttributeBits.
; Меняет A, ObjectAttributes/ObjectFrame и $0178,X; X/Y сохраняются.
ClearUpgradeExtensionAndRefreshAttributes:
LEA39:  lda     #$00
        sta     PlayerExtendedUpgrade,x
        lda     PlayerUpgradeLevel,x
        jmp     MergeTankAttributeBits

; Сохранённый недостижимый байт после хвостового JMP MergeTankAttributeBits;
; следующий адрес $EA45 является самостоятельным entry point. Ссылок нет.
UnreferencedEa44Byte:
LEA44:  .byte   $03
