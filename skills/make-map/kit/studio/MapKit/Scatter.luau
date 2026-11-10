-- Natural placement: Poisson spacing, clusters, masks and exclusions, dropped onto the ground with raycasts.
-- Method by fwjelaa (FWJ STUDIOS). Idea list from Brushtool, ScatterForge and Foliage FX (see research/01).
local Build = require(script.Parent.Build)

local Scatter = {}

-- Bridson's Poisson-disk sampling in the rectangle [min, max] (Vector2 X/Z).
function Scatter.poisson(min, max, r, rng, k)
	k = k or 30
	local cell = r / math.sqrt(2)
	local gw = math.max(1, math.ceil((max.X - min.X) / cell))
	local gh = math.max(1, math.ceil((max.Y - min.Y) / cell))
	local grid, points, active = {}, {}, {}
	local function gi(p)
		return math.min(math.floor((p.X - min.X) / cell), gw - 1), math.min(math.floor((p.Y - min.Y) / cell), gh - 1)
	end
	local function fits(p)
		if p.X < min.X or p.X > max.X or p.Y < min.Y or p.Y > max.Y then
			return false
		end
		local cx, cy = gi(p)
		for x = math.max(cx - 2, 0), math.min(cx + 2, gw - 1) do
			for y = math.max(cy - 2, 0), math.min(cy + 2, gh - 1) do
				local q = grid[y * gw + x]
				if q and (q - p).Magnitude < r then
					return false
				end
			end
		end
		return true
	end
	local function add(p)
		table.insert(points, p)
		table.insert(active, p)
		local cx, cy = gi(p)
		grid[cy * gw + cx] = p
	end
	add(Vector2.new(rng:NextNumber(min.X, max.X), rng:NextNumber(min.Y, max.Y)))
	while #active > 0 do
		local i = rng:NextInteger(1, #active)
		local base = active[i]
		local found = false
		for _ = 1, k do
			local a = rng:NextNumber(0, 2 * math.pi)
			local p = base + Vector2.new(math.cos(a), math.sin(a)) * rng:NextNumber(r, 2 * r)
			if fits(p) then
				add(p)
				found = true
				break
			end
		end
		if not found then
			active[i] = active[#active]
			table.remove(active)
		end
	end
	return points
end

-- Cluster centres at least `spacing` apart, each with per[1]..per[2] members within `radius`, members minDist apart.
function Scatter.clusters(min, max, spacing, radius, per, minDist, rng)
	local out = {}
	for _, c in Scatter.poisson(min, max, spacing, rng) do
		local n = rng:NextInteger(per[1], per[2])
		local members, tries = {}, 0
		while #members < n and tries < n * 30 do
			tries += 1
			local a = rng:NextNumber(0, 2 * math.pi)
			local p = c + Vector2.new(math.cos(a), math.sin(a)) * radius * math.sqrt(rng:NextNumber())
			local ok = true
			for _, q in members do
				if (q - p).Magnitude < minDist then
					ok = false
					break
				end
			end
			if ok then
				table.insert(members, p)
			end
		end
		for _, p in members do
			table.insert(out, p)
		end
	end
	return out
end

local function segmentDistance(p, a, b)
	local ab = b - a
	local len2 = ab:Dot(ab)
	local t = len2 > 0 and math.clamp((p - a):Dot(ab) / len2, 0, 1) or 0
	return (p - (a + ab * t)).Magnitude
end

-- clearance grows every zone (use the prop's radius so big props keep their edges out, not just their centre)
function Scatter.excluded(p, zones, clearance)
	local c = clearance or 0
	for _, z in zones or {} do
		if z.center and (p - z.center).Magnitude < z.radius + c then
			return true
		elseif z.min and p.X >= z.min.X - c and p.X <= z.max.X + c and p.Y >= z.min.Y - c and p.Y <= z.max.Y + c then
			return true
		elseif z.a and segmentDistance(p, z.a, z.b) < z.radius + c then
			return true
		end
	end
	return false
end

-- Measured: raycasts don't see terrain water written moments ago in an untouched area, but the voxel data
-- does. Returns the water surface height in the 4-stud column around pos (from 8 below to 12 above), or nil.
-- Liquid fills a voxel from the bottom, so surface = voxel bottom + occupancy * 4.
local function waterSurface(pos)
	local x0, z0 = math.floor(pos.X / 4) * 4, math.floor(pos.Z / 4) * 4
	local y0 = math.floor(pos.Y / 4) * 4 - 8
	local region = Region3.new(Vector3.new(x0, y0, z0), Vector3.new(x0 + 4, y0 + 20, z0 + 4))
	local liquid = workspace.Terrain:ReadVoxelChannels(region, 4, { "LiquidOccupancy" }).LiquidOccupancy
	local top
	for y = 1, #liquid[1] do
		local l = liquid[1][y][1]
		if l > 0 then
			top = y0 + (y - 1) * 4 + l * 4
		end
	end
	return top
end

local function alignUp(up)
	local axis = Vector3.yAxis:Cross(up)
	if axis.Magnitude < 1e-5 then
		return CFrame.identity
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(Vector3.yAxis:Dot(up), -1, 1)))
end

function Scatter.run(o)
	assert(o.make and o.parent, "Scatter.run: needs make and parent")
	assert(o.spacing or o.clusters, "Scatter.run: give spacing or clusters")
	assert(not o.spacing or o.spacing > 0, "Scatter.run: spacing must be more than 0")
	local c = o.clusters
	assert(not c or (c.spacing > 0 and c.radius > 0 and c.minDist >= 0 and c.per[2] >= c.per[1]),
		"Scatter.run: clusters need spacing > 0, radius > 0, minDist >= 0 and per = {low, high}")
	-- a near-zero spacing over a big area would freeze Studio (and drop the MCP) instead of failing
	local area = math.max(0, o.max.X - o.min.X) * math.max(0, o.max.Y - o.min.Y)
	local estimate = c and (area / (c.spacing * c.spacing)) * c.per[2] or area / (o.spacing * o.spacing)
	assert(estimate <= 50000, ("Scatter.run: about %d points requested; raise spacing (max 50000 per call)"):format(estimate))
	local rng = Random.new(o.seed or 1)
	local pts
	if o.clusters then
		local c = o.clusters
		pts = Scatter.clusters(o.min, o.max, c.spacing, c.radius, c.per, c.minDist, rng)
	else
		pts = Scatter.poisson(o.min, o.max, o.spacing, rng)
	end
	local params = o.params or RaycastParams.new()
	params.IgnoreWater = false
	local cosMax = math.cos(math.rad(o.maxSlope or 35))
	local top, depth = o.top or 500, o.depth or 1000
	local made = {}
	for _, p in pts do
		if o.limit and #made >= o.limit then
			break
		end
		if p.X < o.min.X or p.X > o.max.X or p.Y < o.min.Y or p.Y > o.max.Y or Scatter.excluded(p, o.exclude, o.clearance) then
			continue
		end
		local hit = workspace:Raycast(Vector3.new(p.X, top, p.Y), Vector3.new(0, -depth, 0), params)
		if not hit or hit.Material == Enum.Material.Water or hit.Normal.Y < cosMax then
			continue
		end
		local surface = waterSurface(hit.Position)
		if surface and surface > hit.Position.Y + 0.05 then
			continue
		end
		if o.height and (hit.Position.Y < o.height[1] or hit.Position.Y > o.height[2]) then
			continue
		end
		local up = Vector3.yAxis:Lerp(hit.Normal, o.align or 0).Unit
		local cf = CFrame.new(hit.Position) * alignUp(up) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0)
		local inst = o.make(cf, rng, #made + 1)
		if inst then
			table.insert(made, inst)
		end
	end
	Build.flush(made, o.parent)
	return made
end

return Scatter
