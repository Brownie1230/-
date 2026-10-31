-- ChefService (ModuleScript) — ServerScriptService
-- Сачок повара, клетки для крыс, колпак и фонарик.
-- Клетка = деталь-пол с тегом "Cage". Пойманные крысы телепортируются туда.
-- Свободная крыса может открыть клетку (держать E рядом).

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local ChefService = {}
local ctx
local cageOccupants = {} -- [клетка] = { [игрок] = true }
local lastSwing = {}

local WHITE = Color3.fromRGB(245, 245, 245)

local function getRoot(model)
	return model and model:FindFirstChild("HumanoidRootPart")
end

local function isFreeRat(player)
	return player:GetAttribute("Role") == "Rat" and not player:GetAttribute("Caught")
end

-- ===== Поймать / освободить =====

function ChefService.catchRat(rat)
	if not ctx.isPlaying() or not isFreeRat(rat) then
		return false
	end
	local root = getRoot(rat.Character)
	if not root then
		return false
	end

	local cage, best = nil, math.huge
	for _, c in CollectionService:GetTagged("Cage") do
		local d = (c.Position - root.Position).Magnitude
		if d < best then
			cage, best = c, d
		end
	end
	if not cage then
		warn("[Chef] На карте нет клетки (деталь с тегом Cage)!")
		return false
	end

	rat:SetAttribute("Caught", true)
	rat:SetAttribute("BaseSpeed", 0)
	cageOccupants[cage] = cageOccupants[cage] or {}
	cageOccupants[cage][rat] = true

	local hum = rat.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = 0
		hum.JumpPower = 0
	end
	local offset = CFrame.new(math.random(-15, 15) / 10, cage.Size.Y / 2 + 1.3, math.random(-15, 15) / 10)
	rat.Character:PivotTo(cage.CFrame * offset)

	ctx.notifyAll(("🪤 %s попался в клетку! Спасите!"):format(rat.DisplayName), "bad")
	ctx.checkAllCaught()
	return true
end

function ChefService.release(rat)
	rat:SetAttribute("Caught", false)
	rat:SetAttribute("BaseSpeed", Config.RatWalkSpeed)
	local character = rat.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.JumpPower = Config.RatJumpPower
	end
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
	for rat in occupants do
		if rat.Parent and rat:GetAttribute("Caught") then
			ChefService.release(rat)
			freed += 1
		end
	end
	cageOccupants[cage] = {}
	if freed > 0 then
		rescuer:SetAttribute("Score", (rescuer:GetAttribute("Score") or 0) + freed)
		ctx.notifyAll(("🔓 %s открыл клетку! Свободно крыс: %d"):format(rescuer.DisplayName, freed), "good")
	end
end

local function setupCage(cage)
	if not cage:IsA("BasePart") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FreePrompt"
	prompt.ActionText = "Открыть клетку"
	prompt.ObjectText = "Клетка"
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

	-- Фонарик на лбу — в темноте повар видит, а крысы видят повара
	local light = Instance.new("SpotLight")
	light.Name = "ChefLamp"
	light.Face = Enum.NormalId.Front
	light.Angle = 70
	light.Range = 40
	light.Brightness = 3
	light.Color = Color3.fromRGB(255, 240, 210)
	light.Parent = head
end

-- ===== Сачок =====

function ChefService.giveTool(player)
	local tool = Instance.new("Tool")
	tool.Name = "Сачок"
	tool.ToolTip = "Клик — поймать крысу"
	tool.CanBeDropped = false
	-- держим сачок за конец, сетка смотрит вверх
	tool.Grip = CFrame.fromMatrix(Vector3.new(0, 0, -1.5), Vector3.new(0, 1, 0), Vector3.new(0, 0, 1), Vector3.new(1, 0, 0))

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.3, 4)
	handle.Color = Color3.fromRGB(110, 75, 45)
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.CFrame = CFrame.new()
	handle.Parent = tool

	local net = Instance.new("Part")
	net.Name = "Net"
	net.Shape = Enum.PartType.Cylinder
	net.Size = Vector3.new(0.15, 2.2, 2.2)
	net.Color = WHITE
	net.Transparency = 0.35
	net.CanCollide = false
	net.Massless = true
	net.CFrame = CFrame.new(0, 0, 2.9)
	net.Parent = tool
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = net
	weld.Parent = net

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
		local best, bestDist = nil, Config.CatchRange
		for _, other in Players:GetPlayers() do
			local r = other ~= player and isFreeRat(other) and getRoot(other.Character)
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
			ChefService.catchRat(best)
		end
	end)

	tool.Parent = player:WaitForChild("Backpack")
end

-- ===== Служебное =====

function ChefService.reset()
	cageOccupants = {}
	for _, p in Players:GetPlayers() do
		p:SetAttribute("Caught", false)
	end
end

function ChefService.forget(player)
	lastSwing[player] = nil
	for _, occupants in cageOccupants do
		occupants[player] = nil
	end
end

function ChefService.init(context)
	ctx = context
	for _, cage in CollectionService:GetTagged("Cage") do
		setupCage(cage)
	end
	CollectionService:GetInstanceAddedSignal("Cage"):Connect(setupCage)
end

return ChefService
