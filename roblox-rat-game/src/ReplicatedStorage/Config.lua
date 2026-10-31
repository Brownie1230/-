-- Config (ModuleScript) — ReplicatedStorage
-- Все настройки игры в одном месте. Меняй числа, чтобы настроить баланс.

local Config = {}

-- ===== Раунды =====
Config.MinPlayers = 1 -- сколько игроков нужно для старта (1 = можно тестировать одному)
Config.HumanChefMinPlayers = 3 -- если игроков меньше, поваром будет ИИ-робот
Config.LobbyTime = 20 -- секунд в лобби перед раундом
Config.RoundTime = 300 -- длина раунда (5 минут)
Config.EndTime = 8 -- пауза после раунда
Config.RespawnTime = 3

-- ===== Хаос =====
Config.ChaosToWin = 100 -- столько хаоса нужно крысам для победы
Config.DefaultTaskPoints = 12 -- хаос за одну поломку (если у предмета нет атрибута Points)
Config.DefaultTaskDrip = 0.25 -- хаос в секунду, пока предмет сломан
Config.DefaultSabotageTime = 3 -- сколько секунд держать E, чтобы сломать
Config.RepairTime = 3 -- сколько секунд повар чинит

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
Config.RatColors = {
	Color3.fromRGB(120, 85, 60), -- коричневая
	Color3.fromRGB(140, 140, 148), -- серая
	Color3.fromRGB(232, 226, 215), -- белая
	Color3.fromRGB(70, 60, 56), -- тёмная
}

-- ===== Повар (игрок) =====
Config.ChefWalkSpeed = 17
Config.CatchRange = 7 -- дальность сачка
Config.CatchCooldown = 1.2

-- ===== Повар-робот (ИИ) =====
Config.AIChefWalkSpeed = 15
Config.AISightRange = 55
Config.AIRepairTime = 4

return Config
