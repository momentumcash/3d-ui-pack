--!strict

local Motion = require(script.Parent.Motion)
local Config = require(script.Parent.Config)

local Windows = {}

export type Win = {
	name: string,
	frame: GuiObject,
	scale: UIScale,
	homePos: UDim2,
	onOpen: (() -> ())?,
	onClose: (() -> ())?,
}

local wins: { [string]: Win } = {}
local current: string? = nil
local listeners: { (string?, string?) -> () } = {}
local hudHolds: { [string]: number } = {}
local hudSetter: ((boolean) -> ())? = nil

local design = Vector2.new(2009, 1056)
local function fitOne(w: Win)
	local host = w.frame.Parent
	if not host or not host:IsA("GuiObject") then
		return
	end
	local fit = host:FindFirstChild("Fit") :: UIScale?
	if not fit then
		local f = Instance.new("UIScale")
		f.Name = "Fit"
		f.Parent = host
		fit = f
	end
	if host:GetAttribute("ImmersiveHost") then
		(fit :: UIScale).Scale = 1 -- on a 3D panel: the panel fits itself to the screen
		return
	end
	local size = (host :: GuiObject).Size
	local hw, hh = size.X.Offset, size.Y.Offset
	if hw <= 0 or hh <= 0 then
		return
	end
	local margin = 16
	;(fit :: UIScale).Scale = math.min(1, (design.X - 2 * margin) / hw, (design.Y - 2 * margin) / hh)
end

function Windows.register(name: string, frame: GuiObject, hooks: { onOpen: (() -> ())?, onClose: (() -> ())? }?, transition: any?)
	if transition then
		Config.Transitions[name] = transition
	end
	local sc = frame:FindFirstChild("PopScale") :: UIScale?
	if not sc then
		local s = Instance.new("UIScale")
		s.Name = "PopScale"
		s.Parent = frame
		sc = s
	end
	wins[name] = {
		name = name,
		frame = frame,
		scale = sc :: UIScale,
		homePos = frame.Position,
		onOpen = hooks and hooks.onOpen,
		onClose = hooks and hooks.onClose,
	}
	frame.Visible = false
	fitOne(wins[name])
end

function Windows.onChanged(fn: (string?, string?) -> ())
	table.insert(listeners, fn)
end

function Windows.setHudSetter(fn: (boolean) -> ())
	hudSetter = fn
end

function Windows.holdHud(tag: string): () -> ()
	hudHolds[tag] = (hudHolds[tag] or 0) + 1
	if hudSetter then
		hudSetter(false)
	end
	local released = false
	return function()
		if released then
			return
		end
		released = true
		hudHolds[tag] -= 1
		if hudHolds[tag] <= 0 then
			hudHolds[tag] = nil
		end
		if next(hudHolds) == nil and hudSetter then
			hudSetter(true)
		end
	end
end

local function transition(name: string): any
	return Config.Transitions[name] or Config.Transitions.Default
end

local function playOpen(w: Win)
	local trAll = transition(w.name)
	local tr = trAll.open
	local key = "win_" .. w.name
	local g = Motion.cancel(key)
	if trAll.custom then
		w.frame.Visible = true
		trAll.custom.open(w, key, g)
		if w.onOpen then
			w.onOpen()
		end
		return
	end
	w.frame.Visible = true
	w.frame.Position = w.homePos + (tr.fromOffset or UDim2.new())
	w.scale.Scale = tr.fromScale or 1
	if tr.steps then
		local t0 = 0
		for _, step in tr.steps do
			Motion.after(key, g, t0, function()
				Motion.tween(key, w.scale, step.dur, step.style, step.dir, { Scale = step.scale })
				if step.pos then
					Motion.tween(key, w.frame, step.dur, step.style, step.dir, { Position = w.homePos + step.pos })
				end
			end)
			t0 += step.dur
		end
	else
		Motion.tween(key, w.scale, tr.dur, tr.style, tr.dir, { Scale = 1 })
		Motion.tween(key, w.frame, tr.dur, tr.style, tr.dir, { Position = w.homePos })
	end
	if w.onOpen then
		w.onOpen()
	end
end

local function playClose(w: Win, done: (() -> ())?)
	local trAll = transition(w.name)
	local tr = trAll.close
	local key = "win_" .. w.name
	local g = Motion.cancel(key)
	if w.onClose then
		w.onClose()
	end
	if trAll.custom then
		trAll.custom.close(w, key, g, function()
			if Motion.current(key) == g then
				w.frame.Visible = false
			end
			if done then
				done()
			end
		end)
		return
	end
	if tr.dur <= 0 then
		w.frame.Visible = false
		w.scale.Scale = 1
		w.frame.Position = w.homePos
		if done then
			done()
		end
		return
	end
	Motion.tween(key, w.scale, tr.dur, tr.style, tr.dir, { Scale = tr.toScale or 1 })
	if tr.toOffset then
		Motion.tween(key, w.frame, tr.dur, tr.style, tr.dir, { Position = w.homePos + tr.toOffset })
	end
	Motion.after(key, g, tr.dur, function()
		w.frame.Visible = false
		w.scale.Scale = 1
		w.frame.Position = w.homePos
		if done then
			done()
		end
	end)
end

function Windows.setDesign(d: Vector2)
	design = d
	for _, w in wins do
		fitOne(w)
	end
end

function Windows.isOpen(name: string): boolean
	return current == name
end

function Windows.current(): string?
	return current
end

function Windows.open(name: string)
	local w = wins[name]
	if not w or current == name then
		return
	end
	local prev = current
	if prev and wins[prev] then
		playClose(wins[prev])
	end
	current = name
	playOpen(w)
	for _, fn in listeners do
		task.spawn(fn, current, prev)
	end
end

function Windows.close(name: string?)
	local target = name or current
	if not target or current ~= target then
		return
	end
	current = nil
	playClose(wins[target])
	for _, fn in listeners do
		task.spawn(fn, nil, target)
	end
end

function Windows.toggle(name: string)
	if current == name then
		Windows.close(name)
	else
		Windows.open(name)
	end
end

function Windows.replay(name: string)
	local w = wins[name]
	if not w then
		return
	end
	if current and current ~= name then
		Windows.close(current)
	end
	current = name
	playOpen(w)
end

return Windows
