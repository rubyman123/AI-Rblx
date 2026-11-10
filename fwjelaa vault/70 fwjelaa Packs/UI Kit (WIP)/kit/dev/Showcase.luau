--!strict
-- Builds the demo screens for the UI/UX showcase place: every theme × HUD, Menus, Loading, MainMenu, Feedback.
-- Each is a ScreenGui named SC_<Theme>_<Screen> in StarterGui, built disabled; show() enables exactly one.
-- Rebuilding replaces only kit-built screens and refuses to overwrite a hand-made ScreenGui with the same name.

local StarterGui = game:GetService("StarterGui")

local Showcase = {}

Showcase.SCREENS = { "HUD", "Menus", "Loading", "MainMenu", "Feedback" }

-- Rows are pixel-tall (52) inside a scrolling list so a phone keeps 44-px controls and simply scrolls
local SETTINGS_ROW_HEIGHT = 52
local TAB_HEIGHT = 44

-- Showcase icon keys → icon registry names (kit/Icons.luau resolves them to uploaded art or emoji), or plain glyphs
-- for actions the registry doesn't cover
local ICONS: { [string]: string } = {
	cash = "cash", gem = "gem", shop = "shop", pets = "egg", upgrade = "upgrade", rebirth = "rebirth", gift = "gift",
	star = "star", muscle = "dumbbell", crown = "crown", clover = "clover", sword = "sword", shield = "shield",
	fist = "👊", dash = "💨", jump = "⏫", skull = "skull", bolt = "bolt", book = "book", bag = "backpack",
	potion = "potion", settings = "gear", film = "video", trophy = "trophy", scroll = "scroll", key = "key",
	pass = "pass", coin = "coin",
}

local RAINBOW = {
	Color3.fromHex("FF4A4A"), Color3.fromHex("FFA53A"), Color3.fromHex("FFE23A"), Color3.fromHex("4AE05A"),
	Color3.fromHex("3AA8FF"), Color3.fromHex("B05AFF"),
}

-- Copy per theme so each style reads like a real game (original names, no other game's content)
local COPY: { [string]: { [string]: any } } = {
	StudSimulator = {
		game = "Lift a Rock", tagline = "Get strong. Lift bigger rocks.", tip = "Tip: rebirth to lift heavier rocks!",
		moves = { "Lift", "Throw", "Flex", "Smash" },
	},
	Battlegrounds = {
		game = "BATTLEGROUNDS", tagline = "Last one standing wins.", tip = "Tip: dash-cancel your combo with Q",
		moves = { "Rapid Blows", "Flare Burst", "Shock Shot", "Sky Dive" },
	},
	KineticComic = {
		game = "PHANTOM RUSH", tagline = "Steal the show. Leave a calling card.", tip = "The deadline is in 3 days",
		moves = { "Slash", "Pistol", "Summon", "All-Out" },
	},
	CyberHolo = {
		game = "NEON//PROTOCOL", tagline = "SYS.BOOT > ALL SYSTEMS NOMINAL", tip = "SYS: overclock drains energy 2x faster",
		moves = { "Pulse", "Phase", "Overclock", "EMP" },
	},
	MangaInk = {
		game = "INK BLADE", tagline = "Chapter 1: The Brush That Cuts", tip = "Hold the brush stroke to charge",
		moves = { "Ink Slash", "Splash", "Brush Dash", "Final Panel" },
	},
	DarkFantasy = {
		game = "ASHEN CROWN", tagline = "The flame remembers those who kneel.", tip = "Rest at a shrine to restore your blood",
		moves = { "Rend", "Blood Ward", "Ember Step", "Crimson Rite" },
	},
}

local function icon(key: string): string
	return ICONS[key] or key
end

local function group(UIKit: any, parent: Instance, name: string, props: { [string]: any }, direction: Enum.FillDirection?): Frame
	local frame = UIKit.Util.make("Frame", {
		Name = name, BackgroundTransparency = 1, Position = props.Position, Size = props.Size,
		AnchorPoint = props.AnchorPoint or Vector2.zero, ZIndex = 2, Parent = parent,
	})
	if direction then
		UIKit.Util.make("UIListLayout", {
			FillDirection = direction, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Parent = frame,
		})
	end
	return frame
end

-- Laid out like a top simulator HUD at 1080p (reference: roblox-ai visual-refs/studs-ui/Stud-GUI-2): menu tiles
-- on the left, bare cash bottom-left, stats + level bar + offer tiles bottom-centre, auto-offer top-centre, offers right.
-- Sizes follow the reference: menu tiles ~8% of screen height, level bar 42% wide.
local function hudSimulator(UIKit: any, theme: any, gui: ScreenGui)
	local Util = UIKit.Util

	local menu = group(UIKit, gui, "LeftButtons", { Position = UDim2.fromScale(0.008, 0.38), Size = UDim2.fromScale(0.3, 0.31) })
	Util.aspect(menu, 0.6)
	UIKit.Button(theme, {
		Name = "Shop", Text = "Shop", Icon = icon("shop"), Variant = "primary", Size = UDim2.fromScale(1, 0.17), Parent = menu,
	})
	local tiles = Util.make("Frame", {
		Name = "Tiles", BackgroundTransparency = 1, Position = UDim2.fromScale(0, 0.195), Size = UDim2.fromScale(1, 0.805), Parent = menu,
	})
	Util.make("UIGridLayout", {
		CellSize = UDim2.fromScale(0.485, 0.32), CellPadding = UDim2.fromScale(0.03, 0.02), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tiles,
	})
	for i, b in { { "Pets", "pets" }, { "Rebirth", "rebirth" }, { "Inventory", "bag" }, { "Gifts", "gift" }, { "Quests", "scroll" }, { "Index", "book" } } do
		UIKit.IconButton(theme, {
			Name = b[1], Icon = icon(b[2]), Caption = b[1], Variant = "tile", Badge = if i == 3 then "!" else nil, LayoutOrder = i, Parent = tiles,
		})
	end

	local wallet = Util.make("Frame", {
		Name = "Wallet", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0.01, 0.975),
		Size = UDim2.fromScale(0.25, 0.2), Parent = gui,
	})
	Util.make("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = wallet })
	UIKit.Currency(theme, { Name = "Gems", Icon = icon("gem"), Amount = "12", Kind = "energy", Size = UDim2.fromScale(1, 0.33), LayoutOrder = 1, Parent = wallet })
	UIKit.Currency(theme, { Name = "Cash", Icon = icon("cash"), Amount = "$539.66K", Kind = "accent", Size = UDim2.fromScale(1, 0.4), LayoutOrder = 2, Parent = wallet })
	-- Util.text takes no LayoutOrder, so set it after; without it the label sorts first in the wallet list
	Util.text(theme, {
		Name = "FriendBoost", Text = "Friend Boost +0%", XAlign = Enum.TextXAlignment.Left, Size = UDim2.fromScale(0.7, 0.18), Parent = wallet,
	}).LayoutOrder = 3

	UIKit.Currency(theme, {
		Name = "Strength", Icon = icon("bolt"), Amount = "43.2B Strength", Kind = "xp", Aspect = 7, Size = UDim2.fromScale(0.25, 0.05),
		Position = UDim2.fromScale(0.29, 0.785), AnchorPoint = Vector2.new(0, 0.5), Parent = gui,
	})
	local multiplier = Util.text(theme, {
		Name = "Multiplier", Text = "x174.5 Multiplier", Role = "display", Stroke = theme.textStroke.display, XAlign = Enum.TextXAlignment.Right,
		Size = UDim2.fromScale(0.18, 0.045), Position = UDim2.fromScale(0.71, 0.785), AnchorPoint = Vector2.new(1, 0.5), Parent = gui,
	})
	Util.gradient(multiplier, theme.color.bars.xp, 90)
	UIKit.Bar(theme, {
		Name = "LevelBar", Style = "single", Kind = "xp", Value = 0.62, Label = "Level 309", ValueText = "62%",
		Size = UDim2.fromScale(0.42, 0.075), Position = UDim2.fromScale(0.5, 0.86), AnchorPoint = Vector2.new(0.5, 0.5), Parent = gui,
	})
	local offers = group(UIKit, gui, "Offers", {
		Position = UDim2.fromScale(0.5, 0.985), AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromScale(0.42, 0.085),
	}, Enum.FillDirection.Horizontal)
	UIKit.Offer(theme, { Name = "Boost10B", Title = "+10B", Icon = icon("bolt"), Price = "55", Variant = "primary", Size = UDim2.fromScale(0.32, 1), LayoutOrder = 1, Parent = offers })
	UIKit.Offer(theme, { Name = "Boost100B", Title = "+100B", Icon = icon("bolt"), Price = "215", Variant = "danger", Size = UDim2.fromScale(0.32, 1), LayoutOrder = 2, Parent = offers })
	local rainbow = UIKit.Offer(theme, { Name = "Boost1T", Title = "+1T", Icon = icon("bolt"), Price = "425", Variant = "success", Size = UDim2.fromScale(0.32, 1), LayoutOrder = 3, Parent = offers })
	local rainbowFill = rainbow:FindFirstChildOfClass("UIGradient")
	if rainbowFill then
		rainbowFill.Color = Util.sequence(RAINBOW)
		rainbowFill.Rotation = 0
	end

	-- banner offers: the icon peeks above the top edge, so the row starts a little way down
	local top = group(UIKit, gui, "TopOffers", {
		Position = UDim2.fromScale(0.5, 0.045), AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromScale(0.25, 0.075),
	}, Enum.FillDirection.Horizontal)
	UIKit.Offer(theme, {
		Name = "AutoLift", Title = "AUTO LIFT", Icon = icon("trophy"), Price = "30", PricePrefix = "ONLY", Layout = "banner",
		Variant = "danger", Size = UDim2.fromScale(0.54, 1), LayoutOrder = 1, Parent = top,
	})
	UIKit.Offer(theme, {
		Name = "Luck", Title = "x2 LUCK", Icon = icon("clover"), Price = "49", PricePrefix = "ONLY", Layout = "banner",
		Variant = "secondary", Size = UDim2.fromScale(0.43, 1), LayoutOrder = 2, Parent = top,
	})
	local notice = Util.text(theme, {
		Name = "Notice", Text = "Offline earnings collected!", Role = "display", Stroke = theme.textStroke.display,
		Size = UDim2.fromScale(0.3, 0.045), Position = UDim2.fromScale(0.5, 0.135), AnchorPoint = Vector2.new(0.5, 0), Parent = gui,
	})
	Util.gradient(notice, theme.color.bars.accent, 90)

	UIKit.IconButton(theme, {
		Name = "FreeGift", Icon = icon("gift"), Caption = "Free", Size = UDim2.fromScale(0.08, 0.1),
		Position = UDim2.fromScale(0.985, 0.25), AnchorPoint = Vector2.new(1, 0), Parent = gui,
	})
	local right = group(UIKit, gui, "RightOffers", {
		Position = UDim2.fromScale(0.992, 0.45), AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromScale(0.1, 0.2),
	}, Enum.FillDirection.Vertical)
	UIKit.Offer(theme, {
		Name = "Skill", Title = "+25x SKILL", Icon = icon("bolt"), Price = "6", PricePrefix = "ONLY", Layout = "banner",
		Variant = "success", Size = UDim2.fromScale(1, 0.42), LayoutOrder = 1, Parent = right,
	})
	UIKit.Offer(theme, {
		Name = "Wins", Title = "2x WINS", Icon = icon("trophy"), Price = "69", PricePrefix = "ONLY", Layout = "banner",
		Variant = "primary", Size = UDim2.fromScale(1, 0.42), LayoutOrder = 2, Parent = right,
	})
end

local function hudCombat(UIKit: any, theme: any, gui: ScreenGui, copy: { [string]: any })
	local card = group(UIKit, gui, "PlayerCard", { Position = UDim2.fromScale(0.01, 0.03), Size = UDim2.fromScale(0.24, 0.1) })
	UIKit.Util.icon(theme, icon("skull"), { Name = "Portrait", Size = UDim2.fromScale(1, 1), Parent = card })
	UIKit.Util.text(theme, {
		Name = "PlayerName", Text = "Player1", Role = "display", XAlign = Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(0.68, 0.45), Position = UDim2.fromScale(0.3, 0.02), Parent = card,
	})
	UIKit.Badge(theme, { Name = "Level", Text = "LV 42", Kind = "xp", Size = UDim2.fromScale(0.3, 0.38), Position = UDim2.fromScale(0.3, 0.56), Parent = card })
	UIKit.Currency(theme, {
		Name = "Coins", Icon = icon("gem"), Amount = "8,450", Kind = "accent", Size = UDim2.fromScale(0.16, 0.06),
		Position = UDim2.fromScale(0.99, 0.03), AnchorPoint = Vector2.new(1, 0), Parent = gui,
	})

	UIKit.Badge(theme, {
		Name = "Ultimate", Text = "MAXIMUM OUTPUT [G]", Kind = "accent", Slant = true, Size = UDim2.fromScale(0.26, 0.045),
		Position = UDim2.fromScale(0.5, 0.6), AnchorPoint = Vector2.new(0.5, 0.5), Parent = gui,
	})
	local style = theme.shape.barStyle
	local split = style == "split"
	UIKit.Bar(theme, {
		Name = "Vitals", Style = style, Kind = "health", Value = 0.72, RightKind = "energy", RightValue = 0.45,
		Segments = if style == "single" then nil else 12, Emblem = if split then icon("skull") else nil,
		Label = if split then nil else "HP", ValueText = if split then nil else "72/100",
		Size = UDim2.fromScale(0.42, 0.04), Position = UDim2.fromScale(0.5, 0.67), AnchorPoint = Vector2.new(0.5, 0.5), Parent = gui,
	})
	if not split then
		UIKit.Bar(theme, {
			Name = "Energy", Style = style, Kind = "energy", Value = 0.45, Segments = 12, Size = UDim2.fromScale(0.3, 0.02),
			Position = UDim2.fromScale(0.5, 0.715), AnchorPoint = Vector2.new(0.5, 0.5), Parent = gui,
		})
	end
	local slots = {}
	for i, move in copy.moves do
		table.insert(slots, { Key = tostring(i), Title = move, Cooldown = if i == 3 then 0.55 else 0, Selected = i == 1 })
	end
	UIKit.Hotbar(theme, {
		Name = "Moves", Slots = slots, Size = UDim2.fromScale(0.36, 0.13), Position = UDim2.fromScale(0.5, 0.86),
		AnchorPoint = Vector2.new(0.5, 0.5), Parent = gui,
	})

	local mobile = group(UIKit, gui, "MobileButtons", { Position = UDim2.fromScale(0.985, 0.97), AnchorPoint = Vector2.new(1, 1), Size = UDim2.fromScale(0.17, 0.32) })
	for _, b in {
		{ "Jump", "jump", 0.72, 0.76, 0.5 }, { "Dash", "dash", 0.2, 0.82, 0.34 },
		{ "Attack", "fist", 0.74, 0.3, 0.36 }, { "Block", "shield", 0.24, 0.4, 0.34 },
	} do
		UIKit.IconButton(theme, {
			Name = b[1], Icon = icon(b[2]), Round = true, Size = UDim2.fromScale(b[5], b[5]), Position = UDim2.fromScale(b[3], b[4]),
			AnchorPoint = Vector2.new(0.5, 0.5), Parent = mobile,
		})
	end
end

local function settingsRow(UIKit: any, theme: any, list: Instance, index: number, label: string): Frame
	local row = UIKit.Util.make("Frame", {
		Name = label, BackgroundColor3 = theme.color.surface, BackgroundTransparency = theme.color.surfaceTransparency,
		BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, SETTINGS_ROW_HEIGHT), LayoutOrder = index, ZIndex = 3, Parent = list,
	})
	UIKit.Util.corner(row, theme.radius.slot)
	UIKit.Util.stroke(row, theme.color.barEdge, theme.stroke.slot)
	UIKit.Util.text(theme, {
		Name = "Label", Text = label, Role = "display", XAlign = Enum.TextXAlignment.Left, Size = UDim2.fromScale(0.5, 0.6),
		Position = UDim2.fromScale(0.05, 0.2), Parent = row,
	})
	return row
end

local function menus(UIKit: any, theme: any, gui: ScreenGui)
	local panelSize = UDim2.fromScale(0.31, 0.72)
	local _, shopBody = UIKit.Panel(theme, {
		Name = "Shop", Title = "Shop", Icon = icon("shop"), Body = "none", Tilt = false, AspectRatio = 0.85,
		Size = panelSize, Position = UDim2.fromScale(0.175, 0.55), Parent = gui,
	})
	UIKit.Tabs(theme, { Tabs = { "Featured", "Passes", "Coins" }, Selected = "Featured", Size = UDim2.new(1, 0, 0, TAB_HEIGHT), Parent = shopBody })
	local list = UIKit.List(theme, { Position = UDim2.fromOffset(0, TAB_HEIGHT + 8), Size = UDim2.new(1, 0, 1, -(TAB_HEIGHT + 8)), Parent = shopBody })
	for i, item in {
		{ "2X Strength", "Double every lift", "R$ 199", "muscle" }, { "VIP", "Chat tag + 10% cash", "R$ 399", "crown" },
		{ "Lucky Pack", "+50% luck, 30 min", "R$ 49", "clover" }, { "Starter Bundle", "Gems, pets and boosts", "R$ 99", "gift" },
	} do
		UIKit.Card(theme, { Name = "Item" .. i, Title = item[1], Subtitle = item[2], Action = item[3], Icon = icon(item[4]), Height = 64, LayoutOrder = i, Parent = list })
	end

	local _, grid = UIKit.Panel(theme, {
		Name = "Inventory", Title = "Inventory", Icon = icon("bag"), Body = "grid", Columns = 4, AspectRatio = 0.85,
		Size = panelSize, Position = UDim2.fromScale(0.5, 0.55), Parent = gui,
	})
	for i, key in { "pets", "gem", "crown", "clover", "gift", "potion", "potion_red", "potion_yellow", "key", "sword", "shield", "star" } do
		UIKit.Slot(theme, { Name = "Item" .. i, Icon = icon(key), Value = if i % 3 == 0 then "x" .. i else nil, Selected = i == 2, LayoutOrder = i, Parent = grid })
	end

	local _, settingsList = UIKit.Panel(theme, {
		Name = "Settings", Title = "Settings", Icon = icon("settings"), Body = "list", AspectRatio = 0.85,
		Size = panelSize, Position = UDim2.fromScale(0.825, 0.55), Parent = gui,
	})
	local function control(row: Frame, kind: string, value: any)
		local anchor = Vector2.new(1, 0.5)
		if kind == "toggle" then
			UIKit.Toggle(theme, { On = value, Size = UDim2.fromScale(0.3, 0.7), Position = UDim2.fromScale(0.95, 0.5), AnchorPoint = anchor, Parent = row })
		elseif kind == "slider" then
			UIKit.Slider(theme, { Value = value, Size = UDim2.fromScale(0.4, 0.6), Position = UDim2.fromScale(0.93, 0.5), AnchorPoint = anchor, Parent = row })
		else
			UIKit.TextInput(theme, { Placeholder = "Enter code", Size = UDim2.fromScale(0.44, 0.7), Position = UDim2.fromScale(0.95, 0.5), AnchorPoint = anchor, Parent = row })
		end
	end
	for i, r in { { "Music", "toggle", true }, { "Sound FX", "toggle", true }, { "Volume", "slider", 0.7 }, { "Low Graphics", "toggle", false }, { "Codes", "input", nil } } do
		control(settingsRow(UIKit, theme, settingsList, i, r[1]), r[2], r[3])
	end
end

local function feedback(UIKit: any, theme: any, gui: ScreenGui)
	local popup = UIKit.Popup(theme, {
		Name = "Reward", Title = "You got!", Body = "Golden Dumbbell", Icon = icon("gift"), Confirm = "Claim", Cancel = "Later", Parent = gui,
	})
	-- keep the splash, toasts and damage numbers above the popup's dim for the showcase shot
	popup.ZIndex = 5
	local stack = UIKit.ToastStack(theme, { Parent = gui })
	for i, t in { { "Quest complete! +250 XP", "xp" }, { "x2 Luck active for 15:00", "accent" }, { "Not enough coins", "health" } } do
		UIKit.Toast(theme, { Name = "Toast" .. i, Text = t[1], Kind = t[2], LayoutOrder = i, Parent = stack })
	end
	-- splash top-left and hits bottom-left so nothing covers the popup's title
	UIKit.Splash(theme, {
		Name = "LevelUp", Text = "LEVEL UP!", Kind = "xp", Size = UDim2.fromScale(0.34, 0.17),
		Position = UDim2.fromScale(0.2, 0.22), AnchorPoint = Vector2.new(0.5, 0.5), Parent = gui,
	})
	for _, d in { { 0.14, 0.58, "125", false }, { 0.24, 0.7, "1.2K", true }, { 0.1, 0.8, "98", false } } do
		UIKit.DamageNumber(theme, { Amount = d[3], Crit = d[4], Position = UDim2.fromScale(d[1], d[2]), Parent = gui })
	end
end

local function fitToViewport(UIKit: any, gui: ScreenGui)
	local camera = workspace.CurrentCamera
	if camera then
		UIKit.Util.scaleStrokes(gui, camera.ViewportSize.Y)
	end
	for _, d in gui:GetDescendants() do
		if d:IsA("UIGridLayout") and d:GetAttribute("DesignCell") ~= nil then
			UIKit.Util.pixelGrid(d)
		end
	end
end

function Showcase.build(UIKit: any, themeName: string, screenName: string): ScreenGui
	local theme = UIKit.theme(themeName)
	local copy = COPY[themeName]
	assert(copy, "Showcase has no copy for theme " .. themeName)
	local name = "SC_" .. themeName .. "_" .. screenName
	local old = StarterGui:FindFirstChild(name)
	if old then
		assert(old:GetAttribute("UIKitBuilt") == true, name .. " exists and was not built by UIKit; rename it first")
		old:Destroy()
	end
	local gui: ScreenGui
	if screenName == "Loading" then
		gui = UIKit.LoadingScreen(theme, { Name = name, Title = copy.game, Tip = copy.tip, Progress = 0.62 })
	elseif screenName == "MainMenu" then
		gui = UIKit.MainMenu(theme, { Name = name, Title = copy.game, Subtitle = copy.tagline, Buttons = { "PLAY", "SHOP", "SETTINGS", "CODES" } })
	else
		gui = UIKit.Screen(theme, { Name = name })
		if screenName == "HUD" then
			if theme.hudLayout == "simulator" then
				hudSimulator(UIKit, theme, gui)
			else
				hudCombat(UIKit, theme, gui, copy)
			end
		elseif screenName == "Menus" then
			menus(UIKit, theme, gui)
		elseif screenName == "Feedback" then
			feedback(UIKit, theme, gui)
		else
			error("unknown showcase screen " .. screenName)
		end
	end
	gui.Enabled = false
	gui:SetAttribute("ShowcaseTheme", themeName)
	gui:SetAttribute("ShowcaseScreen", screenName)
	gui.Parent = StarterGui
	return gui
end

function Showcase.buildTheme(UIKit: any, themeName: string)
	for _, screenName in Showcase.SCREENS do
		Showcase.build(UIKit, themeName, screenName)
		task.wait()
	end
end

-- Enables one showcase screen, disables the rest, and fits strokes and grids to the current viewport
function Showcase.show(UIKit: any, themeName: string, screenName: string): string
	local target = "SC_" .. themeName .. "_" .. screenName
	local shown: ScreenGui? = nil
	for _, gui in StarterGui:GetChildren() do
		if gui:IsA("ScreenGui") and gui:GetAttribute("ShowcaseScreen") ~= nil then
			gui.Enabled = gui.Name == target
			if gui.Name == target then
				shown = gui
			end
		end
	end
	assert(shown, "no showcase screen " .. target)
	task.wait()
	fitToViewport(UIKit, shown)
	return target
end

return Showcase
