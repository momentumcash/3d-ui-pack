--!strict
--[[
	Merchant  (ModuleScript in SpeedPetsUI.Scripts)
	The MERCHANT GUI pack, wired into the SpeedPets window system as one more window:
	- a "Merchant" button on the HUD (cloned from the Index button) opens it, X closes it
	- stock cards are filled from the pets the Shop already shows (demo data, no server)
	- PURCHASE marks a card "ITEM OWNED!", Reroll Stock re-deals the cards, the timer counts down
	- the Mysterious Crate's Buy 1 / Buy 5 spin the roller strip and land on a pet
	Everything is client-side demo data: hook BuyRequest / RollRequest (attributes on the gui) to your server.
]]

local TweenService = game:GetService("TweenService")

local Merchant = {}

type Pet = { name: string, rarity: string, image: string, rectOffset: Vector2, rectSize: Vector2 }

local DEMO_FALLBACK = {
	{ name = "Clownfish", rarity = "SECRET", image = "", rectOffset = Vector2.zero, rectSize = Vector2.zero },
}
local TIERS = { "COMMON", "RARE", "EPIC", "LEGENDARY", "SECRET" }
local TIER_COLOR = {
	COMMON = Color3.fromHex("#d8dde6"),
	RARE = Color3.fromHex("#3aa7ff"),
	EPIC = Color3.fromHex("#b45cff"),
	LEGENDARY = Color3.fromHex("#ffc02e"),
	SECRET = Color3.fromHex("#ff3b5c"),
}
local STOCK = 3 -- cards next to the crate (4 cards fit the row at once)
local REFRESH_START = 12 * 3600 + 32

local function tween(o: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function uiScale(o: GuiObject, name: string): UIScale
	local s = o:FindFirstChild(name) :: UIScale?
	if not s then
		local n = Instance.new("UIScale")
		n.Name = name
		n.Parent = o
		s = n
	end
	return s :: UIScale
end

-- hover grow / press squash for the pack's image buttons (they have no Visual/Pop like the SpeedPets buttons)
local function bindPress(btn: GuiButton, onActivate: () -> ())
	local s = uiScale(btn, "PressPop")
	local hovering = false
	btn.MouseEnter:Connect(function()
		hovering = true
		tween(s, 0.12, { Scale = 1.07 })
	end)
	btn.MouseLeave:Connect(function()
		hovering = false
		tween(s, 0.15, { Scale = 1 })
	end)
	btn.MouseButton1Down:Connect(function()
		tween(s, 0.06, { Scale = 0.93 })
	end)
	btn.MouseButton1Up:Connect(function()
		tween(s, 0.1, { Scale = hovering and 1.07 or 1 }, Enum.EasingStyle.Back)
	end)
	btn.Activated:Connect(onActivate)
end

local function fmtTime(sec: number): string
	sec = math.max(0, math.floor(sec))
	return string.format("Next Refresh: %dh %02dm %02ds", sec // 3600, (sec % 3600) // 60, sec % 60)
end

-- the SpeedPets stud texture (same image + tile as the pack's buttons and windows), so both packs read as one set.
-- inset = fraction trimmed off each side, so the rectangle stays inside the art's bevelled / angled edge.
local STUDS = "rbxassetid://78165738325794"
-- layers = 1 stacks a second copy: the stud image is a soft highlight, too faint on dark or deep colours alone.
local function addStuds(on: GuiObject, opts: { inset: Vector2?, area: { number }?, tile: number?, transparency: number?, z: number?, layers: number? })
	if on:FindFirstChild("MerchantStuds") then
		return
	end
	for layer = 1, opts.layers or 1 do
	local st = Instance.new("ImageLabel")
	st.Name = "MerchantStuds"
	st.BackgroundTransparency = 1
	st.Image = STUDS
	st.ScaleType = Enum.ScaleType.Tile
	st.TileSize = UDim2.fromOffset(opts.tile or 22, opts.tile or 22)
	st.ImageTransparency = opts.transparency or 0
	st.ZIndex = opts.z or 0
	st.Active = false
	if opts.area then
		local a = opts.area -- x0, y0, x1, y1 in the parent's scale
		st.Position = UDim2.fromScale(a[1], a[2])
		st.Size = UDim2.fromScale(a[3] - a[1], a[4] - a[2])
	else
		local i = opts.inset or Vector2.zero
		st.Position = UDim2.fromScale(i.X, i.Y)
		st.Size = UDim2.fromScale(1 - 2 * i.X, 1 - 2 * i.Y)
	end
	st.Name = if layer == 1 then "MerchantStuds" else "MerchantStuds" .. layer
	st.Parent = on
	end
end

function Merchant.init(ctx: any)
	local gui = ctx.gui :: ScreenGui
	local root = ctx.root :: Frame
	local Windows = ctx.Windows
	local Clock = ctx.Clock
	local ShopData = require(ctx.Scripts.ShopData) :: any

	local sec = root:FindFirstChild("Merchant") :: Frame?
	if not sec then
		return
	end
	local host = sec:WaitForChild("Host") :: Frame
	local win = host:WaitForChild("Window") :: Frame
	local bg = win:WaitForChild("Background") :: ImageLabel
	local scroll = (bg:WaitForChild("Items") :: Frame):WaitForChild("ScrollingFrame") :: ScrollingFrame
	local template = scroll:WaitForChild("Template") :: ImageLabel
	local crate = scroll:WaitForChild("Mysterious Crate") :: ImageLabel
	local closeBtn = bg:WaitForChild("Close") :: ImageButton
	local bottom = bg:WaitForChild("Bottom") :: Frame
	local reroll = bottom:WaitForChild("Purchase") :: ImageButton
	local arrow = bottom:FindFirstChild("Arrow") :: ImageButton?
	local refresh = bg:FindFirstChild("RefreshLabel") :: TextLabel?

	Windows.register("Merchant", win, nil, ShopData.Transition)
	for _, d in bg:GetDescendants() do
		if d:IsA("TextLabel") then
			d.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
			local st = d:FindFirstChildOfClass("UIStroke")
			if st then
				st.Color = Color3.new(0, 0, 0)
				st.Thickness = math.max(st.Thickness, 2.5)
			end
		end
	end
	win.Visible = false

	------------------------------------------------------------------------------------------------------------
	-- the pet list: every pet the Shop window shows (name, rarity, picture), so the Merchant sells the same world
	------------------------------------------------------------------------------------------------------------
	local pets: { Pet } = {}
	local seen: { [string]: boolean } = {}
	local spare = { "Cloud Bunny", "Lava Dragon", "Leaf Cat", "Galaxy Fox", "Robo Pup", "Jelly King" }
	local NAME_BY_IMAGE = { ["rbxassetid://99827642811574"] = "Cloud Bunny", ["rbxassetid://121456024904593"] = "Lava Dragon", ["rbxassetid://80899799361228"] = "Leaf Cat", ["rbxassetid://109498341767128"] = "Galaxy Fox", ["rbxassetid://132450861970706"] = "Robo Pup", ["rbxassetid://125743073247169"] = "Jelly King" }
	local shopSec = root:FindFirstChild("Shop")
	for _, d in (if shopSec then shopSec else root):GetDescendants() do
		local im = d:FindFirstChild("Pet")
		if d:IsA("GuiButton") and im and im:IsA("ImageLabel") and im.Image ~= "" then
			local key = im.Image .. tostring(im.ImageRectOffset)
			if not seen[key] then
				seen[key] = true
				local pn = d:GetAttribute("PetName")
				local name = NAME_BY_IMAGE[im.Image] or (if typeof(pn) == "string" and pn ~= "" then pn else (table.remove(spare, 1) or "Mystery Pet"))
				table.insert(pets, { name = name, rarity = tostring(d:GetAttribute("Rarity") or "RARE"), image = im.Image, rectOffset = im.ImageRectOffset, rectSize = im.ImageRectSize })
			end
		end
	end
	local tplVector = template:FindFirstChild("VectorFrame") and template.VectorFrame:FindFirstChild("Vector") :: ImageLabel?
	if #pets == 0 then
		DEMO_FALLBACK[1].image = tplVector and tplVector.Image or ""
		pets = DEMO_FALLBACK
	end

	------------------------------------------------------------------------------------------------------------
	-- stock cards
	------------------------------------------------------------------------------------------------------------
	-- studs: panel body, bottom bar, title banner, every card and every button
	addStuds(bg, { area = { 0.02, 0.13, 0.977, 0.86 }, tile = 32, transparency = 0.1 })
	addStuds(bottom, { inset = Vector2.new(0.004, 0.06), tile = 32, transparency = 0, layers = 1 })
	local title = bg:FindFirstChild("Title") :: GuiObject?
	if title then
		addStuds(title, { area = { 0.07, 0.24, 0.63, 0.76 }, tile = 30, transparency = 0, layers = 1 })
	end
	for _, card in { template, crate } do
		addStuds(card, { inset = Vector2.new(0.055, 0.035), tile = 30, transparency = 0, z = -20, layers = 1 })
	end
	local function studButton(b: GuiObject?)
		if b then
			addStuds(b, { inset = Vector2.new(0.05, 0.1), tile = 24, transparency = 0, layers = 1 })
		end
	end
	studButton(template:FindFirstChild("Button") :: GuiObject?)
	studButton(reroll)
	local cOpts = crate:FindFirstChild("Frame") and crate.Frame:FindFirstChild("Options")
	if cOpts then
		for _, n in { "Buy1", "Buy5" } do
			studButton(cOpts:FindFirstChild(n) :: GuiObject?)
		end
	end

	template.Visible = false
	crate.LayoutOrder = 0
	local grid0 = scroll:FindFirstChildOfClass("UIGridLayout")
	if grid0 then
		grid0.CellSize = UDim2.new(grid0.CellSize.X.Scale, 0, 0.92, 0) -- a touch smaller so crate + 3 cards fit
	end
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.X -- if they ever don't, scroll sideways
	local rng = Random.new()
	local cards: { ImageLabel } = {}

	local function fill(card: ImageLabel, pet: Pet, slot: number)
		local tier = TIERS[math.clamp(slot + rng:NextInteger(0, 1), 1, #TIERS)]
		local price = ({ 75, 150, 300, 650, 1200 })[table.find(TIERS, tier) or 1]
		local info = card:FindFirstChild("Frame") :: Frame
		local nameL = info and info:FindFirstChild("ItemName") :: TextLabel?
		local tierL = info and info:FindFirstChild("TierName") :: TextLabel?
		local priceRow = info and info:FindFirstChild("Frame") :: Frame?
		local priceL = priceRow and priceRow:FindFirstChild("Price") :: TextLabel?
		if nameL then
			nameL.Text = pet.name
		end
		if tierL then
			tierL.Text = tier
			local g = tierL:FindFirstChildOfClass("UIGradient")
			if g then
				g.Color = ColorSequence.new(TIER_COLOR[tier], TIER_COLOR[tier]:Lerp(Color3.new(1, 1, 1), 0.35))
			end
		end
		if priceL then
			priceL.Text = tostring(price)
		end
		local vf = card:FindFirstChild("VectorFrame")
		local v = vf and vf:FindFirstChild("Vector") :: ImageLabel?
		if v and pet.image ~= "" then
			v.Image = pet.image
			v.ImageRectOffset = pet.rectOffset
			v.ImageRectSize = pet.rectSize
			v.ScaleType = Enum.ScaleType.Fit
		end
		local owned = card:FindFirstChild("Owned") :: GuiObject?
		if owned then
			owned.Visible = false
		end
		card:SetAttribute("PetName", nil) -- keep the Shop tooltip off these
		card:SetAttribute("Item", pet.name)
		card:SetAttribute("Price", price)
	end

	local function deal(animate: boolean)
		local pool = table.clone(pets)
		for i = 1, STOCK do
			local card = cards[i]
			if #pool == 0 then
				pool = table.clone(pets)
			end
			local pet = table.remove(pool, rng:NextInteger(1, #pool)) :: any
			if animate then
				local s = uiScale(card, "DealPop")
				card:SetAttribute("Dealing", true)
				task.delay((i - 1) * 0.07, function()
					tween(s, 0.09, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Wait()
					fill(card, pet, i)
					tween(s, 0.32, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
					card:SetAttribute("Dealing", nil)
				end)
			else
				fill(card, pet, i)
			end
		end
	end

	for i = 1, STOCK do
		local card = template:Clone()
		card.Name = "Stock" .. i
		card.Visible = true
		card.LayoutOrder = i
		card.Parent = scroll
		cards[i] = card
		local buy = card:FindFirstChild("Button") :: ImageButton?
		if buy then
			bindPress(buy, function()
				local owned = card:FindFirstChild("Owned") :: GuiObject?
				if not owned or owned.Visible or card:GetAttribute("Dealing") then
					return
				end
				gui:SetAttribute("BuyRequest", tostring(card:GetAttribute("Item")) .. "|" .. tostring(os.clock()))
				owned.Visible = true
				local s = uiScale(owned, "OwnedPop")
				s.Scale = 1.5
				tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
				local cs = uiScale(card, "BuyPunch")
				cs.Scale = 0.94
				tween(cs, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
			end)
		end
	end
	deal(false)

	local refreshLeft = REFRESH_START
	local function doReroll()
		deal(true)
		refreshLeft = REFRESH_START
		if refresh then
			refresh.Text = fmtTime(refreshLeft)
		end
	end
	bindPress(reroll, doReroll)
	if arrow then
		bindPress(arrow, doReroll)
	end
	bindPress(closeBtn, function()
		Windows.close("Merchant")
	end)

	------------------------------------------------------------------------------------------------------------
	-- refresh timer
	------------------------------------------------------------------------------------------------------------
	if refresh then
		local last = Clock.now()
		Clock.loop(refresh, function(t)
			local dt = t - last
			if dt >= 1 then
				last += math.floor(dt)
				refreshLeft -= math.floor(dt)
				if refreshLeft <= 0 then
					refreshLeft = REFRESH_START
					deal(true)
				end
				refresh.Text = fmtTime(refreshLeft)
			end
		end)
		refresh.Text = fmtTime(refreshLeft)
	end

	------------------------------------------------------------------------------------------------------------
	-- the Mysterious Crate: Buy 1 / Buy 5 spin the roller and land on a pet
	------------------------------------------------------------------------------------------------------------
	local cf = crate:FindFirstChild("Frame") :: Frame
	local roller = cf and cf:FindFirstChild("Roller") :: Frame?
	local grid = roller and roller:FindFirstChild("List") and roller.List:FindFirstChild("Grid") :: Frame?
	local itemTpl = grid and grid:FindFirstChild("ItemTemplate") :: Frame?
	local crateName = cf and cf:FindFirstChild("ItemName") :: TextLabel?
	local ODDS = { 39, 24, 18, 11, 6.5, 1, 0.5 }
	local strip: { Frame } = {}
	local spinning = false

	local function oddsFor(i: number): number
		return ODDS[(i - 1) % #ODDS + 1]
	end
	local function buildStrip(n: number)
		if not grid or not itemTpl then
			return
		end
		for _, f in strip do
			f:Destroy()
		end
		table.clear(strip)
		itemTpl.Visible = false
		for i = 1, n do
			local pet = pets[rng:NextInteger(1, #pets)]
			local f = itemTpl:Clone()
			f.Name = "Roll" .. i
			f.Visible = true
			f.LayoutOrder = i
			local lab = f:FindFirstChild("Label") :: TextLabel?
			if lab then
				lab.Text = string.format("%g%%", oddsFor(rng:NextInteger(1, #ODDS)))
			end
			local v = f:FindFirstChild("Vector") :: ImageLabel?
			if v and pet.image ~= "" then
				v.Image = pet.image
				v.ImageRectOffset = pet.rectOffset
				v.ImageRectSize = pet.rectSize
				v.ScaleType = Enum.ScaleType.Fit
			end
			f:SetAttribute("Item", pet.name)
			f.Parent = grid
			strip[i] = f
		end
	end
	buildStrip(12)
	if grid then
		grid.Size = UDim2.new(0, 4000, 1, 0)
	end

	local spinBody: (number) -> ()
	local function spin(count: number)
		if spinning or not grid or not roller then
			return
		end
		spinning = true
		local ok, err = pcall(spinBody, count)
		spinning = false
		if not ok then
			warn("[SpeedPetsUI] Merchant spin: " .. tostring(err))
		end
	end
	spinBody = function(count: number)
		if not grid or not roller then
			return
		end
		gui:SetAttribute("RollRequest", tostring(count) .. "|" .. tostring(os.clock()))
		grid.Position = UDim2.fromOffset(0, 0)
		buildStrip(36)
		task.wait() -- layout
		local winIdx = rng:NextInteger(27, 31)
		local winner = strip[winIdx]
		local perOffset = grid.AbsoluteSize.X / math.max(1, grid.Size.X.Offset) -- abs px per offset px
		local centre = roller.AbsolutePosition.X + roller.AbsoluteSize.X / 2
		local wc = winner.AbsolutePosition.X + winner.AbsoluteSize.X * rng:NextNumber(0.3, 0.7)
		local dx = (wc - centre) / math.max(1e-3, perOffset)
		local tw = tween(grid, 2.6, { Position = UDim2.fromOffset(-dx, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		tw.Completed:Wait()
		local ws = uiScale(winner, "WinPop")
		tween(ws, 0.18, { Scale = 1.25 }, Enum.EasingStyle.Back).Completed:Wait()
		tween(ws, 0.25, { Scale = 1.1 })
		if crateName then
			local was = crateName.Text
			crateName.Text = (count > 1 and "x" .. count .. " " or "") .. tostring(winner:GetAttribute("Item")) .. "!"
			task.delay(2.2, function()
				crateName.Text = was
			end)
		end
		task.wait(0.6)
	end

	local opts = cf and cf:FindFirstChild("Options") :: Frame?
	for _, n in { "Buy1", "Buy5" } do
		local b = opts and opts:FindFirstChild(n) :: ImageButton?
		if b then
			local cost = b:FindFirstChild("Inside") and b.Inside:FindFirstChild("Cost") :: TextLabel?
			if cost then
				cost.Text = n == "Buy1" and " 99" or " 449"
			end
			bindPress(b, function()
				task.spawn(spin, n == "Buy1" and 1 or 5)
			end)
		end
	end

	------------------------------------------------------------------------------------------------------------
	-- HUD button (a copy of the Index button, under it)
	------------------------------------------------------------------------------------------------------------
	local hud = root:FindFirstChild("HUD") :: Frame?
	local idx = hud and hud:FindFirstChild("IndexButton") :: TextButton?
	if hud and idx and not hud:FindFirstChild("MerchantButton") then
		local mb = idx:Clone()
		mb.Name = "MerchantButton"
		mb.Position = idx.Position + UDim2.fromOffset(1, 84)
		mb.Size = UDim2.fromOffset(idx.Size.X.Offset + 52, idx.Size.Y.Offset)
		local badge = mb:FindFirstChild("Badge")
		if badge then
			badge:Destroy()
		end
		local vis = mb:FindFirstChild("Visual")
		local label = vis and vis:FindFirstChild("Label") :: TextLabel?
		if label then
			label.Text = "Merchant"
			label.Size = UDim2.fromOffset(label.Size.X.Offset + 52, label.Size.Y.Offset)
		end
		local icon = vis and vis:FindFirstChild("Icon") :: ImageLabel?
		local crateIcon = cf and cf:FindFirstChild("Icon") :: ImageLabel?
		if icon and crateIcon then
			icon.Image = crateIcon.Image
			icon.ImageRectOffset = crateIcon.ImageRectOffset
			icon.ImageRectSize = crateIcon.ImageRectSize
			icon.ScaleType = Enum.ScaleType.Fit
		end
		-- red, in the pack's own style: copy the red egg tab's gradient, dark outline and light inner line, keep the studs
		local surface = vis and vis:FindFirstChild("Surface") :: Frame?
		local eggs = hud:FindFirstChild("TabEggs")
		local eggSurface = eggs and eggs:FindFirstChild("Visual") and eggs.Visual:FindFirstChild("Surface") :: Frame?
		if surface then
			local g = surface:FindFirstChildOfClass("UIGradient")
			local eg = eggSurface and eggSurface:FindFirstChildOfClass("UIGradient")
			if g then
				g.Color = if eg then eg.Color else ColorSequence.new(Color3.fromHex("#ef4f58"), Color3.fromHex("#f52825"))
			end
			local outer = surface:FindFirstChild("Outer") :: UIStroke?
			local eOuter = eggSurface and eggSurface:FindFirstChild("Outer") :: UIStroke?
			if outer then
				outer.Color = if eOuter then eOuter.Color else Color3.fromHex("#450002")
			end
			local inner = surface:FindFirstChild("InnerHighlight")
			local innerStroke = inner and inner:FindFirstChildOfClass("UIStroke")
			local eInner = eggSurface and eggSurface:FindFirstChild("InnerHighlight")
			local eInnerStroke = eInner and eInner:FindFirstChildOfClass("UIStroke")
			if innerStroke then
				innerStroke.Color = if eInnerStroke then eInnerStroke.Color else Color3.fromHex("#f56e73")
			end
			local studs = surface:FindFirstChild("Studs") :: ImageLabel?
			local eStuds = eggSurface and eggSurface:FindFirstChild("Studs") :: ImageLabel?
			if studs then
				studs.ImageTransparency = if eStuds then eStuds.ImageTransparency else 0
			end
		end
		mb.Parent = hud
		for _, n in { "SlowModeToggle", "SlowModeLabel" } do
			local o = hud:FindFirstChild(n) :: GuiObject?
			if o then
				o.Position += UDim2.fromOffset(0, 84)
			end
		end
		require(ctx.Scripts.Pressable).bind(mb, function()
			Windows.toggle("Merchant")
		end)
	end

	ctx.api.merchant = {
		reroll = function()
			doReroll()
		end,
		spin = function(n: any)
			task.spawn(spin, tonumber(n) or 1)
		end,
	}
end

return Merchant
