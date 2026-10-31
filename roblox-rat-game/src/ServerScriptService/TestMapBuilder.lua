-- TestMapBuilder (ModuleScript) — ServerScriptService
-- Строит уютный ночной ресторан, если в Workspace нет папки "Map".
-- Потом можно построить свою карту в папке Workspace/Map — и этот скрипт перестанет срабатывать.
--
-- План (вид сверху):
--   Кабинет | Кухня        | Зал (столики, камин)
--   --------|              |
--   Склад   |--------------+------
--   (клетка,| Бар          | Туалет
--    гнездо)|              |
-- В некоторых стенах есть крысиные лазейки внизу: крыса пролезет, повар — нет!

local Lighting = game:GetService("Lighting")

local TestMapBuilder = {}

local H = 14 -- высота стен
local GAP_W = 2.8 -- ширина крысиной лазейки
local GAP_H = 2.6 -- высота лазейки
local map

local C = {
	wood = Color3.fromRGB(120, 78, 50),
	darkWood = Color3.fromRGB(80, 50, 35),
	wall = Color3.fromRGB(214, 176, 134),
	wainscot = Color3.fromRGB(105, 62, 42),
	tile = Color3.fromRGB(215, 215, 205),
	steel = Color3.fromRGB(170, 172, 178),
	white = Color3.fromRGB(240, 240, 235),
	black = Color3.fromRGB(25, 22, 25),
	cheese = Color3.fromRGB(255, 205, 60),
	dark = Color3.fromRGB(40, 32, 30),
	crate = Color3.fromRGB(165, 120, 75),
	green = Color3.fromRGB(70, 140, 70),
	terracotta = Color3.fromRGB(180, 95, 60),
	red = Color3.fromRGB(170, 40, 45),
}

local VERT = CFrame.Angles(0, 0, math.rad(90)) -- цилиндр стоит вертикально

-- ===== Помощники =====

local function block(name, size, pos, color, material, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	if typeof(pos) == "CFrame" then
		p.CFrame = pos
	else
		p.CFrame = CFrame.new(pos)
	end
	p.Color = color or C.wall
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or map
	return p
end

local function ball(name, d, pos, color, material, parent)
	local p = block(name, Vector3.new(d, d, d), pos, color, material, parent)
	p.Shape = Enum.PartType.Ball
	return p
end

-- вертикальный цилиндр: h — высота, d — диаметр, pos — центр
local function cyl(name, h, d, pos, color, material, parent)
	local p = block(name, Vector3.new(h, d, d), CFrame.new(pos) * VERT, color, material, parent)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function ghost(p) -- невидимая, не мешает ходить и не закрывает обзор
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function decor(p) -- мелочь: не мешает ходить
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function marker(tag, pos)
	local p = ghost(block(tag, Vector3.new(2, 1, 2), pos, C.white))
	p:AddTag(tag)
	return p
end

-- textEn — тот же текст по-английски (игра покажет нужный язык каждому игроку)
local function label(text, pos, width, maxDistance, textEn)
	local p = ghost(block("Label", Vector3.new(1, 1, 1), pos, C.white))
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(width or 220, 50)
	bb.MaxDistance = maxDistance or 70
	bb.LightInfluence = 0
	bb.Parent = p
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = Color3.fromRGB(255, 230, 180)
	t.TextStrokeTransparency = 0.4
	if textEn then
		t:SetAttribute("ru", text)
		t:SetAttribute("en", textEn)
		t:AddTag("Localized")
	end
	t.Parent = bb
	return p
end

-- Плоская табличка/картина. intoRoom — куда смотрит лицевая сторона.
local function sign(pos, intoRoom, w, h, text, bg, textColor, textEn)
	local cf = CFrame.lookAt(pos, pos + intoRoom)
	decor(block("Frame", Vector3.new(w, h, 0.2), cf, C.darkWood, Enum.Material.Wood))
	local canvas = decor(block("Canvas", Vector3.new(w - 0.4, h - 0.4, 0.22), cf * CFrame.new(0, 0, -0.02), bg))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0.3
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = canvas
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = textColor or Color3.new(1, 1, 1)
	if textEn then
		t:SetAttribute("ru", text)
		t:SetAttribute("en", textEn)
		t:AddTag("Localized")
	end
	t.Parent = gui
	return canvas
end

local function wallPiece(x1, z1, x2, z2, y0, y1)
	local h = y1 - y0
	local vertical = x1 == x2
	local size
	if vertical then
		size = Vector3.new(1, h, math.abs(z2 - z1))
	else
		size = Vector3.new(math.abs(x2 - x1), h, 1)
	end
	local cx, cz = (x1 + x2) / 2, (z1 + z2) / 2
	block("Wall", size, Vector3.new(cx, (y0 + y1) / 2, cz), C.wall, Enum.Material.Plaster)
	-- деревянная панель внизу стены
	if y0 < 3.5 then
		local th = math.min(y1, 3.5) - y0
		local tsize
		if vertical then
			tsize = Vector3.new(1.15, th, math.abs(z2 - z1))
		else
			tsize = Vector3.new(math.abs(x2 - x1), th, 1.15)
		end
		block("Wainscot", tsize, Vector3.new(cx, y0 + th / 2, cz), C.wainscot, Enum.Material.Wood)
	end
end

-- Стена по прямой. gaps — список координат вдоль стены, где будут крысиные лазейки.
local function wall(x1, z1, x2, z2, gaps)
	local vertical = x1 == x2
	local a, b, fixed
	if vertical then
		a, b, fixed = math.min(z1, z2), math.max(z1, z2), x1
	else
		a, b, fixed = math.min(x1, x2), math.max(x1, x2), z1
	end
	local function piece(s, e, y0, y1)
		if e - s < 0.05 then
			return
		end
		if vertical then
			wallPiece(fixed, s, fixed, e, y0, y1)
		else
			wallPiece(s, fixed, e, fixed, y0, y1)
		end
	end
	local cuts = {}
	for _, g in ipairs(gaps or {}) do
		table.insert(cuts, g)
	end
	table.sort(cuts)
	local cursor = a
	for _, g in ipairs(cuts) do
		piece(cursor, g - GAP_W / 2, 0, H)
		piece(g - GAP_W / 2, g + GAP_W / 2, GAP_H, H)
		local signPos
		if vertical then
			signPos = Vector3.new(fixed, GAP_H + 0.9, g)
		else
			signPos = Vector3.new(g, GAP_H + 0.9, fixed)
		end
		label("🐀", signPos, 40, 30)
		cursor = g + GAP_W / 2
	end
	piece(cursor, b, 0, H)
end

local function floor(x1, z1, x2, z2, color, material)
	return block("Floor", Vector3.new(x2 - x1, 0.4, z2 - z1), Vector3.new((x1 + x2) / 2, 0, (z1 + z2) / 2), color, material)
end

local function tableWithLegs(cx, cz, w, d, h, color)
	local top = block("TableTop", Vector3.new(w, 0.4, d), Vector3.new(cx, h - 0.2, cz), color or C.wood, Enum.Material.Wood)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			block(
				"TableLeg",
				Vector3.new(0.4, h - 0.4, 0.4),
				Vector3.new(cx + sx * (w / 2 - 0.4), (h - 0.4) / 2, cz + sz * (d / 2 - 0.4)),
				C.darkWood
			)
		end
	end
	return top
end

local function chair(cx, cz, backDir)
	block("ChairSeat", Vector3.new(2, 0.3, 2), Vector3.new(cx, 2, cz), C.wood, Enum.Material.Wood)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			block("ChairLeg", Vector3.new(0.25, 1.85, 0.25), Vector3.new(cx + sx * 0.8, 0.925, cz + sz * 0.8), C.darkWood)
		end
	end
	block("ChairBack", Vector3.new(2, 2.2, 0.3), Vector3.new(cx, 3.25, cz + backDir * 0.85), C.wood, Enum.Material.Wood)
end

local function shelf(cx, cz, w, d, h, levels)
	for i = 0, levels do
		local y = 0.3 + i * (h - 0.3) / levels
		block("ShelfBoard", Vector3.new(w, 0.3, d), Vector3.new(cx, y, cz), C.darkWood, Enum.Material.Wood)
	end
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			block("ShelfPost", Vector3.new(0.3, h, 0.3), Vector3.new(cx + sx * (w / 2 - 0.15), h / 2, cz + sz * (d / 2 - 0.15)), C.darkWood)
		end
	end
end

local function crate(pos, s)
	s = s or 2.5
	return block("Crate", Vector3.new(s, s, s), pos, C.crate, Enum.Material.Wood)
end

local function barrel(x, z)
	cyl("Barrel", 3, 2.4, Vector3.new(x, 1.5, z), Color3.fromRGB(130, 85, 50), Enum.Material.Wood)
	cyl("BarrelRing", 0.25, 2.5, Vector3.new(x, 0.6, z), Color3.fromRGB(70, 70, 75), Enum.Material.Metal)
	cyl("BarrelRing", 0.25, 2.5, Vector3.new(x, 2.4, z), Color3.fromRGB(70, 70, 75), Enum.Material.Metal)
end

local function plant(x, z, s)
	s = s or 1
	cyl("Pot", 1.4 * s, 1.5 * s, Vector3.new(x, 0.7 * s, z), C.terracotta)
	for i = 0, 2 do
		local a = i * 2.1
		decor(ball("Leaves", 1.5 * s, Vector3.new(x + math.cos(a) * 0.45 * s, (2 + i * 0.35) * s, z + math.sin(a) * 0.45 * s), C.green, Enum.Material.Grass))
	end
end

local function lamp(x, z)
	local p = block("Lamp", Vector3.new(2.5, 0.5, 2.5), Vector3.new(x, H - 1.5, z), Color3.fromRGB(255, 210, 140), Enum.Material.Neon)
	decor(block("LampCord", Vector3.new(0.1, 1.2, 0.1), Vector3.new(x, H - 0.65, z), C.black))
	local l = Instance.new("PointLight")
	l.Range = 30
	l.Brightness = 1.3
	l.Color = Color3.fromRGB(255, 190, 120)
	l.Shadows = true
	l.Parent = p
	-- пылинки в свете лампы
	local dust = Instance.new("ParticleEmitter")
	dust.Rate = 2
	dust.Lifetime = NumberRange.new(6, 10)
	dust.Speed = NumberRange.new(0.1, 0.4)
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.Size = NumberSequence.new(0.08)
	dust.LightEmission = 1
	dust.Transparency = NumberSequence.new(0.4)
	dust.Color = ColorSequence.new(Color3.fromRGB(255, 230, 190))
	dust.Parent = p
	p:AddTag("RoomLight")
	return p
end

local function alarmLight(x, z)
	local p = decor(block("AlarmLamp", Vector3.new(0.8, 0.8, 0.8), Vector3.new(x, H - 0.6, z), Color3.fromRGB(90, 20, 20)))
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 40, 40)
	l.Range = 26
	l.Brightness = 2
	l.Enabled = false
	l.Parent = p
	p:AddTag("AlarmLight")
end

-- Окно с лунным светом. intoRoom — направление внутрь комнаты.
local function window(pos, intoRoom)
	local along
	if math.abs(intoRoom.X) > 0 then
		along = Vector3.new(0, 0, 1)
	else
		along = Vector3.new(1, 0, 0)
	end
	local cf = CFrame.lookAt(pos, pos + intoRoom)
	local pane = decor(block("Window", Vector3.new(6, 5, 1.3), cf, Color3.fromRGB(140, 170, 230), Enum.Material.Neon))
	pane.Transparency = 0.35
	decor(block("WindowBar", Vector3.new(0.3, 5, 1.4), cf, C.darkWood, Enum.Material.Wood))
	decor(block("WindowBar", Vector3.new(6, 0.3, 1.4), cf, C.darkWood, Enum.Material.Wood))
	decor(block("WindowSill", Vector3.new(6.6, 0.3, 1.8), cf * CFrame.new(0, -2.6, 0), C.darkWood, Enum.Material.Wood))
	local moon = Instance.new("SpotLight")
	moon.Face = Enum.NormalId.Front
	moon.Color = Color3.fromRGB(150, 180, 255)
	moon.Brightness = 1.6
	moon.Range = 28
	moon.Angle = 70
	moon.Shadows = true
	moon.Parent = pane
	return along
end

local function candle(x, y, z)
	decor(cyl("CandleHolder", 0.15, 0.6, Vector3.new(x, y + 0.075, z), Color3.fromRGB(200, 170, 80), Enum.Material.Metal))
	decor(cyl("Candle", 0.6, 0.25, Vector3.new(x, y + 0.45, z), C.white))
	local flame = decor(ball("Flame", 0.2, Vector3.new(x, y + 0.85, z), Color3.fromRGB(255, 170, 60), Enum.Material.Neon))
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 160, 70)
	l.Range = 10
	l.Brightness = 1.2
	l.Parent = flame
	l:AddTag("Flicker")
end

local function station(name, size, pos, color, attrs, material)
	local p = block(name, size, pos, color, material)
	for k, v in pairs(attrs) do
		p:SetAttribute(k, v)
	end
	p:AddTag("Sabotage")
	return p
end

local function brokenVisual(parentStation, size, pos, color, material, visibleTransparency)
	local v = ghost(block("BrokenVisual", size, pos, color, material or Enum.Material.Neon, parentStation))
	v:SetAttribute("VisibleTransparency", visibleTransparency or 0)
	return v
end

local function smoke(parent, color, opacity, rise)
	local s = Instance.new("Smoke")
	s.Color = color
	s.Opacity = opacity
	s.RiseVelocity = rise
	s.Enabled = false
	s.Parent = parent
	return s
end

local function ratHole(pair, pos, intoRoom)
	local p = block("RatHole", Vector3.new(2.2, 1.8, 1), CFrame.lookAt(pos, pos + intoRoom), C.black)
	p.CanCollide = false
	p.CanQuery = false
	p:SetAttribute("Pair", pair)
	p:AddTag("RatHole")
	return p
end

local function cheese(x, z)
	local p = block("Cheese", Vector3.new(0.9, 0.6, 0.9), CFrame.new(x, 0.55, z), C.cheese)
	p.CanCollide = false
	p.CanQuery = false
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 210, 90)
	glow.Range = 5
	glow.Brightness = 0.7
	glow.Parent = p
	p:AddTag("Crumb")
	return p
end

local function cage(x, z)
	local size = 8
	local hgt = 5
	local f = block("CageFloor", Vector3.new(size, 0.4, size), Vector3.new(x, 0.4, z), C.steel, Enum.Material.DiamondPlate)
	f:AddTag("Cage")
	for i = 0, size do
		local o = -size / 2 + i
		for _, pos in ipairs({
			Vector3.new(x + o, hgt / 2 + 0.6, z - size / 2),
			Vector3.new(x + o, hgt / 2 + 0.6, z + size / 2),
			Vector3.new(x - size / 2, hgt / 2 + 0.6, z + o),
			Vector3.new(x + size / 2, hgt / 2 + 0.6, z + o),
		}) do
			block("CageBar", Vector3.new(0.25, hgt, 0.25), pos, C.steel, Enum.Material.Metal)
		end
	end
	block("CageRoof", Vector3.new(size + 0.5, 0.3, size + 0.5), Vector3.new(x, hgt + 0.75, z), C.steel, Enum.Material.DiamondPlate)
	label("🪤 Клетка", Vector3.new(x, hgt + 2.5, z), nil, nil, "🪤 Cage")
end

local function toilet(x, z)
	local bowl = block("Toilet", Vector3.new(2.2, 1.8, 2.8), Vector3.new(x, 0.9, z), C.white)
	block("ToiletTank", Vector3.new(2.4, 2.4, 0.8), Vector3.new(x, 2.6, z + 1.5), C.white)
	return bowl
end

local function ensureEffect(className, name)
	local e = Lighting:FindFirstChild(name)
	if not e then
		e = Instance.new(className)
		e.Name = name
		e.Parent = Lighting
	end
	return e
end

-- ===== Строим =====

function TestMapBuilder.build()
	map = Instance.new("Folder")
	map.Name = "Map"

	-- Полы комнат (верх пола на высоте 0.2)
	floor(-60, -45, -30, -5, C.wood, Enum.Material.WoodPlanks) -- Кабинет
	floor(-60, -5, -30, 45, Color3.fromRGB(110, 105, 100), Enum.Material.Concrete) -- Склад
	floor(-30, -45, 10, 15, C.tile, Enum.Material.CeramicTiles) -- Кухня
	floor(-30, 15, 20, 45, C.darkWood, Enum.Material.WoodPlanks) -- Бар
	floor(20, 15, 60, 45, Color3.fromRGB(190, 210, 220), Enum.Material.CeramicTiles) -- Туалет
	floor(10, -45, 60, 15, Color3.fromRGB(140, 40, 40), Enum.Material.Carpet) -- Зал

	-- Внешние стены
	wall(-60, -45, 60, -45)
	wall(-60, 45, 60, 45)
	wall(-60, -45, -60, 45)
	wall(60, -45, 60, 45)
	-- Внутренние стены: проёмы-двери по 8 стадов + крысиные лазейки
	wall(-30, -45, -30, -34)
	wall(-30, -26, -30, 1, { -15 }) -- лазейка Кабинет ↔ Кухня
	wall(-30, 9, -30, 26)
	wall(-30, 34, -30, 45)
	wall(-60, -5, -49, -5)
	wall(-41, -5, -30, -5, { -35 }) -- лазейка Кабинет ↔ Склад
	wall(-30, 15, -14, 15)
	wall(-6, 15, 11, 15)
	wall(19, 15, 36, 15, { 28 }) -- лазейка Зал ↔ Туалет
	wall(44, 15, 60, 15)
	wall(10, -45, 10, -21, { -35 }) -- лазейка Кухня ↔ Зал
	wall(10, -9, 10, 15)
	wall(20, 15, 20, 26)
	wall(20, 34, 20, 45, { 40 }) -- лазейка Бар ↔ Туалет

	block("Ceiling", Vector3.new(122, 1, 92), Vector3.new(0, H + 0.5, 0), C.dark)

	for _, pos in ipairs({ { -45, -25 }, { -45, 20 }, { -10, -30 }, { -10, 0 }, { -5, 30 }, { 40, 30 }, { 25, -30 }, { 45, -30 }, { 35, 0 } }) do
		lamp(pos[1], pos[2])
	end
	for _, pos in ipairs({ { -32, -43 }, { -58, 43 }, { 8, -43 }, { -28, 43 }, { 58, 43 }, { 58, -43 } }) do
		alarmLight(pos[1], pos[2])
	end

	-- Окна с лунным светом
	window(Vector3.new(-45, 7.5, -45), Vector3.new(0, 0, 1))
	window(Vector3.new(-10, 7.5, -45), Vector3.new(0, 0, 1))
	window(Vector3.new(25, 7.5, -45), Vector3.new(0, 0, 1))
	window(Vector3.new(45, 7.5, -45), Vector3.new(0, 0, 1))
	window(Vector3.new(60, 7.5, -35), Vector3.new(-1, 0, 0))
	window(Vector3.new(60, 7.5, 5), Vector3.new(-1, 0, 0))
	window(Vector3.new(60, 7.5, 35), Vector3.new(-1, 0, 0))
	window(Vector3.new(12, 7.5, 45), Vector3.new(0, 0, -1))
	window(Vector3.new(-60, 7.5, -35), Vector3.new(1, 0, 0))

	-- ---------- КУХНЯ ----------
	label("Кухня", Vector3.new(-10, 10, -15), nil, nil, "Kitchen")
	block("Counter", Vector3.new(22, 3.5, 4), Vector3.new(-7, 1.75, -42.5), C.steel, Enum.Material.Metal)
	block("SinkBasin", Vector3.new(3, 0.2, 2.4), Vector3.new(0, 3.55, -42.5), Color3.fromRGB(90, 95, 100), Enum.Material.Metal)
	decor(block("Faucet", Vector3.new(0.2, 1, 0.2), Vector3.new(0, 4.1, -43.8), C.steel, Enum.Material.Metal))
	decor(block("CuttingBoard", Vector3.new(2.5, 0.15, 1.6), Vector3.new(-10, 3.58, -42.5), Color3.fromRGB(200, 160, 110), Enum.Material.Wood))
	for i = 0, 3 do
		decor(cyl("Jar", 0.9, 0.6, Vector3.new(-16 + i * 1, 3.95, -43.5), Color3.fromHSV(i / 4, 0.4, 0.9), Enum.Material.Glass))
	end
	local stove = station("Stove", Vector3.new(6, 3.6, 4.2), Vector3.new(-22, 1.8, -42.4), C.black, {
		TaskName = "Поджечь плиту",
		TaskNameEn = "Light up the stove",
		Points = 10,
		MiniGame = "Timing",
	}, Enum.Material.Metal)
	local fire = Instance.new("Fire")
	fire.Size = 6
	fire.Heat = 10
	fire.Enabled = false
	fire.Parent = stove
	decor(cyl("BigPot", 1.4, 2, Vector3.new(-23.5, 4.3, -42.4), Color3.fromRGB(120, 120, 128), Enum.Material.Metal))
	crate(Vector3.new(-27, 1.25, -42))
	-- кастрюли над столом
	decor(block("PotRack", Vector3.new(10, 0.3, 0.3), Vector3.new(-8, 11, -20), C.black, Enum.Material.Metal))
	for i = 0, 3 do
		local x = -12 + i * 2.6
		decor(block("Chain", Vector3.new(0.1, 1.4, 0.1), Vector3.new(x, 10.2, -20), C.steel, Enum.Material.Metal))
		decor(cyl("HangingPot", 1, 1.4 - i * 0.15, Vector3.new(x, 9.1, -20), Color3.fromRGB(190, 110, 70), Enum.Material.Metal))
	end

	local fridge = station("Fridge", Vector3.new(4, 9, 4), Vector3.new(7, 4.5, -42.5), C.white, {
		TaskName = "Испортить еду в холодильнике",
		TaskNameEn = "Spoil the food in the fridge",
		Points = 10,
		HoldTime = 4,
	})
	smoke(fridge, Color3.fromRGB(120, 200, 80), 0.3, 2)
	decor(block("FridgeHandle", Vector3.new(0.2, 2.5, 0.3), Vector3.new(5.6, 5, -40.4), C.steel, Enum.Material.Metal))

	tableWithLegs(-8, -20, 12, 5, 3.5, C.steel)
	decor(ball("Tomato", 0.6, Vector3.new(-10, 3.8, -20), Color3.fromRGB(220, 40, 40)))
	decor(ball("Tomato", 0.6, Vector3.new(-9.4, 3.8, -19.5), Color3.fromRGB(220, 40, 40)))
	decor(block("Bread", Vector3.new(1.6, 0.6, 0.8), Vector3.new(-5, 3.8, -20), Color3.fromRGB(210, 150, 80)))

	local flour = station("FlourSack", Vector3.new(2.5, 3, 2), Vector3.new(-26, 1.5, 11), Color3.fromRGB(235, 225, 200), {
		TaskName = "Прогрызть мешок муки",
		TaskNameEn = "Chew through the flour sack",
		Points = 10,
		MiniGame = "Mash",
	}, Enum.Material.Fabric)
	smoke(flour, Color3.fromRGB(255, 255, 255), 0.4, 1)
	brokenVisual(flour, Vector3.new(5, 0.1, 4), Vector3.new(-24, 0.25, 9), C.white, Enum.Material.SmoothPlastic)

	local trash = station("Trash", Vector3.new(2.5, 2, 2), CFrame.new(4, 1.25, 11) * VERT, Color3.fromRGB(110, 115, 120), {
		TaskName = "Перевернуть мусорку",
		TaskNameEn = "Knock over the trash can",
		Points = 8,
		HoldTime = 2,
	}, Enum.Material.Metal)
	trash.Shape = Enum.PartType.Cylinder
	smoke(trash, Color3.fromRGB(110, 150, 60), 0.25, 1.5)
	brokenVisual(trash, Vector3.new(4, 0.3, 3.5), Vector3.new(4, 0.35, 7.5), Color3.fromRGB(110, 85, 50), Enum.Material.Ground)
	marker("ChefSpawn", Vector3.new(-8, 1, -5))
	cheese(-15, -30)
	cheese(0, 5)
	cheese(-20, -8)

	-- ---------- КАБИНЕТ ----------
	label("Кабинет", Vector3.new(-45, 10, -25), nil, nil, "Office")
	decor(block("Rug", Vector3.new(12, 0.05, 9), Vector3.new(-45, 0.23, -28), Color3.fromRGB(60, 80, 140), Enum.Material.Fabric))
	tableWithLegs(-45, -41.5, 10, 4, 3)
	local pc = station("Computer", Vector3.new(2.6, 2.2, 2), Vector3.new(-45, 4.1, -42.5), Color3.fromRGB(230, 220, 190), {
		TaskName = "Взломать компьютер",
		TaskNameEn = "Hack the computer",
		Points = 12,
		MiniGame = "Code",
	})
	block("Screen", Vector3.new(2, 1.4, 0.1), Vector3.new(-45, 4.2, -41.47), Color3.fromRGB(30, 60, 90), Enum.Material.Neon, pc)
	brokenVisual(pc, Vector3.new(2, 1.4, 0.1), Vector3.new(-45, 4.2, -41.4), Color3.fromRGB(255, 40, 40))
	decor(block("Keyboard", Vector3.new(2, 0.1, 0.7), Vector3.new(-45, 3.05, -40.6), C.black))
	local deskLamp = decor(ball("DeskLamp", 0.6, Vector3.new(-48.5, 3.6, -42.5), Color3.fromRGB(255, 220, 150), Enum.Material.Neon))
	local dl = Instance.new("PointLight")
	dl.Color = Color3.fromRGB(255, 200, 130)
	dl.Range = 9
	dl.Parent = deskLamp
	chair(-45, -38, 1)
	shelf(-54, -43.5, 8, 2, 9, 3)
	block("Safe", Vector3.new(3, 3, 3), Vector3.new(-36, 1.7, -42.5), Color3.fromRGB(60, 65, 70), Enum.Material.Metal)
	plant(-57, -8)
	sign(Vector3.new(-59.35, 7, -25), Vector3.new(1, 0, 0), 5, 4, "🧀", Color3.fromRGB(60, 90, 140))
	cheese(-40, -20)
	cheese(-55, -15)

	-- ---------- СКЛАД ----------
	label("Склад", Vector3.new(-45, 10, 20), nil, nil, "Storage")
	shelf(-45, 43, 14, 3, 8, 3)
	shelf(-57.5, 30, 3, 12, 8, 3)
	for i = 0, 3 do
		crate(Vector3.new(-50 + i * 3, 3.92, 43), 1.8)
	end
	crate(Vector3.new(-40, 1.5, 5), 3)
	crate(Vector3.new(-37, 1.5, 8), 3)
	crate(Vector3.new(-40, 4.5, 5), 3)
	barrel(-34, 20)
	barrel(-34, 24)
	for i = 0, 2 do
		local sack = decor(block("Sack", Vector3.new(2, 1.4, 2.6), Vector3.new(-56 + i * 2.3, 0.9, 10), Color3.fromRGB(200, 180, 130), Enum.Material.Fabric))
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = sack
		sack.CanCollide = true
	end
	local pipe = decor(block("Pipe", Vector3.new(36, 0.8, 0.8), CFrame.new(-58.8, 11, 20) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(110, 110, 115), Enum.Material.Metal))
	pipe.Shape = Enum.PartType.Cylinder
	cage(-38, 35)
	local fuse = station("FuseBox", Vector3.new(1, 3, 2.5), Vector3.new(-59, 4.5, 15), Color3.fromRGB(90, 95, 100), {
		TaskName = "Перегрызть провода в щитке",
		TaskNameEn = "Chew the fuse box wires",
		Points = 12,
		MiniGame = "Wires",
		Effect = "Lights",
	}, Enum.Material.Metal)
	local sparks = Instance.new("Sparkles")
	sparks.SparkleColor = Color3.fromRGB(255, 230, 120)
	sparks.Enabled = false
	sparks.Parent = fuse
	crate(Vector3.new(-57.5, 1.25, 15))
	-- гнездо крыс
	local nest = block("Nest", Vector3.new(0.6, 7, 7), CFrame.new(-52, 0.4, 2) * VERT, Color3.fromRGB(200, 170, 90), Enum.Material.Fabric)
	nest.Shape = Enum.PartType.Cylinder
	for i = 0, 5 do
		local a = i * math.pi / 3
		decor(block("Straw", Vector3.new(2.5, 0.15, 0.3), CFrame.new(-52 + math.cos(a) * 2.5, 0.8, 2 + math.sin(a) * 2.5) * CFrame.Angles(0, a, 0.2), Color3.fromRGB(220, 190, 100)))
	end
	label("🐀 Гнездо", Vector3.new(-52, 5, 2), nil, nil, "🐀 Nest")
	marker("RatSpawn", Vector3.new(-52, 1, 0))
	marker("RatSpawn", Vector3.new(-50, 1, 3))
	marker("RatSpawn", Vector3.new(-54, 1, 3))
	cheese(-45, 15)
	cheese(-35, -2)
	cheese(-50, 30)

	-- ---------- БАР ----------
	label("Бар", Vector3.new(-5, 10, 30), nil, nil, "Bar")
	block("BarCounter", Vector3.new(20, 4, 3), Vector3.new(-5, 2, 40), C.darkWood, Enum.Material.Wood)
	decor(block("BarTop", Vector3.new(20.4, 0.2, 3.4), Vector3.new(-5, 4.1, 40), Color3.fromRGB(60, 35, 25), Enum.Material.Marble))
	local coffee = station("CoffeeMachine", Vector3.new(2, 2.5, 2), Vector3.new(2, 5.45, 40), C.steel, {
		TaskName = "Сломать кофемашину",
		TaskNameEn = "Break the coffee machine",
		Points = 10,
		MiniGame = "Wires",
	}, Enum.Material.Metal)
	smoke(coffee, Color3.fromRGB(240, 240, 240), 0.25, 4)
	for i = 0, 4 do
		decor(block("Bottle", Vector3.new(0.5, 1.4, 0.5), Vector3.new(-12 + i * 1.3, 4.9, 40), Color3.fromHSV(i / 5, 0.6, 0.7), Enum.Material.Glass))
	end
	-- полки с бутылками у стены
	block("BackShelf", Vector3.new(12, 0.3, 1.2), Vector3.new(-8, 6, 44), C.darkWood, Enum.Material.Wood)
	block("BackShelf", Vector3.new(12, 0.3, 1.2), Vector3.new(-8, 8, 44), C.darkWood, Enum.Material.Wood)
	for row = 0, 1 do
		for i = 0, 7 do
			decor(block("Bottle", Vector3.new(0.45, 1.2, 0.45), Vector3.new(-13 + i * 1.4, 6.75 + row * 2, 44), Color3.fromHSV((i * 0.13 + row * 0.4) % 1, 0.6, 0.8), Enum.Material.Glass))
		end
	end
	sign(Vector3.new(-8, 11, 44.35), Vector3.new(0, 0, -1), 8, 2.4, "🍹 БАР 🍹", Color3.fromRGB(40, 20, 50), Color3.fromRGB(255, 120, 220), "🍹 BAR 🍹")
	for _, x in ipairs({ -12, -7, -2 }) do
		block("Stool", Vector3.new(1.5, 2.6, 1.5), Vector3.new(x, 1.3, 36.5), C.wood, Enum.Material.Wood)
	end
	plant(-27, 18)
	cheese(-20, 25)
	cheese(8, 22)

	-- ---------- ТУАЛЕТ ----------
	label("Туалет", Vector3.new(40, 10, 30), nil, nil, "Restroom")
	block("Stall", Vector3.new(0.4, 7, 6), Vector3.new(35, 3.5, 42), C.white)
	local wc = toilet(28, 42.6)
	wc.Name = "ToiletStation"
	wc:SetAttribute("TaskName", "Засорить унитаз")
	wc:SetAttribute("TaskNameEn", "Clog the toilet")
	wc:SetAttribute("Points", 10)
	wc:SetAttribute("MiniGame", "Timing")
	wc:AddTag("Sabotage")
	brokenVisual(wc, Vector3.new(9, 0.1, 7), Vector3.new(28, 0.25, 39), Color3.fromRGB(80, 140, 220), Enum.Material.Glass, 0.35)
	toilet(42, 42.6)
	local sinks = station("Sinks", Vector3.new(6, 3, 2), Vector3.new(50, 1.5, 16.5), C.white, {
		TaskName = "Открыть все краны",
		TaskNameEn = "Turn on all the taps",
		Points = 8,
		MiniGame = "Mash",
	})
	brokenVisual(sinks, Vector3.new(8, 0.1, 5), Vector3.new(50, 0.25, 20), Color3.fromRGB(80, 140, 220), Enum.Material.Glass, 0.35)
	local mirror = decor(block("Mirror", Vector3.new(6, 3, 0.2), Vector3.new(50, 5.5, 15.65), Color3.fromRGB(200, 220, 230), Enum.Material.Glass))
	mirror.Reflectance = 0.5
	plant(57, 42)
	cheese(45, 30)

	-- ---------- ЗАЛ ----------
	label("Зал", Vector3.new(35, 10, -15), nil, nil, "Dining room")
	for _, cx in ipairs({ 22, 36, 50 }) do
		for _, cz in ipairs({ -35, -20, -5 }) do
			tableWithLegs(cx, cz, 6, 4, 3.2, C.wood)
			decor(block("Tablecloth", Vector3.new(6.4, 0.06, 4.4), Vector3.new(cx, 3.23, cz), C.white, Enum.Material.Fabric))
			decor(cyl("Plate", 0.06, 1.1, Vector3.new(cx - 1.6, 3.29, cz), C.white))
			decor(cyl("Plate", 0.06, 1.1, Vector3.new(cx + 1.6, 3.29, cz), C.white))
			if not (cx == 36 and cz == -20) then
				candle(cx, 3.26, cz)
			end
			chair(cx, cz - 3, -1)
			chair(cx, cz + 3, 1)
		end
	end
	local cake = station("Cake", Vector3.new(2, 1.4, 2), Vector3.new(36, 3.96, -20), Color3.fromRGB(255, 170, 200), {
		TaskName = "Уронить праздничный торт",
		TaskNameEn = "Drop the birthday cake",
		Points = 10,
		MiniGame = "Mash",
	})
	decor(cyl("CakeCream", 0.2, 2.1, Vector3.new(36, 4.7, -20), C.white))
	decor(ball("Cherry", 0.4, Vector3.new(36, 5, -20), Color3.fromRGB(220, 20, 40)))
	brokenVisual(cake, Vector3.new(4, 0.1, 4), Vector3.new(37, 0.25, -16.5), Color3.fromRGB(255, 200, 220), Enum.Material.SmoothPlastic)
	-- камин для уюта
	block("Fireplace", Vector3.new(2, 6, 8), Vector3.new(58.5, 3, -20), Color3.fromRGB(150, 70, 50), Enum.Material.Brick)
	local logs = block("Logs", Vector3.new(1, 0.8, 4), Vector3.new(57.2, 0.6, -20), C.darkWood, Enum.Material.Wood)
	local hearth = Instance.new("Fire")
	hearth.Size = 4
	hearth.Parent = logs
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 140, 60)
	glow.Range = 22
	glow.Brightness = 1.5
	glow.Parent = logs
	glow:AddTag("Flicker")
	sign(Vector3.new(35, 8, -44.35), Vector3.new(0, 0, 1), 6, 4, "🍝", Color3.fromRGB(150, 60, 50))
	sign(Vector3.new(59.35, 8, -10), Vector3.new(-1, 0, 0), 4, 5, "👨‍🍳", Color3.fromRGB(60, 110, 80))
	plant(12, -43)
	plant(58, 13)
	cheese(25, -27)
	cheese(45, -12)
	cheese(15, 8)
	cheese(54, -40)

	-- ---------- КРЫСИНЫЕ НОРКИ (телепорты парами) ----------
	ratHole("1", Vector3.new(-59.5, 1.1, -20), Vector3.new(1, 0, 0)) -- Кабинет
	ratHole("1", Vector3.new(59.5, 1.1, 25), Vector3.new(-1, 0, 0)) -- Туалет
	ratHole("2", Vector3.new(-33, 1.1, 44.5), Vector3.new(0, 0, -1)) -- Склад
	ratHole("2", Vector3.new(45, 1.1, -44.5), Vector3.new(0, 0, 1)) -- Зал
	ratHole("3", Vector3.new(-29.5, 1.1, -38), Vector3.new(1, 0, 0)) -- Кухня
	ratHole("3", Vector3.new(10, 1.1, 44.5), Vector3.new(0, 0, -1)) -- Бар

	-- ---------- Точки патруля повара-робота ----------
	for _, pos in ipairs({ { -45, -25 }, { -45, 20 }, { -10, -15 }, { -5, 28 }, { 40, 28 }, { 35, -12 }, { 25, -40 } }) do
		marker("PatrolPoint", Vector3.new(pos[1], 3, pos[2]))
	end

	-- ---------- ЛОББИ ----------
	block("LobbyFloor", Vector3.new(60, 1, 50), Vector3.new(0, 0, 115), Color3.fromRGB(90, 70, 60), Enum.Material.WoodPlanks)
	for _, side in ipairs({ -1, 1 }) do
		block("Fence", Vector3.new(0.5, 2, 50), Vector3.new(30 * side, 1.5, 115), C.darkWood, Enum.Material.Wood)
		block("Fence", Vector3.new(60, 2, 0.5), Vector3.new(0, 1.5, 115 + 25 * side), C.darkWood, Enum.Material.Wood)
	end
	for _, pos in ipairs({ { -22, 98 }, { 22, 98 }, { -22, 132 }, { 22, 132 } }) do
		block("LampPost", Vector3.new(0.5, 8, 0.5), Vector3.new(pos[1], 4.5, pos[2]), C.black, Enum.Material.Metal)
		local bulb = ball("LampBulb", 1.2, Vector3.new(pos[1], 9, pos[2]), Color3.fromRGB(255, 220, 150), Enum.Material.Neon)
		local pl = Instance.new("PointLight")
		pl.Range = 30
		pl.Brightness = 1.6
		pl.Color = Color3.fromRGB(255, 200, 140)
		pl.Parent = bulb
	end
	-- гигантский сыр
	local bigCheese = block("BigCheese", Vector3.new(8, 5, 8), CFrame.new(0, 3, 128) * CFrame.Angles(0, math.rad(30), 0), C.cheese)
	local wedge = Instance.new("SpecialMesh")
	wedge.MeshType = Enum.MeshType.Wedge
	wedge.Parent = bigCheese
	for _, pos in ipairs({ { -1.5, 2.5, 127 }, { 1.2, 1.8, 129 }, { 0, 3.8, 128.5 } }) do
		decor(ball("CheeseHole", 1.2, Vector3.new(pos[1], pos[2], pos[3]), Color3.fromRGB(220, 170, 40)))
	end
	for _, x in ipairs({ -14, 14 }) do
		block("Bench", Vector3.new(6, 0.5, 2), Vector3.new(x, 2, 105), C.wood, Enum.Material.Wood)
		block("BenchLeg", Vector3.new(0.4, 1.5, 1.8), Vector3.new(x - 2.5, 1, 105), C.darkWood)
		block("BenchLeg", Vector3.new(0.4, 1.5, 1.8), Vector3.new(x + 2.5, 1, 105), C.darkWood)
	end
	label("🐀 КРЫСИНЫЙ ПЕРЕПОЛОХ 👨‍🍳", Vector3.new(0, 12, 100), 520, 120, "🐀 RAT RUCKUS 👨‍🍳")
	label("🎩 Шапки — кнопка внизу экрана", Vector3.new(0, 8.5, 100), 320, 80, "🎩 Hats — button at the bottom")
	for _, x in ipairs({ -6, 0, 6 }) do
		marker("LobbySpawn", Vector3.new(x, 2, 112))
	end

	-- Стандартный SpawnLocation из шаблона стоит внутри ресторана — переносим в лобби
	for _, s in ipairs(workspace:GetDescendants()) do
		if s:IsA("SpawnLocation") then
			s.CFrame = CFrame.new(0, 1, 120)
		end
	end

	-- Ночное освещение и атмосфера
	Lighting.ClockTime = 0
	Lighting.Brightness = 1
	Lighting.Ambient = Color3.fromRGB(40, 34, 48)
	Lighting.OutdoorAmbient = Color3.fromRGB(55, 55, 80)
	Lighting.EnvironmentDiffuseScale = 0.25
	Lighting.EnvironmentSpecularScale = 0.3
	local atm = ensureEffect("Atmosphere", "RatAtmosphere")
	atm.Density = 0.12
	atm.Offset = 0.1
	atm.Color = Color3.fromRGB(80, 70, 100)
	atm.Decay = Color3.fromRGB(40, 30, 60)
	atm.Glare = 0
	atm.Haze = 0.5
	local bloom = ensureEffect("BloomEffect", "RatBloom")
	bloom.Intensity = 0.7
	bloom.Size = 30
	bloom.Threshold = 1.4
	local cc = ensureEffect("ColorCorrectionEffect", "RatColor")
	cc.Brightness = 0.02
	cc.Contrast = 0.12
	cc.Saturation = 0.15
	cc.TintColor = Color3.fromRGB(255, 240, 225)

	map.Parent = workspace
	print("[TestMapBuilder] Ресторан построен! Сделай свою карту в Workspace/Map, чтобы заменить его.")
end

return TestMapBuilder
