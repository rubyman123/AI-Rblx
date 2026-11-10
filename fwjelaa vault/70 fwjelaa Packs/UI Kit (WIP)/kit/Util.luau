--!strict
-- Instance and colour helpers shared by every UIKit module. Nothing here yields or needs a player, so it runs
-- the same at edit time (MCP execute_luau) and at runtime.

local Icons = require(script.Parent.Icons)

local Util = {}

-- Strokes are designed for a 600-px-tall screen (roughly Studio's viewport); see scaleStrokes
Util.DESIGN_HEIGHT = 600
local MIN_STROKE_FACTOR = 0.75
local MAX_STROKE_FACTOR = 1.75
local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

function Util.make(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent: Instance? = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(inst :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

-- amount < 0 darkens toward black, amount > 0 lightens toward white (both by up to 1)
function Util.shade(color: Color3, amount: number): Color3
	if amount < 0 then
		return color:Lerp(Color3.new(0, 0, 0), -amount)
	end
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

-- Colour at position t (0..1) along evenly spaced gradient stops
function Util.sample(stops: { Color3 }, t: number): Color3
	if #stops == 1 then
		return stops[1]
	end
	local scaled = math.clamp(t, 0, 1) * (#stops - 1)
	local i = math.min(math.floor(scaled) + 1, #stops - 1)
	return stops[i]:Lerp(stops[i + 1], scaled - (i - 1))
end

function Util.sequence(stops: { Color3 }): ColorSequence
	if #stops == 1 then
		return ColorSequence.new(stops[1])
	end
	local points = {}
	for i, color in stops do
		table.insert(points, ColorSequenceKeypoint.new((i - 1) / (#stops - 1), color))
	end
	return ColorSequence.new(points)
end

-- The gradient carries the colour, so give its parent BackgroundColor3 = white (UIGradient multiplies)
function Util.gradient(parent: Instance, stops: { Color3 }, rotation: number?): UIGradient
	return Util.make("UIGradient", { Color = Util.sequence(stops), Rotation = rotation or 90, Parent = parent })
end

function Util.corner(parent: Instance, radius: UDim): UICorner
	return Util.make("UICorner", { CornerRadius = radius, Parent = parent })
end

-- Border stroke named "Edge". Thickness 0 means the theme wants no border here, so nothing is made.
function Util.stroke(parent: Instance, color: Color3, thickness: number, transparency: number?): UIStroke?
	if thickness <= 0 then
		return nil
	end
	local stroke = Util.make("UIStroke", {
		Name = "Edge",
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = parent,
	})
	stroke:SetAttribute("BaseThickness", thickness)
	return stroke
end

function Util.padding(parent: Instance, all: UDim): UIPadding
	return Util.make("UIPadding", {
		PaddingTop = all, PaddingBottom = all, PaddingLeft = all, PaddingRight = all, Parent = parent,
	})
end

function Util.aspect(parent: Instance, ratio: number): UIAspectRatioConstraint
	return Util.make("UIAspectRatioConstraint", { AspectRatio = ratio, Parent = parent })
end

-- Applies the layout props every builder accepts (Name, Size, Position, AnchorPoint, LayoutOrder, Visible)
function Util.place(inst: GuiObject, props: { [string]: any }, defaultSize: UDim2)
	if props.Name then
		inst.Name = props.Name
	end
	inst.Size = props.Size or defaultSize
	inst.Position = props.Position or UDim2.new()
	inst.AnchorPoint = props.AnchorPoint or Vector2.zero
	inst.LayoutOrder = props.LayoutOrder or 0
	if props.Visible ~= nil then
		inst.Visible = props.Visible
	end
end

export type TextProps = {
	Name: string?,
	Text: string,
	Role: string?, -- "display" | "body" | "number"
	Color: Color3?,
	StrokeColor: Color3?,
	Stroke: number?, -- overrides the theme's text stroke thickness
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	XAlign: Enum.TextXAlignment?,
	MaxTextSize: number?,
	Rotation: number?,
	ZIndex: number?,
	RichText: boolean?,
	Parent: Instance?,
}

-- Every kit label is TextScaled with a size cap, so long text shrinks instead of overflowing
function Util.text(theme: any, props: TextProps): TextLabel
	local role = props.Role or "body"
	local label = Util.make("TextLabel", {
		Name = props.Name or "Label",
		Text = props.Text,
		FontFace = theme.font[role],
		TextColor3 = props.Color or theme.color.text,
		TextScaled = true,
		RichText = props.RichText == true,
		TextXAlignment = props.XAlign or Enum.TextXAlignment.Center,
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Rotation = props.Rotation or 0,
		ZIndex = props.ZIndex or 4,
		Parent = props.Parent,
	})
	Util.make("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 72, MinTextSize = 6, Parent = label })
	local thickness = props.Stroke or (if role == "display" then theme.textStroke.display else theme.textStroke.body)
	if thickness > 0 then
		local stroke = Util.make("UIStroke", {
			Name = "TextStroke",
			Color = props.StrokeColor or theme.color.textStroke,
			Thickness = thickness,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			LineJoinMode = Enum.LineJoinMode.Round,
			Parent = label,
		})
		stroke:SetAttribute("BaseThickness", thickness)
	end
	return label
end

-- An icon is a registry name ("coin", see Icons), an image ("rbxassetid://…", "rbxasset://…", "http…") or a
-- glyph/emoji drawn as text, so the kit works with or without uploads
function Util.icon(theme: any, name: string, props: { [string]: any }): GuiObject
	local value = Icons.get(name)
	local isImage = string.find(value, "^rbx") ~= nil or string.find(value, "^http") ~= nil
	local icon: GuiObject
	if isImage then
		icon = Util.make("ImageLabel", {
			Name = props.Name or "Icon",
			Image = value,
			ScaleType = Enum.ScaleType.Fit,
			BackgroundTransparency = 1,
			Size = props.Size or UDim2.fromScale(1, 1),
			Position = props.Position or UDim2.new(),
			AnchorPoint = props.AnchorPoint or Vector2.zero,
			ZIndex = props.ZIndex or 4,
		})
	else
		icon = Util.text(theme, {
			Name = props.Name or "Icon",
			Text = value,
			Role = "display",
			Stroke = 0,
			MaxTextSize = 200,
			Color = props.Color,
			Size = props.Size,
			Position = props.Position,
			AnchorPoint = props.AnchorPoint,
			ZIndex = props.ZIndex,
		})
	end
	Util.aspect(icon, 1)
	icon.Parent = props.Parent
	return icon
end

function Util.tag(inst: Instance, kind: string, theme: any)
	inst:AddTag("UIKit." .. kind)
	inst:SetAttribute("UIKitTheme", theme.name)
end

function Util.strokeFactor(screenHeight: number): number
	return math.clamp(screenHeight / Util.DESIGN_HEIGHT, MIN_STROKE_FACTOR, MAX_STROKE_FACTOR)
end

-- Pixel strokes look twice as heavy on a phone as on a big monitor. Kit strokes keep their design thickness in
-- BaseThickness; this rescales them (and Path2D rims) for the current screen height.
function Util.scaleStrokes(root: Instance, screenHeight: number)
	local factor = Util.strokeFactor(screenHeight)
	for _, d in root:GetDescendants() do
		if d:IsA("UIStroke") or d:IsA("Path2D") then
			local base = d:GetAttribute("BaseThickness")
			if type(base) == "number" then
				(d :: any).Thickness = math.max(1, base * factor)
			end
		end
	end
end

-- A UIGridLayout with Scale cells inside an auto-sizing ScrollingFrame never settles: the cells scale with the
-- canvas they make grow, so scrolling stops part-way (found in Lift a Rock's Index). Cells are designed in Scale
-- (kept in attributes) and turned into pixels of the visible window here, again whenever the window resizes.
function Util.pixelGrid(layout: UIGridLayout): RBXScriptConnection?
	local scroller = layout.Parent
	local cell = layout:GetAttribute("DesignCell")
	local gap = layout:GetAttribute("DesignGap")
	if not scroller or not scroller:IsA("ScrollingFrame") or typeof(cell) ~= "UDim2" or typeof(gap) ~= "UDim2" then
		return nil
	end
	local aspect = layout:GetAttribute("CellAspect")
	local cellAspect = if type(aspect) == "number" and aspect > 0 then aspect else 1
	local function apply()
		local padding = scroller:FindFirstChildOfClass("UIPadding")
		local inset = if padding then padding.PaddingLeft.Offset + padding.PaddingRight.Offset else 0
		local width = math.max(0, scroller.AbsoluteSize.X - scroller.ScrollBarThickness - inset)
		local cellWidth = math.floor(cell.X.Scale * width + cell.X.Offset)
		layout.CellSize = UDim2.fromOffset(cellWidth, math.floor(cellWidth / cellAspect))
		layout.CellPadding = UDim2.fromOffset(math.floor(gap.X.Scale * width + gap.X.Offset), math.floor(gap.Y.Scale * width + gap.Y.Offset))
	end
	apply()
	return scroller:GetPropertyChangedSignal("AbsoluteSize"):Connect(apply)
end

-- 999.6 -> "1K", 999999 -> "1M", -2500 -> "-2.5K". Values that would round up to 1000 move to the next suffix.
function Util.abbreviate(n: number): string
	if n ~= n then
		return "0"
	end
	local sign = if n < 0 then "-" else ""
	local value = math.abs(n)
	if value < 999.5 then
		return sign .. tostring(math.floor(value + 0.5))
	end
	local i = 1
	repeat
		value /= 1000
		i += 1
	until value < 999.95 or i == #SUFFIXES
	local text = (string.gsub(string.format("%.1f", value), "%.0$", ""))
	return sign .. text .. SUFFIXES[i]
end

return Util
