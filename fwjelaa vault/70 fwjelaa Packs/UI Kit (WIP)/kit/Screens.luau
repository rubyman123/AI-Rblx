--!strict
-- Full-screen screens. Both cover the top bar (FullScreen) and get the theme's background art from
-- decorate.screen(background, theme, "loading" | "menu").

local Util = require(script.Parent.Util)
local Containers = require(script.Parent.Containers)
local Controls = require(script.Parent.Controls)
local Readouts = require(script.Parent.Readouts)
local make = Util.make

local Screens = {}

local function background(theme: any, gui: ScreenGui, transparency: number): Frame
	return make("Frame", {
		Name = "Background", BackgroundColor3 = theme.color.backdrop, BackgroundTransparency = transparency,
		BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = gui,
	})
end

local function bigTitle(theme: any, parent: Instance, text: string, props: { [string]: any }): TextLabel
	local title = Util.text(theme, {
		Name = "Title", Text = text, Role = "display", Stroke = math.max(theme.textStroke.display, 2),
		XAlign = props.XAlign, Size = props.Size, Position = props.Position, AnchorPoint = props.AnchorPoint,
		MaxTextSize = 160, ZIndex = 6, Parent = parent,
	})
	if theme.shape.gradientText then
		Util.gradient(title, theme.color.bars.xp, 90)
	end
	return title
end

function Screens.LoadingScreen(theme: any, props: { [string]: any }): ScreenGui
	local gui = Containers.Screen(theme, { Name = props.Name or "Loading", FullScreen = true, DisplayOrder = 50, Role = "Loading" })
	local bg = background(theme, gui, 0)
	theme.decorate.screen(bg, theme, "loading")
	bigTitle(theme, bg, props.Title, {
		Size = UDim2.fromScale(0.72, 0.22), Position = UDim2.fromScale(0.5, 0.38), AnchorPoint = Vector2.new(0.5, 0.5),
	})
	local progress = math.clamp(props.Progress or 0.35, 0, 1)
	Readouts.Bar(theme, {
		Name = "Progress", Style = "single", Kind = "xp", Value = progress,
		ValueText = string.format("%d%%", math.floor(progress * 100)),
		Size = UDim2.fromScale(0.44, 0.05), Position = UDim2.fromScale(0.5, 0.7), AnchorPoint = Vector2.new(0.5, 0.5), Parent = bg,
	})
	if props.Tip then
		Util.text(theme, {
			Name = "Tip", Text = props.Tip, Color = theme.color.textMuted, Size = UDim2.fromScale(0.6, 0.045),
			Position = UDim2.fromScale(0.5, 0.79), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 6, Parent = bg,
		})
	end
	Controls.Button(theme, {
		Name = "Skip", Text = "Skip", Variant = "ghost", Size = UDim2.fromScale(0.1, 0.06),
		Position = UDim2.fromScale(0.97, 0.95), AnchorPoint = Vector2.new(1, 1), Parent = bg,
	})
	return gui
end

function Screens.MainMenu(theme: any, props: { [string]: any }): ScreenGui
	local gui = Containers.Screen(theme, { Name = props.Name or "MainMenu", FullScreen = true, DisplayOrder = 40, Role = "MainMenu" })
	-- partly see-through so the game world shows behind the menu
	local bg = background(theme, gui, 0.25)
	theme.decorate.screen(bg, theme, "menu")
	bigTitle(theme, bg, props.Title, {
		XAlign = Enum.TextXAlignment.Left, Size = UDim2.fromScale(0.5, 0.2), Position = UDim2.fromScale(0.06, 0.12),
	})
	if props.Subtitle then
		Util.text(theme, {
			Name = "Subtitle", Text = props.Subtitle, Color = theme.color.textMuted, XAlign = Enum.TextXAlignment.Left,
			Size = UDim2.fromScale(0.45, 0.05), Position = UDim2.fromScale(0.065, 0.33), ZIndex = 6, Parent = bg,
		})
	end
	local buttons = make("Frame", {
		Name = "Buttons", BackgroundTransparency = 1, Position = UDim2.fromScale(0.06, 0.42), Size = UDim2.fromScale(0.28, 0.5),
		ZIndex = 5, Parent = bg,
	})
	make("UIListLayout", { Padding = UDim.new(0.04, 0), SortOrder = Enum.SortOrder.LayoutOrder, Parent = buttons })
	for i, label in props.Buttons or { "PLAY", "SETTINGS" } do
		Controls.Button(theme, {
			Name = label, Text = label, Variant = if i == 1 then "primary" else "secondary",
			Size = UDim2.fromScale(if i == 1 then 1 else 0.82, if i == 1 then 0.26 else 0.17), LayoutOrder = i, Parent = buttons,
		})
	end
	Util.text(theme, {
		Name = "Version", Text = props.Version or "v1.0", Color = theme.color.textMuted, XAlign = Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(0.2, 0.03), Position = UDim2.fromScale(0.015, 0.96), ZIndex = 6, Parent = bg,
	})
	return gui
end

return Screens
