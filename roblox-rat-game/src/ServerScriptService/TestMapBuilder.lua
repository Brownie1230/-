-- TestMapBuilder (ModuleScript) — ServerScriptService
-- Строит простой тестовый ресторан, если в Workspace нет папки "Map".
-- Нужен, чтобы сразу нажать Play и поиграть. Потом построй свою красивую карту
-- в папке Workspace/Map — и этот скрипт перестанет срабатывать.
--
-- План (вид сверху):
--   Кабинет | Кухня        | Зал (столики)
--   --------|              |
--   Склад   |--------------+------
--   (клетка,| Бар          | Туалет
--    гнездо)|              |

local Lighting = game:GetService("Lighting")

local TestMapBuilder = {}

local H = 14 -- высота стен
local map

local C = {
	wood = Color3.fromRGB(120, 78, 50),
	darkWood = Color3.fromRGB(80, 50, 35),
	wall = Color3.fromRGB(196, 150, 110),
	tile = Color3.fromRGB(215, 215, 205),
	steel = Color3.fromRGB(170, 172, 178),
	white = Color3.fromRGB(240, 240, 235),
	black = Color3.fromRGB(25, 22, 25),
	cheese = Color3.fromRGB(255, 205, 60),
	dark = Color3.fromRGB(40, 32, 30),
	crate = Color3.fromRGB(165, 120, 75),
}

-- ===== Помощники =====

local function block(name, size, pos, color, material, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = if typeof(pos) == "CFrame" then pos else CFrame.new(pos)
	p.Color = color or C.wall
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or map
	return p
end

local function ghost(p) -- невидимая, не мешает ходить и не закрывает обзор
	p.Transparency = 1
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

local function label(text, pos, width)
	local p = ghost(block("Label", Vector3.new(1, 1, 1), pos, C.white))
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(width or 220, 50)
	bb.MaxDistance = 70
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
	t.Parent = bb
	return p
end

local function wall(x1, z1, x2, z2)
	local size = if x1 == x2 then Vector3.new(1, H, math.abs(z2 - z1)) else Vector3.new(math.abs(x2 - x1), H, 1)
	return block("Wall", size, Vector3.new((x1 + x2) / 2, H / 2, (z1 + z2) / 2), C.wall, Enum.Material.Plaster)
end

local function floor(x1, z1, x2, z2, color, material)
	return block("Floor", Vector3.new(x2 - x1, 0.4, z2 - z1), Vector3.new((x1 + x2) / 2, 0, (z1 + z2) / 2), color, material)
end

local function tableWithLegs(cx, cz, w, d, h, color)
	local top = block("TableTop", Vector3.new(w, 0.4, d), Vector3.new(cx, h - 0.2, cz), color or C.wood, Enum.Material.Wood)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
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
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
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
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			block("ShelfPost", Vector3.new(0.3, h, 0.3), Vector3.new(cx + sx * (w / 2 - 0.15), h / 2, cz + sz * (d / 2 - 0.15)), C.darkWood)
		end
	end
end

local function crate(pos, s)
	s = s or 2.5
	return block("Crate", Vector3.new(s, s, s), pos, C.crate, Enum.Material.Wood)
end

local function lamp(x, z)
	local p = block("Lamp", Vector3.new(2.5, 0.5, 2.5), Vector3.new(x, H - 0.25, z), Color3.fromRGB(255, 210, 140), Enum.Material.Neon)
	local l = Instance.new("PointLight")
	l.Range = 32
	l.Brightness = 1.4
	l.Color = Color3.fromRGB(255, 190, 120)
	l.Shadows = true
	l.Parent = p
	p:AddTag("RoomLight")
	return p
end

local function station(name, size, pos, color, attrs, material)
	local p = block(name, size, pos, color, material)
	for k, v in attrs do
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

local function ratHole(pair, pos, intoRoom)
	local p = block("RatHole", Vector3.new(2.2, 1.8, 1), CFrame.lookAt(pos, pos + intoRoom), C.black)
	p.CanCollide = false
	p.CanQuery = false
	p:SetAttribute("Pair", pair)
	p:AddTag("RatHole")
	return p
end

local function cheese(x, z)
	local p = block("Cheese", Vector3.new(0.9, 0.6, 0.9), CFrame.new(x, 0.55, z) * CFrame.Angles(0, math.rad(math.random(0, 90)), 0), C.cheese)
	p.CanCollide = false
	p.CanQuery = false
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
		for _, pos in {
			Vector3.new(x + o, hgt / 2 + 0.6, z - size / 2),
			Vector3.new(x + o, hgt / 2 + 0.6, z + size / 2),
			Vector3.new(x - size / 2, hgt / 2 + 0.6, z + o),
			Vector3.new(x + size / 2, hgt / 2 + 0.6, z + o),
		} do
			block("CageBar", Vector3.new(0.25, hgt, 0.25), pos, C.steel, Enum.Material.Metal)
		end
	end
	block("CageRoof", Vector3.new(size + 0.5, 0.3, size + 0.5), Vector3.new(x, hgt + 0.75, z), C.steel, Enum.Material.DiamondPlate)
	label("🪤 Клетка", Vector3.new(x, hgt + 2.5, z))
end

local function toilet(x, z)
	local bowl = block("Toilet", Vector3.new(2.2, 1.8, 2.8), Vector3.new(x, 0.9, z), C.white)
	block("ToiletTank", Vector3.new(2.4, 2.4, 0.8), Vector3.new(x, 2.6, z + 1.5), C.white)
	return bowl
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
	-- Внутренние стены (с проёмами-дверями по 8 стадов)
	wall(-30, -45, -30, -34)
	wall(-30, -26, -30, 1)
	wall(-30, 9, -30, 26)
	wall(-30, 34, -30, 45)
	wall(-60, -5, -49, -5)
	wall(-41, -5, -30, -5)
	wall(-30, 15, -14, 15)
	wall(-6, 15, 11, 15)
	wall(19, 15, 36, 15)
	wall(44, 15, 60, 15)
	wall(10, -45, 10, -21)
	wall(10, -9, 10, 15)
	wall(20, 15, 20, 26)
	wall(20, 34, 20, 45)

	block("Ceiling", Vector3.new(122, 1, 92), Vector3.new(0, H + 0.5, 0), C.dark)

	for _, pos in { { -45, -25 }, { -45, 20 }, { -10, -30 }, { -10, 0 }, { -5, 30 }, { 40, 30 }, { 35, -30 }, { 35, 0 } } do
		lamp(pos[1], pos[2])
	end

	-- ---------- КУХНЯ ----------
	label("Кухня", Vector3.new(-10, 10, -15))
	block("Counter", Vector3.new(22, 3.5, 4), Vector3.new(-7, 1.75, -42.5), C.steel, Enum.Material.Metal)
	local stove = station("Stove", Vector3.new(6, 3.6, 4.2), Vector3.new(-22, 1.8, -42.4), C.black, {
		TaskName = "Поджечь плиту",
		Points = 12,
	}, Enum.Material.Metal)
	local fire = Instance.new("Fire")
	fire.Size = 6
	fire.Heat = 10
	fire.Enabled = false
	fire.Parent = stove
	crate(Vector3.new(-27, 1.25, -42))

	local fridge = station("Fridge", Vector3.new(4, 9, 4), Vector3.new(7, 4.5, -42.5), C.white, {
		TaskName = "Испортить еду в холодильнике",
		Points = 12,
		HoldTime = 4,
	})
	local stink = Instance.new("Smoke")
	stink.Color = Color3.fromRGB(120, 200, 80)
	stink.Opacity = 0.3
	stink.RiseVelocity = 2
	stink.Enabled = false
	stink.Parent = fridge

	tableWithLegs(-8, -20, 12, 5, 3.5, C.steel)
	local flour = station("FlourSack", Vector3.new(2.5, 3, 2), Vector3.new(-26, 1.5, 11), Color3.fromRGB(235, 225, 200), {
		TaskName = "Прогрызть мешок муки",
		Points = 10,
		HoldTime = 2,
	}, Enum.Material.Fabric)
	local dust = Instance.new("Smoke")
	dust.Color = Color3.fromRGB(255, 255, 255)
	dust.Opacity = 0.4
	dust.RiseVelocity = 1
	dust.Enabled = false
	dust.Parent = flour
	marker("ChefSpawn", Vector3.new(-8, 1, -5))
	cheese(-15, -30)
	cheese(0, 5)

	-- ---------- КАБИНЕТ ----------
	label("Кабинет", Vector3.new(-45, 10, -25))
	tableWithLegs(-45, -41.5, 10, 4, 3)
	local pc = station("Computer", Vector3.new(2.6, 2.2, 2), Vector3.new(-45, 4.1, -42.5), Color3.fromRGB(230, 220, 190), {
		TaskName = "Взломать компьютер",
		Points = 15,
		HoldTime = 5,
	})
	block("Screen", Vector3.new(2, 1.4, 0.1), Vector3.new(-45, 4.2, -41.47), C.black, Enum.Material.Glass, pc)
	brokenVisual(pc, Vector3.new(2, 1.4, 0.1), Vector3.new(-45, 4.2, -41.4), Color3.fromRGB(255, 40, 40))
	chair(-45, -38, 1)
	shelf(-54, -43.5, 8, 2, 9, 3)
	cheese(-40, -20)

	-- ---------- СКЛАД ----------
	label("Склад", Vector3.new(-45, 10, 20))
	shelf(-45, 43, 14, 3, 8, 3)
	shelf(-57.5, 30, 3, 12, 8, 3)
	crate(Vector3.new(-40, 1.5, 5), 3)
	crate(Vector3.new(-37, 1.5, 8), 3)
	crate(Vector3.new(-40, 4.5, 5), 3)
	cage(-38, 35)
	local fuse = station("FuseBox", Vector3.new(1, 3, 2.5), Vector3.new(-59, 4.5, 15), Color3.fromRGB(90, 95, 100), {
		TaskName = "Перегрызть провода в щитке",
		Points = 15,
		HoldTime = 4,
		Effect = "Lights",
	}, Enum.Material.Metal)
	local sparks = Instance.new("Sparkles")
	sparks.SparkleColor = Color3.fromRGB(255, 230, 120)
	sparks.Enabled = false
	sparks.Parent = fuse
	crate(Vector3.new(-57.5, 1.25, 15))
	-- гнездо крыс
	local nest = block("Nest", Vector3.new(0.6, 7, 7), CFrame.new(-52, 0.4, 2) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(200, 170, 90), Enum.Material.Fabric)
	nest.Shape = Enum.PartType.Cylinder
	label("🐀 Гнездо", Vector3.new(-52, 5, 2))
	marker("RatSpawn", Vector3.new(-52, 1, 0))
	marker("RatSpawn", Vector3.new(-50, 1, 3))
	marker("RatSpawn", Vector3.new(-54, 1, 3))
	cheese(-45, 15)
	cheese(-35, -2)

	-- ---------- БАР ----------
	label("Бар", Vector3.new(-5, 10, 30))
	block("BarCounter", Vector3.new(20, 4, 3), Vector3.new(-5, 2, 40), C.darkWood, Enum.Material.Wood)
	local coffee = station("CoffeeMachine", Vector3.new(2, 2.5, 2), Vector3.new(2, 5.25, 40), C.steel, {
		TaskName = "Сломать кофемашину",
		Points = 12,
	}, Enum.Material.Metal)
	local steam = Instance.new("Smoke")
	steam.Color = Color3.fromRGB(240, 240, 240)
	steam.Opacity = 0.25
	steam.RiseVelocity = 4
	steam.Enabled = false
	steam.Parent = coffee
	for i = 0, 4 do
		block("Bottle", Vector3.new(0.5, 1.4, 0.5), Vector3.new(-12 + i * 1.3, 4.7, 40), Color3.fromHSV(i / 5, 0.6, 0.7), Enum.Material.Glass)
	end
	for _, x in { -12, -7, -2 } do
		block("Stool", Vector3.new(1.5, 2.6, 1.5), Vector3.new(x, 1.3, 36.5), C.wood, Enum.Material.Wood)
	end
	cheese(-20, 25)

	-- ---------- ТУАЛЕТ ----------
	label("Туалет", Vector3.new(40, 10, 30))
	block("Stall", Vector3.new(0.4, 7, 6), Vector3.new(35, 3.5, 42), C.white)
	local wc = toilet(28, 42.6)
	wc.Name = "ToiletStation"
	wc:SetAttribute("TaskName", "Засорить унитаз")
	wc:SetAttribute("Points", 12)
	wc:AddTag("Sabotage")
	brokenVisual(wc, Vector3.new(9, 0.1, 7), Vector3.new(28, 0.25, 39), Color3.fromRGB(80, 140, 220), Enum.Material.Glass, 0.35)
	toilet(42, 42.6)
	block("Sinks", Vector3.new(6, 3, 2), Vector3.new(50, 1.5, 16.5), C.white)
	cheese(45, 30)

	-- ---------- ЗАЛ ----------
	label("Зал", Vector3.new(35, 10, -15))
	for _, cx in { 22, 36, 50 } do
		for _, cz in { -35, -20, -5 } do
			tableWithLegs(cx, cz, 6, 4, 3.2, C.wood)
			chair(cx, cz - 3, -1)
			chair(cx, cz + 3, 1)
		end
	end
	local cake = station("Cake", Vector3.new(2, 1.4, 2), Vector3.new(36, 3.9, -20), Color3.fromRGB(255, 170, 200), {
		TaskName = "Уронить праздничный торт",
		Points = 12,
		HoldTime = 2,
	})
	brokenVisual(cake, Vector3.new(4, 0.1, 4), Vector3.new(37, 0.25, -16.5), C.white, Enum.Material.SmoothPlastic)
	-- камин для уюта
	block("Fireplace", Vector3.new(2, 6, 8), Vector3.new(58.5, 3, -20), Color3.fromRGB(150, 70, 50), Enum.Material.Brick)
	local logs = block("Logs", Vector3.new(1, 0.8, 4), Vector3.new(57.2, 0.6, -20), C.darkWood, Enum.Material.Wood)
	local hearth = Instance.new("Fire")
	hearth.Size = 4
	hearth.Parent = logs
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 140, 60)
	glow.Range = 20
	glow.Parent = logs
	cheese(25, -27)
	cheese(45, -12)
	cheese(15, 8)

	-- ---------- КРЫСИНЫЕ НОРКИ (телепорты парами) ----------
	ratHole("1", Vector3.new(-59.5, 1.1, -20), Vector3.new(1, 0, 0)) -- Кабинет
	ratHole("1", Vector3.new(59.5, 1.1, 25), Vector3.new(-1, 0, 0)) -- Туалет
	ratHole("2", Vector3.new(-33, 1.1, 44.5), Vector3.new(0, 0, -1)) -- Склад
	ratHole("2", Vector3.new(45, 1.1, -44.5), Vector3.new(0, 0, 1)) -- Зал
	ratHole("3", Vector3.new(-29.5, 1.1, -38), Vector3.new(1, 0, 0)) -- Кухня
	ratHole("3", Vector3.new(10, 1.1, 44.5), Vector3.new(0, 0, -1)) -- Бар

	-- ---------- Точки патруля повара-робота ----------
	for _, pos in { { -45, -25 }, { -45, 20 }, { -10, -15 }, { -5, 28 }, { 40, 28 }, { 35, -12 }, { 25, -40 } } do
		marker("PatrolPoint", Vector3.new(pos[1], 3, pos[2]))
	end

	-- ---------- ЛОББИ ----------
	block("LobbyFloor", Vector3.new(50, 1, 40), Vector3.new(0, 0, 110), Color3.fromRGB(90, 70, 60), Enum.Material.WoodPlanks)
	local lobbyLight = ghost(block("LobbyLight", Vector3.new(1, 1, 1), Vector3.new(0, 12, 110), C.white))
	local ll = Instance.new("PointLight")
	ll.Range = 45
	ll.Brightness = 2
	ll.Parent = lobbyLight
	label("🐀 КРЫСИНЫЙ ПЕРЕПОЛОХ 👨‍🍳", Vector3.new(0, 10, 95), 500)
	for _, x in { -6, 0, 6 } do
		marker("LobbySpawn", Vector3.new(x, 2, 112))
	end

	-- Стандартный SpawnLocation из шаблона стоит внутри ресторана — переносим в лобби
	for _, s in workspace:GetDescendants() do
		if s:IsA("SpawnLocation") then
			s.CFrame = CFrame.new(0, 1, 122)
		end
	end

	-- Ночное освещение
	Lighting.ClockTime = 0
	Lighting.Brightness = 1
	Lighting.Ambient = Color3.fromRGB(35, 30, 40)
	Lighting.OutdoorAmbient = Color3.fromRGB(50, 50, 70)
	Lighting.EnvironmentDiffuseScale = 0.2
	Lighting.EnvironmentSpecularScale = 0.2

	map.Parent = workspace
	print("[TestMapBuilder] Тестовый ресторан построен! Сделай свою карту в Workspace/Map, чтобы заменить его.")
end

return TestMapBuilder
