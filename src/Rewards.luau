--!strict
--[[
	Rewards  (ModuleScript in SpeedPetsUI.Scripts, runs after Settings + Merchant)
	A plain DAILY REWARDS window in the pack's own studded style (built from a copy of the Settings window), so the
	right "Daily" tab opens something generic instead of the horror-themed Hollow event.
	- 7 day tiles, today glows; CLAIM marks it claimed, counts the money up, and the button shows the wait
	- the old Hollow window is still in the pack (Windows.open("Hollow")); the tab just points here now
	Demo data only: hook the "ClaimRequest" attribute on the gui to your server.
]]

local TweenService = game:GetService("TweenService")

local Rewards = {}

local ICON = {
	cash = { "rbxassetid://137420059887887", Vector2.zero, Vector2.zero },
	star = { "rbxassetid://77525488650887", Vector2.zero, Vector2.zero },
	shoe = { "rbxassetid://75078350073249", Vector2.zero, Vector2.zero },
	egg = { "rbxassetid://91085739254881", Vector2.zero, Vector2.zero },
	tag = { "rbxassetid://94457709291944", Vector2.zero, Vector2.zero },
}
local DAYS = {
	{ icon = "cash", amount = "+$5B" },
	{ icon = "shoe", amount = "+2x Speed" },
	{ icon = "cash", amount = "+$25B" },
	{ icon = "egg", amount = "+1 Egg" },
	{ icon = "star", amount = "+50 Stars" },
	{ icon = "cash", amount = "+$100B" },
	{ icon = "star", amount = "MEGA" },
}
local STUDS = "rbxassetid://78165738325794"

local function hex(s: string): Color3
	return Color3.fromHex(s)
end
local function tween(o: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function grad(o: Instance, a: string, b: string)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(hex(a), hex(b))
	g.Parent = o
	return g
end
local function studs(o: Instance, tile: number, layers: number)
	for i = 1, layers do
		local s = Instance.new("ImageLabel")
		s.Name = "Studs" .. i
		s.BackgroundTransparency = 1
		s.Image = STUDS
		s.ScaleType = Enum.ScaleType.Tile
		s.TileSize = UDim2.fromOffset(tile, tile)
		s.Size = UDim2.fromScale(1, 1)
		s.ZIndex = 2
		s.Parent = o
	end
end
local function text(parent: Instance, t: string, size: number, pos: UDim2, z: number): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = pos
	l.Size = UDim2.new(1, -8, 0, size + 6)
	l.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
	l.Text = t
	l.TextSize = size
	l.TextColor3 = Color3.new(1, 1, 1)
	l.ZIndex = z
	local st = Instance.new("UIStroke")
	st.Thickness = 3
	st.Color = Color3.new(0, 0, 0)
	st.Parent = l
	l.Parent = parent
	return l
end
local function icon(parent: Instance, key: string, size: number, pos: UDim2, z: number): ImageLabel
	local spec = ICON[key]
	local im = Instance.new("ImageLabel")
	im.BackgroundTransparency = 1
	im.AnchorPoint = Vector2.new(0.5, 0.5)
	im.Position = pos
	im.Size = UDim2.fromOffset(size, size)
	im.Image = spec[1]
	im.ImageRectOffset = spec[2]
	im.ImageRectSize = spec[3]
	im.ScaleType = Enum.ScaleType.Fit
	im.ZIndex = z
	im.Parent = parent
	return im
end

function Rewards.init(ctx: any)
	local gui = ctx.gui :: ScreenGui
	local root = ctx.root :: Frame
	local Windows = ctx.Windows
	local Pressable = require(ctx.Scripts.Pressable) :: any
	local ShopData = require(ctx.Scripts.ShopData) :: any

	local settings = root:FindFirstChild("Settings")
	if not settings or root:FindFirstChild("Rewards") then
		return
	end
	-- copy the Settings window (its look: rim, studded header + body, close button), then empty and refill it
	local sec = settings:Clone()
	sec.Name = "Rewards"
	local host = sec:FindFirstChild("Host") :: Frame
	local win = host:FindFirstChild("Window") :: Frame
	local panel = win:FindFirstChild("Panel") :: Frame
	local W = 900
	local H = 640
	host.Size = UDim2.fromOffset(W, H)
	panel.Size = UDim2.fromOffset(W, H)
	local rim = panel:FindFirstChild("Rim") :: Frame?
	if rim then
		rim.Size = UDim2.fromOffset(W - 8, H - 8)
	end
	local header = panel:FindFirstChild("Header") :: Frame
	header.Size = UDim2.fromOffset(W - 16, header.Size.Y.Offset)
	local close = panel:FindFirstChild("CloseButton") :: TextButton
	close.Position = UDim2.fromOffset(W - 92, close.Position.Y.Offset)
	local sep = panel:FindFirstChild("Separator") :: Frame?
	if sep then
		sep.Size = UDim2.fromOffset(W - 8, sep.Size.Y.Offset)
	end
	local body = panel:FindFirstChild("Body") :: Frame
	body.Size = UDim2.fromOffset(W - 16, H - body.Position.Y.Offset - 8)
	local list = panel:FindFirstChild("List")
	if list then
		list:Destroy()
	end
	for _, n in { "Title", "TitleShadow" } do
		local t = header:FindFirstChild(n) :: TextLabel?
		if t then
			t.Text = "Daily Rewards"
		end
	end
	local hg = header:FindFirstChildOfClass("UIGradient")
	if hg then
		hg.Rotation = 0
		hg.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, hex("#d6a8ff")),
			ColorSequenceKeypoint.new(0.45, hex("#9d4dff")),
			ColorSequenceKeypoint.new(1, hex("#b77bff")),
		})
	end

	-- day tiles: 4 on top, 3 under, centred
	local days = Instance.new("Frame")
	days.Name = "Days"
	days.BackgroundTransparency = 1
	days.Position = UDim2.fromOffset(8, body.Position.Y.Offset + 20)
	days.Size = UDim2.fromOffset(W - 16, 400)
	days.ZIndex = 4
	days.Parent = panel
	local TW, TH, GAP = 186, 186, 18
	local tiles: { Frame } = {}
	for i, d in DAYS do
		local row = if i <= 4 then 0 else 1
		local inRow = if row == 0 then 4 else 3
		local col = if row == 0 then i - 1 else i - 5
		local rowW = inRow * TW + (inRow - 1) * GAP
		local x = ((W - 16) - rowW) / 2 + col * (TW + GAP)
		local tile = Instance.new("Frame")
		tile.Name = "Day" .. i
		tile.Position = UDim2.fromOffset(x, row * (TH + GAP))
		tile.Size = UDim2.fromOffset(TW, TH)
		tile.BackgroundColor3 = Color3.new(1, 1, 1)
		tile.ZIndex = 4
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = tile
		local st = Instance.new("UIStroke")
		st.Thickness = 3.5
		st.Color = hex("#1a1033")
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Parent = tile
		if i == 7 then
			grad(tile, "#ffe24a", "#ff9d00")
		else
			grad(tile, "#5b7cff", "#3a3fd6")
		end
		studs(tile, 20, 2)
		text(tile, "Day " .. i, 28, UDim2.new(0.5, 0, 0, 26), 6)
		icon(tile, d.icon, if i == 7 then 92 else 78, UDim2.fromScale(0.5, 0.52), 6)
		text(tile, d.amount, 24, UDim2.new(0.5, 0, 1, -26), 6)
		local check = text(tile, "CLAIMED", 26, UDim2.fromScale(0.5, 0.52), 9)
		check.Name = "Claimed"
		check.TextColor3 = hex("#7dff6b")
		check.Rotation = -12
		check.Visible = false
		local s = Instance.new("UIScale")
		s.Name = "Pop"
		s.Parent = tile
		tile.Parent = days
		tiles[i] = tile
	end

	-- the claim button: a copy of the green Equip Best button from the Pets drawer (studs + Pressable look)
	local src = root:FindFirstChild("Drawers") and root.Drawers:FindFirstChild("EquipBestButton", true) :: TextButton?
	local claim: TextButton
	if src then
		claim = src:Clone()
		claim:RemoveTag("SPUI_DrawerButton")
	else
		claim = Instance.new("TextButton")
		claim.BackgroundColor3 = hex("#33d64a")
	end
	claim.Name = "ClaimButton"
	claim.AnchorPoint = Vector2.new(0.5, 0)
	claim.Position = UDim2.new(0, W / 2, 0, body.Position.Y.Offset + 20 + 2 * TH + GAP + 26)
	claim.Size = UDim2.fromOffset(360, 74)
	claim.ZIndex = 5
	local claimLabel = claim:FindFirstChild("Label", true) :: TextLabel?
	if claimLabel then
		claimLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		claimLabel.Position = UDim2.fromScale(0.5, 0.5)
		claimLabel.Size = UDim2.fromScale(1, 0.8)
		claimLabel.TextSize = 38
	end
	claim.Parent = panel

	sec.Parent = root
	Windows.register("Rewards", win, nil, ShopData.Transition)
	win.Visible = false

	-- state
	local today = 1
	local claimed = false
	local function paintToday()
		for i, t in tiles do
			local stroke = t:FindFirstChildOfClass("UIStroke") :: UIStroke
			stroke.Color = if i == today and not claimed then hex("#fff27a") else hex("#1a1033")
			stroke.Thickness = if i == today and not claimed then 6 else 3.5
		end
		if claimLabel then
			claimLabel.Text = if claimed then "Come back in 23:59" else "CLAIM DAY " .. today
		end
	end
	paintToday()

	local function countMoneyUp()
		local hud = root:FindFirstChild("HUD")
		local money = hud and hud:FindFirstChild("MoneyValue") :: TextLabel?
		if not money then
			return
		end
		local v = tonumber(string.match(money.Text, "[%d%.]+")) or 95.3
		local target = v + 5
		local n = Instance.new("NumberValue")
		n.Value = v
		n.Changed:Connect(function(x)
			money.Text = string.format("$%.1fB", x)
		end)
		tween(n, 0.9, { Value = target }).Completed:Connect(function()
			n:Destroy()
		end)
	end

	Pressable.bind(claim, function()
		if claimed then
			return
		end
		claimed = true
		gui:SetAttribute("ClaimRequest", "Day" .. today .. "|" .. tostring(os.clock()))
		local t = tiles[today]
		local pop = t:FindFirstChild("Pop") :: UIScale
		pop.Scale = 1.18
		tween(pop, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		local chk = t:FindFirstChild("Claimed") :: TextLabel
		chk.Visible = true
		for _, d in t:GetChildren() do
			if d:IsA("ImageLabel") and not string.find(d.Name, "Studs") then
				d.ImageTransparency = 0.55
			end
		end
		countMoneyUp()
		paintToday()
	end)
	Pressable.bind(close, function()
		Windows.close("Rewards")
	end)

	-- the right tab used to open the horror "Hollow" event: point it here (the Hud module calls Windows.toggle("Hollow"))
	local origToggle = Windows.toggle
	Windows.toggle = function(name: string)
		if name == "Hollow" then
			name = "Rewards"
		end
		origToggle(name)
	end

	ctx.api.rewards = {
		reset = function()
			claimed = false
			for _, t in tiles do
				(t:FindFirstChild("Claimed") :: TextLabel).Visible = false
				for _, d in t:GetChildren() do
					if d:IsA("ImageLabel") and not string.find(d.Name, "Studs") then
						d.ImageTransparency = 0
					end
				end
			end
			paintToday()
		end,
	}
end

return Rewards
