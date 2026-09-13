; Сохранённый trampoline максимального улучшения ($EA0F-$EA11).

; Статических ссылок нет. Это хвостовой адаптер без собственного stack frame;
; входы, выходы и побочные эффекты полностью совпадают с SetMaximumObjectUpgrade.
UnreferencedMaximumUpgradeTrampoline:
LEA0F:
        jmp     SetMaximumObjectUpgrade
