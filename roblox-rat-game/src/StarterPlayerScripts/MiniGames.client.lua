-- MiniGames (LocalScript) — StarterPlayer > StarterPlayerScripts
-- Мини-игры при поломке: 🔌 провода, 🦷 грызть, 🔢 пароль, ⏱ вовремя.
-- Пока крыса играет, она стоит на месте — повар может подкрасться!

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local miniGameEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MiniGame")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FONT = Enum.Font.FredokaOne
local PANEL = Color3.fromRGB(28, 22, 34)
local WHITE = Color3.new(1, 1, 1)
local W, H = 460, 340

local gui = Instance.new("ScreenGui")
gui.Name = "MiniGames"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Parent = playerGui

local current = nil -- { station, kind, frame, started, done, onKey, onStep }

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

local function label(parent, props)
	local t = make("TextLabel", parent, props)
	t.BackgroundTransparency = 1
	t.Font = FONT
	t.TextScaled = true
	t.TextColor3 = props.TextColor3 or WHITE
	return t
end

local function btn(parent, props, color)
	local b = make("TextButton", parent, props)
	b.Font = FONT
	b.TextScaled = true
	b.BackgroundColor3 = color
	b.TextColor3 = props.TextColor3 or WHITE
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	corner(b, 10)
	return b
end

local function setFrozen(on)
	player:SetAttribute("LocalFreeze", on)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, not on)
	end
end

local function close(sendCancel)
	if not current then
		return
	end
	if sendCancel and not current.done then
		miniGameEvent:FireServer("cancel", current.station)
	end
	current.frame:Destroy()
	current = nil
	setFrozen(false)
end

local function finish(answer)
	if not current or current.done then
		return
	end
	local game_ = current
	game_.done = true
	game_.status.Text = "✔ Готово!"
	game_.status.TextColor3 = Color3.fromRGB(120, 255, 140)
	local minTime = Config.MiniGameMinTime[game_.kind] or 1
	local wait = math.max(0.3, minTime - (os.clock() - game_.started) + 0.1)
	task.delay(wait, function()
		if current == game_ then
			miniGameEvent:FireServer("done", game_.station, answer)
			close(false)
		end
	end)
end

local function flashWrong()
	if not current then
		return
	end
	local st = current.status
	st.Text = "❌ Не то!"
	st.TextColor3 = Color3.fromRGB(255, 110, 100)
	task.delay(0.6, function()
		if current and not current.done and current.status == st then
			st.Text = current.hint
			st.TextColor3 = Color3.fromRGB(220, 210, 225)
		end
	end)
end

local function newFrame(title, hint)
	local frame = make("Frame", gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(W, H),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
	})
	corner(frame, 16)
	make("UIStroke", frame, { Color = Color3.fromRGB(255, 200, 120), Thickness = 3, Transparency = 0.2 })
	local scale = make("UIScale", frame, { Scale = 0.6 })
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	label(frame, { Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -80, 0, 36), Text = title, TextXAlignment = Enum.TextXAlignment.Left })
	local x = btn(frame, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(40, 40), Text = "✕" }, Color3.fromRGB(220, 70, 70))
	x.Activated:Connect(function()
		close(true)
	end)
	local status = label(frame, {
		Position = UDim2.new(0, 16, 1, -40),
		Size = UDim2.new(1, -32, 0, 30),
		Text = hint,
		TextColor3 = Color3.fromRGB(220, 210, 225),
	})
	return frame, status
end

-- ===== 🔌 Провода =====
local WIRE_COLORS = {
	Color3.fromRGB(235, 60, 60),
	Color3.fromRGB(70, 120, 255),
	Color3.fromRGB(70, 200, 90),
	Color3.fromRGB(255, 210, 50),
}

local function buildWires(frame)
	local btnW, btnH = 90, 40
	local order = { 1, 2, 3, 4 }
	for i = #order, 2, -1 do
		local j = math.random(i)
		order[i], order[j] = order[j], order[i]
	end
	local connected = {}
	local count = 0
	local selected = nil
	local leftButtons = {}

	local function rowY(i)
		return 60 + (i - 1) * 56
	end

	local function drawWire(i, rightRow)
		local x1, y1 = 20 + btnW, rowY(i) + btnH / 2
		local x2, y2 = W - 20 - btnW, rowY(rightRow) + btnH / 2
		local dx, dy = x2 - x1, y2 - y1
		local wire = make("Frame", frame, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2),
			Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy), 8),
			Rotation = math.deg(math.atan2(dy, dx)),
			BackgroundColor3 = WIRE_COLORS[i],
			BorderSizePixel = 0,
		})
		corner(wire, 4)
	end

	for i = 1, 4 do
		local b = btn(frame, { Position = UDim2.fromOffset(20, rowY(i)), Size = UDim2.fromOffset(btnW, btnH), Text = "" }, WIRE_COLORS[i])
		local st = make("UIStroke", b, { Color = WHITE, Thickness = 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
		leftButtons[i] = st
		b.Activated:Connect(function()
			if connected[i] or not current or current.done then
				return
			end
			selected = i
			for k, s in ipairs(leftButtons) do
				if k == i then
					s.Thickness = 4
				else
					s.Thickness = 0
				end
			end
		end)
	end
	for row = 1, 4 do
		local colorIndex = order[row]
		local b = btn(frame, { Position = UDim2.fromOffset(W - 20 - btnW, rowY(row)), Size = UDim2.fromOffset(btnW, btnH), Text = "" }, WIRE_COLORS[colorIndex])
		b.Activated:Connect(function()
			if not selected or not current or current.done then
				return
			end
			if colorIndex == selected and not connected[selected] then
				connected[selected] = true
				count = count + 1
				drawWire(selected, row)
				leftButtons[selected].Thickness = 0
				selected = nil
				if count >= 4 then
					finish(nil)
				end
			else
				flashWrong()
			end
		end)
	end
end

-- ===== 🦷 Грызть =====
local function buildMash(frame)
	local progress = 0
	local barBg = make("Frame", frame, {
		Position = UDim2.fromOffset(30, 70),
		Size = UDim2.fromOffset(W - 60, 36),
		BackgroundColor3 = Color3.fromRGB(60, 50, 66),
		BorderSizePixel = 0,
	})
	corner(barBg, 10)
	local fill = make("Frame", barBg, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(255, 170, 60), BorderSizePixel = 0 })
	corner(fill, 10)
	local gnaw = btn(frame, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 130),
		Size = UDim2.fromOffset(220, 130),
		Text = "🦷 ГРЫЗТЬ!",
		TextColor3 = Color3.fromRGB(50, 30, 10),
	}, Color3.fromRGB(255, 220, 120))
	local scale = make("UIScale", gnaw, {})

	local function press()
		if not current or current.done then
			return
		end
		progress = math.min(100, progress + 7)
		scale.Scale = 0.9
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
		if progress >= 100 then
			finish(nil)
		end
	end
	gnaw.Activated:Connect(press)
	current.onKey = press
	current.onStep = function(dt)
		if not current.done then
			progress = math.max(0, progress - 12 * dt)
		end
		fill.Size = UDim2.fromScale(progress / 100, 1)
	end
end

-- ===== 🔢 Пароль =====
local function buildCode(frame, code)
	local entered = ""
	local note = make("Frame", frame, {
		Position = UDim2.fromOffset(20, 60),
		Size = UDim2.fromOffset(150, 120),
		BackgroundColor3 = Color3.fromRGB(255, 230, 110),
		BorderSizePixel = 0,
		Rotation = -6,
	})
	label(note, { Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -16, 0, 30), Text = "Пароль:", TextColor3 = Color3.fromRGB(60, 40, 20) })
	label(note, { Position = UDim2.fromOffset(8, 44), Size = UDim2.new(1, -16, 0, 56), Text = code or "????", TextColor3 = Color3.fromRGB(60, 40, 20) })
	local display = label(frame, {
		Position = UDim2.fromOffset(190, 56),
		Size = UDim2.fromOffset(250, 44),
		Text = "_ _ _ _",
	})
	local keys = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "⌫", "0", "" }
	local function refresh()
		local shown = {}
		for i = 1, 4 do
			local ch = string.sub(entered, i, i)
			if ch == "" then
				ch = "_"
			end
			table.insert(shown, ch)
		end
		display.Text = table.concat(shown, " ")
	end
	for i, key in ipairs(keys) do
		if key ~= "" then
			local col = (i - 1) % 3
			local row = math.floor((i - 1) / 3)
			local b = btn(frame, {
				Position = UDim2.fromOffset(200 + col * 78, 108 + row * 46),
				Size = UDim2.fromOffset(70, 40),
				Text = key,
			}, Color3.fromRGB(70, 60, 85))
			b.Activated:Connect(function()
				if not current or current.done then
					return
				end
				if key == "⌫" then
					entered = string.sub(entered, 1, -2)
				elseif #entered < 4 then
					entered = entered .. key
				end
				refresh()
				if #entered == 4 then
					if entered == code then
						finish(entered)
					else
						flashWrong()
						entered = ""
						task.delay(0.3, refresh)
					end
				end
			end)
		end
	end
end

-- ===== ⏱ Вовремя =====
local function buildTiming(frame)
	local barW = W - 60
	local hits = 0
	local needed = 3
	local pos = 0
	local dir = 1
	local speed = 0.9
	local zoneW = 80
	local zoneX = 0
	local barBg = make("Frame", frame, {
		Position = UDim2.fromOffset(30, 90),
		Size = UDim2.fromOffset(barW, 40),
		BackgroundColor3 = Color3.fromRGB(60, 50, 66),
		BorderSizePixel = 0,
	})
	corner(barBg, 8)
	local zone = make("Frame", barBg, { Size = UDim2.fromOffset(zoneW, 40), BackgroundColor3 = Color3.fromRGB(80, 210, 100), BorderSizePixel = 0 })
	corner(zone, 8)
	local needle = make("Frame", barBg, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(8, 56),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 2,
	})
	local counter = label(frame, { Position = UDim2.fromOffset(30, 150), Size = UDim2.new(1, -60, 0, 36), Text = "" })
	local stop = btn(frame, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 200),
		Size = UDim2.fromOffset(200, 70),
		Text = "⏱ СТОП!",
		TextColor3 = Color3.fromRGB(50, 30, 10),
	}, Color3.fromRGB(255, 220, 120))

	local function newZone()
		zoneX = math.random(0, barW - zoneW)
		zone.Position = UDim2.fromOffset(zoneX, 0)
		local dots = {}
		for i = 1, needed do
			if i <= hits then
				table.insert(dots, "🟢")
			else
				table.insert(dots, "⚪")
			end
		end
		counter.Text = table.concat(dots, " ")
	end
	newZone()

	local function press()
		if not current or current.done then
			return
		end
		local x = pos * barW
		if x >= zoneX and x <= zoneX + zoneW then
			hits = hits + 1
			speed = speed + 0.25
			if hits >= needed then
				newZone()
				finish(nil)
				return
			end
		else
			hits = math.max(0, hits - 1)
			flashWrong()
		end
		newZone()
	end
	stop.Activated:Connect(press)
	current.onKey = press
	current.onStep = function(dt)
		if current.done then
			return
		end
		pos = pos + dir * speed * dt
		if pos > 1 then
			pos = 1
			dir = -1
		elseif pos < 0 then
			pos = 0
			dir = 1
		end
		needle.Position = UDim2.fromOffset(pos * barW, 20)
	end
end

-- ===== Открыть мини-игру =====
local TITLES = {
	Wires = { "🔌 Перегрызи провода!", "Соедини провода одного цвета" },
	Mash = { "🦷 Грызи быстрее!", "Жми кнопку, E или Пробел" },
	Code = { "🔢 Взломай пароль!", "Набери пароль со стикера" },
	Timing = { "⏱ Жми вовремя!", "Останови полоску на зелёном (E / Пробел)" },
}

local function open(station, kind, data)
	close(true)
	local info = TITLES[kind]
	if not info then
		return
	end
	local frame, status = newFrame(info[1], info[2])
	current = {
		station = station,
		kind = kind,
		frame = frame,
		status = status,
		hint = info[2],
		started = os.clock(),
		done = false,
	}
	setFrozen(true)
	if kind == "Wires" then
		buildWires(frame)
	elseif kind == "Mash" then
		buildMash(frame)
	elseif kind == "Code" then
		buildCode(frame, data and data.code)
	elseif kind == "Timing" then
		buildTiming(frame)
	end
end

miniGameEvent.OnClientEvent:Connect(function(action, station, kind, data)
	if action == "open" then
		open(station, kind, data)
	elseif action == "close" then
		close(false)
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if not current or not current.onKey then
		return
	end
	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
		current.onKey()
	end
end)

RunService.Heartbeat:Connect(function(dt)
	if not current then
		return
	end
	if current.onStep then
		current.onStep(dt)
	end
	-- закрыть, если крысу поймали, раунд кончился или она ушла
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local station = current.station
	local bad = player:GetAttribute("Role") ~= "Rat"
		or player:GetAttribute("Caught")
		or ReplicatedStorage:GetAttribute("State") ~= "Playing"
		or not root
		or not station
		or not station.Parent
		or (station:GetAttribute("Broken") and not current.done)
		or (root.Position - station.Position).Magnitude > 16
	if bad then
		close(true)
	end
end)
