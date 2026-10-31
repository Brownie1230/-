-- RatBuilder (ModuleScript) — ServerScriptService
-- Собирает из деталей настоящую маленькую крысу, которой управляет игрок.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local RatBuilder = {}

local PINK = Color3.fromRGB(255, 160, 180)
local BLACK = Color3.fromRGB(20, 20, 20)

local function addPart(model, root, name, size, offset, color, shape, ellipsoid)
	local p = Instance.new("Part")
	p.Name = name
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.Massless = true
	p.Anchored = false
	if ellipsoid then
		-- SpecialMesh Sphere растягивается по размеру детали => получается овал
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.CFrame = root.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = p
	weld.Parent = p
	p.Parent = model
	return p
end

function RatBuilder.build(player, cframe)
	local model = Instance.new("Model")
	model.Name = player.Name

	local color = Config.RatColors[math.random(#Config.RatColors)]

	-- Невидимое "ядро" — по нему крыса ходит и сталкивается со стенами
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(1.4, 1, 2.4)
	root.Transparency = 1
	root.CanCollide = true
	root.CFrame = cframe
	root.Parent = model
	model.PrimaryPart = root

	-- Тело и голова (перед крысы смотрит по -Z)
	addPart(model, root, "Body", Vector3.new(1.5, 1.2, 2.6), CFrame.new(0, 0.1, 0.1), color, nil, true)
	addPart(model, root, "Head", Vector3.new(1.1, 1, 1.4), CFrame.new(0, 0.35, -1.45), color, nil, true)
	addPart(model, root, "Nose", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, 0.3, -2.15), PINK, Enum.PartType.Ball)
	for _, side in { -1, 1 } do
		addPart(model, root, "Eye", Vector3.new(0.22, 0.22, 0.22), CFrame.new(0.32 * side, 0.6, -1.85), BLACK, Enum.PartType.Ball)
		addPart(
			model,
			root,
			"Ear",
			Vector3.new(0.12, 0.6, 0.6),
			CFrame.new(0.42 * side, 0.95, -1.2),
			color:Lerp(PINK, 0.5),
			Enum.PartType.Cylinder
		)
		for _, front in { -1, 1 } do
			addPart(model, root, "Foot", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0.5 * side, -0.75, 0.75 * front), PINK, Enum.PartType.Ball)
		end
	end
	addPart(model, root, "Tail", Vector3.new(0.18, 0.18, 2.4), CFrame.new(0, -0.05, 2.4) * CFrame.Angles(math.rad(12), 0, 0), PINK)

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
	hum.NameDisplayDistance = 40
	hum.Parent = model

	return model
end

return RatBuilder
