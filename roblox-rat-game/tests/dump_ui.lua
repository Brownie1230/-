-- Выгружает дерево интерфейса (из симулятора) в JSON, чтобы нарисовать картинку магазина.
local M = require("mock_roblox")
local D = M.D
local function color(c)
	return c and { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) } or nil
end
local function udim2(u)
	return u and { u.X.Scale, u.X.Offset, u.Y.Scale, u.Y.Offset } or nil
end
local function node(inst)
	local cls = inst.ClassName
	local n = { class = cls, children = {} }
	local function p(k)
		local ok, v = pcall(function()
			return inst[k]
		end)
		if ok then
			return v
		end
		return nil
	end
	if inst:IsA("GuiObject") then
		n.pos = udim2(p("Position"))
		n.size = udim2(p("Size"))
		local ap = p("AnchorPoint")
		n.anchor = ap and { ap.X, ap.Y } or { 0, 0 }
		n.bg = color(p("BackgroundColor3"))
		n.bgT = p("BackgroundTransparency")
		n.visible = p("Visible")
		n.z = p("ZIndex")
		n.order = p("LayoutOrder")
		if cls == "TextLabel" or cls == "TextButton" or cls == "TextBox" then
			n.text = p("Text")
			n.textColor = color(p("TextColor3"))
			n.textSize = p("TextSize")
			n.xAlign = p("TextXAlignment") and p("TextXAlignment").Name or "Center"
			n.rich = p("RichText")
		end
	elseif cls == "UICorner" then
		n.radius = p("CornerRadius").Offset
	elseif cls == "UIStroke" then
		n.color = color(p("Color"))
		n.thickness = p("Thickness")
		n.t = p("Transparency")
	elseif cls == "UIGradient" then
		local seq = p("Color")
		if seq then
			n.colors = {}
			for _, kp in ipairs(seq.Keypoints) do
				if M.typeof(kp) == "ColorSequenceKeypoint" then
					table.insert(n.colors, { kp.Time, color(kp.Value) })
				else
					table.insert(n.colors, { #n.colors, color(kp) })
				end
			end
		end
		n.rotation = p("Rotation") or 0
	elseif cls == "UIListLayout" then
		n.dir = p("FillDirection") and p("FillDirection").Name or "Vertical"
		n.pad = p("Padding") and p("Padding").Offset or 0
		n.hAlign = p("HorizontalAlignment") and p("HorizontalAlignment").Name or "Left"
	elseif cls == "UIGridLayout" then
		n.cell = udim2(p("CellSize"))
		n.cellPad = udim2(p("CellPadding"))
	elseif cls == "UIPadding" then
		n.padT = p("PaddingTop") and p("PaddingTop").Offset or 0
		n.padL = p("PaddingLeft") and p("PaddingLeft").Offset or 0
		n.padR = p("PaddingRight") and p("PaddingRight").Offset or 0
		n.padB = p("PaddingBottom") and p("PaddingBottom").Offset or 0
	elseif cls == "UIScale" then
		n.scale = p("Scale")
	end
	for _, c in ipairs(inst:GetChildren()) do
		table.insert(n.children, node(c))
	end
	return n
end
local function json(v)
	local t = type(v)
	if t == "table" then
		if #v > 0 or next(v) == nil then
			local parts = {}
			for _, x in ipairs(v) do
				table.insert(parts, json(x))
			end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local parts = {}
		for k, x in pairs(v) do
			table.insert(parts, string.format("%q", tostring(k)) .. ":" .. json(x))
		end
		return "{" .. table.concat(parts, ",") .. "}"
	elseif t == "string" then
		return (string.format("%q", v):gsub("\\\n", "\\n"))
	elseif t == "number" then
		return tostring(v)
	elseif t == "boolean" then
		return tostring(v)
	end
	return "null"
end
return function(guiInstance, path)
	local f = assert(io.open(path, "w"))
	f:write(json(node(guiInstance)))
	f:close()
end
