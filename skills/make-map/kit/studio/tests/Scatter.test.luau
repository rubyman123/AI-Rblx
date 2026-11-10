-- Tests for MapKit.Scatter. Method by fwjelaa (FWJ STUDIOS).
local function slab(t, y, size)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = Vector3.new(size, 2, size)
	p.CFrame = CFrame.new(0, y - 1, 0)
	p.Parent = t.sandbox
	return p
end

local function dot(K)
	return function(cf)
		return K.Build.decor(K.Build.part({ Size = Vector3.one, CFrame = cf }))
	end
end

return {
	["poisson keeps the minimum distance"] = function(t, K)
		local pts = K.Scatter.poisson(Vector2.new(0, 0), Vector2.new(100, 100), 8, Random.new(4))
		t.ok(#pts > 60, "dense enough: " .. #pts)
		for i = 1, #pts do
			for j = i + 1, #pts do
				t.ok((pts[i] - pts[j]).Magnitude >= 8 - 1e-6, "two points too close")
			end
		end
	end,
	["poisson is deterministic per seed"] = function(t, K)
		local a = K.Scatter.poisson(Vector2.new(0, 0), Vector2.new(50, 50), 5, Random.new(7))
		local b = K.Scatter.poisson(Vector2.new(0, 0), Vector2.new(50, 50), 5, Random.new(7))
		t.eq(#a, #b, "count")
		t.ok((a[#a] - b[#b]).Magnitude < 1e-9, "same last point")
	end,
	["excluded handles circles, rectangles and capsules"] = function(t, K)
		local zones = {
			{ center = Vector2.new(0, 0), radius = 5 },
			{ min = Vector2.new(20, 20), max = Vector2.new(30, 30) },
			{ a = Vector2.new(-50, 40), b = Vector2.new(50, 40), radius = 3 },
		}
		t.ok(K.Scatter.excluded(Vector2.new(3, 3), zones), "circle")
		t.ok(K.Scatter.excluded(Vector2.new(25, 22), zones), "rectangle")
		t.ok(K.Scatter.excluded(Vector2.new(10, 42), zones), "capsule")
		t.ok(not K.Scatter.excluded(Vector2.new(10, 10), zones), "free spot")
	end,
	["run lands on the ground and skips exclusions and water"] = function(t, K)
		slab(t, 300, 120)
		local T = workspace.Terrain
		local waterCf, waterSize = CFrame.new(40, 300, 0), Vector3.new(40, 8, 120)
		t.emptyTerrain(waterCf, waterSize)
		T:FillBlock(waterCf, waterSize, Enum.Material.Water)
		local ok, err = pcall(function()
			local made = K.Scatter.run({
				min = Vector2.new(-58, -58), max = Vector2.new(58, 58), spacing = 6, seed = 2,
				exclude = {
					{ center = Vector2.new(0, 0), radius = 15 },
					{ a = Vector2.new(-60, -40), b = Vector2.new(60, -40), radius = 5 },
				},
				top = 400, depth = 200, parent = t.sandbox, make = dot(K),
			})
			t.ok(#made > 40, "placed " .. #made)
			for _, p in made do
				local q = Vector2.new(p.Position.X, p.Position.Z)
				t.ok(q.Magnitude >= 15, "inside the circle exclusion")
				t.ok(math.abs(q.Y + 40) >= 5, "inside the capsule exclusion")
				t.ok(q.X < 24, ("on the water at x=%.1f"):format(q.X))
				t.near(p.Position.Y, 300, 0.01, "on the slab top")
			end
		end)
		T:FillBlock(waterCf, waterSize, Enum.Material.Air)
		if not ok then
			error(err, 0)
		end
	end,
	["run skips water written the same frame"] = function(t, K)
		-- measured: raycasts don't see freshly written terrain water in an untouched area yet; voxel data does
		local x0 = 2000 + math.random(0, 400) * 40
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = Vector3.new(60, 2, 60)
		p.CFrame = CFrame.new(x0, 299, 0)
		p.Parent = t.sandbox
		local T = workspace.Terrain
		local waterCf, waterSize = CFrame.new(x0, 300, 0), Vector3.new(60, 8, 60)
		t.emptyTerrain(waterCf, waterSize)
		T:FillBlock(waterCf, waterSize, Enum.Material.Water)
		local ok, err = pcall(function()
			local made = K.Scatter.run({
				min = Vector2.new(x0 - 26, -26), max = Vector2.new(x0 + 26, 26), spacing = 6, seed = 3,
				top = 400, depth = 200, parent = t.sandbox, make = dot(K),
			})
			t.eq(#made, 0, "placed on fresh water")
		end)
		T:FillBlock(waterCf, waterSize, Enum.Material.Air)
		if not ok then
			error(err, 0)
		end
	end,
	["run places on ground just above a water surface"] = function(t, K)
		-- water up to y 302 shares the 300-304 voxel with ground at 303: the ground is dry and must get props
		local x0 = 2000 + math.random(0, 400) * 40
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = Vector3.new(40, 2, 40)
		p.CFrame = CFrame.new(x0, 302, 0)
		p.Parent = t.sandbox
		local T = workspace.Terrain
		local waterCf, waterSize = CFrame.new(x0, 297, 0), Vector3.new(40, 10, 40)
		t.emptyTerrain(waterCf, waterSize)
		T:FillBlock(waterCf, waterSize, Enum.Material.Water)
		local ok, err = pcall(function()
			local made = K.Scatter.run({
				min = Vector2.new(x0 - 16, -16), max = Vector2.new(x0 + 16, 16), spacing = 6, seed = 4,
				top = 400, depth = 200, parent = t.sandbox, make = dot(K),
			})
			t.ok(#made > 10, "placed on dry ground above water: " .. #made)
		end)
		T:FillBlock(waterCf, waterSize, Enum.Material.Air)
		if not ok then
			error(err, 0)
		end
	end,
	["run skips an old lake bed under fresh water"] = function(t, K)
		local x0 = 2000 + math.random(0, 400) * 40
		local T = workspace.Terrain
		local bedCf, bedSize = CFrame.new(x0, 290, 0), Vector3.new(40, 8, 40)
		local waterCf, waterSize = CFrame.new(x0, 298, 0), Vector3.new(40, 8, 40)
		t.emptyTerrain(bedCf, bedSize)
		t.emptyTerrain(waterCf, waterSize)
		T:FillBlock(bedCf, bedSize, Enum.Material.Mud)
		for _ = 1, 60 do -- let the bed become raycastable
			task.wait()
			if workspace:Raycast(Vector3.new(x0, 400, 0), Vector3.new(0, -200, 0)) then
				break
			end
		end
		T:FillBlock(waterCf, waterSize, Enum.Material.Water)
		local ok, err = pcall(function()
			local made = K.Scatter.run({
				min = Vector2.new(x0 - 16, -16), max = Vector2.new(x0 + 16, 16), spacing = 6, seed = 5,
				top = 400, depth = 200, parent = t.sandbox, make = dot(K),
			})
			t.eq(#made, 0, "placed under water")
		end)
		T:FillBlock(waterCf, waterSize, Enum.Material.Air)
		T:FillBlock(bedCf, bedSize, Enum.Material.Air)
		if not ok then
			error(err, 0)
		end
	end,
	["clearance grows every exclusion zone"] = function(t, K)
		local circle = { { center = Vector2.zero, radius = 5 } }
		t.ok(K.Scatter.excluded(Vector2.new(0, 9), circle, 6), "within radius + clearance")
		t.ok(not K.Scatter.excluded(Vector2.new(0, 12), circle, 6), "beyond radius + clearance")
		t.ok(K.Scatter.excluded(Vector2.new(0, 23), { { min = Vector2.new(-10, -10), max = Vector2.new(10, 20) } }, 4), "rectangle grown")
		t.ok(K.Scatter.excluded(Vector2.new(30, 4), { { a = Vector2.new(-50, 0), b = Vector2.new(50, 0), radius = 2 } }, 3), "capsule grown")
	end,
	["run rejects bad cluster numbers"] = function(t, K)
		t.errors(function()
			K.Scatter.run({ min = Vector2.zero, max = Vector2.new(50, 50), clusters = { spacing = 0, radius = 5, per = { 1, 2 }, minDist = 1 }, parent = t.sandbox, make = dot(K) })
		end, "Scatter.run")
		t.errors(function()
			K.Scatter.run({ min = Vector2.zero, max = Vector2.new(50, 50), spacing = -3, parent = t.sandbox, make = dot(K) })
		end, "Scatter.run")
	end,
	["run refuses a point count that would freeze Studio"] = function(t, K)
		t.errors(function()
			K.Scatter.run({ min = Vector2.zero, max = Vector2.new(5000, 5000), spacing = 0.5, parent = t.sandbox, make = dot(K) })
		end, "Scatter.run")
	end,
	["run skips steep ground"] = function(t, K)
		local p = slab(t, 300, 60)
		p.CFrame = CFrame.new(0, 300, 0) * CFrame.Angles(math.rad(60), 0, 0)
		local made = K.Scatter.run({
			min = Vector2.new(-20, -10), max = Vector2.new(20, 10), spacing = 4, seed = 1,
			top = 400, depth = 300, maxSlope = 35, parent = t.sandbox, make = dot(K),
		})
		t.eq(#made, 0, "placed on a 60 degree slope")
	end,
	["run rejects zero spacing"] = function(t, K)
		t.errors(function()
			K.Scatter.run({ min = Vector2.zero, max = Vector2.one, spacing = 0, parent = t.sandbox, make = dot(K) })
		end, "Scatter.run")
	end,
	["clusters stay near their centres and apart"] = function(t, K)
		local pts = K.Scatter.clusters(Vector2.new(0, 0), Vector2.new(200, 200), 60, 10, { 3, 5 }, 3, Random.new(5))
		t.ok(#pts >= 9, "enough cluster members: " .. #pts)
		for i = 1, #pts do
			for j = i + 1, #pts do
				t.ok((pts[i] - pts[j]).Magnitude >= 3 - 1e-6, "members too close")
			end
		end
	end,
}
