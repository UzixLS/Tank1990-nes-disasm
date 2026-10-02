; Сохранённый trampoline максимального улучшения ($EA0F-$EA11).

; Статических ссылок нет. Это трёхбайтовый tail-trampoline: JMP не
; трогает стек, а RTS из SetMaximumObjectUpgrade использует return address
; исходного JSR к этому entry. Вход через JMP тоже возможен только если на
; стеке уже лежит валидный RTS-address; прямой аппаратный переход без него опасен.
;
; Вход: X=слот, upper-bound check нет. Цель писать ObjectAttributes,X=$63;
; для player slots X=0/1 также PlayerUpgradeLevel,X=$63, для любого X>=2
; PlayerUpgradeLevel не трогает. PlayerExtendedUpgrade не меняется.
; Выход: A=$63; X/Y сохранены; flags от CPX #2: для X=0/1 C=0,N=1,
; для X=2 C=1,Z=1, для штатных X>2 C=1,N=Z=0; V сохранён.
SetMaximumObjectUpgradeTrampoline:
UnreferencedMaximumUpgradeTrampoline:
LEA0F:
        jmp     SetMaximumObjectUpgrade
