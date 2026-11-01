-- RatBuilder (ModuleScript) — ServerScriptService
-- Собирает из деталей живую крысу (хвост, лапки и голова двигаются — см. Effects)
-- и делает шапки из магазина.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local RatBuilder = {}

local PINK = Color3.fromRGB(255, 160, 180)
local BLACK = Color3.fromRGB(20, 20, 20)
local WHITE = Color3.fromRGB(250, 250, 250)
local VERT = CFrame.Angles(0, 0, math.rad(90)) -- цилиндр стоит вертикально

local function makePart(name, size, color, shape, ellipsoid, material)
	local p = Instance.new("Part")
	p.Name = name
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	if ellipsoid then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	return p
end

local function weldTo(base, part, cframe)
	part.CFrame = cframe
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = base
	weld.Part1 = part
	weld.Parent = part
end

local function addMotor(name, part0, part1, c0, c1)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = c0
	m.C1 = c1 or CFrame.new()
	m.Parent = part0
	part1.CFrame = part0.CFrame * m.C0 * m.C1:Inverse()
	return m
end

-- ===== Шапки =====
-- Каждая шапка: функция add(размер, позиция, цвет, форма, материал).
-- V и AT уже учитывают размер головы.
local HATS = {}

HATS.cap = function(add, V, AT)
	local red = Color3.fromRGB(220, 50, 50)
	add(V(0.5, 1.0, 1.0), AT(0, 0.25, 0) * VERT, red, Enum.PartType.Cylinder)
	add(V(0.9, 0.08, 0.6), AT(0, 0.05, -0.6), red)
	add(V(0.15, 0.15, 0.15), AT(0, 0.52, 0), WHITE, Enum.PartType.Ball)
end

HATS.bow = function(add, V, AT)
	local pink = Color3.fromRGB(255, 105, 180)
	add(V(0.3, 0.3, 0.3), AT(0, 0.15, 0), pink, Enum.PartType.Ball)
	add(V(0.45, 0.3, 0.15), AT(0.3, 0.15, 0) * CFrame.Angles(0, 0, 0.4), pink)
	add(V(0.45, 0.3, 0.15), AT(-0.3, 0.15, 0) * CFrame.Angles(0, 0, -0.4), pink)
end

HATS.party = function(add, V, AT)
	local colors = { Color3.fromRGB(80, 180, 255), Color3.fromRGB(255, 220, 60) }
	for i = 0, 4 do
		local d = 0.9 - i * 0.17
		add(V(0.25, d, d), AT(0, 0.125 + i * 0.25, 0) * VERT, colors[(i % 2) + 1], Enum.PartType.Cylinder)
	end
	add(V(0.28, 0.28, 0.28), AT(0, 1.35, 0), Color3.fromRGB(255, 80, 160), Enum.PartType.Ball)
end

HATS.cowboy = function(add, V, AT)
	local brown = Color3.fromRGB(140, 90, 50)
	add(V(0.1, 2.0, 2.0), AT(0, 0.05, 0) * VERT, brown, Enum.PartType.Cylinder)
	add(V(0.7, 1.05, 1.05), AT(0, 0.4, 0) * VERT, brown, Enum.PartType.Cylinder)
	add(V(0.15, 1.08, 1.08), AT(0, 0.17, 0) * VERT, Color3.fromRGB(60, 35, 20), Enum.PartType.Cylinder)
end

HATS.pumpkin = function(add, V, AT)
	add(V(1.2, 1.2, 1.2), AT(0, 0.5, 0), Color3.fromRGB(255, 140, 30), Enum.PartType.Ball)
	add(V(0.3, 0.15, 0.15), AT(0, 1.15, 0) * VERT, Color3.fromRGB(60, 140, 50), Enum.PartType.Cylinder)
	local glow = Color3.fromRGB(255, 220, 80)
	add(V(0.2, 0.2, 0.06), AT(0.22, 0.62, -0.57), glow, nil, Enum.Material.Neon)
	add(V(0.2, 0.2, 0.06), AT(-0.22, 0.62, -0.57), glow, nil, Enum.Material.Neon)
	add(V(0.5, 0.12, 0.06), AT(0, 0.32, -0.56), glow, nil, Enum.Material.Neon)
end

HATS.tophat = function(add, V, AT)
	local black = Color3.fromRGB(25, 25, 30)
	add(V(0.08, 1.5, 1.5), AT(0, 0.04, 0) * VERT, black, Enum.PartType.Cylinder)
	add(V(1.0, 0.95, 0.95), AT(0, 0.55, 0) * VERT, black, Enum.PartType.Cylinder)
	add(V(0.18, 0.97, 0.97), AT(0, 0.2, 0) * VERT, Color3.fromRGB(200, 30, 40), Enum.PartType.Cylinder)
end

HATS.chef = function(add, V, AT)
	add(V(0.4, 1.0, 1.0), AT(0, 0.2, 0) * VERT, WHITE, Enum.PartType.Cylinder)
	add(V(1.2, 1.2, 1.2), AT(0, 0.75, 0), WHITE, Enum.PartType.Ball)
end

HATS.pirate = function(add, V, AT)
	local black = Color3.fromRGB(25, 25, 30)
	add(V(0.1, 1.6, 1.6), AT(0, 0.05, 0) * VERT, black, Enum.PartType.Cylinder)
	add(V(0.5, 1.0, 1.0), AT(0, 0.3, 0) * VERT, black, Enum.PartType.Cylinder)
	add(V(1.4, 0.6, 0.1), AT(0, 0.4, -0.7) * CFrame.Angles(math.rad(-20), 0, 0), black)
	add(V(0.3, 0.3, 0.3), AT(0, 0.45, -0.78), WHITE, Enum.PartType.Ball)
end

HATS.crown = function(add, V, AT)
	local gold = Color3.fromRGB(255, 200, 40)
	add(V(0.3, 1.0, 1.0), AT(0, 0.15, 0) * VERT, gold, Enum.PartType.Cylinder, Enum.Material.Metal)
	for i = 0, 5 do
		local a = i * math.pi / 3
		add(V(0.15, 0.4, 0.15), CFrame.Angles(0, a, 0) * AT(0, 0.45, -0.42), gold, nil, Enum.Material.Metal)
	end
	add(V(0.16, 0.16, 0.16), AT(0, 0.17, -0.5), Color3.fromRGB(230, 30, 60), Enum.PartType.Ball, Enum.Material.Neon)
end

HATS.vipcrown = function(add, V, AT)
	local gold = Color3.fromRGB(255, 205, 50)
	add(V(0.35, 1.15, 1.15), AT(0, 0.17, 0) * VERT, gold, Enum.PartType.Cylinder, Enum.Material.Metal)
	for i = 0, 7 do
		local a = i * math.pi / 4
		add(V(0.18, 0.55, 0.18), CFrame.Angles(0, a, 0) * AT(0, 0.55, -0.5), gold, nil, Enum.Material.Metal)
		add(V(0.14, 0.14, 0.14), CFrame.Angles(0, a, 0) * AT(0, 0.88, -0.5), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball, Enum.Material.Neon)
	end
	add(V(0.24, 0.24, 0.24), AT(0, 0.2, -0.58), Color3.fromRGB(60, 140, 255), Enum.PartType.Ball, Enum.Material.Neon)
end

HATS.halo = function(add, V, AT)
	local glow = Color3.fromRGB(255, 240, 120)
	for i = 0, 9 do
		local a = i * math.pi / 5
		add(V(0.16, 0.16, 0.16), CFrame.Angles(0, a, 0) * AT(0, 0.7, -0.5), glow, Enum.PartType.Ball, Enum.Material.Neon)
	end
end

-- Надеть шапку на голову персонажа (крысы или человека в лобби)
function RatBuilder.attachHat(character, head, hatId, scale, topOffset)
	local old = character:FindFirstChild("Hat")
	if old then
		old:Destroy()
	end
	local builder = HATS[hatId or "none"]
	if not builder or not head then
		return
	end
	local hatModel = Instance.new("Model")
	hatModel.Name = "Hat"
	local anchor = head.CFrame * topOffset
	local function V(x, y, z)
		return Vector3.new(x * scale, y * scale, z * scale)
	end
	local function AT(x, y, z)
		return CFrame.new(x * scale, y * scale, z * scale)
	end
	local function add(size, rel, color, shape, material)
		local p = makePart("HatPart", size, color, shape, false, material)
		weldTo(head, p, anchor * rel)
		p.Parent = hatModel
		return p
	end
	builder(add, V, AT)
	hatModel.Parent = character
end

-- ===== Крыса =====
function RatBuilder.build(player, cframe)
	local model = Instance.new("Model")
	model.Name = player.Name

	local color = Config.RatColors[math.random(#Config.RatColors)]
	local earColor = color:Lerp(PINK, 0.55)

	-- Невидимое "ядро": по нему крыса ходит и сталкивается со стенами
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(1.4, 1, 2.4)
	root.Transparency = 1
	root.CanCollide = true
	root.CFrame = cframe
	root.Parent = model
	model.PrimaryPart = root

	-- Тело и голова на моторах (их покачивает скрипт Effects). Перед крысы смотрит по -Z.
	local body = makePart("Body", Vector3.new(1.5, 1.2, 2.6), color, nil, true)
	addMotor("BodyMotor", root, body, CFrame.new(0, 0.1, 0.1))
	body.Parent = model
	local belly = makePart("Belly", Vector3.new(1.1, 0.7, 1.9), color:Lerp(WHITE, 0.45), nil, true)
	weldTo(body, belly, body.CFrame * CFrame.new(0, -0.3, -0.1))
	belly.Parent = model

	local head = makePart("Head", Vector3.new(1.1, 1, 1.4), color, nil, true)
	addMotor("HeadMotor", root, head, CFrame.new(0, 0.35, -1.45))
	head.Parent = model

	local function onHead(name, size, offset, c, shape, material)
		local p = makePart(name, size, c, shape, false, material)
		weldTo(head, p, head.CFrame * offset)
		p.Parent = model
		return p
	end
	onHead("Nose", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, -0.05, -0.7), PINK, Enum.PartType.Ball)
	for _, side in ipairs({ -1, 1 }) do
		onHead("Eye", Vector3.new(0.24, 0.24, 0.24), CFrame.new(0.32 * side, 0.25, -0.4), BLACK, Enum.PartType.Ball)
		onHead("EyeShine", Vector3.new(0.08, 0.08, 0.08), CFrame.new(0.32 * side + 0.04, 0.31, -0.5), WHITE, Enum.PartType.Ball, Enum.Material.Neon)
		onHead("Ear", Vector3.new(0.12, 0.65, 0.65), CFrame.new(0.42 * side, 0.6, 0.25), earColor, Enum.PartType.Cylinder)
		onHead("Tooth", Vector3.new(0.1, 0.16, 0.05), CFrame.new(0.06 * side, -0.32, -0.6), WHITE)
		for _, tilt in ipairs({ -0.15, 0.15 }) do
			onHead(
				"Whisker",
				Vector3.new(0.7, 0.03, 0.03),
				CFrame.new(0.42 * side, -0.05, -0.55) * CFrame.Angles(0, 0.25 * side, tilt),
				Color3.fromRGB(230, 230, 230)
			)
		end
	end

	-- Хвост из двух частей, лапки
	local tail1 = makePart("Tail1", Vector3.new(0.2, 0.2, 1.3), PINK)
	addMotor("Tail1Motor", root, tail1, CFrame.new(0, -0.05, 1.3) * CFrame.Angles(math.rad(12), 0, 0), CFrame.new(0, 0, -0.65))
	tail1.Parent = model
	local tail2 = makePart("Tail2", Vector3.new(0.15, 0.15, 1.3), PINK)
	addMotor("Tail2Motor", tail1, tail2, CFrame.new(0, 0, 0.6) * CFrame.Angles(math.rad(-18), 0, 0), CFrame.new(0, 0, -0.6))
	tail2.Parent = model
	for _, side in ipairs({ -1, 1 }) do
		for _, front in ipairs({ -1, 1 }) do
			local foot = makePart("Foot", Vector3.new(0.42, 0.42, 0.42), PINK, Enum.PartType.Ball)
			local m = addMotor("FootMotor", root, foot, CFrame.new(0.5 * side, -0.75, 0.75 * front))
			if side * front > 0 then
				m:SetAttribute("Phase", 0)
			else
				m:SetAttribute("Phase", math.pi)
			end
			foot.Parent = model
		end
	end

	RatBuilder.attachHat(model, head, player:GetAttribute("Hat"), 0.8, CFrame.new(0, 0.42, 0.05))

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15 -- R15 использует HipHeight, ноги не нужны
	hum.RequiresNeck = false -- у крысы нет "шеи", иначе она сразу умрёт
	hum.BreakJointsOnDeath = false
	hum.HipHeight = 0.5
	hum.WalkSpeed = Config.RatWalkSpeed
	hum.UseJumpPower = true
	hum.JumpPower = Config.RatJumpPower
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.DisplayName = player.DisplayName
	if player:GetAttribute("VIP") then
		hum.DisplayName = "👑 " .. player.DisplayName
		local sp = Instance.new("Sparkles")
		sp.SparkleColor = Color3.fromRGB(255, 215, 80)
		sp.Parent = body
	end
	hum.NameDisplayDistance = 40
	hum.Parent = model

	model:AddTag("Rat")
	return model
end

return RatBuilder
