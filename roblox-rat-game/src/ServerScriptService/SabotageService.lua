-- SabotageService (ModuleScript) — ServerScriptService
-- Предметы, которые крысы ломают, а повар чинит.
-- Любая деталь с тегом "Sabotage" становится заданием.
-- Атрибуты детали (необязательные):
--   TaskName (string)  — название задания, например "Засорить унитаз"
--   Points   (number)  — сколько хаоса даёт поломка
--   MiniGame (string)  — "Wires", "Mash", "Code" или "Timing" (иначе просто держать E)
--   HoldTime (number)  — сколько секунд держать E (если нет мини-игры)
--   Drip     (number)  — хаос в секунду, пока предмет сломан
--   Effect   (string)  — "Lights" = выключает свет во всём ресторане
-- Дети детали: Fire / Smoke / ParticleEmitter / Sparkles / Sound включаются при поломке,
-- а детали с именем "BrokenVisual" становятся видимыми (лужа, пятно, красный экран...).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Locale = require(ReplicatedStorage:WaitForChild("Locale"))

local SabotageService = {}
local ctx
local miniGameEvent
local active = {} -- [игрок] = { station, started, code }

-- имя задания на языке каждого игрока
local function taskName(station)
	return function(lang)
		return Locale.taskName(lang, station)
	end
end

local function isFreeRat(player)
	return player:GetAttribute("Role") == "Rat" and not player:GetAttribute("Caught")
end

local function setLights(on, onlyMap)
	for _, lamp in ipairs(CollectionService:GetTagged("RoomLight")) do
		if not onlyMap or lamp:IsDescendantOf(onlyMap) then
			for _, l in ipairs(lamp:GetDescendants()) do
				if l:IsA("Light") then
					l.Enabled = on
				end
			end
			if lamp:IsA("BasePart") then
				if on then
					lamp.Material = Enum.Material.Neon
				else
					lamp.Material = Enum.Material.SmoothPlastic
				end
			end
		end
	end
end

local function setEffects(station, broken)
	for _, d in ipairs(station:GetDescendants()) do
		if d:IsA("ParticleEmitter") or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") then
			d.Enabled = broken
		elseif d:IsA("Sound") then
			if broken then
				d:Play()
			else
				d:Stop()
			end
		elseif d:IsA("BasePart") and d.Name == "BrokenVisual" then
			if broken then
				d.Transparency = d:GetAttribute("VisibleTransparency") or 0
			else
				d.Transparency = 1
			end
		end
	end

	if station:GetAttribute("Effect") == "Lights" then
		local mapFolder = Config.activeMap()
		if mapFolder and not station:IsDescendantOf(mapFolder) then
			mapFolder = nil
		end
		if broken then
			-- свет мигает и гаснет
			task.spawn(function()
				for i = 1, 6 do
					setLights(i % 2 == 0, mapFolder)
					task.wait(0.12)
				end
				setLights(not station:GetAttribute("Broken"), mapFolder)
			end)
		else
			setLights(true, mapFolder)
		end
	end
end

local function closeMiniGamesFor(station)
	for player, info in pairs(active) do
		if info.station == station then
			active[player] = nil
			miniGameEvent:FireClient(player, "close")
		end
	end
end

function SabotageService.sabotage(station, player)
	if not ctx.isPlaying() or not isFreeRat(player) or not Config.inActiveMap(station) then
		return
	end
	if station:GetAttribute("Broken") then
		return
	end

	station:SetAttribute("Broken", true)
	setEffects(station, true)
	closeMiniGamesFor(station)
	player:SetAttribute("Score", (player:GetAttribute("Score") or 0) + 1)
	ctx.reward(player, "Sabotage")
	ctx.fxAll("sabotage", station.Position)
	ctx.notifyAll("good", "sabotaged", player.DisplayName, taskName(station))
	ctx.alertNoise(station.Position)
	ctx.addChaos(station:GetAttribute("Points") or Config.DefaultTaskPoints)
end

function SabotageService.repair(station, whoName, chefPlayer)
	if not ctx.isPlaying() or not station:GetAttribute("Broken") then
		return
	end
	station:SetAttribute("Broken", false)
	setEffects(station, false)
	if chefPlayer then
		ctx.reward(chefPlayer, "Repair")
	end
	ctx.fxAll("repair", station.Position)
	ctx.notifyAll("bad", "repaired", whoName or "?", taskName(station))
end

-- ===== Мини-игры =====
local function startMiniGame(station, player)
	if not ctx.isPlaying() or not isFreeRat(player) or station:GetAttribute("Broken") then
		return
	end
	local mine = active[player]
	if mine and mine.station == station then
		return -- уже играет в эту мини-игру
	end
	for other, info in pairs(active) do
		if other ~= player and info.station == station then
			ctx.notifyPlayer(player, "info", "busy")
			return
		end
	end
	local kind = station:GetAttribute("MiniGame")
	local data = {}
	local code = nil
	if kind == "Code" then
		code = tostring(math.random(1000, 9999))
		data.code = code
	end
	active[player] = { station = station, started = os.clock(), code = code }
	miniGameEvent:FireClient(player, "open", station, kind, data)
end

local function onMiniGameEvent(player, action, station, answer)
	local info = active[player]
	if action == "cancel" then
		active[player] = nil
		return
	end
	if action ~= "done" or not info or info.station ~= station then
		return
	end
	active[player] = nil
	local kind = station:GetAttribute("MiniGame")
	local minTime = Config.MiniGameMinTime[kind] or 1
	if os.clock() - info.started < minTime then
		return
	end
	if info.code and tostring(answer) ~= info.code then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - station.Position).Magnitude > 14 then
		return
	end
	SabotageService.sabotage(station, player)
end

function SabotageService.cancelFor(player)
	if active[player] then
		active[player] = nil
		miniGameEvent:FireClient(player, "close")
	end
end

function SabotageService.forget(player)
	active[player] = nil
end

-- ===== Служебное =====
function SabotageService.getBroken()
	local list = {}
	for _, station in ipairs(Config.taggedInMap("Sabotage")) do
		if station:GetAttribute("Broken") then
			table.insert(list, station)
		end
	end
	return list
end

-- Вызывается раз в секунду: сломанные предметы постепенно добавляют хаос
function SabotageService.dripTick()
	local total = 0
	for _, station in ipairs(SabotageService.getBroken()) do
		total = total + (station:GetAttribute("Drip") or Config.DefaultTaskDrip)
	end
	if total > 0 then
		ctx.addChaos(total)
	end
end

function SabotageService.reset()
	for player in pairs(active) do
		miniGameEvent:FireClient(player, "close")
	end
	active = {}
	for _, station in ipairs(CollectionService:GetTagged("Sabotage")) do
		station:SetAttribute("Broken", false)
		setEffects(station, false)
	end
	setLights(true)
end

local function setupStation(station)
	if not station:IsA("BasePart") then
		warn("[Sabotage] Тег Sabotage нужно ставить на деталь (Part), а не на", station:GetFullName())
		return
	end
	station:SetAttribute("Broken", false)
	setEffects(station, false)
	local kind = station:GetAttribute("MiniGame")

	local sab = Instance.new("ProximityPrompt")
	sab.Name = "SabotagePrompt"
	-- тексты на языке игрока подставляет RatHUD
	sab.ActionText = "Sabotage"
	sab.ObjectText = Locale.taskName("en", station)
	sab.MaxActivationDistance = 7
	sab.RequiresLineOfSight = false
	if kind then
		sab.HoldDuration = 0
		sab.Triggered:Connect(function(player)
			startMiniGame(station, player)
		end)
	else
		sab.HoldDuration = station:GetAttribute("HoldTime") or Config.DefaultSabotageTime
		sab.Triggered:Connect(function(player)
			SabotageService.sabotage(station, player)
		end)
	end
	sab.Parent = station

	local rep = Instance.new("ProximityPrompt")
	rep.Name = "RepairPrompt"
	rep.ActionText = "Repair"
	rep.ObjectText = Locale.taskName("en", station)
	rep.HoldDuration = Config.RepairTime
	rep.MaxActivationDistance = 9
	rep.RequiresLineOfSight = false
	rep.Parent = station
	rep.Triggered:Connect(function(player)
		if player:GetAttribute("Role") == "Chef" then
			SabotageService.repair(station, player.DisplayName, player)
		end
	end)
	-- Какую подсказку показывать (крысе или повару) решает RatHUD на стороне игрока.
end

function SabotageService.init(context)
	ctx = context
	miniGameEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MiniGame")
	miniGameEvent.OnServerEvent:Connect(onMiniGameEvent)
	for _, station in ipairs(CollectionService:GetTagged("Sabotage")) do
		setupStation(station)
	end
	CollectionService:GetInstanceAddedSignal("Sabotage"):Connect(setupStation)
end

return SabotageService
