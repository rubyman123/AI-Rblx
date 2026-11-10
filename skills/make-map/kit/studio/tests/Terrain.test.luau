-- Tests for MapKit.Terrain (heightfields and water written by code). Method by fwjelaa (FWJ STUDIOS).
local BOX_CF, BOX_SIZE = CFrame.new(1600, 616, 1600), Vector3.new(48, 48, 48)

local function clean()
	workspace.Terrain:FillBlock(BOX_CF, BOX_SIZE, Enum.Material.Air)
end

local function columnTop(x, z)
	-- the surface height from the voxels: the highest occupied 4-stud cell plus its solid fill
	local region = Region3.new(Vector3.new(x - 2, 592, z - 2), Vector3.new(x + 2, 640, z + 2)):ExpandToGrid(4)
	local ch = workspace.Terrain:ReadVoxelChannels(region, 4, { "SolidOccupancy", "SolidMaterial", "LiquidOccupancy" })
	local top, mat, water = nil, nil, 0
	for y = 1, #ch.SolidOccupancy[1] do
		local occ = ch.SolidOccupancy[1][y][1]
		if occ > 0 then
			top = region.CFrame.Position.Y - region.Size.Y / 2 + (y - 1) * 4 + occ * 4
			mat = ch.SolidMaterial[1][y][1]
		end
		water = math.max(water, ch.LiquidOccupancy[1][y][1])
	end
	return top, mat, water
end

return {
	["tests refuse to touch a test area that already holds terrain"] = function(t, K)
		-- review 2026-10-25: the terrain tests cleared fixed boxes without looking, which could erase a user's terrain
		local cf, size = CFrame.new(1700, 616, 1600), Vector3.new(8, 8, 8)
		t.emptyTerrain(cf, size) -- passes: nothing there, so this test may write
		workspace.Terrain:FillBlock(cf, Vector3.new(4, 4, 4), Enum.Material.Rock)
		local ok, err = pcall(t.emptyTerrain, cf, size)
		workspace.Terrain:FillBlock(cf, size, Enum.Material.Air)
		t.eq(ok, false, "an occupied area is refused")
		t.ok(tostring(err):find("already holds terrain"), "says why: " .. tostring(err))
	end,
	["heightfield writes the surface at the asked height with the asked material"] = function(t, K)
		t.emptyTerrain(BOX_CF, BOX_SIZE)
		local ok, err = pcall(function()
			K.Terrain.heightfield({
				box = { cf = BOX_CF, size = BOX_SIZE },
				min = Vector2.new(1580, 1580), max = Vector2.new(1620, 1620),
				bottom = 596,
				height = function(x, z)
					return 600 + (x - 1580) * 0.25 -- 600 at the west edge, 610 at the east
				end,
				material = function(x, z, h, slope)
					return slope > 30 and Enum.Material.Rock or Enum.Material.Grass
				end,
			})
			local h1, m1 = columnTop(1582, 1600)
			local h2 = columnTop(1618, 1600)
			t.near(h1, 600.5, 2.1, "west surface")
			t.near(h2, 609.5, 2.1, "east surface")
			t.ok(h2 > h1 + 6, "slopes up to the east")
			t.eq(m1, Enum.Material.Grass, "gentle slope is grass")
		end)
		clean()
		if not ok then
			error(err, 0)
		end
	end,
	["water fills the low ground up to the level and not the high ground"] = function(t, K)
		t.emptyTerrain(BOX_CF, BOX_SIZE)
		local ok, err = pcall(function()
			K.Terrain.heightfield({
				box = { cf = BOX_CF, size = BOX_SIZE },
				min = Vector2.new(1580, 1580), max = Vector2.new(1620, 1620),
				bottom = 596,
				height = function(x)
					return x < 1600 and 600 or 612
				end,
				material = function()
					return Enum.Material.Mud
				end,
				water = 606,
			})
			local _, _, lowWater = columnTop(1588, 1600)
			local _, _, highWater = columnTop(1612, 1600)
			t.ok(lowWater > 0.5, "lake over the low ground: " .. lowWater)
			t.eq(highWater, 0, "no water on the high ground")
		end)
		clean()
		if not ok then
			error(err, 0)
		end
	end,
	-- a stream runs higher than the lake it feeds: water can be a level per column
	["water can be a level per column"] = function(t, K)
		t.emptyTerrain(BOX_CF, BOX_SIZE)
		local ok, err = pcall(function()
			K.Terrain.heightfield({
				box = { cf = BOX_CF, size = BOX_SIZE },
				min = Vector2.new(1580, 1580), max = Vector2.new(1620, 1620),
				bottom = 596,
				height = function()
					return 600
				end,
				material = function()
					return Enum.Material.Mud
				end,
				water = function(x)
					return x < 1600 and 606 or nil
				end,
			})
			local _, _, west = columnTop(1588, 1600)
			local _, _, east = columnTop(1612, 1600)
			t.ok(west > 0.5, "water where the function gives a level")
			t.eq(east, 0, "dry where it gives nil")
		end)
		clean()
		if not ok then
			error(err, 0)
		end
	end,
	["heightfield refuses to write outside its box"] = function(t, K)
		t.errors(function()
			K.Terrain.heightfield({
				box = { cf = BOX_CF, size = BOX_SIZE },
				min = Vector2.new(1500, 1580), max = Vector2.new(1620, 1620),
				bottom = 596,
				height = function()
					return 600
				end,
				material = function()
					return Enum.Material.Grass
				end,
			})
		end, "outside")
	end,
}
