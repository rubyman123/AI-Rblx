--!strict
-- Interactive controls. Each returns plain instances tagged UIKit.<Kind>; Motion gives them behaviour at runtime.

local Util = require(script.Parent.Util)
local Decor = require(script.Parent.Decor)
local Icons = require(script.Parent.Icons)
local make = Util.make

local Controls = {}

local WHITE = Color3.new(1, 1, 1)

function Controls.Button(theme: any, props: { [string]: any }): TextButton
	local variantName = props.Variant or "primary"
	local v = theme.color.variants[variantName]
	local slant = theme.shape.slantButtons
	local button = make("TextButton", {
		Name = "Button",
		Text = "",
		AutoButtonColor = false,
		-- gradient buttons keep a white base because UIGradient multiplies; slanted ones need the flat colour
		BackgroundColor3 = if slant then v.fill[1] else WHITE,
		BackgroundTransparency = v.fillTransparency,
		BorderSizePixel = 0,
		ZIndex = props.ZIndex or 3,
	})
	Util.place(button, props, UDim2.fromScale(0.3, 0.12))
	button:SetAttribute("Variant", variantName)
	if slant then
		Decor.slant(button)
	else
		Util.gradient(button, v.fill, 90)
		Util.corner(button, theme.radius.control)
		Util.stroke(button, v.edge, theme.stroke.control)
	end
	local labelZ = (props.ZIndex or 3) + 2
	if props.Icon then
		Util.icon(theme, props.Icon, {
			Name = "Icon", Size = UDim2.fromScale(0.7, 0.7), Position = UDim2.fromScale(0.06, 0.15), ZIndex = labelZ, Parent = button,
		})
	end
	Util.text(theme, {
		Name = "Label",
		Text = props.Text,
		Role = "display",
		Color = v.text,
		StrokeColor = v.textStroke,
		Size = if props.Icon then UDim2.fromScale(0.62, 0.72) else UDim2.fromScale(0.86, 0.72),
		Position = if props.Icon then UDim2.fromScale(0.62, 0.5) else UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = labelZ,
		Parent = button,
	})
	theme.decorate.button(button, theme, variantName)
	Util.tag(button, "Button", theme)
	button.Parent = props.Parent
	return button
end

-- Robux glyph with a dark outline: a bigger dark copy behind a coloured one, because UIStroke can't outline an image
local function robuxGlyph(theme: any, color: Color3, zIndex: number, parent: Instance): Frame
	local holder = make("Frame", { Name = "Robux", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0.86), ZIndex = zIndex, Parent = parent })
	Util.aspect(holder, 1)
	for _, part in { { "Edge", theme.color.textStroke, 1.32, zIndex }, { "Glyph", color, 1, zIndex + 1 } } do
		make("ImageLabel", {
			Name = part[1], Image = Icons.ROBUX, ImageColor3 = part[2], BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(part[3], part[3]), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = part[4], Parent = holder,
		})
	end
	return holder
end

-- Store offers from top simulators. Layout "tile" (default) is the "+10B" tile: a big icon sits behind the title
-- and spills past its edges, with the price in the bottom-right corner. Layout "banner" is the "AUTO LIFT / ONLY 30"
-- banner: the icon stands on the top edge and peeks above it, with a centred price row under the title.
function Controls.Offer(theme: any, props: { [string]: any }): TextButton
	local banner = props.Layout == "banner"
	local button = Controls.Button(theme, {
		Name = props.Name or "Offer", Text = props.Title, Variant = props.Variant or "primary", Size = props.Size or UDim2.fromScale(0.14, 0.1),
		Position = props.Position, AnchorPoint = props.AnchorPoint, LayoutOrder = props.LayoutOrder, ZIndex = props.ZIndex,
	})
	button:SetAttribute("Layout", if banner then "banner" else "tile")
	local labelZ = (props.ZIndex or 3) + 4
	local label = button:FindFirstChild("Label") :: TextLabel
	label.Size = if banner then UDim2.fromScale(0.88, 0.5) else UDim2.fromScale(0.78, 0.6)
	label.Position = if banner then UDim2.fromScale(0.5, 0.4) else UDim2.fromScale(0.46, 0.42)
	label.ZIndex = labelZ
	if props.Icon then
		Util.icon(theme, props.Icon, {
			Name = "Icon",
			Size = if banner then UDim2.fromScale(1, 0.72) else UDim2.fromScale(1, 1.3),
			Position = if banner then UDim2.fromScale(0.5, 0.5) else UDim2.fromScale(0.42, 0.5),
			AnchorPoint = if banner then Vector2.new(0.5, 1) else Vector2.new(0.5, 0.5),
			ZIndex = labelZ - 1, Parent = button,
		})
	end
	if props.Price then
		-- banner prices read yellow like "ONLY 30"; tile prices read green like the Robux glyph
		local priceColor = if banner then theme.color.bars.xp[1] else theme.color.bars.accent[1]
		local price = make("Frame", {
			Name = "Price", BackgroundTransparency = 1, ZIndex = labelZ, Parent = button,
			AnchorPoint = if banner then Vector2.new(0.5, 1) else Vector2.new(1, 1),
			Position = if banner then UDim2.fromScale(0.5, 0.98) else UDim2.fromScale(0.97, 1.02),
			Size = if banner then UDim2.fromScale(0.8, 0.36) else UDim2.fromScale(0.5, 0.42),
		})
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0.03, 0), SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = if banner then Enum.HorizontalAlignment.Center else Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center, Parent = price,
		})
		if props.PricePrefix then
			local prefix = Util.text(theme, {
				Name = "Prefix", Text = props.PricePrefix, Role = "display", Color = priceColor, XAlign = Enum.TextXAlignment.Right,
				Stroke = theme.textStroke.body, Size = UDim2.fromScale(0.42, 1), ZIndex = labelZ, Parent = price,
			})
			prefix.LayoutOrder = 1
		end
		robuxGlyph(theme, theme.color.bars.accent[1], labelZ, price).LayoutOrder = 2
		local amount = Util.text(theme, {
			Name = "Amount", Text = props.Price, Role = "number", Color = priceColor, XAlign = Enum.TextXAlignment.Left,
			Stroke = theme.textStroke.body, Size = UDim2.fromScale(if props.PricePrefix then 0.3 else 0.6, 1), ZIndex = labelZ, Parent = price,
		})
		amount.LayoutOrder = 3
	end
	button.Parent = props.Parent
	return button
end

-- Re-colours a built button for another variant (selected tabs, toggled states)
function Controls.setVariant(theme: any, button: GuiObject, variantName: string)
	local v = theme.color.variants[variantName]
	button:SetAttribute("Variant", variantName)
	local face = button:FindFirstChild("Face")
	local holder: GuiObject = if face and face:IsA("GuiObject") then face else button
	local gradient = holder:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Color = Util.sequence(v.fill)
	else
		holder.BackgroundColor3 = v.fill[1]
	end
	holder.BackgroundTransparency = v.fillTransparency
	for _, name in { "CapL", "CapR" } do
		local cap = button:FindFirstChild(name)
		if cap and cap:IsA("Frame") then
			cap.BackgroundColor3 = v.fill[1]
			cap.BackgroundTransparency = v.fillTransparency
		end
	end
	local edge = button:FindFirstChild("Edge")
	if edge and edge:IsA("UIStroke") then
		edge.Color = v.edge
	end
	local label = button:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		label.TextColor3 = v.text
		local stroke = label:FindFirstChild("TextStroke")
		if stroke and stroke:IsA("UIStroke") then
			stroke.Color = v.textStroke
		end
	end
end

-- Big icon with an optional caption and notification badge (HUD menu buttons, mobile action buttons).
-- Variant colours the tile like a button variant; shape.iconScale lets a theme fill the tile with the icon and lay
-- the caption over its bottom, the way simulator menu tiles do.
function Controls.IconButton(theme: any, props: { [string]: any }): TextButton
	local framed = theme.shape.iconFrame or props.Round == true
	local v = if framed and props.Variant then theme.color.variants[props.Variant] else nil
	local button = make("TextButton", {
		Name = "IconButton",
		Text = "",
		AutoButtonColor = false,
		-- gradient tiles keep a white base because UIGradient multiplies
		BackgroundColor3 = if v then WHITE else theme.color.surface,
		BackgroundTransparency = if v then v.fillTransparency elseif framed then theme.color.surfaceTransparency else 1,
		BorderSizePixel = 0,
		ZIndex = 3,
	})
	Util.place(button, props, UDim2.fromScale(0.08, 0.14))
	Util.aspect(button, 1)
	if v then
		button:SetAttribute("Variant", props.Variant)
		Util.gradient(button, v.fill, 90)
	end
	if framed then
		Util.corner(button, if props.Round then UDim.new(1, 0) else theme.radius.slot)
		Util.stroke(button, if v then v.edge else theme.color.rim, theme.stroke.slot)
	end
	local iconScale = if framed then theme.shape.iconScale or 0.62 else 0.9
	Util.icon(theme, props.Icon, {
		Name = "Icon",
		Size = UDim2.fromScale(iconScale, iconScale),
		Position = UDim2.fromScale(0.5, if props.Caption and framed then (if iconScale > 0.7 then 0.44 else 0.42) else 0.45),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 4,
		Parent = button,
	})
	if props.Caption then
		Util.text(theme, {
			Name = "Caption",
			Text = props.Caption,
			Role = "display",
			Size = if framed then UDim2.fromScale(0.92, 0.26) else UDim2.fromScale(1.2, 0.38),
			Position = UDim2.fromScale(0.5, if framed then 0.86 else 0.84),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 6,
			Parent = button,
		})
	end
	if props.Badge then
		local badge = make("Frame", {
			Name = "Badge",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.86, 0.08),
			Size = UDim2.fromScale(0.55, 0.26),
			BackgroundColor3 = theme.color.variants.danger.fill[1],
			BorderSizePixel = 0,
			ZIndex = 7,
			Parent = button,
		})
		Util.corner(badge, theme.radius.pill)
		Util.stroke(badge, theme.color.textStroke, math.max(1, theme.stroke.slot - 1))
		Util.text(theme, {
			Name = "Label", Text = props.Badge, Role = "display", Size = UDim2.fromScale(0.9, 0.86),
			Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 8, Parent = badge,
		})
	end
	theme.decorate.button(button, theme, "icon")
	Util.tag(button, "Button", theme)
	button.Parent = props.Parent
	return button
end

function Controls.Toggle(theme: any, props: { [string]: any }): TextButton
	local on = props.On == true
	local root = make("TextButton", {
		Name = "Toggle", Text = "", AutoButtonColor = false, BackgroundColor3 = theme.color.track, BorderSizePixel = 0, ZIndex = 3,
	})
	Util.place(root, props, UDim2.fromScale(0.16, 0.6))
	Util.aspect(root, 2.1)
	Util.corner(root, theme.radius.pill)
	Util.stroke(root, theme.color.barEdge, theme.stroke.slot)
	local fill = make("Frame", {
		Name = "Fill", BackgroundColor3 = WHITE, BackgroundTransparency = if on then 0 else 1, BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = root,
	})
	Util.corner(fill, theme.radius.pill)
	Util.gradient(fill, theme.color.variants.success.fill, 90)
	local knob = make("Frame", {
		Name = "Knob", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(if on then 0.73 else 0.27, 0.5),
		Size = UDim2.fromScale(0.8, 0.8), BackgroundColor3 = theme.color.text, BorderSizePixel = 0, ZIndex = 4, Parent = root,
	})
	Util.aspect(knob, 1)
	Util.corner(knob, theme.radius.pill)
	Util.stroke(knob, theme.color.barEdge, math.max(1, theme.stroke.slot - 1))
	root:SetAttribute("On", on)
	Util.tag(root, "Toggle", theme)
	root.Parent = props.Parent
	return root
end

function Controls.Slider(theme: any, props: { [string]: any }): Frame
	local value = math.clamp(props.Value or 0.5, 0, 1)
	local root = make("Frame", { Name = "Slider", BackgroundTransparency = 1, ZIndex = 3 })
	Util.place(root, props, UDim2.fromScale(0.4, 0.5))
	local track = make("Frame", {
		Name = "Track", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromScale(1, 0.34),
		BackgroundColor3 = theme.color.track, BorderSizePixel = 0, ZIndex = 3, Parent = root,
	})
	Util.corner(track, theme.radius.pill)
	Util.stroke(track, theme.color.barEdge, theme.stroke.slot)
	local fill = make("Frame", {
		Name = "Fill", Size = UDim2.fromScale(value, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 3, Parent = track,
	})
	Util.corner(fill, theme.radius.pill)
	Util.gradient(fill, theme.color.variants.primary.fill, 90)
	local knob = make("TextButton", {
		Name = "Knob", Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(value, 0.5),
		Size = UDim2.fromScale(1, 0.95), BackgroundColor3 = theme.color.text, BorderSizePixel = 0, ZIndex = 5, Parent = root,
	})
	Util.aspect(knob, 1).DominantAxis = Enum.DominantAxis.Height
	Util.corner(knob, theme.radius.pill)
	Util.stroke(knob, theme.color.barEdge, theme.stroke.slot)
	root:SetAttribute("Value", value)
	Util.tag(root, "Slider", theme)
	root.Parent = props.Parent
	return root
end

function Controls.TextInput(theme: any, props: { [string]: any }): Frame
	local root = make("Frame", { Name = "TextInput", BackgroundColor3 = theme.color.track, BorderSizePixel = 0, ZIndex = 3 })
	Util.place(root, props, UDim2.fromScale(0.5, 0.1))
	Util.corner(root, theme.radius.control)
	Util.stroke(root, theme.color.barEdge, theme.stroke.slot)
	local box = make("TextBox", {
		Name = "Box", Text = "", PlaceholderText = props.Placeholder or "", PlaceholderColor3 = theme.color.textMuted,
		TextColor3 = theme.color.text, FontFace = theme.font.body, TextScaled = true, ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Size = UDim2.fromScale(0.92, 0.7),
		Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 4, Parent = root,
	})
	make("UITextSizeConstraint", { MaxTextSize = 40, MinTextSize = 6, Parent = box })
	Util.tag(root, "TextInput", theme)
	root.Parent = props.Parent
	return root
end

return Controls
