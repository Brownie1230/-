# 🐀 Крысиный Переполох / Rat Ruckus — игра для Roblox (версия 2)

**Жанр:** командная игра «крысы против повара».
Ночью в ресторане 2–7 крыс устраивают хаос, а повар (игрок или робот) пытается их переловить.

## ✨ Что есть в игре

**Крысы 🐀**
- Живые крысы: хвост виляет, лапки бегают, голова принюхивается, глаза блестят.
- **Шапки** из магазина (11 штук: кепка, ковбойская шляпа, тыква 🎃, корона 👑, нимб 😇...).
- **Мини-игры** при поломке: 🔌 соединить провода, 🦷 быстро грызть, 🔢 подобрать пароль, ⏱ нажать вовремя.
  Пока крыса играет в мини-игру, она стоит на месте, и повар может подкрасться!
- Бег (Shift), голод и сыр 🧀, **писк (Q)** (зовёт друзей, но повар его слышит!).
- **Крысиные лазейки** в стенах: крыса пролезает, повар нет. Плюс норки-телепорты.
- Спасение друзей из клетки.

**Повар 👨‍🍳**
- Сачок, **мышеловки**, ремонт, фонарик на колпаке, бег.
- Во время тревоги (хаос ≥ 75%) повар **в ярости** и бегает быстрее.
- Если игроков мало, играет **повар-робот**: видит крыс, слышит шум, чинит, ставит мышеловки.

**Атмосфера и эффекты**
- Ночной ресторан: лунный свет из окон, мерцающие свечи, камин, пылинки в свете ламп.
- Конфетти при поломке, тряска камеры, мигающий свет, когда перегрызли провода.
- 🚨 **Тревога**: красные лампы и красные края экрана.
- 💓 **Сердцебиение**: когда повар близко, края экрана пульсируют.
- Шаги повара слышно издалека.
- Отсчёт «3, 2, 1, ХАОС!», карточка роли, экран результатов, лучший игрок.

**🌍 Два языка: русский и английский**
- Язык выбирается автоматически по настройкам Roblox игрока.
- В лобби есть кнопка **🌐 English / Русский**.
- Все тексты в модуле `Locale`. Чтобы добавить язык, скопируй блок `en` и переведи.

**Прогресс**
- Сыр-монетки 🧀 за поломки, спасения, поимки и победы. Таблица игроков (Сыр / Победы).
- **Сохранение** монеток, побед и шапок между играми.

## 🎮 Управление

| | Крыса 🐀 | Повар 👨‍🍳 |
|---|---|---|
| Ходить / прыгать | WASD / Пробел | WASD / Пробел |
| Бег | Shift | Shift |
| Действие | **E**: напакостить / открыть клетку | **E**: починить |
| Особое | **Q**: пискнуть | **1**: сачок, **2**: мышеловка, клик: использовать |
| Задания | Tab | Tab |

На телефоне появляются кнопки 🏃 (бег) и 🐭 (писк).

---

## ⚡ Установка с нуля (12 скриптов)

1. Roblox Studio → **New** → **Baseplate**. Открой **View → Explorer**.
2. Создай скрипты **с точно такими именами** (наведи на папку → **⊕**):

| Где создать | Тип | Имя | Код |
|---|---|---|---|
| ReplicatedStorage | **ModuleScript** | `Config` | `src/ReplicatedStorage/Config.lua` |
| ReplicatedStorage | **ModuleScript** | `Locale` | `src/ReplicatedStorage/Locale.lua` |
| ServerScriptService | **Script** | `GameManager` | `src/ServerScriptService/GameManager.server.lua` |
| ServerScriptService | **ModuleScript** | `RatBuilder` | `src/ServerScriptService/RatBuilder.lua` |
| ServerScriptService | **ModuleScript** | `DataService` | `src/ServerScriptService/DataService.lua` |
| ServerScriptService | **ModuleScript** | `SabotageService` | `src/ServerScriptService/SabotageService.lua` |
| ServerScriptService | **ModuleScript** | `ChefService` | `src/ServerScriptService/ChefService.lua` |
| ServerScriptService | **ModuleScript** | `ChefAI` | `src/ServerScriptService/ChefAI.lua` |
| ServerScriptService | **ModuleScript** | `TestMapBuilder` | `src/ServerScriptService/TestMapBuilder.lua` |
| StarterPlayer → StarterPlayerScripts | **LocalScript** | `RatHUD` | `src/StarterPlayerScripts/RatHUD.client.lua` |
| StarterPlayer → StarterPlayerScripts | **LocalScript** | `Effects` | `src/StarterPlayerScripts/Effects.client.lua` |
| StarterPlayer → StarterPlayerScripts | **LocalScript** | `MiniGames` | `src/StarterPlayerScripts/MiniGames.client.lua` |

3. В каждый скрипт: **Cmd/Ctrl + A**, затем **Cmd/Ctrl + V** с кодом из файла.
4. Нажми **Play** ▶.

## 🔄 Обновление с версии 1

- **Заменить код** в 8 старых скриптах (двойной клик по скрипту, Cmd+A, Cmd+V).
- **Добавить 3 новых:** `DataService` (ModuleScript в ServerScriptService), `Effects` и `MiniGames` (LocalScript в StarterPlayerScripts).

## 💾 Чтобы сохранялись монетки и шапки

1. Опубликуй игру: **File → Publish to Roblox**.
2. **Home → Game Settings → Security** → включи **Enable Studio Access to API Services** → **Save**.

Без этого игра работает, просто прогресс не сохраняется (в Output будет жёлтое предупреждение).

## 💡 Советы

- **Lighting → Technology = Future**: так свет и тени будут гораздо красивее.
- **Музыка и сердцебиение**: в `Config` → `Config.Sounds` вставь ID звуков из Toolbox
  (правый клик по звуку → **Copy Asset ID** → `"rbxassetid://ЦИФРЫ"`).
- Баланс (скорости, награды, цены шапок) настраивается в `Config`.

---

## 🗺 Своя карта

Построй ресторан в папке **Workspace → `Map`**, и тестовая карта строиться не будет.
Скрипты находят объекты по **тегам** (Properties → Tags → `+`):

| Тег | На что ставить | Атрибуты |
|---|---|---|
| `Sabotage` | Деталь, которую ломают крысы | `TaskName` (рус.), `TaskNameEn` (англ.), `Points`, `MiniGame` (`Wires`/`Mash`/`Code`/`Timing`), `HoldTime`, `Drip`, `Effect` (`Lights`) |
| `Cage` | Пол клетки | — |
| `RatSpawn` / `ChefSpawn` / `LobbySpawn` | Невидимые точки появления | — |
| `RatHole` | Норка-телепорт (CanCollide выкл.) | `Pair`: одинаковое у двух норок |
| `Crumb` | Кусочек сыра | — |
| `PatrolPoint` | Точки патруля робота | — |
| `RoomLight` | Лампа с PointLight (гаснет от щитка) | — |
| `AlarmLight` | Деталь с выключенным красным PointLight (мигает при тревоге) | — |
| `Flicker` | Ставится на сам PointLight: свет будет мерцать | — |

Внутрь детали с тегом `Sabotage` можно положить `Fire`, `Smoke`, `ParticleEmitter`, `Sparkles`, `Sound`.
Они включатся при поломке. Деталь с именем **`BrokenVisual`** станет видимой (лужа, пятно, красный экран).

**Крысиные лазейки:** просто оставь в стене дыру высотой ~2.5 стада. Крыса пролезет, повар нет.

---

## 🧪 Автотесты (для разработчиков)

В папке `tests/` лежит мини-симулятор Roblox API. Он прогоняет игру целиком:
раунды, мини-игры, магазин, мышеловки, сохранение, выход игроков.

```
pip install lupa
python3 tests/run.py
```

## 🧰 Если что-то не работает

Открой **View → Output**, ошибки там видны красным.
* `Infinite yield ... Config`: ModuleScript `Config` не в ReplicatedStorage или назван иначе.
* `... is not a valid member`: имя скрипта не совпадает с таблицей выше.
* Не видно подсказки «Напакостить»: ты повар или в лобби, подсказки видит только нужная роль.
