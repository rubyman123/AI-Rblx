--!strict
-- Signature details that themes bolt onto components. Everything is procedural so it works with zero uploaded
-- assets; when a theme has uploaded textures (theme.assets) those are used instead.

local Util = require(script.Parent.Util)
local make = Util.make

local Decor = {}

-- From the Studio spike. DOT_TILE is a client-bundled texture: fine for polish, not guaranteed forever.
-- UIBlur showed no visible blur over GUI, so glass stays off.
Decor.DOT_TILE = "rbxasset://textures/whiteCircle.png" :: string?
Decor.USE_UISHADOW = true
Decor.USE_UIBLUR = false

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local CORNERS = { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) }

-- A square whose UIGradient hides one diagonal half. rotation picks the visible half:
-- 45 = bottom-right, 135 = bottom-left, 225 = top-left, -45 = top-right
local TRIANGLE_HIDE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.499, 1),
	NumberSequenceKeypoint.new(0.501, 0),
	NumberSequenceKeypoint.new(1, 0),
})

function Decor.triangle(parent: Instance, name: string, color: Color3, transparency: number, rotation: number, props: { [string]: any }): Frame
	local tri = make("Frame", {
		Name = name,
		BackgroundColor3 = color,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		ZIndex = props.ZIndex or 1,
		Parent = parent,
	})
	make("UIGradient", { Rotation = rotation, Transparency = TRIANGLE_HIDE, Parent = tri })
	return tri
end

local function stripShapeOf(frame: GuiObject)
	for _, child in frame:GetChildren() do
		if child:IsA("UICorner") or (child:IsA("UIStroke") and child.Name == "Edge") then
			child:Destroy()
		end
	end
end

function Decor.tile(parent: GuiObject, image: string, tilePx: number, transparency: number, radius: UDim?, color: Color3?): ImageLabel
	local tile = make("ImageLabel", {
		Name = "Texture",
		Image = image,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(tilePx, tilePx),
		ImageTransparency = transparency,
		ImageColor3 = color or WHITE,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = parent,
	})
	if radius then
		Util.corner(tile, radius)
	end
	return tile
end

-- Stud field: the theme's uploaded stud tile if there is one, else the built-in dot tile
function Decor.studs(parent: GuiObject, theme: any, transparency: number, tilePx: number, radius: UDim?)
	local image = theme.assets.studTile or Decor.DOT_TILE
	if image then
		Decor.tile(parent, image, tilePx, transparency, radius)
	end
end

-- Halftone dots over a region (screentone). Fade = gradient rotation that fades the dots out across the region.
function Decor.dots(parent: GuiObject, color: Color3, transparency: number, tilePx: number, props: { [string]: any }?): ImageLabel?
	if not Decor.DOT_TILE then
		return nil
	end
	local p = props or {}
	local field = Decor.tile(parent, Decor.DOT_TILE, tilePx, transparency, nil, color)
	field.Name = "Screentone"
	field.Size = p.Size or UDim2.fromScale(1, 1)
	field.Position = p.Position or UDim2.new()
	field.AnchorPoint = p.AnchorPoint or Vector2.zero
	if p.Fade then
		make("UIGradient", { Rotation = p.Fade, Transparency = NumberSequence.new(0, 1), Parent = field })
	end
	return field
end

-- Soft light on the top half only (flat reference buttons: no streaks)
function Decor.shine(parent: GuiObject, strength: number, radius: UDim?)
	local shine = make("Frame", {
		Name = "Shine", BackgroundColor3 = WHITE, BorderSizePixel = 0, Size = UDim2.fromScale(1, 0.5), ZIndex = 2, Parent = parent,
	})
	if radius then
		Util.corner(shine, radius)
	end
	make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1 - strength * 0.7, 1), Parent = shine })
end

-- Diagonal gloss streaks plus a soft top shine (the "Streaks" overlay on Lift a Rock buttons)
function Decor.gloss(parent: GuiObject, strength: number, radius: UDim?)
	local clear = 1 - strength
	local band = make("Frame", {
		Name = "Gloss", BackgroundColor3 = WHITE, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = parent,
	})
	if radius then
		Util.corner(band, radius)
	end
	make("UIGradient", {
		Rotation = -60,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 1), NumberSequenceKeypoint.new(0.26, clear),
			NumberSequenceKeypoint.new(0.34, clear), NumberSequenceKeypoint.new(0.4, 1), NumberSequenceKeypoint.new(0.46, 1),
			NumberSequenceKeypoint.new(0.5, (1 + clear) / 2), NumberSequenceKeypoint.new(0.54, 1), NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = band,
	})
	local shine = make("Frame", {
		Name = "Shine", BackgroundColor3 = WHITE, BorderSizePixel = 0, Size = UDim2.fromScale(1, 0.5), ZIndex = 2, Parent = parent,
	})
	if radius then
		Util.corner(shine, radius)
	end
	make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1 - strength * 0.7, 1), Parent = shine })
end

-- Native drop shadow. Returns false when UIShadow is off so callers can fall back.
function Decor.shadow(frame: GuiObject, color: Color3, offset: Vector2, blur: number, transparency: number): boolean
	if not Decor.USE_UISHADOW then
		return false
	end
	make("UIShadow", {
		Name = "Shadow",
		Color = color,
		Offset = UDim2.fromOffset(offset.X, offset.Y),
		BlurRadius = UDim.new(0, blur),
		Transparency = transparency,
		Parent = frame,
	})
	return true
end

-- Solid offset shadow (comic / manga). The fallback draws the frame's fill on a child "Face" so a child "Drop"
-- can sit under it: children always draw above their parent's own background.
function Decor.hardShadow(frame: GuiObject, color: Color3, offset: Vector2)
	if Decor.shadow(frame, color, offset, 0, 0) then
		return
	end
	local face = make("Frame", {
		Name = "Face",
		BackgroundColor3 = frame.BackgroundColor3,
		BackgroundTransparency = frame.BackgroundTransparency,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		Parent = frame,
	})
	local drop = make("Frame", {
		Name = "Drop", BackgroundColor3 = color, BorderSizePixel = 0, Position = UDim2.fromOffset(offset.X, offset.Y),
		Size = UDim2.fromScale(1, 1), ZIndex = -1, Parent = frame,
	})
	local corner = frame:FindFirstChildOfClass("UICorner")
	if corner then
		corner:Clone().Parent = face
		corner:Clone().Parent = drop
	end
	local gradient = frame:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Parent = face
	end
	frame.BackgroundTransparency = 1
end

function Decor.glow(frame: GuiObject, color: Color3, blur: number?)
	Decor.shadow(frame, color, Vector2.zero, blur or 14, 0.5)
end

-- Frosted glass behind translucent panels
function Decor.glass(frame: GuiObject)
	if Decor.USE_UIBLUR then
		make("UIBlur", { Name = "Glass", Parent = frame })
	end
end

-- Cut-corner shape (Cyber Holo, Battlegrounds menus). UICorner only rounds and ClipsDescendants ignores shapes,
-- so the fill is rebuilt from 3 strips + 4 corner triangles and the rim is a closed Path2D through the cut points.
function Decor.chamfer(frame: GuiObject, cut: number, rim: Color3?, rimThickness: number?): Frame
	local color, transparency = frame.BackgroundColor3, frame.BackgroundTransparency
	frame.BackgroundTransparency = 1
	stripShapeOf(frame)
	local shape = make("Frame", { Name = "Shape", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 0, Parent = frame })
	local function strip(name: string, position: UDim2, size: UDim2)
		make("Frame", {
			Name = name, BackgroundColor3 = color, BackgroundTransparency = transparency, BorderSizePixel = 0,
			Position = position, Size = size, ZIndex = 0, Parent = shape,
		})
	end
	strip("Middle", UDim2.fromOffset(cut, 0), UDim2.new(1, -2 * cut, 1, 0))
	strip("Left", UDim2.fromOffset(0, cut), UDim2.new(0, cut, 1, -2 * cut))
	strip("Right", UDim2.new(1, -cut, 0, cut), UDim2.new(0, cut, 1, -2 * cut))
	local square = UDim2.fromOffset(cut, cut)
	Decor.triangle(shape, "TL", color, transparency, 45, { Size = square, ZIndex = 0 })
	Decor.triangle(shape, "TR", color, transparency, 135, { Size = square, Position = UDim2.new(1, -cut, 0, 0), ZIndex = 0 })
	Decor.triangle(shape, "BR", color, transparency, 225, { Size = square, Position = UDim2.new(1, -cut, 1, -cut), ZIndex = 0 })
	Decor.triangle(shape, "BL", color, transparency, -45, { Size = square, Position = UDim2.new(0, 0, 1, -cut), ZIndex = 0 })
	if rim and rimThickness and rimThickness > 0 then
		local path = make("Path2D", { Name = "Rim", Closed = true, Color3 = rim, Thickness = rimThickness, ZIndex = 6, Parent = frame })
		path:SetAttribute("BaseThickness", rimThickness)
		path:SetControlPoints({
			Path2DControlPoint.new(UDim2.fromOffset(cut, 0)),
			Path2DControlPoint.new(UDim2.new(1, -cut, 0, 0)),
			Path2DControlPoint.new(UDim2.new(1, 0, 0, cut)),
			Path2DControlPoint.new(UDim2.new(1, 0, 1, -cut)),
			Path2DControlPoint.new(UDim2.new(1, -cut, 1, 0)),
			Path2DControlPoint.new(UDim2.new(0, cut, 1, 0)),
			Path2DControlPoint.new(UDim2.new(0, 0, 1, -cut)),
			Path2DControlPoint.new(UDim2.fromOffset(0, cut)),
		})
	end
	return shape
end

-- 45° parallelogram (Kinetic Comic buttons, ultimate banners): the root's flat fill is the middle and two
-- square triangle caps hang off its ends. Flat colours only: a cap can't also carry a colour gradient.
function Decor.slant(frame: GuiObject)
	stripShapeOf(frame)
	local function cap(name: string, anchorX: number, positionX: number, rotation: number)
		local c = Decor.triangle(frame, name, frame.BackgroundColor3, frame.BackgroundTransparency, rotation, {
			Size = UDim2.fromScale(1, 1), AnchorPoint = Vector2.new(anchorX, 0), Position = UDim2.fromScale(positionX, 0), ZIndex = 0,
		})
		Util.aspect(c, 1).DominantAxis = Enum.DominantAxis.Height
	end
	cap("CapL", 1, 0, 45)
	cap("CapR", 0, 1, 225)
end

-- Comic starburst: overlapping squares rotated evenly make a 4n-point star
function Decor.burst(parent: GuiObject, color: Color3, spikes: number, scale: number): Frame
	local holder = make("Frame", {
		Name = "Burst", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(scale, scale), ZIndex = 0, Parent = parent,
	})
	Util.aspect(holder, 1)
	local squares = math.max(2, math.floor(spikes / 4))
	for i = 1, squares do
		make("Frame", {
			Name = "Spike", BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.7, 0.7), Rotation = (90 / squares) * (i - 1),
			ZIndex = 0, Parent = holder,
		})
	end
	return holder
end

-- Each ray sits in its own centred "Arm": GuiObjects rotate around their own centre, not their anchor, so
-- rotating the arm swings the ray around the middle
local function radial(parent: GuiObject, name: string, scale: number, count: number, ray: (arm: Frame, i: number) -> ()): Frame
	local holder = make("Frame", {
		Name = name, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(scale, scale), ZIndex = 0, Parent = parent,
	})
	Util.aspect(holder, 1)
	for i = 1, count do
		local arm = make("Frame", {
			Name = "Arm", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Rotation = (360 / count) * (i - 1),
			ZIndex = 0, Parent = holder,
		})
		ray(arm, i)
	end
	return holder
end

function Decor.rays(parent: GuiObject, color: Color3, count: number, transparency: number, scale: number?): Frame
	return radial(parent, "Rays", scale or 1, count, function(arm, _)
		local ray = make("Frame", {
			Name = "Ray", BackgroundColor3 = color, BackgroundTransparency = transparency, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.06, 0.5),
			ZIndex = 0, Parent = arm,
		})
		make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = ray })
	end)
end

-- Manga speed lines: thin rays with an empty centre, slightly uneven
function Decor.speedlines(parent: GuiObject, color: Color3, count: number, scale: number?): Frame
	return radial(parent, "Speedlines", scale or 2.2, count, function(arm, i)
		arm.Rotation += (i % 3) * 2.5
		local line = make("Frame", {
			Name = "Line", BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 0.32), Size = UDim2.fromScale(0.003 + (i % 3) * 0.002, 0.32),
			ZIndex = 0, Parent = arm,
		})
		make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0, 1), Parent = line })
	end)
end

function Decor.scanlines(parent: GuiObject, color: Color3, transparency: number, spacingPx: number, maxLines: number): Frame
	local holder = make("Frame", {
		Name = "Scanlines", BackgroundTransparency = 1, ClipsDescendants = true, Size = UDim2.fromScale(1, 1), ZIndex = 8, Parent = parent,
	})
	make("UIListLayout", { Padding = UDim.new(0, math.max(0, spacingPx - 1)), SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder })
	for i = 1, maxLines do
		make("Frame", {
			Name = "Line", BackgroundColor3 = color, BackgroundTransparency = transparency, BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 1), LayoutOrder = i, Parent = holder,
		})
	end
	return holder
end

-- HUD corner brackets, drawn outsetPx outside the frame
function Decor.brackets(parent: GuiObject, color: Color3, lengthPx: number, thickness: number, outsetPx: number)
	for _, corner in CORNERS do
		local position = UDim2.new(
			corner.X, if corner.X == 0 then -outsetPx else outsetPx,
			corner.Y, if corner.Y == 0 then -outsetPx else outsetPx
		)
		make("Frame", {
			Name = "BracketH", BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = corner, Position = position,
			Size = UDim2.fromOffset(lengthPx, thickness), ZIndex = 7, Parent = parent,
		})
		make("Frame", {
			Name = "BracketV", BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = corner, Position = position,
			Size = UDim2.fromOffset(thickness, lengthPx), ZIndex = 7, Parent = parent,
		})
	end
end

-- A second outline nudged off-register, like a hand-inked panel
function Decor.ink(frame: GuiObject, color: Color3, thickness: number, offsetPx: number)
	local ghost = make("Frame", {
		Name = "InkGhost", BackgroundTransparency = 1, Position = UDim2.fromOffset(offsetPx, -offsetPx / 2),
		Size = UDim2.new(1, -offsetPx / 2, 1, offsetPx / 2), ZIndex = 7, Parent = frame,
	})
	Util.stroke(ghost, color, thickness)
end

-- Thin inner frame plus diamond gems on the corners (Dark Fantasy)
function Decor.ornate(frame: GuiObject, color: Color3, insetPx: number, gemPx: number)
	local inner = make("Frame", {
		Name = "InnerFrame", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -2 * insetPx, 1, -2 * insetPx), ZIndex = 7, Parent = frame,
	})
	Util.stroke(inner, color, 1, 0.45)
	for _, corner in CORNERS do
		local gem = make("Frame", {
			Name = "Gem", BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(corner.X, corner.Y), Size = UDim2.fromOffset(gemPx, gemPx), Rotation = 45, ZIndex = 8, Parent = frame,
		})
		Util.stroke(gem, BLACK, 1)
	end
end

-- Fading line with a diamond in the middle
function Decor.divider(parent: GuiObject, color: Color3, props: { [string]: any }?): Frame
	local p = props or {}
	local line = make("Frame", {
		Name = "Divider", BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = p.Position or UDim2.fromScale(0.5, 1.12), Size = p.Size or UDim2.new(0.9, 0, 0, 1), ZIndex = 7, Parent = parent,
	})
	make("UIGradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }),
		Parent = line,
	})
	make("Frame", {
		Name = "Gem", BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(7, 7), Rotation = 45, ZIndex = 8, Parent = line,
	})
	return line
end

-- Darkens the top and bottom of a full-screen background
function Decor.vignette(parent: GuiObject, color: Color3, strength: number)
	for _, rotation in { 90, -90 } do
		local atBottom = rotation == 90
		local band = make("Frame", {
			Name = "Vignette", BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, if atBottom then 1 else 0),
			Position = UDim2.fromScale(0, if atBottom then 1 else 0), Size = UDim2.fromScale(1, 0.45), ZIndex = 0, Parent = parent,
		})
		make("UIGradient", { Rotation = rotation, Transparency = NumberSequence.new(1, 1 - strength), Parent = band })
	end
end

-- Scattered glowing specks; positions come from the index so every build looks the same
function Decor.embers(parent: GuiObject, color: Color3, count: number)
	for i = 1, count do
		local size = 2 + (i % 3) * 2
		local ember = make("Frame", {
			Name = "Ember", BackgroundColor3 = color, BackgroundTransparency = 0.2 + (i % 4) * 0.15, BorderSizePixel = 0,
			Position = UDim2.fromScale(((i * 37) % 100) / 100, ((i * 61) % 100) / 100), Size = UDim2.fromOffset(size, size),
			ZIndex = 1, Parent = parent,
		})
		Util.corner(ember, UDim.new(1, 0))
	end
end

-- A long rotated band (Battlegrounds / comic backgrounds)
function Decor.slash(parent: GuiObject, color: Color3, rotation: number, props: { [string]: any }?): Frame
	local p = props or {}
	return make("Frame", {
		Name = "Slash", BackgroundColor3 = color, BackgroundTransparency = p.Transparency or 0, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = p.Position or UDim2.fromScale(0.5, 0.5),
		Size = p.Size or UDim2.fromScale(1.6, 0.08), Rotation = rotation, ZIndex = 0, Parent = parent,
	})
end

-- Ruler ticks under a header (Cyber Holo)
function Decor.ticks(parent: GuiObject, color: Color3, count: number)
	local holder = make("Frame", {
		Name = "Ruler", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 5),
		Size = UDim2.new(1, 0, 0, 4), ZIndex = 7, Parent = parent,
	})
	for i = 0, count do
		make("Frame", {
			Name = "Tick", BackgroundColor3 = color, BorderSizePixel = 0, Position = UDim2.fromScale(i / count, 0),
			Size = UDim2.new(0, 1, if i % 4 == 0 then 1 else 0.5, 0), ZIndex = 7, Parent = holder,
		})
	end
end

return Decor
