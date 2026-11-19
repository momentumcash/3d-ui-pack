--!strict
--[[
	DemoContent  (ModuleScript in SpeedPetsUI.Scripts, runs after Drawers + Merchant)
	Fills the two side drawers so they don't look empty on camera:
	- Pets drawer: 6 equipped pets (from the Shop's own pet pictures), "6/13 Active"
	- Growing Eggs: 3 egg rows instead of 1, each OPEN button pops its row away
	Demo data only.
]]

local TweenService = game:GetService("TweenService")

local DemoContent = {}

local STUDS = "rbxassetid://78165738325794"
local RARITY = {
	{ "#7dff6b", "#2fbf3a" }, -- common green
	{ "#5bd2ff", "#2a7dff" }, -- rare blue
	{ "#d08bff", "#8a2fff" }, -- epic purple
	{ "#ffe24a", "#ff9d00" }, -- legendary gold
}

local function hex(s: string): Color3
	return Color3.fromHex(s)
end

function DemoContent.init(ctx: any)
	local root = ctx.root :: Frame
	local drawers = root:FindFirstChild("Drawers")
	if not drawers then
		return
	end

	-- pet pictures from the Shop (sprite sheet crops)
	local pets: { { image: string, offset: Vector2, size: Vector2 } } = {}
	local seen: { [string]: boolean } = {}
	local shop = root:FindFirstChild("Shop")
	for _, d in (if shop then shop else root):GetDescendants() do
		local im = d:FindFirstChild("Pet")
		if d:IsA("GuiButton") and im and im:IsA("ImageLabel") and im.Image ~= "" then
			local key = im.Image .. tostring(im.ImageRectOffset)
			if not seen[key] then
				seen[key] = true
				table.insert(pets, { image = im.Image, offset = im.ImageRectOffset, size = im.ImageRectSize })
			end
		end
	end

	------------------------------------------------------------------------------------------------------------
	-- Pets drawer
	------------------------------------------------------------------------------------------------------------
	local pd = drawers:FindFirstChild("PetsDrawer")
	local body = pd and pd:FindFirstChild("Body") :: Frame?
	if pd and body and #pets > 0 and not body:FindFirstChild("PetGrid") then
		local grid = Instance.new("Frame")
		grid.Name = "PetGrid"
		grid.BackgroundTransparency = 1
		grid.Position = UDim2.fromOffset(14, 14)
		grid.Size = UDim2.new(1, -28, 1, -28)
		grid.ZIndex = 4
		grid.Parent = body
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.fromOffset(112, 112)
		layout.CellPadding = UDim2.fromOffset(11, 11)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = grid
		for i = 1, 6 do
			local pet = pets[(i - 1) % #pets + 1]
			local r = RARITY[(i - 1) % #RARITY + 1]
			local slot = Instance.new("Frame")
			slot.Name = "Pet" .. i
			slot.LayoutOrder = i
			slot.BackgroundColor3 = Color3.new(1, 1, 1)
			slot.ZIndex = 4
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 8)
			c.Parent = slot
			local st = Instance.new("UIStroke")
			st.Thickness = 3
			st.Color = hex("#14102a")
			st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			st.Parent = slot
			local g = Instance.new("UIGradient")
			g.Rotation = 90
			g.Color = ColorSequence.new(hex(r[1]), hex(r[2]))
			g.Parent = slot
			for k = 1, 2 do
				local s = Instance.new("ImageLabel")
				s.Name = "Studs" .. k
				s.BackgroundTransparency = 1
				s.Image = STUDS
				s.ScaleType = Enum.ScaleType.Tile
				s.TileSize = UDim2.fromOffset(20, 20)
				s.Size = UDim2.fromScale(1, 1)
				s.ZIndex = 5
				s.Parent = slot
			end
			local im = Instance.new("ImageLabel")
			im.Name = "Pet"
			im.BackgroundTransparency = 1
			im.AnchorPoint = Vector2.new(0.5, 0.5)
			im.Position = UDim2.fromScale(0.5, 0.52)
			im.Size = UDim2.fromScale(0.86, 0.86)
			im.Image = pet.image
			im.ImageRectOffset = pet.offset
			im.ImageRectSize = pet.size
			im.ScaleType = Enum.ScaleType.Fit
			im.ZIndex = 6
			im.Parent = slot
			local eq = Instance.new("TextLabel")
			eq.Name = "Equipped"
			eq.BackgroundColor3 = hex("#33d64a")
			eq.Position = UDim2.fromOffset(6, 6)
			eq.Size = UDim2.fromOffset(28, 28)
			eq.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
			eq.Text = "E"
			eq.TextSize = 18
			eq.TextColor3 = Color3.new(1, 1, 1)
			eq.ZIndex = 7
			local ec = Instance.new("UICorner")
			ec.CornerRadius = UDim.new(1, 0)
			ec.Parent = eq
			local es = Instance.new("UIStroke")
			es.Thickness = 2
			es.Color = hex("#0b3d10")
			es.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			es.Parent = eq
			eq.Parent = slot
			slot.Parent = grid
		end
		local title = pd:FindFirstChild("Title") :: TextLabel?
		if title then
			title.Text = "6/13 Active"
		end
	end

	------------------------------------------------------------------------------------------------------------
	-- Growing Eggs: 3 rows
	------------------------------------------------------------------------------------------------------------
	local ge = drawers:FindFirstChild("GrowingEggs")
	local row = ge and ge:FindFirstChild("EggRow", true) :: Frame?
	if row and not row.Parent:FindFirstChild("EggRow2") then
		local step = row.Size.Y.Offset + 12
		for i = 2, 3 do
			local r = row:Clone()
			r.Name = "EggRow" .. i
			r.Position = row.Position + UDim2.fromOffset(0, step * (i - 1))
			r.Parent = row.Parent
			local open = r:FindFirstChild("OpenButton") :: TextButton?
			if open then
				open:RemoveTag("SPUI_DrawerButton")
				require(ctx.Scripts.Pressable).bind(open, function()
					local s = Instance.new("UIScale")
					s.Parent = r
					TweenService:Create(s, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play()
					task.delay(0.2, function()
						r.Visible = false
						s:Destroy()
					end)
				end)
			end
		end
	end
end

return DemoContent
