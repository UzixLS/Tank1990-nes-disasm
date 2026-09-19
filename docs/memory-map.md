# Карта ROM

| Файл | CPU/PPU | Размер | Содержимое |
|---|---:|---:|---|
| `$0000` | — | `$0010` | iNES-заголовок |
| `$0010` | `$8000` | `$238C` | 100 карт Tank 1990 по `$5B` байт |
| `$239C` | `$A38C` | `$01C7` | 5 дополнительных карт по `$5B` байт |
| `$2563` | `$A553` | `$1AAD` | расширения кода, неиспользуемая карта и таблицы |
| `$4010` | `$C000` | `$3022` | основной код и данные |
| `$7032` | `$F022` | `$000E` | неиспользуемый префикс: две строки формата карты |
| `$7040` | `$F030` | `$0CCC` | 36 классических карт по `$5B` байт |
| `$7D0C` | `$FCFC` | `$0304` | дополнительный код, padding и векторы |
| `$8010` | PPU `$0000` | `$1000` | sprite pattern table |
| `$9010` | PPU `$1000` | `$1000` | background pattern table |

## Модули исполняемого банка

| CPU-адреса | Исходник | Назначение |
|---:|---|---|
| `$C000-$C9BF` | `src/game_flow.s` | адресный контейнер игрового потока |
| `$C9C0-$D3FF` | `src/screens.s` | меню, заставки, таблицы экранов и статистика |
| `$D400-$DB0A` | `src/ppu.s` | адресный контейнер кадровых и PPU-подсистем |
| `$DB0B-$E02D` | `src/tanks.s` | адресный контейнер подсистем танков |
| `$E02E-$E603` | `src/projectiles.s` | снаряды и физически соседние игровые подсистемы |
| `$E604-$EA50` | `src/collisions.s` | столкновения и физически соседние данные/подсистемы |
| `$EA51-$EF75` | `src/audio.s` | контейнер аудиодвижка и его данных |
| `$EF76-$F021` | `src/stage_loader.s` | выбор, распаковка и отрисовка карты этапа |
| `$FCFC-$FFFF` | `src/prg1_hi.s` | контейнер верхнего банка, расширения и векторы |

`src/prg1_lo.s` только подключает модули непрерывной области `$C000-$F021` в
исходном порядке; помещать новую логику непосредственно в него не следует.

### Смысловые include-модули

Эти файлы включены в прежних физических позициях. Они не создают новые
сегменты и не меняют порядок байтов, но отделяют игровые подсистемы от
случайного соседства в ROM.

| CPU-адреса | Исходник | Назначение |
|---:|---|---|
| `$A38C-$A552` | `src/extra_levels.s` | пять дополнительных карт |
| `$A553-$A73C` | `src/prg0_extensions.s` | активные расширения Tank 1990 |
| `$A73D-$BF7F` | `src/prg0_unreferenced_data.s` | неподтверждённые таблицы и заполнение |
| `$BF80-$BF83` | `src/deferred_integrity_bridge.s` | мост к отложенной проверке checksum |
| `$BF84-$BFFF` | `src/prg0_extension_prototypes.s` | неиспользуемые прототипы расширений |
| `$C000-$C0AD` | `src/startup.s` | boot hook, reset и frontend loop |
| `$C03A-$C056` | `src/decimal.s` | преобразование байта в десятичные цифры |
| `$C0AE-$C158` | `src/construction_editor.s` | основной цикл редактора Construction |
| `$C159-$C2B2` | `src/battle_flow.s` | выбор этапа, бой и разбор результата |
| `$C2B3-$C2E5` | `src/session_init.s` | инициализация новой сессии |
| `$C2E6-$C330` | `src/gameplay_tick.s` | один logic tick и полусекундная фаза |
| `$C331-$C3B4` | `src/stage_runtime.s` | runtime-состояние выбранного этапа |
| `$C3B5-$C44A` | `src/attract_mode.s` | подготовка и цикл демонстрации |
| `$C44B-$C49B` | `src/new_high_score.s` | экран нового рекорда |
| `$C49C-$C59C` | `src/variant_selection.s` | boot marker и выбор варианта |
| `$C59D-$C5D8` | `src/gameplay_runtime_data.s` | runtime-таблицы игрового потока |
| `$C5D9-$C641` | `src/flow_helpers.s` | общие helpers потока и усилений |
| `$C5F3-$C626` | `src/powerup_flow.s` | выбор типа и эффекты усилений 3/6 |
| `$C642-$C6C5` | `src/attract_ai.s` | генерация ввода для attract mode |
| `$C6C6-$C71D` | `src/construction_cursor.s` | отрисовка и движение курсора Construction |
| `$C71E-$C754` | `src/stage_outcome.s` | счётчики и условие завершения этапа |
| `$C755-$C7C7` | `src/frontend_misc.s` | сохранённый RAM inspector и заставка |
| `$C7C8-$C8CF` | `src/battle_hud_runtime.s` | жизни, номер этапа и маркеры врагов |
| `$C8D0-$C8F8` | `src/construction_cursor_bounds.s` | границы курсора Construction |
| `$C8F9-$C9BF` | `src/battle_overlays.s` | pause, переходный объект и рамка поля |
| `$C9C0-$CA90` | `src/title_menu.s` | логика главного меню и курсора |
| `$CA91-$CAF4` | `src/battle_hud.s` | номер этапа в HUD |
| `$CAF5-$CC26` | `src/base_render.s` | база, кирпичное и стальное ограждение |
| `$CC27-$CCD3` | `src/screen_transitions.s` | строки nametable и экранная шторка |
| `$CCD4-$D137` | `src/stage_statistics.s` | послеэтапная статистика и её анимация |
| `$D138-$D169` | `src/score_rewards.s` | дополнительные жизни за порог счёта |
| `$D16A-$D254` | `src/title_render.s` | построение nametable заглавного экрана |
| `$D255-$D275` | `src/legacy_screen_stream.s` | адаптер неидентифицированных экранных потоков |
| `$D276-$D283` | `src/statistics_delay.s` | задержка с перерисовкой иконок статистики |
| `$D284-$D2F7` | `src/screen_text_data.s` | строки заглавного экрана и статистики |
| `$D2F8-$D333` | `src/runtime_checksum_init.s` | подготовка runtime-проверки суммы |
| `$D334-$D34C` | `src/screen_misc_text.s` | служебные и нераспознанные строки |
| `$D34D-$D357` | `src/remainder.s` | остаток от деления байта на шесть |
| `$D358-$D3D4` | `src/battle_ui_data.s` | данные HUD, базы и статистики |
| `$D3D5-$D3DC` | `src/direction_tables.s` | единичные смещения по направлениям |
| `$D3E0-$D3FC` | `src/powerup_effect0.s` | обработчик усиления 0 |
| `$D400-$D44C` | `src/nmi.s` | кадровый NMI и вызов кадровых подсистем |
| `$D44D-$D466` | `src/random.s` | генератор псевдослучайных байтов |
| `$D467-$D490` | `src/ppu_display.s` | управление NMI, рендеринг и очистка nametable shadow |
| `$D491-$D501` | `src/runtime_init.s` | инициализация общей RAM и restart signature |
| `$D502-$D5FA` | `src/palette.s` | палитры и ожидание vblank |
| `$D5FB-$D688` | `src/ppu_attributes.s` | адресация shadow и attribute table |
| `$D689-$D6B2` | `src/input.s` | чтение двух контроллеров |
| `$D6B3-$D705` | `src/ppu_queues.s` | строковые команды PPU |
| `$D706-$D7B3` | `src/terrain_shadow.s` | подобласти collision/terrain shadow |
| `$D7B4-$D80A` | `src/nametable_shadow.s` | передача и инициализация nametable shadow |
| `$D80B-$D85D` | `src/metatile_render.s` | отрисовка TSA-метатайлов |
| `$D85E-$D8F5` | `src/chr_raster.s` | CHR-растр для collision shadow |
| `$D8F6-$D933` | `src/ppu_sync.s` | ожидание кадра и сброс PPU-очереди |
| `$D934-$DA2A` | `src/score.s` | десятичные записи счёта и high score |
| `$DA2B-$DAAE` | `src/oam.s` | построение спрайтов в OAM shadow |
| `$DAAF-$DABA` | `src/math.s` | нормализация знака разности |
| `$DABB-$DB0A` | `src/metatile_data.s` | палитры и тайлы TSA-метатайлов |
| `$DB0B-$DB47` | `src/tank_player_audio.s` | звук движения танков игроков |
| `$DB48-$DB74` | `src/enemy_tank_spawn.s` | интервалы появления противников |
| `$DB75-$DBF0` | `src/tank_player_input.s` | ввод, поворот и общие no-op handlers |
| `$DBF1-$DC51` | `src/tank_update.s` | диспетчер обновления танков |
| `$DC52-$DD7D` | `src/tank_navigation.s` | движение и terrain-пробы |
| `$DD7E-$DDE9` | `src/tank_targeting.s` | наведение противников |
| `$DDEA-$DE71` | `src/tank_lifecycle.s` | уничтожение и состояния танков |
| `$DE72-$DEA5` | `src/enemy_tank_ai.s` | выбор действий противника |
| `$DEA6-$E02D` | `src/tank_render.s` | кадры и построение спрайтов танков |
| `$E181-$E23A` | `src/tank_occupancy.s` | занятость клеток танками и обнаружение льда |
| `$E23B-$E362` | `src/battle_effects.s` | усиление на поле, щит игроков и эффекты базы |
| `$E363-$E3B7` | `src/tank_spawn.s` | создание танка в слоте |
| `$E3B8-$E3C8` | `src/powerup_effect1.s` | обработчик усиления 1 |
| `$E3C9-$E3EE` | `src/variant_ui_logic.s` | атрибуты игрока и заголовок варианта |
| `$E3EF-$E42A` | `src/object_state_helpers.s` | сброс и изменение состояний объектов |
| `$E42B-$E440` | `src/stage_catalog.s` | описатели наборов классических этапов |
| `$E441-$E450` | `src/variant_metadata_helpers.s` | сохранённый helper variant-метаданных |
| `$E451-$E46B` | `src/input_direction.s` | преобразование D-pad в направление |
| `$E46C-$E4D7` | `src/tank_tables.s` | векторы, spawn-данные и dispatch танков |
| `$E4EC-$E55A` | `src/tank_init.s` | начальные поля и атрибуты танка |
| `$E55B-$E567` | `src/powerup_pickup_entry.s` | выбор диапазона сборщиков усиления |
| `$E568-$E56F` | `src/score_awards.s` | начисление подготовленного счёта игроку |
| `$E570-$E603` | `src/variant_ui_data.s` | строки заголовка и меню вариантов |
| `$E604-$E70B` | `src/projectile_terrain_collisions.s` | столкновения снарядов с местностью |
| `$E70C-$E83F` | `src/projectile_tank_collisions.s` | попадания снарядов в игроков и врагов |
| `$E840-$E8B9` | `src/variant_menu_data.s` | строки скрытого меню вариантов |
| `$E8BA-$E8BD` | `src/enemy_score_awards.s` | награды за типы противников |
| `$E8BE-$E90F` | `src/powerup_spawn.s` | выбор координат и типа усиления |
| `$E910-$E971` | `src/projectile_pair_collisions.s` | столкновения снарядов между собой |
| `$E972-$E9F1` | `src/powerup_pickup.s` | подбор и диспетчеризация усиления |
| `$E9F2-$EA0E` | `src/stage_selection_helpers.s` | изменение номера выбранного этапа |
| `$EA0F-$EA11` | `src/maximum_upgrade_trampoline.s` | сохранённый trampoline улучшения |
| `$EA12-$EA38` | `src/projectile_terrain_classifier.s` | variant-классификация terrain tile |
| `$EA39-$EA44` | `src/upgrade_state_helper.s` | сохранённый адаптер улучшения |
| `$EA45-$EA48` | `src/audio_state_helper.s` | адаптер состояния аудиопотока |
| `$EA49-$EA50` | `src/projectile_direction_tables.s` | векторы направления снаряда |
| `$EA51-$ECE5` | `src/audio_engine.s` | интерпретатор и маршрутизация потоков APU |
| `$ECE6-$EF75` | `src/audio_data.s` | периоды, указатели и байткод аудиопотоков |
| `$FCFC-$FD93` | `src/frontend_extensions.s` | расширения меню и секретное продолжение |
| `$FD94-$FDB0` | `src/runtime_integrity.s` | отложенная runtime-проверка суммы |
| `$FDB1-$FEAC` | `src/powerup_effects_hi.s` | эффекты усилений 2–5/7 и максимальное улучшение |
| `$FEAD-$FF65` | `src/tank1990_extensions.s` | отрисовка расширений, передача жизни и terrain routing |
| `$FF66-$FFC0` | `src/collision_extensions.s` | поглощение попадания и продолжения collision-pass |
| `$FFC1-$FFF0` | `src/projectile_variant.s` | свойства снаряда для варианта игры |

## Неиспользуемые данные PRG0

В диапазоне `$A73D-$BF7F` статических ссылок и подтверждённых точек входа нет.
Регулярные участки отделены от заполнения и размечены в
`src/prg0_unreferenced_data.s`:

- `$A780-$A7A7` — копии фрагментов расположенных ниже таблиц;
- `$A800-$A85A` — полноценная карта, вынесенная в
  `assets/levels/unused/001.map`;
- `$A900-$A9EF` — 12 структурированных записей по 20 байт;
- `$AA00-$B58B` — 12 выровненных таблиц по 140 байт с повторяющимися вариантами;
- `$BF84-$BFBF` — неиспользуемые прототипы/копии активного кода `$FF86-$FFBF`.

Наблюдаемый формат этих таблиц описан в комментариях без недоказанных игровых
названий. Возможность обращения к ним через вычисляемый указатель полностью
исключить нельзя.

Векторы: NMI `$D400`, RESET `$C070`, IRQ/BRK `$C070`.

Префикс `$F022-$F02F` корректно декодируется как две семибайтные строки
упакованной карты, но статических ссылок на него нет. Код загрузки и все
описатели выбирают первую классическую карту с `$F030`, поэтому происхождение
этих строк не устанавливается, а область намеренно не объединена с
редактируемыми картами.
