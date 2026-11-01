-- PetService (ModuleScript) — ServerScriptService
-- Питомцы 🐹: летают/бегают за игроком и дают бонус к сыру.
-- Покупаются за сыр во вкладке «🐹 Питомцы» магазина.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local PetService = {}
local DataService
local pets = {} -- [игрок] = { model, info, pos, phase }
local folder

local WHITE = Color3.fromRGB(250, 250, 250)
local BLACK = Color3.fromRGB(20, 20, 20)

local function addPart(model, name, size, offset, color, shape, material, ellipsoid)
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
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	if ellipsoid then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.CFrame = offset
	p.Parent = model
	return p
end

-- Модель питомца строится вокруг точки (0,0,0); перед смотрит по -Z
local function buildModel(info)
	local model = Instance.new("Model")
	model.Name = "Pet_" .. info.Id
	local c = info.Color or WHITE
	local body
	local function eyes(y, z, spread, size)
		for _, s in ipairs({ -1, 1 }) do
			addPart(model, "Eye", Vector3.new(size, size, size), CFrame.new(spread * s, y, z), BLACK, Enum.PartType.Ball)
			addPart(model, "Shine", Vector3.new(size * 0.35, size * 0.35, size * 0.35), CFrame.new(spread * s + size * 0.15, y + size * 0.2, z - size * 0.35), WHITE, Enum.PartType.Ball, Enum.Material.Neon)
		end
	end
	if info.Id == "roach" then
		body = addPart(model, "Body", Vector3.new(1.0, 0.45, 1.5), CFrame.new(0, 0, 0), c, nil, nil, true)
		addPart(model, "Head", Vector3.new(0.6, 0.4, 0.5), CFrame.new(0, 0.02, -0.85), c:Lerp(BLACK, 0.3), nil, nil, true)
		for _, s in ipairs({ -1, 1 }) do
			addPart(model, "Antenna", Vector3.new(0.05, 0.05, 1.0), CFrame.new(0.15 * s, 0.25, -1.4) * CFrame.Angles(0.5, 0.3 * s, 0), BLACK)
		end
		eyes(0.12, -1.05, 0.18, 0.14)
	elseif info.Id == "pigeon" or info.Id == "dragon" then
		body = addPart(model, "Body", Vector3.new(1.0, 0.9, 1.4), CFrame.new(0, 0, 0), c, nil, nil, true)
		addPart(model, "Head", Vector3.new(0.7, 0.7, 0.7), CFrame.new(0, 0.45, -0.7), c, Enum.PartType.Ball)
		eyes(0.55, -0.98, 0.18, 0.15)
		local beakColor = info.Id == "pigeon" and Color3.fromRGB(255, 170, 60) or Color3.fromRGB(240, 230, 200)
		addPart(model, "Beak", Vector3.new(0.2, 0.15, 0.35), CFrame.new(0, 0.38, -1.12), beakColor)
		for _, s in ipairs({ -1, 1 }) do
			addPart(model, "Wing", Vector3.new(1.1, 0.1, 0.8), CFrame.new(0.75 * s, 0.25, 0) * CFrame.Angles(0, 0, -0.35 * s), c:Lerp(WHITE, 0.25))
			if info.Id == "dragon" then
				addPart(model, "Horn", Vector3.new(0.12, 0.35, 0.12), CFrame.new(0.2 * s, 0.9, -0.6) * CFrame.Angles(-0.3, 0, 0.2 * s), Color3.fromRGB(255, 240, 200))
			end
		end
		if info.Id == "dragon" then
			addPart(model, "Tail", Vector3.new(0.2, 0.2, 1.0), CFrame.new(0, -0.05, 1.0) * CFrame.Angles(0.3, 0, 0), c)
		end
	elseif info.Id == "slime" then
		body = addPart(model, "Body", Vector3.new(1.4, 1.2, 1.4), CFrame.new(0, 0, 0), c, nil, Enum.Material.Glass, true)
		body.Transparency = 0.2
		eyes(0.2, -0.62, 0.25, 0.2)
		for _, pos in ipairs({ { 0.4, 0.4, 0.3 }, { -0.35, -0.1, 0.5 } }) do
			addPart(model, "Hole", Vector3.new(0.25, 0.25, 0.25), CFrame.new(pos[1], pos[2], pos[3]), c:Lerp(BLACK, 0.25), Enum.PartType.Ball)
		end
	else -- хомяк и золотой хомяк
		local material = info.Id == "goldhamster" and Enum.Material.Metal or nil
		body = addPart(model, "Body", Vector3.new(1.3, 1.15, 1.3), CFrame.new(0, 0, 0), c, Enum.PartType.Ball, material)
		addPart(model, "Belly", Vector3.new(0.9, 0.75, 0.3), CFrame.new(0, -0.15, -0.55), WHITE, nil, nil, true)
		for _, s in ipairs({ -1, 1 }) do
			addPart(model, "Ear", Vector3.new(0.35, 0.35, 0.35), CFrame.new(0.42 * s, 0.55, -0.05), c:Lerp(Color3.fromRGB(255, 160, 180), 0.4), Enum.PartType.Ball)
			addPart(model, "Cheek", Vector3.new(0.3, 0.25, 0.25), CFrame.new(0.42 * s, -0.05, -0.5), Color3.fromRGB(255, 170, 180), Enum.PartType.Ball)
		end
		eyes(0.15, -0.6, 0.22, 0.17)
		addPart(model, "Nose", Vector3.new(0.12, 0.1, 0.1), CFrame.new(0, 0.0, -0.66), Color3.fromRGB(255, 120, 150), Enum.PartType.Ball)
	end
	if info.Id == "goldhamster" or info.Id == "dragon" then
		local sp = Instance.new("Sparkles")
		sp.SparkleColor = info.Color
		sp.Parent = body
	end
	model.PrimaryPart = body
	return model
end

function PetService.bonus(player)
	return DataService.getPet(player).Bonus or 0
end

local function remove(player)
	local entry = pets[player]
	if entry then
		entry.model:Destroy()
		pets[player] = nil
	end
end

-- Пересоздать питомца (после покупки/смены или появления персонажа)
function PetService.refresh(player)
	local info = DataService.getPet(player)
	local entry = pets[player]
	if entry and entry.info.Id == info.Id then
		return
	end
	remove(player)
	if info.Id == "none" then
		return
	end
	local model = buildModel(info)
	model.Parent = folder
	pets[player] = { model = model, info = info, pos = nil, phase = math.random() * 6 }
end

local function step(dt)
	for player, entry in pairs(pets) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not hum or not player.Parent then
			entry.model:PivotTo(CFrame.new(0, -500, 0))
		else
			entry.phase = entry.phase + dt
			local ground = root.Position.Y - root.Size.Y / 2 - hum.HipHeight
			local height
			if entry.info.Flying then
				height = 3.2 + math.sin(entry.phase * 3) * 0.35
			else
				height = 0.6 + math.abs(math.sin(entry.phase * 6)) * 0.25
			end
			local side = root.CFrame * CFrame.new(2.6, 0, 2.2)
			local target = Vector3.new(side.Position.X, ground + height, side.Position.Z)
			local pos = entry.pos or target
			pos = pos:Lerp(target, math.clamp(dt * 8, 0, 1))
			entry.pos = pos
			local look = root.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude < 0.01 then
				flat = Vector3.new(0, 0, -1)
			end
			entry.model:PivotTo(CFrame.lookAt(pos, pos + flat))
		end
	end
end

function PetService.forget(player)
	remove(player)
end

function PetService.init(dataService)
	DataService = dataService
	folder = Instance.new("Folder")
	folder.Name = "Pets"
	folder.Parent = workspace
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc = acc + dt
		if acc >= 1 / 20 then -- 20 раз в секунду достаточно
			step(acc)
			acc = 0
		end
	end)
	Players.PlayerRemoving:Connect(remove)
end

return PetService
