-- ChefService (ModuleScript) — ServerScriptService
-- Сачок и мышеловки повара, клетки для крыс, колпак и фонарик.
-- Клетка = деталь-пол с тегом "Cage". Пойманные крысы телепортируются туда.
-- Свободная крыса может открыть клетку (держать E рядом).

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Locale = require(ReplicatedStorage:WaitForChild("Locale"))

local ChefService = {}
local ctx
local cageOccupants = {} -- [клетка] = { [игрок] = true }
local lastSwing = {}
local lastTrap = {}
local traps = {} -- поставленные мышеловки (по порядку)

local WHITE = Color3.fromRGB(245, 245, 245)

local function getRoot(model)
	return model and model:FindFirstChild("HumanoidRootPart")
end

local function isFreeRat(player)
	return player:GetAttribute("Role") == "Rat" and not player:GetAttribute("Caught")
end

local function simplePart(name, size, cframe, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

-- ===== Поймать / освободить =====

function ChefService.catchRat(rat, catcher)
	if not ctx.isPlaying() or not isFreeRat(rat) then
		return false
	end
	local root = getRoot(rat.Character)
	if not root then
		return false
	end

	if rat:GetAttribute("Armored") then
		ctx.notifyAll("info", "armor_block", rat.DisplayName)
		ctx.fxAll("repair", root.Position)
		return false
	end
	local cage, best = nil, math.huge
	for _, c in ipairs(Config.taggedInMap("Cage")) do
		local d = (c.Position - root.Position).Magnitude
		if d < best then
			cage, best = c, d
		end
	end
	if not cage then
		warn("[Chef] На карте нет клетки (деталь с тегом Cage)!")
		return false
	end

	ctx.fxAll("caught", root.Position)
	rat:SetAttribute("Caught", true)
	rat:SetAttribute("Stunned", false)
	cageOccupants[cage] = cageOccupants[cage] or {}
	cageOccupants[cage][rat] = true
	ctx.onCaught(rat)
	ctx.refreshSpeed(rat)

	local hum = rat.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.JumpPower = 0
	end
	local offset = CFrame.new(math.random(-15, 15) / 10, cage.Size.Y / 2 + 1.3, math.random(-15, 15) / 10)
	rat.Character:PivotTo(cage.CFrame * offset)

	if catcher then
		catcher:SetAttribute("Score", (catcher:GetAttribute("Score") or 0) + 1)
		ctx.reward(catcher, "Catch")
	end
	ctx.notifyAll("bad", "caught", rat.DisplayName)
	ctx.checkAllCaught()
	return true
end

function ChefService.release(rat)
	rat:SetAttribute("Caught", false)
	local character = rat.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.JumpPower = Config.RatJumpPower
	end
	ctx.refreshSpeed(rat)
	local spawnPart = ctx.getSpawn("RatSpawn")
	if character and spawnPart then
		character:PivotTo(CFrame.new(spawnPart.Position + Vector3.new(0, 2, 0)))
	end
end

local function freeCage(cage, rescuer)
	local occupants = cageOccupants[cage]
	if not occupants then
		return
	end
	local freed = 0
	for rat in pairs(occupants) do
		if rat.Parent and rat:GetAttribute("Caught") then
			ChefService.release(rat)
			freed = freed + 1
		end
	end
	cageOccupants[cage] = {}
	if freed > 0 then
		rescuer:SetAttribute("Score", (rescuer:GetAttribute("Score") or 0) + freed)
		ctx.reward(rescuer, "Rescue")
		ctx.fxAll("rescue", cage.Position)
		ctx.notifyAll("good", "rescued", rescuer.DisplayName, freed)
	end
end

local function setupCage(cage)
	if not cage:IsA("BasePart") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FreePrompt"
	prompt.ActionText = "Open cage"
	prompt.ObjectText = "Cage"
	prompt.HoldDuration = Config.FreeCageTime
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = cage
	prompt.Triggered:Connect(function(player)
		if ctx.isPlaying() and isFreeRat(player) then
			freeCage(cage, player)
		end
	end)
end

-- ===== Мышеловки =====

function ChefService.stunRat(rat)
	if not isFreeRat(rat) or rat:GetAttribute("Stunned") then
		return
	end
	rat:SetAttribute("Stunned", true)
	ctx.refreshSpeed(rat)
	local hum = rat.Character and rat.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.JumpPower = 0
	end
	ctx.notifyAll("bad", "trapped", rat.DisplayName)
	task.delay(Config.TrapStunTime, function()
		if not rat.Parent then
			return
		end
		rat:SetAttribute("Stunned", false)
		local h = rat.Character and rat.Character:FindFirstChildOfClass("Humanoid")
		if h and not rat:GetAttribute("Caught") then
			h.JumpPower = Config.RatJumpPower
		end
		ctx.refreshSpeed(rat)
	end)
end

local function removeTrap(model)
	for i, t in ipairs(traps) do
		if t == model then
			table.remove(traps, i)
			break
		end
	end
	model:Destroy()
end

function ChefService.placeTrap(position)
	if #traps >= Config.MaxTraps then
		removeTrap(traps[1])
	end

	-- находим пол под точкой
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local ignore = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	local npc = workspace:FindFirstChild("ChefNPC")
	if npc then
		table.insert(ignore, npc)
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(position + Vector3.new(0, 3, 0), Vector3.new(0, -14, 0), params)
	local floorY = position.Y - 2.8
	if hit then
		floorY = hit.Position.Y
	end
	local base = CFrame.new(position.X, floorY, position.Z)

	local model = Instance.new("Model")
	model.Name = "Mousetrap"
	local board = simplePart("Board", Vector3.new(1.6, 0.2, 2.4), base * CFrame.new(0, 0.1, 0), Color3.fromRGB(190, 140, 80), Enum.Material.Wood)
	local bar = simplePart("Bar", Vector3.new(1.5, 0.12, 0.12), base * CFrame.new(0, 0.28, -0.6), Color3.fromRGB(200, 200, 205), Enum.Material.Metal)
	local spring = simplePart("Spring", Vector3.new(0.6, 0.15, 0.15), base * CFrame.new(0, 0.28, 0.2), Color3.fromRGB(200, 200, 205), Enum.Material.Metal)
	local bait = simplePart("Bait", Vector3.new(0.45, 0.3, 0.45), base * CFrame.new(0, 0.35, 0.6), Color3.fromRGB(255, 205, 60))
	local sensor = simplePart("Sensor", Vector3.new(2, 1.6, 2.8), base * CFrame.new(0, 0.8, 0), WHITE)
	sensor.Transparency = 1
	for _, p in ipairs({ board, bar, spring, bait, sensor }) do
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Parent = model
	end
	model.PrimaryPart = board
	model.Parent = workspace
	table.insert(traps, model)

	sensor.Touched:Connect(function(hit2)
		if model:GetAttribute("Sprung") or not ctx.isPlaying() then
			return
		end
		local rat = Players:GetPlayerFromCharacter(hit2.Parent)
		if rat and isFreeRat(rat) and not rat:GetAttribute("Stunned") then
			model:SetAttribute("Sprung", true)
			bar.CFrame = base * CFrame.new(0, 0.28, 0.9)
			ChefService.stunRat(rat)
			ctx.fxAll("trap", base.Position)
			ctx.alertNoise(base.Position)
			task.delay(2, function()
				if model.Parent then
					removeTrap(model)
				end
			end)
		end
	end)
	return model
end

-- ===== Внешний вид повара =====

function ChefService.dressChef(character)
	local head = character:WaitForChild("Head", 5)
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not head or not hum then
		return
	end

	-- Поварской колпак (собираем из шара и цилиндра)
	local hat = Instance.new("Accessory")
	hat.Name = "ChefHat"
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Shape = Enum.PartType.Ball
	handle.Size = Vector3.new(1.9, 1.9, 1.9)
	handle.Color = WHITE
	handle.CanCollide = false
	handle.Massless = true
	handle.CFrame = CFrame.new()
	handle.Parent = hat
	local att = Instance.new("Attachment")
	att.Name = "HatAttachment"
	att.Position = Vector3.new(0, -0.8, 0)
	att.Parent = handle
	local band = Instance.new("Part")
	band.Name = "Band"
	band.Shape = Enum.PartType.Cylinder
	band.Size = Vector3.new(0.7, 1.5, 1.5)
	band.Color = WHITE
	band.CanCollide = false
	band.Massless = true
	band.CFrame = CFrame.new(0, -0.75, 0) * CFrame.Angles(0, 0, math.rad(90))
	band.Parent = hat
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = band
	weld.Parent = band
	hum:AddAccessory(hat)

	-- Фонарик на лбу: в темноте повар видит, а крысы видят повара
	local light = Instance.new("SpotLight")
	light.Name = "ChefLamp"
	light.Face = Enum.NormalId.Front
	light.Angle = 70
	light.Range = 40
	light.Brightness = 3
	light.Color = Color3.fromRGB(255, 240, 210)
	light.Parent = head
end

-- ===== Инструменты =====

function ChefService.makeNetTool(lang)
	lang = lang or "en"
	local tool = Instance.new("Tool")
	tool.Name = Locale.t(lang, "tool_net")
	tool.ToolTip = Locale.t(lang, "tool_net_tip")
	tool:SetAttribute("ToolKind", "Net")
	tool.CanBeDropped = false
	-- держим сачок за конец, сетка смотрит вверх
	tool.Grip = CFrame.fromMatrix(Vector3.new(0, 0, -1.5), Vector3.new(0, 1, 0), Vector3.new(0, 0, 1), Vector3.new(1, 0, 0))

	local handle = simplePart("Handle", Vector3.new(0.3, 0.3, 4), CFrame.new(), Color3.fromRGB(110, 75, 45), Enum.Material.Wood)
	handle.CanCollide = false
	handle.Parent = tool

	local ring = simplePart("Ring", Vector3.new(0.2, 2.3, 2.3), CFrame.new(0, 0, 2.9), Color3.fromRGB(90, 90, 95), Enum.Material.Metal)
	ring.Shape = Enum.PartType.Cylinder
	local net = simplePart("Net", Vector3.new(0.12, 2.1, 2.1), CFrame.new(0, 0, 2.9), WHITE, Enum.Material.Fabric)
	net.Shape = Enum.PartType.Cylinder
	net.Transparency = 0.4
	for _, p in ipairs({ ring, net }) do
		p.CanCollide = false
		p.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = p
		weld.Parent = p
		p.Parent = tool
	end
	return tool
end

function ChefService.giveTool(player)
	local tool = ChefService.makeNetTool(Locale.detect(player))
	tool.Activated:Connect(function()
		local now = os.clock()
		if (lastSwing[player] or 0) + Config.CatchCooldown > now then
			return
		end
		lastSwing[player] = now

		-- стандартная анимация взмаха
		local anim = Instance.new("StringValue")
		anim.Name = "toolanim"
		anim.Value = "Slash"
		anim.Parent = tool
		game:GetService("Debris"):AddItem(anim, 1)

		local root = getRoot(player.Character)
		if not root then
			return
		end
		ctx.fxAll("swing", root.Position)
		local best, bestDist = nil, Config.CatchRange
		for _, other in ipairs(Players:GetPlayers()) do
			local r = nil
			if other ~= player and isFreeRat(other) then
				r = getRoot(other.Character)
			end
			if r then
				local delta = r.Position - root.Position
				local dist = delta.Magnitude
				local inFront = dist < 3 or root.CFrame.LookVector:Dot(delta.Unit) > 0.2
				if dist < bestDist and inFront then
					best, bestDist = other, dist
				end
			end
		end
		if best then
			ChefService.catchRat(best, player)
		end
	end)
	tool.Parent = player:WaitForChild("Backpack")
end

function ChefService.giveTrapTool(player)
	local lang = Locale.detect(player)
	local tool = Instance.new("Tool")
	tool.Name = Locale.t(lang, "tool_trap")
	tool.ToolTip = Locale.t(lang, "tool_trap_tip")
	tool:SetAttribute("ToolKind", "Trap")
	tool.CanBeDropped = false
	local handle = simplePart("Handle", Vector3.new(1, 0.2, 1.4), CFrame.new(), Color3.fromRGB(190, 140, 80), Enum.Material.Wood)
	handle.CanCollide = false
	handle.Parent = tool

	tool.Activated:Connect(function()
		local now = os.clock()
		local left = (lastTrap[player] or -1000) + Config.TrapCooldown - now
		if left > 0 then
			ctx.notifyPlayer(player, "info", "trap_cooldown", math.ceil(left))
			return
		end
		local root = getRoot(player.Character)
		if not root or not ctx.isPlaying() then
			return
		end
		lastTrap[player] = now
		ChefService.placeTrap(root.Position + root.CFrame.LookVector * 4)
		ctx.notifyPlayer(player, "info", "trap_placed")
	end)
	tool.Parent = player:WaitForChild("Backpack")
end

-- ===== Служебное =====

function ChefService.reset()
	cageOccupants = {}
	lastTrap = {}
	while #traps > 0 do
		removeTrap(traps[1])
	end
	for _, p in ipairs(Players:GetPlayers()) do
		p:SetAttribute("Caught", false)
		p:SetAttribute("Stunned", false)
	end
end

function ChefService.forget(player)
	lastSwing[player] = nil
	lastTrap[player] = nil
	for _, occupants in pairs(cageOccupants) do
		occupants[player] = nil
	end
end

function ChefService.trapCount()
	return #traps
end

function ChefService.init(context)
	ctx = context
	for _, cage in ipairs(CollectionService:GetTagged("Cage")) do
		setupCage(cage)
	end
	CollectionService:GetInstanceAddedSignal("Cage"):Connect(setupCage)
end

return ChefService
