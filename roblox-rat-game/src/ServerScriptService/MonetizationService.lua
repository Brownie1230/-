-- MonetizationService (ModuleScript) — ServerScriptService
-- Донат за Robux: Game Passes (VIP, ×2 сыр) и Developer Products (пачки сыра).
-- Как настроить:
--   1) create.roblox.com → твоя игра → Monetization → Passes → Create a Pass (VIP и ×2 Сыр)
--   2) Monetization → Developer Products → Create (пачки сыра)
--   3) Скопируй ID каждого товара в Config (GamePasses и Products)

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local MonetizationService = {}
local ctx, DataService
local owned = {} -- [игрок] = { VIP = true, DoubleCheese = true }

local function passKeyById(id)
	for key, passId in pairs(Config.GamePasses) do
		if passId == id and passId > 0 then
			return key
		end
	end
	return nil
end

local function productById(id)
	for _, p in ipairs(Config.Products) do
		if p.Id == id and p.Id > 0 then
			return p
		end
	end
	return nil
end

function MonetizationService.hasPass(player, key)
	return owned[player] ~= nil and owned[player][key] == true
end

-- Множитель сыра: VIP +1, ×2 Сыр +1 (вместе ×3)
function MonetizationService.coinMultiplier(player)
	local m = 1
	if MonetizationService.hasPass(player, "VIP") then
		m = m + 1
	end
	if MonetizationService.hasPass(player, "DoubleCheese") then
		m = m + 1
	end
	return m
end

local function applyPerks(player)
	local isVip = MonetizationService.hasPass(player, "VIP")
	player:SetAttribute("VIP", isVip)
	player:SetAttribute("DoubleCheese", MonetizationService.hasPass(player, "DoubleCheese"))
	player:SetAttribute("CoinMult", MonetizationService.coinMultiplier(player))
	if isVip then
		DataService.grantHat(player, "vipcrown")
	end
end

function MonetizationService.load(player)
	owned[player] = {}
	for key, id in pairs(Config.GamePasses) do
		if id > 0 then
			local ok, has = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
			end)
			if ok and has then
				owned[player][key] = true
			end
		end
	end
	applyPerks(player)
end

-- Покупка пропуска прямо в игре
local function onPassPurchased(player, passId, purchased)
	if not purchased then
		return
	end
	local key = passKeyById(passId)
	if not key or not owned[player] then
		return
	end
	owned[player][key] = true
	applyPerks(player)
	if key == "VIP" then
		ctx.notifyPlayer(player, "good", "thanks_vip")
	else
		ctx.notifyPlayer(player, "good", "thanks_double")
	end
	ctx.fxPlayer(player, "purchase")
end

-- Покупка сыра (Developer Product). Roblox вызывает это, пока мы не ответим PurchaseGranted.
local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local product = productById(receipt.ProductId)
	if not product then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok = DataService.grantPurchase(player, receipt.PurchaseId, product.Coins)
	if not ok then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	ctx.notifyPlayer(player, "good", "thanks_cheese", product.Coins)
	ctx.fxPlayer(player, "coins", product.Coins, "💎")
	ctx.fxPlayer(player, "purchase")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.forget(player)
	owned[player] = nil
end

function MonetizationService.init(context, dataService)
	ctx = context
	DataService = dataService
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(onPassPurchased)
end

return MonetizationService
