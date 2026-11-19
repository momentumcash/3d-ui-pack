--[[
	DailyShopDemo  (LocalScript)  -  made by @momentumcash, MIT licence
	------------------------------------------------------------------
	A Daily rewards + Shop menu that floats in 3D: a frosted glass panel that tilts toward your mouse while the world
	blurs behind it. The title, close button, coin pill and the big CLAIM button sit on a layer in FRONT of the
	glass, so they visibly float off it when the panel tilts. Built on the ImmersiveUI module.

	HOW TO USE
	  1. Put the ImmersiveUI ModuleScript in ReplicatedStorage (named "ImmersiveUI").
	  2. Put this LocalScript in StarterPlayer > StarterPlayerScripts.
	  3. Press Play. Click DAILY or SHOP on the left side of the screen.

	!! DEMO DATA !!
	  Every number below (786 coins, day rewards, missions, prices) is FAKE demo data. Nothing is saved, nothing talks
	  to a server, nothing uses Robux. Coins reset every time you press Play. To use this in a real game, keep the
	  layout and swap the DEMO table + the claim / buy functions for your own (server-checked) code.

	No uploaded images: every coin, gift, icon and shadow is drawn with Frames, so it works in any game.

	Studio test hook: Players.<you>:SetAttribute("ImmersiveDemoOpen", "Daily" | "Shop" | "") opens / closes it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local ImmersiveUI = require(ReplicatedStorage:WaitForChild("ImmersiveUI"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Everything that outlives a single UI element, so teardown() can undo it all (see the bottom of the file).
local conns: { RBXScriptConnection } = {}
local threads: { thread } = {}
local function track(c: RBXScriptConnection): RBXScriptConnection
	table.insert(conns, c)
	return c
end

------------------------------------------------------------------------------------------------------------------
-- DEMO DATA (fake, not saved)
------------------------------------------------------------------------------------------------------------------
local DEMO = {
	startCoins = 786,
	days = {
		{ coins = 50 },
		{ coins = 75 },
		{ coins = 100 },
		{ coins = 125 },
		{ coins = 150 },
		{ coins = 200 },
		{ coins = 300, gift = true },
	},
	today = 1, -- which day can be claimed
	missions = {
		{ title = "Land 8 perfects", have = 8, need = 8, coins = 60, icon = "ring" },
		{ title = "Finish in the top 3, two times", have = 0, need = 2, coins = 90, icon = "trophy" },
		{ title = "Break 35 trees", have = 12, need = 35, coins = 130, icon = "tree" },
	},
	newMissionsInSeconds = 20 * 3600 + 46 * 60 + 30,
	-- Shop: 5 tabs, 6 items each. price 0 = owned from the start. `colors` drive the drawn preview.
	shop = {
		{
			name = "TRAILS", icon = "trails",
			items = {
				{ name = "None", price = 0 },
				{ name = "Breeze", price = 300, colors = { "#3fa7ff", "#a8e2ff" } },
				{ name = "Mint", price = 450, colors = { "#2fd39a", "#c6f7df" } },
				{ name = "Ember", price = 650, colors = { "#ff5a3a", "#ffd56a" } },
				{ name = "Violet", price = 850, colors = { "#7a5cff", "#e6dcff" } },
				{ name = "Prism", price = 1500, colors = { "#ff4f7b", "#ffb340", "#5ee07a", "#3fb8ff", "#9b6bff" } },
			},
		},
		{
			name = "RINGS", icon = "ring",
			items = {
				{ name = "None", price = 0 },
				{ name = "Classic", price = 250, colors = { "#38d98a" } },
				{ name = "Gold", price = 500, colors = { "#ffc22e" } },
				{ name = "Frost", price = 800, colors = { "#7ad8ff" } },
				{ name = "Inferno", price = 1100, colors = { "#ff5a3a" } },
				{ name = "Galaxy", price = 2000, colors = { "#9b6bff" } },
			},
		},
		{
			name = "HOOKS", icon = "hook",
			items = {
				{ name = "Basic", price = 0, colors = { "#b7c6d6" } },
				{ name = "Chrome", price = 350, colors = { "#e9f1fa" } },
				{ name = "Neon", price = 600, colors = { "#3cf0b0" } },
				{ name = "Ruby", price = 900, colors = { "#ff4f6e" } },
				{ name = "Void", price = 1300, colors = { "#7a5cff" } },
				{ name = "Royal", price = 1800, colors = { "#ffc22e" } },
			},
		},
		{
			name = "EMOTES", icon = "note",
			items = {
				{ name = "None", price = 0 },
				{ name = "Wave", price = 150, colors = { "#3fb8ff" } },
				{ name = "Cheer", price = 300, colors = { "#ff5fa8" } },
				{ name = "Dab", price = 500, colors = { "#2fd39a" } },
				{ name = "Floss", price = 750, colors = { "#ffb340" } },
				{ name = "Moonwalk", price = 1200, colors = { "#9b6bff" } },
			},
		},
		{
			name = "COINS", icon = "coin", money = true,
			items = {
				{ name = "Pouch", give = 100, stack = 1 },
				{ name = "Stack", give = 250, stack = 2 },
				{ name = "Pile", give = 500, stack = 3 },
				{ name = "Bag", give = 1000, stack = 4 },
				{ name = "Chest", give = 2500, stack = 5 },
				{ name = "Vault", give = 5000, stack = 6 },
			},
		},
	},
}

------------------------------------------------------------------------------------------------------------------
-- LOOK: frosted "Aero glass". White glass, ink text, sky blue for secondary pills, ONE orange accent (the main
-- CLAIM). Heavy italic display type, small tracked eyebrows. All sizes are canvas pixels (1100 x 760).
------------------------------------------------------------------------------------------------------------------
local CANVAS = Vector2.new(1100, 760)
local PANE_Y = 40 -- empty canvas above the pane: the title pill sits centred on the pane's top edge
local PANE = Vector2.new(1100, 720)
local FRONT_DEPTH = 0.6 -- studs the front layer floats in front of the glass: ~20 px of slide at full tilt

local FAMILY = "rbxasset://fonts/families/Montserrat.json"
local F = {
	display = Font.new(FAMILY, Enum.FontWeight.Heavy, Enum.FontStyle.Italic),
	bold = Font.new(FAMILY, Enum.FontWeight.Bold, Enum.FontStyle.Normal),
	boldItalic = Font.new(FAMILY, Enum.FontWeight.ExtraBold, Enum.FontStyle.Italic),
	semi = Font.new(FAMILY, Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),
	eyebrow = Font.new(FAMILY, Enum.FontWeight.ExtraBold, Enum.FontStyle.Normal),
}

local function hex(s: string): Color3
	return Color3.fromHex(s)
end

local C = {
	white = Color3.new(1, 1, 1),
	cloud = hex("#f6fafd"),
	skyPale = hex("#dff0fd"),
	sky = hex("#4fa8f0"),
	aqua = hex("#1fb5d6"),
	glow = hex("#7af4ff"),
	ink = hex("#0d2a44"),
	inkSoft = hex("#3d5a75"),
	inkMute = hex("#6f8ba4"),
	good = hex("#4cc400"),
	goldHi = hex("#fff3b0"),
	gold = hex("#ffc93a"),
	goldLo = hex("#e8960e"),
	goldRim = hex("#b8710a"),
	track = hex("#d3e4f3"),
	shadow = hex("#0d2a44"),
}

-- Pill button kinds: { top, bottom, lip, text }
local KIND = {
	cta = { hex("#ff7a55"), hex("#f0442c"), hex("#b82a16"), C.white }, -- the one orange accent
	sky = { hex("#6cc4ff"), hex("#2f8fe8"), hex("#1d64b0"), C.white },
	white = { hex("#ffffff"), hex("#e3eef8"), hex("#b6c9db"), C.ink },
	muted = { hex("#f3f7fb"), hex("#dbe5ee"), hex("#b6c4d1"), C.inkMute },
	good = { hex("#7fe04a"), hex("#43b300"), hex("#2d7a00"), C.white },
	red = { hex("#ff7b8c"), hex("#e8384f"), hex("#a81f33"), C.white },
	ink = { hex("#2d527a"), hex("#0d2a44"), hex("#061a2e"), C.white }, -- dark glass: reads on the white pane
}

------------------------------------------------------------------------------------------------------------------
-- Small helpers
------------------------------------------------------------------------------------------------------------------
local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local o = Instance.new(class)
	for k, v in props do
		(o :: any)[k] = v
	end
	if parent then
		o.Parent = parent
	end
	return o
end

local function px(x: number, y: number): UDim2
	return UDim2.fromOffset(x, y)
end

local function round(o: Instance, r: number?)
	local c = o:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	c.CornerRadius = if r then UDim.new(0, r) else UDim.new(0.5, 0) -- nil = full pill / circle
	c.Parent = o
	return c
end

local function rim(o: Instance, color: Color3, thick: number, transp: number?): UIStroke
	local s = o:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = color
	s.Thickness = thick
	s.Transparency = transp or 0
	s.Parent = o
	return s
end

-- Vertical gradient through 2+ colours (top -> bottom). Sets the base colour white so it shows true.
local function vgrad(o: GuiObject, colors: { Color3 }, transp: { number }?): UIGradient
	local g = o:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient")
	local keys = {}
	for i, c in colors do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c))
	end
	g.Color = ColorSequence.new(keys)
	if transp then
		g.Transparency = NumberSequence.new(transp[1], transp[2])
	end
	g.Rotation = 90
	g.Parent = o
	o.BackgroundColor3 = C.white
	return g
end

local function tween(o: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function frame(parent: Instance?, x: number, y: number, w: number, h: number, z: number, props: { [string]: any }?): Frame
	local f = make("Frame", { Position = px(x, y), Size = px(w, h), BorderSizePixel = 0, BackgroundTransparency = 1, ZIndex = z }, nil)
	for k, v in props or {} do
		(f :: any)[k] = v
	end
	f.Parent = parent
	return f
end

-- Text in a fixed box. Shrinks (never grows) to fit: TextScaled capped at `size`.
local function label(parent: Instance, str: string, font: Font, size: number, color: Color3, props: { [string]: any }): TextLabel
	local t = make("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = font,
		Text = str,
		TextSize = size,
		TextScaled = true,
		TextColor3 = color,
		TextWrapped = false,
		ZIndex = 6,
	}, nil)
	make("UITextSizeConstraint", { MaxTextSize = size, MinTextSize = math.max(8, math.floor(size * 0.5)) }, t)
	for k, v in props do
		(t :: any)[k] = v
	end
	t.Parent = parent
	return t
end

-- Tiny tracked eyebrow ("D A I L Y  R E W A R D S" with thin spaces, Montserrat Bold, ink-soft).
local THIN = utf8.char(0x2009)
local function eyebrow(parent: Instance, str: string, x: number, y: number, w: number, align: Enum.TextXAlignment?, color: Color3?): TextLabel
	local spaced = {}
	for _, ch in utf8.codes(string.upper(str)) do
		table.insert(spaced, utf8.char(ch))
	end
	return label(parent, table.concat(spaced, THIN), F.eyebrow, 24, color or C.ink, {
		Position = px(x, y),
		Size = px(w, 30),
		TextXAlignment = align or Enum.TextXAlignment.Left,
	})
end

-- Big display text with a soft drop shadow (a second copy, offset and see-through).
local function display(parent: Instance, str: string, size: number, color: Color3, props: { [string]: any }): (TextLabel, TextLabel)
	local sh = label(parent, str, F.display, size, C.shadow, props)
	sh.TextTransparency = 0.82
	sh.Position += px(0, 3)
	sh.ZIndex = (props.ZIndex or 6) - 1
	local t = label(parent, str, F.display, size, color, props)
	return t, sh
end

-- Soft shadow from stacked see-through rounded frames (no images). Sits behind a card at (x, y, w, h).
local function softShadow(parent: Instance, x: number, y: number, w: number, h: number, r: number?, z: number, strength: number?)
	local s = strength or 1
	local g = frame(parent, 0, 0, 0, 0, z, { Name = "Shadow" })
	for i, spread in { 2, 6, 12 } do
		local f = frame(g, x - spread, y - spread + 4 + i * 2, w + spread * 2, h + spread * 2, z, {
			BackgroundTransparency = 1 - (0.1 / i) * s,
			BackgroundColor3 = C.shadow,
		})
		round(f, if r then r + spread else nil)
	end
	return g
end

-- Top gloss: a white band over the upper part of a rounded shape, fading out downward.
local function gloss(parent: GuiObject, r: number?, height: number?, strength: number?)
	local g = make("Frame", {
		Name = "Gloss",
		Position = UDim2.new(0, 3, 0, 2),
		Size = UDim2.new(1, -6, height or 0.48, 0),
		BackgroundColor3 = C.white,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ZIndex = (parent.ZIndex or 1) + 1,
	}, parent)
	round(g, r)
	local gr = make("UIGradient", { Rotation = 90 }, g)
	gr.Transparency = NumberSequence.new(1 - (strength or 0.55), 1)
	return g
end

local function colorAt(list: { Color3 }, t: number): Color3
	if #list == 1 then
		return list[1]
	end
	local f = math.clamp(t, 0, 1) * (#list - 1)
	local i = math.min(math.floor(f) + 1, #list - 1)
	return list[i]:Lerp(list[i + 1], f - (i - 1))
end

local function toColors(list: { string }?): { Color3 }
	local out = {}
	for _, h in list or { "#b7c6d6" } do
		table.insert(out, hex(h))
	end
	return out
end

------------------------------------------------------------------------------------------------------------------
-- Glossy icons, all Frames. (parent, centre x, centre y, size, colour?) in the parent's pixels.
------------------------------------------------------------------------------------------------------------------
local Icon = {}

local function holder(parent: Instance, cx: number, cy: number, s: number, name: string, z: number?): Frame
	return make("Frame", { Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(cx, cy), Size = px(s, s), BackgroundTransparency = 1, ZIndex = z or 6 }, parent)
end

local function dot(parent: Instance, cx: number, cy: number, w: number, h: number, color: Color3, z: number, r: number?): Frame
	local f = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = px(cx, cy), Size = px(w, h), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = z }, parent)
	round(f, r)
	return f
end

function Icon.coin(parent: Instance, cx: number, cy: number, d: number): Frame
	local o = holder(parent, cx, cy, d, "Coin")
	local z = o.ZIndex
	local disc = dot(o, d / 2, d / 2, d, d, C.gold, z)
	vgrad(disc, { C.goldHi, C.gold, C.goldLo })
	rim(disc, C.goldRim, math.max(1.5, d / 20))
	local face = dot(o, d / 2, d / 2, d * 0.7, d * 0.7, C.gold, z + 1)
	vgrad(face, { C.goldLo, C.gold, C.goldHi })
	rim(face, hex("#fff6c8"), math.max(1, d / 28), 0.25)
	local star = dot(o, d / 2, d / 2, d * 0.24, d * 0.24, C.goldHi, z + 2, 2)
	star.Rotation = 45
	rim(star, C.goldLo, math.max(1, d / 34), 0.2)
	local spec = dot(o, d * 0.34, d * 0.26, d * 0.3, d * 0.16, C.white, z + 3)
	spec.Rotation = -28
	spec.BackgroundTransparency = 0.2
	return o
end

function Icon.gift(parent: Instance, cx: number, cy: number, s: number): Frame
	local o = holder(parent, cx, cy, s, "Gift")
	local z = o.ZIndex
	local body = dot(o, s / 2, s * 0.64, s * 0.76, s * 0.54, C.white, z, math.floor(s * 0.12))
	vgrad(body, { hex("#ff8cc6"), hex("#ff4f9e"), hex("#d92a7a") })
	local lid = dot(o, s / 2, s * 0.36, s * 0.9, s * 0.2, C.white, z + 1, math.floor(s * 0.08))
	vgrad(lid, { hex("#ffb0d8"), hex("#ff5fa8") })
	local rib = dot(o, s / 2, s * 0.6, s * 0.15, s * 0.62, C.white, z + 2, 2)
	vgrad(rib, { C.goldHi, C.gold })
	for _, side in { -1, 1 } do
		local bow = dot(o, s / 2 + side * s * 0.13, s * 0.18, s * 0.24, s * 0.2, C.gold, z + 2)
		vgrad(bow, { C.goldHi, C.gold, C.goldLo })
		bow.Rotation = side * 25
	end
	local spec = dot(o, s * 0.32, s * 0.52, s * 0.14, s * 0.24, C.white, z + 3)
	spec.BackgroundTransparency = 0.45
	return o
end

function Icon.bag(parent: Instance, cx: number, cy: number, s: number): Frame
	local o = holder(parent, cx, cy, s, "Bag")
	local z = o.ZIndex
	local handle = dot(o, s / 2, s * 0.3, s * 0.4, s * 0.36, C.white, z)
	handle.BackgroundTransparency = 1
	rim(handle, hex("#1d64b0"), math.max(2, s * 0.07))
	local body = dot(o, s / 2, s * 0.64, s * 0.8, s * 0.6, C.white, z + 1, math.floor(s * 0.14))
	vgrad(body, { hex("#7fd0ff"), hex("#3a9cf0"), hex("#1f73d0") })
	gloss(body, math.floor(s * 0.12), 0.45, 0.6)
	Icon.coin(o, s / 2, s * 0.66, s * 0.3).ZIndex = z + 3
	return o
end

function Icon.note(parent: Instance, cx: number, cy: number, s: number, color: Color3?): Frame
	local col = color or hex("#3fb8ff")
	local o = holder(parent, cx, cy, s, "Note")
	local z = o.ZIndex
	local w = math.max(3, s * 0.11)
	dot(o, s * 0.38, s * 0.46, w, s * 0.6, col, z, 2)
	dot(o, s * 0.78, s * 0.38, w, s * 0.6, col, z, 2)
	local beam = dot(o, s * 0.58, s * 0.18, s * 0.46, s * 0.14, col, z, 3)
	beam.Rotation = -12
	for _, p in { { 0.28, 0.76 }, { 0.68, 0.68 } } do
		local head = dot(o, s * p[1], s * p[2], s * 0.32, s * 0.26, col, z + 1)
		head.Rotation = -18
		vgrad(head, { col:Lerp(C.white, 0.45), col, col:Lerp(C.ink, 0.15) })
		local spec = dot(o, s * (p[1] - 0.05), s * (p[2] - 0.04), s * 0.1, s * 0.06, C.white, z + 2)
		spec.BackgroundTransparency = 0.3
	end
	return o
end

function Icon.trophy(parent: Instance, cx: number, cy: number, s: number): Frame
	local o = holder(parent, cx, cy, s, "Trophy")
	local z = o.ZIndex
	for _, side in { -1, 1 } do
		local h = dot(o, s / 2 + side * s * 0.3, s * 0.32, s * 0.24, s * 0.26, C.gold, z)
		h.BackgroundTransparency = 1
		rim(h, C.goldLo, math.max(2, s * 0.07))
	end
	local cup = dot(o, s / 2, s * 0.34, s * 0.56, s * 0.48, C.white, z + 1, math.floor(s * 0.2))
	vgrad(cup, { C.goldHi, C.gold, C.goldLo })
	gloss(cup, math.floor(s * 0.16), 0.4, 0.5)
	dot(o, s / 2, s * 0.64, s * 0.12, s * 0.16, C.goldLo, z, 2)
	local base = dot(o, s / 2, s * 0.8, s * 0.5, s * 0.13, C.white, z + 1, 4)
	vgrad(base, { C.gold, C.goldRim })
	return o
end

function Icon.ring(parent: Instance, cx: number, cy: number, d: number, color: Color3?): Frame
	local col = color or hex("#38d98a")
	local o = holder(parent, cx, cy, d, "Ring")
	local z = o.ZIndex
	local outer = dot(o, d / 2, d / 2, d * 0.84, d * 0.84, col, z)
	outer.BackgroundTransparency = 1
	rim(outer, col, math.max(3, d * 0.14))
	local hi = dot(o, d / 2, d / 2, d * 0.84, d * 0.84, col, z + 1)
	hi.BackgroundTransparency = 1
	rim(hi, col:Lerp(C.white, 0.6), math.max(1, d * 0.035), 0.1)
	local core = dot(o, d / 2, d / 2, d * 0.3, d * 0.3, C.white, z + 1)
	vgrad(core, { C.white, col:Lerp(C.white, 0.35) })
	local spec = dot(o, d * 0.3, d * 0.2, d * 0.2, d * 0.09, C.white, z + 2)
	spec.Rotation = -35
	spec.BackgroundTransparency = 0.25
	return o
end

function Icon.tree(parent: Instance, cx: number, cy: number, s: number): Frame
	local o = holder(parent, cx, cy, s, "Tree")
	local z = o.ZIndex
	local trunk = dot(o, s / 2, s * 0.76, s * 0.16, s * 0.34, C.white, z, 3)
	vgrad(trunk, { hex("#c08a5a"), hex("#8a5a32") })
	local crown = dot(o, s / 2, s * 0.4, s * 0.7, s * 0.6, C.white, z + 1)
	vgrad(crown, { hex("#8bf06a"), hex("#3cc43a"), hex("#1f8f2e") })
	gloss(crown, nil, 0.45, 0.55)
	return o
end

function Icon.hook(parent: Instance, cx: number, cy: number, s: number, color: Color3?): Frame
	local col = color or hex("#b7c6d6")
	local o = holder(parent, cx, cy, s, "Hook")
	local z = o.ZIndex
	local w = math.max(4, s * 0.13)
	local loop = dot(o, s / 2, s * 0.14, s * 0.24, s * 0.24, col, z)
	loop.BackgroundTransparency = 1
	rim(loop, col, math.max(2, s * 0.07))
	local parts = {
		dot(o, s / 2, s * 0.48, w, s * 0.5, col, z, 3),
		dot(o, s * 0.32, s * 0.76, w, s * 0.36, col, z, 3),
		dot(o, s * 0.68, s * 0.76, w, s * 0.36, col, z, 3),
	}
	parts[2].Rotation = 42
	parts[3].Rotation = -42
	for _, p in parts do
		vgrad(p, { col:Lerp(C.white, 0.5), col, col:Lerp(C.ink, 0.2) })
	end
	return o
end

function Icon.trails(parent: Instance, cx: number, cy: number, s: number): Frame
	local o = holder(parent, cx, cy, s, "Trails")
	local z = o.ZIndex
	for i = 0, 1 do
		local bar = dot(o, s * (0.44 + i * 0.14), s * (0.38 + i * 0.24), s * 0.82, s * 0.16, C.white, z)
		bar.Rotation = -28
		local g = vgrad(bar, { hex("#3fb8ff"), hex("#7af4ff") })
		g.Rotation = 0
		g.Transparency = NumberSequence.new(0.85, 0)
	end
	return o
end

function Icon.check(parent: Instance, cx: number, cy: number, s: number, color: Color3?): Frame
	local col = color or C.white
	local o = holder(parent, cx, cy, s, "Check", 8)
	local w = math.max(3, s * 0.18)
	local a = dot(o, s * 0.32, s * 0.6, w, s * 0.4, col, 9, 2)
	a.Rotation = -45
	local b = dot(o, s * 0.6, s * 0.48, w, s * 0.74, col, 9, 2)
	b.Rotation = 38
	return o
end

-- Round green badge with a white tick (claimed / equipped)
function Icon.tick(parent: Instance, cx: number, cy: number, s: number): Frame
	local o = holder(parent, cx, cy, s, "Tick", 8)
	local disc = dot(o, s / 2, s / 2, s, s, C.good, 8)
	vgrad(disc, { hex("#8ff05a"), C.good, hex("#2f8f00") })
	rim(disc, C.white, math.max(2, s * 0.08))
	Icon.check(o, s / 2, s / 2 + s * 0.03, s * 0.62).ZIndex = 9
	return o
end

function Icon.none(parent: Instance, cx: number, cy: number, s: number): Frame
	local o = holder(parent, cx, cy, s, "None")
	local ring = dot(o, s / 2, s / 2, s * 0.8, s * 0.8, C.white, 6)
	ring.BackgroundTransparency = 1
	rim(ring, C.inkMute, math.max(3, s * 0.08), 0.35)
	local bar = dot(o, s / 2, s / 2, s * 0.08, s * 0.8, C.inkMute, 6, 2)
	bar.Rotation = 45
	bar.BackgroundTransparency = 0.35
	return o
end

-- Smooth comet trail: soft capsules fading in from the left, bright head on the right.
local function trailPreview(parent: Instance, w: number, h: number, colors: { Color3 })
	for i, off in { -14, 0, 14 } do
		local thick = if i == 2 then 14 else 8
		local streak = dot(parent, w * 0.4, h * 0.5 + off, w * 0.64, thick, C.white, 6)
		streak.Rotation = -8
		local keys = {}
		for k = 0, 4 do
			table.insert(keys, ColorSequenceKeypoint.new(k / 4, colorAt(colors, k / 4)))
		end
		local g = make("UIGradient", { Color = ColorSequence.new(keys), Transparency = NumberSequence.new(1, if i == 2 then 0 else 0.35) }, streak)
		g.Rotation = 0
	end
	local head = dot(parent, w * 0.72, h * 0.5 - 6, 22, 22, colorAt(colors, 1), 7)
	vgrad(head, { C.white, colorAt(colors, 1) })
	rim(head, C.white, 2, 0.2)
end

local function iconFor(kind: string, parent: Instance, cx: number, cy: number, s: number, color: Color3?): Frame?
	local fn = (Icon :: any)[kind]
	if fn then
		return fn(parent, cx, cy, s, color)
	end
	return nil
end

------------------------------------------------------------------------------------------------------------------
-- Glossy pill button: coloured face over a darker lip, white rim, top sheen, hover lift + glow, press dip.
------------------------------------------------------------------------------------------------------------------
type Button = {
	root: Frame,
	face: TextButton,
	enabled: boolean,
	onClick: (() -> ())?,
	set: (self: Button, kind: string, text: string, icon: string?, textSize: number?, iconColor: Color3?) -> (),
}

local function makeButton(parent: Instance, x: number, y: number, w: number, h: number, z: number?, lipH: number?): Button
	local lip = lipH or 6
	local z0 = z or 4
	local root = frame(parent, x, y, w, h, z0, { Name = "Button" })
	local glowRing = frame(root, -4, -4, w + 8, h - lip + 8, z0)
	round(glowRing)
	local glowStroke = rim(glowRing, C.glow, 4, 1)
	local back = frame(root, 0, 0, w, h, z0, { BackgroundTransparency = 0 })
	round(back)
	local face = make("TextButton", {
		Size = UDim2.new(1, 0, 1, -lip),
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex = z0 + 1,
	}, root)
	round(face)
	rim(face, C.white, 1.5, 0.35)
	gloss(face, nil, 0.5, 0.5)
	local hover = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.white, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = z0 + 4 }, face)
	round(hover)
	local row = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = z0 + 3 }, face)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)

	local b = {} :: any
	b.root, b.face, b.enabled = root, face, true

	function b.set(self: Button, kind: string, text: string, icon: string?, textSize: number?, iconColor: Color3?)
		local k = KIND[kind] or KIND.white
		vgrad(face, { k[1], k[2] })
		back.BackgroundColor3 = k[3]
		for _, c in row:GetChildren() do
			if not c:IsA("UIListLayout") then
				c:Destroy()
			end
		end
		local fh = h - lip
		local size = textSize or math.floor(fh * 0.46)
		if icon then
			local s = math.floor(fh * 0.62)
			local slot = make("Frame", { Size = px(s, s), BackgroundTransparency = 1, LayoutOrder = 1, ZIndex = z0 + 3 }, row)
			local ic = iconFor(icon, slot, s / 2, s / 2, s, iconColor)
			if ic then
				ic.ZIndex = z0 + 3
			end
		end
		local t = make("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = F.boldItalic,
			Text = text,
			TextSize = size,
			TextColor3 = k[4],
			AutomaticSize = Enum.AutomaticSize.X,
			Size = px(0, fh),
			LayoutOrder = 2,
			ZIndex = z0 + 3,
		}, row)
		if k[4] == C.white then
			make("UIStroke", { Color = k[3], Thickness = 1.5, Transparency = 0.45 }, t)
		end
	end

	local hovering = false
	local function setHover(on: boolean)
		hovering = on
		local live = on and b.enabled
		tween(hover, 0.14, { BackgroundTransparency = if live then 0.82 else 1 })
		tween(glowStroke, 0.18, { Transparency = if live then 0.25 else 1 })
		tween(face, 0.14, { Position = px(0, if live then -2 else 0) })
	end
	face.MouseEnter:Connect(function() setHover(true) end)
	face.MouseLeave:Connect(function() setHover(false) end)
	face.SelectionGained:Connect(function() setHover(true) end)
	face.SelectionLost:Connect(function() setHover(false) end)
	face.MouseButton1Down:Connect(function()
		if b.enabled then
			tween(face, 0.06, { Position = px(0, lip - 2) })
		end
	end)
	face.MouseButton1Up:Connect(function()
		tween(face, 0.1, { Position = px(0, if hovering then -2 else 0) })
	end)
	face.Activated:Connect(function()
		tween(face, 0.1, { Position = px(0, if hovering then -2 else 0) })
		if b.enabled and b.onClick then
			b.onClick()
		end
	end)
	return b :: Button
end

-- A frosted white card with depth: soft shadow, inner gradient, bright rim, top gloss. Hover = lift + glow.
type Card = { slot: Frame, card: Frame, rim: UIStroke, glow: UIStroke, lifted: boolean, ring: Color3? }

local function makeCard(parent: Instance, name: string, x: number, y: number, w: number, h: number, r: number, z: number): Card
	local slot = frame(parent, x, y, w, h, z, { Name = name })
	softShadow(slot, 0, 0, w, h, r, z, 1)
	local card = frame(slot, 0, 0, w, h, z + 1, { BackgroundTransparency = 0.72 }) -- clear glass: the world shows
	round(card, r)
	vgrad(card, { C.white, hex("#eef6fd"), hex("#dbeaf8") })
	local edge = rim(card, C.white, 2, 0.1)
	gloss(card, r, 0.32, 0.65)
	local glowF = frame(slot, -5, -5, w + 10, h + 10, z, { Name = "Glow" })
	round(glowF, r + 5)
	local glow = rim(glowF, C.glow, 5, 1)
	local c = { slot = slot, card = card, rim = edge, glow = glow, lifted = false, ring = nil } :: Card
	local function lift(on: boolean)
		c.lifted = on
		tween(card, 0.16, { Position = px(0, if on then -5 else 0) }, Enum.EasingStyle.Back)
		tween(glowF, 0.16, { Position = px(-5, if on then -10 else -5) }, Enum.EasingStyle.Back)
		if not c.ring then
			tween(glow, 0.16, { Transparency = if on then 0.35 else 1 })
		end
	end
	card.MouseEnter:Connect(function() lift(true) end)
	card.MouseLeave:Connect(function() lift(false) end)
	return c
end

-- A permanent glowing ring (selected day / equipped item), or nil to clear it.
local pulses: { [UIStroke]: Tween } = {}
local function setRing(c: Card, color: Color3?)
	c.ring = color
	local old = pulses[c.glow]
	if old then
		old:Cancel()
		pulses[c.glow] = nil
	end
	if color then
		c.glow.Color = color
		c.glow.Transparency = 0.1
		c.rim.Color = color
		local tw = TweenService:Create(c.glow, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.6 })
		tw:Play()
		pulses[c.glow] = tw
	else
		c.glow.Color = C.glow
		c.glow.Transparency = if c.lifted then 0.35 else 1
		c.rim.Color = C.white
	end
end

------------------------------------------------------------------------------------------------------------------
-- Coins (client-only demo state)
------------------------------------------------------------------------------------------------------------------
local coins = DEMO.startCoins
local coinsShown = Instance.new("NumberValue")
coinsShown.Value = coins
local coinLabels: { TextLabel } = {}
local onCoinsChanged: { () -> () } = {}

coinsShown.Changed:Connect(function(v)
	local s = tostring(math.floor(v + 0.5))
	for _, l in coinLabels do
		l.Text = s
	end
end)

local function addCoins(n: number)
	coins = math.max(0, coins + n)
	tween(coinsShown, 0.8, { Value = coins }, Enum.EasingStyle.Quart)
	for _, fn in onCoinsChanged do
		fn()
	end
end

-- "+50" that floats up and fades (claim feedback)
local function floatText(parent: Instance, str: string, x: number, y: number)
	local t = label(parent, str, F.display, 36, C.goldLo, { AnchorPoint = Vector2.new(0.5, 0.5), Position = px(x, y), Size = px(200, 44), ZIndex = 30 })
	make("UIStroke", { Color = C.white, Thickness = 3 }, t)
	tween(t, 0.9, { Position = px(x, y - 50), TextTransparency = 1 })
	tween(t:FindFirstChildOfClass("UIStroke") :: UIStroke, 0.9, { Transparency = 1 })
	task.delay(0.95, function() t:Destroy() end)
end

------------------------------------------------------------------------------------------------------------------
-- Panel (the module does the 3D, tilt, blur, shadow and animations)
------------------------------------------------------------------------------------------------------------------
local sideHud = make("ScreenGui", { Name = "ImmersiveDemoSideHUD", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 5 }, playerGui)
local coinHud = make("ScreenGui", { Name = "ImmersiveDemoCoins", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 5 }, playerGui)

local panel = ImmersiveUI.new({
	Name = "DailyShopDemo",
	DesignSize = CANVAS,
	ScreenHeight = 1, -- ask for the whole free height; the module's tilt fit then shrinks it to the biggest safe size
	MaxScreenWidth = 0.98,
	PaneInsetTop = PANE_Y,
	Tilt = Vector2.new(7, 5), -- showcase tilt (module default 4, 3 is calmer for gameplay menus)
	TiltSmoothing = 6, -- a little floaty lag, like the ref
	Blur = 24,
	Tint = Color3.fromRGB(225, 240, 255), -- brightens + cools the world (Aero daylight), never darkens
	-- clear frosted glass: white, 55% see-through, soft white-to-sky gradient, bright rim, big round corners
	PaneColor = hex("#f4f9ff"),
	PaneTransparency = 0.55,
	PaneGradient = ColorSequence.new({
		ColorSequenceKeypoint.new(0, C.white),
		ColorSequenceKeypoint.new(0.5, hex("#eef6fe")),
		ColorSequenceKeypoint.new(1, hex("#d9ebfb")),
	}),
	PaneBorderColor = C.white,
	PaneCorner = 34,
	-- HideOtherGuis (default true) hides the demo's side buttons and coin pill while open; the coin pill on the
	-- panel's front layer takes over. On a fresh baseplate there is nothing else to hide.
})

-- The front layer floats FRONT_DEPTH studs in front of the glass (parallax as it tilts). If this module version has
-- no layers, the "front" things are simply drawn on each page instead.
local front: Frame? = nil
if type((panel :: any).AddLayer) == "function" then
	front = (panel :: any):AddLayer(FRONT_DEPTH, "Front")
end

------------------------------------------------------------------------------------------------------------------
-- Chrome: title pill (with shine), close button, coin pill. Built once on the front layer (so they stay put while
-- Daily <-> Shop swaps), or once per page when there are no layers.
------------------------------------------------------------------------------------------------------------------
type Chrome = { root: Frame, title: Frame, setTitle: (string) -> () }

-- Where each front element sits, so a dark shadow can be drawn under it ON THE GLASS. The element slides over its
-- shadow as the panel tilts: that is what proves the depth on camera.
local frontRects: { { number } } = {} -- { x, y, w, h, radius (nil = pill) }

local function buildChrome(parent: Instance): Chrome
	local root = frame(parent, 0, 0, CANVAS.X, CANVAS.Y, 10, { Name = "Chrome" })

	-- title pill, centred on the glass's top edge
	local tw, th = 300, 78
	local tx, ty = (CANVAS.X - tw) / 2, PANE_Y - th / 2
	if parent ~= front then
		softShadow(root, tx, ty, tw, th, nil, 10, 1.4)
	end
	table.insert(frontRects, { tx, ty, tw, th })
	local title = frame(root, tx, ty, tw, th, 11, { Name = "TitlePill", BackgroundTransparency = 0, ClipsDescendants = true })
	round(title)
	vgrad(title, { hex("#76ccff"), hex("#3a9cf0"), hex("#2378d8") })
	rim(title, C.white, 3, 0.05)
	gloss(title, nil, 0.5, 0.55)
	local titleText, titleShadow = display(title, "", 46, C.white, { Size = UDim2.fromScale(1, 1), ZIndex = 14, TextXAlignment = Enum.TextXAlignment.Center })

	-- close: round dark-glass button with a drawn X (dark so it has an edge against the white glass)
	local close = makeButton(root, PANE.X - 32 - 58, PANE_Y + 18, 58, 62, 11, 4)
	close:set("ink", "", nil)
	close.face.Name = "Close"
	table.insert(frontRects, { PANE.X - 32 - 58, PANE_Y + 18, 58, 58 })
	local xMark = holder(close.face, 29, 29, 26, "X", 16)
	for _, rot in { 45, -45 } do
		local bar = dot(xMark, 13, 13, 6, 28, C.white, 16, 3)
		bar.Rotation = rot
	end
	close.onClick = function()
		panel:Close()
	end

	-- coin pill
	local cx, cy, cw, chh = 32, PANE_Y + 18, 200, 58
	if parent ~= front then
		softShadow(root, cx, cy, cw, chh, nil, 10, 0.8)
	end
	table.insert(frontRects, { cx, cy, cw, chh })
	local pill = frame(root, cx, cy, cw, chh, 11, { Name = "CoinPill", BackgroundTransparency = 0.08 })
	round(pill)
	vgrad(pill, { KIND.ink[1], KIND.ink[2] })
	rim(pill, C.white, 2, 0.15)
	gloss(pill, nil, 0.45, 0.35)
	Icon.coin(pill, 30, chh / 2, 44).ZIndex = 13
	local count = label(pill, tostring(coins), F.display, 32, C.white, { Position = px(60, 0), Size = px(126, chh), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13 })
	table.insert(coinLabels, count)

	local c = { root = root, title = title } :: any
	c.setTitle = function(s: string)
		titleText.Text = s
		titleShadow.Text = s
	end
	return c :: Chrome
end

------------------------------------------------------------------------------------------------------------------
-- Pages. Each page is a full-canvas Frame; the body sits exactly over the glass (y = PANE_Y).
------------------------------------------------------------------------------------------------------------------
local function makePage(name: string)
	local page = make("Frame", { Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 1 }, nil)
	local body = frame(page, 0, PANE_Y, PANE.X, PANE.Y, 1, { Name = "Body" })
	return page, body
end

local sharedChrome: Chrome? = if front then buildChrome(front) else nil

------------------------------------------------------------------------------------------------------------------
-- DAILY page
------------------------------------------------------------------------------------------------------------------
local Daily = {} :: any
do
	local page, body = makePage("Daily")
	Daily.page = page
	Daily.chrome = if sharedChrome then nil else buildChrome(page)

	eyebrow(body, "Daily rewards", 36, 104, 400) -- coin pill ends at 76 (+~20 px slide): clear

	-- 7 frosted day cards: x 34, w 138, gap 11, y 132, h 178
	Daily.tiles = {}
	Daily.claimed = {}
	for i, d in DEMO.days do
		local c = makeCard(body, "Day" .. i, 34 + (i - 1) * 149, 142, 138, 172, 20, 3)
		local card = c.card
		eyebrow(card, "Day " .. i, 0, 12, 138, Enum.TextXAlignment.Center)
		if d.gift then
			Icon.gift(card, 69, 78, 66)
		else
			Icon.coin(card, 69, 78, 62)
		end
		display(card, "+" .. d.coins, 38, C.ink, { Position = px(0, 116), Size = px(138, 46), TextXAlignment = Enum.TextXAlignment.Center })
		local veil = frame(card, 0, 0, 138, 172, 12, { BackgroundColor3 = C.white, BackgroundTransparency = 1 })
		round(veil, 20)
		Daily.tiles[i] = { c = c, veil = veil, tick = nil :: Frame? }
	end

	-- main CLAIM (front layer when available: it floats off the glass)
	local claimParent: Instance = front or body
	local claimY = if front then PANE_Y + 330 else 330
	if front then
		-- its shadow lies on the glass (this page), the button floats on the front layer
		local sh = frame(body, (PANE.X - 380) / 2, 330 + 6, 380, 74, 2, { Name = "ClaimShadow", BackgroundColor3 = C.shadow, BackgroundTransparency = 0.85 })
		round(sh)
		Daily.claimShadow = nil
	else
		Daily.claimShadow = softShadow(claimParent, (PANE.X - 380) / 2, claimY, 380, 80, nil, 3, 1.2)
	end
	Daily.claim = makeButton(claimParent, (PANE.X - 380) / 2, claimY, 380, 80, 4, 8)
	Daily.claimRoot = Daily.claim.root

	eyebrow(body, "Missions", 36, 432, 300)
	Daily.countdown = eyebrow(body, "", 516, 432, 550, Enum.TextXAlignment.Right, C.inkSoft)

	-- 3 mission rows: x 34, w 1032, tops 470 / 546 / 622, h 66
	Daily.rows = {}
	for i, m in DEMO.missions do
		local c = makeCard(body, "Mission" .. i, 34, 474 + (i - 1) * 76, 1032, 68, 18, 3)
		local row = c.card
		iconFor(m.icon, row, 40, 34, 44)
		label(row, m.title, F.boldItalic, 28, C.ink, { Position = px(78, 4), Size = px(500, 34), TextXAlignment = Enum.TextXAlignment.Left })
		local track = frame(row, 78, 44, 400, 12, 5, { BackgroundColor3 = C.track, BackgroundTransparency = 0 })
		round(track)
		local done = m.have >= m.need
		local fill = frame(track, 0, 0, 0, 0, 6, { Size = UDim2.fromScale(math.clamp(m.have / m.need, 0.04, 1), 1), BackgroundTransparency = 0, BackgroundColor3 = C.white })
		round(fill)
		local fg = make("UIGradient", { Color = if done then ColorSequence.new(hex("#8ff05a"), C.good) else ColorSequence.new(C.aqua, C.sky) }, fill)
		fg.Rotation = 0
		gloss(fill, nil, 0.5, 0.5)
		label(row, m.have .. " / " .. m.need, F.boldItalic, 24, C.ink, { Position = px(490, 36), Size = px(100, 28), TextXAlignment = Enum.TextXAlignment.Left })
		Icon.coin(row, 620, 34, 42)
		display(row, "+" .. m.coins, 38, C.ink, { Position = px(648, 12), Size = px(140, 44), TextXAlignment = Enum.TextXAlignment.Left })
		local btn: Button? = nil
		if done then
			btn = makeButton(row, 834, 8, 184, 54, 6, 6)
		end
		Daily.rows[i] = { c = c, button = btn, claimed = false }
	end
end

local function refreshDaily()
	for i, t in Daily.tiles do
		local claimed = Daily.claimed[i] == true
		setRing(t.c, if i == DEMO.today and not claimed then C.aqua else nil)
		t.veil.BackgroundTransparency = if claimed then 0.45 else 1
		if claimed and not t.tick then
			t.tick = Icon.tick(t.c.card, 116, 22, 30)
			t.tick.ZIndex = 14
		end
	end
	if Daily.claimed[DEMO.today] then
		Daily.claim:set("white", "Come back tomorrow", nil, 24)
		Daily.claim.enabled = false
	else
		Daily.claim:set("cta", "CLAIM DAY " .. DEMO.today, "gift", 32)
		Daily.claim.enabled = true
	end
	for i, r in Daily.rows do
		if r.button then
			setRing(r.c, if not r.claimed then C.good else nil)
			if r.claimed then
				r.button:set("white", "Claimed", "tick", 24)
				r.button.enabled = false
			else
				r.button:set("sky", "CLAIM", nil, 28)
				r.button.enabled = true
			end
		end
	end
end

-- Replace these with your own server-checked code in a real game.
Daily.claim.onClick = function()
	local i = DEMO.today
	if Daily.claimed[i] then
		return
	end
	Daily.claimed[i] = true
	local slot = Daily.tiles[i].c.slot
	floatText(slot.Parent :: Instance, "+" .. DEMO.days[i].coins, slot.Position.X.Offset + 69, slot.Position.Y.Offset + 40)
	addCoins(DEMO.days[i].coins)
	refreshDaily()
	panel:Shine(Daily.claim.face) -- second beat for the clip
	local badge = sideHud:FindFirstChild("Badge", true)
	if badge then
		(badge :: GuiObject).Visible = false
	end
end

for i, r in Daily.rows do
	if r.button then
		r.button.onClick = function()
			if r.claimed then
				return
			end
			r.claimed = true
			floatText(r.c.card, "+" .. DEMO.missions[i].coins, 680, 10)
			addCoins(DEMO.missions[i].coins)
			refreshDaily()
		end
	end
end

refreshDaily()

local function tracked(str: string): string
	return (string.gsub(string.upper(str), ".", "%0" .. THIN):sub(1, -1 - #THIN))
end

-- Countdown from a fixed deadline (no drift). At zero it says so and stops (a real game would roll new missions).
table.insert(threads, task.spawn(function()
	local deadline = os.clock() + DEMO.newMissionsInSeconds
	while true do
		local left = math.max(0, deadline - os.clock())
		if left <= 0 then
			Daily.countdown.Text = tracked("New missions ready")
			Daily.countdown.TextColor3 = C.good
			return
		end
		Daily.countdown.Text = tracked(string.format("New missions in %dh %02dm", left // 3600, (left % 3600) // 60))
		task.wait(1)
	end
end))

------------------------------------------------------------------------------------------------------------------
-- SHOP page
------------------------------------------------------------------------------------------------------------------
local Shop = {} :: any
do
	local page, body = makePage("Shop")
	Shop.page, Shop.body = page, body
	Shop.chrome = if sharedChrome then nil else buildChrome(page)
	Shop.current = 1
	Shop.owned = {}
	Shop.equipped = {}
	for t, data in DEMO.shop do
		Shop.owned[t] = {}
		for i, item in data.items do
			Shop.owned[t][i] = (item.price or 1) == 0
		end
		Shop.equipped[t] = 1
	end

	-- pill tab track (frosted), the active tab is a solid white pill
	local track = frame(body, 34, 104, 1032, 62, 3, { Name = "Tabs", BackgroundColor3 = C.white, BackgroundTransparency = 0.55 })
	round(track)
	rim(track, C.white, 2, 0.1)
	Shop.tabs = {}
	local tabW = (1032 - 12) / 5
	for t, data in DEMO.shop do
		local x = 6 + (t - 1) * (tabW + 0)
		local pillF = frame(track, x, 6, tabW, 50, 4, { BackgroundColor3 = C.white, BackgroundTransparency = 1 })
		round(pillF)
		local pStroke = rim(pillF, C.white, 2, 1)
		local btn = make("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 8, Name = "Tab_" .. data.name }, pillF)
		local row = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 6 }, pillF)
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, row)
		local slot = make("Frame", { Size = px(34, 34), BackgroundTransparency = 1, LayoutOrder = 1, ZIndex = 6 }, row)
		iconFor(data.icon, slot, 17, 17, 34)
		local txt = make("TextLabel", { BackgroundTransparency = 1, FontFace = F.boldItalic, Text = data.name, TextSize = 26, TextColor3 = C.ink, AutomaticSize = Enum.AutomaticSize.X, Size = px(0, 50), LayoutOrder = 2, ZIndex = 6 }, row)
		btn.MouseEnter:Connect(function()
			if Shop.current ~= t then
				tween(pillF, 0.12, { BackgroundTransparency = 0.6 })
			end
		end)
		btn.MouseLeave:Connect(function()
			if Shop.current ~= t then
				tween(pillF, 0.12, { BackgroundTransparency = 1 })
			end
		end)
		Shop.tabs[t] = { pill = pillF, stroke = pStroke, button = btn, text = txt }
	end

	Shop.grid = frame(body, 34, 184, 1032, 512, 3, { Name = "Grid" })
end

local function refreshTabs()
	for t, tab in Shop.tabs do
		local on = t == Shop.current
		tab.pill.BackgroundTransparency = if on then 0 else 1
		tab.stroke.Transparency = if on then 0.2 else 1
		tab.text.TextColor3 = C.ink
		tab.text.TextTransparency = if on then 0 else 0.25
		if on then
			vgrad(tab.pill, { C.white, hex("#eaf3fc") })
		end
	end
end

local cardRefs = {}

local function refreshCards()
	local t = Shop.current
	local data = DEMO.shop[t]
	for i, ref in cardRefs do
		local item = data.items[i]
		if data.money then
			ref.button:set("sky", "GET +" .. item.give, "coin", 28)
			setRing(ref.c, nil)
		elseif Shop.equipped[t] == i then
			ref.button:set("white", "Equipped", "tick", 28)
			setRing(ref.c, C.good)
		elseif Shop.owned[t][i] then
			ref.button:set("white", "EQUIP", nil, 28)
			setRing(ref.c, nil)
		else
			ref.button:set(if coins >= item.price then "sky" else "muted", tostring(item.price), "coin", 32)
			setRing(ref.c, nil)
		end
	end
end
table.insert(onCoinsChanged, function()
	if #cardRefs > 0 then
		refreshCards()
	end
end)

-- One cancellable shake per GuiObject, always from (and back to) its resting position.
local shaking: { [GuiObject]: { rest: UDim2, thread: thread } } = {}
local function shake(o: GuiObject)
	local cur = shaking[o]
	if cur then
		task.cancel(cur.thread)
		o.Position = cur.rest
	end
	local rest = o.Position
	local th = task.spawn(function()
		for _, dx in { -8, 8, -6, 6, -3 } do
			o.Position = rest + px(dx, 0)
			task.wait(0.03)
		end
		o.Position = rest
		shaking[o] = nil
	end)
	if coroutine.status(th) ~= "dead" then
		shaking[o] = { rest = rest, thread = th }
	end
end

-- Replace with your own server-checked purchase code in a real game.
local function onCard(i: number)
	local t = Shop.current
	local data = DEMO.shop[t]
	local item = data.items[i]
	local ref = cardRefs[i]
	if data.money then
		floatText(ref.c.card, "+" .. item.give, 166, 70)
		addCoins(item.give)
	elseif Shop.equipped[t] == i then
		return
	elseif Shop.owned[t][i] then
		Shop.equipped[t] = i
	elseif coins >= item.price then
		Shop.owned[t][i] = true
		Shop.equipped[t] = i
		addCoins(-item.price)
	else
		shake(ref.button.root)
		ref.button:set("red", "Need " .. (item.price - coins) .. " more", nil, 26)
		task.delay(0.9, function()
			if cardRefs[i] == ref then
				refreshCards()
			end
		end)
		return
	end
	refreshCards()
end

local function buildCards()
	for _, ref in cardRefs do
		setRing(ref.c, nil) -- stop pulses
	end
	Shop.grid:ClearAllChildren()
	table.clear(cardRefs)
	local t = Shop.current
	local data = DEMO.shop[t]
	for i, item in data.items do
		local col = (i - 1) % 3
		local row = math.floor((i - 1) / 3)
		local c = makeCard(Shop.grid, "Item_" .. item.name, col * (332 + 18), row * (244 + 24), 332, 244, 22, 3)
		local card = c.card
		local well = frame(card, 12, 10, 308, 108, 5, { Name = "Preview" }) -- no background: no card inside a card
		local colors = toColors(item.colors)
		if item.name == "None" then
			Icon.none(well, 154, 54, 62)
		elseif data.money then
			for k = 1, item.stack do
				Icon.coin(well, 154 + (((k - 1) % 3) - 1) * 40 + (if k > 3 then 20 else 0), 70 - math.floor((k - 1) / 3) * 30, 50).ZIndex = 6 + k
			end
		elseif data.icon == "trails" then
			trailPreview(well, 308, 108, colors)
		else
			iconFor(data.icon, well, 154, 54, 80, colors[1])
		end
		label(card, item.name, F.display, 32, C.ink, { Position = px(14, 120), Size = px(304, 40), TextXAlignment = Enum.TextXAlignment.Center })
		local b = makeButton(card, 14, 174, 304, 60, 6, 6)
		b.onClick = function()
			onCard(i)
		end
		cardRefs[i] = { c = c, button = b }
	end
	refreshCards()
	Shop.grid.Position = px(34, 194)
	tween(Shop.grid, 0.16, { Position = px(34, 184) })
end

local function selectTab(t: number)
	Shop.current = t
	refreshTabs()
	buildCards()
end

for t, tab in Shop.tabs do
	tab.button.Activated:Connect(function()
		if Shop.current ~= t then
			selectTab(t)
		end
	end)
end
selectTab(1)

------------------------------------------------------------------------------------------------------------------
-- Switching pages. One panel; Daily <-> Shop swaps the content with panel:SetContent (the ref's empty-pane beat).
-- On the front layer the title text changes and the CLAIM button shows only on Daily.
------------------------------------------------------------------------------------------------------------------
local currentPage: Frame? = nil

local function chromeOf(page: Frame?): Chrome?
	if sharedChrome then
		return sharedChrome
	end
	return if page == Daily.page then Daily.chrome elseif page == Shop.page then Shop.chrome else nil
end

local function applyFront(page: Frame)
	if sharedChrome then
		sharedChrome.setTitle(if page == Shop.page then "SHOP" else "DAILY")
	end
	if front then
		Daily.claimRoot.Visible = page == Daily.page
		if Daily.claimShadow then
			Daily.claimShadow.Visible = page == Daily.page
		end
	end
end

local function focusFirst()
	if not UserInputService.GamepadEnabled then
		return
	end
	if currentPage == Daily.page then
		GuiService.SelectedObject = Daily.claim.face
	elseif currentPage == Shop.page then
		GuiService.SelectedObject = Shop.tabs[Shop.current].button
	end
end

local function show(which: string, shopTab: number?)
	local page = if which == "Shop" then Shop.page else Daily.page
	if shopTab and shopTab ~= Shop.current then
		selectTab(shopTab)
	end
	if currentPage ~= page then
		local wasOpen = panel.IsOpen
		panel:SetContent(page)
		currentPage = page
		if wasOpen then
			if front then
				Daily.claimRoot.Visible = false -- out with the old content, in with the new
			end
			task.delay(0.07, function()
				if currentPage == page then
					applyFront(page)
				end
			end)
			task.delay(0.12, function()
				local ch = chromeOf(page)
				if currentPage == page and panel.IsOpen and ch then
					panel:Shine(ch.title)
					focusFirst()
				end
			end)
		else
			applyFront(page)
		end
	end
	if not panel.IsOpen then
		panel:Open()
	end
end

-- Opened fires as the open starts; Shine waits for the open animation by itself.
panel.Opened:Connect(function()
	local ch = chromeOf(currentPage)
	if ch then
		panel:Shine(ch.title)
	end
	focusFirst()
end)

panel.Closed:Connect(function()
	local sel = GuiService.SelectedObject
	if sel and (sel:IsDescendantOf(panel.Content) or (front and sel:IsDescendantOf(front))) then
		GuiService.SelectedObject = nil
	end
end)

-- Gamepad B closes it.
track(UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.ButtonB and panel.IsOpen then
		panel:Close()
	end
end))

------------------------------------------------------------------------------------------------------------------
-- HUD: left side buttons (hidden while the panel is open) + coin pill (stays)
------------------------------------------------------------------------------------------------------------------
do
	local scale = make("UIScale", {}, nil)
	local scale2 = make("UIScale", {}, nil)

	local column = make("Frame", { Name = "Column", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 24, 0.5, -30), Size = px(250, 250), BackgroundTransparency = 1 }, sideHud)
	scale.Parent = column

	local function sideButton(name: string, text: string, x: number, y: number, icon: string, onClick: () -> ())
		local slot = frame(column, x, y, 112, 112, 1, { Name = name })
		softShadow(slot, 0, 0, 112, 112, 26, 1, 0.9)
		local b = make("TextButton", { Position = px(0, 0), Size = px(112, 112), BackgroundTransparency = 0.12, AutoButtonColor = false, Text = "", BorderSizePixel = 0, ZIndex = 2 }, slot)
		round(b, 26)
		vgrad(b, { C.white, hex("#e3eef8") })
		local st = rim(b, C.white, 2, 0.05)
		gloss(b, 26, 0.4, 0.6)
		iconFor(icon, b, 56, 46, 56)
		label(b, text, F.boldItalic, 18, C.ink, { Position = px(0, 80), Size = px(112, 22), TextXAlignment = Enum.TextXAlignment.Center })
		b.MouseEnter:Connect(function()
			tween(b, 0.14, { Position = px(0, -4) }, Enum.EasingStyle.Back)
			st.Color = C.aqua
		end)
		b.MouseLeave:Connect(function()
			tween(b, 0.14, { Position = px(0, 0) })
			st.Color = C.white
		end)
		b.Activated:Connect(onClick)
		return b
	end

	sideButton("Shop", "SHOP", 0, 0, "bag", function() show("Shop", 1) end)
	sideButton("Emotes", "EMOTES", 126, 0, "note", function() show("Shop", 4) end)
	local daily = sideButton("Daily", "DAILY", 0, 126, "gift", function() show("Daily") end)
	local badge = dot(daily, 104, 8, 30, 30, KIND.cta[2], 6)
	badge.Name = "Badge"
	vgrad(badge, { KIND.cta[1], KIND.cta[2] })
	rim(badge, C.white, 2.5)
	label(badge, "!", F.display, 20, C.white, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 8 })

	-- AFK switch (hides with the side buttons, like the ref)
	local afkOn = false
	local afk = make("TextButton", { Name = "AFK", AnchorPoint = Vector2.new(0, 1), Size = px(238, 56), BackgroundTransparency = 0.12, AutoButtonColor = false, Text = "", BorderSizePixel = 0 }, sideHud)
	round(afk)
	vgrad(afk, { C.white, hex("#e3eef8") })
	rim(afk, C.white, 2, 0.05)
	local afkScale = make("UIScale", {}, afk)
	label(afk, "AFK", F.boldItalic, 20, C.ink, { Position = px(22, 0), Size = px(80, 56), TextXAlignment = Enum.TextXAlignment.Left })
	local sw = frame(afk, 150, 14, 68, 28, 3, { BackgroundColor3 = C.track, BackgroundTransparency = 0 })
	round(sw)
	local knob = dot(sw, 14, 14, 24, 24, C.white, 4)
	rim(knob, hex("#b6c9db"), 1.5)
	afk.Activated:Connect(function()
		afkOn = not afkOn
		tween(knob, 0.18, { Position = px(if afkOn then 54 else 14, 14) }, Enum.EasingStyle.Back)
		tween(sw, 0.18, { BackgroundColor3 = if afkOn then C.good else C.track })
	end)

	-- coin pill (stays visible while the panel is open)
	local box = make("Frame", { Name = "CoinPill", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 24, 1, -24), Size = px(238, 68), BackgroundTransparency = 0.08, BorderSizePixel = 0 }, coinHud)
	round(box)
	vgrad(box, { C.white, hex("#e3eef8") })
	rim(box, C.white, 2, 0)
	scale2.Parent = box
	Icon.coin(box, 36, 34, 50)
	local n = label(box, tostring(coins), F.display, 34, C.ink, { Position = px(70, 0), Size = px(150, 68), TextXAlignment = Enum.TextXAlignment.Left })
	table.insert(coinLabels, n)

	local function place()
		local cam = workspace.CurrentCamera
		local h = if cam then cam.ViewportSize.Y else 1080
		local s = math.clamp(h / 1080, 0.55, 1.25)
		scale.Scale, scale2.Scale, afkScale.Scale = s, s, s
		afk.Position = UDim2.new(0, 24, 1, -24 - (68 + 12) * s)
	end
	local camConn: RBXScriptConnection? = nil
	local function watchCamera()
		if camConn then
			camConn:Disconnect()
		end
		local cam = workspace.CurrentCamera
		if cam then
			camConn = track(cam:GetPropertyChangedSignal("ViewportSize"):Connect(place))
		end
		place()
	end
	track(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera))
	watchCamera()
end

------------------------------------------------------------------------------------------------------------------
-- Studio test hook: Players.<you>:SetAttribute("ImmersiveDemoOpen", "Daily" | "Shop" | "")
------------------------------------------------------------------------------------------------------------------
track(player:GetAttributeChangedSignal("ImmersiveDemoOpen"):Connect(function()
	local v = player:GetAttribute("ImmersiveDemoOpen")
	if v == "Daily" or v == "Shop" then
		show(v)
	elseif panel.IsOpen then
		panel:Close()
	end
end))

-- Start with the Daily page loaded (closed), so the first open has content ready.
panel:SetContent(Daily.page)
currentPage = Daily.page
applyFront(Daily.page)

-- Shadows of the front-layer chrome, drawn on the glass. Added AFTER the first SetContent so page swaps leave them
-- alone. The title's shadow is clipped to the glass (above the glass is open air).
if front then
	local clip = frame(panel.Content, 0, PANE_Y, PANE.X, PANE.Y, 1, { Name = "FrontShadows", ClipsDescendants = true })
	for _, r in frontRects do
		local sh = frame(clip, r[1], r[2] - PANE_Y + 6, r[3], r[4], 1, { BackgroundColor3 = C.shadow, BackgroundTransparency = 0.85 })
		round(sh, r[5])
	end
end

------------------------------------------------------------------------------------------------------------------
-- Teardown: undo everything this script made (runs if the script is removed, e.g. you swap in your own UI).
------------------------------------------------------------------------------------------------------------------
local tornDown = false
local function teardown()
	if tornDown then
		return
	end
	tornDown = true
	for _, th in threads do
		pcall(task.cancel, th)
	end
	for _, s in shaking do
		pcall(task.cancel, s.thread)
	end
	for _, tw in pulses do
		tw:Cancel()
	end
	for _, c in conns do
		c:Disconnect()
	end
	panel:Destroy()
	sideHud:Destroy()
	coinHud:Destroy()
	coinsShown:Destroy()
end
script.Destroying:Connect(teardown)
