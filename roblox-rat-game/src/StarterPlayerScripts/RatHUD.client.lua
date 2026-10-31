-- RatHUD (LocalScript) — StarterPlayer > StarterPlayerScripts
-- Весь интерфейс: таймер, хаос, сыр-монетки, отсчёт, карточка роли, результаты,
-- магазин шапок, задания, сообщения, бег (Shift), писк (Q).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local notifyEvent = remotes:WaitForChild("Notify")
local volunteerEvent = remotes:WaitForChild("ChefVolunteer")
local fxEvent = remotes:WaitForChild("FX")
local shopEvent = remotes:WaitForChild("ShopAction")
local squeakEvent = remotes:WaitForChild("Squeak")
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
local PANEL = Color3.fromRGB(28, 22, 34)
local WHITE = Color3.new(1, 1, 1)
local YELLOW = Color3.fromRGB(255, 215, 80)
local GREEN = Color3.fromRGB(110, 220, 120)
local RED = Color3.fromRGB(255, 95, 85)
local KIND_COLORS = {
	info = WHITE,
	good = Color3.fromRGB(140, 240, 140),
	bad = Color3.fromRGB(255, 130, 120),
	banner = YELLOW,
}

local function make(className, parent, props)
	local inst = Instance.new(className)
	for k, v in pairs(props or {}) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function corner(parent, r)
	make("UICorner", parent, { CornerRadius = UDim.new(0, r or 12) })
end

local function stroke(parent, color, thickness)
	return make("UIStroke", parent, {
		Color = color or Color3.fromRGB(255, 200, 120),
		Thickness = thickness or 2,
		Transparency = 0.4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function padding(parent, px)
	make("UIPadding", parent, {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
	})
end

local function panel(parent, props)
	local f = make("Frame", parent, props)
	f.BackgroundColor3 = PANEL
	f.BackgroundTransparency = 0.15
	f.BorderSizePixel = 0
	corner(f)
	stroke(f)
	return f
end

local function text(parent, props)
	local t = make("TextLabel", parent, props)
	t.BackgroundTransparency = 1
	t.Font = props.Font or FONT
	if not props.TextSize then
		t.TextScaled = true
	end
	t.TextColor3 = props.TextColor3 or WHITE
	return t
end

local function button(parent, props, color)
	local b = make("TextButton", parent, props)
	b.Font = FONT
	b.TextScaled = true
	b.BackgroundColor3 = color or Color3.fromRGB(255, 170, 60)
	b.TextColor3 = props.TextColor3 or Color3.fromRGB(40, 25, 10)
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	corner(b, 12)
	padding(b, 6)
	return b
end

local function popIn(guiObject)
	local scale = guiObject:FindFirstChildOfClass("UIScale") or make("UIScale", guiObject, {})
	scale.Scale = 0.6
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

local gui = make("ScreenGui", playerGui, { Name = "RatHUD", ResetOnSpawn = false, IgnoreGuiInset = false })

-- ===== Верх: таймер и хаос =====
local top = panel(gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 6),
	Size = UDim2.fromOffset(360, 78),
})
local topStroke = top:FindFirstChildOfClass("UIStroke")
local statusLabel = text(top, {
	Position = UDim2.fromOffset(0, 4),
	Size = UDim2.new(1, 0, 0, 32),
	Text = "",
})
local chaosBg = make("Frame", top, {
	Position = UDim2.new(0, 14, 0, 42),
	Size = UDim2.new(1, -28, 0, 26),
	BackgroundColor3 = Color3.fromRGB(60, 50, 66),
	BorderSizePixel = 0,
})
corner(chaosBg, 10)
local chaosFill = make("Frame", chaosBg, {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
})
corner(chaosFill, 10)
make("UIGradient", chaosFill, {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 90)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(255, 140, 50)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(240, 50, 50)),
	}),
})
local chaosText = text(chaosBg, {
	Size = UDim2.fromScale(1, 1),
	TextStrokeTransparency = 0.4,
	ZIndex = 2,
	Text = "",
})

-- Сыр-монетки
local coinsPill = panel(gui, {
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.new(0.5, 190, 0, 6),
	Size = UDim2.fromOffset(120, 40),
})
local coinsLabel = text(coinsPill, { Size = UDim2.fromScale(1, 1), Text = "🧀 0", TextColor3 = YELLOW })
padding(coinsPill, 6)

-- ===== Лента сообщений =====
local feed = make("Frame", gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 92),
	Size = UDim2.fromOffset(440, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
})
make("UIListLayout", feed, {
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
})

-- ===== Большой баннер =====
local banner = text(gui, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.3),
	Size = UDim2.new(0.8, 0, 0, 64),
	TextColor3 = YELLOW,
	TextStrokeTransparency = 0,
	Visible = false,
	ZIndex = 5,
})

-- ===== Отсчёт и карточка роли =====
local countdown = text(gui, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.42),
	Size = UDim2.fromOffset(400, 160),
	TextColor3 = YELLOW,
	TextStrokeTransparency = 0,
	Visible = false,
	ZIndex = 6,
	Text = "",
})
local roleCard = panel(gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.58, 0),
	Size = UDim2.fromOffset(460, 120),
	Visible = false,
	ZIndex = 6,
})
local roleCardTitle = text(roleCard, {
	Position = UDim2.fromOffset(16, 10),
	Size = UDim2.new(1, -32, 0, 44),
	ZIndex = 6,
	Text = "",
})
local roleCardGoal = text(roleCard, {
	Position = UDim2.fromOffset(16, 58),
	Size = UDim2.new(1, -32, 0, 52),
	Font = Enum.Font.GothamMedium,
	TextWrapped = true,
	TextColor3 = Color3.fromRGB(230, 220, 235),
	ZIndex = 6,
	Text = "",
})

-- ===== Результаты =====
local results = panel(gui, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(460, 280),
	Visible = false,
	ZIndex = 8,
})
local resTitle = text(results, { Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 56), ZIndex = 8, Text = "" })
local resWinner = text(results, { Position = UDim2.fromOffset(16, 72), Size = UDim2.new(1, -32, 0, 34), ZIndex = 8, Text = "" })
local resReason = text(results, {
	Position = UDim2.fromOffset(16, 110),
	Size = UDim2.new(1, -32, 0, 28),
	Font = Enum.Font.GothamMedium,
	TextColor3 = Color3.fromRGB(220, 210, 225),
	ZIndex = 8,
	Text = "",
})
local resMvp = text(results, { Position = UDim2.fromOffset(16, 148), Size = UDim2.new(1, -32, 0, 30), TextColor3 = YELLOW, ZIndex = 8, Text = "" })
local resCoins = text(results, { Position = UDim2.fromOffset(16, 186), Size = UDim2.new(1, -32, 0, 40), TextColor3 = YELLOW, ZIndex = 8, Text = "" })
local resNext = text(results, {
	Position = UDim2.fromOffset(16, 236),
	Size = UDim2.new(1, -32, 0, 26),
	Font = Enum.Font.GothamMedium,
	TextColor3 = Color3.fromRGB(180, 170, 190),
	ZIndex = 8,
	Text = "",
})

-- ===== Низ слева: роль, сытость, бег =====
local rolePanel = panel(gui, {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 12, 1, -12),
	Size = UDim2.fromOffset(290, 140),
})
local roleLabel = text(rolePanel, {
	Position = UDim2.fromOffset(14, 10),
	Size = UDim2.new(1, -28, 0, 30),
	TextXAlignment = Enum.TextXAlignment.Left,
})
local function makeBar(y, color, title)
	local bg = make("Frame", rolePanel, {
		Position = UDim2.fromOffset(14, y),
		Size = UDim2.new(1, -28, 0, 22),
		BackgroundColor3 = Color3.fromRGB(60, 50, 66),
		BorderSizePixel = 0,
	})
	corner(bg, 8)
	local fill = make("Frame", bg, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BorderSizePixel = 0 })
	corner(fill, 8)
	text(bg, { Size = UDim2.fromScale(1, 1), TextStrokeTransparency = 0.5, ZIndex = 2, Text = title })
	return bg, fill
end
local hungerBg, hungerFill = makeBar(46, Color3.fromRGB(240, 120, 80), "🧀 Сытость")
local staminaBg, staminaFill = makeBar(74, Color3.fromRGB(100, 160, 255), "🏃 Бег")
local hintLabel = text(rolePanel, {
	Position = UDim2.fromOffset(14, 102),
	Size = UDim2.new(1, -28, 0, 30),
	Font = Enum.Font.GothamMedium,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(215, 205, 220),
})

-- ===== Слева посередине: задания (Tab) =====
local showTasks = true
local tasksPanel = panel(gui, {
	Position = UDim2.new(0, 12, 0.36, 0),
	Size = UDim2.fromOffset(280, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
})
padding(tasksPanel, 12)
local tasksLabel = text(tasksPanel, {
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	TextSize = 18,
	TextWrapped = true,
	RichText = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	Text = "",
})

-- ===== Лобби: кнопки =====
local lobbyBar = make("Frame", gui, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -18),
	Size = UDim2.fromOffset(560, 54),
	BackgroundTransparency = 1,
})
make("UIListLayout", lobbyBar, {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 14),
})
local shopButton = button(lobbyBar, { Size = UDim2.fromOffset(200, 54), Text = "🎩 Шапки" }, Color3.fromRGB(180, 130, 255))
local chefButton = button(lobbyBar, { Size = UDim2.fromOffset(320, 54), Text = "" })
local wantsChef = false
local function refreshChefButton()
	if wantsChef then
		chefButton.Text = "👨‍🍳 Хочу быть поваром: ДА"
		chefButton.BackgroundColor3 = GREEN
	else
		chefButton.Text = "👨‍🍳 Хочу быть поваром: НЕТ"
		chefButton.BackgroundColor3 = Color3.fromRGB(255, 170, 60)
	end
end
refreshChefButton()
chefButton.Activated:Connect(function()
	wantsChef = not wantsChef
	volunteerEvent:FireServer(wantsChef)
	refreshChefButton()
end)

-- ===== Магазин шапок =====
local shop = panel(gui, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(560, 420),
	Visible = false,
	ZIndex = 10,
})
text(shop, { Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -120, 0, 40), Text = "🎩 Шапки для крысы", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 10 })
local shopCoins = text(shop, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -64, 0, 14), Size = UDim2.fromOffset(120, 32), TextColor3 = YELLOW, ZIndex = 10, Text = "" })
local closeShop = button(shop, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Size = UDim2.fromOffset(42, 42), Text = "✕", ZIndex = 10 }, RED)
local shopList = make("ScrollingFrame", shop, {
	Position = UDim2.fromOffset(12, 62),
	Size = UDim2.new(1, -24, 1, -74),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	ZIndex = 10,
})
make("UIGridLayout", shopList, {
	CellSize = UDim2.fromOffset(160, 130),
	CellPadding = UDim2.fromOffset(10, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
})
local shopCards = {}
for i, hat in ipairs(Config.Hats) do
	local card = make("Frame", shopList, {
		LayoutOrder = i,
		BackgroundColor3 = Color3.fromRGB(50, 40, 60),
		BorderSizePixel = 0,
		ZIndex = 10,
	})
	corner(card, 10)
	text(card, { Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 44), Text = hat.Icon, ZIndex = 10 })
	text(card, { Position = UDim2.fromOffset(6, 52), Size = UDim2.new(1, -12, 0, 24), Text = hat.Name, ZIndex = 10 })
	local buy = button(card, { Position = UDim2.new(0, 10, 1, -44), Size = UDim2.new(1, -20, 0, 36), Text = "", ZIndex = 10 })
	shopCards[hat.Id] = { button = buy, hat = hat }
end

local function ownedSet()
	local set = {}
	for id in string.gmatch(player:GetAttribute("OwnedHats") or "", "[^,]+") do
		set[id] = true
	end
	return set
end

local function refreshShop()
	local owned = ownedSet()
	local coins = player:GetAttribute("Coins") or 0
	local current = player:GetAttribute("Hat")
	shopCoins.Text = "🧀 " .. coins
	for id, info in pairs(shopCards) do
		local b = info.button
		if current == id then
			b.Text = "Надето ✓"
			b.BackgroundColor3 = Color3.fromRGB(120, 120, 130)
		elseif owned[id] then
			b.Text = "Надеть"
			b.BackgroundColor3 = GREEN
		elseif coins >= info.hat.Price then
			b.Text = "Купить 🧀" .. info.hat.Price
			b.BackgroundColor3 = YELLOW
		else
			b.Text = "🔒 🧀" .. info.hat.Price
			b.BackgroundColor3 = Color3.fromRGB(90, 80, 95)
		end
	end
end

for id, info in pairs(shopCards) do
	info.button.Activated:Connect(function()
		if ownedSet()[id] then
			shopEvent:FireServer("equip", id)
		else
			shopEvent:FireServer("buy", id)
		end
	end)
end
shopButton.Activated:Connect(function()
	shop.Visible = not shop.Visible
	if shop.Visible then
		refreshShop()
		popIn(shop)
	end
end)
closeShop.Activated:Connect(function()
	shop.Visible = false
end)

-- ===== Кнопки для телефона =====
local sprintHeld = false
local touchBar = make("Frame", gui, {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -170, 1, -30),
	Size = UDim2.fromOffset(180, 80),
	BackgroundTransparency = 1,
	Visible = false,
})
local sprintButton = button(touchBar, { Position = UDim2.fromOffset(90, 0), Size = UDim2.fromOffset(80, 80), Text = "🏃" }, Color3.fromRGB(100, 160, 255))
corner(sprintButton, 40)
local squeakButton = button(touchBar, { Position = UDim2.fromOffset(0, 10), Size = UDim2.fromOffset(70, 70), Text = "🐭" }, Color3.fromRGB(255, 180, 200))
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
squeakButton.Activated:Connect(function()
	squeakEvent:FireServer()
end)

-- ===== Клавиатура =====
UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL3 then
		sprintHeld = true
	elseif processed then
		return
	elseif input.KeyCode == Enum.KeyCode.Tab then
		showTasks = not showTasks
	elseif input.KeyCode == Enum.KeyCode.Q then
		squeakEvent:FireServer()
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

local function showBanner(msg, color)
	bannerId = bannerId + 1
	local myId = bannerId
	banner.Text = msg
	banner.TextColor3 = color or YELLOW
	banner.Visible = true
	popIn(banner)
	task.delay(4, function()
		if bannerId == myId then
			banner.Visible = false
		end
	end)
end

local function addFeed(msg, kind)
	feedCount = feedCount + 1
	local item = text(feed, {
		LayoutOrder = feedCount,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 18,
		TextWrapped = true,
		TextColor3 = KIND_COLORS[kind] or WHITE,
		Text = msg,
	})
	item.BackgroundTransparency = 0.25
	item.BackgroundColor3 = PANEL
	corner(item, 8)
	make("UIPadding", item, {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
	})

	local items = {}
	for _, c in ipairs(feed:GetChildren()) do
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

notifyEvent.OnClientEvent:Connect(function(msg, kind)
	if kind == "banner" then
		showBanner(msg)
	end
	addFeed(msg, kind)
end)

-- Всплывающие "+5 🧀"
local function coinPopup(amount, reason)
	local pop = text(gui, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 312, 1, -60),
		Size = UDim2.fromOffset(240, 34),
		TextColor3 = YELLOW,
		TextStrokeTransparency = 0.2,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = ("+%d 🧀 %s"):format(amount, reason or ""),
		ZIndex = 7,
	})
	popIn(pop)
	local tween = TweenService:Create(pop, TweenInfo.new(1.6), {
		Position = UDim2.new(0, 312, 1, -140),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	tween:Play()
	tween.Completed:Connect(function()
		pop:Destroy()
	end)
end

local function showResults(data)
	results.Visible = true
	popIn(results)
	if data.won then
		resTitle.Text = "🎉 ПОБЕДА! 🎉"
		resTitle.TextColor3 = GREEN
	else
		resTitle.Text = "😿 Поражение"
		resTitle.TextColor3 = RED
	end
	if data.winner == "Rats" then
		resWinner.Text = "🐀 Крысы победили!"
	else
		resWinner.Text = "👨‍🍳 Повар победил!"
	end
	resReason.Text = data.reason or ""
	if data.mvp and data.mvp ~= "" then
		resMvp.Text = ("⭐ Лучший игрок: %s (%d)"):format(data.mvp, data.mvpScore or 0)
	else
		resMvp.Text = ""
	end
	resCoins.Text = ("+%d 🧀 за раунд"):format(data.coins or 0)
end

fxEvent.OnClientEvent:Connect(function(kind, a, b)
	if kind == "coins" then
		coinPopup(a, b)
	elseif kind == "results" and type(a) == "table" then
		showResults(a)
	end
end)

-- ===== Подсказки и задания =====
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

local MINI_ICONS = { Wires = "🔌", Mash = "🦷", Code = "🔢", Timing = "⏱" }

local function refreshPrompts()
	local r = role()
	local caught = player:GetAttribute("Caught") == true
	local busy = player:GetAttribute("LocalFreeze") == true
	for _, st in ipairs(CollectionService:GetTagged("Sabotage")) do
		local broken = st:GetAttribute("Broken") == true
		local sab = st:FindFirstChild("SabotagePrompt")
		local rep = st:FindFirstChild("RepairPrompt")
		if sab then
			sab.Enabled = r == "Rat" and not caught and not broken and not busy
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
		if r == "Chef" then
			hl.OutlineColor = Color3.fromRGB(255, 80, 80)
		else
			hl.OutlineColor = YELLOW
		end
	end
	for _, cage in ipairs(CollectionService:GetTagged("Cage")) do
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
		for _, st in ipairs(sortedStations()) do
			local name = st:GetAttribute("TaskName") or st.Name
			local icon = MINI_ICONS[st:GetAttribute("MiniGame") or ""] or "✋"
			if st:GetAttribute("Broken") then
				table.insert(lines, '<font color="#7CFC8A">✔ <s>' .. name .. "</s></font>")
			else
				table.insert(lines, icon .. " " .. name)
			end
		end
	elseif r == "Chef" then
		table.insert(lines, "<b>🔧 Почини:</b>")
		local any = false
		for _, st in ipairs(sortedStations()) do
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

local function fmtTime(t)
	return string.format("%d:%02d", math.floor(t / 60), t % 60)
end

local function showRoleCard()
	local r = role()
	if r == "Rat" then
		roleCardTitle.Text = "🐀 ТЫ — КРЫСА"
		roleCardTitle.TextColor3 = YELLOW
		roleCardGoal.Text = "Ломай вещи (жёлтая обводка), наполни шкалу хаоса до 100% и не попадись повару!"
	elseif r == "Chef" then
		roleCardTitle.Text = "👨‍🍳 ТЫ — ПОВАР"
		roleCardTitle.TextColor3 = Color3.fromRGB(255, 140, 120)
		roleCardGoal.Text = "Лови крыс сачком, ставь мышеловки и чини поломки, пока не кончится время!"
	else
		roleCard.Visible = false
		return
	end
	roleCard.Visible = true
	popIn(roleCard)
end

-- ===== Главный цикл интерфейса =====
local stamina = Config.StaminaMax
local exhausted = false
local accum = 0
local lastState = nil
local lastTime = nil

RunService.Heartbeat:Connect(function(dt)
	local r = role()
	local caught = player:GetAttribute("Caught") == true
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local state = ReplicatedStorage:GetAttribute("State") or "Lobby"
	local t = ReplicatedStorage:GetAttribute("TimeLeft") or 0

	-- бег и скорость
	if (r == "Rat" or r == "Chef") and hum then
		local base = player:GetAttribute("BaseSpeed") or 0
		local mult = Config.SprintMultiplier
		if r == "Chef" then
			mult = Config.ChefSprintMultiplier
		end
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
		local speed = base
		if sprinting then
			speed = base * mult
		end
		if player:GetAttribute("LocalFreeze") then
			speed = 0
		end
		hum.WalkSpeed = speed
	end

	-- смена состояния игры
	if state ~= lastState then
		if state == "Intro" then
			results.Visible = false
			shop.Visible = false
			showRoleCard()
		elseif state == "Playing" then
			countdown.Text = "ХАОС!"
			countdown.Visible = true
			popIn(countdown)
			task.delay(1.2, function()
				if ReplicatedStorage:GetAttribute("State") == "Playing" then
					countdown.Visible = false
				end
			end)
			roleCard.Visible = false
		elseif state == "Lobby" then
			results.Visible = false
			countdown.Visible = false
			roleCard.Visible = false
		end
		lastState = state
	end
	if state == "Intro" and t ~= lastTime then
		countdown.Text = tostring(t)
		countdown.Visible = true
		popIn(countdown)
	end
	lastTime = t

	-- таймер и хаос
	if state == "Lobby" then
		if t > 0 then
			statusLabel.Text = "Старт через " .. t
		else
			statusLabel.Text = "Ждём игроков..."
		end
	elseif state == "Intro" then
		statusLabel.Text = "Приготовься!"
	elseif state == "Playing" then
		statusLabel.Text = "⏱ " .. fmtTime(t)
		if t <= 30 then
			statusLabel.TextColor3 = RED
		else
			statusLabel.TextColor3 = WHITE
		end
	else
		statusLabel.Text = "Раунд окончен"
		resNext.Text = ("Следующий раунд через %d сек."):format(t)
	end
	local chaos = ReplicatedStorage:GetAttribute("Chaos") or 0
	local frac = math.clamp(chaos / Config.ChaosToWin, 0, 1)
	chaosFill.Size = UDim2.fromScale(frac, 1)
	if chaos >= Config.AlarmChaos and state == "Playing" then
		chaosText.Text = ("🚨 ТРЕВОГА! Хаос: %d%%"):format(math.floor(frac * 100))
		local pulse = (math.sin(os.clock() * 8) + 1) / 2
		topStroke.Color = Color3.fromRGB(255, 60 + 100 * pulse, 60)
		topStroke.Transparency = 0.1
	else
		chaosText.Text = ("Хаос: %d%%"):format(math.floor(frac * 100))
		topStroke.Color = Color3.fromRGB(255, 200, 120)
		topStroke.Transparency = 0.4
	end
	chaosBg.Visible = state ~= "Lobby"
	lobbyBar.Visible = state == "Lobby"
	if state ~= "Lobby" then
		shop.Visible = false
	end
	coinsLabel.Text = "🧀 " .. (player:GetAttribute("Coins") or 0)

	-- роль
	if r == "Rat" then
		if caught then
			roleLabel.Text = "🪤 Ты в клетке!"
			hintLabel.Text = "Пищи (Q), чтобы позвать друзей!"
		elseif player:GetAttribute("Stunned") then
			roleLabel.Text = "🪤 Мышеловка!"
			hintLabel.Text = "Подожди пару секунд..."
		else
			roleLabel.Text = "🐀 Ты — крыса"
			hintLabel.Text = "E — пакостить • Shift — бег • Q — писк"
		end
	elseif r == "Chef" then
		roleLabel.Text = "👨‍🍳 Ты — повар"
		hintLabel.Text = "1 — сачок • 2 — мышеловка • E — чинить"
	else
		roleLabel.Text = "🏠 Лобби"
		hintLabel.Text = "Выбери шапку и жди начала раунда!"
	end
	hungerBg.Visible = r == "Rat"
	staminaBg.Visible = r == "Rat" or r == "Chef"
	hungerFill.Size = UDim2.fromScale((player:GetAttribute("Hunger") or Config.HungerMax) / Config.HungerMax, 1)
	staminaFill.Size = UDim2.fromScale(stamina / Config.StaminaMax, 1)
	touchBar.Visible = UserInputService.TouchEnabled and (r == "Rat" or r == "Chef")
	squeakButton.Visible = r == "Rat"
	tasksPanel.Visible = showTasks and (r == "Rat" or r == "Chef") and state == "Playing"

	accum = accum + dt
	if accum >= 0.5 then
		accum = 0
		refreshPrompts()
		refreshTasks()
		if shop.Visible then
			refreshShop()
		end
	end
end)
