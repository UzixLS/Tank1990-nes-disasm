; Описатели наборов классических этапов ($E42B-$E440).

ClassicLevelSubsetCount    = 12
ClassicLevelCatalogCount   = 36
ClassicLevelSubsetByteSize = ClassicLevelSubsetCount * PackedStageByteSize

; Семь записей по 3 байта: word-указатель на первую карту и число карт.
; Для режимов 0..5 доступны группы по 12 классических карт; режим 6 использует все 36.
; Последний $8B не входит в семь описателей; его смысл не установлен.
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
; Отдельный байт после семи описателей; назначение и статические ссылки не найдены.
UnreferencedE440Byte:
LE440:  .byte   $8B
