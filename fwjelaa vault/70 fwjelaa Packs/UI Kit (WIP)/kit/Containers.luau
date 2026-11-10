--!strict
-- Screens, panels and the scrolling bodies inside them. Contract names (Main, TitleTab, Close, List, Grid, Body,
-- Template) come from Lift a Rock so runtime code can find things without references.

local Util = require(script.Parent.Util)
local Decor = require(script.Parent.Decor)
local Controls = require(script.Parent.Controls)
local make = Util.make

local Containers = {}

-- Where the title sits for each theme header style, and where the body starts below it
local HEADER = {
	tab = { position = UDim2.fromScale(0.04, -0.1), size = UDim2.fromScale(0.38, 0.13), bodyTop = 0.08 },
	strip = { position = UDim2.fromScale(0.03, 0.03), size = UDim2.fromScale(0.55, 0.1), bodyTop = 0.16 },
	center = { position = UDim2.fromScale(0.2, 0.025), size = UDim2.fromScale(0.6, 0.11), bodyTop = 0.18 },
	-- full-width studded header with the close button inside it (the Studs reference style)
	bar = { position = UDim2.fromScale(0, 0), size = UDim2.fromScale(1, 0.13), bodyTop = 0.165 },
}
local BAR_SEAM_FROM = 0.6 -- the bar's bottom 40% is redrawn square so it sits flush on the panel body

function Containers.Screen(theme: any, props: { [string]: any }): ScreenGui
	local fullScreen = props.FullScreen == true
	local gui = make("ScreenGui", {
		Name = props.Name,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = fullScreen,
		ScreenInsets = if fullScreen then Enum.ScreenInsets.None else Enum.ScreenInsets.CoreUISafeInsets,
		DisplayOrder = props.DisplayOrder or 0,
		Enabled = props.Enabled ~= false,
	})
	gui:SetAttribute("UIKitTheme", theme.name)
	gui:SetAttribute("UIKitBuilt", true)
	gui:SetAttribute("UIKitRole", props.Role or "Screen")
	return gui
end

local function scroller(theme: any, name: string, props: { [string]: any }): ScrollingFrame
	local frame = make("ScrollingFrame", {
		Name = name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = theme.color.rim,
		ZIndex = 3,
	})
	Util.place(frame, props, UDim2.fromScale(1, 1))
	make("UIPadding", {
		PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 12),
		Parent = frame,
	})
	return frame
end

function Containers.List(theme: any, props: { [string]: any }): ScrollingFrame
	local list = scroller(theme, props.Name or "List", props)
	make("UIListLayout", {
		Padding = UDim.new(0, props.Gap or 8), HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder, Parent = list,
	})
	Util.tag(list, "List", theme)
	list.Parent = props.Parent
	return list
end

function Containers.Grid(theme: any, props: { [string]: any }): ScrollingFrame
	local grid = scroller(theme, props.Name or "Grid", props)
	local columns = props.Columns or 4
	local gap = props.Gap or 0.025
	local cellWidth = (1 - gap * (columns - 1)) / columns - 0.003
	local layout = make("UIGridLayout", {
		-- placeholder sizes; Util.pixelGrid swaps in pixel cells once the grid is on screen
		CellSize = UDim2.new(cellWidth, 0, 0, 80),
		CellPadding = UDim2.fromScale(gap, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = grid,
	})
	layout:SetAttribute("DesignCell", UDim2.fromScale(cellWidth, 0))
	layout:SetAttribute("DesignGap", UDim2.fromScale(gap, gap))
	layout:SetAttribute("CellAspect", props.CellAspect or 1)
	Util.tag(grid, "Grid", theme)
	grid.Parent = props.Parent
	return grid
end

function Containers.Panel(theme: any, props: { [string]: any }): (Frame, GuiObject)
	local body = props.Body or "list"
	local headerStyle = theme.shape.header
	local header = HEADER[headerStyle]
	local main = make("Frame", {
		Name = props.Name or "Main",
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		Position = props.Position or UDim2.fromScale(0.5, 0.53),
		Size = props.Size or UDim2.fromScale(0.85, 0.66),
		BackgroundColor3 = theme.color.base,
		BackgroundTransparency = theme.color.baseTransparency,
		BorderSizePixel = 0,
		-- a rotated ancestor switches off ClipsDescendants, so only non-scrolling panels tilt (Tilt = false opts out
		-- when a "none" body will hold a scrolling list)
		Rotation = if body == "none" and props.Tilt ~= false then theme.shape.tilt else 0,
		ZIndex = 1,
	})
	Util.aspect(main, props.AspectRatio or 1.45)
	if theme.shape.chamfer > 0 then
		Decor.chamfer(main, theme.shape.chamfer, theme.color.rim, theme.stroke.panel)
	else
		Util.corner(main, theme.radius.panel)
		Util.stroke(main, theme.color.rim, theme.stroke.panel)
	end

	local tab = make("Frame", {
		Name = "TitleTab", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
		Position = header.position, Size = header.size, ZIndex = 5, Parent = main,
	})
	Util.gradient(tab, theme.color.header, 90)
	local isBar = headerStyle == "bar"
	Util.corner(tab, if isBar then theme.radius.panel else theme.radius.control)
	Util.stroke(tab, theme.color.textStroke, theme.stroke.control)
	if isBar then
		local seam = make("Frame", {
			Name = "Seam", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Position = UDim2.fromScale(0, BAR_SEAM_FROM),
			Size = UDim2.fromScale(1, 1 - BAR_SEAM_FROM), ZIndex = 0, Parent = tab,
		})
		Util.gradient(seam, { Util.sample(theme.color.header, BAR_SEAM_FROM), theme.color.header[#theme.color.header] }, 90)
	end
	local hasIcon = props.Icon ~= nil and (headerStyle == "tab" or isBar)
	if hasIcon and isBar then
		Util.icon(theme, props.Icon, {
			Name = "Icon", Size = UDim2.fromScale(1, 0.92), Position = UDim2.fromScale(0.012, 0.5),
			AnchorPoint = Vector2.new(0, 0.5), ZIndex = 8, Parent = tab,
		})
	elseif hasIcon then
		-- oversized icon breaking out of the tab, like Lift a Rock's panel headers
		Util.icon(theme, props.Icon, {
			Name = "Icon", Size = UDim2.fromScale(0.42, 1.9), Position = UDim2.fromScale(0.1, 0.42),
			AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 8, Parent = tab,
		})
	end
	local titleSize, titlePosition = UDim2.fromScale(0.9, 0.84), UDim2.fromScale(0.05, 0.08)
	if hasIcon and isBar then
		titleSize, titlePosition = UDim2.fromScale(0.7, 0.72), UDim2.fromScale(0.105, 0.14)
	elseif isBar then
		titleSize, titlePosition = UDim2.fromScale(0.75, 0.72), UDim2.fromScale(0.03, 0.14)
	elseif hasIcon then
		titleSize, titlePosition = UDim2.fromScale(0.64, 0.84), UDim2.fromScale(0.3, 0.08)
	end
	Util.text(theme, {
		Name = "Title",
		Text = props.Title,
		Role = "display",
		XAlign = if headerStyle == "center" then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left,
		Size = titleSize,
		Position = titlePosition,
		ZIndex = 7,
		Parent = tab,
	})
	theme.decorate.header(tab, theme)

	local overhang = headerStyle == "tab"
	local closePosition, closeAnchor = UDim2.fromScale(0.975, 0.03), Vector2.new(1, 0)
	if overhang then
		closePosition, closeAnchor = UDim2.fromScale(0.985, 0.015), Vector2.new(0.5, 0.5)
	elseif isBar then
		closePosition, closeAnchor = UDim2.fromScale(0.985, header.size.Y.Scale / 2), Vector2.new(1, 0.5)
	end
	local close = Controls.Button(theme, {
		Name = "Close",
		Text = "X",
		Variant = "danger",
		Size = if isBar then UDim2.fromScale(0.1, header.size.Y.Scale * 0.74) else UDim2.fromScale(0.08, 0.12),
		Position = closePosition,
		AnchorPoint = closeAnchor,
		ZIndex = 6,
		Parent = main,
	})
	Util.aspect(close, 1)
	close:AddTag("UIKit.Close")

	local bodyPosition = UDim2.fromScale(0.03, header.bodyTop)
	local bodySize = UDim2.fromScale(0.94, 0.96 - header.bodyTop)
	local content: GuiObject
	if body == "grid" then
		content = Containers.Grid(theme, {
			Columns = props.Columns, CellAspect = props.CellAspect, Position = bodyPosition, Size = bodySize, Parent = main,
		})
	elseif body == "none" then
		content = make("Frame", {
			Name = "Body", BackgroundTransparency = 1, Position = bodyPosition, Size = bodySize, ZIndex = 3, Parent = main,
		})
	else
		content = Containers.List(theme, { Position = bodyPosition, Size = bodySize, Parent = main })
	end

	theme.decorate.panel(main, theme)
	Util.tag(main, "Panel", theme)
	main.Parent = props.Parent
	return main, content
end

function Containers.Tabs(theme: any, props: { [string]: any }): Frame
	local bar = make("Frame", { Name = "Tabs", BackgroundTransparency = 1, ZIndex = 3 })
	Util.place(bar, props, UDim2.fromScale(1, 0.12))
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0.015, 0), SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center, Parent = bar,
	})
	local selected = props.Selected or props.Tabs[1]
	local width = 1 / #props.Tabs - 0.015
	for i, id in props.Tabs do
		Controls.Button(theme, {
			Name = id, Text = id, Variant = if id == selected then "primary" else "secondary",
			Size = UDim2.fromScale(width, 1), LayoutOrder = i, Parent = bar,
		})
	end
	bar:SetAttribute("Selected", selected)
	Util.tag(bar, "Tabs", theme)
	bar.Parent = props.Parent
	return bar
end

-- A list row: icon, title, subtitle and an action button (shop items, quests, settings rows)
function Containers.Card(theme: any, props: { [string]: any }): Frame
	local card = make("Frame", {
		Name = "Card",
		BackgroundColor3 = theme.color.surface,
		BackgroundTransparency = theme.color.surfaceTransparency,
		BorderSizePixel = 0,
		ZIndex = 3,
	})
	-- rows are pixel-tall like Lift a Rock's: Scale heights inside an auto-sizing list feed back into the canvas
	Util.place(card, props, UDim2.new(1, 0, 0, props.Height or 84))
	Util.corner(card, theme.radius.slot)
	Util.stroke(card, theme.color.rim, theme.stroke.slot)
	local textLeft = 0.04
	if props.Icon then
		Util.icon(theme, props.Icon, {
			Name = "Icon", Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.015, 0.1), ZIndex = 5, Parent = card,
		})
		textLeft = 0.2
	end
	Util.text(theme, {
		Name = "Title", Text = props.Title, Role = "display", XAlign = Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(0.5, 0.42), Position = UDim2.fromScale(textLeft, 0.08), ZIndex = 5, Parent = card,
	})
	Util.text(theme, {
		Name = "Subtitle", Text = props.Subtitle or "", Color = theme.color.textMuted, XAlign = Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(0.5, 0.34), Position = UDim2.fromScale(textLeft, 0.54), ZIndex = 5, Parent = card,
	})
	if props.Action then
		Controls.Button(theme, {
			Name = "Action", Text = props.Action, Variant = props.ActionVariant or "success",
			Size = UDim2.fromScale(0.25, 0.62), Position = UDim2.fromScale(0.735, 0.19), ZIndex = 4, Parent = card,
		})
	end
	theme.decorate.slot(card, theme)
	Util.tag(card, "Card", theme)
	card.Parent = props.Parent
	return card
end

return Containers
