--!strict
--[[
	HudStyle  (ModuleScript in SpeedPetsUI.Scripts, runs after Merchant)
	One look for every HUD button:
	- the stud texture shows on all of them (a second stud layer, same image + tile as the pack: one layer at the
	  pack's setting is too faint to see)
	- the three right tabs get bright simulator colours like the left buttons, a label under each, and the horror
	  "Hollow" art swapped for a plain star. Their jobs stay the same (Eggs drawer, Pets drawer, Rewards window).
	Sizes and positions are not touched.
]]

local HudStyle = {}

local function hex(s: string): Color3
	return Color3.fromHex(s)
end

-- top, middle, bottom of the fill; dark outline; light inner line
local TABS = {
	TabEggs = { label = "Eggs", fill = { "#fff05a", "#ffd21f", "#ffae00" }, outer = "#6b3f00", inner = "#fff6b0" },
	TabPets = { label = "Pets", fill = { "#ff7be0", "#ff3fc4", "#e0109e" }, outer = "#5a0040", inner = "#ffc2f0" },
	TabHollow = { label = "Daily", fill = { "#c58bff", "#9d4dff", "#7a1fff" }, outer = "#2a0060", inner = "#e2c8ff" },
}
local TAG = { image = "rbxassetid://94457709291944", offset = Vector2.zero, size = Vector2.zero }
local STAR = { image = "rbxassetid://77525488650887", offset = Vector2.zero, size = Vector2.zero }

local function strengthenStuds(btn: Instance, layers: number)
	local surface = btn:FindFirstChild("Visual") and btn.Visual:FindFirstChild("Surface")
	local studs = surface and surface:FindFirstChild("Studs") :: ImageLabel?
	if not surface or not studs or surface:FindFirstChild("Studs2") then
		return
	end
	studs.ImageTransparency = 0
	for i = 2, layers do
		local extra = studs:Clone()
		extra.Name = "Studs" .. i
		extra.Parent = surface
	end
end

local function paint(btn: Instance, spec: any)
	local vis = btn:FindFirstChild("Visual")
	local surface = vis and vis:FindFirstChild("Surface") :: Frame?
	if not vis or not surface then
		return
	end
	local g = surface:FindFirstChildOfClass("UIGradient")
	if g then
		g.Rotation = 90
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, hex(spec.fill[1])),
			ColorSequenceKeypoint.new(0.5, hex(spec.fill[2])),
			ColorSequenceKeypoint.new(1, hex(spec.fill[3])),
		})
	end
	local outer = surface:FindFirstChild("Outer") :: UIStroke?
	if outer then
		outer.Color = hex(spec.outer)
	end
	local inner = surface:FindFirstChild("InnerHighlight")
	local innerStroke = inner and inner:FindFirstChildOfClass("UIStroke")
	if innerStroke then
		innerStroke.Color = hex(spec.inner)
	end

	-- label under the tile, half over its bottom edge (like the Shop's side tabs)
	if not vis:FindFirstChild("TabLabel") then
		local l = Instance.new("TextLabel")
		l.Name = "TabLabel"
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.new(0.5, 0, 1, 2)
		l.Size = UDim2.fromOffset(130, 30)
		l.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
		l.Text = spec.label
		l.TextSize = 23
		l.TextColor3 = Color3.new(1, 1, 1)
		l.ZIndex = 8
		local st = Instance.new("UIStroke")
		st.Thickness = 3
		st.Color = Color3.new(0, 0, 0)
		st.Parent = l
		l.Parent = vis
	end
end

function HudStyle.init(ctx: any)
	local root = ctx.root :: Frame
	local hud = root:FindFirstChild("HUD")
	if not hud then
		return
	end
	for _, n in { "ShopButton", "IndexButton", "MerchantButton", "TabEggs", "TabPets", "TabHollow" } do
		local b = hud:FindFirstChild(n)
		if b then
			-- 3 layers on the wide left buttons (one shows only zoomed in), 2 on the small square tabs
			strengthenStuds(b, if string.sub(n, 1, 3) == "Tab" then 2 else 3)
		end
	end
	for name, spec in TABS do
		local b = hud:FindFirstChild(name)
		if b then
			paint(b, spec)
		end
	end
	-- the Hollow tab: plain star instead of the horror logo
	local hollow = hud:FindFirstChild("TabHollow")
	local icon = hollow and hollow:FindFirstChild("Visual") and hollow.Visual:FindFirstChild("Icon") :: ImageLabel?
	if icon then
		icon.Image = STAR.image
		icon.ImageRectOffset = STAR.offset
		icon.ImageRectSize = STAR.size
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Size = UDim2.fromOffset(58, 58)
		icon.Position = UDim2.fromOffset(13, 12)
	end
	-- Merchant button: a clear sale-tag icon instead of the dark crate
	local mb = hud:FindFirstChild("MerchantButton")
	local micon = mb and mb:FindFirstChild("Visual") and mb.Visual:FindFirstChild("Icon") :: ImageLabel?
	if micon then
		micon.Image = TAG.image
		micon.ImageRectOffset = TAG.offset
		micon.ImageRectSize = TAG.size
		micon.ScaleType = Enum.ScaleType.Fit
	end
end

return HudStyle
