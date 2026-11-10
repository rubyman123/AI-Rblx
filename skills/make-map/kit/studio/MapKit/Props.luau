-- Stylized props from primitives, the 2026 simulator look. Method by fwjelaa (FWJ STUDIOS).
-- Sizes suit a 5-stud character. Every recipe takes (cf, opts): cf is the prop's base centre on the ground,
-- cf.LookVector its front, opts.rng a Random for variation. It returns an unparented Model built in place.
local Build = require(script.Parent.Build)
local Geo = require(script.Parent.Geo)

local Props = {}

local function hex(h)
	return Color3.fromHex(h)
end

local function shade(c, rng, amount)
	local h, s, v = c:ToHSV()
	return Color3.fromHSV(h, s, math.clamp(v + rng:NextNumber(-amount, amount), 0, 1))
end

local function newModel(name, cf)
	local m = Instance.new("Model")
	m.Name = name
	m.WorldPivot = cf
	return m
end

local function rngOf(opts)
	return opts and opts.rng or Random.new(1)
end

local function ball(m, pos, d, color)
	return Build.part({ Shape = Enum.PartType.Ball, Size = Vector3.one * d, CFrame = CFrame.new(pos), Color = color, Parent = m })
end

-- A cylinder standing along cf's UpVector, centred on cf (a Part cylinder's own axis is X).
local function column(m, cf, height, d, color)
	return Build.part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, d, d),
		CFrame = cf * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Parent = m,
	})
end

-- Small random lean and a random spin so copies never line up.
local function natural(cf, rng, lean)
	lean = lean or 4
	return cf * CFrame.Angles(math.rad(rng:NextNumber(-lean, lean)), rng:NextNumber(0, 2 * math.pi), math.rad(rng:NextNumber(-lean, lean)))
end

-- Pyramid tier: `sides` triangles from a ring to an apex, plus a disc underneath.
local function cone(m, cf, radius, height, color, sides)
	local apex = (cf * CFrame.new(0, height, 0)).Position
	local inside = (cf * CFrame.new(0, height * 0.3, 0)).Position
	local ring = {}
	for i = 0, sides - 1 do
		local a = i / sides * 2 * math.pi
		ring[i + 1] = (cf * CFrame.new(math.cos(a) * radius, 0, math.sin(a) * radius)).Position
	end
	for i = 1, sides do
		Geo.tri(ring[i], ring[i % sides + 1], apex, 0.4, { Color = color }, m, inside)
	end
	column(m, cf * CFrame.new(0, 0.2, 0), 0.4, radius * 1.72, color)
end

function Props.tree(cf, opts)
	opts = opts or {}
	local rng = rngOf(opts)
	local s = opts.scale or rng:NextNumber(0.85, 1.2)
	local m = newModel("Tree", cf)
	local base = natural(cf, rng)
	local trunkH = 10 * s
	column(m, base * CFrame.new(0, trunkH / 2 - 0.5, 0), trunkH, 1.8 * s, hex(opts.trunk or "#694028"))
	local leaf = hex(opts.leaf or "#5B9A4C")
	local dark = hex(opts.leafDark or "#348E40")
	local top = base * CFrame.new(0, trunkH + 2 * s, 0)
	local crown = {
		ball(m, top.Position, 10 * s, leaf),
		ball(m, (top * CFrame.new(4 * s, -1.5 * s, 0)).Position, 7 * s, shade(leaf, rng, 0.05)),
		ball(m, (top * CFrame.new(-4 * s, -1 * s, 1 * s)).Position, 7 * s, dark),
		ball(m, (top * CFrame.new(0.5 * s, 3.5 * s, -1 * s)).Position, 5 * s, shade(leaf, rng, 0.06)),
	}
	if rng:NextNumber() < 0.5 then
		table.insert(crown, ball(m, (top * CFrame.new(-1 * s, -2 * s, -4 * s)).Position, 5 * s, dark))
	end
	for _, p in crown do
		Build.decor(p)
	end
	return m
end

function Props.pine(cf, opts)
	opts = opts or {}
	local rng = rngOf(opts)
	local s = opts.scale or rng:NextNumber(0.85, 1.25)
	local m = newModel("Pine", cf)
	local base = natural(cf, rng, 3)
	local green = hex(opts.color or "#27462D")
	local tiers = { { 3, 6, 7 }, { 7, 4.5, 6 }, { 10.5, 3, 5 } } -- base height, radius, height
	for i, tier in tiers do
		local tcf = base * CFrame.new(0, tier[1] * s, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		local col = (opts.snow and i == #tiers) and hex("#F8F8F8") or shade(green, rng, 0.04)
		cone(m, tcf, tier[2] * s, tier[3] * s, col, 6)
	end
	Build.decor(m)
	local trunk = column(m, base * CFrame.new(0, 2 * s - 0.3, 0), 4 * s, 1.5 * s, hex(opts.trunk or "#694028"))
	trunk.CanCollide, trunk.CanQuery, trunk.CanTouch = true, true, true
	return m
end

-- Scenery rock: a squat faceted lump with a darker chip beside it (measured: tilted blocks and octahedra both
-- read as boxes or pyramids from eye level; the icosahedron lump reads as rock).
function Props.rock(cf, opts)
	opts = opts or {}
	local rng = rngOf(opts)
	local s = opts.scale or rng:NextNumber(0.8, 1.4)
	local m = newModel("Rock", cf)
	local main = Props.boulder(cf, { rng = rng, radius = 2.6 * s, squash = 0.7, color = opts.color or "#A9A8AB" })
	for _, p in main:GetChildren() do
		p.Parent = m
	end
	if rng:NextNumber() < 0.6 then
		local chip = Props.boulder(cf * CFrame.new(2.8 * s, 0, 1.4 * s), { rng = rng, radius = 1.2 * s, squash = 0.75, color = opts.dark or "#635F62" })
		for _, p in chip:GetChildren() do
			p.Parent = m
		end
	end
	return m
end

function Props.bush(cf, opts)
	opts = opts or {}
	local rng = rngOf(opts)
	local s = opts.scale or rng:NextNumber(0.8, 1.3)
	local m = newModel("Bush", cf)
	local c = hex(opts.color or "#7C9C6B")
	for _ = 1, rng:NextInteger(3, 4) do
		local d = rng:NextNumber(3, 4.5) * s
		local off = Vector3.new(rng:NextNumber(-2, 2) * s, d * 0.25, rng:NextNumber(-2, 2) * s)
		ball(m, (cf * CFrame.new(off)).Position, d, shade(c, rng, 0.06))
	end
	return Build.decor(m)
end

function Props.cloud(cf, opts)
	opts = opts or {}
	local rng = rngOf(opts)
	local s = opts.scale or rng:NextNumber(0.8, 1.4)
	local m = newModel("Cloud", cf)
	local n = rng:NextInteger(5, 7)
	for i = 1, n do
		local d = (i == math.ceil(n / 2) and 12 or rng:NextNumber(6, 10)) * s
		ball(m, (cf * CFrame.new((i - (n + 1) / 2) * 4.5 * s, d * 0.15, rng:NextNumber(-2, 2) * s)).Position, d, hex("#F8F8F8"))
	end
	Build.decor(m)
	for _, p in m:GetChildren() do
		p.CastShadow = false
	end
	return m
end

function Props.crate(cf, opts)
	opts = opts or {}
	local rng = rngOf(opts)
	local s = opts.scale or rng:NextNumber(0.9, 1.15)
	local m = newModel("Crate", cf)
	local size = Vector3.new(3, 3, 3) * s
	local body = natural(cf, rng, 0) * CFrame.new(0, size.Y / 2, 0)
	Build.part({ Size = size, CFrame = body, Color = hex(opts.color or "#CC8E69"), Parent = m })
	local trim = hex(opts.trim or "#694028")
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Build.decor(Build.part({
				Size = Vector3.new(0.4, size.Y + 0.05, 0.4),
				CFrame = body * CFrame.new(sx * (size.X / 2 - 0.15), 0, sz * (size.Z / 2 - 0.15)),
				Color = trim,
				Parent = m,
			}))
		end
	end
	return m
end

function Props.flower(cf, opts)
	opts = opts or {}
	local rng = rngOf(opts)
	local m = newModel("Flower", cf)
	local colors = opts.colors or { "#F5CD30", "#FF5959", "#FF98DC", "#B1A7FF" }
	local petal = hex(colors[rng:NextInteger(1, #colors)])
	column(m, cf * CFrame.new(0, 0.6, 0), 1.2, 0.25, hex("#348E40"))
	local head = cf * CFrame.new(0, 1.4, 0)
	ball(m, head.Position, 0.5, hex("#F5CD30"))
	for i = 0, 4 do
		local a = i / 5 * 2 * math.pi
		ball(m, (head * CFrame.new(math.cos(a) * 0.45, 0, math.sin(a) * 0.45)).Position, 0.55, petal)
	end
	return Build.decor(m)
end

function Props.cactus(cf, opts)
	opts = opts or {}
	local rng = rngOf(opts)
	local s = opts.scale or rng:NextNumber(0.8, 1.3)
	local m = newModel("Cactus", cf)
	local g = hex(opts.color or "#5B9A4C")
	local base = natural(cf, rng, 3)
	local h = 8 * s
	column(m, base * CFrame.new(0, h / 2, 0), h, 2 * s, g)
	ball(m, (base * CFrame.new(0, h, 0)).Position, 2 * s, g)
	for _, side in { -1, 1 } do
		if rng:NextNumber() < 0.8 then
			local y = rng:NextNumber(0.35, 0.6) * h
			local armH = rng:NextNumber(2, 3.5) * s
			Build.part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(2 * s, 1.4 * s, 1.4 * s), CFrame = base * CFrame.new(side * 1.5 * s, y, 0), Color = g, Parent = m })
			column(m, base * CFrame.new(side * 2.4 * s, y + armH / 2, 0), armH, 1.4 * s, g)
			ball(m, (base * CFrame.new(side * 2.4 * s, y + armH, 0)).Position, 1.4 * s, g)
		end
	end
	return m
end

function Props.deadTree(cf, opts)
	opts = opts or {}
	local rng = rngOf(opts)
	local s = opts.scale or rng:NextNumber(0.8, 1.2)
	local m = newModel("DeadTree", cf)
	local c = hex(opts.color or "#562424")
	local base = natural(cf, rng, 6)
	local h = 12 * s
	column(m, base * CFrame.new(0, h / 2 - 0.5, 0), h, 1.4 * s, c)
	for _ = 1, rng:NextInteger(2, 3) do
		local y = rng:NextNumber(0.45, 0.85) * h
		local len = rng:NextNumber(3, 5) * s
		local branch = base * CFrame.new(0, y, 0) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), math.rad(rng:NextNumber(35, 60)))
		Build.decor(column(m, branch * CFrame.new(0, len / 2, 0), len, 0.7 * s, c))
	end
	return m
end

local ICO = (function()
	local g = (1 + math.sqrt(5)) / 2
	local raw = {
		{ -1, g, 0 }, { 1, g, 0 }, { -1, -g, 0 }, { 1, -g, 0 },
		{ 0, -1, g }, { 0, 1, g }, { 0, -1, -g }, { 0, 1, -g },
		{ g, 0, -1 }, { g, 0, 1 }, { -g, 0, -1 }, { -g, 0, 1 },
	}
	local faces = {
		{ 1, 12, 6 }, { 1, 6, 2 }, { 1, 2, 8 }, { 1, 8, 11 }, { 1, 11, 12 },
		{ 2, 6, 10 }, { 6, 12, 5 }, { 12, 11, 3 }, { 11, 8, 7 }, { 8, 2, 9 },
		{ 4, 10, 5 }, { 4, 5, 3 }, { 4, 3, 7 }, { 4, 7, 9 }, { 4, 9, 10 },
		{ 5, 10, 6 }, { 3, 5, 12 }, { 7, 3, 11 }, { 9, 7, 8 }, { 10, 9, 2 },
	}
	local verts = {}
	for i, p in raw do
		verts[i] = Vector3.new(p[1], p[2], p[3]).Unit
	end
	return { v = verts, f = faces }
end)()

-- One subdivision of the icosahedron (80 faces). Edge midpoints are shared, so jitter never opens cracks.
local ICO1 = (function()
	local verts = table.clone(ICO.v)
	local faces, mids = {}, {}
	local function mid(a, b)
		local key = math.min(a, b) .. ":" .. math.max(a, b)
		if not mids[key] then
			table.insert(verts, ((verts[a] + verts[b]) / 2).Unit)
			mids[key] = #verts
		end
		return mids[key]
	end
	for _, f in ICO.f do
		local a, b, c = f[1], f[2], f[3]
		local ab, bc, ca = mid(a, b), mid(b, c), mid(c, a)
		table.insert(faces, { a, ab, ca })
		table.insert(faces, { b, bc, ab })
		table.insert(faces, { c, ca, bc })
		table.insert(faces, { ab, bc, ca })
	end
	return { v = verts, f = faces }
end)()

-- Low-poly boulder: a jittered icosahedron (40 wedges; opts.detail = 1 gives 160 for hero rocks), squashed a
-- little and sunk about 15 % into the ground.
function Props.boulder(cf, opts)
	opts = opts or {}
	local rng = rngOf(opts)
	local r = opts.radius or 4
	local squash = opts.squash or 0.8
	local m = newModel("Boulder", cf)
	local color = hex(opts.color or "#A9A8AB")
	local shape = opts.detail == 1 and ICO1 or ICO
	local centre = natural(cf, rng, 10) * CFrame.new(0, r * squash * 0.85, 0)
	local pts = {}
	for i, p in shape.v do
		local k = 1 + rng:NextNumber(-0.18, 0.18)
		pts[i] = (centre * CFrame.new(p.X * r * k, p.Y * r * k * squash, p.Z * r * k)).Position
	end
	for _, f in shape.f do
		Geo.tri(pts[f[1]], pts[f[2]], pts[f[3]], math.max(0.3, r * 0.12), { Color = shade(color, rng, 0.06) }, m, centre.Position)
	end
	return m
end

-- Round upgrade pad: a raised disc over a slightly wider neon rim. Top surface 0.8 above cf.
function Props.pad(cf, opts)
	opts = opts or {}
	local m = newModel("Pad", cf)
	local r = opts.radius or 6
	local rim = column(m, cf * CFrame.new(0, 0.3, 0), 0.6, 2 * r + 1, hex(opts.rim or "#04AFEC"))
	rim.Material = Enum.Material.Neon
	column(m, cf * CFrame.new(0, 0.4, 0), 0.8, 2 * r, hex(opts.color or "#0D69AC"))
	return m
end

-- Flat ground arrow pointing along cf.LookVector, lying just above the ground.
function Props.arrow(cf, opts)
	opts = opts or {}
	local m = newModel("Arrow", cf)
	local len = opts.length or 8
	local w = opts.width or 3
	local color = hex(opts.color or "#F8F8F8")
	local headLen = w * 1.1
	local shaftLen = len - headLen
	Build.part({ Size = Vector3.new(w * 0.45, 0.1, shaftLen), CFrame = cf * CFrame.new(0, 0.1, -shaftLen / 2), Color = color, Parent = m })
	local tip = (cf * CFrame.new(0, 0.15, -len)).Position
	local left = (cf * CFrame.new(-w / 2, 0.15, -shaftLen)).Position
	local right = (cf * CFrame.new(w / 2, 0.15, -shaftLen)).Position
	Geo.tri(left, right, tip, 0.1, { Color = color }, m)
	return Build.decor(m)
end

-- Board on a post with SurfaceGui text. cf.LookVector points at the reader.
function Props.sign(cf, opts)
	opts = opts or {}
	local m = newModel("Sign", cf)
	local w, h = opts.width or 8, opts.height or 3
	local postH = opts.postHeight or 5
	if postH > 0 then
		column(m, cf * CFrame.new(0, postH / 2, 0.3), postH, 0.6, hex(opts.post or "#694028"))
	end
	local board = Build.part({ Size = Vector3.new(w, h, 0.5), CFrame = cf * CFrame.new(0, postH + h / 2, 0), Color = hex(opts.color or "#CC8E69"), Parent = m })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = opts.text or ""
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = hex(opts.textColor or "#F8F8F8")
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
	return m
end

-- Zone gate: two square pillars and a beam with the zone name. Walk through along cf.LookVector.
function Props.gate(cf, opts)
	opts = opts or {}
	local m = newModel("Gate", cf)
	local w, h = opts.width or 16, opts.height or 12
	local p = 3
	local color = hex(opts.color or "#A9A8AB")
	local trim = hex(opts.trim or "#635F62")
	for _, side in { -1, 1 } do
		local x = side * (w / 2 + p / 2)
		Build.part({ Size = Vector3.new(p, h, p), CFrame = cf * CFrame.new(x, h / 2, 0), Color = color, Parent = m })
		Build.part({ Size = Vector3.new(p + 1, 1, p + 1), CFrame = cf * CFrame.new(x, 0.5, 0), Color = trim, Parent = m })
		Build.part({ Size = Vector3.new(p + 1, 1, p + 1), CFrame = cf * CFrame.new(x, h - 0.5, 0), Color = trim, Parent = m })
	end
	Build.part({ Size = Vector3.new(w + 2 * p + 2, 3, p + 1), CFrame = cf * CFrame.new(0, h + 1.5, 0), Color = trim, Parent = m })
	if opts.text then
		-- on the approach side of the beam, facing the players walking in
		local sign = Props.sign(cf * CFrame.new(0, h - 0.25, (p + 1) / 2 + 0.3) * CFrame.Angles(0, math.pi, 0), {
			text = opts.text, width = w * 0.8, height = 3.5, postHeight = 0, color = opts.signColor or "#0D69AC",
		})
		sign.Parent = m
	end
	return m
end

function Props.fence(a, b, opts)
	opts = opts or {}
	local m = newModel("Fence", CFrame.new(a))
	local color = hex(opts.color or "#694028")
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local len = flat.Magnitude
	local spacing = opts.spacing or 6
	assert(spacing > 0 and len > 0.05, "Props.fence: needs two different points and spacing > 0")
	local frame = CFrame.lookAt(a, a + flat)
	local n = math.max(1, math.floor(len / spacing))
	for i = 0, n do
		Build.part({ Size = Vector3.new(1, 4, 1), CFrame = frame * CFrame.new(0, 2, -len * i / n), Color = color, Parent = m })
	end
	for _, y in { 1.5, 3 } do
		Build.part({ Size = Vector3.new(0.5, 0.5, len), CFrame = frame * CFrame.new(0, y, -len / 2), Color = shade(color, Random.new(2), 0.05), Parent = m })
	end
	return m
end

-- Market stall: counter, two posts, striped awning, a header sign. cf faces the customers.
function Props.stall(cf, opts)
	opts = opts or {}
	local m = newModel("Stall", cf)
	local w = opts.width or 12
	local wood, dark = hex("#CC8E69"), hex("#694028")
	Build.part({ Size = Vector3.new(w, 3.5, 3), CFrame = cf * CFrame.new(0, 1.75, 0), Color = wood, Parent = m })
	Build.part({ Size = Vector3.new(w + 0.6, 0.4, 3.6), CFrame = cf * CFrame.new(0, 3.7, 0), Color = dark, Parent = m })
	for _, x in { -w / 2 + 0.5, w / 2 - 0.5 } do
		Build.part({ Size = Vector3.new(0.8, 9, 0.8), CFrame = cf * CFrame.new(x, 4.5, 2), Color = dark, Parent = m })
	end
	local stripes = { hex(opts.color or "#FF5959"), hex("#F8F8F8") }
	local n = 6
	for i = 1, n do
		Build.part({
			Size = Vector3.new(w / n, 0.4, 5),
			CFrame = cf * CFrame.new(-w / 2 + (i - 0.5) * w / n, 9.2, 1) * CFrame.Angles(math.rad(-15), 0, 0),
			Color = stripes[i % 2 + 1],
			Parent = m,
		})
	end
	local sign = Props.sign(cf * CFrame.new(0, 9.8, -0.6), { text = opts.text or "SHOP", width = w * 0.7, height = 2.5, postHeight = 0, color = opts.signColor or "#0D69AC" })
	sign.Parent = m
	return m
end

return Props
