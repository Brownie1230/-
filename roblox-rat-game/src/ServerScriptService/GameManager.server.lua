-- GameManager (Script) — ServerScriptService
-- Главный скрипт: лобби, раунды, роли, голод, сыр, крысиные норки, победа.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local StarterPlayer = game:GetService("StarterPlayer")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local RatBuilder = require(script.Parent:WaitForChild("RatBuilder"))
local SabotageService = require(script.Parent:WaitForChild("SabotageService"))
local ChefService = require(script.Parent:WaitForChild("ChefService"))
local ChefAI = require(script.Parent:WaitForChild("ChefAI"))
local TestMapBuilder = require(script.Parent:WaitForChild("TestMapBuilder"))

Players.CharacterAutoLoads = false -- персонажей создаём сами (крыса или человек)
StarterPlayer.EnableMouseLockOption = false -- Shift нужен для бега

-- ===== Сетевые события =====
local notifyEvent = Instance.new("RemoteEvent")
notifyEvent.Name = "Notify"
notifyEvent.Parent = ReplicatedStorage

local volunteerEvent = Instance.new("RemoteEvent")
volunteerEvent.Name = "ChefVolunteer"
volunteerEvent.Parent = ReplicatedStorage

-- Общее состояние игры видно всем игрокам через атрибуты
ReplicatedStorage:SetAttribute("State", "Lobby")
ReplicatedStorage:SetAttribute("TimeLeft", 0)
ReplicatedStorage:SetAttribute("Chaos", 0)

-- Нет своей карты? Построим тестовый ресторан
if not workspace:FindFirstChild("Map") then
	TestMapBuilder.build()
end

local state = "Lobby"
local winner, winReason = nil, nil

local function setState(s)
	state = s
	ReplicatedStorage:SetAttribute("State", s)
end

local function notifyAll(text, kind)
	notifyEvent:FireAllClients(text, kind or "info")
end

local function getSpawn(tag)
	local list = CollectionService:GetTagged(tag)
	if #list == 0 then
		return nil
	end
	return list[math.random(#list)]
end

local function spawnPoint(tag)
	local s = getSpawn(tag)
	if not s then
		warn("[GameManager] Нет детали с тегом", tag)
		return CFrame.new(0, 10, 0)
	end
	return CFrame.new(s.Position + Vector3.new(math.random(-20, 20) / 10, 3, math.random(-20, 20) / 10))
end

local function ratsList()
	local list = {}
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Role") == "Rat" then
			table.insert(list, p)
		end
	end
	return list
end

local function endRound(who, reason)
	if state ~= "Playing" or winner then
		return
	end
	winner, winReason = who, reason
end

local function addChaos(amount)
	if state ~= "Playing" then
		return
	end
	local chaos = math.clamp((ReplicatedStorage:GetAttribute("Chaos") or 0) + amount, 0, Config.ChaosToWin)
	ReplicatedStorage:SetAttribute("Chaos", chaos)
	if chaos >= Config.ChaosToWin then
		endRound("Rats", "Ресторан в полном хаосе!")
	end
end

local function checkAllCaught()
	local rats = ratsList()
	if #rats == 0 then
		return
	end
	for _, r in rats do
		if not r:GetAttribute("Caught") then
			return
		end
	end
	endRound("Chef", "Все крысы сидят в клетке!")
end

local ctx = {
	notifyAll = notifyAll,
	getSpawn = getSpawn,
	addChaos = addChaos,
	checkAllCaught = checkAllCaught,
	isPlaying = function()
		return state == "Playing"
	end,
}
SabotageService.init(ctx)
ChefService.init(ctx)
ChefAI.init(ctx, SabotageService, ChefService)

-- ===== Появление персонажей =====
local spawnPlayer

local function watchDeath(player, character)
	local hum = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if not hum then
		return
	end
	hum.Died:Connect(function()
		task.wait(Config.RespawnTime)
		if player.Parent and player.Character == character then
			spawnPlayer(player)
		end
	end)
end

spawnPlayer = function(player)
	local role = player:GetAttribute("Role") or "Lobby"
	if player.Character then
		player.Character:Destroy()
	end

	if role == "Rat" then
		player:SetAttribute("Caught", false)
		player:SetAttribute("Hunger", Config.HungerMax)
		player:SetAttribute("BaseSpeed", Config.RatWalkSpeed)
		local rat = RatBuilder.build(player, spawnPoint("RatSpawn"))
		player.Character = rat
		rat.Parent = workspace
		rat.HumanoidRootPart:SetNetworkOwner(player)
		watchDeath(player, rat)
	else
		player:LoadCharacter()
		local character = player.Character
		if not character then
			return
		end
		character:PivotTo(spawnPoint(if role == "Chef" then "ChefSpawn" else "LobbySpawn"))
		if role == "Chef" then
			local hum = character:WaitForChild("Humanoid")
			hum.WalkSpeed = Config.ChefWalkSpeed
			ChefService.dressChef(character)
			ChefService.giveTool(player)
		end
		watchDeath(player, character)
	end
end

-- ===== Голод, сыр, норки =====
local function hungerTick()
	for _, p in ratsList() do
		if not p:GetAttribute("Caught") then
			local hunger = math.max(0, (p:GetAttribute("Hunger") or Config.HungerMax) - Config.HungerDrain)
			p:SetAttribute("Hunger", hunger)
			p:SetAttribute("BaseSpeed", if hunger > 0 then Config.RatWalkSpeed else Config.HungryWalkSpeed)
		end
	end
end

local function setupCrumb(crumb)
	crumb.Touched:Connect(function(hit)
		if crumb:GetAttribute("Eaten") then
			return
		end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player or player:GetAttribute("Role") ~= "Rat" then
			return
		end
		crumb:SetAttribute("Eaten", true)
		crumb.Transparency = 1
		local hunger = math.min(Config.HungerMax, (player:GetAttribute("Hunger") or 0) + Config.CrumbFood)
		player:SetAttribute("Hunger", hunger)
		task.delay(Config.CrumbRespawn, function()
			crumb:SetAttribute("Eaten", false)
			crumb.Transparency = 0
		end)
	end)
end

local holeCooldown = {}
local function setupHole(hole)
	hole.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if not player or player:GetAttribute("Role") ~= "Rat" or player:GetAttribute("Caught") then
			return
		end
		if (holeCooldown[player] or 0) > os.clock() then
			return
		end
		local pair = hole:GetAttribute("Pair")
		for _, other in CollectionService:GetTagged("RatHole") do
			if other ~= hole and other:GetAttribute("Pair") == pair then
				holeCooldown[player] = os.clock() + Config.HoleCooldown
				character:PivotTo(other.CFrame * CFrame.new(0, 0.3, -2.5))
				return
			end
		end
	end)
end

local function forEachTagged(tag, fn)
	for _, inst in CollectionService:GetTagged(tag) do
		fn(inst)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(fn)
end
forEachTagged("Crumb", setupCrumb)
forEachTagged("RatHole", setupHole)

-- ===== Игроки =====
volunteerEvent.OnServerEvent:Connect(function(player, wants)
	player:SetAttribute("WantsChef", wants == true)
end)

local function onPlayerAdded(player)
	player:SetAttribute("Role", if state == "Playing" then "Rat" else "Lobby")
	player:SetAttribute("Score", 0)
	if state == "Playing" then
		notifyAll(("🐀 %s присоединился к крысам!"):format(player.DisplayName), "info")
	end
	spawnPlayer(player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in Players:GetPlayers() do
	task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
	holeCooldown[player] = nil
	ChefService.forget(player)
	task.delay(0.5, function()
		if state == "Playing" then
			checkAllCaught()
		end
	end)
end)

local function assignRoles()
	local players = Players:GetPlayers()
	local chef = nil
	if #players >= Config.HumanChefMinPlayers then
		local volunteers = {}
		for _, p in players do
			if p:GetAttribute("WantsChef") then
				table.insert(volunteers, p)
			end
		end
		local pool = if #volunteers > 0 then volunteers else players
		chef = pool[math.random(#pool)]
	end
	for _, p in players do
		p:SetAttribute("Role", if p == chef then "Chef" else "Rat")
		p:SetAttribute("Score", 0)
	end
	return chef
end

local function everyoneToLobby()
	for _, p in Players:GetPlayers() do
		p:SetAttribute("Role", "Lobby")
		p:SetAttribute("Caught", false)
		task.spawn(spawnPlayer, p)
	end
end

-- ===== Главный цикл =====
while true do
	-- ЛОББИ
	setState("Lobby")
	ReplicatedStorage:SetAttribute("Chaos", 0)
	ReplicatedStorage:SetAttribute("TimeLeft", 0)
	while #Players:GetPlayers() < Config.MinPlayers do
		task.wait(1)
	end
	local enough = true
	for t = Config.LobbyTime, 1, -1 do
		ReplicatedStorage:SetAttribute("TimeLeft", t)
		task.wait(1)
		if #Players:GetPlayers() < Config.MinPlayers then
			enough = false
			break
		end
	end

	if enough then
		-- РАУНД
		winner, winReason = nil, nil
		SabotageService.reset()
		ChefService.reset()
		local chef = assignRoles()
		for _, p in Players:GetPlayers() do
			task.spawn(spawnPlayer, p)
		end
		if not chef then
			ChefAI.start(spawnPoint("ChefSpawn"))
		end
		setState("Playing")
		if chef then
			notifyAll(("👨‍🍳 Повар — %s! Крысы, устройте хаос!"):format(chef.DisplayName), "banner")
		else
			notifyAll("🤖 На смену вышел повар-робот! Крысы, устройте хаос!", "banner")
		end

		local timeLeft = Config.RoundTime
		while timeLeft > 0 and not winner do
			ReplicatedStorage:SetAttribute("TimeLeft", timeLeft)
			task.wait(1)
			timeLeft -= 1
			hungerTick()
			SabotageService.dripTick()
			if chef and not chef.Parent then
				chef = nil
				ChefAI.start(spawnPoint("ChefSpawn"))
				notifyAll("Повар сбежал! Его заменил робот 🤖", "info")
			end
			if #ratsList() == 0 then
				endRound("Chef", "Крыс не осталось")
			end
		end
		if not winner then
			winner, winReason = "Chef", "Время вышло — ресторан выстоял!"
		end

		-- КОНЕЦ РАУНДА
		setState("Ended")
		ChefAI.stop()
		local title = if winner == "Rats" then "🐀 КРЫСЫ ПОБЕДИЛИ! " else "👨‍🍳 ПОВАР ПОБЕДИЛ! "
		notifyAll(title .. winReason, "banner")
		local best, bestScore = nil, 0
		for _, p in ratsList() do
			local s = p:GetAttribute("Score") or 0
			if s > bestScore then
				best, bestScore = p, s
			end
		end
		if best then
			notifyAll(("⭐ Самая вредная крыса: %s (очков: %d)"):format(best.DisplayName, bestScore), "good")
		end
		task.wait(Config.EndTime)
		everyoneToLobby()
	end
end
