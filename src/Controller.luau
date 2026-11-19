--!strict

local gui = script:FindFirstAncestorOfClass("ScreenGui") :: ScreenGui
local Scripts = script.Parent
local root = gui:WaitForChild("Root") :: Frame

if gui:GetAttribute("Bound") then
	return
end
gui:SetAttribute("Bound", true)

local Scale = require(Scripts.Scale)
local Clock = require(Scripts.Clock)
local Motion = require(Scripts.Motion)
local Windows = require(Scripts.Windows)
local Fixtures = require(Scripts.Fixtures)

Scale.init(gui)
Clock.init(gui)
Motion.init(gui)

local ctx = {
	gui = gui,
	root = root,
	Scale = Scale,
	Clock = Clock,
	Motion = Motion,
	Windows = Windows,
	Fixtures = Fixtures,
	Scripts = Scripts,
	api = {},
	refStates = {},
}

local order = { "Hud", "Tooltip", "Shop", "Index", "Drawers", "Hollow", "Settings", "Merchant", "Rewards", "DemoContent", "HudStyle", "Topbar", "Immersive", "Dev" }
for _, name in order do
	local mod = Scripts:FindFirstChild(name)
	if mod and mod:IsA("ModuleScript") then
		local ok, err = pcall(function()
			(require(mod) :: any).init(ctx)
		end)
		if not ok then
			warn("[SpeedPetsUI] " .. name .. " init failed: " .. tostring(err))
			gui:SetAttribute("InitError_" .. name, tostring(err))
		end
	end
end

Scale.onChanged(function(_s, design)
	Windows.setDesign(design)
end)

gui:SetAttribute("Ready", true)
