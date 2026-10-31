-- SabotageService (ModuleScript) — ServerScriptService
-- Предметы, которые крысы ломают, а повар чинит.
-- Любая деталь с тегом "Sabotage" становится заданием.
-- Атрибуты детали (необязательные):
--   TaskName (string)  — название задания, например "Засорить унитаз"
--   Points   (number)  — сколько хаоса даёт поломка
--   HoldTime (number)  — сколько секунд держать E
--   Drip     (number)  — хаос в секунду, пока предмет сломан
--   Effect   (string)  — "Lights" = выключает свет во всём ресторане
-- Дети детали: Fire / Smoke / ParticleEmitter / Sparkles / Sound включаются при поломке,
-- а детали с именем "BrokenVisual" становятся видимыми (лужа, пятно, красный экран...).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local SabotageService = {}
local ctx

local function taskName(station)
	return station:GetAttribute("TaskName") or station.Name
end

local function setEffects(station, broken)
	for _, d in station:GetDescendants() do
		if d:IsA("ParticleEmitter") or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") then
			d.Enabled = broken
		elseif d:IsA("Sound") then
			if broken then
				d:Play()
			else
				d:Stop()
			end
		elseif d:IsA("BasePart") and d.Name == "BrokenVisual" then
			d.Transparency = if broken then (d:GetAttribute("VisibleTransparency") or 0) else 1
		end
	end

	if station:GetAttribute("Effect") == "Lights" then
		for _, lamp in CollectionService:GetTagged("RoomLight") do
			for _, l in lamp:GetDescendants() do
				if l:IsA("Light") then
					l.Enabled = not broken
				end
			end
			if lamp:IsA("BasePart") then
				lamp.Material = if broken then Enum.Material.SmoothPlastic else Enum.Material.Neon
			end
		end
	end
end

function SabotageService.sabotage(station, player)
	if not ctx.isPlaying() then
		return
	end
	if player:GetAttribute("Role") ~= "Rat" or player:GetAttribute("Caught") then
		return
	end
	if station:GetAttribute("Broken") then
		return
	end

	station:SetAttribute("Broken", true)
	setEffects(station, true)
	player:SetAttribute("Score", (player:GetAttribute("Score") or 0) + 1)
	ctx.notifyAll(("💥 %s: «%s» — готово!"):format(player.DisplayName, taskName(station)), "good")
	ctx.addChaos(station:GetAttribute("Points") or Config.DefaultTaskPoints)
end

function SabotageService.repair(station, whoName)
	if not ctx.isPlaying() or not station:GetAttribute("Broken") then
		return
	end
	station:SetAttribute("Broken", false)
	setEffects(station, false)
	ctx.notifyAll(("🔧 %s починил: «%s»"):format(whoName or "Повар", taskName(station)), "bad")
end

function SabotageService.getBroken()
	local list = {}
	for _, station in CollectionService:GetTagged("Sabotage") do
		if station:GetAttribute("Broken") then
			table.insert(list, station)
		end
	end
	return list
end

-- Вызывается раз в секунду: сломанные предметы постепенно добавляют хаос
function SabotageService.dripTick()
	local total = 0
	for _, station in SabotageService.getBroken() do
		total += station:GetAttribute("Drip") or Config.DefaultTaskDrip
	end
	if total > 0 then
		ctx.addChaos(total)
	end
end

function SabotageService.reset()
	for _, station in CollectionService:GetTagged("Sabotage") do
		station:SetAttribute("Broken", false)
		setEffects(station, false)
	end
end

local function setupStation(station)
	if not station:IsA("BasePart") then
		warn("[Sabotage] Тег Sabotage нужно ставить на деталь (Part), а не на", station:GetFullName())
		return
	end
	station:SetAttribute("Broken", false)
	setEffects(station, false)

	local sab = Instance.new("ProximityPrompt")
	sab.Name = "SabotagePrompt"
	sab.ActionText = "Напакостить"
	sab.ObjectText = taskName(station)
	sab.HoldDuration = station:GetAttribute("HoldTime") or Config.DefaultSabotageTime
	sab.MaxActivationDistance = 7
	sab.RequiresLineOfSight = false
	sab.Parent = station
	sab.Triggered:Connect(function(player)
		SabotageService.sabotage(station, player)
	end)

	local rep = Instance.new("ProximityPrompt")
	rep.Name = "RepairPrompt"
	rep.ActionText = "Починить"
	rep.ObjectText = taskName(station)
	rep.HoldDuration = Config.RepairTime
	rep.MaxActivationDistance = 9
	rep.RequiresLineOfSight = false
	rep.Parent = station
	rep.Triggered:Connect(function(player)
		if player:GetAttribute("Role") == "Chef" then
			SabotageService.repair(station, player.DisplayName)
		end
	end)
	-- Какую подсказку показывать (крысе или повару) решает RatHUD на стороне игрока.
end

function SabotageService.init(context)
	ctx = context
	for _, station in CollectionService:GetTagged("Sabotage") do
		setupStation(station)
	end
	CollectionService:GetInstanceAddedSignal("Sabotage"):Connect(setupStation)
end

return SabotageService
