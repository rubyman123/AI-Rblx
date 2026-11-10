--!strict
-- Read-only HUD pieces. Game code changes values through the contract names (Fill, Amount, Cooldown) or with
-- Motion.setBar / Motion.countTo / Motion.cooldown.

local Util = require(script.Parent.Util)
local Decor = require(script.Parent.Decor)
local make = Util.make

local Readouts = {}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local function makeFill(theme: any, parent: Instance, kind: string, value: number, fromRight: boolean): Frame
	local fill = make("Frame", {
		Name = "Fill",
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		-- the left half of a split bar drains toward the emblem in the middle
		AnchorPoint = Vector2.new(if fromRight then 1 else 0, 0),
		Position = UDim2.fromScale(if fromRight then 1 else 0, 0),
		Size = UDim2.fromScale(math.clamp(value, 0, 1), 1),
		ZIndex = 2,
		Parent = parent,
	})
	Util.corner(fill, theme.radius.control)
	Util.gradient(fill, theme.color.bars[kind], 90)
	return fill
end

local function makeTicks(theme: any, parent: Instance, segments: number)
	local holder = make("Frame", { Name = "Ticks", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = parent })
	for i = 1, segments - 1 do
		make("Frame", {
			Name = "Tick", BackgroundColor3 = theme.color.barEdge, BackgroundTransparency = 0.3, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(i / segments, 0), Size = UDim2.new(0, 2, 1, 0),
			ZIndex = 4, Parent = holder,
		})
	end
end

function Readouts.Bar(theme: any, props: { [string]: any }): Frame
	local style = props.Style or theme.shape.barStyle
	local kind = props.Kind or "health"
	local bar = make("Frame", { Name = "Bar", BackgroundColor3 = theme.color.track, BorderSizePixel = 0, ZIndex = 2 })
	Util.place(bar, props, UDim2.fromScale(0.4, 0.05))
	Util.corner(bar, theme.radius.control)
	Util.stroke(bar, theme.color.barEdge, theme.stroke.control)
	if style == "split" then
		local gap = 0.05
		local left = make("Frame", {
			Name = "Left", BackgroundTransparency = 1, Size = UDim2.fromScale(0.5 - gap / 2, 1), ZIndex = 2, Parent = bar,
		})
		makeFill(theme, left, kind, props.Value or 1, true)
		local right = make("Frame", {
			Name = "Right", BackgroundTransparency = 1, Position = UDim2.fromScale(0.5 + gap / 2, 0),
			Size = UDim2.fromScale(0.5 - gap / 2, 1), ZIndex = 2, Parent = bar,
		})
		makeFill(theme, right, props.RightKind or "energy", props.RightValue or props.Value or 1, false)
		if props.Segments then
			makeTicks(theme, left, math.max(2, math.floor(props.Segments / 2)))
			makeTicks(theme, right, math.max(2, math.floor(props.Segments / 2)))
		end
		local emblem = make("Frame", {
			Name = "Emblem", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1.9), Rotation = 45, BackgroundColor3 = theme.color.base, BorderSizePixel = 0,
			ZIndex = 5, Parent = bar,
		})
		Util.aspect(emblem, 1).DominantAxis = Enum.DominantAxis.Height
		Util.stroke(emblem, theme.color.rim, math.max(1.5, theme.stroke.control))
		if props.Emblem then
			-- the glyph sits on the bar, not inside the rotated diamond, so it stays upright
			Util.icon(theme, props.Emblem, {
				Name = "Glyph", Size = UDim2.fromScale(1, 1.3), Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 6, Parent = bar,
			})
		end
	else
		makeFill(theme, bar, kind, props.Value or 1, false)
		if style == "segmented" then
			makeTicks(theme, bar, props.Segments or 10)
		end
	end
	if props.Icon then
		Util.icon(theme, props.Icon, {
			Name = "Icon", Size = UDim2.fromScale(1, 1.75), Position = UDim2.fromScale(0, 0.45),
			AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 7, Parent = bar,
		})
	end
	if props.Label then
		Util.text(theme, {
			Name = "Label", Text = props.Label, Role = "display", XAlign = Enum.TextXAlignment.Left,
			Size = UDim2.fromScale(0.46, 0.84), Position = UDim2.fromScale(if props.Icon then 0.08 else 0.03, 0.08), ZIndex = 6, Parent = bar,
		})
	end
	if props.ValueText then
		Util.text(theme, {
			Name = "Value", Text = props.ValueText, Role = "number", XAlign = Enum.TextXAlignment.Right,
			Size = UDim2.fromScale(0.4, 0.8), Position = UDim2.fromScale(0.57, 0.1), ZIndex = 6, Parent = bar,
		})
	end
	theme.decorate.bar(bar, theme)
	Util.tag(bar, "Bar", theme)
	bar.Parent = props.Parent
	return bar
end

-- Icon + amount pill (cash, gems, tokens). Amount is the contract name game code writes to.
function Readouts.Currency(theme: any, props: { [string]: any }): Frame
	local kind = props.Kind or "accent"
	-- "bare": icon + outlined number straight on the world, the way top simulators show cash (no pill behind it)
	local bare = theme.shape.currencyStyle == "bare"
	local root = make("Frame", {
		Name = "Currency", BackgroundColor3 = theme.color.base,
		BackgroundTransparency = if bare then 1 else math.max(theme.color.baseTransparency, 0.25), BorderSizePixel = 0, ZIndex = 2,
	})
	Util.place(root, props, UDim2.fromScale(0.18, 0.07))
	-- one-line stats ("43.2B Strength") need a wider box than a bare number, or TextScaled wraps them
	Util.aspect(root, props.Aspect or 3.6)
	if not bare then
		Util.corner(root, theme.radius.pill)
		Util.stroke(root, theme.color.barEdge, theme.stroke.slot)
	end
	Util.icon(theme, props.Icon, {
		Name = "Icon", Size = UDim2.fromScale(1, if bare then 1.1 else 1.35), Position = UDim2.fromScale(0.02, 0.5),
		AnchorPoint = Vector2.new(if bare then 0 else 0.2, 0.5), ZIndex = 5, Parent = root,
	})
	local amount = Util.text(theme, {
		Name = "Amount", Text = props.Amount, Role = "number", XAlign = Enum.TextXAlignment.Left,
		Stroke = if bare then theme.textStroke.display else nil,
		-- the icon is one box-height wide, so the number starts just past it whatever the aspect
		Size = UDim2.fromScale(if bare then 0.98 - 1.25 / (props.Aspect or 3.6) else 0.66, if bare then 0.92 else 0.8),
		Position = UDim2.fromScale(if bare then 1.25 / (props.Aspect or 3.6) else 0.3, if bare then 0.04 else 0.1), ZIndex = 5, Parent = root,
	})
	if theme.shape.gradientText then
		local stops = theme.color.bars[kind]
		Util.gradient(amount, stops, 90)
		local stroke = amount:FindFirstChild("TextStroke")
		if stroke and stroke:IsA("UIStroke") then
			stroke.Color = Util.shade(stops[#stops], -0.65)
		end
	end
	Util.tag(root, "Currency", theme)
	root.Parent = props.Parent
	return root
end

-- Small label: "NEW!", "-50%", "Permanent!", or a slanted ultimate banner (Slant = true)
function Readouts.Badge(theme: any, props: { [string]: any }): Frame
	local stops = theme.color.bars[props.Kind or "accent"]
	local slant = props.Slant == true
	local badge = make("Frame", {
		Name = "Badge", BackgroundColor3 = if slant then stops[1] else WHITE, BorderSizePixel = 0,
		Rotation = props.Rotation or 0, ZIndex = 4,
	})
	Util.place(badge, props, UDim2.fromScale(0.12, 0.05))
	if slant then
		Decor.slant(badge)
	else
		Util.gradient(badge, stops, 90)
		Util.corner(badge, theme.radius.pill)
		Util.stroke(badge, theme.color.textStroke, math.max(1, theme.stroke.slot - 1))
	end
	Util.text(theme, {
		Name = "Label", Text = props.Text, Role = "display", Size = UDim2.fromScale(0.9, 0.82),
		Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 6, Parent = badge,
	})
	Util.tag(badge, "Badge", theme)
	badge.Parent = props.Parent
	return badge
end

-- Square cell: hotbar slot, move tile ("1 / Lapse Blue"), inventory item. Cooldown is a dark overlay whose
-- height is the remaining fraction.
function Readouts.Slot(theme: any, props: { [string]: any }): TextButton
	local slot = make("TextButton", {
		Name = "Slot", Text = "", AutoButtonColor = false, BackgroundColor3 = theme.color.surface,
		BackgroundTransparency = theme.color.surfaceTransparency, BorderSizePixel = 0, ZIndex = 3,
	})
	Util.place(slot, props, UDim2.fromScale(0.1, 1))
	Util.aspect(slot, 1)
	Util.corner(slot, theme.radius.slot)
	Util.stroke(slot, if props.Selected then theme.color.rim else theme.color.barEdge, theme.stroke.slot)
	if props.Icon then
		Util.icon(theme, props.Icon, {
			Name = "Icon", Size = UDim2.fromScale(0.6, 0.6), Position = UDim2.fromScale(0.5, if props.Title or props.Value then 0.42 else 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 4, Parent = slot,
		})
	end
	if props.Key then
		Util.text(theme, {
			Name = "Key", Text = props.Key, Role = "number", XAlign = Enum.TextXAlignment.Left,
			Size = UDim2.fromScale(0.36, 0.3), Position = UDim2.fromScale(0.07, 0.04), ZIndex = 7, Parent = slot,
		})
	end
	if props.Title then
		Util.text(theme, {
			Name = "Title", Text = props.Title, Role = "body",
			Size = if props.Icon then UDim2.fromScale(0.94, 0.22) else UDim2.fromScale(0.88, 0.46),
			Position = if props.Icon then UDim2.fromScale(0.03, 0.75) else UDim2.fromScale(0.06, 0.32),
			ZIndex = 7, Parent = slot,
		})
	end
	if props.Value then
		Util.text(theme, {
			Name = "Value", Text = props.Value, Role = "number", Color = theme.color.bars.accent[1],
			Size = UDim2.fromScale(0.9, 0.22), Position = UDim2.fromScale(0.05, 0.74), ZIndex = 7, Parent = slot,
		})
	end
	local cooldown = make("Frame", {
		Name = "Cooldown", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, math.clamp(props.Cooldown or 0, 0, 1)), BackgroundColor3 = BLACK,
		BackgroundTransparency = 0.4, BorderSizePixel = 0, ZIndex = 6, Parent = slot,
	})
	Util.corner(cooldown, theme.radius.slot)
	slot:SetAttribute("Selected", props.Selected == true)
	theme.decorate.slot(slot, theme)
	Util.tag(slot, "Slot", theme)
	slot.Parent = props.Parent
	return slot
end

function Readouts.Hotbar(theme: any, props: { [string]: any }): Frame
	local bar = make("Frame", { Name = "Hotbar", BackgroundTransparency = 1, ZIndex = 3 })
	Util.place(bar, props, UDim2.fromScale(0.5, 0.12))
	if not props.AnchorPoint then
		bar.AnchorPoint = Vector2.new(0.5, 1)
	end
	if not props.Position then
		bar.Position = UDim2.fromScale(0.5, 0.98)
	end
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = bar,
	})
	for i, slotProps in props.Slots do
		local p = table.clone(slotProps)
		p.Name = p.Name or ("Slot" .. i)
		p.LayoutOrder = i
		p.Size = UDim2.fromScale(1, 1)
		p.Parent = bar
		Readouts.Slot(theme, p)
	end
	Util.tag(bar, "Hotbar", theme)
	bar.Parent = props.Parent
	return bar
end

function Readouts.Tooltip(theme: any, props: { [string]: any }): Frame
	local tip = make("Frame", {
		Name = "Tooltip", BackgroundColor3 = theme.color.base, BackgroundTransparency = math.max(theme.color.baseTransparency, 0.08),
		BorderSizePixel = 0, ZIndex = 20,
	})
	Util.place(tip, props, UDim2.fromScale(0.2, 0.06))
	Util.corner(tip, theme.radius.control)
	Util.stroke(tip, theme.color.rim, theme.stroke.slot)
	Util.text(theme, {
		Name = "Label", Text = props.Text, Size = UDim2.fromScale(0.92, 0.8), Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 21, Parent = tip,
	})
	Util.tag(tip, "Tooltip", theme)
	tip.Parent = props.Parent
	return tip
end

return Readouts
