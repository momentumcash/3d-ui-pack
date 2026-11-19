# Immersive UI for Roblox

Make your game's menu float in 3D: a clear glass panel that leans toward your mouse while the world blurs behind it.
Buttons on the front float off the glass, so it really looks 3D when it tilts.

Made by @momentumcash. Free to use (MIT licence).


---

## Install (with Claude Code)

1. **Unzip the download.** Inside you'll find a folder called `immersive-ui`. Open it: you should see `SKILL.md`
   right there (not another folder). That's the one you copy.
2. **Copy that folder into your Claude skills folder**, so the file ends up here:
   - Mac: `~/.claude/skills/immersive-ui/SKILL.md`
   - Windows: `%USERPROFILE%\.claude\skills\immersive-ui\SKILL.md`
     (paste `%USERPROFILE%\.claude\skills` into the File Explorer address bar; make the `skills` folder if it's missing)
3. **Connect Roblox Studio to Claude Code.** Open your game in Studio, then:
   **Assistant** > **...** menu > **Manage MCP Servers** > **Quick connect** > **Claude Code**.
   Restart Claude Code after that.
4. **Ask Claude.** Type `/immersive-ui` or just:

   > make my shop menu immersive

   (Swap "shop" for your menu's name. No menu yet? Type **"build the immersive daily and shop demo"**.)

Claude finds your menu, installs the module, wraps your menu, presses Play, checks it and tunes it. It backs up
anything it changes into **ServerStorage > ImmersiveUI_Backups** (with an `UNDO` list), never deletes your UI and
never publishes. To keep the result, use **File > Save to File**. Heads-up: if your place uses Team Create, Studio
can save edits to Roblox on its own.

---

## No Claude? Do it by hand

**Try the demo (2 minutes):**

1. In the Explorer, right-click **ReplicatedStorage** > Insert Object > **ModuleScript**. Rename it `ImmersiveUI`.
   Double-click it, delete everything in it, paste in all of `ImmersiveUI.luau`.
2. Right-click **StarterPlayer > StarterPlayerScripts** > Insert Object > **LocalScript**. Delete the
   `print("Hello world!")` line, paste in all of `examples/DailyShopDemo.client.luau`.
3. (Optional, for a pretty background) Right-click **ServerScriptService** > Insert Object > **Script**, replace its
   text with all of `examples/ShowcaseScene.server.luau`. Only do this on an empty baseplate: it changes Lighting.
4. Press **Play**. Click **DAILY** or **SHOP** on the left of the screen.

**Use it on your own menu.** Say your menu is the Frame **StarterGui > ShopGui > Main** and your open button is
**StarterGui > HUD > ShopButton**. Make a **LocalScript** in **StarterPlayer > StarterPlayerScripts** and paste:

```lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ImmersiveUI = require(ReplicatedStorage:WaitForChild("ImmersiveUI"))

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local shopFrame = playerGui:WaitForChild("ShopGui"):WaitForChild("Main")    -- your menu
local openButton = playerGui:WaitForChild("HUD"):WaitForChild("ShopButton") -- the button that opens it

local panel = ImmersiveUI.new({
	Name = "Shop",
	DesignSize = Vector2.new(1100, 720), -- your menu's size in pixels (roughly)
	HideOtherGuis = false,               -- keep your HUD; list anything that covers the menu in HideGuis
})

shopFrame.AnchorPoint = Vector2.zero
shopFrame.Position = UDim2.fromScale(0, 0)
shopFrame.Size = UDim2.fromScale(1, 1)
shopFrame.Visible = true
shopFrame.Parent = panel.Content

openButton.Activated:Connect(function()
	panel:Toggle()
end)
```

Change the names in the two `WaitForChild` lines to match yours, then press **Play**. If your menu has its own close
button, make it call `panel:Close()` (find its script, or add `closeButton.Activated:Connect(function() panel:Close()
end)` above). Every setting (tilt, blur, glass colour...) is explained at the top of `ImmersiveUI.luau`.

---

## What's in the folder

| File | What it is |
|---|---|
| `SKILL.md` | The instructions Claude follows |
| `ImmersiveUI.luau` | The module that does the 3D, tilt, blur and animations |
| `examples/DailyShopDemo.client.luau` | A full Daily rewards + Shop menu to try it out (fake coins, nothing saved) |
| `examples/ShowcaseScene.server.luau` | A colourful scene + lighting so the blur looks great in a recording |

## Good to know

- The demo is a bright frosted-glass look. Change the colours in the `C` and `KIND` tables at the top of it.
- Flat screen GUIs always draw on top of the 3D panel, so hide the ones that overlap it while it's open (`HideGuis`,
  or `HideOtherGuis = true` to hide them all).
- Works with mouse, touch and controller. On small phones, try `Flat = true` if buttons feel tiny.
- No images to upload. Everything is drawn with Frames, so it works in any game.
