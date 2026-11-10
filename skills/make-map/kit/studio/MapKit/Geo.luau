-- Architecture from primitives: walls with openings, slabs, stairs, ramps, triangles. Method by fwjelaa (FWJ STUDIOS).
-- Geo.tri uses the two-wedge right-triangle split popularised by EgoMoose and stravant's GapFill (MIT).
local Build = require(script.Parent.Build)

local Geo = {}

local function merge(a, b)
	local t = table.clone(a or {})
	for k, v in b or {} do
		t[k] = v
	end
	return t
end

function Geo.box(cf, size, props)
	return Build.part(merge(props, { CFrame = cf, Size = size }))
end

function Geo.wall(a, b, height, thickness, openings, props, parent)
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local length = flat.Magnitude
	assert(length > 0.05, "Geo.wall: a and b are the same point")
	local frame = CFrame.fromMatrix(a, flat.Unit, Vector3.yAxis) -- X runs along the wall, Y up
	local model = Build.model("Wall")
	local function piece(x0, x1, y0, y1)
		if x1 - x0 < 0.01 or y1 - y0 < 0.01 then
			return
		end
		Geo.box(frame * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, 0), Vector3.new(x1 - x0, y1 - y0, thickness),
			merge(props, { Parent = model }))
	end
	local list = table.clone(openings or {})
	table.sort(list, function(p, q)
		return p.at < q.at
	end)
	local cursor = 0
	for _, o in list do
		local x0, x1 = o.at - o.width / 2, o.at + o.width / 2
		if x0 < cursor - 1e-3 or x1 > length + 1e-3 then
			error(("Geo.wall: opening at %.1f (width %.1f) overlaps another or leaves the %.1f-stud wall")
				:format(o.at, o.width, length), 2)
		end
		piece(cursor, x0, 0, height)
		piece(x0, x1, 0, o.bottom or 0)
		piece(x0, x1, math.min(o.top or height, height), height)
		cursor = x1
	end
	piece(cursor, length, 0, height)
	model.Parent = parent
	return model
end

function Geo.slab(cf, sizeX, sizeZ, thickness, props, parent)
	thickness = thickness or 1
	return Geo.box(cf * CFrame.new(0, -thickness / 2, 0), Vector3.new(sizeX, thickness, sizeZ),
		merge(props, { Parent = parent }))
end

function Geo.stairs(cf, width, rise, steps, run, props, parent)
	local model = Build.model("Stairs")
	local h = rise / steps
	for i = 1, steps do
		Geo.box(cf * CFrame.new(0, h * i / 2, -(i - 0.5) * run), Vector3.new(width, h * i, run),
			merge(props, { Parent = model }))
	end
	model.Parent = parent
	return model
end

-- Measured: a WedgePart is high at its +Z end, so turn it round to rise along LookVector (-Z).
function Geo.ramp(cf, width, rise, length, props, parent)
	return Build.part(merge(props, {
		CFrame = cf * CFrame.new(0, rise / 2, -length / 2) * CFrame.Angles(0, math.pi, 0),
		Size = Vector3.new(width, rise, length),
		Parent = parent,
	}), "WedgePart")
end

function Geo.tri(a, b, c, thickness, props, parent, inside)
	thickness = thickness or 0.4
	local n = (b - a):Cross(c - a)
	if n.Magnitude < 1e-6 then
		return nil
	end
	n = n.Unit
	local offset
	if inside then
		offset = (n:Dot(inside - a) > 0 and n or -n) * (thickness / 2)
	else
		offset = (n.Y > 0 and -n or n) * (thickness / 2)
	end
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	local p = merge(props, { Parent = parent })
	local w1 = Build.part(merge(p, {
		Size = Vector3.new(thickness, height, math.abs(ab:Dot(back))),
		CFrame = CFrame.fromMatrix((a + b) / 2 + offset, right, up, back),
	}), "WedgePart")
	local w2 = Build.part(merge(p, {
		Size = Vector3.new(thickness, height, math.abs(ac:Dot(back))),
		CFrame = CFrame.fromMatrix((a + c) / 2 + offset, -right, up, -back),
	}), "WedgePart")
	return w1, w2
end

return Geo
