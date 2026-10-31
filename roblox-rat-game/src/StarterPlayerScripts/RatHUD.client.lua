-- RatHUD (LocalScript) — StarterPlayer > StarterPlayerScripts
-- Интерфейс: таймер, шкала хаоса, сытость, бег, задания, сообщения.
-- Также: бег на Shift, кнопка бега на телефоне, подсказки только для своей роли.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local notifyEvent = ReplicatedStorage:WaitForChild("Notify")
local volunteerEvent = ReplicatedStorage:WaitForChild("ChefVolunteer")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Пойманная крыса не должна сбегать через "Reset"
task.spawn(function()
	for _ = 1, 10 do
		if pcall(StarterGui.SetCore, StarterGui, "ResetButtonCallback", false) then
			break
		end
		task.wait(1)
	end
end)

-- ===== Стиль =====
local FONT = Enum.Font.FredokaOne
local PANEL = Color3.fromRGB(28, 22, 30)
local WHITE = Color3.new(1, 1, 1)
local KIND_COLORS = {
	info = WHITE,
	good = Color3.fromRGB(140, 240, 140),
	bad = Color3.fromRGB(255, 130, 120),
	banner = Color3.fromRGB(255, 220, 90),
}

local function make(className, parent, props)
	local inst = Instance.new(className)
	for k, v in props or {} do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function corner(parent, r)
	make("UICorner", parent, { CornerRadius = UDim.new(0, r or 10) })
end

local function panel(parent, props)
	local f = make("Frame", parent, props)
	f.BackgroundColor3 = PANEL
	f.BackgroundTransparency = 0.25
	f.BorderSizePixel = 0
	corner(f)
	return f
end

local gui = make("ScreenGui", playerGui, { Name = "RatHUD", ResetOnSpawn = false })

-- ===== Верх: таймер и хаос =====
local top = panel(gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 6),
	Size = UDim2.fromOffset(340, 74),
})
local statusLabel = make("TextLabel", top, {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 4),
	Size = UDim2.new(1, 0, 0, 30),
	Font = FONT,
	TextScaled = true,
	TextColor3 = WHITE,
	Text = "",
})
local chaosBg = make("Frame", top, {
	Position = UDim2.new(0, 12, 0, 40),
	Size = UDim2.new(1, -24, 0, 24),
	BackgroundColor3 = Color3.fromRGB(60, 50, 60),
	BorderSizePixel = 0,
})
corner(chaosBg, 8)
local chaosFill = make("Frame", chaosBg, {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Color3.fromRGB(255, 120, 60),
	BorderSizePixel = 0,
})
corner(chaosFill, 8)
local chaosText = make("TextLabel", chaosBg, {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Font = FONT,
	TextScaled = true,
	TextColor3 = WHITE,
	TextStrokeTransparency = 0.5,
	ZIndex = 2,
	Text = "",
})

-- ===== Лента сообщений (под таймером) =====
local feed = make("Frame", gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 88),
	Size = UDim2.fromOffset(420, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
})
make("UIListLayout", feed, {
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
})

-- ===== Большой баннер по центру =====
local banner = make("TextLabel", gui, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.42),
	Size = UDim2.new(0.8, 0, 0, 70),
	BackgroundTransparency = 1,
	Font = FONT,
	TextScaled = true,
	TextColor3 = KIND_COLORS.banner,
	TextStrokeTransparency = 0,
	Visible = false,
})

-- ===== Низ слева: роль, сытость, бег =====
local rolePanel = panel(gui, {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 12, 1, -12),
	Size = UDim2.fromOffset(270, 130),
})
local roleLabel = make("TextLabel", rolePanel, {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(12, 8),
	Size = UDim2.new(1, -24, 0, 28),
	Font = FONT,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = WHITE,
})
local function makeBar(y, color, title)
	local bg = make("Frame", rolePanel, {
		Position = UDim2.fromOffset(12, y),
		Size = UDim2.new(1, -24, 0, 20),
		BackgroundColor3 = Color3.fromRGB(60, 50, 60),
		BorderSizePixel = 0,
	})
	corner(bg, 8)
	local fill = make("Frame", bg, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BorderSizePixel = 0 })
	corner(fill, 8)
	make("TextLabel", bg, {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = FONT,
		TextScaled = true,
		TextColor3 = WHITE,
		TextStrokeTransparency = 0.5,
		ZIndex = 2,
		Text = title,
	})
	return bg, fill
end
local hungerBg, hungerFill = makeBar(42, Color3.fromRGB(240, 110, 90), "🧀 Сытость")
local staminaBg, staminaFill = makeBar(68, Color3.fromRGB(100, 160, 255), "🏃 Бег")
local hintLabel = make("TextLabel", rolePanel, {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(12, 94),
	Size = UDim2.new(1, -24, 0, 28),
	Font = Enum.Font.Gotham,
	TextScaled = true,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(210, 200, 210),
})

-- ===== Слева посередине: задания (Tab) =====
local showTasks = true
local tasksPanel = panel(gui, {
	Position = UDim2.new(0, 12, 0.38, 0),
	Size = UDim2.fromOffset(270, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
})
make("UIPadding", tasksPanel, {
	PaddingTop = UDim.new(0, 10),
	PaddingBottom = UDim.new(0, 10),
	PaddingLeft = UDim.new(0, 12),
	PaddingRight = UDim.new(0, 12),
})
local tasksLabel = make("TextLabel", tasksPanel, {
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Font = FONT,
	TextSize = 18,
	TextWrapped = true,
	RichText = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextColor3 = WHITE,
	Text = "",
})

-- ===== Кнопка "Хочу быть поваром" (в лобби) =====
local wantsChef = false
local chefButton = make("TextButton", gui, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -20),
	Size = UDim2.fromOffset(320, 50),
	Font = FONT,
	TextScaled = true,
	TextColor3 = Color3.fromRGB(40, 25, 10),
	BorderSizePixel = 0,
})
corner(chefButton, 12)
make("UIPadding", chefButton, {
	PaddingTop = UDim.new(0, 8),
	PaddingBottom = UDim.new(0, 8),
	PaddingLeft = UDim.new(0, 12),
	PaddingRight = UDim.new(0, 12),
})
local function refreshChefButton()
	chefButton.Text = if wantsChef then "👨‍🍳 Хочу быть поваром: ДА" else "👨‍🍳 Хочу быть поваром: НЕТ"
	chefButton.BackgroundColor3 = if wantsChef then Color3.fromRGB(120, 220, 120) else Color3.fromRGB(255, 170, 60)
end
refreshChefButton()
chefButton.Activated:Connect(function()
	wantsChef = not wantsChef
	volunteerEvent:FireServer(wantsChef)
	refreshChefButton()
end)

-- ===== Бег =====
local sprintHeld = false
local stamina = Config.StaminaMax
local exhausted = false

local sprintButton = make("TextButton", gui, {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -170, 1, -40),
	Size = UDim2.fromOffset(80, 80),
	BackgroundColor3 = Color3.fromRGB(100, 160, 255),
	BackgroundTransparency = 0.2,
	Text = "🏃",
	TextScaled = true,
	Font = FONT,
	Visible = false,
})
corner(sprintButton, 40)
sprintButton.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		sprintHeld = true
	end
end)
sprintButton.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		sprintHeld = false
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL3 then
		sprintHeld = true
	elseif input.KeyCode == Enum.KeyCode.Tab and not processed then
		showTasks = not showTasks
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL3 then
		sprintHeld = false
	end
end)

-- ===== Сообщения =====
local feedCount = 0
local bannerId = 0

local function showBanner(text)
	bannerId += 1
	local myId = bannerId
	banner.Text = text
	banner.Visible = true
	task.delay(5, function()
		if bannerId == myId then
			banner.Visible = false
		end
	end)
end

local function addFeed(text, kind)
	feedCount += 1
	local item = make("TextLabel", feed, {
		LayoutOrder = feedCount,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.3,
		Font = FONT,
		TextSize = 18,
		TextWrapped = true,
		TextColor3 = KIND_COLORS[kind] or WHITE,
		Text = text,
	})
	corner(item, 8)
	make("UIPadding", item, {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
	})

	local items = {}
	for _, c in feed:GetChildren() do
		if c:IsA("TextLabel") then
			table.insert(items, c)
		end
	end
	table.sort(items, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	while #items > 4 do
		table.remove(items, 1):Destroy()
	end

	task.delay(6, function()
		if item.Parent then
			local tween = TweenService:Create(item, TweenInfo.new(0.6), { TextTransparency = 1, BackgroundTransparency = 1 })
			tween:Play()
			tween.Completed:Wait()
			item:Destroy()
		end
	end)
end

notifyEvent.OnClientEvent:Connect(function(text, kind)
	if kind == "banner" then
		showBanner(text)
	end
	addFeed(text, kind)
end)

-- ===== Подсказки и задания (обновляются 2 раза в секунду) =====
local function role()
	return player:GetAttribute("Role") or "Lobby"
end

local function sortedStations()
	local list = CollectionService:GetTagged("Sabotage")
	table.sort(list, function(a, b)
		return (a:GetAttribute("TaskName") or a.Name) < (b:GetAttribute("TaskName") or b.Name)
	end)
	return list
end

local function refreshPrompts()
	local r = role()
	local caught = player:GetAttribute("Caught") == true
	for _, st in CollectionService:GetTagged("Sabotage") do
		local broken = st:GetAttribute("Broken") == true
		local sab = st:FindFirstChild("SabotagePrompt")
		local rep = st:FindFirstChild("RepairPrompt")
		if sab then
			sab.Enabled = r == "Rat" and not caught and not broken
		end
		if rep then
			rep.Enabled = r == "Chef" and broken
		end
		-- подсветка: крысам — что можно сломать, повару — что надо чинить
		local hl = st:FindFirstChild("TaskHighlight")
		if not hl then
			hl = make("Highlight", st, {
				Name = "TaskHighlight",
				FillTransparency = 1,
				DepthMode = Enum.HighlightDepthMode.Occluded,
			})
		end
		hl.Enabled = (r == "Rat" and not broken) or (r == "Chef" and broken)
		hl.OutlineColor = if r == "Chef" then Color3.fromRGB(255, 80, 80) else Color3.fromRGB(255, 220, 80)
	end
	for _, cage in CollectionService:GetTagged("Cage") do
		local fp = cage:FindFirstChild("FreePrompt")
		if fp then
			fp.Enabled = r == "Rat" and not caught
		end
	end
end

local function refreshTasks()
	local r = role()
	local lines = {}
	if r == "Rat" then
		table.insert(lines, "<b>🐀 Напакости:</b>")
		for _, st in sortedStations() do
			local name = st:GetAttribute("TaskName") or st.Name
			if st:GetAttribute("Broken") then
				table.insert(lines, '<font color="#7CFC8A">✔ <s>' .. name .. "</s></font>")
			else
				table.insert(lines, "• " .. name)
			end
		end
	elseif r == "Chef" then
		table.insert(lines, "<b>🔧 Почини:</b>")
		local any = false
		for _, st in sortedStations() do
			if st:GetAttribute("Broken") then
				any = true
				table.insert(lines, '<font color="#FF8A80">• ' .. (st:GetAttribute("TaskName") or st.Name) .. "</font>")
			end
		end
		if not any then
			table.insert(lines, "Пока всё цело... 👀")
		end
	end
	table.insert(lines, '<font size="13" color="#AAAAAA">Tab — скрыть</font>')
	tasksLabel.Text = table.concat(lines, "\n")
end

-- Крысиное зрение: мягкий свет вокруг своей крысы (видишь только ты)
local function ensureRatVision(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and not root:FindFirstChild("RatVision") then
		make("PointLight", root, { Name = "RatVision", Range = 10, Brightness = 0.6, Color = Color3.fromRGB(200, 210, 255) })
	end
end

local function fmtTime(t)
	return string.format("%d:%02d", t // 60, t % 60)
end

-- ===== Главный цикл интерфейса =====
local accum = 0
RunService.Heartbeat:Connect(function(dt)
	local r = role()
	local caught = player:GetAttribute("Caught") == true
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")

	-- бег и скорость крысы
	if r == "Rat" and hum then
		local base = player:GetAttribute("BaseSpeed") or Config.RatWalkSpeed
		local moving = hum.MoveDirection.Magnitude > 0.1
		if stamina <= 0 then
			exhausted = true
		elseif stamina > 30 then
			exhausted = false
		end
		local sprinting = sprintHeld and moving and not exhausted and base > 0
		if sprinting then
			stamina = math.max(0, stamina - Config.StaminaDrain * dt)
		else
			stamina = math.min(Config.StaminaMax, stamina + Config.StaminaRegen * dt)
		end
		hum.WalkSpeed = if sprinting then base * Config.SprintMultiplier else base
		ensureRatVision(character)
	end

	-- таймер и хаос
	local state = ReplicatedStorage:GetAttribute("State") or "Lobby"
	local t = ReplicatedStorage:GetAttribute("TimeLeft") or 0
	if state == "Lobby" then
		statusLabel.Text = if t > 0 then ("Старт через " .. t) else "Ждём игроков..."
	elseif state == "Playing" then
		statusLabel.Text = "⏱ " .. fmtTime(t)
	else
		statusLabel.Text = "Раунд окончен"
	end
	local frac = math.clamp((ReplicatedStorage:GetAttribute("Chaos") or 0) / Config.ChaosToWin, 0, 1)
	chaosFill.Size = UDim2.fromScale(frac, 1)
	chaosText.Text = ("Хаос: %d%%"):format(math.floor(frac * 100))
	chaosBg.Visible = state ~= "Lobby"
	chefButton.Visible = state == "Lobby"

	-- роль
	if r == "Rat" then
		roleLabel.Text = if caught then "🪤 Ты в клетке!" else "🐀 Ты — крыса"
		hintLabel.Text = if caught then "Жди, пока друзья откроют клетку!" else "E — пакостить • Shift — бег • ешь сыр 🧀"
	elseif r == "Chef" then
		roleLabel.Text = "👨‍🍳 Ты — повар"
		hintLabel.Text = "Клик сачком — поймать • E — починить"
	else
		roleLabel.Text = "🏠 Лобби"
		hintLabel.Text = "Скоро начнётся раунд!"
	end
	hungerBg.Visible = r == "Rat"
	staminaBg.Visible = r == "Rat"
	hungerFill.Size = UDim2.fromScale((player:GetAttribute("Hunger") or Config.HungerMax) / Config.HungerMax, 1)
	staminaFill.Size = UDim2.fromScale(stamina / Config.StaminaMax, 1)
	sprintButton.Visible = UserInputService.TouchEnabled and r == "Rat"
	tasksPanel.Visible = showTasks and r ~= "Lobby"

	accum += dt
	if accum >= 0.5 then
		accum = 0
		refreshPrompts()
		refreshTasks()
	end
end)
