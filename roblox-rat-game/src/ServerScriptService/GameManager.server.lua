-- GameManager (Script) — ServerScriptService
-- Главный скрипт: лобби, отсчёт, раунды, роли, награды, голод, сыр, норки, писк, победа.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local StarterPlayer = game:GetService("StarterPlayer")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

Players.CharacterAutoLoads = false -- персонажей создаём сами (крыса или человек)
StarterPlayer.EnableMouseLockOption = false -- Shift нужен для бега

-- ===== Сетевые события (до загрузки модулей!) =====
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage
local function makeRemote(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local notifyEvent = makeRemote("Notify")
local volunteerEvent = makeRemote("ChefVolunteer")
local fxEvent = makeRemote("FX")
local squeakEvent = makeRemote("Squeak")
makeRemote("ShopAction")
makeRemote("MiniGame")

local RatBuilder = require(script.Parent:WaitForChild("RatBuilder"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local SabotageService = require(script.Parent:WaitForChild("SabotageService"))
local ChefService = require(script.Parent:WaitForChild("ChefService"))
local ChefAI = require(script.Parent:WaitForChild("ChefAI"))
local TestMapBuilder = require(script.Parent:WaitForChild("TestMapBuilder"))

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
local alarmOn = false
local roundCoins = {}
local lastSqueak = {}

local function setState(s)
	state = s
	ReplicatedStorage:SetAttribute("State", s)
end

local function notifyAll(text, kind)
	notifyEvent:FireAllClients(text, kind or "info")
end

local function notifyPlayer(player, text, kind)
	notifyEvent:FireClient(player, text, kind or "info")
end

local function fxAll(kind, a, b)
	fxEvent:FireAllClients(kind, a, b)
end

local function getRoot(model)
	return model and model:FindFirstChild("HumanoidRootPart")
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
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("Role") == "Rat" then
			table.insert(list, p)
		end
	end
	return list
end

local function inRound()
	return state == "Intro" or state == "Playing"
end

-- ===== Скорость: одна функция для всех случаев =====
local function refreshSpeed(player)
	local role = player:GetAttribute("Role")
	local speed = 16
	if state == "Intro" and role ~= "Lobby" then
		speed = 0
	elseif role == "Rat" then
		if player:GetAttribute("Caught") or player:GetAttribute("Stunned") then
			speed = 0
		elseif (player:GetAttribute("Hunger") or Config.HungerMax) <= 0 then
			speed = Config.HungryWalkSpeed
		else
			speed = Config.RatWalkSpeed
		end
	elseif role == "Chef" then
		speed = Config.ChefWalkSpeed
		if alarmOn then
			speed = speed + Config.ChefRageBonus
		end
	end
	player:SetAttribute("BaseSpeed", speed)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = speed
	end
end

local function reward(player, kind)
	local amount = Config.Rewards[kind] or 0
	if amount <= 0 or not player.Parent then
		return
	end
	DataService.addCoins(player, amount)
	roundCoins[player] = (roundCoins[player] or 0) + amount
	fxEvent:FireClient(player, "coins", amount, Config.RewardNames[kind] or "")
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
	if chaos >= Config.AlarmChaos and not alarmOn then
		alarmOn = true
		notifyAll("🚨 ТРЕВОГА! Повар в ЯРОСТИ и стал быстрее!", "banner")
		for _, p in ipairs(Players:GetPlayers()) do
			if p:GetAttribute("Role") == "Chef" then
				refreshSpeed(p)
			end
		end
	end
	if chaos >= Config.ChaosToWin then
		endRound("Rats", "Ресторан в полном хаосе!")
	end
end

local function checkAllCaught()
	local rats = ratsList()
	if #rats == 0 then
		return
	end
	for _, r in ipairs(rats) do
		if not r:GetAttribute("Caught") then
			return
		end
	end
	endRound("Chef", "Все крысы сидят в клетке!")
end

local function refreshHat(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local role = player:GetAttribute("Role")
	local hatId = DataService.getHat(player)
	if role == "Rat" then
		RatBuilder.attachHat(character, head, hatId, 0.8, CFrame.new(0, 0.42, 0.05))
	elseif role ~= "Chef" then
		RatBuilder.attachHat(character, head, hatId, 1.15, CFrame.new(0, head.Size.Y / 2, 0))
	end
end

local ctx = {
	notifyAll = notifyAll,
	notifyPlayer = notifyPlayer,
	fxAll = fxAll,
	getSpawn = getSpawn,
	addChaos = addChaos,
	checkAllCaught = checkAllCaught,
	refreshSpeed = refreshSpeed,
	refreshHat = refreshHat,
	reward = reward,
	isPlaying = function()
		return state == "Playing"
	end,
	alertNoise = function(position, range)
		ChefAI.alert(position, range)
	end,
	onCaught = function(player)
		SabotageService.cancelFor(player)
	end,
}
DataService.init(ctx)
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
		player:SetAttribute("Stunned", false)
		player:SetAttribute("Hunger", Config.HungerMax)
		local rat = RatBuilder.build(player, spawnPoint("RatSpawn"))
		player.Character = rat
		rat.Parent = workspace
		rat.HumanoidRootPart:SetNetworkOwner(player)
		refreshSpeed(player)
		watchDeath(player, rat)
	else
		player:LoadCharacter()
		local character = player.Character
		if not character then
			return
		end
		local spawnTag = "LobbySpawn"
		if role == "Chef" then
			spawnTag = "ChefSpawn"
		end
		character:PivotTo(spawnPoint(spawnTag))
		character:WaitForChild("Humanoid")
		if role == "Chef" then
			ChefService.dressChef(character)
			ChefService.giveTool(player)
			ChefService.giveTrapTool(player)
		else
			character:WaitForChild("Head", 5)
			refreshHat(player)
		end
		refreshSpeed(player)
		watchDeath(player, character)
	end
end

-- ===== Голод, сыр, норки, писк =====
local function hungerTick()
	for _, p in ipairs(ratsList()) do
		if not p:GetAttribute("Caught") then
			local hunger = math.max(0, (p:GetAttribute("Hunger") or Config.HungerMax) - Config.HungerDrain)
			p:SetAttribute("Hunger", hunger)
			refreshSpeed(p)
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
		refreshSpeed(player)
		fxEvent:FireClient(player, "eat", crumb.Position)
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
		for _, other in ipairs(CollectionService:GetTagged("RatHole")) do
			if other ~= hole and other:GetAttribute("Pair") == pair then
				holeCooldown[player] = os.clock() + Config.HoleCooldown
				character:PivotTo(other.CFrame * CFrame.new(0, 0.3, -2.5))
				fxEvent:FireClient(player, "hole", other.Position)
				return
			end
		end
	end)
end

local function forEachTagged(tag, fn)
	for _, inst in ipairs(CollectionService:GetTagged(tag)) do
		fn(inst)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(fn)
end
forEachTagged("Crumb", setupCrumb)
forEachTagged("RatHole", setupHole)

squeakEvent.OnServerEvent:Connect(function(player)
	if player:GetAttribute("Role") ~= "Rat" or not inRound() then
		return
	end
	if (lastSqueak[player] or 0) + Config.SqueakCooldown > os.clock() then
		return
	end
	lastSqueak[player] = os.clock()
	local root = getRoot(player.Character)
	if root then
		fxAll("squeak", player.Character)
		ChefAI.alert(root.Position, 45)
	end
end)

-- ===== Игроки =====
volunteerEvent.OnServerEvent:Connect(function(player, wants)
	player:SetAttribute("WantsChef", wants == true)
end)

local function onPlayerAdded(player)
	if inRound() then
		player:SetAttribute("Role", "Rat")
	else
		player:SetAttribute("Role", "Lobby")
	end
	player:SetAttribute("Score", 0)
	DataService.load(player)
	if not player.Parent then
		return
	end
	if inRound() then
		notifyAll(("🐀 %s присоединился к крысам!"):format(player.DisplayName), "info")
	end
	spawnPlayer(player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
	holeCooldown[player] = nil
	lastSqueak[player] = nil
	roundCoins[player] = nil
	ChefService.forget(player)
	SabotageService.forget(player)
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
		for _, p in ipairs(players) do
			if p:GetAttribute("WantsChef") then
				table.insert(volunteers, p)
			end
		end
		local pool = players
		if #volunteers > 0 then
			pool = volunteers
		end
		chef = pool[math.random(#pool)]
	end
	for _, p in ipairs(players) do
		if p == chef then
			p:SetAttribute("Role", "Chef")
		else
			p:SetAttribute("Role", "Rat")
		end
		p:SetAttribute("Score", 0)
	end
	return chef
end

local function everyoneToLobby()
	for _, p in ipairs(Players:GetPlayers()) do
		p:SetAttribute("Role", "Lobby")
		p:SetAttribute("Caught", false)
		p:SetAttribute("Stunned", false)
		task.spawn(spawnPlayer, p)
	end
end

local function giveResults()
	local ratsWon = winner == "Rats"
	local best, bestScore = nil, 0
	for _, p in ipairs(Players:GetPlayers()) do
		local s = p:GetAttribute("Score") or 0
		if s > bestScore and p:GetAttribute("Role") ~= "Lobby" then
			best, bestScore = p, s
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		local role = p:GetAttribute("Role")
		if role == "Rat" or role == "Chef" then
			local won = (role == "Rat" and ratsWon) or (role == "Chef" and not ratsWon)
			reward(p, "Participation")
			if won then
				if role == "Rat" then
					reward(p, "RatWin")
				else
					reward(p, "ChefWin")
				end
				DataService.addWin(p)
			end
			local mvpName = ""
			if best then
				mvpName = best.DisplayName
			end
			fxEvent:FireClient(p, "results", {
				winner = winner,
				reason = winReason,
				won = won,
				mvp = mvpName,
				mvpScore = bestScore,
				coins = roundCoins[p] or 0,
			})
		end
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
		-- ОТСЧЁТ
		winner, winReason = nil, nil
		alarmOn = false
		roundCoins = {}
		SabotageService.reset()
		ChefService.reset()
		setState("Intro")
		local chef = assignRoles()
		for _, p in ipairs(Players:GetPlayers()) do
			task.spawn(spawnPlayer, p)
		end
		for t = Config.IntroTime, 1, -1 do
			ReplicatedStorage:SetAttribute("TimeLeft", t)
			task.wait(1)
		end

		-- РАУНД
		setState("Playing")
		for _, p in ipairs(Players:GetPlayers()) do
			refreshSpeed(p)
		end
		if chef and chef.Parent then
			notifyAll(("👨‍🍳 Повар — %s! Крысы, устройте хаос!"):format(chef.DisplayName), "info")
		else
			chef = nil
			ChefAI.start(spawnPoint("ChefSpawn"))
			notifyAll("🤖 На смену вышел повар-робот! Крысы, устройте хаос!", "info")
		end

		local timeLeft = Config.RoundTime
		while timeLeft > 0 and not winner do
			ReplicatedStorage:SetAttribute("TimeLeft", timeLeft)
			task.wait(1)
			timeLeft = timeLeft - 1
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
		ReplicatedStorage:SetAttribute("TimeLeft", Config.EndTime)
		ReplicatedStorage:SetAttribute("Winner", winner)
		ChefAI.stop()
		SabotageService.reset()
		giveResults()
		for t = Config.EndTime, 1, -1 do
			ReplicatedStorage:SetAttribute("TimeLeft", t)
			task.wait(1)
		end
		everyoneToLobby()
	end
end
