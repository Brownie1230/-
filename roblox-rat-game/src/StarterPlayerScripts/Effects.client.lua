-- Effects (LocalScript) — StarterPlayer > StarterPlayerScripts
-- Всё, что делает игру живой: анимация крыс, крутящийся сыр, мерцающие свечи,
-- тревога, сердцебиение рядом с поваром, шаги повара, взрывы конфетти,
-- тряска камеры, писк "Пи-пи!", звуки и музыка.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local fxEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("FX")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local S = Config.Sounds

-- ===== Звуки =====
local function playAt(soundId, position, volume, speed)
	if not soundId or soundId == "" then
		return
	end
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.new(position)
	holder.Parent = workspace
	local s = Instance.new("Sound")
	s.SoundId = soundId
	s.Volume = volume or 0.8
	s.PlaybackSpeed = speed or 1
	s.RollOffMaxDistance = 90
	s.Parent = holder
	s:Play()
	Debris:AddItem(holder, 4)
end

local function playUI(soundId, volume, speed)
	if not soundId or soundId == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = soundId
	s.Volume = volume or 0.6
	s.PlaybackSpeed = speed or 1
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, 4)
end

-- ===== Частицы =====
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 60)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 230, 110)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 170, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 100, 255)),
})

local function burst(position, colors, count, speed, size)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.5, 0.5, 0.5)
	holder.CFrame = CFrame.new(position)
	holder.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Color = colors
	e.LightEmission = 0.6
	e.Size = NumberSequence.new(size or 0.35, 0)
	e.Lifetime = NumberRange.new(0.8, 1.5)
	e.Speed = NumberRange.new(speed or 12, (speed or 12) * 1.6)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -25, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-200, 200)
	e.Rate = 0
	e.Parent = holder
	e:Emit(count or 40)
	Debris:AddItem(holder, 3)
end

-- ===== Тряска камеры =====
local shakeTime = 0
local shakePower = 0
local function shake(power, duration)
	if power > shakePower or shakeTime <= 0 then
		shakePower = power
	end
	shakeTime = math.max(shakeTime, duration)
end

local function distanceToMe(position)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return math.huge
	end
	return (root.Position - position).Magnitude
end

-- ===== Писк "Пи-пи!" =====
local function squeakBubble(character)
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(110, 44)
	bb.StudsOffset = Vector3.new(0, 2.2, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 80
	bb.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.new(1, 1, 1)
	label.TextColor3 = Color3.fromRGB(40, 30, 40)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "Пи-пи! 🐭"
	label.Parent = bb
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = label
	TweenService:Create(bb, TweenInfo.new(1.4), { StudsOffset = Vector3.new(0, 3.6, 0) }):Play()
	Debris:AddItem(bb, 1.5)
	playAt(S.Squeak, head.Position, 0.7, 2.2 + math.random() * 0.8)
end

-- ===== События от сервера =====
fxEvent.OnClientEvent:Connect(function(kind, a, b)
	if kind == "sabotage" then
		burst(a, RAINBOW, 50, 14, 0.4)
		playAt(S.Sabotage, a, 0.9, 1)
		if distanceToMe(a) < 35 then
			shake(0.5, 0.4)
		end
	elseif kind == "caught" then
		burst(a, ColorSequence.new(Color3.fromRGB(255, 255, 255)), 35, 8, 0.6)
		playAt(S.Catch, a, 1, 0.9)
		if distanceToMe(a) < 10 then
			shake(0.8, 0.5)
		end
	elseif kind == "swing" then
		playAt(S.Swing, a, 0.7, 1)
	elseif kind == "trap" then
		burst(a, ColorSequence.new(Color3.fromRGB(255, 200, 80)), 25, 10, 0.3)
		playAt(S.TrapSnap, a, 1, 1)
		if distanceToMe(a) < 12 then
			shake(0.7, 0.4)
		end
	elseif kind == "repair" then
		burst(a, ColorSequence.new(Color3.fromRGB(110, 190, 255)), 20, 6, 0.25)
	elseif kind == "rescue" then
		burst(a, ColorSequence.new(Color3.fromRGB(120, 255, 140)), 40, 10, 0.35)
		playAt(S.Rescue, a, 1, 1.2)
	elseif kind == "squeak" then
		squeakBubble(a)
	elseif kind == "eat" then
		burst(a, ColorSequence.new(Color3.fromRGB(255, 210, 70)), 15, 5, 0.25)
		playUI(S.Coin, 0.4, 1.6)
	elseif kind == "coins" then
		playUI(S.Coin, 0.5, 1.3)
	elseif kind == "hole" then
		burst(a, ColorSequence.new(Color3.fromRGB(80, 70, 60)), 15, 5, 0.3)
	elseif kind == "results" and type(a) == "table" then
		if a.won then
			playUI(S.Victory, 0.8, 1)
		end
	end
end)

-- ===== Виньетка (края экрана) для тревоги и сердцебиения =====
local fxGui = Instance.new("ScreenGui")
fxGui.Name = "FXGui"
fxGui.ResetOnSpawn = false
fxGui.IgnoreGuiInset = true
fxGui.DisplayOrder = -1
fxGui.Parent = playerGui

local edges = {}
local function edge(anchor, pos, size, rotation)
	local f = Instance.new("Frame")
	f.AnchorPoint = anchor
	f.Position = pos
	f.Size = size
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
	f.BackgroundTransparency = 0
	f.Parent = fxGui
	local g = Instance.new("UIGradient")
	g.Rotation = rotation
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	g.Parent = f
	table.insert(edges, { frame = f, gradient = g })
end
edge(Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.25), 90)
edge(Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.fromScale(1, 0.25), -90)
edge(Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(0.2, 1), 0)
edge(Vector2.new(1, 0), UDim2.fromScale(1, 0), UDim2.fromScale(0.2, 1), 180)

local function setVignette(strength)
	strength = math.clamp(strength, 0, 1)
	for _, e in ipairs(edges) do
		e.frame.Visible = strength > 0.01
		e.gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1 - strength * 0.75),
			NumberSequenceKeypoint.new(1, 1),
		})
	end
end
setVignette(0)

-- ===== Музыка =====
local music = {}
local function track(id)
	if not id or id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Looped = true
	s.Volume = 0
	s.Parent = SoundService
	s:Play()
	return s
end
music.Lobby = track(S.MusicLobby)
music.Round = track(S.MusicRound)
music.Alarm = track(S.MusicAlarm)

local heartbeatSound = nil
if S.Heartbeat and S.Heartbeat ~= "" then
	heartbeatSound = Instance.new("Sound")
	heartbeatSound.SoundId = S.Heartbeat
	heartbeatSound.Looped = true
	heartbeatSound.Volume = 0
	heartbeatSound.Parent = SoundService
	heartbeatSound:Play()
end

-- ===== Анимация крыс =====
local rats = {} -- [модель] = данные

local function setupRat(model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local data = { motors = {}, phase = 0 }
	local function grab(parent, name)
		local m = parent and parent:FindFirstChild(name)
		if m and m:IsA("Motor6D") then
			data.motors[name] = { motor = m, base = m.C0 }
		end
	end
	grab(root, "BodyMotor")
	grab(root, "HeadMotor")
	grab(root, "Tail1Motor")
	grab(model:FindFirstChild("Tail1"), "Tail2Motor")
	data.feet = {}
	for _, m in ipairs(root:GetChildren()) do
		if m.Name == "FootMotor" and m:IsA("Motor6D") then
			table.insert(data.feet, { motor = m, base = m.C0, phase = m:GetAttribute("Phase") or 0 })
		end
	end
	data.root = root
	data.seed = math.random() * 10
	rats[model] = data
	return data
end

local function animateRat(model, data, dt, t)
	local root = data.root
	local vel = root.AssemblyLinearVelocity
	local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
	local moving = math.min(speed / 14, 1.6)
	data.phase = data.phase + dt * (4 + speed * 0.9)
	local p = data.phase
	local s = t + data.seed

	local body = data.motors.BodyMotor
	if body then
		local bob = math.abs(math.sin(p)) * 0.12 * moving
		body.motor.C0 = body.base * CFrame.new(0, bob, 0) * CFrame.Angles(math.sin(p) * 0.06 * moving, 0, math.sin(p * 0.5) * 0.04 * moving)
	end
	local head = data.motors.HeadMotor
	if head then
		local sniff = math.sin(s * 9) * 0.03 * (1 - math.min(moving, 1))
		head.motor.C0 = head.base * CFrame.new(0, math.sin(p) * 0.05 * moving + sniff, 0) * CFrame.Angles(math.sin(s * 1.3) * 0.08, math.sin(s * 0.7) * 0.25 * (1 - math.min(moving, 1)), 0)
	end
	local tail1 = data.motors.Tail1Motor
	if tail1 then
		tail1.motor.C0 = tail1.base * CFrame.Angles(0, math.sin(s * 3) * 0.35 + math.sin(p) * 0.25 * moving, 0)
	end
	local tail2 = data.motors.Tail2Motor
	if tail2 then
		tail2.motor.C0 = tail2.base * CFrame.Angles(math.sin(s * 2) * 0.15, math.sin(s * 3 + 1) * 0.5, 0)
	end
	for _, foot in ipairs(data.feet) do
		local fp = p + foot.phase
		foot.motor.C0 = foot.base * CFrame.new(0, math.max(0, math.sin(fp)) * 0.2 * math.min(moving, 1), math.cos(fp) * 0.3 * math.min(moving, 1))
	end
end

-- ===== Прочее =====
local cheeseBase = {}
local flickerBase = {}
local chefSteps = {}

local function findChefs()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("Role") == "Chef" and p.Character then
			table.insert(list, p.Character)
		end
	end
	local npc = workspace:FindFirstChild("ChefNPC")
	if npc then
		table.insert(list, npc)
	end
	return list
end

local function ensureRatVision(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and not root:FindFirstChild("RatVision") then
		local l = Instance.new("PointLight")
		l.Name = "RatVision"
		l.Range = 11
		l.Brightness = 0.7
		l.Color = Color3.fromRGB(200, 210, 255)
		l.Parent = root
	end
end

local function fadeMusic(s, target, dt)
	if s then
		s.Volume = s.Volume + (target - s.Volume) * math.min(1, dt * 1.5)
	end
end

-- ===== Каждый кадр =====
local camOffset = Vector3.new(0, 0, 0)

RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	local state = ReplicatedStorage:GetAttribute("State") or "Lobby"
	local chaos = ReplicatedStorage:GetAttribute("Chaos") or 0
	local alarm = state == "Playing" and chaos >= Config.AlarmChaos
	local role = player:GetAttribute("Role")
	local character = player.Character
	local myRoot = character and character:FindFirstChild("HumanoidRootPart")
	local hum = character and character:FindFirstChildOfClass("Humanoid")

	-- крысы
	for _, model in ipairs(CollectionService:GetTagged("Rat")) do
		local data = rats[model] or setupRat(model)
		if data and model.Parent then
			animateRat(model, data, dt, t)
		end
	end
	for model in pairs(rats) do
		if not model.Parent then
			rats[model] = nil
		end
	end

	-- сыр крутится и светится
	for _, c in ipairs(CollectionService:GetTagged("Crumb")) do
		if not cheeseBase[c] then
			cheeseBase[c] = c.CFrame
		end
		c.CFrame = cheeseBase[c] * CFrame.new(0, math.sin(t * 2 + cheeseBase[c].Position.X) * 0.12, 0) * CFrame.Angles(0, t * 1.5, 0)
		local glow = c:FindFirstChildOfClass("PointLight")
		if glow then
			glow.Enabled = c.Transparency < 1
		end
	end

	-- свечи мерцают
	for _, l in ipairs(CollectionService:GetTagged("Flicker")) do
		if not flickerBase[l] then
			flickerBase[l] = l.Brightness
		end
		l.Brightness = flickerBase[l] * (0.8 + 0.2 * math.sin(t * 13 + flickerBase[l] * 7) * math.sin(t * 7.3))
	end

	-- тревога
	local pulse = (math.sin(t * 6) + 1) / 2
	for _, lamp in ipairs(CollectionService:GetTagged("AlarmLight")) do
		local light = lamp:FindFirstChildOfClass("PointLight")
		if light then
			light.Enabled = alarm
			light.Brightness = 0.5 + 2.5 * pulse
		end
		if alarm then
			lamp.Material = Enum.Material.Neon
			lamp.Color = Color3.fromRGB(150 + 105 * pulse, 20, 20)
		else
			lamp.Material = Enum.Material.SmoothPlastic
			lamp.Color = Color3.fromRGB(90, 20, 20)
		end
	end

	-- шаги повара (слышно издалека, это страшно!)
	local chefs = findChefs()
	for _, chef in ipairs(chefs) do
		local root = chef:FindFirstChild("HumanoidRootPart")
		if root then
			local steps = chefSteps[chef]
			if not steps and S.Footsteps ~= "" then
				steps = Instance.new("Sound")
				steps.Name = "ChefSteps"
				steps.SoundId = S.Footsteps
				steps.Looped = true
				steps.Volume = 0.9
				steps.PlaybackSpeed = 0.85
				steps.RollOffMaxDistance = 70
				steps.Parent = root
				chefSteps[chef] = steps
			end
			if steps then
				local v = root.AssemblyLinearVelocity
				local movingChef = Vector3.new(v.X, 0, v.Z).Magnitude > 3
				if movingChef and not steps.IsPlaying then
					steps:Play()
				elseif not movingChef and steps.IsPlaying then
					steps:Stop()
				end
			end
		end
	end
	for chef in pairs(chefSteps) do
		if not chef.Parent then
			chefSteps[chef] = nil
		end
	end

	-- сердцебиение: повар рядом с моей крысой
	local heart = 0
	if role == "Rat" and myRoot and not player:GetAttribute("Caught") and state == "Playing" then
		ensureRatVision(character)
		local nearest = math.huge
		for _, chef in ipairs(chefs) do
			local root = chef:FindFirstChild("HumanoidRootPart")
			if root then
				nearest = math.min(nearest, (root.Position - myRoot.Position).Magnitude)
			end
		end
		if nearest < 32 then
			local closeness = 1 - nearest / 32
			local rate = 6 + closeness * 8
			local beat = math.max(0, math.sin(t * rate)) ^ 6
			heart = closeness * (0.35 + 0.65 * beat)
		end
	end
	if heartbeatSound then
		heartbeatSound.Volume = heart * 1.5
		heartbeatSound.PlaybackSpeed = 1 + heart * 0.5
	end
	local vignette = heart
	if alarm then
		vignette = math.max(vignette, 0.25 + 0.25 * pulse)
	end
	setVignette(vignette)

	-- музыка
	local wantLobby, wantRound, wantAlarm = 0, 0, 0
	if state == "Lobby" or state == "Ended" then
		wantLobby = 0.4
	elseif alarm then
		wantAlarm = 0.5
	else
		wantRound = 0.35
	end
	fadeMusic(music.Lobby, wantLobby, dt)
	fadeMusic(music.Round, wantRound, dt)
	fadeMusic(music.Alarm, wantAlarm, dt)

	-- тряска камеры
	if hum then
		if shakeTime > 0 then
			shakeTime = shakeTime - dt
			local p = shakePower * math.max(shakeTime, 0) * 2
			camOffset = Vector3.new((math.random() - 0.5) * p, (math.random() - 0.5) * p, 0)
			hum.CameraOffset = camOffset
		elseif camOffset.Magnitude > 0 then
			camOffset = Vector3.new(0, 0, 0)
			hum.CameraOffset = camOffset
		end
	end
end)

-- звук отсчёта
local lastCount = nil
RunService.Heartbeat:Connect(function()
	local state = ReplicatedStorage:GetAttribute("State")
	local t = ReplicatedStorage:GetAttribute("TimeLeft")
	if state == "Intro" and t ~= lastCount then
		playUI(S.Countdown, 0.6, 1)
	end
	if state == "Intro" then
		lastCount = t
	else
		lastCount = nil
	end
end)
