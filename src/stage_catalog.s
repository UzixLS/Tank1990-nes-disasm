; Описатели наборов классических этапов ($E42B-$E440).

ClassicLevelSubsetCount    = 12
ClassicLevelCatalogCount   = 36
ClassicLevelSubsetByteSize = ClassicLevelSubsetCount * PackedStageByteSize
ClassicLevelDescriptorSize = 3
ClassicLevelDescriptorCount = 7

; Семь fixed-size записей [word base, byte count], индексируемых как 3*selector
; без bounds check. Selectors 0/3, 1/4 и 2/5 повторяют три последовательные
; группы по 12 карт; selector 6 указывает на начало и length=36.
;
; Все семь bases находятся только внутри ClassicLevels. TankLevels не
; является runtime map catalog для LoadAndDrawStage. Важное
; layout-ограничение: loader прибавляет к base фазу 0/2/4 до шага по 91 byte,
; поэтому окна могут пересекать границы соседних записей/подмножеств, а крайнее
; окно третьей группы/полного каталога — читать до четырёх следующих ROM bytes.
; Перестановка карт, изменение stride/count или bytes после ClassicLevels должны
; учитывать эту формулу, а не только три word pointers.
ClassicLevelSetDescriptors:
LE42B:  .word   ClassicLevels
        .byte   ClassicLevelSubsetCount
        .word   ClassicLevels + ClassicLevelSubsetByteSize
        .byte   ClassicLevelSubsetCount
        .word   ClassicLevels + 2 * ClassicLevelSubsetByteSize
        .byte   ClassicLevelSubsetCount
        .word   ClassicLevels
        .byte   ClassicLevelSubsetCount
        .word   ClassicLevels + ClassicLevelSubsetByteSize
        .byte   ClassicLevelSubsetCount
        .word   ClassicLevels + 2 * ClassicLevelSubsetByteSize
        .byte   ClassicLevelSubsetCount
        .word   ClassicLevels
        .byte   ClassicLevelCatalogCount
; Отдельный байт после семи описателей; в таблицу не входит. При ошибочном
; selector=7 loader использовал бы его как low byte указателя. Статических
; ссылок и самостоятельного назначения не найдено.
UnreferencedE440Byte:
LE440:  .byte   $8B
