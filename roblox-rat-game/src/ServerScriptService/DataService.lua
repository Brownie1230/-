-- DataService (ModuleScript) — ServerScriptService
-- Сыр-монетки 🧀, победы и купленные шапки. Сохраняется между играми (DataStore).
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

local function defaultData()
	return { Coins = 0, Wins = 0, Owned = { none = true, cap = true }, Hat = "cap", LastDaily = 0, Streak = 0, Purchases = {} }
end

local function ownedString(data)
	local list = {}
	for id, owned in pairs(data.Owned) do
		if owned then
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
	player:SetAttribute("Hat", data.Hat)
	player:SetAttribute("OwnedHats", ownedString(data))
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		local coins = stats:FindFirstChild(COINS_NAME)
		local wins = stats:FindFirstChild(WINS_NAME)
		if coins then
			coins.Value = data.Coins
		end
		if wins then
			wins.Value = data.Wins
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
			if type(saved.Owned) == "table" then
				for id, owned in pairs(saved.Owned) do
					if owned and Config.getHat(id) then
						data.Owned[id] = true
					end
				end
			end
			if type(saved.Hat) == "string" and data.Owned[saved.Hat] then
				data.Hat = saved.Hat
			end
			data.LastDaily = tonumber(saved.LastDaily) or 0
			data.Streak = tonumber(saved.Streak) or 0
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
	local coins = Instance.new("IntValue")
	coins.Name = COINS_NAME
	coins.Parent = stats
	local wins = Instance.new("IntValue")
	wins.Name = WINS_NAME
	wins.Parent = stats
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

-- Выдать шапку (например, VIP-корону за покупку пропуска)
function DataService.grantHat(player, hatId)
	local data = cache[player]
	if data and not data.Owned[hatId] then
		data.Owned[hatId] = true
		publish(player)
	end
end

-- Выдать сыр за покупку. Один и тот же чек не засчитывается дважды.
function DataService.grantPurchase(player, purchaseId, coins)
	local data = cache[player]
	if not data then
		return false
	end
	purchaseId = tostring(purchaseId)
	if data.Purchases[purchaseId] then
		return true
	end
	data.Purchases[purchaseId] = true
	data.Coins = data.Coins + coins
	publish(player)
	if store then
		local ok = pcall(function()
			store:SetAsync("player_" .. player.UserId, data)
		end)
		if not ok then
			data.Purchases[purchaseId] = nil
			data.Coins = data.Coins - coins
			publish(player)
			return false
		end
	end
	return true
end

function DataService.getHat(player)
	local data = cache[player]
	if data then
		return data.Hat
	end
	return player:GetAttribute("Hat")
end

local function onShop(player, action, hatId)
	local data = cache[player]
	if not data or type(action) ~= "string" or type(hatId) ~= "string" then
		return
	end
	local hat = Config.getHat(hatId)
	if not hat then
		return
	end

	if hat.VipOnly and not data.Owned[hatId] then
		ctx.notifyPlayer(player, "info", "vip_only")
		return
	end
	if action == "buy" and not data.Owned[hatId] then
		if data.Coins < hat.Price then
			ctx.notifyPlayer(player, "bad", "no_cheese")
			return
		end
		data.Coins = data.Coins - hat.Price
		data.Owned[hatId] = true
		ctx.notifyPlayer(player, "good", "bought", hat.Icon, Locale.hatName(Locale.detect(player), hat))
		task.spawn(DataService.save, player)
	end
	if (action == "buy" or action == "equip") and data.Owned[hatId] then
		data.Hat = hatId
		publish(player)
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
