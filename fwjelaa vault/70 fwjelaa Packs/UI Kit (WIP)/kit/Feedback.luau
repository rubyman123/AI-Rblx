--!strict
-- Moments: toasts, reward popups, level-up splashes and damage numbers. Motion animates them; these builders
-- only make the pieces.

local Util = require(script.Parent.Util)
local Decor = require(script.Parent.Decor)
local Containers = require(script.Parent.Containers)
local Controls = require(script.Parent.Controls)
local make = Util.make

local Feedback = {}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

function Feedback.Toast(theme: any, props: { [string]: any }): Frame
	local kind = props.Kind or "accent"
	local toast = make("Frame", {
		Name = "Toast", BackgroundColor3 = theme.color.base, BackgroundTransparency = math.max(theme.color.baseTransparency, 0.1),
		BorderSizePixel = 0, ZIndex = 10,
	})
	-- pixel height: a Scale height inside the stack's list would follow the stack, not the text
	Util.place(toast, props, UDim2.new(1, 0, 0, 44))
	Util.corner(toast, theme.radius.control)
	Util.stroke(toast, theme.color.barEdge, theme.stroke.slot)
	local stripe = make("Frame", {
		Name = "Stripe", BackgroundColor3 = WHITE, BorderSizePixel = 0, Size = UDim2.new(0, 6, 1, 0), ZIndex = 11, Parent = toast,
	})
	Util.corner(stripe, theme.radius.control)
	Util.gradient(stripe, theme.color.bars[kind], 90)
	Util.text(theme, {
		Name = "Label", Text = props.Text, Role = "display", XAlign = Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(0.88, 0.7), Position = UDim2.fromScale(0.07, 0.15), ZIndex = 12, Parent = toast,
	})
	toast:SetAttribute("Kind", kind)
	theme.decorate.slot(toast, theme)
	Util.tag(toast, "Toast", theme)
	toast.Parent = props.Parent
	return toast
end

function Feedback.ToastStack(theme: any, props: { [string]: any }): Frame
	local stack = make("Frame", { Name = "Toasts", BackgroundTransparency = 1, ZIndex = 10 })
	Util.place(stack, props, UDim2.fromScale(0.26, 0.5))
	if not props.Position then
		stack.AnchorPoint = Vector2.new(1, 0)
		stack.Position = UDim2.fromScale(0.99, 0.12)
	end
	make("UIListLayout", {
		Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = stack,
	})
	Feedback.Toast(theme, { Name = "Template", Text = "Template", Visible = false, Parent = stack })
	Util.tag(stack, "ToastStack", theme)
	stack.Parent = props.Parent
	return stack
end

-- Modal: dims the screen and shows a small panel with an optional rewarded item, a message and buttons
function Feedback.Popup(theme: any, props: { [string]: any }): Frame
	local dim = make("Frame", {
		Name = props.Name or "Popup", BackgroundColor3 = BLACK, BackgroundTransparency = 0.45, BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1), ZIndex = 20,
	})
	local _, body = Containers.Panel(theme, {
		Title = props.Title, Body = "none", AspectRatio = 1.15, Size = UDim2.fromScale(0.5, 0.56),
		Position = UDim2.fromScale(0.5, 0.52), Parent = dim,
	})
	if props.Icon then
		local reward = make("Frame", {
			Name = "Reward", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.02),
			Size = UDim2.fromScale(0.5, 0.5), ZIndex = 3, Parent = body,
		})
		Util.aspect(reward, 1)
		Decor.rays(reward, theme.color.bars.xp[1], 14, 0.55, 1.5)
		Util.icon(theme, props.Icon, {
			Name = "Icon", Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 5, Parent = reward,
		})
	end
	if props.Body then
		Util.text(theme, {
			Name = "Message", Text = props.Body, Role = "display", Size = UDim2.fromScale(0.9, 0.16),
			Position = UDim2.fromScale(0.5, if props.Icon then 0.58 else 0.3), AnchorPoint = Vector2.new(0.5, 0),
			ZIndex = 5, Parent = body,
		})
	end
	local actions = make("Frame", {
		Name = "Actions", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.98),
		Size = UDim2.fromScale(0.9, 0.18), ZIndex = 4, Parent = body,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0.04, 0), SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = actions,
	})
	if props.Cancel then
		Controls.Button(theme, {
			Name = "Cancel", Text = props.Cancel, Variant = "secondary", Size = UDim2.fromScale(0.42, 1), LayoutOrder = 1, Parent = actions,
		})
	end
	if props.Confirm then
		Controls.Button(theme, {
			Name = "Confirm", Text = props.Confirm, Variant = "success", Size = UDim2.fromScale(0.42, 1), LayoutOrder = 2, Parent = actions,
		})
	end
	Util.tag(dim, "Popup", theme)
	dim.Parent = props.Parent
	return dim
end

-- "LEVEL UP!" / "X2 LUCK" banner with rays behind it
function Feedback.Splash(theme: any, props: { [string]: any }): Frame
	local stops = theme.color.bars[props.Kind or "xp"]
	local splash = make("Frame", { Name = "Splash", BackgroundTransparency = 1, ZIndex = 15 })
	Util.place(splash, props, UDim2.fromScale(0.6, 0.2))
	if not props.Position then
		splash.AnchorPoint = Vector2.new(0.5, 0.5)
		splash.Position = UDim2.fromScale(0.5, 0.2)
	end
	Util.aspect(splash, 3)
	Decor.rays(splash, stops[1], 18, 0.5, 1.3)
	local text = Util.text(theme, {
		Name = "Text", Text = props.Text, Role = "display", Stroke = math.max(theme.textStroke.display, 3),
		Size = UDim2.fromScale(1, 0.8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
		MaxTextSize = 120, ZIndex = 16, Parent = splash,
	})
	Util.gradient(text, stops, 90)
	Util.tag(splash, "Splash", theme)
	splash.Parent = props.Parent
	return splash
end

-- Always outlined, whatever the theme's text stroke: it floats over the 3D world
function Feedback.DamageNumber(theme: any, props: { [string]: any }): TextLabel
	local crit = props.Crit == true
	local label = Util.text(theme, {
		Name = props.Name or "Damage",
		Text = props.Amount .. (if crit then "!" else ""),
		Role = "number",
		Color = if crit then theme.color.bars.accent[1] else theme.color.text,
		Stroke = math.max(theme.textStroke.display, 2.5),
		Size = if crit then UDim2.fromScale(0.16, 0.1) else UDim2.fromScale(0.11, 0.07),
		Position = props.Position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = if crit then -8 else 0,
		MaxTextSize = 96,
		ZIndex = 25,
		Parent = props.Parent,
	})
	Util.tag(label, "DamageNumber", theme)
	return label
end

return Feedback
