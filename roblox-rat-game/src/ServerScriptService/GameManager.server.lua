-- GameManager (Script) — ServerScriptService
-- Главный скрипт: лобби, отсчёт, раунды, роли, награды, голод, сыр, норки, писк, победа.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local StarterPlayer = game:GetService("StarterPlayer")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Locale = require(ReplicatedStorage:WaitForChild("Locale"))

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
local languageEvent = makeRemote("SetLanguage")
local abilityEvent = makeRemote("Ability")
local voteEvent = makeRemote("VoteMap")
makeRemote("RedeemCode")
makeRemote("SetPendingItem")
makeRemote("Emote")
makeRemote("ShopAction")
makeRemote("MiniGame")

-- Понятная ошибка, если какого-то скрипта не хватает или он назван неправильно
local function needModule(name)
	local m = script.Parent:WaitForChild(name, 8)
	if not m then
		error(("❌ НЕ НАЙДЕН скрипт «%s» в ServerScriptService! Проверь, что он есть, это ModuleScript и имя написано точно так: %s"):format(name, name))
	end
	if not m:IsA("ModuleScript") then
		error(("❌ «%s» должен быть ModuleScript (фиолетовая иконка), а сейчас это %s. Удали его и создай заново как ModuleScript."):format(name, m.ClassName))
	end
	return require(m)
end
local RatBuilder = needModule("RatBuilder")
local DataService = needModule("DataService")
local SabotageService = needModule("SabotageService")
local ChefService = needModule("ChefService")
local ChefAI = needModule("ChefAI")
local TestMapBuilder = needModule("TestMapBuilder")
local MonetizationService = needModule("MonetizationService")
local PetService = needModule("PetService")
local ExtrasService = needModule("ExtrasService")
print("✅ Все скрипты найдены, игра запускается!")

-- Общее состояние игры видно всем игрокам через атрибуты
ReplicatedStorage:SetAttribute("State", "Lobby")
ReplicatedStorage:SetAttribute("TimeLeft", 0)
ReplicatedStorage:SetAttribute("Chaos", 0)

-- Нет своей карты? Построим ресторан и пиццерию
if not workspace:FindFirstChild("Map") then
	TestMapBuilder.build()
end

-- Какие карты есть (для голосования)
local function availableMaps()
	local list = {}
	for _, m in ipairs(Config.Maps) do
		if workspace:FindFirstChild(m.Folder) then
			table.insert(list, m)
		end
	end
	return list
end
do
	local ids = {}
	for _, m in ipairs(availableMaps()) do
		table.insert(ids, m.Id)
	end
	ReplicatedStorage:SetAttribute("MapList", table.concat(ids, ","))
	local first = availableMaps()[1]
	ReplicatedStorage:SetAttribute("ActiveMap", first and first.Folder or "Map")
	ReplicatedStorage:SetAttribute("ActiveMapId", first and first.Id or "")
end

local state = "Lobby"
local winner, winReason = nil, nil
local alarmOn = false
local roundCoins = {}
local lastSqueak = {}
local goldenCheese = nil
local nextGolden = 0
local currentEvent = nil
local lastAbility = {}
local votes = {}

local function setState(s)
	state = s
	ReplicatedStorage:SetAttribute("State", s)
end

-- Сообщение каждому игроку на его языке (ключ из Locale + аргументы)
local function notifyPlayer(player, kind, key, ...)
	notifyEvent:FireClient(player, Locale.forPlayer(player, key, ...), kind or "info")
end

local function notifyAll(kind, key, ...)
	for _, p in ipairs(Players:GetPlayers()) do
		notifyPlayer(p, kind, key, ...)
	end
end

local function fxAll(kind, a, b)
	fxEvent:FireAllClients(kind, a, b)
end

local function getRoot(model)
	return model and model:FindFirstChild("HumanoidRootPart")
end

local function getSpawn(tag)
	local list
	if tag == "LobbySpawn" then
		list = CollectionService:GetTagged(tag)
	else
		list = Config.taggedInMap(tag) -- только на карте этого раунда
	end
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
		local cls = DataService.getClass(player)
		speed = speed * (cls.SpeedMult or 1)
		if player:GetAttribute("Dashing") then
			speed = speed * Config.DashMultiplier
		end
	elseif role == "Chef" then
		speed = Config.ChefWalkSpeed
		if alarmOn then
			speed = speed + Config.ChefRageBonus
		end
	end
	if currentEvent == "Turbo" and (role == "Rat" or role == "Chef") then
		speed = speed * Config.TurboMult
	end
	player:SetAttribute("BaseSpeed", speed)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = speed
	end
end

-- задания дня, которые засчитываются за награды
local QUEST_KIND = { Sabotage = "Sabotage", Rescue = "Rescue", Catch = "Catch", Repair = "Repair", Golden = "Golden", Participation = "Play", RatWin = "Win", ChefWin = "Win" }

-- во сколько раз больше сыра: пропуски + питомец + друг на сервере
local function cheeseFactor(player)
	local f = MonetizationService.coinMultiplier(player) + PetService.bonus(player)
	if player:GetAttribute("FriendBonus") then
		f = f + Config.FriendBonus
	end
	return f
end

local function reward(player, kind)
	local amount = Config.Rewards[kind] or 0
	if amount <= 0 or not player.Parent then
		return
	end
	local mult = cheeseFactor(player)
	amount = math.floor(amount * mult + 0.5)
	DataService.addCoins(player, amount)
	roundCoins[player] = (roundCoins[player] or 0) + amount
	local label = Locale.forPlayer(player, "reward_" .. kind)
	if mult > 1 then
		label = label .. " (×" .. mult .. ")"
	end
	fxEvent:FireClient(player, "coins", amount, label)
	DataService.addXP(player, Config.XP[kind])
	ExtrasService.progress(player, QUEST_KIND[kind])
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
	if currentEvent == "ChaosNight" and amount > 0 then
		amount = amount * Config.ChaosNightMult
	end
	local chaos = math.clamp((ReplicatedStorage:GetAttribute("Chaos") or 0) + amount, 0, Config.ChaosToWin)
	ReplicatedStorage:SetAttribute("Chaos", chaos)
	if chaos >= Config.AlarmChaos and not alarmOn then
		alarmOn = true
		notifyAll("banner", "alarm")
		for _, p in ipairs(Players:GetPlayers()) do
			if p:GetAttribute("Role") == "Chef" then
				refreshSpeed(p)
			end
		end
	end
	if chaos >= Config.ChaosToWin then
		endRound("Rats", "reason_chaos")
	end
end

local function checkAllCaught()
	local rats = ratsList()
	if #rats == 0 then
		return
	end
	for _, r in ipairs(rats) do
		if not r:GetAttribute("Caught") or r:GetAttribute("LuckPending") then
			return -- 🍀 у кого-то сработает «Второй шанс», ждём
		end
	end
	endRound("Chef", "reason_caught")
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
	if role ~= "Chef" then
		RatBuilder.attachTrail(character, DataService.getTrail(player))
	end
end

local function fxPlayer(player, kind, a, b)
	fxEvent:FireClient(player, kind, a, b)
end

-- 🍀 пропуск «Второй шанс»: первый раз за раунд клетка открывается сама
local function trySecondChance(player)
	if not MonetizationService.hasPass(player, "SecondChance") or player:GetAttribute("LuckUsed") then
		return
	end
	player:SetAttribute("LuckUsed", true)
	player:SetAttribute("LuckPending", true)
	notifyPlayer(player, "good", "luck_soon", Config.SecondChanceDelay)
	task.delay(Config.SecondChanceDelay, function()
		player:SetAttribute("LuckPending", nil)
		if state == "Playing" and player.Parent and player:GetAttribute("Role") == "Rat" and player:GetAttribute("Caught") then
			ChefService.release(player)
			local root = getRoot(player.Character)
			if root then
				fxAll("rescue", root.Position)
			end
			notifyAll("good", "luck_done", player.DisplayName)
		elseif state == "Playing" then
			checkAllCaught()
		end
	end)
end

local ctx = {
	fxPlayer = fxPlayer,
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
		trySecondChance(player)
	end,
	refreshClass = function(player)
		refreshSpeed(player)
	end,
	refreshPet = function(player)
		PetService.refresh(player)
	end,
	canEscape = function(player)
		return state == "Playing" and player:GetAttribute("Role") == "Rat" and player:GetAttribute("Caught") == true
	end,
	escape = function(player)
		ChefService.release(player)
		local root = getRoot(player.Character)
		if root then
			fxAll("rescue", root.Position)
		end
		notifyAll("good", "escape_done", player.DisplayName)
	end,
}
DataService.init(ctx)
MonetizationService.init(ctx, DataService)
PetService.init(DataService)
ExtrasService.init(ctx, DataService)
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
		player:SetAttribute("Dashing", false)
		player:SetAttribute("Armored", false)
		player:SetAttribute("Invisible", false)
		player:SetAttribute("Hunger", Config.HungerMax)
		local rat = RatBuilder.build(player, spawnPoint("RatSpawn"))
		player.Character = rat
		rat.Parent = workspace
		rat.HumanoidRootPart:SetNetworkOwner(player)
		refreshSpeed(player)
		PetService.refresh(player)
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
			if currentEvent == "GiantChef" then
				pcall(function()
					character:ScaleTo(Config.GiantScale)
				end)
			end
		else
			character:WaitForChild("Head", 5)
			refreshHat(player)
		end
		refreshSpeed(player)
		PetService.refresh(player)
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
		ExtrasService.progress(player, "Eat")
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

-- ===== Способности классов (клавиша F) =====
local ABILITY_FLAG = { Dash = "Dashing", Armor = "Armored", Invisible = "Invisible" }
abilityEvent.OnServerEvent:Connect(function(player)
	if state ~= "Playing" or player:GetAttribute("Role") ~= "Rat" or player:GetAttribute("Caught") then
		return
	end
	local cls = DataService.getClass(player)
	local flag = cls.Ability and ABILITY_FLAG[cls.Ability]
	if not flag then
		return
	end
	local now = os.clock()
	if (lastAbility[player] or -1000) + cls.Cooldown > now then
		return
	end
	lastAbility[player] = now
	local character = player.Character
	player:SetAttribute(flag, true)
	player:SetAttribute("AbilityUses", (player:GetAttribute("AbilityUses") or 0) + 1)
	if cls.Ability == "Invisible" then
		RatBuilder.setInvisible(character, true)
	end
	refreshSpeed(player)
	if character then
		fxAll("ability", character, cls.Ability)
	end
	notifyPlayer(player, "good", "ability_" .. cls.Ability)
	ExtrasService.progress(player, "Ability")
	task.delay(cls.Duration, function()
		if not player.Parent then
			return
		end
		player:SetAttribute(flag, false)
		if cls.Ability == "Invisible" and player.Character == character then
			RatBuilder.setInvisible(character, false)
		end
		refreshSpeed(player)
	end)
end)

-- ===== Голосование за карту =====
local function publishVotes()
	local counts = {}
	for _, m in ipairs(availableMaps()) do
		counts[m.Id] = 0
	end
	for p, id in pairs(votes) do
		if p.Parent and counts[id] then
			counts[id] = counts[id] + 1
		end
	end
	for id, c in pairs(counts) do
		ReplicatedStorage:SetAttribute("Votes_" .. id, c)
	end
end
publishVotes()

voteEvent.OnServerEvent:Connect(function(player, mapId)
	if state ~= "Lobby" or type(mapId) ~= "string" then
		return
	end
	for _, m in ipairs(availableMaps()) do
		if m.Id == mapId then
			votes[player] = mapId
			player:SetAttribute("Vote", mapId)
			publishVotes()
			return
		end
	end
end)

local function chooseMap()
	local maps = availableMaps()
	if #maps == 0 then
		return
	end
	local counts = {}
	for p, id in pairs(votes) do
		if p.Parent then
			counts[id] = (counts[id] or 0) + 1
		end
	end
	local best, bestCount = {}, -1
	for _, m in ipairs(maps) do
		local c = counts[m.Id] or 0
		if c > bestCount then
			best, bestCount = { m }, c
		elseif c == bestCount then
			table.insert(best, m)
		end
	end
	local chosen = best[math.random(#best)]
	ReplicatedStorage:SetAttribute("ActiveMap", chosen.Folder)
	ReplicatedStorage:SetAttribute("ActiveMapId", chosen.Id)
	votes = {}
	for _, p in ipairs(Players:GetPlayers()) do
		p:SetAttribute("Vote", nil)
	end
	publishVotes()
	return chosen
end

-- ===== Случайное событие раунда =====
local function pickEvent()
	local forced = ReplicatedStorage:GetAttribute("ForceEvent") -- для проверки: поставь атрибут вручную
	if forced == "none" then
		currentEvent = nil
	elseif type(forced) == "string" and forced ~= "" then
		currentEvent = forced
	elseif math.random() < Config.EventChance then
		currentEvent = Config.Events[math.random(#Config.Events)]
	else
		currentEvent = nil
	end
	ReplicatedStorage:SetAttribute("Event", currentEvent or "")
end

-- ===== Игроки =====
volunteerEvent.OnServerEvent:Connect(function(player, wants)
	player:SetAttribute("WantsChef", wants == true)
end)

languageEvent.OnServerEvent:Connect(function(player, lang)
	if lang == "ru" or lang == "en" then
		player:SetAttribute("Lang", lang)
	end
end)

local function onPlayerAdded(player)
	if inRound() then
		player:SetAttribute("Role", "Rat")
	else
		player:SetAttribute("Role", "Lobby")
	end
	player:SetAttribute("Score", 0)
	local bonus, streak = DataService.load(player)
	if player.Parent then
		MonetizationService.load(player)
		ExtrasService.onJoin(player)
	end
	if not player.Parent then
		return
	end
	if inRound() then
		notifyAll("info", "join_rats", player.DisplayName)
	end
	spawnPlayer(player)
	if bonus and bonus > 0 then
		notifyPlayer(player, "good", "daily", bonus, streak)
		fxPlayer(player, "coins", bonus, "🎁")
	end
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
	MonetizationService.forget(player)
	lastAbility[player] = nil
	votes[player] = nil
	PetService.forget(player)
	ExtrasService.onLeave(player)
	publishVotes()
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
		local volunteers, paid, passVolunteers = {}, {}, {}
		for _, p in ipairs(players) do
			if DataService.isChefNext(p) then
				table.insert(paid, p)
			elseif p:GetAttribute("WantsChef") then
				table.insert(volunteers, p)
				if MonetizationService.hasPass(p, "ChefPass") then
					table.insert(passVolunteers, p) -- 🍳 пропуск повара: выбирают первым
				end
			end
		end
		local pool = players
		if #paid > 0 then
			pool = paid
		elseif #passVolunteers > 0 then
			pool = passVolunteers
		elseif #volunteers > 0 then
			pool = volunteers
		end
		chef = pool[math.random(#pool)]
		DataService.clearChefNext(chef)
	end
	for _, p in ipairs(players) do
		if p == chef then
			p:SetAttribute("Role", "Chef")
		else
			p:SetAttribute("Role", "Rat")
		end
		p:SetAttribute("Score", 0)
		p:SetAttribute("LuckUsed", nil) -- 🍀 «Второй шанс» снова доступен
		p:SetAttribute("LuckPending", nil)
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
			DataService.markTutorial(p)
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
				reason = Locale.forPlayer(p, winReason),
				won = won,
				mvp = mvpName,
				mvpScore = bestScore,
				coins = roundCoins[p] or 0,
			})
		end
	end
end

-- ===== Золотой сыр: редкий бонус, появляется в труднодоступных местах =====
local function removeGolden()
	if goldenCheese then
		goldenCheese:Destroy()
		goldenCheese = nil
	end
end

local function spawnGolden()
	removeGolden()
	local spot = getSpawn("GoldenSpot")
	if not spot then
		return
	end
	local p = Instance.new("Part")
	p.Name = "GoldenCheese"
	p.Size = Vector3.new(1.3, 0.9, 1.3)
	p.CFrame = CFrame.new(spot.Position)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(255, 200, 40)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 210, 80)
	light.Range = 14
	light.Brightness = 2
	light.Parent = p
	local sp = Instance.new("Sparkles")
	sp.SparkleColor = Color3.fromRGB(255, 230, 120)
	sp.Parent = p
	p:AddTag("GoldenCheese")
	p.Parent = workspace
	goldenCheese = p
	local taken = false
	p.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if taken or not player or player:GetAttribute("Role") ~= "Rat" or player:GetAttribute("Caught") or state ~= "Playing" then
			return
		end
		taken = true
		local pos = p.Position
		removeGolden()
		player:SetAttribute("Hunger", Config.HungerMax)
		refreshSpeed(player)
		reward(player, "Golden")
		fxAll("rescue", pos)
		notifyAll("good", "golden_found", player.DisplayName, Config.Rewards.Golden * MonetizationService.coinMultiplier(player))
	end)
	notifyAll("banner", "golden_spawn")
	task.delay(Config.GoldenCheeseLifetime, function()
		if goldenCheese == p then
			removeGolden()
		end
	end)
end

-- ===== 🪂 Упал с карты? Возвращаем назад =====
task.spawn(function()
	while true do
		task.wait(1)
		for _, p in ipairs(Players:GetPlayers()) do
			local root = getRoot(p.Character)
			if root and root.Position.Y < Config.FallRescueY then
				local role = p:GetAttribute("Role")
				local tag = "LobbySpawn"
				if role == "Rat" then
					tag = "RatSpawn"
				elseif role == "Chef" then
					tag = "ChefSpawn"
				end
				root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
				p.Character:PivotTo(spawnPoint(tag))
			end
		end
	end
end)

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
		lastAbility = {}
		chooseMap()
		pickEvent()
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
		if currentEvent == "GoldenHour" then
			nextGolden = os.clock() + 5
		else
			nextGolden = os.clock() + 25
		end
		for _, p in ipairs(Players:GetPlayers()) do
			refreshSpeed(p)
		end
		if currentEvent then
			notifyAll("banner", "event_" .. currentEvent)
		end
		if chef and chef.Parent then
			notifyAll("info", "chef_is", chef.DisplayName)
		else
			chef = nil
			ChefAI.start(spawnPoint("ChefSpawn"))
			notifyAll("info", "chef_bot")
		end

		local timeLeft = Config.RoundTime
		while timeLeft > 0 and not winner do
			ReplicatedStorage:SetAttribute("TimeLeft", timeLeft)
			task.wait(1)
			timeLeft = timeLeft - 1
			hungerTick()
			SabotageService.dripTick()
			if os.clock() >= nextGolden then
				if currentEvent == "GoldenHour" then
					nextGolden = os.clock() + Config.GoldenHourInterval
				else
					nextGolden = os.clock() + Config.GoldenCheeseInterval
				end
				spawnGolden()
			end
			if chef and not chef.Parent then
				chef = nil
				ChefAI.start(spawnPoint("ChefSpawn"))
				notifyAll("info", "chef_left")
			end
			if #ratsList() == 0 then
				endRound("Chef", "reason_norats")
			end
		end
		if not winner then
			winner, winReason = "Chef", "reason_time"
		end

		-- КОНЕЦ РАУНДА
		setState("Ended")
		ReplicatedStorage:SetAttribute("TimeLeft", Config.EndTime)
		ReplicatedStorage:SetAttribute("Winner", winner)
		ChefAI.stop()
		removeGolden()
		currentEvent = nil
		ReplicatedStorage:SetAttribute("Event", "")
		SabotageService.reset()
		giveResults()
		task.spawn(ExtrasService.updateLeaderboard)
		for t = Config.EndTime, 1, -1 do
			ReplicatedStorage:SetAttribute("TimeLeft", t)
			task.wait(1)
		end
		everyoneToLobby()
	end
end
