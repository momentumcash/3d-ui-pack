---
name: immersive-ui
description: Turn a Roblox game's menu into an "immersive" 3D glass menu - a real tilted panel floating in front of the camera that leans toward the mouse, with the world blurred behind it (like the Daily / Shop menus in top Roblox racing games). Works in Roblox Studio through the Roblox Studio MCP - installs the ImmersiveUI module, wraps one of the user's existing menus without deleting anything, play-tests and tunes it. Can also build a full Daily rewards + Shop demo when asked. Use when the user says "immersive ui", "make my menu immersive", "make my shop / daily / settings / inventory menu immersive", "3d menu", "tilting menu", "menu that follows the mouse", "glass menu", "blur the background behind my menu", "floating ui", or runs /immersive-ui.
---

# Immersive UI (Roblox)

You are going to make one of the user's Roblox menus feel like it floats in 3D: a glass panel in front of the
camera, tilting toward the mouse, the game world blurred behind it, smooth open / close / switch animations. You do
it through the **Roblox Studio MCP** tools. You never ask the user to paste code unless the MCP is missing.

Made by @momentumcash. MIT licence.

## Files in this skill folder

The folder is `${CLAUDE_SKILL_DIR}` (the folder this SKILL.md is in). If that variable is empty, it is
`~/.claude/skills/immersive-ui/` on macOS / Linux, `%USERPROFILE%\.claude\skills\immersive-ui\` on Windows, or a
project-level `.claude/skills/immersive-ui/`. Always read files from there.

| File | What it is |
|---|---|
| `ImmersiveUI.luau` | The engine. One ModuleScript, no dependencies. Goes to `ReplicatedStorage.ImmersiveUI`. **Its top comment is the source of truth for every option name and method signature. Read it before you write any code.** |
| `examples/DailyShopDemo.client.luau` | A full Daily rewards + Shop menu built on the module (LocalScript). Only when the user asks for the demo. |
| `examples/ShowcaseScene.server.luau` | Turns the baseplate into a sunny grass field + sets Lighting so the blur shows up in a recording (Script). Only on a fresh baseplate, only when asked. |
| `README.md` | For humans. You don't need it. |

## Hard rules (never break these)

1. **Never delete or overwrite the user's UI, scripts or modules.** Before you change anything of theirs, put a copy
   in `ServerStorage.ImmersiveUI_Backups` (a Folder; create it if missing), named `<OriginalName>_<YYYY-MM-DD>`.
   That includes an existing `ReplicatedStorage.ImmersiveUI` (Step 3 decides whether you may touch it at all).
2. **Keep an undo list.** Every object you create and every script you edit goes into a StringValue
   `ServerStorage.ImmersiveUI_Backups.UNDO` (one line each: what, where, how to undo). Tell the user it exists.
3. **Never publish, never save to Roblox.** If the place is a Team Create / cloud place, edits can autosave to Roblox
   by themselves (Step 1). For a test, the user saves a local copy with **File > Save to File**.
4. **Never touch DataStores** (no `DataStoreService`, no edits to scripts that use it). The demo's coins live only in
   the client and reset every play test, on purpose.
5. **One Studio window, one target.** Use the Studio that is already open. Pin its `studio_id` from
   `list_roblox_studios` and pass it on EVERY Studio tool call. Every `execute_luau` also gets an explicit
   `datamodel_type`: `"Edit"` for installs and edits, `"Server"` / `"Client"` only while a play test runs.
6. **Never stop the user's own play test.** Only stop a play test that you started. If Studio is already in Play when
   you begin, ask them to stop it and wait.
7. **Do not judge the panel with the MCP `screen_capture` tool.** It does NOT draw SurfaceGuis in PlayerGui, so the
   panel looks invisible in it even when it works. Capture the Studio window instead (Step 6).
8. **Small ask = small change.** Wrap ONE menu (the one they named). Offer the others at the end.
9. **The demo and the showcase scene are opt-in.** Install them only when the user asks, or after you've confirmed
   the game has no suitable menu AND they said yes. `ShowcaseScene` changes Lighting: fresh baseplates only.
10. No HTTP, no asset uploads, no plugins. Everything goes in through `execute_luau`.

## Step 1 - Check the Studio connection and the target place

Call `list_roblox_studios` (the Roblox Studio MCP tool; its full name may have a prefix like
`mcp__Roblox_Studio__list_roblox_studios`).

- **Tool doesn't exist / errors:** tell the user, then stop:
  "I can't see Roblox Studio. In Studio: open the **Assistant**, then **... > Manage MCP Servers > Quick connect >
  Claude Code**. Then restart Claude Code and ask again (or type `/immersive-ui`)."
- **No Studio open:** "Open your game in Roblox Studio, then ask me again." Stop.
- **Pick the target by its `name`** (place name or file). One match: use it. More than one, or only a blank
  `Place1` / Baseplate while they talked about a real game: ask which one before writing anything. Write the
  `studio_id` down and use it for every call.
- **Cloud / Team Create check:** if the entry says `persistedToCloud` (or has a `placeId`), say once: "This place is
  saved on Roblox. With Team Create on, my edits can autosave there. Want me to go ahead, or will you make a local
  copy first (File > Save to File)?" Wait for the answer.
- `get_studio_state` (with the `studio_id`). In Play and you didn't start it: rule 6.

## Step 2 - Find their menus

Run this with `execute_luau` (`datamodel_type = "Edit"`). It lists every ScreenGui in StarterGui with ALL its
GuiObjects that are big enough to be a menu, at any depth, with full paths:

```lua
local HttpService = game:GetService("HttpService")
local out = {}
local function px(u: UDim2) -- size on a 1920x1080 screen if the parent were the whole screen
	return { math.floor(u.X.Scale * 1920 + u.X.Offset), math.floor(u.Y.Scale * 1080 + u.Y.Offset) }
end
for _, gui in game:GetService("StarterGui"):GetChildren() do
	if gui:IsA("ScreenGui") then
		local g = { name = gui.Name, enabled = gui.Enabled, resetOnSpawn = gui.ResetOnSpawn, items = {} }
		for _, f in gui:GetDescendants() do
			if f:IsA("GuiObject") and not f:IsA("TextLabel") and not f:IsA("TextButton") then
				local s = px(f.Size)
				if (s[1] >= 250 and s[2] >= 180) or f.Size.X.Scale >= 0.3 then
					table.insert(g.items, { path = f:GetFullName(), class = f.ClassName, visible = f.Visible,
						size1080 = s, children = #f:GetChildren(),
						constraints = (f:FindFirstChildWhichIsA("UIAspectRatioConstraint") or f:FindFirstChildWhichIsA("UIScale")) and true or false })
				end
			end
		end
		table.insert(out, g)
	end
end
return HttpService:JSONEncode(out)
```

Then find the **controller** (the code that opens and closes it): `script_grep` / `script_search` for the frame name
and the ScreenGui name, and read those scripts with `script_read`. Note for the menu you pick:
- **How it opens**: `frame.Visible = true / not frame.Visible` ("Visible" menus) or `gui.Enabled = true`
  ("Enabled" menus). This decides `OPEN_PROP` in the bridge.
- **How other code finds it**: a reference grabbed once at start (`local shop = gui:WaitForChild("Main")`) is fine.
  Path lookups at click time (`PlayerGui.ShopGui.Main`, `script.Parent.Parent.Main` from a script OUTSIDE the
  frame, `frame.Parent.X` sibling lookups), or a `UIListLayout` / `UIGridLayout` in the ScreenGui that positions it,
  will break when the frame moves into the panel. Write these down.
- **Tweens on Position / Size / AnchorPoint** in its open / close code, and whether a tween's `Completed` does real
  work (sets Visible, enables input...).
- **Menus built at runtime** (scripts that do `Instance.new("ScreenGui")`) don't show in StarterGui. If the scan is
  empty or doesn't have the menu they named, grep for `Instance.new("ScreenGui")` / `Instance.new("Frame")`, or start
  a play test and scan `Players.<you>.PlayerGui` with `datamodel_type = "Client"`.

Pick the menu:
- They named one ("shop") → the closest match by name. Confirm the path in one line if it's not obvious.
- Ambiguous → one short question listing the candidates ("I found ShopGui.Main and SettingsGui.Frame. Which one?").
- Nothing found after the runtime check → say so and offer the demo (rule 9). Don't install it unasked.

## Step 3 - Install the module

1. **Checksum the local file first** (the number you'll compare against in Studio):

   macOS / Linux:
   ```bash
   python3 -c 'import sys,functools;s=open(sys.argv[1],"rb").read().replace(b"\r",b"");print(len(s),functools.reduce(lambda h,b:(h*31+b)%1000000007,s,0))' "${CLAUDE_SKILL_DIR}/ImmersiveUI.luau"
   ```
   Windows (PowerShell, no Python needed):
   ```powershell
   $b = [IO.File]::ReadAllBytes("$env:USERPROFILE\.claude\skills\immersive-ui\ImmersiveUI.luau") | Where-Object { $_ -ne 13 }; $h = [long]0; foreach ($x in $b) { $h = ($h * 31 + $x) % 1000000007 }; "$($b.Count) $h"
   ```
   You get `LEN SUM`. Keep both.

2. **Look at what's already there** (`datamodel_type = "Edit"`):
   ```lua
   local m = game:GetService("ReplicatedStorage"):FindFirstChild("ImmersiveUI")
   if not m then return "none" end
   if not m:IsA("ModuleScript") then return "other " .. m.ClassName end
   local s, h = m.Source:gsub("\r", ""), 0
   for i = 1, #s do h = (h * 31 + string.byte(s, i)) % 1000000007 end
   return (string.find(s, "made by @momentumcash", 1, true) and "ours " or "unknown ") .. #s .. " " .. h
   ```
   - `none` → install (step 3).
   - `ours LEN SUM` with the SAME numbers as step 1 → already installed. Skip to Step 4.
   - `ours` with different numbers → an older copy of this module. Ask: "You have an older ImmersiveUI. Update it?
     (backed up first)". Only on yes: install with `MODE = "upgrade"`.
   - `unknown` or `other` → something else with that name. **Stop and ask.** Never overwrite it. If they want to
     keep theirs, install ours as `ReplicatedStorage.ImmersiveUI_MC` instead and use that name in every `require`.

3. **Paste it in.** Read `ImmersiveUI.luau` with your Read tool. Pick a long-string level that doesn't appear in the
   file (start with `[====[` / `]====]`; if the file contains `]====]`, use 5 `=`, and so on). Under 100,000
   characters: ONE `execute_luau` call (`datamodel_type = "Edit"`). Never set `.Source` directly (Studio refuses over
   200,000 characters); `ScriptEditorService:UpdateSourceAsync` has no cap. Luau drops exactly one newline right after
   `[====[`, so start the file on the NEXT line; the file ends with a newline, so put `]====]` at the start of the line
   after its last line.

```lua
local SRC = [====[
<the whole ImmersiveUI.luau file, unchanged>
]====]
local EXPECT_LEN, EXPECT_SUM = 0, 0 -- the two numbers from step 1
local NAME = "ImmersiveUI"          -- or "ImmersiveUI_MC" (step 2)
local MODE = "new"                  -- "new" | "upgrade" (only after the user said yes)

local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local SES = game:GetService("ScriptEditorService")
local function sum(s: string): (number, number)
	local h = 0
	for i = 1, #s do h = (h * 31 + string.byte(s, i)) % 1000000007 end
	return #s, h
end

SRC = SRC:gsub("\r", "")
local len, h = sum(SRC)
if len ~= EXPECT_LEN or h ~= EXPECT_SUM then
	error(("paste mismatch: got %d %d, want %d %d. Nothing was changed."):format(len, h, EXPECT_LEN, EXPECT_SUM))
end
local mod = RS:FindFirstChild(NAME)
if mod and MODE ~= "upgrade" then
	error(NAME .. " already exists. Nothing was changed.")
end
local bk = SS:FindFirstChild("ImmersiveUI_Backups") or Instance.new("Folder")
bk.Name = "ImmersiveUI_Backups"
bk.Parent = SS
if mod then
	local c = mod:Clone()
	c.Name = NAME .. "_" .. os.date("%Y-%m-%d_%H%M%S")
	c.Parent = bk
else
	mod = Instance.new("ModuleScript")
	mod.Name = NAME
	mod.Parent = RS
end
SES:UpdateSourceAsync(mod, function() return SRC end)
local undo = bk:FindFirstChild("UNDO") or Instance.new("StringValue")
undo.Name = "UNDO"
undo.Value ..= ("\n%s: %s ReplicatedStorage.%s (undo: %s)"):format(os.date("%Y-%m-%d %H:%M"), MODE, NAME,
	if MODE == "upgrade" then "restore the newest backup in ImmersiveUI_Backups" else "delete it")
undo.Parent = bk
local l2, h2 = sum(mod.Source:gsub("\r", ""))
return ("ok %d %d"):format(l2, h2)
```

   The returned numbers must equal step 1's. If the call errors with "paste mismatch", nothing changed: paste again.

**Chunked route (only for a file over 100,000 characters; both shipped files are well under).** Split the file at line
ends into parts of at most 90,000 characters (whole lines, so no UTF-8 character is ever cut). Use a fresh staging
folder name, e.g. `ImmersiveUI_Upload_<random 6 letters>`. One call per part:

```lua
local SS = game:GetService("ServerStorage")
local up = SS:FindFirstChild("ImmersiveUI_Upload_abcdef") or Instance.new("Folder")
up.Name = "ImmersiveUI_Upload_abcdef"
up.Parent = SS
local v = Instance.new("StringValue")
v.Name = string.format("Part%03d", 1) -- 1, 2, 3 ...
v.Value = [====[
<part text>]====]
v.Parent = up
return #v.Value
```

(The newline after `[====[` is the one Luau drops, so a part that itself starts with a newline keeps it. Put
`]====]` directly after the part's last character.) Then one final call: check the folder has exactly the part count
you sent, join the values in name order, run the same `EXPECT_LEN / EXPECT_SUM` check, then the backup +
`UpdateSourceAsync` + read-back from step 3, then `up:Destroy()`. On any mismatch, destroy the folder and start over
with a new name.

## Step 4 - Read the API before writing code

Read the top comment of `ImmersiveUI.luau`. The short version (if anything here disagrees with the file, the file
wins):

```lua
local ImmersiveUI = require(game:GetService("ReplicatedStorage"):WaitForChild("ImmersiveUI"))
local panel = ImmersiveUI.new({ Name = "Shop", DesignSize = Vector2.new(1100, 720), ScreenHeight = 0.72 })
panel.Content                      -- a Frame of DesignSize pixels: parent your menu into it
panel.Gui                          -- the main SurfaceGui (or ScreenGui in Flat mode)
panel:Open()  panel:Close(instant?)  panel:Toggle()
panel.IsOpen                       -- true from Open() until Close() starts
panel.ModalActive                  -- true from Open() until the close has fully finished
panel:SetContent(frame)            -- swap pages with the ref's beat (old page out, empty pane, new page in).
                                   -- Returns the old page; it stays in Content with Visible = false.
panel:AddLayer(depthStuds, name?)  -- a Frame on a parallel plane IN FRONT of the glass (negative = behind), same
                                   -- canvas coords. Things on it slide against the glass as it tilts (parallax).
panel:AddGlint(frame)              -- the moving tilt sheen on your own sheet (when Pane = false)
panel.Opened:Connect(fn)           -- fires when Open() STARTS
panel.Closed:Connect(fn)           -- fires when Close() STARTS (or the panel is replaced / destroyed while open)
panel:OnModalChanged(fn)           -- fn(true) on open, fn(false) when the close has FULLY finished
panel:Shine(guiObject)             -- diagonal light sweep (waits for the open animation by itself)
panel:ScreenToCanvas(input.Position, allowOutside?, target?) -- returns (point, canvasFrame) in the same space as
                                   -- AbsolutePosition on that canvas, or nil off the panel. Sliders: target = track.
panel:Configure({ Blur = 10 })     -- change options live
panel:Destroy()
ImmersiveUI.Glass(parent, props)   -- a glass Frame (Color, Transparency, Dark, Border, Corner, Gradient, ...)
ImmersiveUI.Active()               -- the open panel, if any
ImmersiveUI.CanvasFolder()         -- workspace.ImmersiveUILocal: add it to raycast Exclude lists
```

`Players.LocalPlayer:GetAttribute("ImmersiveUIOpen")` is true while a panel is open.

**One open panel per player.** Opening a second panel closes the first instantly. Menus that switch between each
other (Daily <-> Shop) share one panel and use `SetContent`.

## Step 5A - Wrap their menu

Two routes. Pick one from what you found in Step 2.

**Route 1: edit their controller (preferred when it is ONE LocalScript with clear open / close code).** Back up the
script (rule 1), then in that same script: `require` the module, create the panel once, and right after the script
gets its reference to the menu frame, move it in (`frame.AnchorPoint = Vector2.zero; frame.Position =
UDim2.new(); frame.Size = UDim2.fromScale(1, 1); frame.Parent = panel.Content`). At each place it shows the menu,
add `panel:Open()`; where it hides it, add `panel:Close()`. Keep their own Visible lines. Because their script holds
the reference, nothing else needs paths. Also fix any click-time path lookups you noted (`PlayerGui.ShopGui.Main` →
the saved reference). Add one UNDO line per edited script.

**Route 2: the bridge (when the controller is spread across scripts or unclear).** A separate LocalScript that,
while the game runs, moves the menu's Frame from the player's own copy of the ScreenGui into the panel and follows
their open / close. StarterGui is never changed. Use it only if Step 2 found no click-time path lookups or layout
parents for that frame (or you fixed them, backed up, with UNDO lines).

Both routes:
1. **Numbers.** `DesignSize` = the frame's `size1080`. Under 700 px tall: scale both by one factor to ~700-800 tall
   (sharper text). `ScreenHeight` = its 1080p height / 1080, clamped 0.55-0.85.
2. **Tweens on Position / Size / AnchorPoint** in their open / close code now fight the panel's animation. Back up,
   then comment those tween lines out with a `-- [immersive-ui]` prefix. If a tween's `Completed` does real work
   (`Visible = false`, re-enabling input), keep that work and run it straight away instead. Note each edit in UNDO.
3. **Other HUD.** Flat ScreenGuis always draw ON TOP of the 3D panel. The module can hide every other ScreenGui
   (`HideOtherGuis`), but for a real game set **`HideOtherGuis = false`** and hide only the ones you inspected that
   overlap the panel or catch clicks (full-screen backdrops, side buttons) via `HideGuis`. Their own close button,
   timers and anything outside the panel's area stay.

Bridge template (Route 2). Create a LocalScript `ImmersiveUI_<FrameName>` in `StarterPlayer.StarterPlayerScripts`
with the Step 3 paste method (`datamodel_type = "Edit"`), add an UNDO line, and fill in the CAPS values:

```lua
-- ImmersiveUI bridge (made by the immersive-ui skill, @momentumcash). Moves <GUI_NAME>.<FRAME_NAME> into a
-- 3D glass panel while the game runs. StarterGui is untouched. Delete this script to undo.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local ImmersiveUI = require(RS:WaitForChild("ImmersiveUI"))

local GUI_NAME = "ShopGui"            -- their ScreenGui (direct child of PlayerGui)
local FRAME_PATH = { "Main" }         -- path from that ScreenGui to the menu frame, e.g. { "Holder", "Main" }
local OPEN_PROP = "Visible"           -- "Visible": their code shows the frame. "Enabled": their code enables the gui.
local HIDE = {}                       -- ScreenGuis you inspected that cover the panel or catch clicks (names)

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

local panel = ImmersiveUI.new({
	Name = GUI_NAME,
	DesignSize = Vector2.new(1100, 720),
	ScreenHeight = 0.72,
	Blur = 18,
	HideOtherGuis = false, -- a real game: hide only what you inspected
	HideGuis = function()  -- looked up on every open, so respawned copies are found too
		local list = {}
		for _, name in HIDE do
			local g = pg:FindFirstChild(name)
			if g and g:IsA("LayerCollector") then table.insert(list, g) end
		end
		return list
	end,
})

type Bound = { gui: ScreenGui, frame: GuiObject, conns: { RBXScriptConnection }, saved: { any } }
local bound: Bound? = nil
local pending: boolean? = nil   -- a value WE just wrote, so its (maybe deferred) Changed event is ignored once

local function target(): Instance?
	if not bound then return nil end
	return if OPEN_PROP == "Enabled" then bound.gui else bound.frame
end

local function writeOurs(v: boolean)
	local t: any = target()
	if t and t[OPEN_PROP] ~= v then
		pending = v
		t[OPEN_PROP] = v
	end
end

local function onTheirChange()
	local t = target()
	if not t then return end
	local v = (t :: any)[OPEN_PROP] == true
	local mine = pending
	pending = nil
	if mine ~= nil and v == mine then return end -- our own write coming back
	if v then
		panel:Open()
	elseif panel.IsOpen then
		if OPEN_PROP == "Visible" then writeOurs(true) end -- keep it drawn while the glass fades out
		panel:Close()
	end
end

-- The close has fully finished (their close, a click outside, a respawn): make their state say "closed" too,
-- so their own open button works next time.
panel:OnModalChanged(function(isOpen: boolean)
	if isOpen then return end
	writeOurs(false)
end)

local function findFrame(gui: ScreenGui): GuiObject?
	local node: Instance? = gui
	for _, name in FRAME_PATH do
		node = node and node:WaitForChild(name, 10)
	end
	return if node and node:IsA("GuiObject") then node else nil
end

local function release(b: Bound)
	for _, c in b.conns do c:Disconnect() end
	if panel.ModalActive then panel:Close(true) end
	-- put the frame back exactly where it was; if that gui is gone for good, the frame goes with it
	local f = b.frame
	f.AnchorPoint, f.Position, f.Size = b.saved[2], b.saved[3], b.saved[4]
	local ok = pcall(function() f.Parent = b.saved[1] end)
	if not ok or not b.gui:IsDescendantOf(game) then f:Destroy() end
end

local function bind(gui: ScreenGui)
	if bound and bound.gui:IsDescendantOf(pg) then
		if bound.gui ~= gui then
			warn("[ImmersiveUI] two ScreenGuis named " .. GUI_NAME .. "; keeping the first")
		end
		return
	end
	if bound then
		release(bound)
		bound = nil
	end
	local f = findFrame(gui)
	if not f then
		warn("[ImmersiveUI] " .. GUI_NAME .. "." .. table.concat(FRAME_PATH, ".") .. " not found")
		return
	end
	local b: Bound = { gui = gui, frame = f, conns = {}, saved = { f.Parent, f.AnchorPoint, f.Position, f.Size } }
	bound = b
	f.AnchorPoint = Vector2.zero
	f.Position = UDim2.fromScale(0, 0)
	f.Size = UDim2.fromScale(1, 1)
	f.Parent = panel.Content
	local watched: Instance = if OPEN_PROP == "Enabled" then gui else f
	table.insert(b.conns, watched:GetPropertyChangedSignal(OPEN_PROP):Connect(onTheirChange))
	-- their gui leaves PlayerGui (ResetOnSpawn respawn, or their code removes it): give the frame back
	table.insert(b.conns, gui.AncestryChanged:Connect(function()
		if bound == b and not gui:IsDescendantOf(pg) then
			release(b)
			bound = nil
		end
	end))
	pending = nil
	onTheirChange() -- start in whatever state their gui is in
end

for _, child in pg:GetChildren() do
	if child.Name == GUI_NAME and child:IsA("ScreenGui") then task.spawn(bind, child) end
end
pg.ChildAdded:Connect(function(child)
	if child.Name == GUI_NAME and child:IsA("ScreenGui") then bind(child) end
end)

-- Studio test hook (use the REAL open button first): Players.<you>:SetAttribute("ImmersiveUIDebugOpen", true/false)
-- writes their OPEN_PROP the way their own code would.
player:GetAttributeChangedSignal("ImmersiveUIDebugOpen"):Connect(function()
	local t = target()
	if t then (t :: any)[OPEN_PROP] = player:GetAttribute("ImmersiveUIDebugOpen") == true end
end)
```

Notes:
- `OPEN_PROP` comes from reading their controller (Step 2), never from a guess.
- The module draws a glass pane behind `Content` (`Pane = true`). A menu with a solid background just covers it. For
  the see-through look, set the frame's `BackgroundTransparency` to 0.35-0.45 in the bridge (not in StarterGui).
- Sliders / drags doing maths with `InputObject.Position` vs `AbsolutePosition` break in 3D. Fix them with
  `panel:ScreenToCanvas(input.Position, false, sliderTrack)` (same space as the track's `AbsolutePosition`).
  `ImmersiveUI.Active()` gives their script the panel. Back up first, UNDO line.

## Step 5B - The demo (only when asked, rule 9)

Read `examples/DailyShopDemo.client.luau` and create a LocalScript `DailyShopDemo` in
`StarterPlayer.StarterPlayerScripts` (Step 3 paste method, `datamodel_type = "Edit"`, UNDO line). It needs only
`ReplicatedStorage.ImmersiveUI`. It builds left-side DAILY / SHOP / EMOTES buttons, a coin pill, and one clear frosted
glass panel with a Daily page (7 day cards, CLAIM DAY 1, 3 missions) and a Shop page (5 pill tabs, 6 items each,
BUY / EQUIP). The title pill, close button, coin pill and CLAIM float on a front layer (`panel:AddLayer(0.6)`), with
their shadows on the glass, so they slide as it tilts. All numbers are fake demo data, not saved. Deleting the
script tears everything down. Their colours: change only the `C` and `KIND` tables at the top.

For a recording on a fresh baseplate (and only if asked): also put `examples/ShowcaseScene.server.luau` in
`ServerScriptService` as a Script. It fills Terrain with grass (hides the Baseplate, which stays solid)
and sets Lighting, so the blur has some colour to show. No props or models.

Open it without clicking (screenshots): `Players.<you>:SetAttribute("ImmersiveDemoOpen", "Daily")` (or `"Shop"`, or
`""` to close).

## Step 6 - Play-test and look at it

1. If Studio is in Edit: `start_stop_play` (`is_start = true`) and remember YOU started it. Wait ~3 s.
   `get_console_output`: any red error from `ImmersiveUI`, the bridge or the demo → stop your test, fix in Edit, retry.
2. **Open the menu with their real opener**: click their open button with `user_mouse_input` using `instance_path`
   (e.g. `LocalPlayer.PlayerGui.SideButtons.Shop`; x/y clicks go to the game, not the GUI), or press their key with
   `user_keyboard_input`. Only if that's impossible, use the debug hook (`execute_luau`, `datamodel_type = "Server"`):
   `game.Players:GetPlayers()[1]:SetAttribute("ImmersiveUIDebugOpen", true)` (demo: `ImmersiveDemoOpen = "Daily"`).
3. Lean it for the shot: `game.Players:GetPlayers()[1]:SetAttribute("ImmersiveDebugPointer", Vector2.new(0.8, -0.8))`
   (x right, y DOWN, each -1..1, so (0.8, -0.8) is top-right; Studio only). Clear it after with `nil`.
4. **Screenshot the Studio window** (NOT `screen_capture`, rule 7). Give it 1 s after opening.
   - **macOS:** get the Studio window id with this Swift snippet (write it to a temp file, run `swift <file>`; needs
     Xcode Command Line Tools: `xcode-select --install`), then capture that window:

     ```swift
     import CoreGraphics
     let l = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as! [[String: Any]]
     var best = 0; var area = 0.0
     for w in l { if let o = w["kCGWindowOwnerName"] as? String, o.contains("Roblox"), (w["kCGWindowLayer"] as? Int) == 0, let b = w["kCGWindowBounds"] as? [String: Double] { let a = b["Width"]! * b["Height"]!; if a > area { area = a; best = w["kCGWindowNumber"] as! Int } } }
     print(best)
     ```

     ```bash
     screencapture -x -o -l <id> -t jpg /tmp/immersive_open.jpg
     ```

     Look at the image with your Read tool. The first time, macOS may ask to allow Screen Recording for their
     terminal app (System Settings > Privacy & Security > Screen Recording). No Swift? Bring Studio to the front
     (`osascript -e 'tell application "RobloxStudio" to activate'`), wait 1 s, `screencapture -x /tmp/immersive_open.jpg`.
   - **Windows:** you can't capture the window yourself. Ask: "Press Win+Shift+S, snip the Studio window with the
     menu open, and paste it here." If no picture comes, say the visual check is **pending** (don't claim it passed).
5. Check in the picture: panel visible and crisp, world blurred, tilted toward the pointer side (that side looks
   bigger), nothing cut off, text readable, nothing flat drawn over the panel.
6. Click one or two real buttons inside the menu (`user_mouse_input` + `instance_path`) and check they still do their
   job. Close it the normal way (their X or key). Open it again once (the second open must work too).

## Step 7 - Tune, then stop

Stop YOUR play test, change the numbers (bridge / controller / demo `ImmersiveUI.new{}`), play again, look again.
Max 3 rounds unless the user asks for more. Then stop your test and tell the user in a few short lines: what you
changed, where the backups and the UNDO list are, how to undo (delete the bridge / restore the backed-up scripts), and
how to keep it: **File > Save to File** for a local copy (on a Team Create place their edits may already be saved
to Roblox). Offer to do their other menus.

### Tuning knobs (options in `ImmersiveUI.new{}`, or live with `panel:Configure{}`)

| Option | Default | What it does | Turn it when |
|---|---|---|---|
| `DesignSize` | 1100 x 720 | The panel's own pixel size; the menu is laid out in these px | Menu squished: match the menu's aspect. Text soft: bigger |
| `ScreenHeight` | 0.72 | Panel height, fraction of the free screen height | Too big / small. Phones: up to 0.9 |
| `MaxScreenWidth` | 0.92 | Width cap (narrow / portrait screens) | Sides cut off on phones |
| `Distance` | 4 | Studs in front of the camera (looks the same at any distance) | Clicks fail with the camera pressed into a wall: 2-3 |
| `Tilt` | (6, 4.5) | Max lean in degrees (left-right, up-down) | Calmer: (4, 3). Showcase: (7, 5). No motion: `Vector2.zero` |
| `TiltSmoothing` | 9 | How fast it follows the mouse (higher = snappier) | Laggy: 12. Floaty clip look: 6 |
| `Idle` | true | Gentle sway when there's no mouse (touch, gamepad) | Turn off if it bothers them |
| `Blur` | 18 | World blur strength (0 = off) | Too blurry: 10-12. Showcase: 24 |
| `Tint` | nil | Colour wash on the world while open | Cool daylight: `Color3.fromRGB(225, 240, 255)` |
| `HideOtherGuis` | true | Hides EVERY other ScreenGui while open (flat GUIs draw over the 3D panel) | Real games: **false**, then list blockers in `HideGuis` |
| `HideGuis` | {} | ScreenGuis (or a function returning them) hidden while open (keep rules still apply) | A backdrop or side buttons cover the panel |
| `KeepGuis` | {} | Never hidden (instances or names). Or attribute `ImmersiveKeep = true` on the gui | A timer that must stay (keep it off the panel's area) |
| `HideTouchControls` | true | Hides the Roblox thumbstick + jump while open | Never, usually |
| `BlockInput` | true | Clicks / taps that miss the panel never reach the game while open | Their game needs those clicks |
| `Shadow` | true | Soft shadow behind the glass | Muddy on a dark game: false |
| `Glint` | true | A sheen on the glass that moves with the tilt | Too shiny: false |
| `Pane` | true | The module draws the glass pane behind Content | Their menu has its own full background: false (+ `panel:AddGlint`) |
| `PaneColor` / `PaneTransparency` / `PaneGradient` / `PaneBorderColor` / `PaneCorner` | navy, 0.42, light falloff, pale blue, 6 | The glass's look | Match their game; clear glass: `PaneTransparency = 0.55` |
| `PaneInsetTop` | 0 | Empty canvas above the pane (canvas px) | A title tab that sticks out above the panel |
| `CloseOnClickOutside` | true | Click / tap off the panel closes it | Their game needs clicks outside |
| `CloseOnRespawn` | true | Closes when the character resets | Menu should stay open through a respawn |
| `RenderPriority` | Camera + 1 | When the panel updates each frame | Shakes / lags behind a custom camera: `Enum.RenderPriority.Camera.Value + 51` |
| `ManageMouse` | true | Frees and shows the mouse while open | Their game already handles the cursor in menus: false |
| `ManageEffects` | true | Module makes its own blur / tint | Game already blurs for menus: false |
| `CanvasScale` | "auto" | Renders the canvas up to 2x for sharp text | Phones lagging: 1 |
| `FadeContent` | true | Fades content during open / close / swap | Content soft while animating, old phones: false |
| `TopInset` | top bar height | Screen px kept free at the top | Game hides the Roblox top bar |
| `DisplayOrder` | 50 | Draw order of the Flat-mode ScreenGui | Another GUI covers it in Flat mode |
| `Flat` | false | Same menu as a normal flat GUI (no 3D) | Phones where buttons get too small, old devices |

### Common problems

- **The game's HUD draws on top of the panel** → Roblox draws flat ScreenGuis over 3D SurfaceGuis, whatever their
  DisplayOrder. Hide the ones that overlap the panel with `HideGuis` (or `HideOtherGuis = true`, which hides all).
  If their own script turns a gui OFF while the panel is open, Roblox can't tell the module, so it may come back on at
  close: re-apply their state when `ImmersiveUIOpen` goes false, or put it in `KeepGuis` and let them handle it.
- **Panel invisible in my screenshot** → you used the MCP `screen_capture`; it hides PlayerGui SurfaceGuis. Capture
  the Studio window (Step 6). Still invisible: check the console; while open the canvas parts are in
  `workspace.ImmersiveUILocal`, and `PlayerGui.ImmersiveUI_<Name>` has `Adornee` set and `Enabled = true`. A cleanup
  script deleting unknown parts in workspace can remove the parts.
- **Panel invisible for players but fine in Studio** → the module isn't in ReplicatedStorage, or the bridge / demo
  is a Script in ServerScriptService instead of a LocalScript in StarterPlayerScripts.
- **Buttons don't click** → (a) a full-screen ScreenGui (backdrop, loading screen, invisible click-catcher with
  `Active = true`) sits on top: screen GUIs win over 3D GUIs; add it to `HideGuis`. Their kept source ScreenGui can do
  this too if it has a full-screen sibling of the menu frame. (b) The SurfaceGui must stay in PlayerGui. (c) A wall
  right in front of the camera: lower `Distance`. (d) Use `.Activated` (mouse + touch). (e) Rare: in Studio set
  `Players.<you>:SetAttribute("ImmersiveDebugCanQuery", false)` to test the canvas CanQuery, then set `CanQuery`.
- **Mouse locked in the middle / cursor hidden** → their camera (shift-lock, first person, custom) forces
  `MouseBehavior` every frame. Keep `ManageMouse = true` and raise `RenderPriority` above their camera script, or make
  it skip while `Players.LocalPlayer:GetAttribute("ImmersiveUIOpen")` is true (or use `panel:OnModalChanged`).
- **Double blur / too blurry** → the game has its own menu `BlurEffect`. `ManageEffects = false` or lower `Blur`.
  Never edit their effects.
- **Text blurry or soft** → `DesignSize` is too small for the panel's size on screen. Raise it (keep the aspect); scale
  their offset-sized children with a `UIScale` inside the frame, or use `TextScaled`.
- **Menu tiny / huge inside the panel** → their script sets a `UIScale` from the screen size, or a `UISizeConstraint`.
  Inside the panel, sizes are panel pixels. Remove that scaling for the panel (back up first) or fix DesignSize.
- **Menu slides around inside the panel** → their open / close tweens on Position / Size (Step 5A, both routes, 2).
- **Opens then instantly closes** → wrong `OPEN_PROP`, their code toggles twice per click, or a "click outside"
  catcher gets the same click. Check with prints, don't guess.
- **Their script errors after the move** (`Main is not a valid member of ShopGui`) → a click-time path lookup you
  missed. Use Route 1, or fix the lookup to a saved reference (back up, UNDO line).
- **Sliders jump to the wrong value** → `panel:ScreenToCanvas(input.Position, false, track)` vs the track's
  `AbsolutePosition` / `AbsoluteSize`.
- **Menu closes when I click inside it** → part of the menu hangs outside the canvas (a dropdown). Grow `DesignSize`
  or `CloseOnClickOutside = false`.
- **After respawn the menu is doubled or gone** → their ScreenGui has `ResetOnSpawn = true`; the bridge gives the frame
  back with the old gui and binds the new copy. If it still breaks, Route 1 is usually cleaner. Don't change their
  `ResetOnSpawn` unless they agree.
- **Two menus fight** → one panel per player. Use `SetContent` to switch pages.
- **Buttons too small on phones** → test in Studio's device emulator (phone landscape); raise `ScreenHeight` to
  0.85-0.9 or `Flat = true` on touch devices (`UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled`).
