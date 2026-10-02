; Сохранённый адаптер состояния улучшения ($EA39-$EA44).

; Адаптер без статических ссылок для player slot X=0..1: очищает
; PlayerExtendedUpgrade,X, загружает PlayerUpgradeLevel,X и хвостовым JMP
; объединяет этот byte с текущим ObjectAttributes,X. Это OR-merge, не замена;
; точный raw=$E7 дополнительно нормализуется в $E4.
;
; Выход совпадает с MergeTankAttributeBits: A=0, N=0/Z=1, X/Y сохранены,
; C=1 iff raw merged attributes >=$E7 unsigned, V сохраняется. Меняет
; PlayerExtendedUpgrade,X, ObjectAttributes,X и ObjectFrame,X; base upgrade
; не меняет. Bounds check нет: X>=2 читает соседнюю RAM после двухбайтового
; PlayerUpgradeLevel и пишет за двухбайтовый PlayerExtendedUpgrade, поэтому
; этот entry нельзя расширять на enemy slots без изменения layout.
ClearUpgradeExtensionAndRefreshAttributes:
LEA39:  lda     #$00
        sta     PlayerExtendedUpgrade,x
        lda     PlayerUpgradeLevel,x
        jmp     MergeTankAttributeBits

; Сохранённый недостижимый байт после хвостового JMP MergeTankAttributeBits;
; следующий адрес $EA45 является самостоятельным entry point. Ссылок нет.
UnreferencedEa44Byte:
LEA44:  .byte   $03
