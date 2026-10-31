-- Мини-симулятор Roblox API для автотестов (Lua 5.4).
-- Не настоящий движок: нет физики и рендера. Нужен, чтобы прогнать скрипты игры
-- и поймать ошибки: опечатки, nil, неизвестные свойства/классы/Enum, ошибки логики.

local M = {}
M.errors = {}
M.warnings = {}
M.logs = {}
M.verbose = false

------------------------------------------------------------------------
-- Планировщик (виртуальное время)
------------------------------------------------------------------------
local now = 0
local timers = {}
local timerSeq = 0
local currentOwner = nil -- игрок-клиент, от лица которого выполняется код (nil = сервер)
local coOwner = setmetatable({}, { __mode = "k" })

local function recordError(msg)
	table.insert(M.errors, msg)
	if M.verbose then
		print("ERROR: " .. msg)
	end
end

local function resume(co, ...)
	local prev = currentOwner
	currentOwner = coOwner[co]
	local ok, err = coroutine.resume(co, ...)
	currentOwner = prev
	if not ok then
		recordError(debug.traceback(co, tostring(err)))
	end
end

local function spawnAs(owner, fn, ...)
	local co
	if type(fn) == "thread" then
		co = fn
	else
		co = coroutine.create(fn)
		coOwner[co] = owner
	end
	resume(co, ...)
	return co
end

local function schedule(at, co, args)
	timerSeq = timerSeq + 1
	table.insert(timers, { at = at, co = co, args = args, seq = timerSeq })
end

local task = {}
function task.spawn(fn, ...)
	return spawnAs(currentOwner, fn, ...)
end
function task.defer(fn, ...)
	local co = coroutine.create(fn)
	coOwner[co] = currentOwner
	schedule(now, co, table.pack(...))
	return co
end
function task.delay(t, fn, ...)
	local co = coroutine.create(fn)
	coOwner[co] = currentOwner
	schedule(now + (t or 0), co, table.pack(...))
	return co
end
function task.wait(t)
	local co, main = coroutine.running()
	if main then
		error("task.wait called from main thread")
	end
	t = t or (1 / 60)
	local start = now
	schedule(now + t, co, nil)
	coroutine.yield()
	return now - start
end
function task.cancel() end
M.task = task

local signalsStepped = {}

function M.step(dt)
	now = now + dt
	-- запуск таймеров
	while true do
		local best, bestIndex = nil, nil
		for i, tm in ipairs(timers) do
			if tm.at <= now + 1e-9 and (not best or tm.at < best.at or (tm.at == best.at and tm.seq < best.seq)) then
				best, bestIndex = tm, i
			end
		end
		if not best then
			break
		end
		table.remove(timers, bestIndex)
		if coroutine.status(best.co) == "suspended" then
			if best.args then
				resume(best.co, table.unpack(best.args, 1, best.args.n))
			else
				resume(best.co, now)
			end
		end
	end
	for _, fn in ipairs(signalsStepped) do
		fn(dt)
	end
end

function M.advance(seconds, dt)
	dt = dt or (1 / 20)
	local n = math.floor(seconds / dt + 0.5)
	for _ = 1, n do
		M.step(dt)
	end
end

function M.now()
	return now
end

------------------------------------------------------------------------
-- Типы данных
------------------------------------------------------------------------
local function typeof(v)
	local t = type(v)
	if t == "table" then
		local mt = getmetatable(v)
		if mt and mt.__type then
			return mt.__type
		end
	end
	if t == "userdata" then
		return "userdata"
	end
	return t
end
M.typeof = typeof

local function checkNum(v, what)
	if type(v) ~= "number" then
		error(("%s: expected number, got %s"):format(what, typeof(v)), 3)
	end
end

-- Vector3
local V3 = { __type = "Vector3" }
local function v3(x, y, z)
	return setmetatable({ _x = x or 0, _y = y or 0, _z = z or 0 }, V3)
end
V3.__index = function(v, k)
	if k == "X" or k == "x" then
		return v._x
	elseif k == "Y" or k == "y" then
		return v._y
	elseif k == "Z" or k == "z" then
		return v._z
	elseif k == "Magnitude" or k == "magnitude" then
		return math.sqrt(v._x * v._x + v._y * v._y + v._z * v._z)
	elseif k == "Unit" or k == "unit" then
		local m = math.sqrt(v._x * v._x + v._y * v._y + v._z * v._z)
		if m == 0 then
			return v3(0 / 0, 0 / 0, 0 / 0)
		end
		return v3(v._x / m, v._y / m, v._z / m)
	elseif k == "Dot" then
		return function(a, b)
			return a._x * b._x + a._y * b._y + a._z * b._z
		end
	elseif k == "Cross" then
		return function(a, b)
			return v3(a._y * b._z - a._z * b._y, a._z * b._x - a._x * b._z, a._x * b._y - a._y * b._x)
		end
	elseif k == "Lerp" then
		return function(a, b, t)
			return v3(a._x + (b._x - a._x) * t, a._y + (b._y - a._y) * t, a._z + (b._z - a._z) * t)
		end
	elseif k == "Abs" then
		return function(a)
			return v3(math.abs(a._x), math.abs(a._y), math.abs(a._z))
		end
	end
	error("Vector3 has no member " .. tostring(k), 2)
end
V3.__add = function(a, b)
	if typeof(a) ~= "Vector3" or typeof(b) ~= "Vector3" then
		error("Vector3 + expects Vector3, got " .. typeof(a) .. ", " .. typeof(b), 2)
	end
	return v3(a._x + b._x, a._y + b._y, a._z + b._z)
end
V3.__sub = function(a, b)
	if typeof(a) ~= "Vector3" or typeof(b) ~= "Vector3" then
		error("Vector3 - expects Vector3, got " .. typeof(a) .. ", " .. typeof(b), 2)
	end
	return v3(a._x - b._x, a._y - b._y, a._z - b._z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return v3(a * b._x, a * b._y, a * b._z)
	elseif type(b) == "number" then
		return v3(a._x * b, a._y * b, a._z * b)
	elseif typeof(a) == "Vector3" and typeof(b) == "Vector3" then
		return v3(a._x * b._x, a._y * b._y, a._z * b._z)
	end
	error("bad Vector3 multiply " .. typeof(a) .. " * " .. typeof(b), 2)
end
V3.__div = function(a, b)
	if type(b) == "number" then
		return v3(a._x / b, a._y / b, a._z / b)
	end
	return v3(a._x / b._x, a._y / b._y, a._z / b._z)
end
V3.__unm = function(a)
	return v3(-a._x, -a._y, -a._z)
end
V3.__eq = function(a, b)
	return a._x == b._x and a._y == b._y and a._z == b._z
end
V3.__tostring = function(v)
	return ("%g, %g, %g"):format(v._x, v._y, v._z)
end
local Vector3 = {
	new = function(x, y, z)
		if x ~= nil then
			checkNum(x, "Vector3.new x")
			checkNum(y, "Vector3.new y")
			checkNum(z, "Vector3.new z")
		end
		return v3(x, y, z)
	end,
	zero = v3(0, 0, 0),
	one = v3(1, 1, 1),
	xAxis = v3(1, 0, 0),
	yAxis = v3(0, 1, 0),
	zAxis = v3(0, 0, 1),
}

-- Vector2
local V2 = { __type = "Vector2" }
V2.__index = function(v, k)
	if k == "X" or k == "x" then
		return v._x
	elseif k == "Y" or k == "y" then
		return v._y
	elseif k == "Magnitude" then
		return math.sqrt(v._x * v._x + v._y * v._y)
	end
	error("Vector2 has no member " .. tostring(k), 2)
end
local Vector2 = {
	new = function(x, y)
		return setmetatable({ _x = x or 0, _y = y or 0 }, V2)
	end,
}
Vector2.zero = Vector2.new(0, 0)

-- CFrame
local CF = { __type = "CFrame" }
local function cf(px, py, pz, r)
	return setmetatable({ _p = v3(px, py, pz), _r = r or { 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, CF)
end
local function mulR(a, b)
	local r = {}
	for i = 0, 2 do
		for j = 0, 2 do
			local s = 0
			for k = 0, 2 do
				s = s + a[i * 3 + k + 1] * b[k * 3 + j + 1]
			end
			r[i * 3 + j + 1] = s
		end
	end
	return r
end
local function rotV(r, v)
	return v3(r[1] * v._x + r[2] * v._y + r[3] * v._z, r[4] * v._x + r[5] * v._y + r[6] * v._z, r[7] * v._x + r[8] * v._y + r[9] * v._z)
end
local function transposeR(r)
	return { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] }
end
local function cfInverse(c)
	local rt = transposeR(c._r)
	local p = rotV(rt, c._p)
	return cf(-p._x, -p._y, -p._z, rt)
end
CF.__index = function(c, k)
	if k == "Position" or k == "p" then
		return c._p
	elseif k == "X" then
		return c._p._x
	elseif k == "Y" then
		return c._p._y
	elseif k == "Z" then
		return c._p._z
	elseif k == "LookVector" or k == "lookVector" then
		return v3(-c._r[3], -c._r[6], -c._r[9])
	elseif k == "RightVector" then
		return v3(c._r[1], c._r[4], c._r[7])
	elseif k == "UpVector" then
		return v3(c._r[2], c._r[5], c._r[8])
	elseif k == "Rotation" then
		return cf(0, 0, 0, c._r)
	elseif k == "Inverse" then
		return cfInverse
	elseif k == "ToWorldSpace" then
		return function(a, b)
			return a * b
		end
	elseif k == "ToObjectSpace" then
		return function(a, b)
			return cfInverse(a) * b
		end
	elseif k == "PointToWorldSpace" then
		return function(a, v)
			return a * v
		end
	elseif k == "PointToObjectSpace" then
		return function(a, v)
			return cfInverse(a) * v
		end
	elseif k == "Lerp" then
		return function(a, b, t)
			return cf(a._p._x + (b._p._x - a._p._x) * t, a._p._y + (b._p._y - a._p._y) * t, a._p._z + (b._p._z - a._p._z) * t, b._r)
		end
	end
	error("CFrame has no member " .. tostring(k), 2)
end
CF.__mul = function(a, b)
	if typeof(a) ~= "CFrame" then
		error("CFrame * : left side is " .. typeof(a), 2)
	end
	if typeof(b) == "CFrame" then
		local p = rotV(a._r, b._p) + a._p
		return cf(p._x, p._y, p._z, mulR(a._r, b._r))
	elseif typeof(b) == "Vector3" then
		return rotV(a._r, b) + a._p
	end
	error("CFrame * : right side is " .. typeof(b), 2)
end
CF.__add = function(a, b)
	if typeof(a) ~= "CFrame" or typeof(b) ~= "Vector3" then
		error("CFrame + expects CFrame + Vector3, got " .. typeof(a) .. " + " .. typeof(b), 2)
	end
	local p = a._p + b
	return cf(p._x, p._y, p._z, a._r)
end
CF.__sub = function(a, b)
	local p = a._p - b
	return cf(p._x, p._y, p._z, a._r)
end
CF.__tostring = function(c)
	return "CFrame(" .. tostring(c._p) .. ")"
end
function M.orthonormalize(c)
	local r = c._r
	local x = v3(r[1], r[4], r[7]).Unit
	local y = v3(r[2], r[5], r[8])
	y = (y - x * x:Dot(y)).Unit
	local z = x:Cross(y)
	return cf(c._p._x, c._p._y, c._p._z, { x._x, y._x, z._x, x._y, y._y, z._y, x._z, y._z, z._z })
end

local function anglesR(rx, ry, rz)
	local cx, sx = math.cos(rx), math.sin(rx)
	local cy, sy = math.cos(ry), math.sin(ry)
	local cz, sz = math.cos(rz), math.sin(rz)
	local Rx = { 1, 0, 0, 0, cx, -sx, 0, sx, cx }
	local Ry = { cy, 0, sy, 0, 1, 0, -sy, 0, cy }
	local Rz = { cz, -sz, 0, sz, cz, 0, 0, 0, 1 }
	return mulR(mulR(Rx, Ry), Rz)
end
local function fromMatrix(pos, vx, vy, vz)
	vz = vz or vx:Cross(vy)
	return cf(pos._x, pos._y, pos._z, { vx._x, vy._x, vz._x, vx._y, vy._y, vz._y, vx._z, vy._z, vz._z })
end
local function lookAt(pos, target, up)
	up = up or v3(0, 1, 0)
	local f = (target - pos).Unit
	local z = -f
	local x = up:Cross(z)
	if x.Magnitude < 1e-6 then
		x = v3(1, 0, 0)
	end
	x = x.Unit
	local y = z:Cross(x)
	return fromMatrix(pos, x, y, z)
end
local CFrame = {
	new = function(a, b, c, ...)
		if a == nil then
			return cf(0, 0, 0)
		elseif typeof(a) == "Vector3" then
			if b ~= nil then
				return lookAt(a, b)
			end
			return cf(a._x, a._y, a._z)
		elseif type(a) == "number" then
			checkNum(b, "CFrame.new y")
			checkNum(c, "CFrame.new z")
			local rest = { ... }
			if #rest == 9 then
				return cf(a, b, c, rest)
			end
			return cf(a, b, c)
		end
		error("CFrame.new bad args " .. typeof(a), 2)
	end,
	Angles = function(rx, ry, rz)
		checkNum(rx, "CFrame.Angles")
		checkNum(ry, "CFrame.Angles")
		checkNum(rz, "CFrame.Angles")
		return cf(0, 0, 0, anglesR(rx, ry, rz))
	end,
	lookAt = function(pos, target, up)
		if typeof(pos) ~= "Vector3" or typeof(target) ~= "Vector3" then
			error("CFrame.lookAt expects Vector3", 2)
		end
		return lookAt(pos, target, up)
	end,
	fromMatrix = function(pos, vx, vy, vz)
		if typeof(pos) ~= "Vector3" or typeof(vx) ~= "Vector3" or typeof(vy) ~= "Vector3" then
			error("CFrame.fromMatrix expects Vector3", 2)
		end
		return fromMatrix(pos, vx, vy, vz)
	end,
	identity = cf(0, 0, 0),
}
CFrame.fromEulerAnglesXYZ = CFrame.Angles

-- Color3
local C3 = { __type = "Color3" }
C3.__index = function(c, k)
	if k == "R" or k == "r" then
		return c._r
	elseif k == "G" or k == "g" then
		return c._g
	elseif k == "B" or k == "b" then
		return c._b
	elseif k == "Lerp" then
		return function(a, b, t)
			return setmetatable({ _r = a._r + (b._r - a._r) * t, _g = a._g + (b._g - a._g) * t, _b = a._b + (b._b - a._b) * t }, C3)
		end
	elseif k == "ToHSV" then
		return function()
			return 0, 0, 0
		end
	end
	error("Color3 has no member " .. tostring(k), 2)
end
C3.__eq = function(a, b)
	return a._r == b._r and a._g == b._g and a._b == b._b
end
local function c3(r, g, b)
	return setmetatable({ _r = r, _g = g, _b = b }, C3)
end
local Color3 = {
	new = function(r, g, b)
		return c3(r or 0, g or 0, b or 0)
	end,
	fromRGB = function(r, g, b)
		checkNum(r, "Color3.fromRGB r")
		checkNum(g, "Color3.fromRGB g")
		checkNum(b, "Color3.fromRGB b")
		return c3(r / 255, g / 255, b / 255)
	end,
	fromHSV = function(h, s, v)
		checkNum(h, "Color3.fromHSV")
		checkNum(s, "Color3.fromHSV")
		checkNum(v, "Color3.fromHSV")
		return c3(v, v * (1 - s), v * (1 - s * h))
	end,
}

-- UDim / UDim2
local UD = { __type = "UDim" }
UD.__index = function(u, k)
	if k == "Scale" then
		return u._s
	elseif k == "Offset" then
		return u._o
	end
	error("UDim has no member " .. tostring(k), 2)
end
local function udim(s, o)
	return setmetatable({ _s = s or 0, _o = o or 0 }, UD)
end
local UDim = {
	new = function(s, o)
		return udim(s, o)
	end,
}
local UD2 = { __type = "UDim2" }
UD2.__index = function(u, k)
	if k == "X" or k == "Width" then
		return u._x
	elseif k == "Y" or k == "Height" then
		return u._y
	end
	error("UDim2 has no member " .. tostring(k), 2)
end
local function udim2(xs, xo, ys, yo)
	return setmetatable({ _x = udim(xs, xo), _y = udim(ys, yo) }, UD2)
end
UD2.__add = function(a, b)
	return udim2(a._x._s + b._x._s, a._x._o + b._x._o, a._y._s + b._y._s, a._y._o + b._y._o)
end
local UDim2 = {
	new = function(xs, xo, ys, yo)
		for _, v in ipairs({ xs or 0, xo or 0, ys or 0, yo or 0 }) do
			checkNum(v, "UDim2.new")
		end
		return udim2(xs, xo, ys, yo)
	end,
	fromScale = function(x, y)
		checkNum(x, "UDim2.fromScale")
		checkNum(y, "UDim2.fromScale")
		return udim2(x, 0, y, 0)
	end,
	fromOffset = function(x, y)
		checkNum(x, "UDim2.fromOffset")
		checkNum(y, "UDim2.fromOffset")
		return udim2(0, x, 0, y)
	end,
}

local function simpleType(name, ctor)
	local mt = { __type = name }
	mt.__index = function(t, k)
		local v = rawget(t, "_f")[k]
		if v == nil then
			error(name .. " has no member " .. tostring(k), 2)
		end
		return v
	end
	return function(...)
		return setmetatable({ _f = ctor(...) }, mt)
	end
end

local NumberSequenceKeypoint = {
	new = simpleType("NumberSequenceKeypoint", function(t, v)
		checkNum(t, "NumberSequenceKeypoint time")
		checkNum(v, "NumberSequenceKeypoint value")
		return { Time = t, Value = v }
	end),
}
local NumberSequence = {
	new = simpleType("NumberSequence", function(a, b)
		if type(a) == "number" then
			return { Keypoints = { a, b or a } }
		end
		if type(a) ~= "table" then
			error("NumberSequence.new bad arg")
		end
		for _, kp in ipairs(a) do
			if typeof(kp) ~= "NumberSequenceKeypoint" then
				error("NumberSequence.new expects keypoints")
			end
		end
		return { Keypoints = a }
	end),
}
local ColorSequenceKeypoint = {
	new = simpleType("ColorSequenceKeypoint", function(t, c)
		checkNum(t, "ColorSequenceKeypoint time")
		if typeof(c) ~= "Color3" then
			error("ColorSequenceKeypoint expects Color3")
		end
		return { Time = t, Value = c }
	end),
}
local ColorSequence = {
	new = simpleType("ColorSequence", function(a, b)
		if typeof(a) == "Color3" then
			return { Keypoints = { a, b or a } }
		end
		if type(a) ~= "table" then
			error("ColorSequence.new bad arg")
		end
		for _, kp in ipairs(a) do
			if typeof(kp) ~= "ColorSequenceKeypoint" then
				error("ColorSequence.new expects keypoints")
			end
		end
		return { Keypoints = a }
	end),
}
local NumberRange = {
	new = simpleType("NumberRange", function(a, b)
		checkNum(a, "NumberRange.new")
		return { Min = a, Max = b or a }
	end),
}
local TweenInfo = {
	new = simpleType("TweenInfo", function(t, style, dir)
		return { Time = t or 1, EasingStyle = style, EasingDirection = dir }
	end),
}

------------------------------------------------------------------------
-- Enum
------------------------------------------------------------------------
local enumLists = {
	Material = "Plastic SmoothPlastic Neon Wood WoodPlanks Marble Slate Concrete Granite Brick Pebble Cobblestone Metal DiamondPlate CorrodedMetal Foil Grass Ice Sand Fabric Glass ForceField Air Water Rock Glacier Snow Sandstone Mud Basalt Ground CrackedLava Asphalt LeafyGrass Salt Limestone Pavement Cardboard Carpet CeramicTiles ClayRoofTiles RoofShingles Leather Plaster Rubber",
	PartType = "Ball Block Cylinder Wedge CornerWedge",
	SurfaceType = "Smooth Glue Weld Studs Inlet Universal Hinge Motor SteppingMotor SmoothNoOutlines",
	MeshType = "Head Torso Wedge Prism Pyramid ParallelRamp RightAngleRamp CornerWedge Brick Sphere Cylinder FileMesh",
	NormalId = "Top Bottom Front Back Left Right",
	Font = "Legacy Arial ArialBold SourceSans SourceSansBold SourceSansLight SourceSansItalic SourceSansSemibold Bodoni Garamond Cartoon Code Highway SciFi Arcade Fantasy Antique Gotham GothamMedium GothamBold GothamBlack AmaticSC Bangers Creepster DenkOne Fondamento FredokaOne GrenzeGotisch IndieFlower JosefinSans Jura Kalam LuckiestGuy Merriweather Michroma Nunito Oswald PatrickHand PermanentMarker Roboto RobotoCondensed RobotoMono Sarpanch SpecialElite TitilliumWeb Ubuntu BuilderSans BuilderSansMedium BuilderSansBold BuilderSansExtraBold Arimo ArimoBold",
	HumanoidRigType = "R6 R15",
	HumanoidHealthDisplayType = "DisplayWhenDamaged AlwaysOn AlwaysOff",
	HumanoidStateType = "Jumping Freefall Running Landed Seated Dead Physics Climbing FallingDown GettingUp Ragdoll Swimming Flying StrafingNoPhysics RunningNoPhysics PlatformStanding None",
	RaycastFilterType = "Exclude Include Blacklist Whitelist",
	PathStatus = "Success ClosestNoPath ClosestOutOfRange FailStartNotEmpty FailFinishNotEmpty NoPath",
	PathWaypointAction = "Walk Jump Custom",
	EasingStyle = "Linear Sine Back Quad Quart Quint Bounce Elastic Exponential Circular Cubic",
	EasingDirection = "In Out InOut",
	TextXAlignment = "Left Center Right",
	TextYAlignment = "Top Center Bottom",
	AutomaticSize = "None X Y XY",
	SortOrder = "LayoutOrder Name Custom",
	FillDirection = "Horizontal Vertical",
	HorizontalAlignment = "Center Left Right",
	VerticalAlignment = "Center Top Bottom",
	ApplyStrokeMode = "Contextual Border",
	UserInputType = "MouseButton1 MouseButton2 MouseButton3 MouseWheel MouseMovement Touch Keyboard Focus Accelerometer Gyro Gamepad1 Gamepad2 TextInput None",
	KeyCode = "A B C D E F G H I J K L M N O P Q R S T U V W X Y Z Zero One Two Three Four Five Six Seven Eight Nine Space LeftShift RightShift LeftControl RightControl Tab Return Backspace Escape ButtonA ButtonB ButtonX ButtonY ButtonL1 ButtonR1 ButtonL2 ButtonR2 ButtonL3 ButtonR3 DPadUp DPadDown DPadLeft DPadRight Unknown",
	HighlightDepthMode = "AlwaysOnTop Occluded",
	SurfaceGuiSizingMode = "FixedSize PixelsPerStud",
	ZIndexBehavior = "Global Sibling",
	PlaybackState = "Begin Delayed Playing Paused Completed Cancelled",
	ScrollingDirection = "X Y XY",
	ProximityPromptStyle = "Default Custom",
}
local enumItems = {}
local EnumItemMT = { __type = "EnumItem" }
EnumItemMT.__index = function(e, k)
	if k == "Name" then
		return rawget(e, "_name")
	elseif k == "EnumType" then
		return rawget(e, "_type")
	elseif k == "Value" then
		return rawget(e, "_value")
	end
	error("EnumItem has no member " .. tostring(k), 2)
end
EnumItemMT.__tostring = function(e)
	return "Enum." .. rawget(e, "_type") .. "." .. rawget(e, "_name")
end
local Enum = setmetatable({}, {
	__index = function(_, typeName)
		local list = enumLists[typeName]
		if not list then
			error("Unknown Enum type: Enum." .. tostring(typeName), 2)
		end
		if not enumItems[typeName] then
			local items = {}
			local i = 0
			for name in list:gmatch("%S+") do
				items[name] = setmetatable({ _name = name, _type = typeName, _value = i }, EnumItemMT)
				i = i + 1
			end
			enumItems[typeName] = setmetatable(items, {
				__index = function(_, item)
					error("Unknown Enum item: Enum." .. typeName .. "." .. tostring(item), 2)
				end,
			})
		end
		return enumItems[typeName]
	end,
})

------------------------------------------------------------------------
-- Сигналы
------------------------------------------------------------------------
local SignalMT = { __type = "RBXScriptSignal" }
SignalMT.__index = SignalMT
local function newSignal(name)
	return setmetatable({ _name = name, _conns = {}, _waiting = {} }, SignalMT)
end
function SignalMT:Connect(fn)
	if type(fn) ~= "function" then
		error("Connect expects a function", 2)
	end
	local conn = { fn = fn, owner = currentOwner, Connected = true }
	conn.Disconnect = function(c)
		c.Connected = false
	end
	table.insert(self._conns, conn)
	return conn
end
SignalMT.connect = SignalMT.Connect
function SignalMT:Once(fn)
	local conn
	conn = self:Connect(function(...)
		conn.Connected = false
		fn(...)
	end)
	return conn
end
function SignalMT:Wait()
	local co = coroutine.running()
	table.insert(self._waiting, co)
	return coroutine.yield()
end
function SignalMT:Fire(...)
	local list = {}
	for _, c in ipairs(self._conns) do
		table.insert(list, c)
	end
	for _, c in ipairs(list) do
		if c.Connected then
			spawnAs(c.owner, c.fn, ...)
		end
	end
	local waiting = self._waiting
	self._waiting = {}
	for _, co in ipairs(waiting) do
		if coroutine.status(co) == "suspended" then
			resume(co, ...)
		end
	end
end
-- для клиентских событий: только соединения конкретного игрока
function SignalMT:FireFor(owner, ...)
	local list = {}
	for _, c in ipairs(self._conns) do
		if c.owner == owner then
			table.insert(list, c)
		end
	end
	for _, c in ipairs(list) do
		if c.Connected then
			spawnAs(c.owner, c.fn, ...)
		end
	end
end
M.newSignal = newSignal

------------------------------------------------------------------------
-- Классы и свойства
------------------------------------------------------------------------
local Classes = {}
local function def(name, base, props, events, defaults, methods)
	Classes[name] = { name = name, base = base, props = props or {}, events = events or {}, defaults = defaults or {}, methods = methods or {} }
end

-- типы свойств: "number" "string" "boolean" "Vector3" "CFrame" "Color3" "UDim2" "UDim" "Vector2"
-- "Instance" "NumberSequence" "ColorSequence" "NumberRange" "EnumItem" "any"
def("Instance", nil, { Name = "string", Archivable = "boolean" }, { "ChildAdded", "ChildRemoved", "AncestryChanged", "Destroying" })
def("PVInstance", "Instance", {})
def("BasePart", "PVInstance", {
	Anchored = "boolean",
	CanCollide = "boolean",
	CanQuery = "boolean",
	CanTouch = "boolean",
	Massless = "boolean",
	CastShadow = "boolean",
	Locked = "boolean",
	Size = "Vector3",
	CFrame = "CFrame",
	Position = "Vector3",
	Orientation = "Vector3",
	Color = "Color3",
	Material = "EnumItem:Material",
	Transparency = "number",
	Reflectance = "number",
	TopSurface = "EnumItem:SurfaceType",
	BottomSurface = "EnumItem:SurfaceType",
	AssemblyLinearVelocity = "Vector3",
}, { "Touched", "TouchEnded" }, {
	Size = Vector3.new(4, 1, 2),
	Transparency = 0,
	Anchored = false,
	CanCollide = true,
	CanQuery = true,
	CanTouch = true,
	Color = Color3.new(0.6, 0.6, 0.6),
	Reflectance = 0,
	AssemblyLinearVelocity = Vector3.new(0, 0, 0),
})
def("Part", "BasePart", { Shape = "EnumItem:PartType" })
def("SpawnLocation", "Part", { Neutral = "boolean", Duration = "number" })
def("MeshPart", "BasePart", {})
def("Model", "PVInstance", { PrimaryPart = "Instance", WorldPivot = "CFrame" })
def("Folder", "Instance", {})
def("Workspace", "Model", { Gravity = "number" })
def("Humanoid", "Instance", {
	WalkSpeed = "number",
	JumpPower = "number",
	JumpHeight = "number",
	UseJumpPower = "boolean",
	HipHeight = "number",
	RigType = "EnumItem:HumanoidRigType",
	RequiresNeck = "boolean",
	BreakJointsOnDeath = "boolean",
	HealthDisplayType = "EnumItem:HumanoidHealthDisplayType",
	DisplayName = "string",
	NameDisplayDistance = "number",
	Health = "number",
	MaxHealth = "number",
	MoveDirection = "Vector3",
	CameraOffset = "Vector3",
	AutoRotate = "boolean",
	Jump = "boolean",
}, { "Died", "Running", "MoveToFinished", "StateChanged", "Jumping" }, {
	WalkSpeed = 16,
	JumpPower = 50,
	Health = 100,
	MaxHealth = 100,
	MoveDirection = Vector3.new(0, 0, 0),
	CameraOffset = Vector3.new(0, 0, 0),
	Jump = false,
	HipHeight = 2,
})
def("Animator", "Instance", {})
def("Animation", "Instance", { AnimationId = "string" })
def("HumanoidDescription", "Instance", {
	HeadColor = "Color3",
	LeftArmColor = "Color3",
	RightArmColor = "Color3",
	TorsoColor = "Color3",
	LeftLegColor = "Color3",
	RightLegColor = "Color3",
})
def("JointInstance", "Instance", { Part0 = "Instance", Part1 = "Instance", C0 = "CFrame", C1 = "CFrame", Enabled = "boolean" }, {}, {
	C0 = CFrame.new(),
	C1 = CFrame.new(),
	Enabled = true,
})
def("Motor6D", "JointInstance", { Transform = "CFrame" })
def("Weld", "JointInstance", {})
def("WeldConstraint", "Instance", { Part0 = "Instance", Part1 = "Instance", Enabled = "boolean" })
def("SpecialMesh", "Instance", { MeshType = "EnumItem:MeshType", Scale = "Vector3", MeshId = "string", Offset = "Vector3" })
def("Attachment", "Instance", { Position = "Vector3", CFrame = "CFrame", Orientation = "Vector3" })
def("Accessory", "Instance", {})
def("Tool", "Instance", {
	Grip = "CFrame",
	ToolTip = "string",
	CanBeDropped = "boolean",
	RequiresHandle = "boolean",
	ManualActivationOnly = "boolean",
	Enabled = "boolean",
}, { "Activated", "Equipped", "Unequipped" })
def("ValueBase", "Instance", {})
def("StringValue", "ValueBase", { Value = "string" }, { "Changed" }, { Value = "" })
def("IntValue", "ValueBase", { Value = "number" }, { "Changed" }, { Value = 0 })
def("NumberValue", "ValueBase", { Value = "number" }, { "Changed" }, { Value = 0 })
def("BoolValue", "ValueBase", { Value = "boolean" }, { "Changed" }, { Value = false })
def("ProximityPrompt", "Instance", {
	ActionText = "string",
	ObjectText = "string",
	HoldDuration = "number",
	MaxActivationDistance = "number",
	RequiresLineOfSight = "boolean",
	KeyboardKeyCode = "EnumItem:KeyCode",
	Enabled = "boolean",
	Style = "EnumItem:ProximityPromptStyle",
}, { "Triggered", "PromptShown", "PromptHidden", "Triggerended" }, { Enabled = true, HoldDuration = 0 })
def("Light", "Instance", { Brightness = "number", Color = "Color3", Range = "number", Shadows = "boolean", Enabled = "boolean" }, {}, {
	Brightness = 1,
	Enabled = true,
	Range = 8,
	Color = Color3.new(1, 1, 1),
})
def("PointLight", "Light", {})
def("SpotLight", "Light", { Angle = "number", Face = "EnumItem:NormalId" })
def("SurfaceLight", "Light", { Angle = "number", Face = "EnumItem:NormalId" })
def("Fire", "Instance", { Size = "number", Heat = "number", Color = "Color3", SecondaryColor = "Color3", Enabled = "boolean" }, {}, { Enabled = true })
def("Smoke", "Instance", { Color = "Color3", Opacity = "number", RiseVelocity = "number", Size = "number", Enabled = "boolean" }, {}, { Enabled = true })
def("Sparkles", "Instance", { SparkleColor = "Color3", Enabled = "boolean" }, {}, { Enabled = true })
def("ParticleEmitter", "Instance", {
	Rate = "number",
	Lifetime = "NumberRange",
	Speed = "NumberRange",
	SpreadAngle = "Vector2",
	Size = "NumberSequence",
	LightEmission = "number",
	Transparency = "NumberSequence",
	Color = "ColorSequence",
	Texture = "string",
	Acceleration = "Vector3",
	Rotation = "NumberRange",
	RotSpeed = "NumberRange",
	Enabled = "boolean",
	Drag = "number",
	LockedToPart = "boolean",
	ZOffset = "number",
}, {}, { Enabled = true, Rate = 5 })
def("Sound", "Instance", {
	SoundId = "string",
	Volume = "number",
	PlaybackSpeed = "number",
	Looped = "boolean",
	RollOffMaxDistance = "number",
	RollOffMinDistance = "number",
	Playing = "boolean",
	TimePosition = "number",
}, { "Ended" }, { Volume = 0.5, PlaybackSpeed = 1, Playing = false, Looped = false })
def("GuiBase2d", "Instance", {})
def("LayerCollector", "GuiBase2d", { Enabled = "boolean", ResetOnSpawn = "boolean", ZIndexBehavior = "EnumItem:ZIndexBehavior" })
def("ScreenGui", "LayerCollector", { IgnoreGuiInset = "boolean", DisplayOrder = "number" })
def("BillboardGui", "LayerCollector", {
	Size = "UDim2",
	StudsOffset = "Vector3",
	AlwaysOnTop = "boolean",
	MaxDistance = "number",
	LightInfluence = "number",
	Adornee = "Instance",
	ExtentsOffset = "Vector3",
}, {}, { StudsOffset = Vector3.new(0, 0, 0) })
def("SurfaceGui", "LayerCollector", {
	Face = "EnumItem:NormalId",
	LightInfluence = "number",
	SizingMode = "EnumItem:SurfaceGuiSizingMode",
	PixelsPerStud = "number",
	CanvasSize = "Vector2",
	Adornee = "Instance",
	AlwaysOnTop = "boolean",
	Brightness = "number",
})
def("GuiObject", "GuiBase2d", {
	AnchorPoint = "Vector2",
	Position = "UDim2",
	Size = "UDim2",
	BackgroundColor3 = "Color3",
	BackgroundTransparency = "number",
	BorderSizePixel = "number",
	Visible = "boolean",
	ZIndex = "number",
	LayoutOrder = "number",
	Rotation = "number",
	AutomaticSize = "EnumItem:AutomaticSize",
	ClipsDescendants = "boolean",
	Active = "boolean",
}, { "InputBegan", "InputEnded", "MouseEnter", "MouseLeave" }, {
	Visible = true,
	BackgroundTransparency = 0,
	ZIndex = 1,
	LayoutOrder = 0,
	Rotation = 0,
	Size = UDim2.new(0, 100, 0, 100),
	Position = UDim2.new(0, 0, 0, 0),
	BackgroundColor3 = Color3.new(1, 1, 1),
})
def("Frame", "GuiObject", {})
def("ScrollingFrame", "GuiObject", {
	CanvasSize = "UDim2",
	ScrollBarThickness = "number",
	AutomaticCanvasSize = "EnumItem:AutomaticSize",
	ScrollingDirection = "EnumItem:ScrollingDirection",
})
local textProps = {
	Text = "string",
	TextColor3 = "Color3",
	TextScaled = "boolean",
	TextSize = "number",
	Font = "EnumItem:Font",
	TextWrapped = "boolean",
	RichText = "boolean",
	TextXAlignment = "EnumItem:TextXAlignment",
	TextYAlignment = "EnumItem:TextYAlignment",
	TextTransparency = "number",
	TextStrokeTransparency = "number",
	TextStrokeColor3 = "Color3",
}
local textDefaults = { Text = "Label", TextTransparency = 0, TextStrokeTransparency = 1, TextColor3 = Color3.new(0, 0, 0) }
def("TextLabel", "GuiObject", textProps, {}, textDefaults)
local buttonProps = {}
for k, v in pairs(textProps) do
	buttonProps[k] = v
end
buttonProps.AutoButtonColor = "boolean"
def("TextButton", "GuiObject", buttonProps, { "Activated", "MouseButton1Click" }, textDefaults)
def("UIComponent", "Instance", {})
def("UICorner", "UIComponent", { CornerRadius = "UDim" })
def("UIStroke", "UIComponent", {
	Color = "Color3",
	Thickness = "number",
	Transparency = "number",
	ApplyStrokeMode = "EnumItem:ApplyStrokeMode",
	Enabled = "boolean",
}, {}, { Thickness = 1, Transparency = 0, Color = Color3.new(0, 0, 0) })
def("UIPadding", "UIComponent", { PaddingTop = "UDim", PaddingBottom = "UDim", PaddingLeft = "UDim", PaddingRight = "UDim" })
def("UIListLayout", "UIComponent", {
	Padding = "UDim",
	SortOrder = "EnumItem:SortOrder",
	FillDirection = "EnumItem:FillDirection",
	HorizontalAlignment = "EnumItem:HorizontalAlignment",
	VerticalAlignment = "EnumItem:VerticalAlignment",
})
def("UIGridLayout", "UIComponent", {
	CellSize = "UDim2",
	CellPadding = "UDim2",
	SortOrder = "EnumItem:SortOrder",
	FillDirection = "EnumItem:FillDirection",
	HorizontalAlignment = "EnumItem:HorizontalAlignment",
})
def("UIGradient", "UIComponent", { Color = "ColorSequence", Transparency = "NumberSequence", Rotation = "number", Offset = "Vector2", Enabled = "boolean" })
def("UIScale", "UIComponent", { Scale = "number" }, {}, { Scale = 1 })
def("Highlight", "Instance", {
	FillTransparency = "number",
	OutlineTransparency = "number",
	OutlineColor = "Color3",
	FillColor = "Color3",
	DepthMode = "EnumItem:HighlightDepthMode",
	Enabled = "boolean",
	Adornee = "Instance",
}, {}, { Enabled = true })
def("PostEffect", "Instance", { Enabled = "boolean" })
def("Atmosphere", "Instance", { Density = "number", Offset = "number", Color = "Color3", Decay = "Color3", Glare = "number", Haze = "number" })
def("BloomEffect", "PostEffect", { Intensity = "number", Size = "number", Threshold = "number" })
def("ColorCorrectionEffect", "PostEffect", { Brightness = "number", Contrast = "number", Saturation = "number", TintColor = "Color3" })
def("RemoteEvent", "Instance", {}, { "OnServerEvent", "OnClientEvent" })
def("LuaSourceContainer", "Instance", {})
def("BaseScript", "LuaSourceContainer", { Enabled = "boolean" })
def("Script", "BaseScript", {})
def("LocalScript", "Script", {})
def("ModuleScript", "LuaSourceContainer", {})
def("Player", "Instance", { Character = "Instance", UserId = "number", DisplayName = "string", LocaleId = "string" }, { "CharacterAdded", "CharacterRemoving" })
def("Backpack", "Instance", {})
def("PlayerGui", "Instance", {})
def("DataModel", "Instance", {})
def("Players", "Instance", { CharacterAutoLoads = "boolean" }, { "PlayerAdded", "PlayerRemoving" })
def("ReplicatedStorage", "Instance", {})
def("ServerScriptService", "Instance", {})
def("ServerStorage", "Instance", {})
def("StarterPlayer", "Instance", { EnableMouseLockOption = "boolean" })
def("StarterPlayerScripts", "Instance", {})
def("Lighting", "Instance", {
	ClockTime = "number",
	Brightness = "number",
	Ambient = "Color3",
	OutdoorAmbient = "Color3",
	EnvironmentDiffuseScale = "number",
	EnvironmentSpecularScale = "number",
})
def("SoundService", "Instance", {})
def("StarterGui", "Instance", {})
def("Service", "Instance", {})

local creatable = {
	Part = true, SpawnLocation = true, Model = true, Folder = true, Humanoid = true, Animator = true, Animation = true,
	HumanoidDescription = true, Motor6D = true, Weld = true, WeldConstraint = true, SpecialMesh = true, Attachment = true,
	Accessory = true, Tool = true, StringValue = true, IntValue = true, NumberValue = true, BoolValue = true,
	ProximityPrompt = true, PointLight = true, SpotLight = true, SurfaceLight = true, Fire = true, Smoke = true,
	Sparkles = true, ParticleEmitter = true, Sound = true, ScreenGui = true, BillboardGui = true, SurfaceGui = true,
	Frame = true, ScrollingFrame = true, TextLabel = true, TextButton = true, UICorner = true, UIStroke = true,
	UIPadding = true, UIListLayout = true, UIGridLayout = true, UIGradient = true, UIScale = true, Highlight = true,
	Atmosphere = true, BloomEffect = true, ColorCorrectionEffect = true, RemoteEvent = true, Script = true,
	LocalScript = true, ModuleScript = true, MeshPart = true,
}

local function classChain(name)
	local chain = {}
	local c = Classes[name]
	while c do
		table.insert(chain, c)
		c = Classes[c.base]
	end
	return chain
end

local chainCache = {}
local function getChain(name)
	if not chainCache[name] then
		chainCache[name] = classChain(name)
	end
	return chainCache[name]
end

local function propType(className, key)
	for _, c in ipairs(getChain(className)) do
		if c.props[key] then
			return c.props[key]
		end
	end
	return nil
end

local function propDefault(className, key)
	for _, c in ipairs(getChain(className)) do
		if c.defaults[key] ~= nil then
			return c.defaults[key]
		end
	end
	return nil
end

local function hasEvent(className, key)
	for _, c in ipairs(getChain(className)) do
		for _, e in ipairs(c.events) do
			if e == key then
				return true
			end
		end
	end
	return false
end

local function isA(className, target)
	for _, c in ipairs(getChain(className)) do
		if c.name == target then
			return true
		end
	end
	return false
end

------------------------------------------------------------------------
-- Instance
------------------------------------------------------------------------
local D = setmetatable({}, { __mode = "k" })
local tagIndex = {} -- [tag] = { [inst] = true }
local tagSignals = {}
local allHumanoids = setmetatable({}, { __mode = "k" })
local InstMT = { __type = "Instance" }
local game -- DataModel
local Methods = {}
local ClassMethods = {}

local function newInstance(className)
	local inst = setmetatable({}, InstMT)
	D[inst] = {
		class = className,
		props = { Name = className },
		children = {},
		attrs = {},
		tags = {},
		signals = {},
		attrSignals = {},
		parent = nil,
		destroyed = false,
	}
	if className == "Humanoid" then
		allHumanoids[inst] = true
	end
	return inst
end
M.rawNew = newInstance

local function inDataModel(inst)
	local p = inst
	while p do
		if p == game then
			return true
		end
		p = D[p].parent
	end
	return false
end
M.inDataModel = inDataModel

local function getSignal(inst, name)
	local d = D[inst]
	if not d.signals[name] then
		d.signals[name] = newSignal(name)
	end
	return d.signals[name]
end
M.getSignal = getSignal

local function tagSignal(tag)
	if not tagSignals[tag] then
		tagSignals[tag] = newSignal("tag:" .. tag)
	end
	return tagSignals[tag]
end

local function eachDescendant(inst, fn)
	for _, c in ipairs(D[inst].children) do
		fn(c)
		eachDescendant(c, fn)
	end
end

local function fireTagsFor(inst)
	for tag in pairs(D[inst].tags) do
		tagSignal(tag):Fire(inst)
	end
end

local function setParent(inst, parent)
	local d = D[inst]
	if d.destroyed then
		error("The Parent property of " .. d.props.Name .. " is locked (destroyed)", 3)
	end
	if parent ~= nil and typeof(parent) ~= "Instance" then
		error("Parent must be an Instance, got " .. typeof(parent), 3)
	end
	if parent == inst then
		error("Attempt to set parent to self", 3)
	end
	local wasIn = inDataModel(inst)
	if d.parent then
		local siblings = D[d.parent].children
		for i, c in ipairs(siblings) do
			if c == inst then
				table.remove(siblings, i)
				break
			end
		end
	end
	d.parent = parent
	if parent then
		table.insert(D[parent].children, inst)
	end
	local isIn = inDataModel(inst)
	if isIn and not wasIn then
		fireTagsFor(inst)
		eachDescendant(inst, fireTagsFor)
	end
	if parent then
		getSignal(parent, "ChildAdded"):Fire(inst)
	end
end

local function fullName(inst)
	local parts = {}
	local p = inst
	while p and p ~= game do
		table.insert(parts, 1, D[p].props.Name)
		p = D[p].parent
	end
	return table.concat(parts, ".")
end

local validAttrTypes = {
	number = true, string = true, boolean = true, Vector3 = true, Color3 = true, CFrame = true,
	UDim2 = true, UDim = true, Vector2 = true, NumberRange = true, ["nil"] = true, EnumItem = true,
}

local function checkPropValue(className, key, ptype, value)
	if value == nil then
		if ptype == "Instance" or ptype == "any" then
			return
		end
		error(("Cannot set %s.%s to nil"):format(className, key), 4)
	end
	if ptype == "any" then
		return
	end
	local vt = typeof(value)
	local base, enumType = ptype:match("^(EnumItem):(%w+)$")
	if base then
		if vt ~= "EnumItem" or rawget(value, "_type") ~= enumType then
			error(("%s.%s expects Enum.%s, got %s"):format(className, key, enumType, tostring(value)), 4)
		end
		return
	end
	if vt ~= ptype then
		error(("%s.%s expects %s, got %s"):format(className, key, ptype, vt), 4)
	end
	if ptype == "number" and value ~= value then
		error(("%s.%s set to NaN"):format(className, key), 4)
	end
	if ptype == "Vector3" and (value._x ~= value._x or value._y ~= value._y or value._z ~= value._z) then
		error(("%s.%s set to NaN vector"):format(className, key), 4)
	end
	if ptype == "CFrame" then
		local p = value._p
		if p._x ~= p._x or p._y ~= p._y or p._z ~= p._z then
			error(("%s.%s set to NaN CFrame"):format(className, key), 4)
		end
	end
end

-- методы Instance
function Methods.FindFirstChild(inst, name, recursive)
	for _, c in ipairs(D[inst].children) do
		if D[c].props.Name == name then
			return c
		end
	end
	if recursive then
		for _, c in ipairs(D[inst].children) do
			local r = Methods.FindFirstChild(c, name, true)
			if r then
				return r
			end
		end
	end
	return nil
end
function Methods.FindFirstChildOfClass(inst, className)
	for _, c in ipairs(D[inst].children) do
		if D[c].class == className then
			return c
		end
	end
	return nil
end
function Methods.FindFirstChildWhichIsA(inst, className)
	for _, c in ipairs(D[inst].children) do
		if isA(D[c].class, className) then
			return c
		end
	end
	return nil
end
function Methods.FindFirstAncestor(inst, name)
	local p = D[inst].parent
	while p do
		if D[p].props.Name == name then
			return p
		end
		p = D[p].parent
	end
	return nil
end
function Methods.WaitForChild(inst, name, timeout)
	local c = Methods.FindFirstChild(inst, name)
	if c then
		return c
	end
	local limit = timeout or 15
	local waited = 0
	while waited < limit do
		waited = waited + task.wait(0.05)
		c = Methods.FindFirstChild(inst, name)
		if c then
			return c
		end
	end
	if not timeout then
		error("Infinite yield possible on " .. fullName(inst) .. ":WaitForChild(\"" .. name .. "\")", 2)
	end
	return nil
end
function Methods.GetChildren(inst)
	local list = {}
	for i, c in ipairs(D[inst].children) do
		list[i] = c
	end
	return list
end
function Methods.GetDescendants(inst)
	local list = {}
	eachDescendant(inst, function(c)
		table.insert(list, c)
	end)
	return list
end
function Methods.IsA(inst, className)
	return isA(D[inst].class, className)
end
function Methods.IsDescendantOf(inst, other)
	local p = D[inst].parent
	while p do
		if p == other then
			return true
		end
		p = D[p].parent
	end
	return false
end
function Methods.Destroy(inst)
	local d = D[inst]
	if d.destroyed then
		return
	end
	for _, c in ipairs(Methods.GetChildren(inst)) do
		Methods.Destroy(c)
	end
	if d.parent then
		setParent(inst, nil)
	end
	d.destroyed = true
	getSignal(inst, "Destroying"):Fire()
end
function Methods.ClearAllChildren(inst)
	for _, c in ipairs(Methods.GetChildren(inst)) do
		Methods.Destroy(c)
	end
end
function Methods.GetFullName(inst)
	return fullName(inst)
end
function Methods.SetAttribute(inst, name, value)
	if type(name) ~= "string" then
		error("SetAttribute: name must be string", 2)
	end
	if not validAttrTypes[typeof(value)] then
		error(("SetAttribute(%q): type %s is not supported"):format(name, typeof(value)), 2)
	end
	if type(value) == "number" and value ~= value then
		error("SetAttribute(" .. name .. ") NaN", 2)
	end
	local d = D[inst]
	local old = d.attrs[name]
	d.attrs[name] = value
	if old ~= value and d.attrSignals[name] then
		d.attrSignals[name]:Fire()
	end
end
function Methods.GetAttribute(inst, name)
	return D[inst].attrs[name]
end
function Methods.GetAttributes(inst)
	local t = {}
	for k, v in pairs(D[inst].attrs) do
		t[k] = v
	end
	return t
end
function Methods.GetAttributeChangedSignal(inst, name)
	local d = D[inst]
	if not d.attrSignals[name] then
		d.attrSignals[name] = newSignal("attr:" .. name)
	end
	return d.attrSignals[name]
end
function Methods.GetPropertyChangedSignal(inst, name)
	return newSignal("prop:" .. name)
end
function Methods.AddTag(inst, tag)
	local d = D[inst]
	if d.tags[tag] then
		return
	end
	d.tags[tag] = true
	tagIndex[tag] = tagIndex[tag] or setmetatable({}, { __mode = "k" })
	tagIndex[tag][inst] = true
	if inDataModel(inst) then
		tagSignal(tag):Fire(inst)
	end
end
function Methods.RemoveTag(inst, tag)
	D[inst].tags[tag] = nil
	if tagIndex[tag] then
		tagIndex[tag][inst] = nil
	end
end
function Methods.HasTag(inst, tag)
	return D[inst].tags[tag] == true
end
function Methods.Clone(inst)
	error("Clone not supported in mock")
end

-- PVInstance / Model
local function allParts(inst)
	local list = {}
	if isA(D[inst].class, "BasePart") then
		table.insert(list, inst)
	end
	eachDescendant(inst, function(c)
		if isA(D[c].class, "BasePart") then
			table.insert(list, c)
		end
	end)
	return list
end
local function getPivot(inst)
	local d = D[inst]
	if isA(d.class, "BasePart") then
		return d.props.CFrame or CFrame.new()
	end
	local pp = d.props.PrimaryPart
	if pp then
		return D[pp].props.CFrame or CFrame.new()
	end
	local parts = allParts(inst)
	if #parts > 0 then
		return D[parts[1]].props.CFrame or CFrame.new()
	end
	return CFrame.new()
end
function Methods.GetPivot(inst)
	if not isA(D[inst].class, "PVInstance") then
		error("GetPivot is not a valid member of " .. D[inst].class, 2)
	end
	return getPivot(inst)
end
function Methods.PivotTo(inst, target)
	if not isA(D[inst].class, "PVInstance") then
		error("PivotTo is not a valid member of " .. D[inst].class, 2)
	end
	if typeof(target) ~= "CFrame" then
		error("PivotTo expects CFrame, got " .. typeof(target), 2)
	end
	local tp = target._p
	if tp._x ~= tp._x or tp._y ~= tp._y or tp._z ~= tp._z then
		error("PivotTo with NaN CFrame", 2)
	end
	for _, x in ipairs(target._r) do
		if x ~= x then
			error("PivotTo with NaN rotation", 2)
		end
	end
	local pv = getPivot(inst)
	for _, x in ipairs(pv._r) do
		if x ~= x then
			error("PivotTo: current pivot of " .. fullName(inst) .. " has NaN rotation", 2)
		end
	end
	local delta = target * cfInverse(getPivot(inst))
	for _, p in ipairs(allParts(inst)) do
		local pd = D[p]
		local newCf = M.orthonormalize(delta * (pd.props.CFrame or CFrame.new()))
		if newCf._p._x ~= newCf._p._x then
			error("PivotTo produced NaN for " .. fullName(p) .. " old=" .. tostring(pd.props.CFrame) .. " target=" .. tostring(target), 2)
		end
		pd.props.CFrame = newCf
	end
end

ClassMethods.BasePart = {
	SetNetworkOwner = function(inst, owner)
		if not inDataModel(inst) then
			error("SetNetworkOwner: part must be in workspace", 2)
		end
	end,
	GetMass = function()
		return 1
	end,
}

ClassMethods.Humanoid = {
	MoveTo = function(h, pos)
		if typeof(pos) ~= "Vector3" then
			error("MoveTo expects Vector3", 2)
		end
		if pos._x ~= pos._x or pos._y ~= pos._y or pos._z ~= pos._z then
			error("MoveTo with NaN position", 2)
		end
		D[h].moveTarget = pos
	end,
	EquipTool = function(h, tool)
		local char = D[h].parent
		setParent(tool, char)
	end,
	UnequipTools = function() end,
	AddAccessory = function(h, acc)
		if D[acc].class ~= "Accessory" then
			error("AddAccessory expects Accessory", 2)
		end
		setParent(acc, D[h].parent)
	end,
	SetStateEnabled = function(h, state, on)
		if typeof(state) ~= "EnumItem" then
			error("SetStateEnabled expects Enum", 2)
		end
	end,
	GetState = function()
		return Enum.HumanoidStateType.Running
	end,
	ChangeState = function() end,
	TakeDamage = function(h, amount)
		local d = D[h]
		d.props.Health = (d.props.Health or 100) - amount
		if d.props.Health <= 0 then
			getSignal(h, "Died"):Fire()
		end
	end,
	LoadAnimation = function(h, anim)
		return ClassMethods.Animator.LoadAnimation(h, anim)
	end,
}

ClassMethods.Animator = {
	LoadAnimation = function(a, anim)
		if not anim or D[anim].class ~= "Animation" then
			error("LoadAnimation expects Animation", 2)
		end
		local track = { IsPlaying = false, Looped = true }
		function track.Play(self)
			self.IsPlaying = true
		end
		function track.Stop(self)
			self.IsPlaying = false
		end
		function track.AdjustSpeed() end
		return track
	end,
}

ClassMethods.Sound = {
	Play = function(s)
		D[s].props.Playing = true
	end,
	Stop = function(s)
		D[s].props.Playing = false
	end,
	Pause = function(s)
		D[s].props.Playing = false
	end,
	Resume = function(s)
		D[s].props.Playing = true
	end,
}

ClassMethods.ParticleEmitter = {
	Emit = function(e, n)
		checkNum(n, "Emit")
	end,
	Clear = function() end,
}

ClassMethods.RemoteEvent = {
	FireServer = function(r, ...)
		local owner = currentOwner
		if not owner then
			error("FireServer called from server", 2)
		end
		M.remoteLog = M.remoteLog or {}
		table.insert(M.remoteLog, { name = D[r].props.Name, dir = "toServer", args = { ... } })
		getSignal(r, "OnServerEvent"):FireFor(nil, owner, ...)
	end,
	FireClient = function(r, player, ...)
		if currentOwner then
			error("FireClient called from client", 2)
		end
		if typeof(player) ~= "Instance" or D[player].class ~= "Player" then
			error("FireClient: first arg must be Player", 2)
		end
		M.checkRemoteArgs(...)
		getSignal(r, "OnClientEvent"):FireFor(player, ...)
	end,
	FireAllClients = function(r, ...)
		if currentOwner then
			error("FireAllClients called from client", 2)
		end
		M.checkRemoteArgs(...)
		for _, p in ipairs(M.Players:GetPlayers()) do
			getSignal(r, "OnClientEvent"):FireFor(p, ...)
		end
	end,
}

function M.checkRemoteArgs(...)
	local args = table.pack(...)
	for i = 1, args.n do
		local v = args[i]
		local t = typeof(v)
		if t == "function" or t == "thread" then
			error("Cannot send " .. t .. " through a RemoteEvent", 3)
		end
		if t == "table" then
			for k, val in pairs(v) do
				if type(val) == "function" then
					error("Cannot send table containing function through a RemoteEvent", 3)
				end
			end
		end
	end
end

ClassMethods.Player = {
	LoadCharacter = function(p)
		local d = D[p]
		if d.props.Character then
			Methods.Destroy(d.props.Character)
		end
		local char = M.makeCharacter(d.props.Name)
		d.props.Character = char
		setParent(char, M.workspace)
		-- новый рюкзак
		local bp = Methods.FindFirstChild(p, "Backpack")
		if bp then
			Methods.Destroy(bp)
		end
		local nb = newInstance("Backpack")
		D[nb].props.Name = "Backpack"
		setParent(nb, p)
		getSignal(p, "CharacterAdded"):Fire(char)
	end,
	Kick = function() end,
}

ClassMethods.Model = {
	ScaleTo = function() end,
}

ClassMethods.Tool = {}

------------------------------------------------------------------------
-- Метатаблица Instance
------------------------------------------------------------------------
local function findClassMethod(className, key)
	for _, c in ipairs(getChain(className)) do
		local cm = ClassMethods[c.name]
		if cm and cm[key] then
			return cm[key]
		end
	end
	return nil
end

InstMT.__index = function(inst, key)
	local d = D[inst]
	if not d then
		error("indexing non-instance", 2)
	end
	if key == "Parent" then
		return d.parent
	elseif key == "ClassName" then
		return d.class
	elseif key == "Name" then
		return d.props.Name
	end
	if d.getters and d.getters[key] then
		return d.getters[key](inst)
	end
	local cm = findClassMethod(d.class, key)
	if cm then
		return cm
	end
	if Methods[key] then
		return Methods[key]
	end
	if key == "Position" and isA(d.class, "BasePart") then
		return (d.props.CFrame or CFrame.new()).Position
	end
	if key == "Character" and d.class == "Player" then
		return d.props.Character
	end
	if key == "IsPlaying" and d.class == "Sound" then
		return d.props.Playing == true
	end
	local pt = propType(d.class, key)
	if pt then
		local v = d.props[key]
		if v == nil then
			v = propDefault(d.class, key)
			if key == "CFrame" and v == nil and isA(d.class, "BasePart") then
				v = CFrame.new()
			end
		end
		return v
	end
	if hasEvent(d.class, key) then
		return getSignal(inst, key)
	end
	local child = Methods.FindFirstChild(inst, key)
	if child then
		return child
	end
	error(("%s is not a valid member of %s \"%s\""):format(tostring(key), d.class, fullName(inst)), 2)
end

InstMT.__newindex = function(inst, key, value)
	local d = D[inst]
	if key == "Parent" then
		setParent(inst, value)
		return
	end
	if d.setters and d.setters[key] then
		d.setters[key](inst, value)
		return
	end
	if key == "Position" and isA(d.class, "BasePart") then
		checkPropValue(d.class, key, "Vector3", value)
		local old = d.props.CFrame or CFrame.new()
		d.props.CFrame = cf(value._x, value._y, value._z, old._r)
		return
	end
	local pt = propType(d.class, key)
	if not pt then
		error(("%s is not a valid property of %s \"%s\""):format(tostring(key), d.class, fullName(inst)), 2)
	end
	checkPropValue(d.class, key, pt, value)
	if key == "Character" and d.class == "Player" then
		d.props.Character = value
		if value then
			getSignal(inst, "CharacterAdded"):Fire(value)
		end
		return
	end
	if key == "Health" and d.class == "Humanoid" then
		d.props.Health = value
		if value <= 0 then
			getSignal(inst, "Died"):Fire()
		end
		return
	end
	if key == "Value" and isA(d.class, "ValueBase") then
		d.props.Value = value
		getSignal(inst, "Changed"):Fire(value)
		return
	end
	d.props[key] = value
end

InstMT.__tostring = function(inst)
	return D[inst].props.Name
end

local Instance = {
	new = function(className, parent)
		if not creatable[className] then
			error("Unable to create an Instance of type \"" .. tostring(className) .. "\"", 2)
		end
		local inst = newInstance(className)
		if parent then
			setParent(inst, parent)
		end
		return inst
	end,
}

------------------------------------------------------------------------
-- Персонажи
------------------------------------------------------------------------
function M.makeCharacter(name)
	local model = newInstance("Model")
	D[model].props.Name = name
	local root = newInstance("Part")
	D[root].props.Name = "HumanoidRootPart"
	D[root].props.Size = Vector3.new(2, 2, 1)
	D[root].props.CFrame = CFrame.new(0, 3, 0)
	setParent(root, model)
	local head = newInstance("Part")
	D[head].props.Name = "Head"
	D[head].props.Size = Vector3.new(1.2, 1.2, 1.2)
	D[head].props.CFrame = CFrame.new(0, 4.6, 0)
	setParent(head, model)
	local att = newInstance("Attachment")
	D[att].props.Name = "HatAttachment"
	setParent(att, head)
	local torso = newInstance("Part")
	D[torso].props.Name = "UpperTorso"
	D[torso].props.CFrame = CFrame.new(0, 3.5, 0)
	setParent(torso, model)
	local hum = newInstance("Humanoid")
	setParent(hum, model)
	local animator = newInstance("Animator")
	setParent(animator, hum)
	D[model].props.PrimaryPart = root
	return model
end

-- простая "физика": движение гуманоидов к цели MoveTo
table.insert(signalsStepped, function(dt)
	for h in pairs(allHumanoids) do
		local d = D[h]
		local model = d.parent
		if d.moveTarget and model and not d.destroyed then
			local root = Methods.FindFirstChild(model, "HumanoidRootPart")
			if root then
				local pos = (D[root].props.CFrame or CFrame.new()).Position
				local target = d.moveTarget
				local delta = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
				local dist = delta.Magnitude
				local speed = d.props.WalkSpeed or 16
				if dist < 0.5 or speed <= 0 then
					d.moveTarget = nil
					D[root].props.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
					getSignal(h, "MoveToFinished"):Fire(true)
					getSignal(h, "Running"):Fire(0)
				else
					local stepLen = math.min(dist, speed * dt)
					if pos.X ~= pos.X or stepLen ~= stepLen then
						error(("NaN move: pos=%s target=%s speed=%s model=%s"):format(tostring(pos), tostring(target), tostring(speed), fullName(model)))
					end
					local dir = delta.Unit
					local newPos = pos + dir * stepLen
					Methods.PivotTo(model, CFrame.lookAt(newPos, newPos + dir))
					D[root].props.AssemblyLinearVelocity = dir * speed
					getSignal(h, "Running"):Fire(speed)
				end
			end
		end
	end
end)

------------------------------------------------------------------------
-- Сервисы
------------------------------------------------------------------------
local function service(className, name)
	local s = newInstance(className)
	D[s].props.Name = name or className
	setParent(s, game)
	return s
end

game = newInstance("DataModel")
D[game].props.Name = "Game"
M.game = game

local workspace = service("Workspace", "Workspace")
M.workspace = workspace
local Players = service("Players", "Players")
M.Players = Players
local ReplicatedStorage = service("ReplicatedStorage")
local ServerScriptService = service("ServerScriptService")
local ServerStorage = service("ServerStorage")
local StarterPlayer = service("StarterPlayer")
local StarterPlayerScripts = newInstance("StarterPlayerScripts")
D[StarterPlayerScripts].props.Name = "StarterPlayerScripts"
setParent(StarterPlayerScripts, StarterPlayer)
local Lighting = service("Lighting")
local SoundService = service("SoundService")
local StarterGui = service("StarterGui")
M.ReplicatedStorage = ReplicatedStorage
M.ServerScriptService = ServerScriptService
M.StarterPlayerScripts = StarterPlayerScripts
M.Lighting = Lighting

local baseplate = newInstance("Part")
D[baseplate].props.Name = "Baseplate"
D[baseplate].props.Anchored = true
setParent(baseplate, workspace)
local spawnLoc = newInstance("SpawnLocation")
D[spawnLoc].props.Name = "SpawnLocation"
setParent(spawnLoc, workspace)

-- Players
D[Players].getters = {
	LocalPlayer = function()
		if not currentOwner then
			error("LocalPlayer accessed on server", 3)
		end
		return currentOwner
	end,
}
ClassMethods.Players = {
	GetPlayers = function(ps)
		local list = {}
		for _, c in ipairs(D[ps].children) do
			if D[c].class == "Player" then
				table.insert(list, c)
			end
		end
		return list
	end,
	GetPlayerFromCharacter = function(ps, model)
		if model == nil then
			return nil
		end
		for _, c in ipairs(D[ps].children) do
			if D[c].class == "Player" and D[c].props.Character == model then
				return c
			end
		end
		return nil
	end,
	CreateHumanoidModelFromDescription = function(ps, desc, rig)
		if D[desc].class ~= "HumanoidDescription" then
			error("expects HumanoidDescription", 2)
		end
		if typeof(rig) ~= "EnumItem" then
			error("expects rig type", 2)
		end
		task.wait(0.1)
		return M.makeCharacter("NPC")
	end,
}

local nextUserId = 1000
function M.addPlayer(name, localeId)
	local p = newInstance("Player")
	D[p].props.Name = name
	D[p].props.DisplayName = name
	D[p].props.LocaleId = localeId or "en-us"
	nextUserId = nextUserId + 1
	D[p].props.UserId = nextUserId
	local bp = newInstance("Backpack")
	D[bp].props.Name = "Backpack"
	setParent(bp, p)
	local pg = newInstance("PlayerGui")
	D[pg].props.Name = "PlayerGui"
	setParent(pg, p)
	setParent(p, Players)
	getSignal(Players, "PlayerAdded"):Fire(p)
	return p
end

function M.removePlayer(p)
	getSignal(Players, "PlayerRemoving"):Fire(p)
	local char = D[p].props.Character
	if char then
		Methods.Destroy(char)
	end
	setParent(p, nil)
end

-- Workspace
ClassMethods.Workspace = {
	Raycast = function(ws, origin, direction, params)
		if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
			error("Raycast expects Vector3", 2)
		end
		if params ~= nil and typeof(params) ~= "RaycastParams" then
			error("Raycast params must be RaycastParams", 2)
		end
		if M.raycastHook then
			return M.raycastHook(origin, direction, params)
		end
		return nil
	end,
}

local RaycastParamsMT = { __type = "RaycastParams" }
RaycastParamsMT.__index = function(t, k)
	error("RaycastParams has no member " .. tostring(k), 2)
end
RaycastParamsMT.__newindex = function(t, k, v)
	local allowed = { FilterType = true, FilterDescendantsInstances = true, RespectCanCollide = true, IgnoreWater = true, CollisionGroup = true }
	if not allowed[k] then
		error("RaycastParams has no property " .. tostring(k), 2)
	end
	if k == "FilterDescendantsInstances" then
		for _, inst in ipairs(v) do
			if typeof(inst) ~= "Instance" then
				error("FilterDescendantsInstances must contain Instances, got " .. typeof(inst), 2)
			end
		end
	end
	rawset(t, "_" .. k, v)
end
local RaycastParams = {
	new = function()
		return setmetatable({}, RaycastParamsMT)
	end,
}

-- Сервисы без экземпляров в дереве
local services = {
	Workspace = workspace,
	Players = Players,
	ReplicatedStorage = ReplicatedStorage,
	ServerScriptService = ServerScriptService,
	ServerStorage = ServerStorage,
	StarterPlayer = StarterPlayer,
	Lighting = Lighting,
	SoundService = SoundService,
	StarterGui = StarterGui,
}

local function plainService(name, members)
	local s = setmetatable({}, {
		__type = "Instance",
		__index = function(_, k)
			local v = members[k]
			if v == nil then
				error(k .. " is not a valid member of " .. name, 2)
			end
			return v
		end,
		__newindex = function(_, k)
			error("cannot set " .. k .. " on " .. name, 2)
		end,
	})
	services[name] = s
	return s
end

plainService("CollectionService", {
	GetTagged = function(_, tag)
		local list = {}
		for inst in pairs(tagIndex[tag] or {}) do
			if inDataModel(inst) and D[inst].tags[tag] then
				table.insert(list, inst)
			end
		end
		return list
	end,
	GetInstanceAddedSignal = function(_, tag)
		return tagSignal(tag)
	end,
	AddTag = function(_, inst, tag)
		Methods.AddTag(inst, tag)
	end,
	HasTag = function(_, inst, tag)
		return Methods.HasTag(inst, tag)
	end,
})

local heartbeat = newSignal("Heartbeat")
local renderStepped = newSignal("RenderStepped")
local stepped = newSignal("Stepped")
table.insert(signalsStepped, function(dt)
	stepped:Fire(now, dt)
	heartbeat:Fire(dt)
	renderStepped:Fire(dt)
end)
plainService("RunService", {
	Heartbeat = heartbeat,
	RenderStepped = renderStepped,
	Stepped = stepped,
	IsServer = function()
		return currentOwner == nil
	end,
	IsClient = function()
		return currentOwner ~= nil
	end,
	IsStudio = function()
		return true
	end,
})

local pathMT = { __type = "Instance" }
plainService("PathfindingService", {
	CreatePath = function(_, params)
		if type(params) ~= "table" then
			error("CreatePath expects table", 2)
		end
		local path = { Status = Enum.PathStatus.NoPath, _wps = {} }
		function path.ComputeAsync(self, from, to)
			if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" then
				error("ComputeAsync expects Vector3", 2)
			end
			task.wait(0.02)
			self.Status = Enum.PathStatus.Success
			self._wps = {}
			for i = 0, 3 do
				local p = from:Lerp(to, i / 3)
				table.insert(self._wps, { Position = p, Action = Enum.PathWaypointAction.Walk })
			end
		end
		function path.GetWaypoints(self)
			return self._wps
		end
		return path
	end,
})

M.dataStoreData = {}
M.dataStoreFail = false
plainService("DataStoreService", {
	GetDataStore = function(_, name)
		if type(name) ~= "string" then
			error("GetDataStore expects string", 2)
		end
		local store = {}
		function store.GetAsync(self, key)
			task.wait(0.05)
			if M.dataStoreFail then
				error("Studio access to APIs is not allowed")
			end
			return M.deepCopy(M.dataStoreData[key])
		end
		function store.SetAsync(self, key, value)
			task.wait(0.05)
			if M.dataStoreFail then
				error("Studio access to APIs is not allowed")
			end
			M.checkSerializable(value, key)
			M.dataStoreData[key] = M.deepCopy(value)
		end
		return store
	end,
})

function M.deepCopy(v)
	if type(v) ~= "table" then
		return v
	end
	local t = {}
	for k, val in pairs(v) do
		t[k] = M.deepCopy(val)
	end
	return t
end

function M.checkSerializable(v, path)
	local t = typeof(v)
	if t == "table" then
		for k, val in pairs(v) do
			if type(k) ~= "string" and type(k) ~= "number" then
				error("DataStore: bad key type at " .. path)
			end
			M.checkSerializable(val, path .. "." .. tostring(k))
		end
	elseif t ~= "number" and t ~= "string" and t ~= "boolean" and t ~= "nil" then
		error("DataStore: cannot store " .. t .. " at " .. path)
	end
end

plainService("TweenService", {
	Create = function(_, inst, info, goals)
		if typeof(inst) ~= "Instance" then
			error("TweenService:Create expects Instance", 2)
		end
		if typeof(info) ~= "TweenInfo" then
			error("TweenService:Create expects TweenInfo", 2)
		end
		for k, v in pairs(goals) do
			local pt = propType(D[inst].class, k)
			if not pt then
				error("Tween: " .. k .. " is not a property of " .. D[inst].class, 2)
			end
			checkPropValue(D[inst].class, k, pt, v)
		end
		local tween = { Completed = newSignal("Completed") }
		function tween.Play(self)
			task.delay(rawget(info, "_f").Time, function()
				if not D[inst].destroyed then
					for k, v in pairs(goals) do
						inst[k] = v
					end
				end
				self.Completed:Fire(Enum.PlaybackState.Completed)
			end)
		end
		function tween.Cancel() end
		function tween.Pause() end
		return tween
	end,
})

plainService("Debris", {
	AddItem = function(_, inst, t)
		task.delay(t or 10, function()
			Methods.Destroy(inst)
		end)
	end,
})

M.inputBegan = newSignal("InputBegan")
M.inputEnded = newSignal("InputEnded")
plainService("UserInputService", {
	InputBegan = M.inputBegan,
	InputEnded = M.inputEnded,
	TouchEnabled = false,
	KeyboardEnabled = true,
	GamepadEnabled = false,
})

ClassMethods.StarterGui = {
	SetCore = function(sg, name, value)
		if type(name) ~= "string" then
			error("SetCore expects string", 2)
		end
	end,
	SetCoreGuiEnabled = function() end,
}

ClassMethods.SoundService = {
	PlayLocalSound = function() end,
}

M.closeCallbacks = {}
ClassMethods.DataModel = {
	GetService = function(g, name)
		local s = services[name]
		if not s then
			error("Unknown service " .. tostring(name), 2)
		end
		return s
	end,
	BindToClose = function(g, fn)
		table.insert(M.closeCallbacks, fn)
	end,
}

------------------------------------------------------------------------
-- Окружение скриптов
------------------------------------------------------------------------
local mathx = {}
for k, v in pairs(math) do
	mathx[k] = v
end
mathx.clamp = function(x, a, b)
	checkNum(x, "math.clamp")
	if a > b then
		error("math.clamp: max < min", 2)
	end
	return math.max(a, math.min(b, x))
end
mathx.round = function(x)
	return math.floor(x + 0.5)
end
mathx.sign = function(x)
	if x > 0 then
		return 1
	elseif x < 0 then
		return -1
	end
	return 0
end
mathx.atan2 = function(y, x)
	return math.atan(y, x)
end
mathx.pow = function(a, b)
	return a ^ b
end
mathx.huge = math.huge
-- Luau: math.floor возвращает число; в Lua 5.4 целое — это совместимо

local tablex = {}
for k, v in pairs(table) do
	tablex[k] = v
end
tablex.find = function(t, v)
	for i, x in ipairs(t) do
		if x == v then
			return i
		end
	end
	return nil
end
tablex.clear = function(t)
	for k in pairs(t) do
		t[k] = nil
	end
end

local osx = {
	clock = function()
		return now
	end,
	time = function()
		return math.floor(now)
	end,
	date = os.date,
}

local stringx = {}
for k, v in pairs(string) do
	stringx[k] = v
end
-- В Luau %d с дробным числом падает — эмулируем строгую проверку
stringx.format = function(fmt, ...)
	local args = table.pack(...)
	local i = 0
	for spec in fmt:gmatch("%%[-+ #0]*%d*%.?%d*([%a%%])") do
		if spec ~= "%" then
			i = i + 1
			if spec == "d" or spec == "i" then
				local v = args[i]
				if type(v) ~= "number" or v ~= math.floor(v) then
					error("string.format: %d expects integer, got " .. tostring(v), 2)
				end
				args[i] = math.floor(v)
			end
		end
	end
	return string.format(fmt, table.unpack(args, 1, args.n))
end
-- метод "x":format(...) использует string metatable — подменим
getmetatable("").__index = stringx

local G = {
	print = function(...)
		local t = {}
		for i, v in ipairs({ ... }) do
			t[i] = tostring(v)
		end
		table.insert(M.logs, table.concat(t, " "))
	end,
	warn = function(...)
		local t = {}
		for i, v in ipairs({ ... }) do
			t[i] = tostring(v)
		end
		table.insert(M.warnings, table.concat(t, " "))
	end,
	error = error,
	assert = assert,
	pcall = pcall,
	xpcall = xpcall,
	type = type,
	typeof = typeof,
	tostring = tostring,
	tonumber = tonumber,
	pairs = pairs,
	ipairs = ipairs,
	next = next,
	select = select,
	unpack = table.unpack,
	rawget = rawget,
	rawset = rawset,
	rawequal = rawequal,
	setmetatable = setmetatable,
	getmetatable = getmetatable,
	math = mathx,
	table = tablex,
	string = stringx,
	os = osx,
	coroutine = coroutine,
	utf8 = utf8,
	task = task,
	tick = function()
		return now
	end,
	wait = task.wait,
	delay = task.delay,
	spawn = task.spawn,
	game = game,
	workspace = workspace,
	Instance = Instance,
	Vector3 = Vector3,
	Vector2 = Vector2,
	CFrame = CFrame,
	Color3 = Color3,
	UDim = UDim,
	UDim2 = UDim2,
	NumberSequence = NumberSequence,
	NumberSequenceKeypoint = NumberSequenceKeypoint,
	ColorSequence = ColorSequence,
	ColorSequenceKeypoint = ColorSequenceKeypoint,
	NumberRange = NumberRange,
	TweenInfo = TweenInfo,
	RaycastParams = RaycastParams,
	Enum = Enum,
}
M.G = G

local moduleCache = {}
local sources = {}

local function makeEnv(scriptInst)
	local env = setmetatable({ script = scriptInst }, {
		__index = function(_, k)
			local v = G[k]
			if v == nil then
				if k == "require" then
					return M.require
				end
				error("Unknown global '" .. tostring(k) .. "' (опечатка или забытый local?)", 2)
			end
			return v
		end,
		__newindex = function(_, k, v)
			error("Assignment to global '" .. tostring(k) .. "' (забыт local?)", 2)
		end,
	})
	return env
end

local function loadSource(scriptInst)
	local path = sources[scriptInst]
	if not path then
		error("No source for " .. fullName(scriptInst))
	end
	local f = assert(io.open(path, "r"))
	local src = f:read("a")
	f:close()
	local chunk, err = load(src, "@" .. path, "t", makeEnv(scriptInst))
	if not chunk then
		error("SYNTAX: " .. err)
	end
	return chunk
end

function M.require(moduleInst)
	if typeof(moduleInst) ~= "Instance" or D[moduleInst].class ~= "ModuleScript" then
		error("require expects ModuleScript", 2)
	end
	if moduleCache[moduleInst] == nil then
		moduleCache[moduleInst] = "loading"
		local chunk = loadSource(moduleInst)
		local result = chunk()
		if result == nil then
			error("Module " .. fullName(moduleInst) .. " did not return a value")
		end
		moduleCache[moduleInst] = result
	elseif moduleCache[moduleInst] == "loading" then
		error("Recursive require of " .. fullName(moduleInst))
	end
	return moduleCache[moduleInst]
end

function M.addScript(className, name, parent, path)
	local s = newInstance(className)
	D[s].props.Name = name
	sources[s] = path
	setParent(s, parent)
	return s
end

function M.runScript(scriptInst, owner)
	local chunk = loadSource(scriptInst)
	return spawnAs(owner, chunk)
end

function M.runAs(owner, fn, ...)
	return spawnAs(owner, fn, ...)
end

function M.syntaxCheck(path)
	local f = assert(io.open(path, "r"))
	local src = f:read("a")
	f:close()
	local chunk, err = load(src, "@" .. path, "t", {})
	return chunk ~= nil, err
end

-- доступ к внутренностям для тестов
M.D = D
M.Enum = Enum
M.Vector3 = Vector3
M.CFrame = CFrame
M.Methods = Methods
M.CollectionService = services.CollectionService

return M
