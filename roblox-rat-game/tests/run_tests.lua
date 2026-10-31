-- Автотест: прогоняет игру в симуляторе Roblox (mock_roblox.lua).
-- Запуск: python3 tests/run.py

local M = require("mock_roblox")
local DS_FAIL = os.getenv("RAT_DS_FAIL") == "1"
M.dataStoreFail = DS_FAIL
local ROOT = (os.getenv("RAT_ROOT") or ".") .. "/src/"

local failures = {}
local passes = 0
local function check(cond, msg)
	if cond then
		passes = passes + 1
	else
		table.insert(failures, msg)
		print("FAIL: " .. msg)
	end
end

------------------------------------------------------------------------
-- Синтаксис всех файлов
------------------------------------------------------------------------
local files = {
	"ReplicatedStorage/Config.lua",
	"ReplicatedStorage/Locale.lua",
	"ServerScriptService/GameManager.server.lua",
	"ServerScriptService/RatBuilder.lua",
	"ServerScriptService/DataService.lua",
	"ServerScriptService/SabotageService.lua",
	"ServerScriptService/ChefService.lua",
	"ServerScriptService/ChefAI.lua",
	"ServerScriptService/TestMapBuilder.lua",
	"StarterPlayerScripts/RatHUD.client.lua",
	"StarterPlayerScripts/Effects.client.lua",
	"StarterPlayerScripts/MiniGames.client.lua",
}
for _, f in ipairs(files) do
	local ok, err = M.syntaxCheck(ROOT .. f)
	check(ok, "syntax " .. f .. ": " .. tostring(err))
end
if #failures > 0 then
	return failures
end

------------------------------------------------------------------------
-- Собираем "место"
------------------------------------------------------------------------
M.addScript("ModuleScript", "Config", M.ReplicatedStorage, ROOT .. "ReplicatedStorage/Config.lua")
M.addScript("ModuleScript", "Locale", M.ReplicatedStorage, ROOT .. "ReplicatedStorage/Locale.lua")
local modules = {}
for _, n in ipairs({ "RatBuilder", "DataService", "SabotageService", "ChefService", "ChefAI", "TestMapBuilder" }) do
	modules[n] = M.addScript("ModuleScript", n, M.ServerScriptService, ROOT .. "ServerScriptService/" .. n .. ".lua")
end
local gm = M.addScript("Script", "GameManager", M.ServerScriptService, ROOT .. "ServerScriptService/GameManager.server.lua")
local clientScripts = {}
for _, n in ipairs({ "RatHUD", "Effects", "MiniGames" }) do
	table.insert(clientScripts, M.addScript("LocalScript", n, M.StarterPlayerScripts, ROOT .. "StarterPlayerScripts/" .. n .. ".client.lua"))
end

local Vector3, CFrame, Enum = M.Vector3, M.CFrame, M.Enum
local CS = M.CollectionService
local RS = M.ReplicatedStorage
local getSignal = M.getSignal

local function join(name, localeId)
	local p = M.addPlayer(name, localeId)
	for _, s in ipairs(clientScripts) do
		M.runScript(s, p)
	end
	return p
end

local function advance(t)
	M.advance(t)
end

local function waitUntil(fn, timeout, dt)
	local t = 0
	dt = dt or 0.05
	while t < timeout do
		if fn() then
			return true
		end
		M.step(dt)
		t = t + dt
	end
	return fn()
end

local function descendants(inst, pred)
	local out = {}
	for _, d in ipairs(inst:GetDescendants()) do
		if pred(d) then
			table.insert(out, d)
		end
	end
	return out
end

local function station(name)
	for _, s in ipairs(CS:GetTagged("Sabotage")) do
		if s.Name == name then
			return s
		end
	end
	error("no station " .. name)
end

local function toolOf(container, kind)
	for _, t in ipairs(container:GetChildren()) do
		if t:IsA("Tool") and t:GetAttribute("ToolKind") == kind then
			return t
		end
	end
	return nil
end

local function rootOf(p)
	return p.Character and p.Character:FindFirstChild("HumanoidRootPart")
end

local function moveNear(p, part, dist)
	local pos = part.Position + Vector3.new(0, 0, dist or 3)
	p.Character:PivotTo(CFrame.new(pos.X, 1.2, pos.Z))
end

local function prompt(part, name)
	return part:FindFirstChild(name)
end

local function trigger(part, promptName, player)
	local pr = prompt(part, promptName)
	check(pr ~= nil, "prompt " .. promptName .. " on " .. part.Name)
	if pr then
		getSignal(pr, "Triggered"):Fire(player)
	end
end

local function click(button)
	getSignal(button, "Activated"):Fire()
end

local function miniFrame(p)
	local g = p.PlayerGui:FindFirstChild("MiniGames")
	if not g then
		return nil
	end
	for _, c in ipairs(g:GetChildren()) do
		if c:IsA("Frame") then
			return c
		end
	end
	return nil
end

local function buttonsIn(frame)
	return descendants(frame, function(d)
		return d:IsA("TextButton")
	end)
end

local function sameColor(a, b)
	return math.abs(a.R - b.R) < 1e-6 and math.abs(a.G - b.G) < 1e-6 and math.abs(a.B - b.B) < 1e-6
end

-- Пройти мини-игру (или подержать E) за игрока
local function doStation(p, st)
	moveNear(p, st, 3)
	local kind = st:GetAttribute("MiniGame")
	trigger(st, "SabotagePrompt", p)
	if not kind then
		M.step(0.1)
		return
	end
	M.step(0.1)
	local frame = miniFrame(p)
	check(frame ~= nil, "minigame frame opened for " .. st.Name)
	if not frame then
		return
	end
	if kind == "Code" then
		local code = nil
		local codeLabel = frame:FindFirstChild("CodeText", true)
		if codeLabel and codeLabel.Text:match("^%d%d%d%d$") then
			code = codeLabel.Text
		end
		check(code ~= nil, "code note visible")
		local buttons = buttonsIn(frame)
		-- сначала неверный код
		for _, ch in ipairs({ "0", "0", "0", "0" }) do
			if code == "0000" then
				break
			end
			for _, b in ipairs(buttons) do
				if b.Text == ch then
					click(b)
					break
				end
			end
		end
		M.step(0.5)
		for ch in code:gmatch("%d") do
			for _, b in ipairs(buttons) do
				if b.Text == ch then
					click(b)
					break
				end
			end
			M.step(0.1)
		end
	elseif kind == "Wires" then
		local left, right = {}, {}
		for _, b in ipairs(buttonsIn(frame)) do
			if b.Text == "" then
				if b.Position.X.Offset == 20 then
					table.insert(left, b)
				else
					table.insert(right, b)
				end
			end
		end
		check(#left == 4 and #right == 4, "wires: 4+4 buttons")
		-- ошибка
		click(left[1])
		for _, r in ipairs(right) do
			if not sameColor(r.BackgroundColor3, left[1].BackgroundColor3) then
				click(r)
				break
			end
		end
		M.step(0.2)
		for _, l in ipairs(left) do
			click(l)
			for _, r in ipairs(right) do
				if sameColor(r.BackgroundColor3, l.BackgroundColor3) then
					click(r)
					break
				end
			end
			M.step(0.2)
		end
		local wires = descendants(frame, function(d)
			return d:IsA("Frame") and d.Size.Y.Offset == 8
		end)
		check(#wires == 4 or RS:GetAttribute("State") ~= "Playing", "wires drawn: " .. #wires .. " station " .. st.Name .. " frameAlive " .. tostring(miniFrame(p) == frame) .. " broken " .. tostring(st:GetAttribute("Broken")) .. " state " .. tostring(RS:GetAttribute("State")))
	elseif kind == "Mash" then
		local gnaw = frame:FindFirstChild("GnawButton", true)
		check(gnaw ~= nil, "gnaw button")
		for _ = 1, 25 do
			if miniFrame(p) ~= frame then
				break
			end
			click(gnaw)
			M.step(0.05)
		end
	elseif kind == "Timing" then
		local stop = frame:FindFirstChild("StopButton", true)
		local zone, needle
		for _, f in ipairs(descendants(frame, function(d)
			return d:IsA("Frame")
		end)) do
			if f.Size.X.Offset == 80 and f.Size.Y.Offset == 40 then
				zone = f
			elseif f.Size.X.Offset == 8 and f.Size.Y.Offset == 56 then
				needle = f
			end
		end
		check(stop and zone and needle, "timing parts")
		local presses = 0
		local t = 0
		while miniFrame(p) == frame and t < 15 do
			local nx = needle.Position.X.Offset
			local zx = zone.Position.X.Offset
			if nx > zx + 8 and nx < zx + 72 then
				click(stop)
				presses = presses + 1
			end
			M.step(1 / 60)
			t = t + 1 / 60
		end
		check(presses >= 3, "timing presses " .. presses)
	end
	M.step(2)
end

local function guiText(p, pred)
	for _, d in ipairs(p.PlayerGui:GetDescendants()) do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and pred(d) then
			return d
		end
	end
	return nil
end

------------------------------------------------------------------------
-- 1. Запуск сервера
------------------------------------------------------------------------
M.runScript(gm, nil)
advance(1)
check(M.workspace:FindFirstChild("Map") ~= nil, "map built")
check(RS:FindFirstChild("Remotes") ~= nil, "remotes created")
check(#CS:GetTagged("Sabotage") == 10, "10 stations, got " .. #CS:GetTagged("Sabotage"))
check(#CS:GetTagged("Cage") == 1, "1 cage")
check(#CS:GetTagged("RatSpawn") >= 1 and #CS:GetTagged("ChefSpawn") == 1 and #CS:GetTagged("LobbySpawn") >= 1, "spawns")
check(#CS:GetTagged("AlarmLight") >= 1, "alarm lights")
check(#CS:GetTagged("Flicker") >= 1, "flicker lights")
local partCount = #descendants(M.workspace.Map, function(d)
	return d:IsA("BasePart")
end)
print("Map parts: " .. partCount)
check(partCount < 3500, "map part count reasonable")
for _, st in ipairs(CS:GetTagged("Sabotage")) do
	check(st:FindFirstChild("SabotagePrompt") and st:FindFirstChild("RepairPrompt"), "prompts on " .. st.Name)
end

------------------------------------------------------------------------
-- 2. Первый игрок, лобби, магазин
------------------------------------------------------------------------
local alice = join("Alice", "ru-ru")
advance(1)
check(alice:GetAttribute("Role") == "Lobby", "alice in lobby")
check(alice:GetAttribute("Coins") == 0, "alice coins 0")
check(alice:FindFirstChild("leaderstats") ~= nil, "leaderstats")
check(alice.Character ~= nil and alice.Character:FindFirstChild("Hat") ~= nil, "lobby hat on human")
check(guiText(alice, function(d)
	return d.Text:find("Шапки") ~= nil
end) ~= nil, "shop button exists")

local shopEvent = RS.Remotes.ShopAction
M.runAs(alice, function()
	shopEvent:FireServer("buy", "bow")
end)
advance(0.2)
check(not (alice:GetAttribute("OwnedHats") or ""):find("bow"), "cannot buy bow without coins")
M.runAs(alice, function()
	shopEvent:FireServer("equip", "none")
end)
advance(0.2)
check(alice:GetAttribute("Hat") == "none", "equip none")
check(alice.Character:FindFirstChild("Hat") == nil, "hat removed")
M.runAs(alice, function()
	shopEvent:FireServer("equip", "cap")
	shopEvent:FireServer("buy", 123) -- мусор от клиента
	shopEvent:FireServer(nil, nil)
end)
advance(0.2)
check(alice:GetAttribute("Hat") == "cap", "equip cap")

-- переключение языка
local langBtn = guiText(alice, function(d)
	return d:IsA("TextButton") and d.Text == "🌐 English"
end)
check(langBtn ~= nil, "language button")
click(langBtn)
advance(0.3)
check(alice:GetAttribute("Lang") == "en", "language switched to en")
check(guiText(alice, function(d)
	return d:IsA("TextButton") and d.Text == "🎩 Hats"
end) ~= nil, "UI switched to english")
click(guiText(alice, function(d)
	return d:IsA("TextButton") and d.Text == "🌐 Русский"
end))
advance(0.3)
check(alice:GetAttribute("Lang") == "ru", "language back to ru")

-- открыть магазин в интерфейсе
local shopBtn = guiText(alice, function(d)
	return d:IsA("TextButton") and d.Text == "🎩 Шапки"
end)
click(shopBtn)
advance(1)

------------------------------------------------------------------------
-- 3. Раунд 1: соло против повара-робота
------------------------------------------------------------------------
M.raycastHook = function(origin, direction)
	-- робот "не видит" крысу (стена), а пол для мышеловки находится
	return { Position = origin + direction * 0.3, Instance = M.workspace.Baseplate, Normal = Vector3.new(0, 1, 0) }
end
check(waitUntil(function()
	return RS:GetAttribute("State") == "Intro"
end, 25), "intro started")
advance(0.5)
check(alice:GetAttribute("Role") == "Rat", "alice is rat")
check(alice:GetAttribute("BaseSpeed") == 0, "frozen during intro")
check(alice.Character and alice.Character:HasTag("Rat"), "rat model tagged")
check(alice.Character:FindFirstChild("Hat") ~= nil, "rat wears hat")
check(guiText(alice, function(d)
	return d.Text == "🐀 ТЫ — КРЫСА" and d.Visible
end) ~= nil, "role card shown")
check(waitUntil(function()
	return RS:GetAttribute("State") == "Playing"
end, 6), "playing")
advance(0.5)
check(alice:GetAttribute("BaseSpeed") == 14, "rat speed 14 got " .. tostring(alice:GetAttribute("BaseSpeed")))
check(M.workspace:FindFirstChild("ChefNPC") ~= nil, "AI chef spawned")
local npc = M.workspace:FindFirstChild("ChefNPC")
check(npc and toolOf(npc, "Net") ~= nil, "AI holds net")
check(npc and npc:FindFirstChild("ChefHat") ~= nil, "AI chef hat")
-- клиент выставил скорость
local hum = alice.Character:FindFirstChildOfClass("Humanoid")
advance(0.2)
check(hum.WalkSpeed == 14, "client walk speed 14")

-- обычная поломка (держать E)
local coins0 = alice:GetAttribute("Coins")
doStation(alice, station("Fridge"))
check(station("Fridge"):GetAttribute("Broken") == true, "fridge broken")
check(alice:GetAttribute("Coins") == coins0 + 5, "coins for sabotage")
check(RS:GetAttribute("Chaos") >= 10, "chaos >= 10")

-- мини-игры
for _, name in ipairs({ "Computer", "FuseBox", "FlourSack", "Stove" }) do
	doStation(alice, station(name))
	check(station(name):GetAttribute("Broken") == true, name .. " broken via minigame")
	check(miniFrame(alice) == nil, "minigame closed after " .. name)
	check(alice:GetAttribute("LocalFreeze") == false, "unfrozen after " .. name)
end
-- свет погас
advance(1)
local lightsOff = true
for _, lamp in ipairs(CS:GetTagged("RoomLight")) do
	local l = lamp:FindFirstChildOfClass("PointLight")
	if l and l.Enabled then
		lightsOff = false
	end
end
check(lightsOff, "lights off after fuse box")

-- читерство: "done" без мини-игры не считается
local wc = station("ToiletStation")
M.runAs(alice, function()
	RS.Remotes.MiniGame:FireServer("done", wc, nil)
end)
advance(0.2)
check(wc:GetAttribute("Broken") == false, "cannot cheat minigame")
-- слишком быстро
moveNear(alice, wc, 3)
trigger(wc, "SabotagePrompt", alice)
M.runAs(alice, function()
	RS.Remotes.MiniGame:FireServer("done", wc, nil)
end)
advance(0.2)
check(wc:GetAttribute("Broken") == false, "too fast minigame rejected")
advance(1)
-- мини-игра закрывается, если отойти
local f = miniFrame(alice)
alice.Character:PivotTo(CFrame.new(0, 1.2, 100))
advance(0.3)
check(miniFrame(alice) == nil, "minigame closes when walking away")
check(alice:GetAttribute("LocalFreeze") == false, "unfrozen after walking away")

-- робот чинит (видит поломки)
advance(20)
check(RS:GetAttribute("State") == "Playing", "still playing before catch, chaos=" .. tostring(RS:GetAttribute("Chaos")))
local repaired = 0
for _, st in ipairs(CS:GetTagged("Sabotage")) do
	if st.Name ~= "ToiletStation" and st:GetAttribute("Broken") == false then
		repaired = repaired + 1
	end
end
print("AI repaired stations: " .. repaired)
check(repaired >= 1, "AI repaired something")

-- задания видны в интерфейсе
check(guiText(alice, function(d)
	return d.Text:find("Напакости") ~= nil
end) ~= nil, "tasks list")

-- поимка: робот видит крысу
M.raycastHook = nil
local npcRoot = M.workspace.ChefNPC.HumanoidRootPart
alice.Character:PivotTo(CFrame.new(npcRoot.Position + Vector3.new(4, 0, 0)))
check(waitUntil(function()
	return alice:GetAttribute("Caught") == true
end, 5), "AI catches rat")
check(alice:GetAttribute("BaseSpeed") == 0, "caught speed 0")
check(waitUntil(function()
	return RS:GetAttribute("State") == "Ended"
end, 3), "round ends when all caught")
advance(0.5)
check(RS:GetAttribute("Winner") == "Chef", "chef won")
check(guiText(alice, function(d)
	return d.Text:find("Поражение") ~= nil
end) ~= nil, "results panel shows defeat")
check(M.workspace:FindFirstChild("ChefNPC") == nil, "AI removed after round")
print("Alice coins after round 1: " .. tostring(alice:GetAttribute("Coins")))
check(waitUntil(function()
	return RS:GetAttribute("State") == "Lobby"
end, 12), "back to lobby")
advance(1)
check(alice:GetAttribute("Role") == "Lobby", "alice lobby again")
check(station("Fridge"):GetAttribute("Broken") == false, "stations reset")

------------------------------------------------------------------------
-- 4. Раунд 2: трое, повар — игрок
------------------------------------------------------------------------
local bob = join("Bob", "en-us")
local cara = join("Cara", "ru-ru")
advance(1)
M.runAs(bob, function()
	RS.Remotes.ChefVolunteer:FireServer(true)
end)
check(waitUntil(function()
	return RS:GetAttribute("State") == "Playing"
end, 30), "round 2 playing")
advance(0.5)
check(bob:GetAttribute("Role") == "Chef", "bob is chef (volunteer)")
check(M.workspace:FindFirstChild("ChefNPC") == nil, "no AI when human chef")
check(toolOf(bob.Backpack, "Net") ~= nil and toolOf(bob.Backpack, "Trap") ~= nil, "chef tools")
check(toolOf(bob.Backpack, "Net").Name == "Net", "english tool name for bob")
check(guiText(bob, function(d)
	return d.Text == "👨‍🍳 You're the chef"
end) ~= nil, "bob UI in english")
check(guiText(alice, function(d)
	return d.Text == "🐀 Ты — крыса"
end) ~= nil, "alice UI in russian")
check(bob:GetAttribute("BaseSpeed") == 17, "chef speed")
check(bob.Character:FindFirstChild("ChefHat") ~= nil, "chef hat")

-- Боб ловит Кару сачком (Алису отводим подальше, они рядом в гнезде)
alice.Character:PivotTo(CFrame.new(-10, 1.2, -30))
local caraPos = rootOf(cara).Position
bob.Character:PivotTo(CFrame.lookAt(caraPos + Vector3.new(0, 0, 4), caraPos))
local bobCoins = bob:GetAttribute("Coins")
getSignal(toolOf(bob.Backpack, "Net"), "Activated"):Fire()
advance(0.2)
check(cara:GetAttribute("Caught") == true, "bob caught cara")
check(bob:GetAttribute("Coins") == bobCoins + 6, "chef coins for catch")
check(RS:GetAttribute("State") == "Playing", "round continues (alice free)")

-- Алиса открывает клетку
local cageFloor = CS:GetTagged("Cage")[1]
moveNear(alice, cageFloor, 5)
local aliceCoins = alice:GetAttribute("Coins")
trigger(cageFloor, "FreePrompt", alice)
advance(0.2)
check(cara:GetAttribute("Caught") == false, "cara freed")
check(cara:GetAttribute("BaseSpeed") == 14, "cara speed restored")
check(alice:GetAttribute("Coins") == aliceCoins + 8, "rescue coins")
check(guiText(bob, function(d)
	return d.Text:find("opened the cage") ~= nil
end) ~= nil, "bob got english message")
check(guiText(alice, function(d)
	return d.Text:find("открыл клетку") ~= nil
end) ~= nil, "alice got russian message")

-- мышеловка
bob.Character:PivotTo(CFrame.new(0, 3, 0))
getSignal(toolOf(bob.Backpack, "Trap"), "Activated"):Fire()
advance(0.2)
local trap = M.workspace:FindFirstChild("Mousetrap")
check(trap ~= nil, "trap placed")
getSignal(toolOf(bob.Backpack, "Trap"), "Activated"):Fire() -- перезарядка
advance(0.2)
if trap then
	getSignal(trap.Sensor, "Touched"):Fire(rootOf(alice))
	advance(0.2)
	check(alice:GetAttribute("Stunned") == true, "alice stunned")
	check(alice:GetAttribute("BaseSpeed") == 0, "stunned speed 0")
	advance(4.5)
	check(alice:GetAttribute("Stunned") == false, "stun over")
	check(alice:GetAttribute("BaseSpeed") == 14, "speed back after stun")
	check(M.workspace:FindFirstChild("Mousetrap") == nil, "trap removed after snap")
end

-- писк
M.runAs(alice, function()
	RS.Remotes.Squeak:FireServer()
end)
advance(0.1)
check(alice.Character.Head:FindFirstChildOfClass("BillboardGui") ~= nil, "squeak bubble")

-- голод и сыр
alice:SetAttribute("Hunger", 0.3)
advance(1.1)
check(alice:GetAttribute("BaseSpeed") == 8, "hungry speed")
local crumb = CS:GetTagged("Crumb")[1]
getSignal(crumb, "Touched"):Fire(rootOf(alice))
advance(0.1)
check(alice:GetAttribute("Hunger") > 30, "ate cheese")
check(alice:GetAttribute("BaseSpeed") == 14, "speed after eating")
check(crumb.Transparency == 1, "cheese hidden")

-- норка
local hole = CS:GetTagged("RatHole")[1]
alice.Character:PivotTo(CFrame.new(0, 1.2, 0))
local before = rootOf(alice).Position
getSignal(hole, "Touched"):Fire(rootOf(alice))
advance(0.1)
check((rootOf(alice).Position - before).Magnitude > 20, "hole teleport")

-- ремонт поваром
doStation(alice, station("Fridge"))
check(station("Fridge"):GetAttribute("Broken") == true, "fridge broken r2")
bobCoins = bob:GetAttribute("Coins")
trigger(station("Fridge"), "RepairPrompt", bob)
advance(0.2)
check(station("Fridge"):GetAttribute("Broken") == false, "bob repaired")
check(bob:GetAttribute("Coins") == bobCoins + 3, "repair coins")
-- крыса не может чинить
doStation(alice, station("Fridge"))
trigger(station("Fridge"), "RepairPrompt", alice)
advance(0.2)
check(station("Fridge"):GetAttribute("Broken") == true, "rat cannot repair")

-- крысы ломают всё → победа
local alarmSeen = false
for _, st in ipairs(CS:GetTagged("Sabotage")) do
	if RS:GetAttribute("State") ~= "Playing" then
		break
	end
	if not st:GetAttribute("Broken") then
		local who = alice
		if st.Name == "Cake" or st.Name == "Sinks" then
			who = cara
		end
		doStation(who, st)
		if (RS:GetAttribute("Chaos") or 0) >= 75 then
			alarmSeen = true
		end
	end
end
check(alarmSeen, "alarm reached")
check(waitUntil(function()
	return RS:GetAttribute("State") == "Ended"
end, 20), "round 2 ended")
check(RS:GetAttribute("Winner") == "Rats", "rats won")
advance(0.5)
check(alice:GetAttribute("Wins") == 1, "alice has 1 win, got " .. tostring(alice:GetAttribute("Wins")))
check(guiText(alice, function(d)
	return d.Text:find("ПОБЕДА") ~= nil
end) ~= nil, "victory panel")
print("Coins: Alice " .. alice:GetAttribute("Coins") .. ", Bob " .. bob:GetAttribute("Coins") .. ", Cara " .. cara:GetAttribute("Coins"))

------------------------------------------------------------------------
-- 5. Магазин с монетками
------------------------------------------------------------------------
check(waitUntil(function()
	return RS:GetAttribute("State") == "Lobby"
end, 12), "lobby after round 2")
advance(1)
local DataService = M.require(modules.DataService)
M.runAs(nil, function()
	DataService.addCoins(alice, 200)
end)
local c0 = alice:GetAttribute("Coins")
M.runAs(alice, function()
	shopEvent:FireServer("buy", "crown")
end)
advance(0.5)
check(alice:GetAttribute("OwnedHats"):find("crown") ~= nil, "bought crown")
check(alice:GetAttribute("Coins") == c0 - 250, "crown price paid")
check(alice:GetAttribute("Hat") == "crown", "crown equipped")
check(alice.Character:FindFirstChild("Hat") ~= nil, "crown visible")
check(DS_FAIL or M.dataStoreData["player_" .. alice.UserId] ~= nil, "data saved after purchase")

------------------------------------------------------------------------
-- 6. Раунд 3: игроки уходят
------------------------------------------------------------------------
check(waitUntil(function()
	return RS:GetAttribute("State") == "Playing"
end, 30), "round 3 playing")
advance(1)
local chefPlayer = nil
for _, p in ipairs({ alice, bob, cara }) do
	if p:GetAttribute("Role") == "Chef" then
		chefPlayer = p
	end
end
check(chefPlayer ~= nil, "round 3 has human chef")
check(alice:GetAttribute("Role") ~= "Rat" or alice.Character:FindFirstChild("Hat") ~= nil, "crown on rat")
if chefPlayer then
	M.removePlayer(chefPlayer)
	advance(2)
	check(M.workspace:FindFirstChild("ChefNPC") ~= nil, "AI replaces leaving chef")
	check(DS_FAIL or M.dataStoreData["player_" .. chefPlayer.UserId] ~= nil, "data saved on leave")
end
-- оставшиеся уходят
for _, p in ipairs({ alice, bob, cara }) do
	if p.Parent then
		M.removePlayer(p)
	end
end
check(waitUntil(function()
	return RS:GetAttribute("State") ~= "Playing"
end, 5), "round ends when everyone leaves")
advance(15)

-- новый игрок с сохранёнными данными
M.dataStoreData["player_1004"] = { Coins = 77, Wins = 3, Owned = { none = true, cap = true, halo = true, hacked = true }, Hat = "halo" }
local dan = join("Dan")
advance(1)
check(dan.UserId == 1004, "dan id")
if not DS_FAIL then
	check(dan:GetAttribute("Coins") == 77, "dan coins loaded")
	check(dan:GetAttribute("Wins") == 3, "dan wins loaded")
	check(dan:GetAttribute("Hat") == "halo", "dan hat loaded")
	check(not dan:GetAttribute("OwnedHats"):find("hacked"), "unknown hat filtered")
	check(dan.leaderstats["🧀 Cheese"].Value == 77, "leaderstats coins")
end
advance(30)

-- сохранение при выключении
for _, fn in ipairs(M.closeCallbacks) do
	M.runAs(nil, fn)
end
advance(1)

------------------------------------------------------------------------
-- Итог
------------------------------------------------------------------------
print("")
print(("Checks passed: %d, failed: %d"):format(passes, #failures))
print("Runtime errors: " .. #M.errors)
for i, e in ipairs(M.errors) do
	if i > 15 then
		print("... and more")
		break
	end
	print("---- ERROR " .. i .. " ----")
	print(e)
end
print("Warnings: " .. #M.warnings)
local seen = {}
for _, w in ipairs(M.warnings) do
	if not seen[w] then
		seen[w] = true
		print("  warn: " .. w)
	end
end
return failures
