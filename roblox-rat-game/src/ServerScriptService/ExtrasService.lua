-- ExtrasService (ModuleScript) — ServerScriptService
-- То, что делает игру «залипательной»:
--   🎟️ коды (для TikTok/YouTube), 📜 ежедневные задания, 🏆 глобальная таблица побед,
--   👥 бонус за игру с друзьями, 🧗 награда за паркур в лобби, 💃 эмоции крыс.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local ExtrasService = {}
local ctx, DataService
local winsStore = nil
local nameCache = {}
local friendCache = {} -- [игрок] = { [userId] = true/false }
local lastCode = {}
local lastEmote = {}
local obbyNotified = {}

local function today()
	return math.floor(os.time() / 86400)
end

-- ===== 📜 Ежедневные задания =====
local function makeRng(seed)
	local s = seed % 2147483646 + 1
	return function(n)
		s = (s * 16807) % 2147483647
		return (s % n) + 1
	end
end

function ExtrasService.ensureQuests(player)
	local data = DataService.getData(player)
	if not data then
		return
	end
	local day = today()
	if data.Quests.Day == day and #data.Quests.List > 0 then
		return
	end
	local pick = makeRng(day * 7919 + player.UserId)
	local pool = {}
	for i, q in ipairs(Config.QuestPool) do
		pool[i] = q
	end
	local list = {}
	for _ = 1, math.min(Config.QuestsPerDay, #pool) do
		local q = table.remove(pool, pick(#pool))
		table.insert(list, { Id = q.Id, Kind = q.Kind, Goal = q.Goal, Reward = q.Reward, Progress = 0, Done = false })
	end
	data.Quests = { Day = day, List = list }
	DataService.publish(player)
end

function ExtrasService.progress(player, kind, n)
	local data = DataService.getData(player)
	if not data or not kind then
		return
	end
	ExtrasService.ensureQuests(player)
	local changed = false
	for _, q in ipairs(data.Quests.List) do
		if q.Kind == kind and not q.Done then
			q.Progress = math.min(q.Goal, q.Progress + (n or 1))
			changed = true
			if q.Progress >= q.Goal then
				q.Done = true
				data.Coins = data.Coins + q.Reward
				ctx.notifyPlayer(player, "good", "quest_done", q.Reward)
				ctx.fxPlayer(player, "coins", q.Reward, "📜")
			end
		end
	end
	if changed then
		DataService.publish(player)
	end
end

-- ===== 🎟️ Коды =====
local function onCode(player, code)
	if type(code) ~= "string" or #code > 40 then
		return
	end
	if (lastCode[player] or -10) + 1 > os.clock() then
		return -- не чаще раза в секунду
	end
	lastCode[player] = os.clock()
	local data = DataService.getData(player)
	if not data then
		return
	end
	code = string.upper((string.gsub(code, "%s", "")))
	local reward = Config.Codes[code]
	if not reward then
		ctx.notifyPlayer(player, "bad", "code_bad")
		return
	end
	if data.UsedCodes[code] then
		ctx.notifyPlayer(player, "info", "code_used")
		return
	end
	data.UsedCodes[code] = true
	data.Coins = data.Coins + reward
	DataService.publish(player)
	ctx.notifyPlayer(player, "good", "code_ok", reward)
	ctx.fxPlayer(player, "coins", reward, "🎟️")
	ctx.fxPlayer(player, "purchase")
	task.spawn(DataService.save, player)
end

-- ===== 💃 Эмоции крыс =====
local function onEmote(player, id)
	local emote = type(id) == "string" and Config.getEmote(id)
	if not emote or player:GetAttribute("Role") ~= "Rat" or player:GetAttribute("Caught") then
		return
	end
	if (lastEmote[player] or -100) + Config.EmoteCooldown > os.clock() then
		return
	end
	lastEmote[player] = os.clock()
	local n = (player:GetAttribute("EmoteN") or 0) + 1
	player:SetAttribute("Emote", id)
	player:SetAttribute("EmoteN", n)
	ExtrasService.progress(player, "Emote", 1)
	task.delay(emote.Duration, function()
		if player.Parent and player:GetAttribute("EmoteN") == n then
			player:SetAttribute("Emote", nil)
		end
	end)
end

-- ===== 🧗 Паркур в лобби =====
local function setupObby(part)
	part.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		local data = player and DataService.getData(player)
		if not data then
			return
		end
		if data.LastObby >= today() then
			if (obbyNotified[player] or 0) < os.clock() then
				obbyNotified[player] = os.clock() + 10
				ctx.notifyPlayer(player, "info", "obby_again")
			end
			return
		end
		data.LastObby = today()
		data.Coins = data.Coins + Config.ObbyReward
		DataService.publish(player)
		ctx.notifyPlayer(player, "good", "obby_done", Config.ObbyReward)
		ctx.fxPlayer(player, "coins", Config.ObbyReward, "🧗")
		ctx.fxPlayer(player, "levelup", 0)
	end)
end

-- ===== 👥 Друзья =====
local function areFriends(a, b)
	friendCache[a] = friendCache[a] or {}
	local known = friendCache[a][b.UserId]
	if known == nil then
		local ok, result = pcall(function()
			return a:IsFriendsWith(b.UserId)
		end)
		known = ok and result == true
		friendCache[a][b.UserId] = known
	end
	return known
end

function ExtrasService.checkFriends()
	local list = Players:GetPlayers()
	for _, p in ipairs(list) do
		local has = false
		for _, other in ipairs(list) do
			if other ~= p and (areFriends(p, other) or areFriends(other, p)) then
				has = true
			end
		end
		if has ~= (p:GetAttribute("FriendBonus") == true) then
			p:SetAttribute("FriendBonus", has)
			if has then
				ctx.notifyPlayer(p, "good", "friend_joined")
			end
		end
	end
end

-- ===== 🏆 Глобальная таблица побед =====
local function nameOf(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		nameCache[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok and type(name) == "string" then
		nameCache[userId] = name
		return name
	end
	return "?"
end

function ExtrasService.updateLeaderboard()
	local rows = {}
	if winsStore then
		for _, p in ipairs(Players:GetPlayers()) do
			local d = DataService.getData(p)
			if d then
				pcall(function()
					winsStore:SetAsync(tostring(p.UserId), d.Wins)
				end)
			end
		end
		local ok, pages = pcall(function()
			return winsStore:GetSortedAsync(false, Config.LeaderboardSize)
		end)
		if ok and pages then
			local okPage, page = pcall(function()
				return pages:GetCurrentPage()
			end)
			if okPage and type(page) == "table" then
				for _, entry in ipairs(page) do
					table.insert(rows, { nameOf(tonumber(entry.key) or 0), tonumber(entry.value) or 0 })
				end
			end
		end
	end
	if #rows == 0 then
		-- сохранение недоступно (Studio): показываем игроков этого сервера
		for _, p in ipairs(Players:GetPlayers()) do
			local d = DataService.getData(p)
			if d then
				table.insert(rows, { p.DisplayName, d.Wins })
			end
		end
		table.sort(rows, function(a, b)
			return a[2] > b[2]
		end)
	end
	local medals = { "🥇", "🥈", "🥉" }
	for _, board in ipairs(CollectionService:GetTagged("Leaderboard")) do
		for i = 1, Config.LeaderboardSize do
			local label = board:FindFirstChild("Row" .. i, true)
			if label then
				local r = rows[i]
				if r then
					label.Text = ("%s %s — %d 🏆"):format(medals[i] or (i .. "."), r[1], r[2])
				else
					label.Text = ""
				end
			end
		end
	end
end

-- ===== Вход и выход игроков =====
function ExtrasService.onJoin(player)
	ExtrasService.ensureQuests(player)
	ExtrasService.checkFriends()
end

function ExtrasService.onLeave(player)
	friendCache[player] = nil
	lastCode[player] = nil
	lastEmote[player] = nil
	obbyNotified[player] = nil
	task.delay(0.5, ExtrasService.checkFriends)
end

function ExtrasService.init(context, dataService)
	ctx = context
	DataService = dataService
	local ok = pcall(function()
		winsStore = DataStoreService:GetOrderedDataStore("RatRuckus_Wins_v1")
	end)
	if not ok then
		winsStore = nil
	end
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes:WaitForChild("RedeemCode").OnServerEvent:Connect(onCode)
	remotes:WaitForChild("Emote").OnServerEvent:Connect(onEmote)
	for _, part in ipairs(CollectionService:GetTagged("ObbyReward")) do
		setupObby(part)
	end
	CollectionService:GetInstanceAddedSignal("ObbyReward"):Connect(setupObby)
	task.spawn(function()
		task.wait(3)
		while true do
			ExtrasService.updateLeaderboard()
			task.wait(Config.LeaderboardRefresh)
		end
	end)
end

return ExtrasService
