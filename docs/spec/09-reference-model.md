# Эталонная модель реализации

## Цель модели

Эта глава сводит правила в алгоритм, который можно прямо перенести в C, C++, Rust, JavaScript, Python или игровой движок. Это не эмулятор 6502: состояние названо по смыслу, а вывод отделён от логики.

Основной принцип — фиксированный логический такт и целочисленное состояние. Отрисовка может происходить с любой частотой, но не должна менять результат симуляции.

## Минимальное состояние

```text
Game:
    frameCounter, slowFrameCounter: u8
    battleState: u8
    paused: bool
    variant: u8                  # 00..06 или 80..86
    allPowerUps: bool
    playerMode: 1P | 2P | combinedFire
    stageNumber, stageSetLength: u8
    enemiesToSpawn, enemiesRemaining: u8
    enemyActivityInterval: u8
    enemyFreezeTimer, baseFortificationTimer: u8
    terrain[30][32]: u8
    tanks[8]: Tank
    projectiles[10]: Projectile
    players[2]: Player
    powerUp: PowerUp
    scores[3][7]: digit          # P1, P2, high score
    killCounts[2][4]: u8
    rngState, rngIndex: u8

Tank:
    state, x, y, attributes, special: u8
    lifecycleTimer, iceTimer: u8

Player:
    lives: u8
    upgrade: u8                  # 00,20,40,60 или 63
    extendedUpgrade: u8
    shieldTimer, stunTimer: u8
    scoreLifeAwarded: bool

Projectile:
    state, x, y, flags: u8

PowerUp:
    x, y, type, pickupMarkerTimer: u8
```

`powerUp.x == 0` означает отсутствие объекта. Реализация МОЖЕТ хранить карту как 13×13 метатайлов и отдельную маску повреждений, но все пробы должны давать те же 8×8/4×4 результаты, что развёрнутый `terrain`.

## Системный цикл

```text
accumulator += realElapsed
while accumulator >= 1 / 60.0988:
    sampleControllers()
    simulateOneFrame()
    accumulator -= 1 / 60.0988

render(interpolation = 0)        # оригинал не интерполирует позиции
```

При нестабильной производительности число догоняющих тактов следует ограничить, но нельзя растягивать один такт произвольным `deltaTime`.

## Один кадр

```text
function simulateOneFrame():
    pressed[p] = held[p] & ~previousHeld[p]
    previousHeld[p] = held[p]
    audio.tick()
    frameCounter = u8(frameCounter + 1)
    if (frameCounter & 0x3f) == 0:
        slowFrameCounter = u8(slowFrameCounter + 1)
        tickSlowTimers()

    if screen != BATTLE:
        updateCurrentScreen()
        return

    if not paused:
        battleTick()

    buildPowerUpSprites()
    buildProjectileSprites()
    buildTankSprites()
    buildPauseAndTransitionSprites()

    if pressed[P1] contains START:
        paused = not paused

    evaluateStageOutcomeAtOriginalBoundary()
```

Для покадрового сравнения `tickSlowTimers()` следует вызывать в тех же экранных состояниях, что оригинальные consumers, а не централизовать абсолютно все таймеры. Псевдокод показывает игровое намерение.

## Медленные таймеры

```text
function tickSlowTimers():
    if enemyFreezeTimer > 0:
        enemyFreezeTimer -= 1

    for player in players:
        if player.shieldTimer > 0:
            player.shieldTimer -= 1

    if baseFortificationTimer > 0:
        baseFortificationTimer -= 1
        if baseFortificationTimer in {3, 2, 1}:
            drawSteelOrBrickBy(frameCounter bit 4)
        if baseFortificationTimer == 0:
            drawBrickBaseEnclosure()
```

Оглушение игроков сюда не входит: оно уменьшается при обслуживании их слотов.

## Боевое обновление

```text
function battleTick():
    markTankOccupiedTiles()
    updatePlayerInputs()
    updateAllTanks()
    clearTankOccupiedTiles()

    updateExistingProjectiles()
    updateDestroyedBaseEffect()
    updateShieldEffects()

    tryPlayerFire(P1)
    tryPlayerFire(P2)
    tryEnemyFire()
    trySpawnPendingEnemy()

    collideProjectilesWithTerrain()
    collideProjectilePairs()
    collideProjectilesWithTanks()
    updatePowerUpPickup()

    updateGameOverTransition()
    updateMovementAudio()
    updateLivesHud()
    updateTank1990Extensions()
```

Не объединяйте движение с коллизией «на лету»: все танки используют snapshot занятости начала такта, а все снаряды сначала перемещаются и только затем разрешают три категории столкновений.

## Обслуживание танков

```text
function shouldServiceTank(slot):
    if slot < 2:
        return (frameCounter & 3) != 2
    if highClass(tanks[slot].attributes) == 0xa0:
        return true
    return ((slot ^ frameCounter) & 1) != 0

function updateAllTanks():
    for slot in 0..7 in original slot order:
        tank = tanks[slot]
        if tank.state == 0 or not shouldServiceTank(slot):
            continue
        class = tank.state >> 4
        if slot >= 2 and enemyFreezeTimer != 0 and class in 8..13:
            continue
        dispatchTankState(slot, class)
```

`dispatchTankState` реализует таблицу классов из главы 4. Класс выбора цели `B/C/D` только записывает новый активный класс; он не вызывает движение рекурсивно в том же такте.

## Попытка шага танка

```text
function tryMoveTank(slot, direction):
    nextX = u8(tank.x + DX[direction])
    nextY = u8(tank.y + DY[direction])

    for offset in FRONT_POINTS[direction]:
        px = u8(nextX + offset.x)
        py = u8(nextY + offset.y)
        tile = terrain[py >> 3][px >> 3]
        if tile & 0x80:
            return BLOCKED
        if tile < 0x20 and not (tank.special != 0 and tile == 0x12):
            return BLOCKED

    tank.x = nextX
    tank.y = nextY
    return MOVED
```

Перед перпендикулярным поворотом выровняйте вторую координату формулой `(v+4)&0xF8` и только затем проверяйте шаг.

## Выбор ИИ

```text
function chooseEnemyMode(slot):
    E = enemyActivityInterval
    S = slowFrameCounter
    if S <= floor(E / 8):
        tanks[slot].state = 0xa0 | (nextRandom() & 3)
    elif S <= floor(E / 4):
        target = selectPlayerBySlotParity(slot)
        tanks[slot].state = classFor(target) | oldDirection(slot)
    else:
        tanks[slot].state = 0xb0 | oldDirection(slot)

function chooseDirectionToward(slot, targetX, targetY):
    relation = relation3(targetX, tank.x) + 3 * relation3(targetY, tank.y)
    horizontal = nextRandom() & 1
    tanks[slot].state = DIRECTION_MATRIX[horizontal][relation]
```

При выровненной позиции новый выбор режима происходит, если `(nextRandom() & 0x0f) == 0`. Стрельба — отдельный вызов PRNG и отдельная проверка `(random & 0x1f) == 0`.

## Создание и движение снаряда

```text
function createProjectile(projectileSlot, tankSlot):
    if projectiles[projectileSlot].state != 0:
        return false
    d = tanks[tankSlot].state & 3
    projectile.state = 0x40 | d
    projectile.x = u8(tank.x + 8 * DX[d])
    projectile.y = u8(tank.y + 8 * DY[d])
    projectile.flags = decodeProjectileFlags(tank.attributes, variant)
    return true

function updateExistingProjectiles():
    for slot in projectileUpdateOrder:
        p = projectiles[slot]
        if highClass(p.state) == 4:
            speed = 4 if p.flags.fast else 2
            d = p.state & 3
            p.x = u8(p.x + speed * DX[d])
            p.y = u8(p.y + speed * DY[d])
        elif p.state != 0:
            advanceImpactState(p)
```

Двойной выстрел игрока сначала переносит занятый основной слот в свободный дополнительный, затем создаёт новый в основном. После движения выполняются три отдельные фазы коллизий. Более поздняя фаза принимает только класс `0x40`, но оставшиеся точки одной terrain-пробы могут выполниться после первого impact.

## Повреждение объектов

```text
function hitPlayer(playerSlot, projectileSlot):
    if players[playerSlot].shieldTimer != 0:
        projectiles[projectileSlot].state = 0
    elif tanks[playerSlot].special != 0:
        tanks[playerSlot].special = 0
        projectiles[projectileSlot].state = 0x33
    elif players[playerSlot].upgrade == 0x63:
        players[playerSlot].upgrade = 0x40
        tanks[playerSlot].attributes = 0x40
        projectiles[projectileSlot].state = 0x33
        requestSound(ARMOR)
    else:
        projectiles[projectileSlot].state = 0x33
        destroyTank(playerSlot)
        players[playerSlot].upgrade = 0x20 if isExtended(variant) else 0

function hitEnemy(enemySlot, projectileSlot):
    projectiles[projectileSlot].state = 0x33
    a = tanks[enemySlot].attributes
    if a & 4:
        spawnPowerUp()
        if a == 0xe4:
            a = u8(a - 1)
    if (a & 3) != 0:
        tanks[enemySlot].attributes = u8(a - 1)
        requestSound(ARMOR)
    else:
        type = (a >> 5) - 4
        owner = projectileSlot & 1
        destroyTank(enemySlot)
        killCounts[owner][type] += 1
        if stageSetLength != 2:
            addScore(owner, [100,200,300,400][type])
```

## Появление противников

```text
function trySpawnPendingEnemy():
    if enemiesToSpawn == 0:
        return
    if enemySpawnTimer != 0:
        enemySpawnTimer -= 1
        return
    slot = firstAvailableEnemySlot()
    if slot == NONE:
        return
    spawnPoint = nextOf(center, right, left)
    enemySpawnTimer = enemyActivityInterval
    initializeEnemy(slot, spawnPoint)
    enemiesToSpawn -= 1
    clearOneEnemyHudMarker()
```

Диапазон доступных слотов 2..5 / 2..6 / 2..7 сам задаёт предел 4/5/6 противников. Проверки занятости точки нет; spawn очищает там 16×16 местности. Инициализация активного состояния после 28 обслуживаний расходует PRNG в порядке тип, носитель, HP. `enemiesRemaining` включает появившихся и ожидающих противников и уменьшается после конца уничтожения.

## Бонус

```text
function spawnPowerUp():
    repeat:
        x = [48,96,144,192][nextRandom() & 3]
        y = [48,96,144,192][nextRandom() & 3]
    until noEligibleCollectorWithin12(x, y)
    raw = nextRandom() & 7
    type = raw if allPowerUps else [0,1,2,3,3,4,5,6][raw]
    powerUp = {x, y, type, pickupMarkerTimer: 0}

function updatePowerUpPickup():
    if powerUp.x == 0 or powerUp.pickupMarkerTimer != 0:
        return
    slots = [1,0] if not isExtended(variant) else [7,6,5,4,3,2,1,0]
    for slot in slots:
        if targetable(tanks[slot]) and within12(tank, powerUp):
            powerUp.pickupMarkerTimer = 0x32
            if slot < 2:
                addScore(slot, 500)
            applyPowerUp(type, slot)
            return
```

Эффекты реализуйте буквально по таблице главы 6, особенно их глобальные действия над неактивными вражескими слотами.

## Передача жизни

В конце боевого такта `updateTank1990Extensions()` выполняет:

```text
if twoPlayerMode:
    if players[P2].lives != 0:
        if players[P2].lives >= 2 and players[P1].lives == 0 and held[P1].A:
            players[P1].lives += 1
            players[P2].lives -= 1
            spawnPlayerImmediately(P1)
    else:
        if players[P1].lives >= 2 and held[P2].A:
            players[P2].lives += 1
            players[P1].lives -= 1
            spawnPlayerImmediately(P2)
```

Проверка состояния танка не заменяет проверку счётчика жизней. Spawn не проверяет занятость клетки.

## Счёт и дополнительная жизнь

```text
function addScore(player, amount):
    addDecimalDigitsModulo10M(scores[player], amount)
    if battleIsActive and not players[player].scoreLifeAwarded:
        if scores[player].tenThousandsDigit >= 2:
            players[player].lives = u8(players[player].lives + 1)
            players[player].scoreLifeAwarded = true
            requestSound(EXTRA_LIFE)
```

Не используйте обычное условие `score >= 20000`, если нужна точная совместимость: оригинал проверяет конкретную цифру после каждой награды.

## Разделение логики и представления

```text
Input -> Fixed-step Simulation -> Render Snapshot -> Renderer
                         |
                         +-> Audio event requests -> Stream mixer
```

Renderer не должен менять игровые координаты, таймеры или порядок PRNG. Аудио не решает, произошло ли событие: симуляция отправляет идентификаторы уже совершившихся событий.

Для replay сохраняйте начальный seed/снимок нулевой страницы и по кадрам маски двух контроллеров. Для игровой совместимости достаточно собственного seed. Для покадровой нужны полное начальное состояние и исходный feedback-PRNG.
