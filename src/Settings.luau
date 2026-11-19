--!strict

local UserInputService = game:GetService("UserInputService")

local Settings = {}

local TRANSITION = {
	open = { dur = 0.18, style = Enum.EasingStyle.Quart, dir = Enum.EasingDirection.Out, fromScale = 0.95, fromOffset = UDim2.fromOffset(0, 120) },
	close = { dur = 0.233, style = Enum.EasingStyle.Quart, dir = Enum.EasingDirection.Out, toScale = 0.9, toOffset = UDim2.fromOffset(0, 135) },
}

local CLOSE_PROFILE = { hoverScale = 1.05, hoverTime = 0.1, pressScale = 0.95, pressTime = 0.1, leaveTime = 0.1, shade = 0.3, light = 0.3 }
local TOGGLE_TIME = 0.14

local function isPress(io: InputObject): boolean
	return io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch
end

local function isMove(io: InputObject): boolean
	return io.UserInputType == Enum.UserInputType.MouseMovement or io.UserInputType == Enum.UserInputType.Touch
end

function Settings.init(ctx: any)
	local gui = ctx.gui :: ScreenGui
	local root = ctx.root :: Frame
	local Windows = ctx.Windows
	local Motion = ctx.Motion

	local section = root:WaitForChild("Settings") :: Frame
	local host = section:WaitForChild("Host") :: Frame
	local win = host:WaitForChild("Window") :: Frame
	local panel = win:WaitForChild("Panel") :: Frame
	local list = panel:WaitForChild("List") :: ScrollingFrame
	local close = panel:WaitForChild("CloseButton") :: TextButton
	local home = win.Position

	local defaults: { [string]: any } = { SettingsMusic = 1, SettingsSFX = 1, SettingsViewOthersPets = true, SettingsViewYourPets = true }
	for k, v in defaults do
		if gui:GetAttribute(k) == nil then
			gui:SetAttribute(k, v)
		end
	end

	Windows.register("Settings", win, {
		onOpen = function()
			list.CanvasPosition = Vector2.zero
		end,
	}, TRANSITION)

	do
		local vis = close:WaitForChild("Visual") :: Frame
		local pop = vis:WaitForChild("Pop") :: UIScale
		local shade = vis:WaitForChild("Shade") :: Frame
		local light = vis:WaitForChild("Light") :: Frame
		local key = "settings_close"
		local hovering = false
		local p = CLOSE_PROFILE
		local function look(mode: string)
			shade.BackgroundTransparency = if mode == "hover" then 1 - p.shade else 1
			light.BackgroundTransparency = if mode == "press" then 1 - p.light else 1
		end
		local function scaleTo(s: number, d: number)
			Motion.cancel(key)
			Motion.tween(key, pop, d, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Scale = s })
		end
		close.MouseEnter:Connect(function()
			hovering = true
			look("hover")
			scaleTo(p.hoverScale, p.hoverTime)
		end)
		close.MouseLeave:Connect(function()
			hovering = false
			look("none")
			scaleTo(1, p.leaveTime)
		end)
		close.MouseButton1Down:Connect(function()
			look("press")
			scaleTo(p.pressScale, p.pressTime)
		end)
		close.MouseButton1Up:Connect(function()
			look(if hovering then "hover" else "none")
			scaleTo(if hovering then p.hoverScale else 1, p.hoverTime)
		end)
		close.Activated:Connect(function()
			Windows.close("Settings")
			task.delay(TRANSITION.close.dur + 0.05, function()
				if not Windows.isOpen("Settings") then
					hovering = false
					look("none")
					Motion.cancel(key)
					pop.Scale = 1
				end
			end)
		end)
		ctx.api.SettingsClose = { look = look, scale = function(s: string)
			Motion.cancel(key)
			pop.Scale = tonumber(s) or 1
		end }
	end

	local dragging: { hit: GuiObject, inner: GuiObject, attr: string, input: InputObject? }? = nil
	local lastY = 0 -- screen Y of the pointer, so a tilted panel can map X correctly
	local function bindSlider(rowName: string)
		local r = list:WaitForChild(rowName) :: Frame
		local hit = r:WaitForChild("Slider") :: TextButton
		local attr = hit:GetAttribute("Setting") :: string
		local track = hit:WaitForChild("Track") :: Frame
		local inner = track:WaitForChild("Inner") :: Frame
		local fill = inner:WaitForChild("Fill") :: Frame
		local knob = inner:WaitForChild("Knob") :: Frame
		local function apply(v: number)
			v = math.clamp(v, 0, 1)
			fill.Size = UDim2.fromScale(v, 1)
			fill.Visible = v > 0.005
			knob.Position = UDim2.fromScale(v, 0.5)
		end
		apply(gui:GetAttribute(attr) :: number)
		gui:GetAttributeChangedSignal(attr):Connect(function()
			apply(gui:GetAttribute(attr) :: number)
		end)
		local function setFromX(x: number)
			local a, w = inner.AbsolutePosition.X, inner.AbsoluteSize.X
			if w > 0 and ctx.toCanvas then
				-- the window is on a tilted 3D panel: map the screen point onto the slider's canvas
				local p = ctx.toCanvas(Vector2.new(x, lastY), inner)
				if p then
					x = p.X
				end
			end
			if w > 0 then
				gui:SetAttribute(attr, math.clamp((x - a) / w, 0, 1))
			end
		end
		hit.InputBegan:Connect(function(io: InputObject)
			if isPress(io) then
				dragging = { hit = hit, inner = inner, attr = attr, input = if io.UserInputType == Enum.UserInputType.Touch then io else nil }
				list.ScrollingEnabled = false
				lastY = io.Position.Y
				setFromX(io.Position.X)
			end
		end)
		return setFromX
	end
	local setters: { [string]: (number) -> () } = {
		SettingsMusic = bindSlider("Row_Music"),
		SettingsSFX = bindSlider("Row_SFX"),
	}
	UserInputService.InputChanged:Connect(function(io: InputObject)
		local d = dragging
		if d and isMove(io) and (d.input == nil or d.input == io) then
			lastY = io.Position.Y
			setters[d.attr](io.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(io: InputObject)
		local d = dragging
		if d and isPress(io) and (d.input == nil or d.input == io) then
			dragging = nil
			list.ScrollingEnabled = true
		end
	end)

	local function bindToggle(rowName: string)
		local r = list:WaitForChild(rowName) :: Frame
		local btn = r:WaitForChild("Toggle") :: TextButton
		local attr = btn:GetAttribute("Setting") :: string
		local knob = btn:WaitForChild("Knob") :: Frame
		local state = r:WaitForChild("State") :: TextLabel
		local stateShadow = r:FindFirstChild("StateShadow") :: TextLabel?
		local key = "settings_toggle_" .. attr
		local function apply(animate: boolean)
			local on = gui:GetAttribute(attr) == true
			local x = (if on then knob:GetAttribute("OnX") else knob:GetAttribute("OffX")) :: number
			local pos = UDim2.fromOffset(x, knob.Position.Y.Offset)
			Motion.cancel(key)
			if animate then
				Motion.tween(key, knob, TOGGLE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Position = pos })
			else
				knob.Position = pos
			end
			local text = (if on then state:GetAttribute("OnText") else state:GetAttribute("OffText")) :: string
			state.Text = text
			if stateShadow then
				stateShadow.Text = text
			end
		end
		apply(false)
		gui:GetAttributeChangedSignal(attr):Connect(function()
			apply(true)
		end)
		btn.Activated:Connect(function()
			gui:SetAttribute(attr, not (gui:GetAttribute(attr) == true))
		end)
	end
	bindToggle("Row_ViewOthersPets")
	bindToggle("Row_ViewYourPets")

	local function snap(name: string)
		Windows.open(name)
		Motion.cancel("win_" .. name)
		local pop = win:FindFirstChild("PopScale") :: UIScale?
		if pop then
			pop.Scale = 1
		end
		win.Position = home
	end
	local function setScroll(designPx: number)
		local k = if list.Size.Y.Offset > 0 then list.AbsoluteSize.Y / list.Size.Y.Offset else 1
		list.CanvasPosition = Vector2.new(0, designPx * k)
	end
	local function reset()
		for k, v in defaults do
			gui:SetAttribute(k, v)
		end
		list.CanvasPosition = Vector2.zero
		ctx.api.SettingsClose.look("none")
		ctx.api.SettingsClose.scale("1")
	end
	ctx.api.Settings = {
		open = function()
			snap("Settings")
			return "open"
		end,
		set = function(attr: string, v: string)
			local n = tonumber(v)
			gui:SetAttribute(attr, if n ~= nil then n else v == "true")
			return attr .. "=" .. tostring(gui:GetAttribute(attr))
		end,
		scroll = function(px: string)
			setScroll(tonumber(px) or 0)
			return "scroll " .. tostring(list.CanvasPosition.Y)
		end,
		pose = function(scale: string, dy: string)
			Motion.cancel("win_Settings")
			local pop = win:FindFirstChild("PopScale") :: UIScale?
			if pop then
				pop.Scale = tonumber(scale) or 1
			end
			win.Position = home + UDim2.fromOffset(0, tonumber(dy) or 0)
			return "pose"
		end,
		reset = reset,
	}
	ctx.refStates["settings_open_113_9"] = function()
		reset()
		snap("Settings")
	end
	ctx.refStates["settings_music_drag_117_0"] = function()
		reset()
		snap("Settings")
		gui:SetAttribute("SettingsMusic", 0.839)
	end
	ctx.refStates["settings_scrolled_119_5"] = function()
		reset()
		snap("Settings")
		setScroll(279)
	end
	ctx.refStates["settings_x_hover_120_133"] = function()
		reset()
		snap("Settings")
		ctx.api.SettingsClose.look("hover")
		ctx.api.SettingsClose.scale("1.05")
	end
	ctx.refStates["settings_x_press_120_25"] = function()
		reset()
		snap("Settings")
		ctx.api.SettingsClose.look("press")
		ctx.api.SettingsClose.scale("0.96")
	end
	ctx.refStates["settings_opening_113_25"] = function()
		reset()
		snap("Settings")
		ctx.api.Settings.pose("0.995", "17")
	end
	ctx.refStates["settings_closing_120_383"] = function()
		reset()
		snap("Settings")
		ctx.api.SettingsClose.look("hover")
		ctx.api.SettingsClose.scale("1.05")
		ctx.api.Settings.pose("0.906", "122")
	end
	ctx.refStates["settings_toggles_off_inferred"] = function()
		reset()
		snap("Settings")
		gui:SetAttribute("SettingsViewOthersPets", false)
		gui:SetAttribute("SettingsViewYourPets", false)
	end
end

return Settings
