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
local Locale = require(ReplicatedStorage:WaitForChild("Locale"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local notifyEvent = remotes:WaitForChild("Notify")
local volunteerEvent = remotes:WaitForChild("ChefVolunteer")
local fxEvent = remotes:WaitForChild("FX")
local shopEvent = remotes:WaitForChild("ShopAction")
local squeakEvent = remotes:WaitForChild("Squeak")
local abilityEvent = remotes:WaitForChild("Ability")
local codeEvent = remotes:WaitForChild("RedeemCode")
local emoteEvent = remotes:WaitForChild("Emote")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- язык игрока ("ru" или "en") выбирается автоматически по настройкам Roblox
local function lang()
	return Locale.detect(player)
end
local function L(key, ...)
	return Locale.t(lang(), key, ...)
end

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

-- Уровень и опыт
local levelPill = panel(gui, {
	Position = UDim2.new(0.5, 190, 0, 52),
	Size = UDim2.fromOffset(120, 32),
})
local levelLabel = text(levelPill, { Position = UDim2.fromOffset(6, 1), Size = UDim2.new(1, -12, 0, 20), Text = "⭐ 1", TextColor3 = YELLOW, ZIndex = 2 })
local xpBg = make("Frame", levelPill, { Position = UDim2.new(0, 8, 1, -9), Size = UDim2.new(1, -16, 0, 5), BackgroundColor3 = Color3.fromRGB(60, 50, 66), BorderSizePixel = 0 })
corner(xpBg, 3)
local xpFill = make("Frame", xpBg, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = YELLOW, BorderSizePixel = 0 })
corner(xpFill, 3)

-- Событие раунда
local eventPill = panel(gui, {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(0.5, -190, 0, 6),
	Size = UDim2.fromOffset(190, 40),
	Visible = false,
})
local eventLabel = text(eventPill, { Size = UDim2.fromScale(1, 1), Text = "", TextColor3 = Color3.fromRGB(255, 170, 90) })
padding(eventPill, 6)

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
	local caption = text(bg, { Size = UDim2.fromScale(1, 1), TextStrokeTransparency = 0.5, ZIndex = 2, Text = title })
	return bg, fill, caption
end
local hungerBg, hungerFill, hungerCaption = makeBar(46, Color3.fromRGB(240, 120, 80), "")
local staminaBg, staminaFill, staminaCaption = makeBar(74, Color3.fromRGB(100, 160, 255), "")
local hintLabel = text(rolePanel, {
	Position = UDim2.fromOffset(14, 102),
	Size = UDim2.new(1, -28, 0, 30),
	Font = Enum.Font.GothamMedium,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(215, 205, 220),
})

-- Способность класса (F)
local abilityPill = panel(gui, {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 12, 1, -160),
	Size = UDim2.fromOffset(290, 38),
	Visible = false,
})
local abilityLabel = text(abilityPill, { Size = UDim2.fromScale(1, 1), Text = "", TextColor3 = Color3.fromRGB(150, 220, 255) })
padding(abilityPill, 6)
local abilityReadyAt = 0
player:GetAttributeChangedSignal("AbilityUses"):Connect(function()
	local cls = Config.getClass(player:GetAttribute("Class") or "normal")
	abilityReadyAt = os.clock() + ((cls and cls.Cooldown) or 0)
end)

-- Как играть (первый раунд)
local tutorial = panel(gui, {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -12, 0.42, 0),
	Size = UDim2.fromOffset(380, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Visible = false,
})
padding(tutorial, 14)
stroke(tutorial, YELLOW, 3)
local tutorialLabel = text(tutorial, {
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	TextSize = 20,
	TextWrapped = true,
	RichText = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	Text = "",
})

-- Стрелка к ближайшему заданию
local marker = make("BillboardGui", playerGui, {
	Name = "TaskMarker",
	Size = UDim2.fromOffset(230, 70),
	StudsOffset = Vector3.new(0, 4, 0),
	AlwaysOnTop = true,
	MaxDistance = 1000,
	LightInfluence = 0,
	Enabled = false,
	ResetOnSpawn = false,
})
local markerLabel = text(marker, { Size = UDim2.fromScale(1, 1), Text = "", TextColor3 = YELLOW, TextStrokeTransparency = 0 })

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
	Size = UDim2.fromOffset(820, 54),
	BackgroundTransparency = 1,
})
make("UIListLayout", lobbyBar, {
	SortOrder = Enum.SortOrder.LayoutOrder,
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 14),
})
local shopButton = button(lobbyBar, { LayoutOrder = 1, Size = UDim2.fromOffset(150, 54), Text = "" }, Color3.fromRGB(180, 130, 255))
local codesButton = button(lobbyBar, { LayoutOrder = 2, Size = UDim2.fromOffset(130, 54), Text = "" }, Color3.fromRGB(255, 120, 160))
local inviteButton = button(lobbyBar, { LayoutOrder = 3, Size = UDim2.fromOffset(160, 54), Text = "" }, Color3.fromRGB(110, 210, 255))
local chefButton = button(lobbyBar, { LayoutOrder = 4, Size = UDim2.fromOffset(330, 54), Text = "" })
local wantsChef = false
local function refreshChefButton()
	if wantsChef then
		chefButton.Text = L("chef_yes")
		chefButton.BackgroundColor3 = GREEN
	else
		chefButton.Text = L("chef_no")
		chefButton.BackgroundColor3 = Color3.fromRGB(255, 170, 60)
	end
end

refreshChefButton()
chefButton.Activated:Connect(function()
	wantsChef = not wantsChef
	volunteerEvent:FireServer(wantsChef)
	refreshChefButton()
end)

local addFeedLocal -- объявлена ниже, после ленты сообщений

-- ===== Голосование за карту (лобби) =====
local voteEvent = remotes:WaitForChild("VoteMap")
local votePanel = panel(gui, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -84),
	Size = UDim2.fromOffset(600, 56),
})
padding(votePanel, 6)
make("UIListLayout", votePanel, {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 10),
})
local voteTitle = text(votePanel, { Size = UDim2.fromOffset(200, 40), Text = "" })
local voteButtons = {}
for i, m in ipairs(Config.Maps) do
	local b = button(votePanel, { LayoutOrder = i, Size = UDim2.fromOffset(180, 42), Text = "" }, Color3.fromRGB(255, 200, 90))
	local st = stroke(b, WHITE, 0)
	st.Transparency = 0
	voteButtons[m.Id] = { button = b, stroke = st, map = m }
	b.Activated:Connect(function()
		voteEvent:FireServer(m.Id)
	end)
end

local function mapListSet()
	local set, n = {}, 0
	for id in string.gmatch(ReplicatedStorage:GetAttribute("MapList") or "", "[^,]+") do
		set[id] = true
		n = n + 1
	end
	return set, n
end

local function refreshVotes()
	local set, n = mapListSet()
	votePanel.Visible = n > 1 and (ReplicatedStorage:GetAttribute("State") or "Lobby") == "Lobby"
	voteTitle.Text = L("vote_title")
	local mine = player:GetAttribute("Vote")
	for id, info in pairs(voteButtons) do
		info.button.Visible = set[id] == true
		info.button.Text = ("%s %s (%d)"):format(info.map.Icon, Locale.itemName(lang(), info.map), ReplicatedStorage:GetAttribute("Votes_" .. id) or 0)
		info.stroke.Thickness = (mine == id) and 4 or 0
	end
end

local function activeMapName()
	local id = ReplicatedStorage:GetAttribute("ActiveMapId")
	for _, m in ipairs(Config.Maps) do
		if m.Id == id then
			return m.Icon .. " " .. Locale.itemName(lang(), m)
		end
	end
	return ""
end

-- ===== Магазин: шапки, следы, классы (за сыр) и донат (Robux) =====
local shop = panel(gui, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(660, 520),
	Visible = false,
	ZIndex = 10,
})
local shopTitle = text(shop, { Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -260, 0, 40), Text = "", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 10 })
local shopCoins = text(shop, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -64, 0, 14), Size = UDim2.fromOffset(160, 32), TextColor3 = YELLOW, ZIndex = 10, Text = "" })
local closeShop = button(shop, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Size = UDim2.fromOffset(42, 42), Text = "✕", ZIndex = 10 }, RED)
local TABS = {
	{ id = "hats", key = "tab_hats", color = Color3.fromRGB(180, 130, 255) },
	{ id = "trails", key = "tab_trails", color = Color3.fromRGB(255, 140, 200) },
	{ id = "classes", key = "tab_classes", color = Color3.fromRGB(255, 180, 70) },
	{ id = "pets", key = "tab_pets", color = Color3.fromRGB(140, 220, 120) },
	{ id = "robux", key = "tab_robux", color = Color3.fromRGB(80, 200, 255) },
}
local shopTab = "hats"
local tabButtons, lists = {}, {}

local function makeList()
	local list = make("ScrollingFrame", shop, {
		Position = UDim2.fromOffset(12, 112),
		Size = UDim2.new(1, -24, 1, -124),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ZIndex = 10,
	})
	make("UIGridLayout", list, {
		CellSize = UDim2.fromOffset(150, 150),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	return list
end

local refreshShop
for i, tab in ipairs(TABS) do
	local b = button(shop, { Position = UDim2.fromOffset(14 + (i - 1) * 126, 60), Size = UDim2.fromOffset(122, 42), Text = "", ZIndex = 10 }, tab.color)
	tabButtons[tab.id] = b
	lists[tab.id] = makeList()
	b.Activated:Connect(function()
		shopTab = tab.id
		refreshShop()
	end)
end

local function card(list, order, icon, gold)
	local c = make("Frame", list, {
		LayoutOrder = order,
		BackgroundColor3 = Color3.fromRGB(50, 40, 60),
		BorderSizePixel = 0,
		ZIndex = 10,
	})
	corner(c, 10)
	if gold then
		stroke(c, YELLOW, 3)
	end
	text(c, { Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 40), Text = icon, ZIndex = 10 })
	local title = text(c, { Position = UDim2.fromOffset(6, 46), Size = UDim2.new(1, -12, 0, 24), Text = "", ZIndex = 10 })
	local desc = text(c, { Position = UDim2.fromOffset(6, 72), Size = UDim2.new(1, -12, 0, 26), Font = Enum.Font.GothamMedium, TextWrapped = true, TextColor3 = Color3.fromRGB(210, 200, 220), Text = "", ZIndex = 10 })
	local b = button(c, { Position = UDim2.new(0, 8, 1, -42), Size = UDim2.new(1, -16, 0, 34), Text = "", ZIndex = 10 })
	return title, desc, b
end

local function setOf(attr)
	local set = {}
	for id in string.gmatch(player:GetAttribute(attr) or "", "[^,]+") do
		set[id] = true
	end
	return set
end

-- товары за сыр: одинаковая логика для шапок, следов и классов
local CATS = {
	{ tab = "hats", cat = "hat", items = Config.Hats, owned = "OwnedHats", current = "Hat", equipKey = "equip", equippedKey = "equipped" },
	{ tab = "trails", cat = "trail", items = Config.Trails, owned = "OwnedTrails", current = "Trail", equipKey = "equip", equippedKey = "equipped" },
	{ tab = "classes", cat = "class", items = Config.Classes, owned = "OwnedClasses", current = "Class", equipKey = "select", equippedKey = "selected" },
	{ tab = "pets", cat = "pet", items = Config.Pets, owned = "OwnedPets", current = "Pet", equipKey = "equip", equippedKey = "equipped" },
}
local itemCards = {}
for _, c in ipairs(CATS) do
	for i, item in ipairs(c.items) do
		local title, desc, b = card(lists[c.tab], i, item.Icon, item.VipOnly)
		local info = { cat = c, item = item, title = title, desc = desc, button = b }
		table.insert(itemCards, info)
		b.Activated:Connect(function()
			local owned = setOf(c.owned)
			if owned[item.Id] then
				shopEvent:FireServer("equip", item.Id, c.cat)
			elseif item.VipOnly then
				shopTab = "robux"
				refreshShop()
			elseif item.Level and (player:GetAttribute("Level") or 1) < item.Level then
				addFeedLocal(L("level_lock", item.Level))
			else
				shopEvent:FireServer("buy", item.Id, c.cat)
			end
		end)
	end
end

-- донат за Robux
local MarketplaceService = game:GetService("MarketplaceService")
local robuxCards = {}
local function addRobuxCard(order, icon, kind, key, id, price, gold)
	local title, desc, b = card(lists.robux, order, icon, gold)
	local info = { kind = kind, key = key, id = id, price = price, title = title, desc = desc, button = b }
	table.insert(robuxCards, info)
	b.Activated:Connect(function()
		if info.id <= 0 then
			addFeedLocal(L("not_configured"))
			return
		end
		if info.kind == "pass" then
			MarketplaceService:PromptGamePassPurchase(player, info.id)
		else
			MarketplaceService:PromptProductPurchase(player, info.id)
		end
	end)
	return info
end
addRobuxCard(1, "👑", "pass", "VIP", Config.GamePasses.VIP, Config.GamePassPrices.VIP, true)
addRobuxCard(2, "🧀", "pass", "DoubleCheese", Config.GamePasses.DoubleCheese, Config.GamePassPrices.DoubleCheese, false)
addRobuxCard(3, "🐀", "pass", "AllClasses", Config.GamePasses.AllClasses, Config.GamePassPrices.AllClasses, false)
local escapeProduct = nil
local order = 4
for _, prod in ipairs(Config.Products) do
	if prod.Kind == "escape" then
		escapeProduct = prod
	elseif prod.Kind == "chef" then
		addRobuxCard(order, "👨‍🍳", "product", "BeChef", prod.Id, prod.Price, false)
		order = order + 1
	else
		local info = addRobuxCard(order, "💰", "product", prod.Key, prod.Id, prod.Price, prod.Coins >= 10000)
		info.coins = prod.Coins
		order = order + 1
	end
end

refreshShop = function()
	local coins = player:GetAttribute("Coins") or 0
	local level = player:GetAttribute("Level") or 1
	shopCoins.Text = "🧀 " .. coins
	shopTitle.Text = L("shop_main")
	for _, tab in ipairs(TABS) do
		tabButtons[tab.id].Text = L(tab.key)
		tabButtons[tab.id].BackgroundTransparency = (shopTab == tab.id) and 0 or 0.55
		lists[tab.id].Visible = shopTab == tab.id
	end
	for _, info in ipairs(itemCards) do
		local item, c, b = info.item, info.cat, info.button
		local owned = setOf(c.owned)
		local current = player:GetAttribute(c.current)
		info.title.Text = Locale.itemName(lang(), item)
		if c.cat == "class" then
			info.desc.Text = L("class_" .. item.Id .. "_desc")
		elseif c.cat == "pet" and (item.Bonus or 0) > 0 then
			info.desc.Text = L("pet_bonus", math.floor(item.Bonus * 100 + 0.5)) .. (item.Level and (" • ⭐" .. item.Level) or "")
		elseif item.Level then
			info.desc.Text = "⭐ " .. item.Level
		else
			info.desc.Text = ""
		end
		if current == item.Id then
			b.Text = L(c.equippedKey)
			b.BackgroundColor3 = Color3.fromRGB(120, 120, 130)
		elseif owned[item.Id] then
			b.Text = L(c.equipKey)
			b.BackgroundColor3 = GREEN
		elseif item.VipOnly then
			b.Text = L("vip_only")
			b.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
		elseif item.Level and level < item.Level then
			b.Text = L("level_lock", item.Level)
			b.BackgroundColor3 = Color3.fromRGB(90, 80, 95)
		elseif coins >= item.Price then
			b.Text = L("buy", item.Price)
			b.BackgroundColor3 = YELLOW
		else
			b.Text = L("locked", item.Price)
			b.BackgroundColor3 = Color3.fromRGB(90, 80, 95)
		end
	end
	for _, info in ipairs(robuxCards) do
		local b = info.button
		if info.key == "VIP" then
			info.title.Text = L("vip_title")
			info.desc.Text = L("vip_desc")
		elseif info.key == "DoubleCheese" then
			info.title.Text = L("double_title")
			info.desc.Text = L("double_desc")
		elseif info.key == "AllClasses" then
			info.title.Text = L("allclasses_title")
			info.desc.Text = L("allclasses_desc")
		elseif info.key == "BeChef" then
			info.title.Text = L("bechef_title")
			info.desc.Text = L("bechef_desc")
		else
			info.title.Text = L("pack_title", info.coins)
			info.desc.Text = L("pack_desc")
		end
		local done = (info.kind == "pass" and player:GetAttribute(info.key)) or (info.key == "BeChef" and player:GetAttribute("ChefNext"))
		if done then
			b.Text = L("owned")
			b.BackgroundColor3 = Color3.fromRGB(120, 120, 130)
		elseif info.id <= 0 then
			b.Text = L("soon")
			b.BackgroundColor3 = Color3.fromRGB(90, 80, 95)
		else
			b.Text = "R$ " .. info.price
			b.BackgroundColor3 = GREEN
		end
	end
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

-- ===== 🎟️ Коды =====
local codesPanel = panel(gui, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.45),
	Size = UDim2.fromOffset(420, 210),
	Visible = false,
	ZIndex = 12,
})
local codesTitle = text(codesPanel, { Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -80, 0, 40), TextXAlignment = Enum.TextXAlignment.Left, Text = "", ZIndex = 12 })
local closeCodes = button(codesPanel, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Size = UDim2.fromOffset(42, 42), Text = "✕", ZIndex = 12 }, RED)
local codeBox = make("TextBox", codesPanel, {
	Position = UDim2.fromOffset(16, 64),
	Size = UDim2.new(1, -150, 0, 52),
	BackgroundColor3 = Color3.fromRGB(245, 240, 250),
	TextColor3 = Color3.fromRGB(30, 20, 40),
	Font = FONT,
	TextScaled = true,
	PlaceholderText = "TIKTOK",
	Text = "",
	ClearTextOnFocus = false,
	ZIndex = 12,
})
corner(codeBox, 10)
local codeOk = button(codesPanel, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 64), Size = UDim2.fromOffset(118, 52), Text = "OK", ZIndex = 12 }, GREEN)
local codesHint = text(codesPanel, { Position = UDim2.fromOffset(16, 130), Size = UDim2.new(1, -32, 0, 30), Font = Enum.Font.GothamMedium, TextColor3 = Color3.fromRGB(210, 200, 220), Text = "", ZIndex = 12 })
local function sendCode()
	if codeBox.Text ~= "" then
		codeEvent:FireServer(codeBox.Text)
		codeBox.Text = ""
	end
end
codeOk.Activated:Connect(sendCode)
codeBox.FocusLost:Connect(function(enter)
	if enter then
		sendCode()
	end
end)
codesButton.Activated:Connect(function()
	codesPanel.Visible = not codesPanel.Visible
	if codesPanel.Visible then
		popIn(codesPanel)
	end
end)
closeCodes.Activated:Connect(function()
	codesPanel.Visible = false
end)

-- ===== 👥 Пригласить друзей =====
inviteButton.Activated:Connect(function()
	pcall(function()
		game:GetService("SocialService"):PromptGameInvite(player)
	end)
end)

-- ===== 📜 Задания дня =====
local questsPanel = panel(gui, {
	Position = UDim2.new(0, 12, 0.3, 0),
	Size = UDim2.fromOffset(300, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Visible = false,
})
padding(questsPanel, 12)
local questsLabel = text(questsPanel, {
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	TextSize = 18,
	TextWrapped = true,
	RichText = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	Text = "",
})
local function refreshQuests()
	local lines = { "<b>" .. L("quests_title") .. "</b>" }
	for entry in string.gmatch(player:GetAttribute("Quests") or "", "[^;]+") do
		local kind, prog, goal, rewardAmount, done = string.match(entry, "^(%w+):(%d+):(%d+):(%d+):(%d)$")
		if kind then
			local line = L("quest_" .. kind, tonumber(prog), tonumber(goal))
			if done == "1" then
				table.insert(lines, '<font color="#7CFC8A">✔ ' .. line .. "</font>")
			else
				table.insert(lines, "• " .. line .. ' <font color="#FFD750">+' .. rewardAmount .. " 🧀</font>")
			end
		end
	end
	questsLabel.Text = table.concat(lines, "\n")
end

-- бонус друзей
local friendPill = panel(gui, {
	Position = UDim2.new(0.5, 190, 0, 90),
	Size = UDim2.fromOffset(120, 28),
	Visible = false,
})
local friendLabel = text(friendPill, { Size = UDim2.fromScale(1, 1), Text = "", TextColor3 = Color3.fromRGB(120, 220, 255) })
padding(friendPill, 4)

-- ===== Кнопка «Сбежать из клетки» (Robux) =====
local escapeButton = button(gui, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -150),
	Size = UDim2.fromOffset(300, 56),
	Text = "",
	Visible = false,
	ZIndex = 6,
}, GREEN)
escapeButton.Activated:Connect(function()
	if not escapeProduct or escapeProduct.Id <= 0 then
		addFeedLocal(L("not_configured"))
		return
	end
	MarketplaceService:PromptProductPurchase(player, escapeProduct.Id)
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
local abilityButton = button(touchBar, { Position = UDim2.fromOffset(0, -84), Size = UDim2.fromOffset(80, 80), Text = "⚡" }, Color3.fromRGB(150, 220, 255))
local emoteButton = button(touchBar, { Position = UDim2.fromOffset(90, -84), Size = UDim2.fromOffset(70, 70), Text = "💃" }, Color3.fromRGB(255, 200, 120))
local emoteIndex = 0
emoteButton.Activated:Connect(function()
	emoteIndex = emoteIndex % #Config.Emotes + 1
	emoteEvent:FireServer(Config.Emotes[emoteIndex].Id)
end)
corner(abilityButton, 40)
abilityButton.Activated:Connect(function()
	abilityEvent:FireServer()
end)
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
	elseif input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonX then
		abilityEvent:FireServer()
	else
		for _, em in ipairs(Config.Emotes) do
			if input.KeyCode == Enum.KeyCode[em.Key] then
				emoteEvent:FireServer(em.Id)
			end
		end
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

addFeedLocal = function(msg)
	addFeed(msg, "info")
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
		resTitle.Text = L("victory")
		resTitle.TextColor3 = GREEN
	else
		resTitle.Text = L("defeat")
		resTitle.TextColor3 = RED
	end
	if data.winner == "Rats" then
		resWinner.Text = L("rats_won")
	else
		resWinner.Text = L("chef_won")
	end
	resReason.Text = data.reason or ""
	if data.mvp and data.mvp ~= "" then
		resMvp.Text = L("mvp", data.mvp, data.mvpScore or 0)
	else
		resMvp.Text = ""
	end
	resCoins.Text = L("round_coins", data.coins or 0)
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
	local list = Config.taggedInMap("Sabotage")
	table.sort(list, function(a, b)
		return (a:GetAttribute("TaskName") or a.Name) < (b:GetAttribute("TaskName") or b.Name)
	end)
	return list
end

local MINI_ICONS = { Wires = "🔌", Mash = "🦷", Code = "🔢", Timing = "⏱" }

local function refreshPrompts()
	local r = role()
	local lg = lang()
	local caught = player:GetAttribute("Caught") == true
	local busy = player:GetAttribute("LocalFreeze") == true
	local cls = Config.getClass(player:GetAttribute("Class") or "normal") or Config.Classes[1]
	for _, st in ipairs(CollectionService:GetTagged("Sabotage")) do
		local here = Config.inActiveMap(st)
		local broken = st:GetAttribute("Broken") == true
		local sab = st:FindFirstChild("SabotagePrompt")
		local rep = st:FindFirstChild("RepairPrompt")
		local name = Locale.taskName(lg, st)
		if sab then
			sab.Enabled = here and r == "Rat" and not caught and not broken and not busy
			if not st:GetAttribute("MiniGame") then
				-- «Сильная» крыса держит E меньше
				sab.HoldDuration = (st:GetAttribute("HoldTime") or Config.DefaultSabotageTime) / (cls.SabotageMult or 1)
			end
			sab.ActionText = L("prompt_sabotage")
			sab.ObjectText = name
		end
		if rep then
			rep.Enabled = here and r == "Chef" and broken
			rep.ActionText = L("prompt_repair")
			rep.ObjectText = name
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
		hl.Enabled = here and ((r == "Rat" and not broken) or (r == "Chef" and broken))
		if r == "Chef" then
			hl.OutlineColor = Color3.fromRGB(255, 80, 80)
		else
			hl.OutlineColor = YELLOW
		end
	end
	for _, cage in ipairs(CollectionService:GetTagged("Cage")) do
		local fp = cage:FindFirstChild("FreePrompt")
		if fp then
			fp.Enabled = Config.inActiveMap(cage) and r == "Rat" and not caught
			fp.ActionText = L("prompt_free")
			fp.ObjectText = L("cage")
		end
	end
	-- таблички на карте
	for _, label in ipairs(CollectionService:GetTagged("Localized")) do
		local t = label:GetAttribute(lg)
		if t and label:IsA("TextLabel") then
			label.Text = t
		end
	end
end

local function refreshTasks()
	local r = role()
	local lg = lang()
	local lines = {}
	if r == "Rat" then
		table.insert(lines, "<b>" .. L("tasks_rat") .. "</b>")
		for _, st in ipairs(sortedStations()) do
			local name = Locale.taskName(lg, st)
			local icon = MINI_ICONS[st:GetAttribute("MiniGame") or ""] or "✋"
			if st:GetAttribute("Broken") then
				table.insert(lines, '<font color="#7CFC8A">✔ <s>' .. name .. "</s></font>")
			else
				table.insert(lines, icon .. " " .. name)
			end
		end
	elseif r == "Chef" then
		table.insert(lines, "<b>" .. L("tasks_chef") .. "</b>")
		local any = false
		for _, st in ipairs(sortedStations()) do
			if st:GetAttribute("Broken") then
				any = true
				table.insert(lines, '<font color="#FF8A80">• ' .. Locale.taskName(lg, st) .. "</font>")
			end
		end
		if not any then
			table.insert(lines, L("all_ok"))
		end
	end
	table.insert(lines, '<font size="13" color="#AAAAAA">' .. L("tab_hide") .. "</font>")
	tasksLabel.Text = table.concat(lines, "\n")
end

local function fmtTime(t)
	return string.format("%d:%02d", math.floor(t / 60), t % 60)
end

local function showRoleCard()
	local r = role()
	if r == "Rat" then
		roleCardTitle.Text = L("you_rat")
		roleCardTitle.TextColor3 = YELLOW
		roleCardGoal.Text = L("goal_rat") .. "  " .. L("map_is", activeMapName())
	elseif r == "Chef" then
		roleCardTitle.Text = L("you_chef")
		roleCardTitle.TextColor3 = Color3.fromRGB(255, 140, 120)
		roleCardGoal.Text = L("goal_chef") .. "  " .. L("map_is", activeMapName())
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
			countdown.Text = L("chaos_go")
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
			statusLabel.Text = L("start_in", t)
		else
			statusLabel.Text = L("waiting")
		end
	elseif state == "Intro" then
		statusLabel.Text = activeMapName()
	elseif state == "Playing" then
		statusLabel.Text = "⏱ " .. fmtTime(t)
		if t <= 30 then
			statusLabel.TextColor3 = RED
		else
			statusLabel.TextColor3 = WHITE
		end
	else
		statusLabel.Text = L("round_over")
		resNext.Text = L("next_round", t)
	end
	local chaos = ReplicatedStorage:GetAttribute("Chaos") or 0
	local frac = math.clamp(chaos / Config.ChaosToWin, 0, 1)
	chaosFill.Size = UDim2.fromScale(frac, 1)
	if chaos >= Config.AlarmChaos and state == "Playing" then
		chaosText.Text = L("alarm_bar", math.floor(frac * 100))
		local pulse = (math.sin(os.clock() * 8) + 1) / 2
		topStroke.Color = Color3.fromRGB(255, 60 + 100 * pulse, 60)
		topStroke.Transparency = 0.1
	else
		chaosText.Text = L("chaos_bar", math.floor(frac * 100))
		topStroke.Color = Color3.fromRGB(255, 200, 120)
		topStroke.Transparency = 0.4
	end
	chaosBg.Visible = state ~= "Lobby"
	lobbyBar.Visible = state == "Lobby"
	if state ~= "Lobby" then
		shop.Visible = false
	end
	coinsLabel.Text = "🧀 " .. (player:GetAttribute("Coins") or 0)
	levelLabel.Text = "⭐ " .. (player:GetAttribute("Level") or 1)
	xpFill.Size = UDim2.fromScale(math.clamp((player:GetAttribute("XP") or 0) / math.max(1, player:GetAttribute("XPNeed") or 100), 0, 1), 1)
	local ev = ReplicatedStorage:GetAttribute("Event") or ""
	eventPill.Visible = ev ~= "" and (state == "Intro" or state == "Playing")
	if ev ~= "" then
		eventLabel.Text = L("ev_" .. ev)
	end

	-- роль
	if r == "Rat" then
		if caught then
			roleLabel.Text = L("role_caught")
			hintLabel.Text = L("hint_caught")
		elseif player:GetAttribute("Stunned") then
			roleLabel.Text = L("role_stunned")
			hintLabel.Text = L("hint_stunned")
		else
			roleLabel.Text = L("role_rat")
			hintLabel.Text = L("hint_rat")
		end
	elseif r == "Chef" then
		roleLabel.Text = L("role_chef")
		hintLabel.Text = L("hint_chef")
	else
		roleLabel.Text = L("role_lobby")
		hintLabel.Text = L("hint_lobby")
	end
	-- надписи, которые зависят только от языка
	hungerCaption.Text = L("hunger")
	staminaCaption.Text = L("stamina")
	shopButton.Text = L("shop_main")
	codesButton.Text = L("codes_button")
	inviteButton.Text = L("invite_button")
	codesTitle.Text = L("codes_title")
	codesHint.Text = L("codes_hint")
	friendPill.Visible = player:GetAttribute("FriendBonus") == true
	friendLabel.Text = L("friend_bonus")
	questsPanel.Visible = (state == "Lobby" or state == "Ended") and (player:GetAttribute("Quests") or "") ~= "" and not shop.Visible
	if state ~= "Lobby" then
		codesPanel.Visible = false
	end
	emoteButton.Visible = r == "Rat" and not caught
	refreshChefButton()
	hungerBg.Visible = r == "Rat"
	staminaBg.Visible = r == "Rat" or r == "Chef"
	hungerFill.Size = UDim2.fromScale((player:GetAttribute("Hunger") or Config.HungerMax) / Config.HungerMax, 1)
	staminaFill.Size = UDim2.fromScale(stamina / Config.StaminaMax, 1)
	touchBar.Visible = UserInputService.TouchEnabled and (r == "Rat" or r == "Chef")
	squeakButton.Visible = r == "Rat"
	tasksPanel.Visible = showTasks and (r == "Rat" or r == "Chef") and state == "Playing"

	-- способность класса
	local cls = Config.getClass(player:GetAttribute("Class") or "normal") or Config.Classes[1]
	local hasAbility = r == "Rat" and cls.Ability ~= nil and state == "Playing" and not caught
	abilityPill.Visible = hasAbility
	abilityButton.Visible = hasAbility
	if hasAbility then
		local left = abilityReadyAt - os.clock()
		local abilityName = L("ability_" .. cls.Ability)
		if left > 0 then
			abilityLabel.Text = ("⏳ %d • %s"):format(math.ceil(left), abilityName)
			abilityLabel.TextColor3 = Color3.fromRGB(170, 160, 180)
			abilityButton.Text = tostring(math.ceil(left))
		else
			abilityLabel.Text = "F • " .. abilityName
			abilityLabel.TextColor3 = Color3.fromRGB(150, 220, 255)
			abilityButton.Text = cls.Icon
		end
	end

	-- сбежать из клетки за Robux
	escapeButton.Visible = r == "Rat" and caught and state == "Playing" and escapeProduct ~= nil
	if escapeButton.Visible then
		escapeButton.Text = L("escape_btn", escapeProduct.Price)
	end

	-- «Как играть» в первом раунде
	local firstRound = not player:GetAttribute("TutorialDone")
	local showTut = firstRound and state == "Playing" and (r == "Rat" or r == "Chef") and t > Config.RoundTime - 35
	tutorial.Visible = showTut
	if showTut then
		local p = (r == "Rat") and "tut_rat" or "tut_chef"
		tutorialLabel.Text = ("<b>%s</b>\n%s\n%s\n%s\n%s"):format(L("tut_title"), L(p .. "1"), L(p .. "2"), L(p .. "3"), L(p .. "4"))
	end

	accum = accum + dt
	if accum >= 0.5 then
		accum = 0
		refreshPrompts()
		refreshTasks()
		refreshVotes()
		refreshQuests()
		if shop.Visible then
			refreshShop()
		end
		-- стрелка к ближайшему заданию: крысе — что сломать, повару — что починить
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local target, best = nil, math.huge
		if root and state == "Playing" and ((r == "Rat" and not caught) or r == "Chef") then
			for _, st in ipairs(Config.taggedInMap("Sabotage")) do
				local broken = st:GetAttribute("Broken") == true
				if (r == "Rat" and not broken) or (r == "Chef" and broken) then
					local d = (st.Position - root.Position).Magnitude
					if d < best then
						target, best = st, d
					end
				end
			end
		end
		marker.Enabled = target ~= nil and best > 8
		if target then
			marker.Adornee = target
			local icon = (r == "Chef") and "🔧" or "💥"
			markerLabel.Text = ("%s %s\n⬇ %s"):format(icon, Locale.taskName(lang(), target), L("marker_dist", math.floor(best)))
			markerLabel.TextColor3 = (r == "Chef") and Color3.fromRGB(255, 120, 110) or YELLOW
		end
	end
end)
