--!strict
--[[
	ImmersiveUI  (made by @momentumcash, MIT licence)
	================================================================================================================
	Turns any menu into a glass panel that floats in 3D in front of the camera, tilts toward your mouse, and blurs the
	world behind it, like the menus in the big simulator / racing games. One ModuleScript, no dependencies, client only.

	QUICK START (a LocalScript):

		local ImmersiveUI = require(game.ReplicatedStorage.ImmersiveUI)
		local panel = ImmersiveUI.new({ Name = "Shop", DesignSize = Vector2.new(1100, 720) })
		myShopFrame.Size = UDim2.fromScale(1, 1)  -- your menu, laid out in DesignSize pixels
		myShopFrame.Parent = panel.Content
		openButton.Activated:Connect(function() panel:Toggle() end)

	HOW IT WORKS
	- An invisible, local, anchored Part sits `Distance` studs in front of the camera, re-placed every frame AFTER the
	  game's camera scripts (BindToRenderStep at `RenderPriority`), so it never lags a frame behind the camera.
	- A SurfaceGui in PlayerGui is drawn on that Part's Back face (the face toward the camera), AlwaysOnTop, so the
	  panel shows real perspective and is never hidden by walls. Its canvas is `DesignSize` px: lay your UI out in
	  those px and it looks the same on every screen.
	- The Part is sized from the camera's LIVE field of view every frame, so FOV kicks / zooms never make the panel
	  breathe. The panel is fitted so even its fully tilted corners stay on screen (and clear of notches).
	- The tilt follows the mouse (eased), the last touch for 1 s (phones), or the selected button (gamepad). With no
	  pointer it sways a tiny bit (Idle). Tilt = Vector2.zero turns all motion off (reduced motion).
	- Layers: panel:AddLayer(depth) gives you another canvas on its own plane in front of (or behind) the pane. Put
	  the title tab, the close button or big buttons on a front layer and they slide against the pane as it tilts:
	  that parallax is what sells the 3D. A soft shadow layer sits behind the pane by default.
	- Roblox always draws ScreenGuis ON TOP of SurfaceGuis, so while the panel is open every other ScreenGui in
	  PlayerGui is hidden (HideOtherGuis) except the ones you keep (KeepGuis), and comes back after.
	- The world is blurred with our OWN BlurEffect ("ImmersiveUIBlur" in Lighting). Tested in Play: the panel stays
	  sharp because SurfaceGuis are drawn after the blur. We never touch a BlurEffect your game made.
	- Flat = true draws the same Content in a normal ScreenGui instead (no 3D, same blur + open/close animation).

	OPTIONS (all optional)                              default
		Name            string                          "Panel"
		DesignSize      Vector2   canvas px             1100 x 720  (include a title tab that sticks out: see PaneInsetTop)
		ScreenHeight    number    of the free height    0.72        (untilted panel height)
		MaxScreenWidth  number    of the free width     0.92        (clamp on narrow / portrait screens)
		FitFOV          number    degrees               90          (the tilt fit keeps corners on screen up to this
		                                                              vertical FOV; 70 = Roblox default camera, bigger
		                                                              panels, but a FOV kick past it can clip a corner)
		Distance        number    studs                 4           (the look is the same at any distance; layer depths
		                                                              are in studs, so their parallax = depth / Distance)
		Tilt            Vector2   max yaw, pitch deg    (6, 4.5)    (Vector2.zero = reduced motion: no tilt, swing, sway, pop)
		TiltSmoothing   number    1/s                   9           (higher = snappier)
		Idle            boolean                         true        (tiny sway when there is no mouse)
		Blur            number    BlurEffect.Size       18          (0 = no blur)
		Tint            Color3?                         nil         (a ColorCorrection tint while open, nil = off)
		HideOtherGuis   boolean                         true        (hide every other enabled ScreenGui in PlayerGui
		                                                              while open; see HIDING below)
		KeepGuis        { LayerCollector | string }     {}          (never hidden: instances or names)
		HideGuis        { LayerCollector } or a function returning one   {}   also hidden while open (any kind; the same
		                                                              KeepGuis / ImmersiveKeep / Roblox-own rules apply)
		HideTouchControls boolean                       true        (Roblox thumbstick + jump hide while open)
		Shadow          boolean                         true        (soft shadow on a layer behind the pane)
		Glint           boolean                         true        (a sheen on the pane that slides with the tilt;
		                                                              panel:AddGlint(frame) for a sheet you draw)
		PaneColor / PaneTransparency / PaneGradient (ColorSequence) / PaneBorderColor / PaneCorner (px)
		                                                            the module pane's look (defaults: ImmersiveUI.Glass)
		DisplayOrder    number                          50          (Flat mode ScreenGui)
		Flat            boolean                         false
		RenderPriority  number                          Enum.RenderPriority.Camera.Value + 1   (run after your LAST
		                                                              camera writer; e.g. Camera + 51)
		ManageMouse     boolean                         true        (frees the mouse while open, restores it after)
		ManageEffects   boolean                         true        (false = we never create blur / tint)
		BlockInput      boolean                         true        (clicks / taps that miss the panel never reach
		                                                              your game while it is open)
		Pane            boolean                         true        (draw the glass pane behind Content; false if your
		                                                              Content draws its own background)
		PaneInsetTop    number    canvas px             0           (empty canvas above the pane, e.g. for a title tab
		                                                              that sits half outside the pane)
		CloseOnClickOutside boolean                     true
		CloseOnRespawn  boolean                         true
		TopInset        number?   screen px             nil = Roblox top bar height   (space kept free at the top)
		CanvasScale     number or "auto"                "auto"      (renders the canvas at up to 2x for sharp text on big
		                                                              screens; your layout stays in DesignSize px)
		CanQuery        boolean                         true        (the canvas Parts' CanQuery; SurfaceGui clicks need it)
		FadeContent     boolean                         true        (fade with a CanvasGroup during open / close / swap)

	PANEL API
		panel.Content                 Frame (DesignSize). Parent your UI here.
		panel.Gui                     the main SurfaceGui (3D) or the ScreenGui (Flat)
		panel.IsOpen                  true from Open() until Close() starts
		panel.ModalActive             true from Open() until the close has fully finished
		panel:Open()  panel:Close(instant?)  panel:Toggle()
		panel:AddLayer(depth, name?)  -> Frame. Another canvas (same DesignSize coords as Content) on a plane `depth`
		                              studs in FRONT of the pane (negative = behind). It tilts with the panel, so it
		                              slides against the pane. At zero tilt it lines up with Content exactly.
		                              Buttons on layers work. Good depths at Distance 4: 0.25 - 0.6.
		panel:SetContent(frame)       swap content with the ref's beat (old content goes, the empty pane holds one
		                              frame, the new content fades in). Returns the old frame, left in Content with
		                              Visible = false. The first call hides every other child.
		panel.Opened / panel.Closed   signals (:Connect / :Once / :Wait). Opened fires when Open() starts, Closed when
		                              Close() starts (or the panel is replaced / destroyed while open).
		panel:OnModalChanged(fn)      fn(true) when the panel opens, fn(false) when the close has FULLY finished and
		                              the hidden GUIs are back. Gate your game input on this.
		panel:AddGlint(guiObject)     the tilt-following sheen on any frame (returns the glint Frame)
		panel:Shine(guiObject)        the diagonal white sweep (waits for the open animation if it is still playing)
		panel:ScreenToCanvas(pos, allowOutside?, target?)  pos = InputObject.Position. Returns (point, canvasFrame):
		                              the point in the same space as `AbsolutePosition` of things on that canvas, or
		                              nil off the panel. Front layers are tested first (only where they have
		                              something visible). target = a GuiObject: map onto ITS canvas (use it for
		                              sliders). allowOutside = true: extrapolate on the plane (drags).
		panel:GetScreenScale()        screen px per DesignSize px right now (untilted)
		panel:Configure(options)      change DesignSize / ScreenHeight / Tilt / Blur / ... live (not Flat)
		panel:Destroy()
		ImmersiveUI.Glass(parent, props)   a ref-style glass Frame (see below)
		ImmersiveUI.Shine(guiObject)  the sweep, no panel needed
		ImmersiveUI.Active()          the open panel, if any (one at a time; opening another closes the first)
		ImmersiveUI.CanvasFolder()    workspace.ImmersiveUILocal: add it to your raycast Exclude lists

	HIDING (HideOtherGuis)
	- Hidden: every enabled ScreenGui directly in PlayerGui, plus ones added while open, except the panel's own,
	  KeepGuis, anything with attribute ImmersiveKeep = true, and Roblox's own: TouchGui (use HideTouchControls),
	  Freecam, Chat, BubbleChat.
	- Restored: exactly the ones we hid. If a gui's owner script sets Enabled = true while it is hidden, we do NOT
	  fight it (it stays on and we leave it alone at close). If your script turns a gui OFF while a panel is open,
	  Roblox can't tell us (it is already off), so check `ImmersiveUI.Active()` or the LocalPlayer attribute
	  ImmersiveUIOpen and re-apply your own state when it goes false, or put that gui in KeepGuis and hide it yourself.

	ALSO
	- LocalPlayer attribute "ImmersiveUIOpen" (and the same attribute on each panel SurfaceGui) = true while a panel
	  is open (same timing as OnModalChanged).
	- Studio only: LocalPlayer attribute ImmersiveDebugPointer = Vector2 (-1..1, X right, Y DOWN, so (1, -1) is the
	  top-right corner) pretends the pointer is there, for screenshots. ImmersiveDebugCanQuery = bool overrides
	  CanQuery live.
	- Gamepad: selection works inside the SurfaceGui. Set GuiService.SelectedObject to one of your buttons after
	  Open(); the tilt follows the selected button.
	- The Studio MCP screen_capture does not draw SurfaceGuis in PlayerGui. Screenshot the Studio window instead.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer

--------------------------------------------------------------------------------------------------------------------
-- timings, decoded from the reference at 10 fps (see SPEC "What the ref does")
--------------------------------------------------------------------------------------------------------------------
local OPEN_PANE = 0.24 -- pane: scale 1.06 -> 1 (small Back Out overshoot), transparent -> its glass (Quad Out)
local OPEN_SCALE = 1.06
local CONTENT_DELAY = 0.08 -- content starts after the empty pane is up (0 when Pane = false)
local CONTENT_FADE = 0.16
local CONTENT_RISE = 10 -- canvas px the content rises while it fades in
local BLUR_IN = 0.24
local CLOSE_FADE = 0.18 -- content + pane fade together (Quad In) while the pane shrinks and tips away
local CLOSE_SCALE = 0.94
local BLUR_OUT = 0.18
local SWING_PITCH = 8 -- the open "swing in": the pane starts tipped (deg, CFrame.Angles terms: + pitch = top nearer)
local SWING_YAW = -4 -- (- yaw = right edge nearer) and settles into the pointer tilt
local CLOSE_TIP = -4 -- deg of pitch the pane tips away (top recedes) as it fades out
local BACK_S = 0.9 -- Back Out overshoot (TweenService's Back is 1.70158 = ~10%, too bouncy); 0.9 = ~3% of the travel
local HUD_BACK = 0.1 -- hidden GUIs come back this long after the pane is gone
local SWAP_GAP = 0.06 -- SetContent: the empty pane holds this long
local SWAP_FADE = 0.1
local TOUCH_HOLD = 1 -- s the tilt follows the last touch
local FIT_MARGIN = 0.98 -- tilted corners stay inside 98% of the free screen
local FIT_TANV = math.tan(math.rad(90) / 2) -- the fit is solved at a wide FOV (90), so normal FOV kicks never resize it
local THICK = 0.02 -- canvas part thickness; its Back face sits exactly at the plane
local SHADOW_DEPTH = 0.35 -- studs behind the pane at Distance 4 (scaled with Distance): it visibly shifts with tilt
local SHADOW_DROP = 30 -- canvas px down
local SHADOW_RINGS = { 0.86, 0.88, 0.9, 0.92, 0.945, 0.97 } -- each ring 18 px bigger: a soft falloff, no slab
local GLINT_OFFSET = 0.25 -- glint gradient offset per unit of tilt
local GLINT_ROT = 8 -- deg of glint rotation per unit of tilt
local SHINE_TIME = 0.5
local INTERNAL = { TouchGui = true, Freecam = true, Chat = true, BubbleChat = true, ImmersiveUIMeasure = true, ImmersiveUIMeasureSafe = true }

local QUAD = Enum.EasingStyle.Quad
local OUT = Enum.EasingDirection.Out
local IN = Enum.EasingDirection.In
local INOUT = Enum.EasingDirection.InOut

local function ease(a: number, dir: Enum.EasingDirection): number
	if a <= 0 then
		return 0
	elseif a >= 1 then
		return 1
	end
	return TweenService:GetValue(a, QUAD, dir)
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Back Out with a small overshoot (BACK_S)
local function backOut(t: number): number
	if t <= 0 then
		return 0
	elseif t >= 1 then
		return 1
	end
	local u = t - 1
	return 1 + (BACK_S + 1) * u * u * u + BACK_S * u * u
end

--------------------------------------------------------------------------------------------------------------------
-- types
--------------------------------------------------------------------------------------------------------------------
export type Options = {
	Name: string?,
	DesignSize: Vector2?,
	ScreenHeight: number?,
	MaxScreenWidth: number?,
	FitFOV: number?,
	Distance: number?,
	Tilt: Vector2?,
	TiltSmoothing: number?,
	Idle: boolean?,
	Blur: number?,
	Tint: Color3?,
	HideOtherGuis: boolean?,
	KeepGuis: { any }?,
	HideGuis: any?, -- { LayerCollector } | () -> { LayerCollector }
	HideTouchControls: boolean?,
	Shadow: boolean?,
	Glint: boolean?,
	PaneColor: Color3?,
	PaneTransparency: number?,
	PaneGradient: ColorSequence?,
	PaneBorderColor: Color3?,
	PaneCorner: number?,
	DisplayOrder: number?,
	Flat: boolean?,
	RenderPriority: number?,
	ManageMouse: boolean?,
	ManageEffects: boolean?,
	BlockInput: boolean?,
	Pane: boolean?,
	PaneInsetTop: number?,
	CloseOnClickOutside: boolean?,
	CloseOnRespawn: boolean?,
	TopInset: number?,
	CanvasScale: any?, -- number | "auto"
	CanQuery: boolean?,
	FadeContent: boolean?,
}

export type Signal = {
	Connect: (self: Signal, fn: (...any) -> ()) -> RBXScriptConnection,
	Once: (self: Signal, fn: (...any) -> ()) -> RBXScriptConnection,
	Wait: (self: Signal) -> ...any,
	_event: BindableEvent,
}

local function newSignal(): Signal
	local ev = Instance.new("BindableEvent")
	local s = {} :: any
	s._event = ev
	function s:Connect(fn: (...any) -> ()): RBXScriptConnection
		return ev.Event:Connect(fn)
	end
	function s:Once(fn: (...any) -> ()): RBXScriptConnection
		return ev.Event:Once(fn)
	end
	function s:Wait(): ...any
		return ev.Event:Wait()
	end
	return s :: Signal
end

local DEFAULTS = {
	Name = "Panel",
	DesignSize = Vector2.new(1100, 720),
	ScreenHeight = 0.72,
	MaxScreenWidth = 0.92,
	FitFOV = 90,
	Distance = 4,
	Tilt = Vector2.new(6, 4.5),
	TiltSmoothing = 9,
	Idle = true,
	Blur = 18,
	HideOtherGuis = true,
	KeepGuis = {},
	HideTouchControls = true,
	Shadow = true,
	Glint = true,
	DisplayOrder = 50,
	Flat = false,
	RenderPriority = Enum.RenderPriority.Camera.Value + 1,
	ManageMouse = true,
	ManageEffects = true,
	BlockInput = true,
	Pane = true,
	PaneInsetTop = 0,
	CloseOnClickOutside = true,
	CloseOnRespawn = true,
	CanvasScale = "auto",
	CanQuery = true,
	FadeContent = true,
}

--------------------------------------------------------------------------------------------------------------------
-- Glass: a ref-style glass Frame (navy tint, see-through, thin light border, small corners)
-- props: Size, Position, AnchorPoint, Name, ZIndex, LayoutOrder, Color, Transparency, Dark (the darker row / tile
-- glass), Border, BorderTransparency, BorderThickness, Corner (px), Gradient (bool); any other key is set on the Frame.
--------------------------------------------------------------------------------------------------------------------
local GLASS_KEYS = {
	Color = true, Transparency = true, Dark = true, Border = true, BorderTransparency = true,
	BorderThickness = true, Corner = true, Gradient = true, Name = true, Size = true,
}

local function glass(parent: Instance?, props: { [string]: any }?): Frame
	local p: { [string]: any } = props or {}
	local dark = p.Dark == true
	local f = Instance.new("Frame")
	f.Name = p.Name or "Glass"
	f.BorderSizePixel = 0
	f.BackgroundColor3 = p.Color or (if dark then Color3.fromRGB(18, 30, 78) else Color3.fromRGB(40, 66, 150))
	f.BackgroundTransparency = p.Transparency or (if dark then 0.32 else 0.42)
	f.Size = p.Size or UDim2.fromScale(1, 1)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, p.Corner or 6)
	corner.Parent = f
	local stroke = Instance.new("UIStroke")
	stroke.Name = "GlassBorder"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = p.Border or (if dark then Color3.fromRGB(120, 150, 230) else Color3.fromRGB(205, 222, 255))
	stroke.Transparency = p.BorderTransparency or (if dark then 0.45 else 0.3)
	stroke.Thickness = p.BorderThickness or 2
	stroke.Parent = f
	if p.Gradient ~= false then
		local g = Instance.new("UIGradient") -- a faint light falloff top -> bottom, like light through glass
		g.Name = "GlassLight"
		g.Rotation = 90
		g.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(205, 215, 240))
		g.Parent = f
	end
	for k, v in p do
		if not GLASS_KEYS[k] then
			(f :: any)[k] = v
		end
	end
	f.Parent = parent
	return f
end

--------------------------------------------------------------------------------------------------------------------
-- Shine: a diagonal white band that sweeps across a GuiObject once
--------------------------------------------------------------------------------------------------------------------
local function shine(target: GuiObject, delay: number?)
	local old = target:FindFirstChild("ImmersiveShine")
	if old then
		old:Destroy()
	end
	local f = Instance.new("Frame")
	f.Name = "ImmersiveShine"
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BackgroundTransparency = 0
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = 50
	local c = target:FindFirstChildOfClass("UICorner")
	if c then
		c:Clone().Parent = f
	end
	local g = Instance.new("UIGradient")
	g.Rotation = 22
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.4, 1),
		NumberSequenceKeypoint.new(0.47, 0.55),
		NumberSequenceKeypoint.new(0.5, 0.25),
		NumberSequenceKeypoint.new(0.53, 0.55),
		NumberSequenceKeypoint.new(0.6, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Offset = Vector2.new(-1, 0)
	g.Parent = f
	f.Parent = target
	local tw = TweenService:Create(g, TweenInfo.new(SHINE_TIME, QUAD, INOUT, 0, false, delay or 0), { Offset = Vector2.new(1, 0) })
	tw.Completed:Once(function()
		f:Destroy()
	end)
	tw:Play()
end

--------------------------------------------------------------------------------------------------------------------
-- shared state: one open panel per client, one owned blur + tint, the screen measure
--------------------------------------------------------------------------------------------------------------------
local active: any = nil
local fx = { Blur = nil :: BlurEffect?, Tint = nil :: ColorCorrectionEffect?, Owner = nil :: any }

local function fxBlur(): BlurEffect
	local b = fx.Blur
	if not b or b.Parent ~= Lighting then
		local n = Instance.new("BlurEffect")
		n.Name = "ImmersiveUIBlur"
		n.Size = 0
		n.Enabled = false
		n.Parent = Lighting
		fx.Blur = n
		return n
	end
	return b
end

local function fxTint(): ColorCorrectionEffect
	local t = fx.Tint
	if not t or t.Parent ~= Lighting then
		local n = Instance.new("ColorCorrectionEffect")
		n.Name = "ImmersiveUITint"
		n.Enabled = false
		n.Parent = Lighting
		fx.Tint = n
		return n
	end
	return t
end

local function fxRelease(owner: any)
	if fx.Owner ~= owner then
		return
	end
	fx.Owner = nil
	if fx.Blur and fx.Blur.Parent then
		fx.Blur.Enabled = false
		fx.Blur.Size = 0
	end
	if fx.Tint and fx.Tint.Parent then
		fx.Tint.Enabled = false
	end
end

-- Camera.ViewportSize can be the device-SAFE size on notched phones while the camera's FOV covers the full render
-- area. Two empty ScreenGuis measure both: ScreenInsets None = the full screen, DeviceSafeInsets =
-- the safe area. We assume the side cutouts are symmetric and any extra height is at the bottom (home bar).
local measureFull: ScreenGui? = nil
local measureSafe: ScreenGui? = nil
local function screenRects(): (Vector2, Vector2)
	local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if pg and (not measureFull or measureFull.Parent ~= pg) then
		local a = Instance.new("ScreenGui")
		a.Name = "ImmersiveUIMeasure"
		a.ResetOnSpawn = false
		a.ScreenInsets = Enum.ScreenInsets.None
		a.Parent = pg
		measureFull = a
		local b = Instance.new("ScreenGui")
		b.Name = "ImmersiveUIMeasureSafe"
		b.ResetOnSpawn = false
		b.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
		b.Parent = pg
		measureSafe = b
	end
	local cam = workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.zero
	local full = if measureFull then measureFull.AbsoluteSize else Vector2.zero
	if full.X < 2 or full.Y < 2 then
		full = vp
	end
	local safe = if measureSafe then measureSafe.AbsoluteSize else Vector2.zero
	if safe.X < 2 or safe.Y < 2 or safe.X > full.X or safe.Y > full.Y then
		safe = full
	end
	return full, safe
end

local function localFolder(): Folder
	local f = workspace:FindFirstChild("ImmersiveUILocal")
	if f and f:IsA("Folder") then
		return f
	end
	local n = Instance.new("Folder")
	n.Name = "ImmersiveUILocal" -- client-made: never replicated, survives respawns and camera swaps
	n.Parent = workspace
	return n
end

local function studioAttr(name: string): any
	if not RunService:IsStudio() then
		return nil
	end
	return LocalPlayer:GetAttribute(name)
end

local function guiToViewport(p: Vector2): Vector2
	-- InputObject.Position is below the top bar; viewport / GetMouseLocation space includes it (verified in Play)
	local tl = GuiService:GetGuiInset()
	return p + tl
end

--------------------------------------------------------------------------------------------------------------------
-- Panel
--------------------------------------------------------------------------------------------------------------------
local Panel = {}
Panel.__index = Panel

local ImmersiveUI = {}
ImmersiveUI.Glass = glass
ImmersiveUI.Shine = function(target: GuiObject)
	shine(target, 0)
end
ImmersiveUI.Active = function(): any
	return active
end
ImmersiveUI.CanvasFolder = function(): Folder
	return localFolder()
end

local nextId = 0

function ImmersiveUI.new(options: Options?): any
	local opt: { [string]: any } = table.clone(DEFAULTS :: any)
	opt.KeepGuis = {}
	for k, v in (options or {}) :: any do
		opt[k] = v
	end
	nextId += 1
	local self = setmetatable({}, Panel) :: any
	self._opt = opt
	self._id = nextId
	self._bindName = "ImmersiveUI_" .. tostring(opt.Name) .. "_" .. nextId
	self._state = "closed" -- closed | opening | open | closing
	self._gen = 0
	self._t0 = 0
	self._from = nil
	self._r = { scale = 1, pane = 0, content = 0, rise = 0, fx = 0, swing = 0, tip = 0 } -- what is on screen now
	self._modal = false
	self._hidden = {}
	self._conns = {} -- live only while shown
	self._modalConns = {} -- live only while modal
	self._perm = {} -- the panel's lifetime
	self._tilt = Vector2.zero -- smoothed pointer, -1..1
	self._target = Vector2.zero
	self._mode = "none" -- mouse | touch | gamepad | none
	self._touchPos = Vector2.zero
	self._touchT = -math.huge
	self._mouseHold = false
	self._touchHolds = {}
	self._swap = nil
	self._current = nil
	self._hPx = 0
	self._fitKey = ""
	self._fitK = 1
	self._cs = 1
	self._area = nil -- free screen area this frame
	self._canvasHidden = true
	self.IsOpen = false
	self.ModalActive = false
	self.Opened = newSignal()
	self.Closed = newSignal()
	self.ModalChanged = newSignal()
	self._canvases = {}

	local flat = opt.Flat == true
	self._flat = flat
	if flat then
		local sg = Instance.new("ScreenGui")
		sg.Name = "ImmersiveUI_" .. tostring(opt.Name)
		sg.ResetOnSpawn = false
		sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		sg.DisplayOrder = opt.DisplayOrder
		sg.ScreenInsets = Enum.ScreenInsets.None -- full screen: we place the panel inside the safe area ourselves
		sg.Enabled = false
		self._flatGui = sg
	end

	local main = self:_newCanvas(0, "Main", "content")
	self._main = main
	self.Gui = main.Gui
	self.Content = main.Frame
	main.Frame.Name = "Content"
	self._glints = {}
	if opt.Pane then
		local pane = glass(main.Root, { Name = "Pane", ZIndex = 1 })
		self._pane = pane
		local st = pane:FindFirstChild("GlassBorder") :: UIStroke
		self._paneStroke = st
		self._paneStrokeT = st.Transparency
		self:_stylePane()
		if opt.Glint then
			self:AddGlint(pane)
		end
	end
	if opt.Shadow then
		self:_makeShadow()
	end
	self:_applyDesign()
	local pg = LocalPlayer:WaitForChild("PlayerGui")
	if flat then
		self._flatGui.Parent = pg
	end
	for _, c in self._canvases do
		if not flat then
			c.Gui.Parent = pg
		end
	end

	table.insert(self._perm, LocalPlayer.CharacterRemoving:Connect(function()
		if self._opt.CloseOnRespawn and self.IsOpen then
			self:Close()
		end
	end))
	return self
end

-- one canvas = (3D) its own SurfaceGui + Part, or (Flat) a root Frame in the flat ScreenGui. Root -> Live | Fader ->
-- Frame. depth: studs toward the camera from the pane. alpha: "content" or "pane" (which animation curve it follows).
function Panel._newCanvas(self: any, depth: number, name: string, alpha: string): any
	local c: any = { Depth = depth, Name = name, Alpha = alpha, Faded = false, W = 0, H = 0, Face = CFrame.identity }
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	if self._flat then
		root.Name = "Layer_" .. name
		root.AnchorPoint = Vector2.new(0.5, 0.5)
		root.Parent = self._flatGui
		c.Gui = self._flatGui
	else
		local sg = Instance.new("SurfaceGui")
		sg.Name = "ImmersiveUI_" .. tostring(self._opt.Name) .. (if name == "Main" then "" else "_" .. name)
		sg.ResetOnSpawn = false
		sg.Face = Enum.NormalId.Back -- the face toward the camera
		sg.AlwaysOnTop = true
		sg.LightInfluence = 0
		sg.Brightness = 1
		sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		sg.MaxDistance = 0 -- unlimited
		sg.ClipsDescendants = false
		sg.Active = true
		sg.Enabled = false
		root.Parent = sg
		c.Gui = sg
	end
	c.Root = root
	local scale = Instance.new("UIScale")
	scale.Name = "CanvasScale"
	scale.Parent = root
	c.Scale = scale
	local live = Instance.new("Frame")
	live.Name = "Live"
	live.BackgroundTransparency = 1
	live.Size = UDim2.fromScale(1, 1)
	live.ZIndex = 2
	live.Parent = root
	c.Live = live
	local fader = Instance.new("CanvasGroup")
	fader.Name = "Fader"
	fader.BackgroundTransparency = 1
	fader.Size = UDim2.fromScale(1, 1)
	fader.ZIndex = 2
	fader.Visible = false
	fader.Parent = root
	c.Fader = fader
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = live
	c.Frame = frame
	table.insert(self._canvases, c)
	-- back to front: the draw order of the AlwaysOnTop surfaces (ZOffset) and of the flat roots (ZIndex)
	table.sort(self._canvases, function(a: any, b: any): boolean
		return a.Depth < b.Depth
	end)
	for i, k in self._canvases do
		if self._flat then
			k.Root.ZIndex = i
		else
			(k.Gui :: SurfaceGui).ZOffset = i - 1
		end
	end
	return c
end

-- public pane style: PaneColor, PaneTransparency, PaneGradient, PaneBorderColor, PaneCorner
function Panel._stylePane(self: any)
	local pane = self._pane
	if not pane then
		return
	end
	local opt = self._opt
	if opt.PaneColor then
		pane.BackgroundColor3 = opt.PaneColor
	end
	self._paneT = if type(opt.PaneTransparency) == "number" then opt.PaneTransparency else 0.42
	if opt.PaneBorderColor then
		self._paneStroke.Color = opt.PaneBorderColor
	end
	local corner = pane:FindFirstChildOfClass("UICorner")
	if corner and type(opt.PaneCorner) == "number" then
		corner.CornerRadius = UDim.new(0, opt.PaneCorner)
	end
	local g = pane:FindFirstChild("GlassLight") :: UIGradient?
	if g and opt.PaneGradient then
		g.Color = opt.PaneGradient
	end
	for _, gl in self._glints do
		local gc = gl.Frame:FindFirstChildOfClass("UICorner")
		local tc = gl.Target:FindFirstChildOfClass("UICorner")
		if gc and tc then
			gc.CornerRadius = tc.CornerRadius
		end
	end
	-- (a new PaneTransparency while open lands next frame: the per-frame alpha write compares against it)
end

-- the glint : a soft white sheen over `target` whose gradient Offset / Rotation follow the
-- current tilt, so light seems to slide across the glass as it turns. The pane gets one when Glint = true; call
-- this yourself for a sheet you draw (Pane = false). Fades with the pane. Not Active: clicks pass through.
function Panel.AddGlint(self: any, target: GuiObject): Frame
	local f = Instance.new("Frame")
	f.Name = "ImmersiveGlint"
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = 40
	f.Active = false
	local c = target:FindFirstChildOfClass("UICorner")
	if c then
		c:Clone().Parent = f
	end
	local g = Instance.new("UIGradient")
	g.Rotation = 25
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.28, 0.97),
		NumberSequenceKeypoint.new(0.42, 0.86),
		NumberSequenceKeypoint.new(0.5, 0.82),
		NumberSequenceKeypoint.new(0.58, 0.86),
		NumberSequenceKeypoint.new(0.72, 0.97),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = f
	f.Parent = target
	table.insert(self._glints, { Frame = f, Grad = g, Target = target })
	return f
end

function Panel._makeShadow(self: any)
	local c = self:_newCanvas(-SHADOW_DEPTH * (self._opt.Distance / 4), "Shadow", "pane")
	c.IsShadow = true
	local holder = Instance.new("Frame")
	holder.Name = "ShadowRect"
	holder.BackgroundTransparency = 1
	holder.Parent = c.Frame
	c.ShadowRect = holder
	-- a soft edge from stacked rounded rings, each 18 px bigger and fainter (no image asset needed)
	for i, t in SHADOW_RINGS do
		local grow = (i - 1) * 18
		local f = Instance.new("Frame")
		f.Name = "Soft" .. i
		f.BackgroundColor3 = Color3.fromRGB(4, 8, 24)
		f.BackgroundTransparency = t
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.5)
		f.Size = UDim2.new(1, grow, 1, grow)
		f.ZIndex = 10 - i
		local k = Instance.new("UICorner")
		k.CornerRadius = UDim.new(0, 14 + grow / 2)
		k.Parent = f
		f.Parent = holder
	end
	self._shadow = c
end

function Panel.AddLayer(self: any, depth: number, name: string?): Frame
	local c = self:_newCanvas(depth, name or ("Layer" .. #self._canvases), "content")
	self:_applyDesign()
	if not self._flat then
		c.Gui.Parent = LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if not self._canvasHidden then
			c.Gui.Enabled = true
		end
	end
	if self._state ~= "closed" then
		self:_setFaded(c, true)
	end
	return c.Frame
end

-- DesignSize / pane inset / canvas scale -> instances
function Panel._applyDesign(self: any)
	local opt = self._opt
	local ds: Vector2 = opt.DesignSize
	local inset = opt.PaneInsetTop or 0
	for _, c in self._canvases do
		c.Root.Size = UDim2.fromOffset(ds.X, ds.Y)
		if not self._flat then
			c.Root.Position = UDim2.fromOffset(0, 0)
			local cs = self._cs
			;(c.Gui :: SurfaceGui).CanvasSize = Vector2.new(math.ceil(ds.X * cs), math.ceil(ds.Y * cs))
			c.Scale.Scale = cs
		end
	end
	if self._pane then
		self._pane.Position = UDim2.fromOffset(0, inset)
		self._pane.Size = UDim2.new(1, 0, 1, -inset)
	end
	local sh = self._shadow
	if sh then
		sh.ShadowRect.Position = UDim2.fromOffset(0, inset + SHADOW_DROP)
		sh.ShadowRect.Size = UDim2.new(1, 0, 1, -inset)
	end
	self._fitKey = ""
end

function Panel.Configure(self: any, options: Options)
	for k, v in options :: any do
		self._opt[k] = v
	end
	if self._shadow then
		self._shadow.Depth = -SHADOW_DEPTH * (self._opt.Distance / 4)
	end
	if not self._opt.ManageEffects then
		fxRelease(self) -- turning management off while open lets go of our blur now
	end
	self:_stylePane()
	self:_applyDesign()
end

--------------------------------------------------------------------------------------------------------------------
-- open / close. Every transition commits its state first, then fires signals, and stops if a handler changed the
-- panel in between (generation token).
--------------------------------------------------------------------------------------------------------------------
function Panel.Toggle(self: any)
	if self.IsOpen then
		self:Close()
	else
		self:Open()
	end
end

function Panel._keepSet(self: any): ({ [Instance]: boolean }, { [string]: boolean })
	local inst, names = {}, {}
	for _, k in self._opt.KeepGuis or {} do
		if typeof(k) == "Instance" then
			inst[k] = true
		elseif type(k) == "string" then
			names[k] = true
		end
	end
	if self._flatGui then
		inst[self._flatGui] = true
	end
	for _, c in self._canvases do
		inst[c.Gui] = true
	end
	return inst, names
end

-- hide one gui and watch its owner: an owner re-enabling it while hidden wins (we never fight it)
function Panel._hideGui(self: any, g: Instance)
	for _, rec in self._hidden do
		if rec.Gui == g then
			return
		end
	end
	local gui = g :: any
	if not gui.Enabled then
		return
	end
	gui.Enabled = false
	local rec = { Gui = gui, Touched = false, Conn = nil :: RBXScriptConnection? }
	rec.Conn = gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if gui.Enabled then
			rec.Touched = true -- the owner wants it shown: leave it to them
		end
	end)
	table.insert(self._hidden, rec)
end

function Panel._otherCandidate(self: any, g: Instance, keepI: { [Instance]: boolean }, keepN: { [string]: boolean }): boolean
	return g:IsA("ScreenGui") and keepI[g] == nil and keepN[g.Name] == nil and INTERNAL[g.Name] == nil and g:GetAttribute("ImmersiveKeep") ~= true
end

function Panel._modalOn(self: any)
	self._modal = true
	self.ModalActive = true
	local opt = self._opt
	local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local keepI, keepN = self:_keepSet()
	self._hidden = {}
	-- the ref hides its side buttons on the first frame; ScreenGuis would draw over the 3D panel anyway
	local list: any = opt.HideGuis
	if type(list) == "function" then
		list = (list :: any)()
	end
	for _, g in (list or {}) :: any do
		-- explicit list, same keep rules as HideOtherGuis (KeepGuis instances / names, ImmersiveKeep, Roblox's own)
		if typeof(g) == "Instance" and g:IsA("LayerCollector") and keepI[g] == nil and keepN[g.Name] == nil
			and INTERNAL[g.Name] == nil and g:GetAttribute("ImmersiveKeep") ~= true then
			self:_hideGui(g)
		end
	end
	if opt.HideOtherGuis and pg then
		for _, g in pg:GetChildren() do
			if self:_otherCandidate(g, keepI, keepN) then
				self:_hideGui(g)
			end
		end
		table.insert(self._modalConns, pg.ChildAdded:Connect(function(g: Instance)
			task.defer(function() -- after its builder set it up
				if self._modal and g.Parent == pg then
					local ki, kn = self:_keepSet()
					if self:_otherCandidate(g, ki, kn) then
						self:_hideGui(g)
					end
				end
			end)
		end))
	end
	if opt.HideTouchControls then
		self._savedTouch = GuiService.TouchControlsEnabled
		GuiService.TouchControlsEnabled = false
	end
	if opt.ManageMouse then
		self._savedMouse = { UserInputService.MouseBehavior, UserInputService.MouseIconEnabled }
	end
	if opt.BlockInput then
		-- outside presses (the old scrim): CAS runs after GUI, so buttons on the panel still get theirs; anything that
		-- misses the panel is sunk here (and closes it), so it never reaches the game
		ContextActionService:BindActionAtPriority(self._bindName .. "_Block", function(_n: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
			if state == Enum.UserInputState.Begin and self.IsOpen and self._opt.CloseOnClickOutside then
				if self:ScreenToCanvas(Vector2.new(input.Position.X, input.Position.Y)) == nil then
					self:Close()
				end
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value + 50, Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2, Enum.UserInputType.Touch)
		self._blocking = true
	end
	for _, c in self._canvases do
		c.Gui:SetAttribute("ImmersiveUIOpen", true)
	end
	LocalPlayer:SetAttribute("ImmersiveUIOpen", true)
end

function Panel._modalOff(self: any)
	self._modal = false
	self.ModalActive = false
	for _, c in self._modalConns do
		c:Disconnect()
	end
	table.clear(self._modalConns)
	if self._blocking then
		self._blocking = false
		ContextActionService:UnbindAction(self._bindName .. "_Block")
	end
	for _, rec in self._hidden do
		if rec.Conn then
			rec.Conn:Disconnect()
		end
		local g = rec.Gui
		if not rec.Touched and g.Parent and not g.Enabled then
			g.Enabled = true
		end
	end
	self._hidden = {}
	if self._savedTouch ~= nil then
		GuiService.TouchControlsEnabled = self._savedTouch
		self._savedTouch = nil
	end
	local m = self._savedMouse
	if m then
		UserInputService.MouseBehavior = m[1]
		UserInputService.MouseIconEnabled = m[2]
		self._savedMouse = nil
	end
	for _, c in self._canvases do
		c.Gui:SetAttribute("ImmersiveUIOpen", false)
	end
	if not (active and active ~= self and active.ModalActive) then
		LocalPlayer:SetAttribute("ImmersiveUIOpen", false)
	end
end

function Panel.OnModalChanged(self: any, fn: (boolean) -> ()): RBXScriptConnection
	return self.ModalChanged:Connect(fn)
end

function Panel._fresh(self: any): { [string]: number }
	local reduced = self:_reduced()
	return { scale = if reduced then 1 else OPEN_SCALE, pane = 0, content = 0, rise = if reduced then 0 else CONTENT_RISE, fx = 0, swing = if reduced then 0 else 1, tip = 0 }
end

function Panel.Open(self: any)
	if self._destroying or self._state == "opening" or self._state == "open" then
		return
	end
	if active and active ~= self then
		active:_finish() -- one panel at a time: the old one goes now (it fires its own Closed + ModalChanged)
		if self._destroying or self._state == "opening" or self._state == "open" then
			return
		end
	end
	active = self
	self._gen += 1
	local gen = self._gen
	if self._state == "closing" then
		self._from = table.clone(self._r) -- carry on from what is on screen
	else
		self._from = self:_fresh()
		self._tilt = Vector2.zero
		self._target = Vector2.zero
		self._mode = self:_initialMode()
	end
	self._t0 = os.clock()
	self._state = "opening"
	self.IsOpen = true
	local wasModal = self._modal
	if not wasModal then
		self:_modalOn()
	end
	self:_show()
	if not wasModal then
		self.ModalChanged._event:Fire(true)
		if self._gen ~= gen then
			return
		end
	end
	self.Opened._event:Fire()
end

function Panel.Close(self: any, instant: boolean?)
	if self._state == "closed" then
		return
	end
	if instant then
		self:_finish()
		return
	end
	if self._state == "closing" then
		return
	end
	self._gen += 1
	self._from = table.clone(self._r) -- from what is on screen, incl. a swap mid-fade
	if self._swap then
		self:_endSwap()
	end
	self._t0 = os.clock()
	self._state = "closing"
	self.IsOpen = false
	self._mouseHold = false
	table.clear(self._touchHolds)
	for _, c in self._canvases do
		self:_setFaded(c, true)
	end
	self.Closed._event:Fire()
end

-- start per-frame work (only while the panel is on screen)
function Panel._show(self: any)
	for _, c in self._canvases do
		self:_setFaded(c, true)
	end
	self:_showCanvas()
	if self._bound then
		return
	end
	self._bound = true
	RunService:BindToRenderStep(self._bindName, self._opt.RenderPriority, function(dt: number)
		self:_step(dt)
	end)
	local conns = self._conns
	table.insert(conns, UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		self:_inputBegan(input, processed)
	end))
	table.insert(conns, UserInputService.InputChanged:Connect(function(input: InputObject)
		self:_inputChanged(input)
	end))
	table.insert(conns, UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self._mouseHold = false
		elseif input.UserInputType == Enum.UserInputType.Touch then
			self._touchHolds[input] = nil
		end
	end))
	table.insert(conns, UserInputService.WindowFocusReleased:Connect(function()
		self._mouseHold = false
		table.clear(self._touchHolds)
	end))
	self:_step(0) -- placed this frame
end

function Panel._showCanvas(self: any)
	self._canvasHidden = false
	if self._flat then
		self._flatGui.Enabled = true
	else
		for _, c in self._canvases do
			c.Gui.Enabled = true
		end
	end
end

-- gone from the screen AND from the world as soon as the fade ends: no invisible plane left for
-- raycasts during the HUD-return beat
function Panel._hideCanvas(self: any)
	if self._canvasHidden then
		return
	end
	self._canvasHidden = true
	if self._flat then
		self._flatGui.Enabled = false
		return
	end
	for _, c in self._canvases do
		c.Gui.Enabled = false
		local part = c.Part
		if part then
			pcall(function()
				part.Parent = nil
			end)
		end
	end
end

-- the one terminal path: normal close end, instant close, another panel opening, Destroy. Commits everything, then
-- fires Closed (if it was open) and ModalChanged(false).
function Panel._finish(self: any)
	if self._state == "closed" and not self._modal then
		return
	end
	self._gen += 1
	local gen = self._gen
	local wasOpen = self.IsOpen
	local wasModal = self._modal
	if self._swap then
		self:_endSwap()
	end
	self._state = "closed"
	self.IsOpen = false
	self._r = { scale = 1, pane = 0, content = 0, rise = 0, fx = 0, swing = 0, tip = 0 }
	if self._bound then
		self._bound = false
		pcall(function()
			RunService:UnbindFromRenderStep(self._bindName)
		end)
	end
	for _, c in self._conns do
		c:Disconnect()
	end
	table.clear(self._conns)
	self:_hideCanvas()
	for _, c in self._canvases do
		self:_setFaded(c, false)
	end
	fxRelease(self)
	if active == self then
		active = nil
	end
	if wasModal then
		self:_modalOff()
	end
	if wasOpen then
		self.Closed._event:Fire()
		if self._gen ~= gen then
			return
		end
	end
	if wasModal then
		self.ModalChanged._event:Fire(false)
	end
end

function Panel.Destroy(self: any)
	if self._destroying then
		return
	end
	self._destroying = true -- set before any teardown callback runs
	self:_finish()
	for _, c in self._perm do
		c:Disconnect()
	end
	for _, c in self._canvases do
		if c.Part then
			pcall(function()
				c.Part:Destroy()
			end)
		end
		if not self._flat then
			c.Gui:Destroy()
		end
	end
	if self._flatGui then
		self._flatGui:Destroy()
	end
	for _, s in { self.Opened, self.Closed, self.ModalChanged } do
		s._event:Destroy()
	end
end

--------------------------------------------------------------------------------------------------------------------
-- content: fading uses a CanvasGroup only while something animates; the rest of the time a canvas sits in a plain
-- Frame (crisper, cheaper). Gamepad selection is kept across the move.
--------------------------------------------------------------------------------------------------------------------
function Panel._setFaded(self: any, c: any, on: boolean)
	if not self._opt.FadeContent then
		on = false
	end
	if c.Faded == on then
		return
	end
	c.Faded = on
	local sel = GuiService.SelectedObject
	local frame: Frame = c.Frame
	if on then
		c.Fader.Visible = true
		frame.Parent = c.Fader
	else
		frame.Parent = c.Live
		c.Fader.Visible = false
		c.Fader.GroupTransparency = 0
	end
	if sel and sel:IsDescendantOf(frame) and GuiService.SelectedObject ~= sel then
		GuiService.SelectedObject = sel
	end
end

function Panel.SetContent(self: any, frame: GuiObject): GuiObject?
	local old = self._current
	if old == frame then
		frame.Visible = true
		return old
	end
	if self._swap then
		self:_endSwap()
	end
	local hide = {}
	if old == nil then
		for _, c in self.Content:GetChildren() do
			if c:IsA("GuiObject") and c ~= frame then
				table.insert(hide, c)
			end
		end
	elseif old.Parent == self.Content then
		table.insert(hide, old)
	end
	for _, c in hide do
		c.Visible = false
	end
	self._current = frame
	frame.Parent = self.Content
	if self._state == "open" then
		frame.Visible = false
		self._swap = { T0 = os.clock(), Frame = frame, Shown = false }
		self:_setFaded(self._main, true)
		self._main.Fader.GroupTransparency = 1
	else
		frame.Visible = true
	end
	return old
end

function Panel._endSwap(self: any)
	local s = self._swap
	if s then
		s.Frame.Visible = true
		self._swap = nil
	end
end

function Panel.Shine(self: any, target: GuiObject)
	local delay = 0
	if self._state == "opening" then
		local done = self._t0 + math.max(OPEN_PANE, self:_contentDelay() + CONTENT_FADE)
		delay = math.max(0, done - os.clock())
	end
	shine(target, delay)
end

function Panel._contentDelay(self: any): number
	return if self._pane then CONTENT_DELAY else 0
end

function Panel._reduced(self: any): boolean
	local t: Vector2 = self._opt.Tilt
	return t.X == 0 and t.Y == 0
end

--------------------------------------------------------------------------------------------------------------------
-- input: pointer mode, touch-follow, holds (the tilt freezes while you drag), outside-press close
--------------------------------------------------------------------------------------------------------------------
function Panel._initialMode(_self: any): string
	local t = UserInputService:GetLastInputType()
	if t == Enum.UserInputType.Touch then
		return "touch"
	elseif string.sub(t.Name, 1, 7) == "Gamepad" then
		return "gamepad"
	elseif t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.MouseButton2 or t == Enum.UserInputType.MouseWheel then
		return "mouse"
	end
	return if UserInputService.MouseEnabled and not UserInputService.TouchEnabled then "mouse" else "none"
end

function Panel._inputBegan(self: any, input: InputObject, processed: boolean)
	local t = input.UserInputType
	if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
		if t == Enum.UserInputType.Touch then
			self._mode = "touch"
			self._touchPos = guiToViewport(Vector2.new(input.Position.X, input.Position.Y))
			self._touchT = os.clock()
		else
			self._mode = "mouse"
		end
		if not self.IsOpen then
			return
		end
		local inside = self:ScreenToCanvas(Vector2.new(input.Position.X, input.Position.Y)) ~= nil
		if inside then
			if t == Enum.UserInputType.Touch then
				self._touchHolds[input] = true
			else
				self._mouseHold = true
			end
		elseif not processed and not self._blocking and self._opt.CloseOnClickOutside then
			self:Close() -- BlockInput = false: close on unprocessed outside presses only
		end
	elseif string.sub(t.Name, 1, 7) == "Gamepad" then
		self._mode = "gamepad"
	end
end

function Panel._inputChanged(self: any, input: InputObject)
	local t = input.UserInputType
	if t == Enum.UserInputType.MouseMovement then
		self._mode = "mouse"
	elseif t == Enum.UserInputType.Touch then
		self._mode = "touch"
		self._touchPos = guiToViewport(Vector2.new(input.Position.X, input.Position.Y))
		self._touchT = os.clock()
	elseif string.sub(t.Name, 1, 7) == "Gamepad" and input.Position.Magnitude > 0.3 then
		self._mode = "gamepad"
	end
end

function Panel._holding(self: any): boolean
	return self._mouseHold or next(self._touchHolds) ~= nil
end

-- where the pointer is, -1..1 of the free area (X right, Y down), or nil = no pointer
function Panel._pointer(self: any, now: number): Vector2?
	local dbg = studioAttr("ImmersiveDebugPointer")
	if typeof(dbg) == "Vector2" then
		return Vector2.new(math.clamp(dbg.X, -1, 1), math.clamp(dbg.Y, -1, 1))
	end
	if self:_reduced() then
		return nil
	end
	local a = self._area
	if not a then
		return nil
	end
	local function norm(p: Vector2): Vector2
		return Vector2.new(math.clamp((p.X - a.CX) / math.max(a.HW, 1), -1, 1), math.clamp((p.Y - a.CY) / math.max(a.HH, 1), -1, 1))
	end
	local mode = self._mode
	if mode == "mouse" then
		return norm(UserInputService:GetMouseLocation())
	elseif mode == "touch" then
		if now - self._touchT < TOUCH_HOLD or self:_holding() then
			return norm(self._touchPos)
		end
	elseif mode == "gamepad" then
		local sel = GuiService.SelectedObject
		if sel then
			for _, c in self._canvases do
				if sel:IsDescendantOf(c.Root) then
					-- from the button's place on the CANVAS (not the screen), so the tilt can't feed back into itself
					local rs = c.Root.AbsoluteSize
					if rs.X > 0 and rs.Y > 0 then
						local p = sel.AbsolutePosition + sel.AbsoluteSize / 2 - c.Root.AbsolutePosition
						return Vector2.new(math.clamp(p.X / rs.X * 2 - 1, -1, 1), math.clamp(p.Y / rs.Y * 2 - 1, -1, 1)) * 0.6
					end
				end
			end
		end
	end
	return nil
end

--------------------------------------------------------------------------------------------------------------------
-- geometry
--------------------------------------------------------------------------------------------------------------------
function Panel._ensurePart(self: any, c: any): Part
	local folder = localFolder()
	local part = c.Part
	if not part then
		local p = Instance.new("Part")
		p.Name = "ImmersiveUI_" .. tostring(self._opt.Name) .. "_" .. c.Name
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CastShadow = false
		p.Transparency = 1
		p.Locked = true
		p.Massless = true
		p.Size = Vector3.new(1, 1, THICK)
		-- someone deleted the folder / part: forget it and make a new one next frame
		p.Destroying:Connect(function()
			if c.Part == p then
				c.Part = nil
			end
		end)
		part = p
		c.Part = p
	end
	local q = studioAttr("ImmersiveDebugCanQuery")
	local want = if type(q) == "boolean" then q else self._opt.CanQuery ~= false
	if part.CanQuery ~= want then
		part.CanQuery = want
	end
	if part.Parent ~= folder then
		local ok = pcall(function()
			part.Parent = folder
		end)
		if not ok then
			c.Part = nil
			return self:_ensurePart(c)
		end
	end
	local sg = c.Gui :: SurfaceGui
	if sg.Adornee ~= part then
		sg.Adornee = part
	end
	return part
end

-- the free screen area (full-screen px): x inside the safe width, y below TopInset and above the safe bottom
function Panel._freeArea(self: any): any
	local full, safe = screenRects()
	local opt = self._opt
	local top = if type(opt.TopInset) == "number" then opt.TopInset else (GuiService:GetGuiInset()).Y
	local x0 = (full.X - safe.X) / 2
	local y1 = math.max(top + 2, safe.Y) -- extra height of the full screen is taken at the bottom
	return {
		Full = full,
		X0 = x0, X1 = full.X - x0, Y0 = top, Y1 = y1,
		CX = full.X / 2, CY = (top + y1) / 2,
		HW = (full.X - 2 * x0) / 2, HH = (y1 - top) / 2,
	}
end

-- largest |corner| of the tilted, overshot panel (and every layer) on screen, against the free area. k <= 1 shrinks
-- it to fit. Solved at FOV 90 (wide case), so it never changes with live FOV.
-- Units: pane plane at depth 1, screen NDC = (x / -z) / tanH, (y / -z) / tanV.
function Panel._fit(self: any, hPx: number, a: any): number
	local opt = self._opt
	local ds: Vector2 = opt.DesignSize
	local tilt: Vector2 = opt.Tilt
	local full: Vector2 = a.Full
	local depths = {}
	for _, c in self._canvases do
		if not c.IsShadow then
			table.insert(depths, c.Depth / opt.Distance)
		end
	end
	local key = string.format("%.1f|%.1f|%.1f|%.1f|%.1f|%.1f|%.3f|%.2f|%.2f|%.1f|%.1f|%s|%s", full.X, full.Y, a.X0, a.Y0, a.Y1, opt.Distance, hPx, tilt.X, tilt.Y, ds.X, ds.Y, table.concat(depths, ","), tostring(opt.FitFOV))
	if key == self._fitKey then
		return self._fitK
	end
	local fitFov = tonumber(opt.FitFOV)
	local tanV = if fitFov and fitFov > 1 and fitFov < 170 then math.tan(math.rad(fitFov) / 2) else FIT_TANV
	local tanH = tanV * full.X / full.Y
	local over = if self:_reduced() then 1 else OPEN_SCALE
	local function ndcY(px: number): number
		return 1 - 2 * px / full.Y
	end
	local yTop, yBot = ndcY(a.Y0), ndcY(a.Y1)
	local yc, yHalf = (yTop + yBot) / 2, (yTop - yBot) / 2
	local xHalf = (a.X1 - a.X0) / full.X
	local cy = yc * tanV
	local k = 1
	for _ = 1, 3 do
		local hh = (hPx * k / full.Y) * tanV * over
		local hw = hh * ds.X / ds.Y
		local worst = 0
		for _, sy in { -1, 1 } do
			for _, sx in { -1, 1 } do
				local rot = CFrame.Angles(math.rad(sy * tilt.Y), math.rad(sx * tilt.X), 0)
				for _, dz in depths do
					local f = 1 - dz -- a layer dz (in Distance units) closer is drawn (1 - dz) as big
					for _, cn in { Vector3.new(-hw, -hh, 0), Vector3.new(hw, -hh, 0), Vector3.new(-hw, hh, 0), Vector3.new(hw, hh, 0) } do
						local p = rot * (cn * f + Vector3.new(0, 0, dz)) + Vector3.new(0, cy, -1)
						local z = -p.Z
						if z <= 0.05 then
							worst = math.max(worst, 10) -- a corner at the camera: shrink hard
						else
							local nx = (p.X / z) / tanH
							local ny = (p.Y / z) / tanV
							worst = math.max(worst, math.abs(nx) / (xHalf * FIT_MARGIN), math.abs(ny - yc) / (yHalf * FIT_MARGIN))
						end
					end
				end
			end
		end
		if worst <= 1 then
			break
		end
		k /= worst
	end
	self._fitKey = key
	self._fitK = k
	return k
end

-- the panel's untilted on-screen height in px (ScreenHeight, MaxScreenWidth, then the tilt fit)
function Panel._layoutPx(self: any, a: any): number
	local opt = self._opt
	local ds: Vector2 = opt.DesignSize
	local hPx = math.min(opt.ScreenHeight * (a.Y1 - a.Y0), opt.MaxScreenWidth * (a.X1 - a.X0) * ds.Y / ds.X)
	return hPx * self:_fit(hPx, a)
end

function Panel.GetScreenScale(self: any): number
	local ds: Vector2 = self._opt.DesignSize
	local a = self:_freeArea()
	if a.Full.X >= 2 and a.Full.Y >= 2 then
		return self:_layoutPx(a) / ds.Y
	end
	return if self._hPx > 0 then self._hPx / ds.Y else 1
end

function Panel._updateCanvasScale(self: any)
	if self._flat then
		return
	end
	local want = self._opt.CanvasScale
	local cs: number
	if type(want) == "number" then
		cs = want
	else
		local ds: Vector2 = self._opt.DesignSize
		local ratio = self._hPx / ds.Y * 1.1 -- the near edge of a tilted panel is bigger
		cs = math.clamp(math.ceil(ratio * 4) / 4, 1, 2)
	end
	if cs ~= self._cs then
		self._cs = cs
		self:_applyDesign()
	end
end

--------------------------------------------------------------------------------------------------------------------
-- the frame step (render step, after the camera)
--------------------------------------------------------------------------------------------------------------------
function Panel._step(self: any, dt: number)
	local opt = self._opt
	local now = os.clock()
	local state = self._state
	local e = now - self._t0
	local reduced = self:_reduced()
	local from = self._from or self:_fresh()

	-- animation: every curve runs from what was on screen when the transition began
	local scale, paneA, contentA, rise, fxA, swing, tip
	if state == "opening" or state == "open" then
		local a = ease(e / OPEN_PANE, OUT)
		local b = backOut(e / OPEN_PANE) -- scale + swing settle with a small overshoot
		scale = lerp(from.scale, 1, b)
		swing = lerp(from.swing or 0, 0, b)
		tip = lerp(from.tip or 0, 0, a)
		paneA = lerp(from.pane, 1, a)
		local delay = if from.content > 0.01 then 0 else self:_contentDelay()
		local ca = ease((e - delay) / CONTENT_FADE, OUT)
		contentA = lerp(from.content, 1, ca)
		rise = lerp(from.rise, 0, ca)
		fxA = lerp(from.fx, 1, ease(e / BLUR_IN, OUT))
		if state == "opening" and e >= math.max(OPEN_PANE, delay + CONTENT_FADE, BLUR_IN) then
			self._state = "open"
			state = "open"
		end
	else -- closing
		local a = ease(e / CLOSE_FADE, IN)
		scale = if reduced then 1 else lerp(from.scale, CLOSE_SCALE, a)
		swing = lerp(from.swing or 0, 0, a)
		tip = lerp(from.tip or 0, if reduced then 0 else 1, a)
		paneA = lerp(from.pane, 0, a)
		contentA = lerp(from.content, 0, a)
		rise = from.rise
		fxA = lerp(from.fx, 0, ease(e / BLUR_OUT, INOUT))
		if e >= CLOSE_FADE then
			self:_hideCanvas()
		end
		if e >= CLOSE_FADE + HUD_BACK and e >= BLUR_OUT then
			self:_finish()
			return
		end
	end
	local swap = self._swap
	if swap then
		local se = now - swap.T0
		local sa = 0
		if se >= SWAP_GAP then
			if not swap.Shown then
				swap.Shown = true
				swap.Frame.Visible = true
			end
			sa = ease((se - SWAP_GAP) / SWAP_FADE, OUT)
			if se >= SWAP_GAP + SWAP_FADE then
				self:_endSwap()
			end
		end
		contentA *= sa
		rise = math.max(rise, if reduced then 0 else (1 - sa) * CONTENT_RISE)
	end
	self._r = { scale = scale, pane = paneA, content = contentA, rise = rise, fx = fxA, swing = swing, tip = tip }

	-- canvases: alpha + rise
	local riseOff = math.floor(rise + 0.5)
	for _, c in self._canvases do
		local alpha = if c.Alpha == "pane" then paneA else contentA
		if not opt.FadeContent then
			local vis = alpha > 0.5 -- no CanvasGroup: the canvas just appears / goes at half way
			if c.Frame.Visible ~= vis then
				c.Frame.Visible = vis
			end
		elseif alpha >= 1 and state == "open" and not (c == self._main and self._swap) then
			self:_setFaded(c, false)
		elseif c.Faded then
			local t = 1 - alpha
			if c.Fader.GroupTransparency ~= t then
				c.Fader.GroupTransparency = t
			end
		end
		if c.Alpha == "content" and c.Frame.Position.Y.Offset ~= riseOff then
			c.Frame.Position = UDim2.fromOffset(0, riseOff)
		end
	end
	for _, gl in self._glints do
		local gt = 1 - paneA -- the sheen's shape is in the gradient; the frame alpha fades it with the pane
		if gl.Frame.BackgroundTransparency ~= gt then
			gl.Frame.BackgroundTransparency = gt
		end
	end
	local pane = self._pane
	if pane then
		local pt = lerp(1, self._paneT, paneA)
		if pane.BackgroundTransparency ~= pt then -- written only while it animates
			pane.BackgroundTransparency = pt
			self._paneStroke.Transparency = lerp(1, self._paneStrokeT, paneA)
		end
	end

	-- effects: only while we own them
	if opt.ManageEffects then
		if fx.Owner ~= self then
			fx.Owner = self
		end
		if (opt.Blur or 0) > 0 then
			local b = fxBlur()
			local size = opt.Blur * fxA
			if b.Size ~= size then
				b.Size = size
			end
			if b.Enabled ~= (fxA > 0.001) then
				b.Enabled = fxA > 0.001
			end
		elseif fx.Blur and fx.Blur.Enabled then
			fx.Blur.Enabled = false
		end
		if opt.Tint then
			local t = fxTint()
			local tc = Color3.new(1, 1, 1):Lerp(opt.Tint, fxA)
			if t.TintColor ~= tc then
				t.TintColor = tc
				t.Brightness = 0.03 * fxA
			end
			if t.Enabled ~= (fxA > 0.001) then
				t.Enabled = fxA > 0.001
			end
		elseif fx.Tint and fx.Tint.Enabled then
			fx.Tint.Enabled = false
		end
	else
		fxRelease(self)
	end

	-- mouse
	if opt.ManageMouse and state ~= "closing" then
		if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
		if not UserInputService.MouseIconEnabled then
			UserInputService.MouseIconEnabled = true
		end
	end
	if self._canvasHidden then
		return -- fade done, waiting for the HUD beat: nothing to place
	end

	-- size
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local a = self:_freeArea()
	local full: Vector2 = a.Full
	if full.X < 2 or full.Y < 2 then
		return -- suspended while the screen has no size
	end
	self._area = a
	local hPx = self:_layoutPx(a)
	if math.abs(hPx - self._hPx) > 0.01 then
		self._hPx = hPx
		self:_updateCanvasScale()
	end

	-- tilt: target from the pointer, then smoothed; frozen outright while a press on the panel is held
	if not self:_holding() then
		local p = self:_pointer(now)
		local target = p or Vector2.zero
		if not p and opt.Idle and not reduced then
			target = Vector2.new(0.16 * math.sin(now * 0.7), 0.12 * math.sin(now * 0.53 + 1.3))
		end
		self._target = target
		local k = 1 - math.exp(-(opt.TiltSmoothing or 9) * math.min(dt, 0.1))
		self._tilt = self._tilt:Lerp(self._target, if dt <= 0 then 0 else k)
	end
	local tilt: Vector2 = opt.Tilt
	local yaw = -self._tilt.X * tilt.X + swing * SWING_YAW
	local pitch = -self._tilt.Y * tilt.Y + swing * SWING_PITCH + tip * CLOSE_TIP
	for _, gl in self._glints do
		local off = Vector2.new(self._tilt.X * GLINT_OFFSET, self._tilt.Y * GLINT_OFFSET)
		if (gl.Grad.Offset - off).Magnitude > 0.002 then
			gl.Grad.Offset = off
			gl.Grad.Rotation = 25 + self._tilt.X * GLINT_ROT
		end
	end
	local ds: Vector2 = opt.DesignSize
	local d = opt.Distance

	if self._flat then
		-- flat: each root scaled to the same on-screen size; the tilt becomes a 2D parallax, more for front layers
		local s = hPx / ds.Y * scale
		for _, c in self._canvases do
			if math.abs(c.Scale.Scale - s) > 1e-4 then
				c.Scale.Scale = s
			end
			local par = 5 + c.Depth / d * 40
			local pos = UDim2.fromOffset(math.floor(a.CX + self._tilt.X * par + 0.5), math.floor(a.CY + self._tilt.Y * par * 0.8 + 0.5))
			if c.Root.Position ~= pos then
				c.Root.Position = pos
			end
		end
		return
	end

	local tanV = math.tan(math.rad(math.clamp(cam.FieldOfView, 1, 120)) / 2) -- the LIVE fov: size never breathes
	local wpp = 2 * d * tanV / full.Y -- studs per screen px at depth d
	local h = hPx * wpp * scale
	local w = h * ds.X / ds.Y
	local cy = -(a.CY - full.Y / 2) * wpp -- the free area's centre
	-- the pane's FACE sits exactly at depth d (part centre half a thickness behind it), tilted about its centre
	local face = cam.CFrame * CFrame.new(0, cy, -d) * CFrame.Angles(math.rad(pitch), math.rad(yaw), 0)
	for _, c in self._canvases do
		local part = self:_ensurePart(c)
		local f = (d - c.Depth) / d -- a closer plane drawn smaller so it lines up with the pane at zero tilt
		local cw, ch = w * f, h * f
		local cf = face * CFrame.new(0, 0, c.Depth)
		c.Face = cf
		c.W = cw
		c.H = ch
		local size = Vector3.new(cw, ch, THICK)
		if part.Size ~= size then
			part.Size = size
		end
		part.CFrame = cf * CFrame.new(0, 0, -THICK / 2)
	end
end

--------------------------------------------------------------------------------------------------------------------
-- pointer -> canvas (sliders, drags, hit tests in 3D)
--------------------------------------------------------------------------------------------------------------------
-- the point on canvas c (in that canvas's AbsolutePosition space) + whether it is inside the canvas
function Panel._mapOn(self: any, c: any, vpPos: Vector2): (Vector2?, boolean)
	local ds: Vector2 = self._opt.DesignSize
	if self._flat then
		local s = c.Scale.Scale
		if s <= 0 then
			return nil, false
		end
		local centre = Vector2.new(c.Root.Position.X.Offset, c.Root.Position.Y.Offset) -- full-screen px (ScreenInsets None)
		local loc = (vpPos - centre) / s + ds / 2
		local inside = loc.X >= 0 and loc.Y >= 0 and loc.X <= ds.X and loc.Y <= ds.Y
		return c.Root.AbsolutePosition + loc * s, inside
	end
	local cam = workspace.CurrentCamera
	local a = self._area
	if not cam or not a or c.W <= 0 or not c.Part then
		return nil, false
	end
	-- our own ray through the full-screen point (same projection we place the panel with)
	local full: Vector2 = a.Full
	local tanV = math.tan(math.rad(math.clamp(cam.FieldOfView, 1, 120)) / 2)
	local nx = (vpPos.X - full.X / 2) / (full.Y / 2) * tanV
	local ny = -(vpPos.Y - full.Y / 2) / (full.Y / 2) * tanV
	local origin = cam.CFrame.Position
	local dir = cam.CFrame:VectorToWorldSpace(Vector3.new(nx, ny, -1).Unit)
	local cf: CFrame = c.Face
	local n = cf.ZVector -- the Back face looks back at the camera
	local denom = dir:Dot(n)
	if math.abs(denom) < 1e-6 then
		return nil, false
	end
	local t = (cf.Position - origin):Dot(n) / denom
	if t <= 0 then
		return nil, false
	end
	local l = cf:PointToObjectSpace(origin + dir * t)
	local u = (l.X + c.W / 2) / c.W
	local v = (c.H / 2 - l.Y) / c.H
	local inside = u >= 0 and u <= 1 and v >= 0 and v <= 1
	local cs = self._cs
	return Vector2.new(u * ds.X * cs, v * ds.Y * cs) + c.Root.AbsolutePosition, inside
end

local function overVisibleChild(frame: Frame, p: Vector2): boolean
	for _, ch in frame:GetChildren() do
		if ch:IsA("GuiObject") and ch.Visible then
			local ap, as = ch.AbsolutePosition, ch.AbsoluteSize
			if p.X >= ap.X and p.Y >= ap.Y and p.X <= ap.X + as.X and p.Y <= ap.Y + as.Y then
				return true
			end
		end
	end
	return false
end

function Panel.ScreenToCanvas(self: any, pos: Vector2, allowOutside: boolean?, target: GuiObject?): (Vector2?, Frame?)
	if self._canvasHidden then
		return nil, nil
	end
	local vpPos = guiToViewport(pos)
	if target then
		for _, c in self._canvases do
			if target == c.Root or target:IsDescendantOf(c.Root) then
				local p, inside = self:_mapOn(c, vpPos)
				if p and (inside or allowOutside) then
					return p, c.Frame
				end
				return nil, nil
			end
		end
	end
	-- front layers first, where they actually have something; then the pane; then back layers
	for i = #self._canvases, 1, -1 do
		local c = self._canvases[i]
		if not c.IsShadow then
			local p, inside = self:_mapOn(c, vpPos)
			if p and inside and (c == self._main or overVisibleChild(c.Frame, p)) then
				return p, c.Frame
			end
		end
	end
	if allowOutside then
		local p = self:_mapOn(self._main, vpPos)
		if p then
			return p, self._main.Frame
		end
	end
	return nil, nil
end

return ImmersiveUI
