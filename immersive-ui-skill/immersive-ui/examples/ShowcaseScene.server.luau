--[[
	ShowcaseScene  (Script)  -  made by @momentumcash, MIT licence
	--------------------------------------------------------------
	Turns a plain Baseplate into a sunny grass field so the immersive menu's blur has some colour to show
	(grey blurred to grey looks like nothing). For recording the demo, not for a real game.

	HOW TO USE
	  Put this Script in ServerScriptService (next to the DailyShopDemo LocalScript in StarterPlayerScripts) and press
	  Play. Everything goes in workspace.ImmersiveShowcase and is rebuilt each run. Delete the script to remove it.

	No asset ids, no meshes, no decals: Terrain grass + Lighting only (afternoon sun, light atmosphere, a little
	bloom). It hides the Baseplate (still solid) and does not clear the grass when removed: use Terrain > Clear.
]]

local Lighting = game:GetService("Lighting")

------------------------------------------------------------------------------------------------------------------
-- Colours
------------------------------------------------------------------------------------------------------------------
local function hex(s: string): Color3
	return Color3.fromHex(s)
end

------------------------------------------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------------------------------------------
local old = workspace:FindFirstChild("ImmersiveShowcase")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "ImmersiveShowcase"

------------------------------------------------------------------------------------------------------------------
-- Ground: one big field of grass (Terrain grass, with the little blades on). Nothing else, so the menu is the star.
------------------------------------------------------------------------------------------------------------------
local floorY = 0
local base = workspace:FindFirstChild("Baseplate")
if base and base:IsA("BasePart") then
	floorY = base.Position.Y + base.Size.Y / 2
	base.Transparency = 1 -- the grass covers it; it stays solid underneath as a safety floor
end

local terrain = workspace.Terrain
local FIELD = 1024 -- studs across
terrain:FillBlock(CFrame.new(0, floorY - 4, 0), Vector3.new(FIELD, 8, FIELD), Enum.Material.Grass)
terrain:SetMaterialColor(Enum.Material.Grass, hex("#6fcf4a")) -- bright spring green
pcall(function()
	terrain.Decoration = true -- animated grass blades (set it in Terrain properties if this is blocked)
end)

if not workspace:FindFirstChildWhichIsA("SpawnLocation", true) then
	local sp = Instance.new("SpawnLocation")
	sp.Anchored = true
	sp.Size = Vector3.new(8, 1, 8)
	sp.Position = Vector3.new(0, floorY + 0.5, 0)
	sp.Transparency = 1
	sp.CanCollide = false
	sp.Parent = root
end

root.Parent = workspace

------------------------------------------------------------------------------------------------------------------
-- Lighting: early-afternoon sun, light blue atmosphere, a little bloom. Our own effects only, named Showcase*.
------------------------------------------------------------------------------------------------------------------
Lighting.ClockTime = 14
Lighting.Brightness = 2.6
Lighting.Ambient = hex("#7a8aa6")
Lighting.OutdoorAmbient = hex("#a9c4e6")
Lighting.EnvironmentDiffuseScale = 0.6
Lighting.EnvironmentSpecularScale = 0.6
Lighting.GlobalShadows = true

for _, name in { "ShowcaseAtmosphere", "ShowcaseBloom", "ShowcaseColor" } do
	local o = Lighting:FindFirstChild(name)
	if o then
		o:Destroy()
	end
end
if not Lighting:FindFirstChildOfClass("Atmosphere") then
	local atm = Instance.new("Atmosphere")
	atm.Name = "ShowcaseAtmosphere"
	atm.Density = 0.28
	atm.Offset = 0.15
	atm.Color = hex("#cfe8ff")
	atm.Decay = hex("#9fc8f0")
	atm.Glare = 0.2
	atm.Haze = 1.2
	atm.Parent = Lighting
end
local bloom = Instance.new("BloomEffect")
bloom.Name = "ShowcaseBloom"
bloom.Intensity = 0.35
bloom.Size = 24
bloom.Threshold = 1.6
bloom.Parent = Lighting
local cc = Instance.new("ColorCorrectionEffect")
cc.Name = "ShowcaseColor"
cc.Saturation = 0.15
cc.Contrast = 0.05
cc.Parent = Lighting
