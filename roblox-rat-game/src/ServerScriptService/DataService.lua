-- DataService (ModuleScript) — ServerScriptService
-- Сыр-монетки 🧀, победы, уровень, шапки, следы, классы. Сохраняется между играми (DataStore).
-- В Studio сохранение работает, только если включить:
--   Home → Game Settings → Security → Enable Studio Access to API Services

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Locale = require(ReplicatedStorage:WaitForChild("Locale"))

local DataService = {}
local ctx
local store = nil
local cache = {} -- [player] = данные

-- таблицу игроков видят все, поэтому названия понятны на любом языке
local COINS_NAME = "🧀 Cheese"
local WINS_NAME = "🏆 Wins"
local LEVEL_NAME = "⭐ Level"

local function defaultData()
	return {
		Coins = 0,
		Wins = 0,
		Level = 1,
		XP = 0,
		Owned = { none = true, cap = true },
		Hat = "cap",
		OwnedTrails = { none = true },
		Trail = "none",
		OwnedClasses = { normal = true },
		Class = "normal",
		LastDaily = 0,
		Streak = 0,
		Tutorial = false,
		ChefNext = false,
		Purchases = {},
	}
end

local function setString(set)
	local list = {}
	for id, on in pairs(set) do
		if on then
			table.insert(list, id)
		end
	end
	table.sort(list)
	return table.concat(list, ",")
end

local function publish(player)
	local data = cache[player]
	if not data then
		return
	end
	player:SetAttribute("Coins", data.Coins)
	player:SetAttribute("Wins", data.Wins)
	player:SetAttribute("Level", data.Level)
	player:SetAttribute("XP", data.XP)
	player:SetAttribute("XPNeed", Config.xpForLevel(data.Level))
	player:SetAttribute("Hat", data.Hat)
	player:SetAttribute("OwnedHats", setString(data.Owned))
	player:SetAttribute("Trail", data.Trail)
	player:SetAttribute("OwnedTrails", setString(data.OwnedTrails))
	player:SetAttribute("Class", data.Class)
	player:SetAttribute("OwnedClasses", setString(data.OwnedClasses))
	player:SetAttribute("TutorialDone", data.Tutorial)
	player:SetAttribute("ChefNext", data.ChefNext)
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		local map = { [COINS_NAME] = data.Coins, [WINS_NAME] = data.Wins, [LEVEL_NAME] = data.Level }
		for name, value in pairs(map) do
			local v = stats:FindFirstChild(name)
			if v then
				v.Value = value
			end
		end
	end
end

-- шапки за уровень выдаются сами
local function unlockLevelHats(player, data, announce)
	for _, hat in ipairs(Config.Hats) do
		if hat.Level and data.Level >= hat.Level and not data.Owned[hat.Id] then
			data.Owned[hat.Id] = true
			if announce and ctx then
				ctx.notifyPlayer(player, "good", "level_hat", hat.Icon, function(lang)
					return Locale.itemName(lang, hat)
				end)
			end
		end
	end
end

local function copySet(src, dst, valid)
	if type(src) == "table" then
		for id, on in pairs(src) do
			if on and valid(id) then
				dst[id] = true
			end
		end
	end
end

function DataService.load(player)
	local data = defaultData()
	if store then
		local ok, saved = pcall(function()
			return store:GetAsync("player_" .. player.UserId)
		end)
		if ok and type(saved) == "table" then
			data.Coins = tonumber(saved.Coins) or 0
			data.Wins = tonumber(saved.Wins) or 0
			data.Level = math.max(1, tonumber(saved.Level) or 1)
			data.XP = math.max(0, tonumber(saved.XP) or 0)
			copySet(saved.Owned, data.Owned, function(id)
				return Config.getHat(id) ~= nil
			end)
			copySet(saved.OwnedTrails, data.OwnedTrails, function(id)
				return Config.getTrail(id) ~= nil
			end)
			copySet(saved.OwnedClasses, data.OwnedClasses, function(id)
				return Config.getClass(id) ~= nil
			end)
			if type(saved.Hat) == "string" and data.Owned[saved.Hat] then
				data.Hat = saved.Hat
			end
			if type(saved.Trail) == "string" and data.OwnedTrails[saved.Trail] then
				data.Trail = saved.Trail
			end
			if type(saved.Class) == "string" and data.OwnedClasses[saved.Class] then
				data.Class = saved.Class
			end
			data.LastDaily = tonumber(saved.LastDaily) or 0
			data.Streak = tonumber(saved.Streak) or 0
			data.Tutorial = saved.Tutorial == true
			data.ChefNext = saved.ChefNext == true
			if type(saved.Purchases) == "table" then
				for id, v in pairs(saved.Purchases) do
					if v then
						data.Purchases[tostring(id)] = true
					end
				end
			end
		elseif not ok then
			warn("[Data] Не удалось загрузить данные (в Studio включи доступ к API):", saved)
		end
	end
	if not player.Parent then
		return 0, 0
	end
	cache[player] = data
	unlockLevelHats(player, data, false)

	-- ежедневный бонус (дни подряд дают больше)
	local today = math.floor(os.time() / 86400)
	local bonus = 0
	if today > data.LastDaily then
		if today == data.LastDaily + 1 then
			data.Streak = math.min(data.Streak + 1, Config.DailyBonusMaxDays)
		else
			data.Streak = 1
		end
		data.LastDaily = today
		bonus = Config.DailyBonusBase + (data.Streak - 1) * Config.DailyBonusStep
		data.Coins = data.Coins + bonus
	end

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, name in ipairs({ LEVEL_NAME, COINS_NAME, WINS_NAME }) do
		local v = Instance.new("IntValue")
		v.Name = name
		v.Parent = stats
	end
	stats.Parent = player

	publish(player)
	return bonus, data.Streak
end

function DataService.save(player)
	local data = cache[player]
	if not data or not store then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync("player_" .. player.UserId, data)
	end)
	if not ok then
		warn("[Data] Не удалось сохранить:", err)
	end
end

function DataService.addCoins(player, amount)
	local data = cache[player]
	if not data or amount == 0 then
		return
	end
	data.Coins = math.max(0, data.Coins + amount)
	publish(player)
end

function DataService.addWin(player)
	local data = cache[player]
	if data then
		data.Wins = data.Wins + 1
		publish(player)
	end
end

-- Опыт. Возвращает, сколько уровней получено.
function DataService.addXP(player, amount)
	local data = cache[player]
	if not data or not amount or amount <= 0 then
		return 0
	end
	data.XP = data.XP + amount
	local gained = 0
	while data.XP >= Config.xpForLevel(data.Level) do
		data.XP = data.XP - Config.xpForLevel(data.Level)
		data.Level = data.Level + 1
		data.Coins = data.Coins + Config.LevelUpCheese
		gained = gained + 1
		ctx.notifyPlayer(player, "banner", "level_up", data.Level, Config.LevelUpCheese)
		ctx.fxPlayer(player, "levelup", data.Level)
	end
	if gained > 0 then
		unlockLevelHats(player, data, true)
	end
	publish(player)
	return gained
end

-- Выдать шапку (например, VIP-корону за покупку пропуска)
function DataService.grantHat(player, hatId)
	local data = cache[player]
	if data and not data.Owned[hatId] then
		data.Owned[hatId] = true
		publish(player)
	end
end

function DataService.grantTrail(player, trailId)
	local data = cache[player]
	if data and not data.OwnedTrails[trailId] then
		data.OwnedTrails[trailId] = true
		publish(player)
	end
end

function DataService.grantAllClasses(player)
	local data = cache[player]
	if not data then
		return
	end
	for _, cls in ipairs(Config.Classes) do
		data.OwnedClasses[cls.Id] = true
	end
	publish(player)
end

-- Покупка за Robux: один чек засчитывается один раз. mutate(data) меняет Coins/ChefNext.
-- Сначала сохраняем, и только потом подтверждаем Roblox (иначе Robux пропали бы зря).
function DataService.processPurchase(player, purchaseId, mutate)
	local data = cache[player]
	if not data then
		return false
	end
	purchaseId = tostring(purchaseId)
	if data.Purchases[purchaseId] then
		return true, true
	end
	local before = { Coins = data.Coins, ChefNext = data.ChefNext }
	data.Purchases[purchaseId] = true
	mutate(data)
	if store then
		local ok = pcall(function()
			store:SetAsync("player_" .. player.UserId, data)
		end)
		if not ok then
			data.Purchases[purchaseId] = nil
			data.Coins = before.Coins
			data.ChefNext = before.ChefNext
			publish(player)
			return false
		end
	end
	publish(player)
	return true, false
end

-- старое имя (покупка сыра)
function DataService.grantPurchase(player, purchaseId, coins)
	local ok = DataService.processPurchase(player, purchaseId, function(data)
		data.Coins = data.Coins + coins
	end)
	return ok
end

function DataService.getHat(player)
	local data = cache[player]
	if data then
		return data.Hat
	end
	return player:GetAttribute("Hat")
end

function DataService.getTrail(player)
	local data = cache[player]
	return data and data.Trail or "none"
end

function DataService.getClass(player)
	local data = cache[player]
	return Config.getClass(data and data.Class or "normal") or Config.Classes[1]
end

function DataService.isChefNext(player)
	local data = cache[player]
	return data ~= nil and data.ChefNext == true
end

function DataService.clearChefNext(player)
	local data = cache[player]
	if data then
		data.ChefNext = false
		publish(player)
	end
end

function DataService.markTutorial(player)
	local data = cache[player]
	if data and not data.Tutorial then
		data.Tutorial = true
		publish(player)
	end
end

-- ===== Магазин за сыр: шапки, следы, классы =====
local CATEGORIES = {
	hat = { list = "Hats", owned = "Owned", field = "Hat", get = Config.getHat },
	trail = { list = "Trails", owned = "OwnedTrails", field = "Trail", get = Config.getTrail },
	class = { list = "Classes", owned = "OwnedClasses", field = "Class", get = Config.getClass },
}

local function onShop(player, action, itemId, category)
	local data = cache[player]
	if not data or type(action) ~= "string" or type(itemId) ~= "string" then
		return
	end
	local cat = CATEGORIES[category or "hat"]
	if not cat then
		return
	end
	local item = cat.get(itemId)
	if not item then
		return
	end
	local owned = data[cat.owned]

	if not owned[itemId] then
		if action ~= "buy" then
			return
		end
		if item.VipOnly then
			ctx.notifyPlayer(player, "info", "vip_only")
			return
		end
		if item.Level then
			ctx.notifyPlayer(player, "info", "level_lock", item.Level)
			return
		end
		if data.Coins < item.Price then
			ctx.notifyPlayer(player, "bad", "no_cheese")
			return
		end
		data.Coins = data.Coins - item.Price
		owned[itemId] = true
		ctx.notifyPlayer(player, "good", "bought", item.Icon, function(lang)
			return Locale.itemName(lang, item)
		end)
		task.spawn(DataService.save, player)
	end
	data[cat.field] = itemId
	publish(player)
	if category == "class" then
		ctx.refreshClass(player)
	else
		ctx.refreshHat(player)
	end
end

function DataService.init(context)
	ctx = context
	local ok, err = pcall(function()
		store = DataStoreService:GetDataStore("KrysinyPerepoloh_v1")
	end)
	if not ok then
		store = nil
		warn("[Data] Сохранение выключено:", err)
	end

	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ShopAction").OnServerEvent:Connect(onShop)

	Players.PlayerRemoving:Connect(function(player)
		DataService.save(player)
		cache[player] = nil
	end)

	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			DataService.save(player)
		end
	end)

	-- автосохранение раз в 2 минуты
	task.spawn(function()
		while true do
			task.wait(120)
			for _, player in ipairs(Players:GetPlayers()) do
				DataService.save(player)
			end
		end
	end)
end

return DataService
