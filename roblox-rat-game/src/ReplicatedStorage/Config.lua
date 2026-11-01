-- Config (ModuleScript) — ReplicatedStorage
-- Все настройки игры в одном месте. Меняй числа, чтобы настроить баланс.

local Config = {}

-- ===== Раунды =====
Config.MinPlayers = 1 -- сколько игроков нужно для старта (1 = можно тестировать одному)
Config.HumanChefMinPlayers = 3 -- если игроков меньше, поваром будет ИИ-робот
Config.LobbyTime = 20 -- секунд в лобби перед раундом
Config.IntroTime = 4 -- обратный отсчёт перед стартом
Config.RoundTime = 300 -- длина раунда (5 минут)
Config.EndTime = 10 -- экран результатов
Config.RespawnTime = 3

-- ===== Хаос =====
Config.ChaosToWin = 100 -- столько хаоса нужно крысам для победы
Config.AlarmChaos = 75 -- с этого уровня включается тревога и повар злится
Config.DefaultTaskPoints = 10 -- хаос за одну поломку
Config.DefaultTaskDrip = 0.1 -- хаос в секунду, пока предмет сломан
Config.DefaultSabotageTime = 3 -- сколько секунд держать E (если у предмета нет мини-игры)
Config.RepairTime = 3 -- сколько секунд повар чинит
Config.MiniGameMinTime = { Wires = 1.5, Mash = 1.5, Code = 1.5, Timing = 1.2 }

-- ===== Крысы =====
Config.RatWalkSpeed = 14
Config.RatJumpPower = 42 -- крыса может запрыгнуть на стол/стойку
Config.HungryWalkSpeed = 8 -- скорость, когда крыса голодная
Config.SprintMultiplier = 1.6
Config.StaminaMax = 100
Config.StaminaDrain = 30 -- в секунду при беге
Config.StaminaRegen = 18
Config.HungerMax = 100
Config.HungerDrain = 0.6 -- в секунду
Config.CrumbFood = 40 -- сколько сытости даёт кусочек сыра
Config.CrumbRespawn = 25 -- через сколько секунд сыр появится снова
Config.HoleCooldown = 2 -- пауза между прыжками в норки
Config.FreeCageTime = 2.5 -- сколько держать E, чтобы открыть клетку
Config.SqueakCooldown = 2.5 -- писк на Q
Config.TrapStunTime = 4 -- сколько секунд крыса сидит в мышеловке
Config.RatColors = {
	Color3.fromRGB(120, 85, 60), -- коричневая
	Color3.fromRGB(140, 140, 148), -- серая
	Color3.fromRGB(232, 226, 215), -- белая
	Color3.fromRGB(70, 60, 56), -- тёмная
	Color3.fromRGB(176, 120, 72), -- рыжая
}

-- ===== Повар (игрок) =====
Config.ChefWalkSpeed = 17
Config.ChefSprintMultiplier = 1.35
Config.ChefRageBonus = 3 -- прибавка к скорости во время тревоги
Config.CatchRange = 7 -- дальность сачка
Config.CatchCooldown = 1.2
Config.MaxTraps = 3 -- сколько мышеловок может стоять одновременно
Config.TrapCooldown = 12

-- ===== Повар-робот (ИИ) =====
Config.AIChefWalkSpeed = 15
Config.AISightRange = 55
Config.AIRepairTime = 4
Config.AIHearingRange = 70 -- слышит поломки и писк на таком расстоянии

-- ===== Награды (сыр-монетки 🧀) =====
Config.Rewards = {
	Sabotage = 5,
	Rescue = 8,
	Catch = 6,
	Repair = 3,
	RatWin = 25,
	ChefWin = 30,
	Participation = 5,
	Golden = 15,
}
-- Названия наград на двух языках — в модуле Locale (reward_...)

-- ===== Шапки (магазин в лобби) =====
Config.Hats = {
	{ Id = "none", Name = "Без шапки", NameEn = "No hat", Icon = "🚫", Price = 0 },
	{ Id = "cap", Name = "Кепка", NameEn = "Cap", Icon = "🧢", Price = 0 },
	{ Id = "bow", Name = "Бантик", NameEn = "Bow", Icon = "🎀", Price = 40 },
	{ Id = "party", Name = "Праздничный колпак", NameEn = "Party hat", Icon = "🥳", Price = 60 },
	{ Id = "cowboy", Name = "Ковбойская шляпа", NameEn = "Cowboy hat", Icon = "🤠", Price = 80 },
	{ Id = "pumpkin", Name = "Тыква", NameEn = "Pumpkin", Icon = "🎃", Price = 100 },
	{ Id = "tophat", Name = "Цилиндр", NameEn = "Top hat", Icon = "🎩", Price = 120 },
	{ Id = "chef", Name = "Мини-колпак", NameEn = "Mini chef hat", Icon = "🍳", Price = 150 },
	{ Id = "pirate", Name = "Пиратская шляпа", NameEn = "Pirate hat", Icon = "🏴‍☠️", Price = 180 },
	{ Id = "crown", Name = "Корона", NameEn = "Crown", Icon = "👑", Price = 250 },
	{ Id = "halo", Name = "Нимб", NameEn = "Halo", Icon = "😇", Price = 300 },
	{ Id = "vipcrown", Name = "Золотая VIP-корона", NameEn = "Golden VIP crown", Icon = "👑", Price = 0, VipOnly = true },
	-- шапки за уровень (открываются сами, когда достигнешь уровня)
	{ Id = "viking", Name = "Шлем викинга", NameEn = "Viking helmet", Icon = "⚔️", Price = 0, Level = 5 },
	{ Id = "headphones", Name = "Наушники", NameEn = "Headphones", Icon = "🎧", Price = 0, Level = 10 },
	{ Id = "wizard", Name = "Шляпа волшебника", NameEn = "Wizard hat", Icon = "🧙", Price = 0, Level = 20 },
}

function Config.getHat(id)
	for _, hat in ipairs(Config.Hats) do
		if hat.Id == id then
			return hat
		end
	end
	return nil
end

-- ===== Следы за крысой (магазин) =====
Config.Trails = {
	{ Id = "none", Name = "Без следа", NameEn = "No trail", Icon = "🚫", Price = 0 },
	{ Id = "sparkle", Name = "Искры", NameEn = "Sparkles", Icon = "✨", Price = 60, Colors = { Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 200, 60) } },
	{ Id = "hearts", Name = "Сердечки", NameEn = "Hearts", Icon = "💖", Price = 120, Colors = { Color3.fromRGB(255, 130, 190), Color3.fromRGB(255, 60, 120) } },
	{ Id = "fire", Name = "Огонь", NameEn = "Fire", Icon = "🔥", Price = 180, Colors = { Color3.fromRGB(255, 230, 80), Color3.fromRGB(255, 60, 20) } },
	{ Id = "ice", Name = "Лёд", NameEn = "Ice", Icon = "❄️", Price = 180, Colors = { Color3.fromRGB(220, 250, 255), Color3.fromRGB(80, 170, 255) } },
	{ Id = "rainbow", Name = "Радуга", NameEn = "Rainbow", Icon = "🌈", Price = 300, Colors = { Color3.fromRGB(255, 60, 60), Color3.fromRGB(255, 220, 60), Color3.fromRGB(60, 220, 90), Color3.fromRGB(60, 140, 255), Color3.fromRGB(200, 80, 255) } },
	{ Id = "galaxy", Name = "Галактика", NameEn = "Galaxy", Icon = "🌌", Price = 0, VipOnly = true, Colors = { Color3.fromRGB(120, 60, 255), Color3.fromRGB(255, 80, 220), Color3.fromRGB(60, 200, 255) } },
}

-- ===== Питомцы: летают за тобой и дают бонус к сыру =====
Config.Pets = {
	{ Id = "none", Name = "Без питомца", NameEn = "No pet", Icon = "🚫", Price = 0, Bonus = 0 },
	{ Id = "roach", Name = "Таракан", NameEn = "Cockroach", Icon = "🪳", Price = 100, Bonus = 0.05, Color = Color3.fromRGB(90, 55, 35) },
	{ Id = "hamster", Name = "Хомяк", NameEn = "Hamster", Icon = "🐹", Price = 250, Bonus = 0.1, Color = Color3.fromRGB(230, 170, 100) },
	{ Id = "pigeon", Name = "Голубь", NameEn = "Pigeon", Icon = "🐦", Price = 400, Bonus = 0.15, Color = Color3.fromRGB(150, 155, 170), Flying = true },
	{ Id = "slime", Name = "Сырный слайм", NameEn = "Cheese slime", Icon = "🟨", Price = 700, Bonus = 0.2, Color = Color3.fromRGB(255, 210, 60) },
	{ Id = "dragon", Name = "Мини-дракон", NameEn = "Mini dragon", Icon = "🐉", Price = 0, Level = 15, Bonus = 0.25, Color = Color3.fromRGB(80, 200, 110), Flying = true },
	{ Id = "goldhamster", Name = "Золотой хомяк", NameEn = "Golden hamster", Icon = "🌟", Price = 0, VipOnly = true, Bonus = 0.3, Color = Color3.fromRGB(255, 200, 40) },
}

-- ===== Коды (для TikTok и YouTube!) =====
-- Скажи код в видео — игроки введут его в игре и получат сыр. Каждый код — один раз на игрока.
-- Добавляй свои: ["МОЙКОД"] = 300
Config.Codes = {
	RATS = 250,
	TIKTOK = 500,
	CHEESE = 150,
	RELEASE = 300,
}

-- ===== Ежедневные задания (3 в день) =====
Config.QuestsPerDay = 3
Config.QuestPool = {
	{ Id = "sabotage5", Kind = "Sabotage", Goal = 5, Reward = 60 },
	{ Id = "sabotage15", Kind = "Sabotage", Goal = 15, Reward = 150 },
	{ Id = "rescue2", Kind = "Rescue", Goal = 2, Reward = 80 },
	{ Id = "golden1", Kind = "Golden", Goal = 1, Reward = 70 },
	{ Id = "eat5", Kind = "Eat", Goal = 5, Reward = 50 },
	{ Id = "win1", Kind = "Win", Goal = 1, Reward = 100 },
	{ Id = "play3", Kind = "Play", Goal = 3, Reward = 75 },
	{ Id = "catch3", Kind = "Catch", Goal = 3, Reward = 90 },
	{ Id = "repair5", Kind = "Repair", Goal = 5, Reward = 60 },
	{ Id = "ability5", Kind = "Ability", Goal = 5, Reward = 60 },
	{ Id = "emote3", Kind = "Emote", Goal = 3, Reward = 40 },
}

-- ===== Эмоции крыс (Z X C V или кнопка 💃) =====
Config.Emotes = {
	{ Id = "dance", Key = "Z", Duration = 3 },
	{ Id = "flip", Key = "X", Duration = 1.2 },
	{ Id = "wave", Key = "C", Duration = 2.5 },
	{ Id = "dead", Key = "V", Duration = 4 },
}
Config.EmoteCooldown = 1.5

-- ===== Друзья, паркур, таблица лидеров =====
Config.FriendBonus = 0.2 -- +20% сыра, если на сервере есть твой друг
Config.ObbyReward = 75 -- награда за паркур в лобби (раз в день)
Config.LeaderboardSize = 10
Config.LeaderboardRefresh = 45 -- сек

-- ===== Классы крыс (способность на F) =====
-- SpeedMult — скорость, SabotageMult — во сколько раз быстрее ломает (держать E / мини-игры)
Config.Classes = {
	{ Id = "normal", Name = "Обычная", NameEn = "Classic", Icon = "🐀", Price = 0, SpeedMult = 1, SabotageMult = 1 },
	{ Id = "fast", Name = "Быстрая", NameEn = "Speedy", Icon = "⚡", Price = 150, SpeedMult = 1.12, SabotageMult = 1, Ability = "Dash", Cooldown = 12, Duration = 2.5 },
	{ Id = "strong", Name = "Сильная", NameEn = "Tough", Icon = "💪", Price = 250, SpeedMult = 1, SabotageMult = 1.6, Ability = "Armor", Cooldown = 30, Duration = 3 },
	{ Id = "ninja", Name = "Невидимка", NameEn = "Ninja", Icon = "🥷", Price = 400, SpeedMult = 1, SabotageMult = 1, Ability = "Invisible", Cooldown = 25, Duration = 4 },
}
Config.DashMultiplier = 1.8

-- ===== Уровни =====
Config.XP = { Sabotage = 10, Rescue = 15, Catch = 15, Repair = 5, RatWin = 50, ChefWin = 50, Participation = 20, Golden = 10 }
Config.LevelUpCheese = 50 -- награда за новый уровень
function Config.xpForLevel(level) -- сколько опыта нужно, чтобы перейти с этого уровня на следующий
	return 100 + (level - 1) * 50
end

-- ===== События раунда (случайные) =====
Config.EventChance = 0.35
Config.Events = { "ChaosNight", "GoldenHour", "Turbo", "GiantChef" }
Config.GiantScale = 1.8 -- «Гигантский повар»: во сколько раз больше
Config.GiantCatchMult = 1.5 -- и насколько дальше достаёт сачок
Config.ChaosNightMult = 1.5 -- хаос растёт в 1.5 раза быстрее
Config.GoldenHourInterval = 12 -- золотой сыр каждые 12 сек
Config.TurboMult = 1.25 -- все бегают быстрее

-- ===== Карты =====
-- Folder — имя папки в Workspace. Своя карта: положи её в Workspace как папку "Map".
Config.Maps = {
	{ Id = "Restaurant", Folder = "Map", Name = "Ресторан", NameEn = "Restaurant", Icon = "🍽️" },
	{ Id = "Pizzeria", Folder = "MapPizzeria", Name = "Пиццерия", NameEn = "Pizzeria", Icon = "🍕" },
}

local function findIn(list, id)
	for _, item in ipairs(list) do
		if item.Id == id then
			return item
		end
	end
	return nil
end
function Config.getTrail(id)
	return findIn(Config.Trails, id)
end
function Config.getClass(id)
	return findIn(Config.Classes, id)
end
function Config.getPet(id)
	return findIn(Config.Pets, id)
end
function Config.getEmote(id)
	return findIn(Config.Emotes, id)
end

-- Активная карта раунда и фильтр «только объекты активной карты»
function Config.activeMap()
	local name = game:GetService("ReplicatedStorage"):GetAttribute("ActiveMap") or "Map"
	return workspace:FindFirstChild(name)
end
function Config.inActiveMap(inst)
	local m = Config.activeMap()
	return m == nil or inst:IsDescendantOf(m)
end
function Config.taggedInMap(tag)
	local list = {}
	for _, inst in ipairs(game:GetService("CollectionService"):GetTagged(tag)) do
		if Config.inActiveMap(inst) then
			table.insert(list, inst)
		end
	end
	return list
end

-- ===== Донат (Robux) =====
-- 1) create.roblox.com → твоя игра → Monetization → Passes / Developer Products → Create
-- 2) Скопируй ID товара и вставь сюда вместо 0. Пока стоит 0, кнопка покажет «скоро».
Config.GamePasses = {
	VIP = 0, -- 👑 VIP: золотая корона, ×2 сыра, блеск
	DoubleCheese = 0, -- 🧀 ×2 сыра навсегда
	AllClasses = 0, -- 🐀 все классы крыс навсегда
}
Config.GamePassPrices = { VIP = 199, DoubleCheese = 99, AllClasses = 149 } -- только для надписи на кнопке (цену ставишь в Creator Hub)
Config.Products = {
	{ Key = "Cheese500", Kind = "cheese", Id = 0, Coins = 500, Price = 25 },
	{ Key = "Cheese2500", Kind = "cheese", Id = 0, Coins = 2500, Price = 99 },
	{ Key = "Cheese10000", Kind = "cheese", Id = 0, Coins = 10000, Price = 299 },
	{ Key = "Escape", Kind = "escape", Id = 0, Coins = 100, Price = 15 }, -- 🔓 сбежать из клетки (если уже свободен — 100 сыра)
	{ Key = "BeChef", Kind = "chef", Id = 0, Price = 25 }, -- 👨‍🍳 стать поваром в следующем раунде
}

-- ===== Бонусы =====
Config.DailyBonusBase = 25 -- ежедневный бонус в первый день
Config.DailyBonusStep = 25 -- +25 за каждый следующий день подряд
Config.DailyBonusMaxDays = 7
Config.GoldenCheeseInterval = 40 -- как часто появляется золотой сыр (сек)
Config.GoldenCheeseLifetime = 20 -- сколько он лежит

-- ===== Звуки =====
-- Можно заменить на любой звук из Toolbox: правый клик по звуку → Copy Asset ID,
-- и вставить сюда так: "rbxassetid://123456789". Пустая строка = без звука.
Config.Sounds = {
	Squeak = "rbxasset://sounds/electronicpingshort.wav",
	Sabotage = "rbxasset://sounds/glassbreak.wav",
	Swing = "rbxasset://sounds/swordslash.wav",
	Catch = "rbxasset://sounds/swordlunge.wav",
	TrapSnap = "rbxasset://sounds/snap.wav",
	Rescue = "rbxasset://sounds/unsheath.wav",
	Coin = "rbxasset://sounds/electronicpingshort.wav",
	Countdown = "rbxasset://sounds/electronicpingshort.wav",
	Victory = "rbxasset://sounds/victory.wav",
	Footsteps = "rbxasset://sounds/action_footsteps_plastic.mp3",
	Heartbeat = "", -- найди в Toolbox "heartbeat" и вставь ID
	MusicLobby = "", -- спокойная музыка в лобби
	MusicRound = "", -- музыка во время раунда
	MusicAlarm = "", -- быстрая музыка во время тревоги
}

return Config
