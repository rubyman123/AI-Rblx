--!strict
-- Structural self-test for UIKit. Builds every component in every theme and checks the contract names that
-- Motion and game code rely on. Run it through MCP execute_luau (see workflow.md); it returns a report string.

local KitCheck = {}

-- Themes the kit must ship. A task that adds a theme adds its name here first (red), then the theme (green).
KitCheck.EXPECTED_THEMES = { "StudSimulator" }

local REQUIRED_TOKENS = {
	"name", "hudLayout",
	"color.backdrop", "color.base", "color.baseTransparency", "color.surface", "color.surfaceTransparency",
	"color.rim", "color.barEdge", "color.text", "color.textMuted", "color.textStroke", "color.track", "color.header",
	"color.variants.primary", "color.variants.secondary", "color.variants.success", "color.variants.danger",
	"color.variants.ghost",
	"color.bars.health", "color.bars.energy", "color.bars.xp", "color.bars.accent",
	"font.display", "font.body", "font.number",
	"textStroke.display", "textStroke.body",
	"stroke.panel", "stroke.control", "stroke.slot",
	"radius.panel", "radius.control", "radius.slot", "radius.pill",
	"shape.chamfer", "shape.slantButtons", "shape.tilt", "shape.header", "shape.iconFrame", "shape.gradientText",
	"shape.barStyle", "shape.currencyStyle",
	"motion.style", "motion.easing", "motion.fast", "motion.normal", "motion.slow", "motion.pressScale",
	"motion.openFrom", "motion.worldBlur",
	"assets",
	"decorate.panel", "decorate.header", "decorate.button", "decorate.slot", "decorate.bar", "decorate.screen",
}

local function lookup(root: any, path: string): any
	local node = root
	for key in string.gmatch(path, "[^%.]+") do
		if type(node) ~= "table" then
			return nil
		end
		node = node[key]
	end
	return node
end

local function need(root: Instance, path: string)
	local node: Instance? = root
	for name in string.gmatch(path, "[^%.]+") do
		node = if node then node:FindFirstChild(name) else nil
	end
	assert(node ~= nil, root.Name .. " is missing " .. path)
end

-- Long text must shrink to fit, and every stroke must be rescalable for phones
local function assertSafe(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("TextLabel") then
			assert(d.TextScaled, d:GetFullName() .. " is not TextScaled")
			assert(d:FindFirstChildOfClass("UITextSizeConstraint"), d:GetFullName() .. " has no UITextSizeConstraint")
		elseif d:IsA("UIStroke") then
			assert(type(d:GetAttribute("BaseThickness")) == "number", d:GetFullName() .. " has no BaseThickness")
		end
	end
end

local function report(passed: number, failures: { string }): string
	local lines = { string.format("KitCheck: %d passed, %d failed", passed, #failures) }
	for _, failure in failures do
		table.insert(lines, "- " .. failure)
	end
	return table.concat(lines, "\n")
end

function KitCheck.run(UIKit: any): string
	local passed = 0
	local failures: { string } = {}
	local function case(label: string, fn: () -> ())
		local ok, err = pcall(fn)
		if ok then
			passed += 1
		else
			table.insert(failures, label .. ": " .. tostring(err))
		end
	end

	case("kit installed", function()
		assert(UIKit ~= nil, "ReplicatedStorage.UIKit not found")
	end)
	if UIKit == nil then
		return report(passed, failures)
	end

	case("Util.abbreviate", function()
		local cases = {
			{ 0, "0" }, { 999, "999" }, { 999.6, "1K" }, { 1000, "1K" }, { 1234, "1.2K" }, { 15000, "15K" },
			{ 999999, "1M" }, { 1500000, "1.5M" }, { -2500, "-2.5K" }, { 2.5e12, "2.5T" },
		}
		for _, c in cases do
			local got = UIKit.Util.abbreviate(c[1])
			assert(got == c[2], string.format("abbreviate(%s) = %s, want %s", tostring(c[1]), got, c[2]))
		end
	end)

	case("Util.sequence", function()
		local one = UIKit.Util.sequence({ Color3.new(1, 0, 0) })
		assert(#one.Keypoints == 2, "a single stop should make a 2-keypoint sequence")
		local three = UIKit.Util.sequence({ Color3.new(1, 0, 0), Color3.new(0, 1, 0), Color3.new(0, 0, 1) })
		assert(math.abs(three.Keypoints[2].Time - 0.5) < 1e-6, "the middle stop should sit at 0.5")
	end)

	case("Icons registry", function()
		local Icons = UIKit.Icons
		assert(Icons, "UIKit.Icons missing")
		assert(string.find(Icons.get("coin"), "^rbxassetid://"), "coin should resolve to uploaded art")
		assert(Icons.get("💎") == "💎", "unknown values must pass through unchanged")
		Icons.USE_ART = false
		local emoji = Icons.get("coin")
		Icons.USE_ART = true
		assert(not string.find(emoji, "^rbx"), "with USE_ART off, names fall back to emoji")
	end)

	case("Util.strokeFactor", function()
		assert(UIKit.Util.strokeFactor(600) == 1, "600 px is the design height")
		assert(UIKit.Util.strokeFactor(300) == 0.75, "small screens clamp to 0.75")
		assert(UIKit.Util.strokeFactor(2160) == 1.75, "huge screens clamp to 1.75")
	end)

	local names = UIKit.themeNames()
	for _, expected in KitCheck.EXPECTED_THEMES do
		case("theme " .. expected .. " exists", function()
			assert(table.find(names, expected), "no theme module named " .. expected)
		end)
	end

	for _, name in names do
		local theme = UIKit.theme(name)
		local function build(label: string, fn: () -> Instance?)
			case(name .. " " .. label, function()
				local root = fn()
				if root then
					assertSafe(root)
					root:Destroy()
				end
			end)
		end

		case(name .. " tokens", function()
			assert(theme.name == name, "theme.name must equal the module name")
			for _, path in REQUIRED_TOKENS do
				assert(lookup(theme, path) ~= nil, "missing token " .. path)
			end
			for vname, v in theme.color.variants do
				assert(type(v.fill) == "table" and #v.fill >= 1, vname .. ".fill needs at least one colour")
				assert(typeof(v.text) == "Color3" and typeof(v.edge) == "Color3" and typeof(v.textStroke) == "Color3",
					vname .. " needs text, edge and textStroke colours")
				assert(type(v.fillTransparency) == "number", vname .. ".fillTransparency must be a number")
			end
			assert(table.find({ "simulator", "combat" }, theme.hudLayout), "hudLayout must be simulator|combat")
			assert(table.find({ "tab", "strip", "center", "bar" }, theme.shape.header), "shape.header must be tab|strip|center|bar")
			assert(table.find({ "pill", "bare" }, theme.shape.currencyStyle), "shape.currencyStyle must be pill|bare")
			assert(table.find({ "single", "split", "segmented" }, theme.shape.barStyle), "bad shape.barStyle")
			assert(table.find({ "pop", "slam", "flicker", "slide", "stamp", "fade" }, theme.motion.style), "bad motion.style")
		end)

		build("Screen", function()
			local hud = UIKit.Screen(theme, { Name = "HUD" })
			assert(hud.ScreenInsets == Enum.ScreenInsets.CoreUISafeInsets and not hud.IgnoreGuiInset,
				"HUD screens must keep clear of the top bar")
			assert(hud:GetAttribute("UIKitBuilt") == true and hud:GetAttribute("UIKitTheme") == name, "screen attributes missing")
			local full = UIKit.Screen(theme, { Name = "Full", FullScreen = true })
			assert(full.IgnoreGuiInset and full.ScreenInsets == Enum.ScreenInsets.None, "full-screen guis must cover the top bar")
			full:Destroy()
			return hud
		end)

		build("Panel(list)", function()
			local main, list = UIKit.Panel(theme, { Title = "Legendary Golden Dumbbell of Power", Icon = "🛒", Body = "list" })
			assert(main.Name == "Main" and main:HasTag("UIKit.Panel"), "panel root must be Main, tagged UIKit.Panel")
			need(main, "TitleTab.Title")
			need(main, "Close.Label")
			assert(main.Close:HasTag("UIKit.Close"), "Close must be tagged UIKit.Close")
			assert(list.Name == "List" and list:IsA("ScrollingFrame") and list:FindFirstChildOfClass("UIListLayout"), "list body wrong")
			return main
		end)

		build("Panel(grid)", function()
			local main, grid = UIKit.Panel(theme, { Title = "Inventory", Body = "grid", Columns = 4 })
			local layout = grid:FindFirstChildOfClass("UIGridLayout")
			assert(grid.Name == "Grid" and layout, "grid body wrong")
			assert(typeof(layout:GetAttribute("DesignCell")) == "UDim2", "grid layout needs DesignCell for the pixel fix")
			return main
		end)

		build("Panel(none)", function()
			local main, body = UIKit.Panel(theme, { Title = "Settings", Body = "none" })
			assert(body.Name == "Body", "a none body must be a Frame named Body")
			return main
		end)

		for vname in theme.color.variants do
			build("Button(" .. vname .. ")", function()
				local b = UIKit.Button(theme, { Text = "Play", Variant = vname })
				need(b, "Label")
				assert(b:IsA("TextButton") and b.Text == "" and b:HasTag("UIKit.Button") and b:GetAttribute("Variant") == vname,
					"button contract wrong")
				return b
			end)
		end

		build("setVariant", function()
			local b = UIKit.Button(theme, { Text = "Tab", Variant = "secondary" })
			UIKit.setVariant(theme, b, "primary")
			assert(b:GetAttribute("Variant") == "primary", "Variant attribute not updated")
			assert(b.Label.TextColor3 == theme.color.variants.primary.text, "label colour not updated")
			return b
		end)

		build("IconButton", function()
			local b = UIKit.IconButton(theme, { Icon = "🛒", Caption = "Shop" })
			need(b, "Icon")
			need(b, "Caption")
			assert(b:HasTag("UIKit.Button"), "icon buttons need press feedback too")
			return b
		end)

		build("Toggle", function()
			local t = UIKit.Toggle(theme, { On = true })
			need(t, "Knob")
			need(t, "Fill")
			assert(t:GetAttribute("On") == true and t:HasTag("UIKit.Toggle"), "toggle contract wrong")
			return t
		end)

		build("Slider", function()
			local s = UIKit.Slider(theme, { Value = 0.3 })
			need(s, "Track.Fill")
			need(s, "Knob")
			assert(math.abs(s:GetAttribute("Value") - 0.3) < 1e-6 and s:HasTag("UIKit.Slider"), "slider contract wrong")
			return s
		end)

		build("TextInput", function()
			local i = UIKit.TextInput(theme, { Placeholder = "Enter code" })
			need(i, "Box")
			return i
		end)

		build("Tabs", function()
			local t = UIKit.Tabs(theme, { Tabs = { "Featured", "Passes", "Coins" }, Selected = "Passes" })
			assert(t:GetAttribute("Selected") == "Passes" and t:HasTag("UIKit.Tabs"), "tabs contract wrong")
			assert(t.Passes:GetAttribute("Variant") == "primary" and t.Featured:GetAttribute("Variant") == "secondary",
				"the selected tab must use the primary variant")
			return t
		end)

		build("Card(template)", function()
			local c = UIKit.Card(theme, {
				Name = "Template", Title = "2X Strength", Subtitle = "Double gains", Icon = "💪", Action = "R$ 199", Visible = false,
			})
			need(c, "Title")
			need(c, "Subtitle")
			need(c, "Action.Label")
			assert(c.Visible == false, "templates must start hidden")
			return c
		end)

		for _, style in { "single", "split", "segmented" } do
			build("Bar(" .. style .. ")", function()
				local b = UIKit.Bar(theme, { Style = style, Value = 0.5, Label = "HP", ValueText = "50/100", Segments = 10 })
				if style == "split" then
					need(b, "Left.Fill")
					need(b, "Right.Fill")
					need(b, "Emblem")
				else
					need(b, "Fill")
				end
				if style == "segmented" then
					local ticks = b:FindFirstChild("Ticks")
					assert(ticks and #ticks:GetChildren() == 9, "10 segments need 9 ticks")
				end
				return b
			end)
		end

		build("Currency", function()
			local c = UIKit.Currency(theme, { Icon = "💵", Amount = "$1.2K", Kind = "accent" })
			need(c, "Amount")
			need(c, "Icon")
			return c
		end)

		build("Offer", function()
			local o = UIKit.Offer(theme, { Title = "+10B", Price = "55", Icon = "bolt", Variant = "primary" })
			need(o, "Label")
			need(o, "Price")
			need(o, "Icon")
			assert(o:IsA("TextButton") and o:HasTag("UIKit.Button"), "offers are buttons with press feedback")
			return o
		end)

		build("Offer(banner)", function()
			local o = UIKit.Offer(theme, {
				Title = "AUTO LIFT", Price = "30", PricePrefix = "ONLY", Icon = "trophy", Variant = "danger", Layout = "banner",
			})
			assert(o:GetAttribute("Layout") == "banner", "offers must record their layout")
			assert(o.Icon.AnchorPoint.Y == 1 and o.Icon.Position.Y.Scale <= 0.5, "a banner icon must stand on the top edge and peek above it")
			need(o, "Price.Prefix")
			assert(o.Price.Prefix.Text == "ONLY", "price prefix text wrong")
			assert(o.Price.AnchorPoint.X == 0.5, "a banner price row must be centred")
			return o
		end)

		build("Offer price glyph", function()
			local o = UIKit.Offer(theme, { Title = "+10B", Price = "55", Icon = "bolt" })
			need(o, "Price.Robux.Glyph")
			need(o, "Price.Robux.Edge")
			assert(o.Price.Robux.Edge.ZIndex < o.Price.Robux.Glyph.ZIndex, "the dark edge copy must sit behind the robux glyph")
			return o
		end)

		build("IconButton(variant)", function()
			local b = UIKit.IconButton(theme, { Icon = "egg", Caption = "Pets", Variant = "secondary" })
			if theme.shape.iconFrame then
				local g = b:FindFirstChildOfClass("UIGradient")
				assert(g and g.Color.Keypoints[1].Value == theme.color.variants.secondary.fill[1], "a variant icon tile needs the variant's gradient")
				-- UDim scales are 32-bit floats, so compare with a tolerance
				assert(math.abs(b.Icon.Size.X.Scale - (theme.shape.iconScale or 0.62)) < 1e-4, "a framed icon must follow shape.iconScale")
			end
			return b
		end)

		build("Currency(aspect)", function()
			local c = UIKit.Currency(theme, { Icon = "bolt", Amount = "43.2B Strength", Kind = "xp", Aspect = 7 })
			local a = c:FindFirstChildOfClass("UIAspectRatioConstraint")
			assert(a and a.AspectRatio == 7, "Currency must take an Aspect for one-line stats")
			return c
		end)

		build("named icon", function()
			local c = UIKit.Card(theme, { Title = "Coins", Icon = "coin" })
			assert(c.Icon:IsA("ImageLabel"), "a registry name should resolve to an image, got " .. c.Icon.ClassName)
			return c
		end)

		build("Badge", function()
			local b = UIKit.Badge(theme, { Text = "NEW!", Kind = "accent" })
			need(b, "Label")
			return b
		end)

		build("Slot", function()
			local s = UIKit.Slot(theme, { Key = "1", Title = "Lapse Blue", Cooldown = 0.5 })
			need(s, "Key")
			need(s, "Title")
			need(s, "Cooldown")
			return s
		end)

		build("Hotbar", function()
			local h = UIKit.Hotbar(theme, { Slots = { { Key = "1" }, { Key = "2" }, { Key = "3" }, { Key = "4" } } })
			local count = 0
			for _, child in h:GetChildren() do
				if child:IsA("GuiButton") then
					count += 1
				end
			end
			assert(count == 4, "the hotbar should hold 4 slots, has " .. count)
			return h
		end)

		build("Tooltip", function()
			local t = UIKit.Tooltip(theme, { Text = "Deals 2x damage" })
			need(t, "Label")
			return t
		end)

		build("ToastStack", function()
			local s = UIKit.ToastStack(theme, {})
			need(s, "Template.Label")
			assert(s.Template.Visible == false and s:FindFirstChildOfClass("UIListLayout"), "toast stack contract wrong")
			return s
		end)

		build("Popup", function()
			local p = UIKit.Popup(theme, { Title = "You got!", Body = "Golden Dumbbell", Icon = "🎁", Confirm = "Claim", Cancel = "Later" })
			need(p, "Main.Body.Actions.Confirm")
			need(p, "Main.Body.Actions.Cancel")
			return p
		end)

		build("Splash", function()
			local s = UIKit.Splash(theme, { Text = "LEVEL UP!", Kind = "xp" })
			need(s, "Text")
			return s
		end)

		build("DamageNumber", function()
			local d = UIKit.DamageNumber(theme, { Amount = "1.2K", Crit = true })
			assert(d:IsA("TextLabel"), "damage numbers are TextLabels")
			return d
		end)

		build("LoadingScreen", function()
			local g = UIKit.LoadingScreen(theme, { Title = "Lift a Rock", Tip = "Tip: rebirth for x1.5" })
			need(g, "Background.Progress.Fill")
			need(g, "Background.Title")
			assert(g:IsA("ScreenGui") and g.IgnoreGuiInset, "the loading screen must be full-screen")
			return g
		end)

		build("MainMenu", function()
			local g = UIKit.MainMenu(theme, { Title = "Lift a Rock", Buttons = { "PLAY", "SHOP", "SETTINGS" } })
			need(g, "Background.Buttons.PLAY.Label")
			return g
		end)
	end

	return report(passed, failures)
end

return KitCheck
