--!strict
--[[
	Immersive  (ModuleScript in SpeedPetsUI.Scripts)
	Puts every SpeedPets window (Shop, Index, Hollow, Settings, Merchant) on its own 3D ImmersiveUI panel: the window
	floats in front of the camera, tilts toward the mouse and swings in. The pack's own pop animation, blur and
	buttons keep working; this module only moves each window's Host onto a panel and keeps the two in sync.

	- Windows.open(name)  -> that panel opens (opening another closes the first, like before)
	- Windows.close()     -> the panel closes
	- the panel closes itself (click outside, respawn) -> Windows.close(name)
	- while a panel is open the HUD, top bar and drawers hide (ScreenGuis always draw over 3D panels)
	- ctx.toCanvas(screenPoint, guiObject) maps a screen point onto that object's panel (Settings sliders use it)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Immersive = {}

local WINDOWS = { "Shop", "Index", "Hollow", "Settings", "Merchant", "Rewards" }
local DRAWERS = { "GrowingEggs", "PetsDrawer" }
local MARGIN = 40 -- canvas px of air around each window's furthest-out piece
local REF_H = 1056 -- the pack's design height (Scale.REF_H)

-- bounds of everything that draws for this window, in the Host's own px (DesignScale divided out). Pieces inside a
-- ClipsDescendants frame only count as far as that frame (rotated header stripes poke out but never draw out there).
local function measure(host: GuiObject, s: number): (Vector2, Vector2)
	local hp = host.AbsolutePosition
	local minV = Vector2.new(0, 0)
	local maxV = host.AbsoluteSize / s
	local function visit(o: Instance, clipLo: Vector2?, clipHi: Vector2?)
		for _, c in o:GetChildren() do
			if c:IsA("GuiObject") and (c.Visible or c.Name == "Window") then
				local a = (c.AbsolutePosition - hp) / s
				local b = a + c.AbsoluteSize / s
				if clipLo and clipHi then
					a = a:Max(clipLo)
					b = b:Min(clipHi)
				end
				if b.X > a.X and b.Y > a.Y then
					minV = minV:Min(a)
					maxV = maxV:Max(b)
				end
				-- scroll content is clipped by the frame, so its size never counts
				if not c:IsA("ScrollingFrame") then
					if c.ClipsDescendants then
						visit(c, a, b)
					else
						visit(c, clipLo, clipHi)
					end
				end
			end
		end
	end
	visit(host, nil, nil)
	return minV, maxV
end

function Immersive.init(ctx: any)
	local mod = ReplicatedStorage:FindFirstChild("ImmersiveUI")
	if not mod or not mod:IsA("ModuleScript") then
		warn("[SpeedPetsUI] Immersive: ReplicatedStorage.ImmersiveUI not found, windows stay flat")
		return
	end
	local ImmersiveUI = require(mod) :: any
	local gui = ctx.gui :: ScreenGui
	local root = ctx.root :: Frame
	local Windows = ctx.Windows
	local Scale = ctx.Scale

	-- screen-space pieces that hide while a window is up (the ref's side buttons slide away the same way)
	local hideList: { GuiObject } = {}
	for _, n in { "HUD", "Topbar", "Drawers", "Hotbar" } do
		local f = root:FindFirstChild(n)
		if f and f:IsA("GuiObject") then
			table.insert(hideList, f)
		end
	end
	local openCount = 0
	local hudHidden = false
	local wasVisible: { [GuiObject]: boolean } = {}
	local function resetPress(container: Instance)
		-- a button hidden under the cursor never gets MouseLeave: drop its hover grow + shade
		for _, d in container:GetDescendants() do
			if d:IsA("UIScale") and (d.Name == "Pop" or d.Name == "PressPop") then
				d.Scale = 1
			elseif d:IsA("Frame") and d.Name == "Shade" and d.Parent and d.Parent.Name == "Visual" then
				d.BackgroundTransparency = 1
			end
		end
	end
	local function setHudHidden(hidden: boolean)
		if hidden == hudHidden then
			return
		end
		hudHidden = hidden
		for _, f in hideList do
			if hidden then
				wasVisible[f] = f.Visible
				f.Visible = false
			else
				f.Visible = if wasVisible[f] == nil then true else wasVisible[f]
				resetPress(f)
			end
		end
	end

	-- one motion per window: the panel swings in, so the pack's own 110 px slide is dropped (its scale pop stays)
	local Config = require(ctx.Scripts.Config) :: any
	for _, name in WINDOWS do
		local tr = Config.Transitions[name]
		if tr and not tr.custom and tr.open and tr.close then
			local o, c = table.clone(tr.open), table.clone(tr.close)
			o.fromOffset = nil
			c.toOffset = nil
			Config.Transitions[name] = { open = o, close = c }
		end
	end

	-- AbsolutePosition needs one layout pass after Scale.apply. Measure off-screen so nothing flashes.
	local rootPos = root.Position
	root.Position = UDim2.fromOffset(-20000, -20000)
	task.wait()
	local s = math.max(0.05, Scale.value :: number)

	local panels: { [string]: any } = {}
	local hostOf: { [string]: GuiObject } = {}
	for _, name in WINDOWS do
		local sec = root:FindFirstChild(name)
		local host = sec and sec:FindFirstChild("Host")
		if host and host:IsA("GuiObject") then
			local fit = host:FindFirstChild("Fit") :: UIScale?
			if fit then
				fit.Scale = 1
			end
			-- measure with the window shown for one frame (invisible things have no layout)
			local win = host:FindFirstChild("Window") :: GuiObject?
			local wasVisible = win and win.Visible
			if win then
				win.Visible = true
			end
			task.wait()
			local lo, hi = measure(host, s)
			if win then
				win.Visible = wasVisible :: boolean
			end
			lo -= Vector2.new(MARGIN, MARGIN)
			hi += Vector2.new(MARGIN, MARGIN)
			local size = Vector2.new(math.ceil(hi.X - lo.X), math.ceil(hi.Y - lo.Y))

			local panel = ImmersiveUI.new({
				Name = "SPUI_" .. name,
				DesignSize = size,
				ScreenHeight = math.clamp(size.Y / REF_H * 1.25, 0.6, 0.94), -- a bit bigger than the pack drew it flat
				MaxScreenWidth = 1,
				FitFOV = 72, -- this place keeps Roblox's default 70 FOV, so fit for that (bigger panels)
				-- wide windows get a smaller yaw: their edges swing more in perspective, and the fit would shrink them
				Tilt = Vector2.new(math.clamp(8.5 * size.Y / size.X * 1.6, 4.5, 8.5), 5.5),
				TiltSmoothing = 8,
				Pane = false, -- the window draws its own background
				Shadow = false,
				Glint = false,
				ManageEffects = false, -- the pack's own blur (SPUI_MenuBlur) stays in charge
				HideOtherGuis = true,
				KeepGuis = { gui }, -- keep this gui: its tooltip draws on top; we hide the HUD ourselves
				FadeContent = false, -- the pack's pop animation does the fade feel
				CloseOnClickOutside = true,
			})

			host:SetAttribute("ImmersiveHost", true)
			host.AnchorPoint = Vector2.zero
			host.Position = UDim2.fromOffset(-lo.X, -lo.Y)
			host.Parent = panel.Content

			panels[name] = panel
			hostOf[name] = host

			panel.Closed:Connect(function()
				-- the panel closed itself (click outside, respawn). Deferred signals: skip if it was reopened meanwhile.
				if Windows.current() == name and not panel.IsOpen then
					Windows.close(name)
				end
			end)
			panel:OnModalChanged(function(on: boolean)
				openCount += if on then 1 else -1
				openCount = math.max(0, openCount)
				setHudHidden(openCount > 0)
			end)
		end
	end
	-- the side drawers (Eggs / Pets) get their own tilting panels too. The Drawers module keeps sliding the group by
	-- its home Position, which is in Root px (scale + offset), so each group sits on a "stage" the size of Root,
	-- shifted so the drawer lands inside the canvas. The slide-in becomes a wipe across the panel.
	local drawerSec = root:FindFirstChild("Drawers")
	local drawerPanels: { [string]: any } = {}
	for _, name in DRAWERS do
		local group = drawerSec and drawerSec:FindFirstChild(name)
		if group and group:IsA("GuiObject") then
			local home = group.Position
			local was = group.Visible
			group.Visible = true
			task.wait()
			local lo, hi = measure(group, s)
			group.Visible = was
			lo -= Vector2.new(MARGIN, MARGIN)
			hi += Vector2.new(MARGIN, MARGIN)
			local size = Vector2.new(math.ceil(hi.X - lo.X), math.ceil(hi.Y - lo.Y))
			local panel = ImmersiveUI.new({
				Name = "SPUI_" .. name,
				DesignSize = size,
				ScreenHeight = math.clamp(size.Y / REF_H * 1.6, 0.45, 0.72),
				MaxScreenWidth = 1,
				FitFOV = 72,
				Tilt = Vector2.new(8, 6),
				TiltSmoothing = 8,
				Pane = false,
				Shadow = false,
				Glint = false,
				Blur = 14,
				HideOtherGuis = true,
				KeepGuis = { gui },
				FadeContent = false,
				CloseOnClickOutside = true,
			})
			local stage = Instance.new("Frame")
			stage.Name = "Stage_" .. name
			stage.BackgroundTransparency = 1
			stage.Parent = panel.Content
			local function placeStage(design: Vector2)
				stage.Size = UDim2.fromOffset(design.X, design.Y)
				local hx = home.X.Scale * design.X + home.X.Offset
				local hy = home.Y.Scale * design.Y + home.Y.Offset
				stage.Position = UDim2.fromOffset(-lo.X - hx, -lo.Y - hy)
			end
			placeStage(Scale.design :: Vector2)
			Scale.onChanged(function(_s: number, design: Vector2)
				placeStage(design)
			end)
			group.Parent = stage
			drawerPanels[name] = panel
			hostOf[name] = group
			panel.Closed:Connect(function()
				if gui:GetAttribute("DrawerOpen") == name and not panel.IsOpen then
					local api = ctx.api.Drawers
					if api then
						api.close()
					end
				end
			end)
		end
	end
	gui:GetAttributeChangedSignal("DrawerOpen"):Connect(function()
		local open = gui:GetAttribute("DrawerOpen")
		for name, panel in drawerPanels do
			if name == open then
				if not panel.IsOpen then
					panel:Open()
				end
			elseif panel.IsOpen then
				panel:Close()
			end
		end
	end)
	for name, panel in drawerPanels do
		panels[name] = panel
	end

	if root.Position == UDim2.fromOffset(-20000, -20000) then
		root.Position = rootPos
	end

	Windows.onChanged(function(cur: string?, prev: string?)
		if prev and prev ~= cur and panels[prev] and panels[prev].IsOpen then
			panels[prev]:Close()
		end
		if cur and panels[cur] then
			if not panels[cur].IsOpen then
				panels[cur]:Open()
			end
		end
		local win = if prev then hostOf[prev] else nil
		if win and prev ~= cur then
			task.delay(0.3, function()
				if Windows.current() ~= prev then
					resetPress(win)
				end
			end)
		end
	end)

	-- a window already open before we got here (Dev command during load)
	local now = Windows.current()
	if now and panels[now] then
		panels[now]:Open()
	end

	ctx.toCanvas = function(screen: Vector2, target: GuiObject): Vector2?
		for name, host in hostOf do
			if target:IsDescendantOf(host) then
				local p = panels[name]:ScreenToCanvas(screen, true, target)
				return p
			end
		end
		return nil
	end
	ctx.panels = panels
end

return Immersive
