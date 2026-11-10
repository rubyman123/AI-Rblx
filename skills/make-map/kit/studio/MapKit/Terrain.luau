-- Terrain written by code: heightfields with slope/altitude materials, and water. Method by fwjelaa (FWJ STUDIOS).
-- Writes only inside the box the map claimed (K.Root.claimTerrain); refuses before writing anything if the field
-- would leave it. Shore cells hold soil and water together (WriteVoxelChannels).
local Terrain = {}

local CELL = 4
local CHUNK = 32 -- columns per write along X, so big fields never freeze Studio

local function clamp01(v)
	return math.max(0, math.min(1, v))
end

-- o = { box = {cf, size}, min = Vector2, max = Vector2, bottom = y, height = fn(x, z) -> y,
--       material = fn(x, z, y, slopeDegrees) -> Enum.Material, water = level? }
function Terrain.heightfield(o)
	local blo = o.box.cf.Position - o.box.size / 2
	local bhi = o.box.cf.Position + o.box.size / 2
	local x0, z0 = math.floor(o.min.X / CELL) * CELL, math.floor(o.min.Y / CELL) * CELL
	local x1, z1 = math.ceil(o.max.X / CELL) * CELL, math.ceil(o.max.Y / CELL) * CELL
	local nx, nz = (x1 - x0) / CELL, (z1 - z0) / CELL
	-- water: one level for the whole field, or a level per column (nil = dry), e.g. a stream above its lake
	local waterAt = type(o.water) == "function" and o.water or function()
		return o.water
	end
	-- heights first: they set the region's top and tell us if anything would leave the box
	local hs, ws, top = table.create(nx), table.create(nx), -math.huge
	for i = 1, nx do
		hs[i], ws[i] = table.create(nz), table.create(nz)
		for k = 1, nz do
			local x, z = x0 + (i - 0.5) * CELL, z0 + (k - 0.5) * CELL
			local h, w = o.height(x, z), waterAt(x, z)
			hs[i][k], ws[i][k] = h, w or false
			top = math.max(top, h, w or -math.huge)
		end
	end
	local y0 = math.floor(o.bottom / CELL) * CELL
	local y1 = math.ceil(top / CELL) * CELL + CELL
	if x0 < blo.X - 1e-3 or z0 < blo.Z - 1e-3 or x1 > bhi.X + 1e-3 or z1 > bhi.Z + 1e-3 or y0 < blo.Y - 1e-3 or y1 > bhi.Y + 1e-3 then
		error(("Terrain.heightfield: the field (%d..%d, %d..%d, y %d..%d) is outside its claimed box (%s ± %s); claim a bigger box with K.Root.claimTerrain")
			:format(x0, x1, z0, z1, y0, y1, tostring(o.box.cf.Position), tostring(o.box.size / 2)), 2)
	end
	local ny = (y1 - y0) / CELL
	local T = workspace.Terrain
	for c0 = 1, nx, CHUNK do
		local c1 = math.min(nx, c0 + CHUNK - 1)
		local mats, solid, liquid = {}, {}, {}
		for i = c0, c1 do
			local mi, si, li = table.create(ny), table.create(ny), table.create(ny)
			for j = 1, ny do
				mi[j], si[j], li[j] = table.create(nz), table.create(nz), table.create(nz)
			end
			for k = 1, nz do
				local x, z = x0 + (i - 0.5) * CELL, z0 + (k - 0.5) * CELL
				local h = hs[i][k]
				local dx = o.height(x + 2, z) - o.height(x - 2, z)
				local dz = o.height(x, z + 2) - o.height(x, z - 2)
				local slope = math.deg(math.atan(math.sqrt(dx * dx + dz * dz) / 4))
				local m = o.material(x, z, h, slope)
				for j = 1, ny do
					local cellBottom = y0 + (j - 1) * CELL
					local occ = clamp01((h - cellBottom) / CELL)
					local level = ws[i][k]
					local wet = level and clamp01(clamp01((level - cellBottom) / CELL) - occ) or 0
					mi[j][k] = occ > 0 and m or (wet > 0 and Enum.Material.Water or Enum.Material.Air)
					si[j][k] = occ
					li[j][k] = wet
				end
			end
			table.insert(mats, mi)
			table.insert(solid, si)
			table.insert(liquid, li)
		end
		local region = Region3.new(Vector3.new(x0 + (c0 - 1) * CELL, y0, z0), Vector3.new(x0 + c1 * CELL, y1, z1))
		T:WriteVoxelChannels(region, CELL, { SolidMaterial = mats, SolidOccupancy = solid, LiquidOccupancy = liquid })
		task.wait()
	end
	return { cells = nx * nz, top = top }
end

return Terrain
