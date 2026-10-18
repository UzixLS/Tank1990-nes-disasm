# Источники и достоверность

## Первичные материалы проекта

Первичный источник — образ `Tank 1990 (Ch).nes`:

```text
размер: 40976 bytes
SHA-256: ec453e7e3cc1d49d11d5860ced7f9e1235e2c7d33927bd6073b631754dc08dbb
```

`make verify` проверяет побайтовое совпадение сборки с ROM; `make test` — упаковку ассетов и работу загрузчика карт.

Связь разделов с исходным кодом:

| Область | Файлы реализации |
|---|---|
| платформа и кадр | `src/header.s`, `src/startup.s`, `src/nmi.s`, `src/ppu*.s` |
| главный такт | `src/gameplay_tick.s`, `src/battle_flow.s` |
| меню и варианты | `src/title_menu.s`, `src/variant_*.s`, `src/session_init.s` |
| уровни | `src/stage_catalog.s`, `src/stage_loader.s`, `src/levels.s` |
| танки | `src/tank_*.s`, `src/enemy_tank_*.s`, `src/attract_ai.s` |
| снаряды | `src/projectile*.s`, `src/collisions.s` |
| бонусы | `src/powerup_*.s`, `src/tank1990_extensions.s` |
| счёт и статистика | `src/score*.s`, `src/stage_statistics.s` |
| графика | `src/chr*.s`, `src/metatile*.s`, `src/palette.s`, `src/oam.s` |
| звук | `src/audio_engine.s`, `src/audio_data.s`, `docs/audio.md` |
| переменные и константы | `src/ram.inc`, `src/game.inc` |

`BC_SourceCode.asm` — полезный аннотированный референс исходной Battle City, но не источник различий Tank 1990. При несовпадении он уступает коду исследуемого образа.

## Нормативные данные

Из ROM извлечены и проходят round-trip тесты:

- `assets/chr/sprites.bmp` и `assets/chr/background.bmp`;
- `assets/palettes/*.pal`;
- `assets/metatiles/background.tsa`;
- `assets/levels/classic/*.map`.

Форматы и границы использования описаны в [нормативных данных](normative-data.md). Каталоги `assets/levels/extra` и `unused` сохранены для исследования, но штатный загрузчик данного ROM на них не ссылается.

## Внешние источники

Внешние материалы использованы для терминов, общего контекста и проверки правил исходной Battle City. Они не переопределяют исследуемый ROM.

- [Официальное руководство Battle City для Wii U Virtual Console](https://www.nintendo.co.jp/data/software/manual/man_FCTJ_00.pdf): управление, режимы 1P/2P/Construction, условия поражения, базовый смысл звезды, гранаты, часов, шлема, лопаты и танка.
- [Официальная страница Battle City для Wii Virtual Console](https://www.nintendo.co.jp/wii/vc/vc_bc/vc_bc_02.html): структура оригинальной игры.
- [NESdev: NROM](https://www.nesdev.org/wiki/NROM), [PPU](https://www.nesdev.org/wiki/PPU), [PPU frame timing](https://www.nesdev.org/wiki/PPU_frame_timing), [APU](https://www.nesdev.org/wiki/NES_APU): свойства платформы.
- [BootlegGames Wiki: Tank 1990](https://bootleggames.fandom.com/wiki/Tank_1990): распространённые названия дополнительных предметов и вариантов A–N.
- [MruczekWiki: Tank 1990](https://mruczek.wiki/Tank_1990): независимое описание вариантов, сдвинутых карт и эффектов предметов.
- [StrategyWiki: Battle City gameplay](https://strategywiki.org/wiki/Battle_City/Gameplay): вторичная сводка механик оригинала.
- [vgrichina/battlecity](https://github.com/vgrichina/battlecity): независимая реконструкция Battle City, использованная только для перекрёстной проверки терминов.

## Терминология

Код определяет эффект как специальное состояние: видимый маркер, проход по воде и поглощение одного попадания. Название **Boat/корабль** взято из устойчивой терминологии Tank 1990 [WEB, INF]. Само поведение подтверждено кодом [ROM].

## Границы проверки

Попиксельное совпадение экранов и совпадение семплов APU не проверены дифференциальным прогоном в эмуляторе. Для покадровой проверки нужны эталонные трассы ROM по сценариям [критериев приёмки](10-acceptance-tests.md).
