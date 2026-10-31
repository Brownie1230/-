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
}

function Config.getHat(id)
	for _, hat in ipairs(Config.Hats) do
		if hat.Id == id then
			return hat
		end
	end
	return nil
end

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
