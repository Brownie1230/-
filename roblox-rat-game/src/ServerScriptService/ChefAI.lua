-- ChefAI (ModuleScript) — ServerScriptService
-- Повар-робот: играет за повара, если людей мало.
-- Видит крыс перед собой (за столами и стенами можно спрятаться!),
-- слышит поломки, писк и мышеловки, гонится, ловит, чинит, ставит мышеловки,
-- злится во время тревоги и патрулирует точки с тегом "PatrolPoint".

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Locale = require(ReplicatedStorage:WaitForChild("Locale"))

local ChefAI = {}
local ctx, Sabotage, Chef
local npc = nil
local running = false
local generation = 0
local spawnCFrame = CFrame.new(0, 5, 0)
local skipUntil = {} -- предметы, до которых не получилось дойти
local alertPos = nil
local alertTime = 0

local AGENT = { AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 4 }
local ANIM_WALK = "rbxassetid://507777826" -- стандартная R15 ходьба
local ANIM_IDLE = "rbxassetid://507766388" -- стандартная R15 стойка
local OFFSETS = {
	Vector3.new(0, 0, 0),
	Vector3.new(6, 0, 0),
	Vector3.new(-6, 0, 0),
	Vector3.new(0, 0, 6),
	Vector3.new(0, 0, -6),
}

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true -- сквозь невидимые/некасаемые детали видно

local function getRoot(model)
	return model and model:FindFirstChild("HumanoidRootPart")
end

local function buildNPC()
	local desc = Instance.new("HumanoidDescription")
	local skin = Color3.fromRGB(234, 184, 146)
	desc.HeadColor = skin
	desc.LeftArmColor = skin
	desc.RightArmColor = skin
	desc.TorsoColor = Color3.fromRGB(245, 245, 245)
	desc.LeftLegColor = Color3.fromRGB(50, 50, 60)
	desc.RightLegColor = Color3.fromRGB(50, 50, 60)

	local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	model.Name = "ChefNPC"
	model:PivotTo(spawnCFrame)
	model.Parent = workspace

	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.WalkSpeed = Config.AIChefWalkSpeed
	hum.DisplayName = "🤖 Chef Bot"
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	Chef.dressChef(model)
	getRoot(model):SetNetworkOwner(nil)

	-- робот держит сачок
	local net = Chef.makeNetTool()
	net.Parent = model
	hum:EquipTool(net)

	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end
	local walkAnim = Instance.new("Animation")
	walkAnim.AnimationId = ANIM_WALK
	local idleAnim = Instance.new("Animation")
	idleAnim.AnimationId = ANIM_IDLE
	local walk = animator:LoadAnimation(walkAnim)
	local idle = animator:LoadAnimation(idleAnim)
	idle:Play()
	hum.Running:Connect(function(speed)
		if speed > 0.5 then
			if not walk.IsPlaying then
				walk:Play(0.2)
				idle:Stop(0.2)
			end
		elseif not idle.IsPlaying then
			idle:Play(0.2)
			walk:Stop(0.2)
		end
	end)
	return model
end

local function canSee(root, ratChar)
	local ratRoot = getRoot(ratChar)
	if not ratRoot then
		return false
	end
	local eye = root.Position + Vector3.new(0, 1.5, 0)
	local delta = ratRoot.Position - eye
	local dist = delta.Magnitude
	if dist > Config.AISightRange then
		return false
	end
	-- далеко видит только то, что впереди; вблизи "слышит" со всех сторон
	if dist > 12 then
		local flat = Vector3.new(delta.X, 0, delta.Z)
		if flat.Magnitude > 0.01 and root.CFrame.LookVector:Dot(flat.Unit) < 0.1 then
			return false
		end
	end
	rayParams.FilterDescendantsInstances = { npc, ratChar }
	return workspace:Raycast(eye, delta, rayParams) == nil
end

local function findTarget()
	local root = getRoot(npc)
	if not root then
		return nil
	end
	local best, bestDist = nil, math.huge
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("Role") == "Rat" and not p:GetAttribute("Caught") and p.Character then
			local r = getRoot(p.Character)
			if r and canSee(root, p.Character) then
				local d = (r.Position - root.Position).Magnitude
				if d < bestDist then
					best, bestDist = p, d
				end
			end
		end
	end
	return best
end

local function computePath(from, to)
	local path = PathfindingService:CreatePath(AGENT)
	local ok = pcall(function()
		path:ComputeAsync(from, to)
	end)
	if ok and path.Status == Enum.PathStatus.Success then
		return path
	end
	return nil
end

local function updateSpeed(hum)
	local speed = Config.AIChefWalkSpeed
	if (ReplicatedStorage:GetAttribute("Chaos") or 0) >= Config.AlarmChaos then
		speed = speed + Config.ChefRageBonus
	end
	hum.WalkSpeed = speed
end

-- Идти к точке по пути. abort() => true прерывает (например, увидел крысу)
local function walkTo(target, alive, abort)
	local root = getRoot(npc)
	local hum = npc and npc:FindFirstChildOfClass("Humanoid")
	if not root or not hum then
		return
	end

	local path = nil
	for _, off in ipairs(OFFSETS) do
		path = computePath(root.Position, Vector3.new(target.X, 1, target.Z) + off)
		if path then
			break
		end
	end
	if not path then
		hum:MoveTo(target)
		task.wait(1)
		return
	end

	for _, wp in ipairs(path:GetWaypoints()) do
		if not alive() then
			return
		end
		if wp.Action == Enum.PathWaypointAction.Jump then
			hum.Jump = true
		end
		hum:MoveTo(wp.Position)
		local started = os.clock()
		local lastPos = root.Position
		local stuckTime = 0
		while os.clock() - started < 2 do
			local flat = (root.Position - wp.Position) * Vector3.new(1, 0, 1)
			if flat.Magnitude < 2.5 then
				break
			end
			if not alive() or (abort and abort()) then
				return
			end
			task.wait(0.1)
			-- застрял? подпрыгнуть
			if (root.Position - lastPos).Magnitude < 0.05 then
				stuckTime = stuckTime + 0.1
				if stuckTime > 0.8 then
					hum.Jump = true
					stuckTime = 0
				end
			else
				stuckTime = 0
			end
			lastPos = root.Position
		end
	end
end

local function nearestStation(list, pos)
	local best, bestDist = nil, math.huge
	for _, st in ipairs(list) do
		if (skipUntil[st] or 0) < os.clock() then
			local d = (st.Position - pos).Magnitude
			if d < bestDist then
				best, bestDist = st, d
			end
		end
	end
	return best
end

local function brain(myGen)
	local function alive()
		return running and generation == myGen and npc ~= nil and npc.Parent ~= nil
	end
	local lastSeen = nil

	while running and generation == myGen do
		-- робот упал с карты / умер: создаём заново
		local hum = npc and npc:FindFirstChildOfClass("Humanoid")
		if not npc or not npc.Parent or not hum or hum.Health <= 0 then
			if npc then
				npc:Destroy()
				npc = nil
			end
			task.wait(2)
			if not running or generation ~= myGen then
				break
			end
			local model = buildNPC()
			if generation ~= myGen then
				model:Destroy()
				break
			end
			npc = model
			hum = npc:FindFirstChildOfClass("Humanoid")
		end
		local root = getRoot(npc)
		updateSpeed(hum)

		local target = findTarget()
		local tRoot = nil
		if target then
			tRoot = getRoot(target.Character)
		end
		if tRoot then
			lastSeen = tRoot.Position
			if (tRoot.Position - root.Position).Magnitude <= Config.CatchRange - 1 then
				ctx.fxAll("swing", root.Position)
				Chef.catchRat(target, nil)
				lastSeen = nil
				task.wait(1)
			else
				hum:MoveTo(tRoot.Position)
				task.wait(0.15)
			end
		elseif lastSeen then
			-- проверить место, где последний раз видел крысу
			local pos = lastSeen
			lastSeen = nil
			walkTo(pos, alive, findTarget)
		elseif alertPos and os.clock() - alertTime < 20 then
			-- услышал шум
			local pos = alertPos
			alertPos = nil
			walkTo(pos, alive, findTarget)
		else
			local st = nearestStation(Sabotage.getBroken(), root.Position)
			if st then
				walkTo(st.Position, alive, findTarget)
				if alive() and st:GetAttribute("Broken") and (st.Position - root.Position).Magnitude < 10 then
					hum:MoveTo(root.Position)
					local interrupted = false
					local t0 = os.clock()
					while os.clock() - t0 < Config.AIRepairTime do
						task.wait(0.2)
						if not alive() or findTarget() then
							interrupted = true
							break
						end
					end
					if not interrupted then
						Sabotage.repair(st, function(lang)
							return Locale.t(lang, "bot_name")
						end, nil)
						-- иногда оставляет мышеловку рядом с починенным
						if math.random() < 0.5 and Chef.trapCount() < Config.MaxTraps then
							Chef.placeTrap(root.Position + root.CFrame.LookVector * 3)
						end
					end
				elseif alive() and st:GetAttribute("Broken") then
					skipUntil[st] = os.clock() + 15 -- не дошёл, попробуем позже
				end
			else
				local points = CollectionService:GetTagged("PatrolPoint")
				if #points > 0 then
					walkTo(points[math.random(#points)].Position, alive, findTarget)
				else
					task.wait(1)
				end
			end
		end
	end
end

-- Шум (поломка, писк, мышеловка): робот идёт проверить, если услышал
function ChefAI.alert(position, range)
	if not running or not npc then
		return
	end
	local root = getRoot(npc)
	if root and (position - root.Position).Magnitude <= (range or Config.AIHearingRange) then
		alertPos = position
		alertTime = os.clock()
	end
end

function ChefAI.start(cframe)
	ChefAI.stop()
	spawnCFrame = cframe
	running = true
	generation = generation + 1
	skipUntil = {}
	alertPos = nil
	local myGen = generation
	task.spawn(function()
		local model = buildNPC()
		if generation ~= myGen then
			model:Destroy()
			return
		end
		npc = model
		brain(myGen)
	end)
end

function ChefAI.stop()
	running = false
	generation = generation + 1
	if npc then
		npc:Destroy()
		npc = nil
	end
end

function ChefAI.init(context, sabotageService, chefService)
	ctx = context
	Sabotage = sabotageService
	Chef = chefService
end

return ChefAI
