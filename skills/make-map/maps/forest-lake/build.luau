-- Forest Lake at Golden Hour (MapKit by fwjelaa, FWJ STUDIOS). Data: map.json. Style: styles/nature.md.
-- The ground is one height function (meadow + hill rim + lake bowl + stream channel) written with K.Terrain;
-- trees, rocks and plants are placed by zone (forest, edge, hills, meadow, shore, stream) on top of it.
return function(K, spec)
	local id = spec.id
	local Root, Build, Materials, Models = K.Root, K.Build, K.Materials, K.Models
	local T, M = spec.terrain, spec.materials
	local seedOff = spec.seed * 0.137
	local phases = {}

	local function v3(t)
		return Vector3.new(t[1], t[2], t[3])
	end
	local function smooth(e0, e1, x)
		local t = math.clamp((x - e0) / (e1 - e0), 0, 1)
		return t * t * (3 - 2 * t)
	end
	local function fbm(x, z, scale, off)
		local v, a, f = 0, 1, 1 / scale
		for i = 1, 4 do
			v += a * math.noise(x * f + (off or 0), z * f - (off or 0), seedOff + i * 7.31)
			a *= 0.5
			f *= 2
		end
		return v
	end
	-- distance from (x, z) to a polyline and how far along it (0..1) the nearest point is
	local function polyline(pts, x, z)
		local best, bestT, total, along = math.huge, 0, 0, {}
		for i = 1, #pts - 1 do
			along[i] = total
			total += (Vector2.new(pts[i + 1][1], pts[i + 1][2]) - Vector2.new(pts[i][1], pts[i][2])).Magnitude
		end
		for i = 1, #pts - 1 do
			local a, b = Vector2.new(pts[i][1], pts[i][2]), Vector2.new(pts[i + 1][1], pts[i + 1][2])
			local ab, p = b - a, Vector2.new(x, z)
			local u = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
			local d = (p - (a + ab * u)).Magnitude
			if d < best then
				best, bestT = d, (along[i] + ab.Magnitude * u) / total
			end
		end
		return best, bestT
	end

	local L, R, S, P, O = T.lake, T.rim, T.stream, T.path, T.outer
	local calm = Vector2.new(L.calm.center[1], L.calm.center[2])
	-- an ellipse whose edge wanders (noise), held still near the pier and campfire so props meet the shore
	local function lakeD(x, z)
		local d = ((x - L.center[1]) / L.radius[1]) ^ 2 + ((z - L.center[2]) / L.radius[2]) ^ 2
		local still = smooth(L.calm.radius * 0.5, L.calm.radius, (Vector2.new(x, z) - calm).Magnitude)
		return d * (1 + L.wobble * still * fbm(x + 300, z + 300, 45))
	end
	local function rimW(x, z)
		local r = (Vector2.new(x, z) - Vector2.new(R.center[1], R.center[2])).Magnitude
		local w = smooth(R.inner, R.outer, r)
		if z > R.center[2] then -- lower toward the south so the spawn looks over the valley
			w *= 1 - R.southDip * smooth(0, R.outer, z - R.center[2])
		end
		return w
	end
	-- the ground without the stream: meadow, hills, lake bowl, and past the walls a ring of higher hills that
	-- closes the horizon (no terrain edge is ever in view)
	local function land(x, z)
		local h = T.base + fbm(x, z, 60) * 3.5
		h += rimW(x, z) * (R.height + fbm(x + 500, z, 40) * 8)
		h += smooth(O.from, O.to, math.max(math.abs(x), math.abs(z))) * (O.height + fbm(x - 700, z, 50) * 10)
		local d = lakeD(x, z)
		local k = smooth(1.3, 0.85, d)
		local bowl = T.water - 0.6 - L.depth * (1 - math.min(d, 1)) ^ 0.7
		return h * (1 - k) + bowl * k
	end
	local function streamAt(x, z)
		local dist, t = polyline(S.points, x, z)
		return dist, t
	end
	local function streamLevel(t)
		-- water surface along the stream: from its source down to the lake, never below the lake
		local n = #S.points
		local f = t * (n - 1)
		local i = math.clamp(math.floor(f) + 1, 1, n - 1)
		local a, b = S.points[i], S.points[i + 1]
		local u = f - (i - 1)
		local x, z = a[1] + (b[1] - a[1]) * u, a[2] + (b[2] - a[2]) * u
		-- near the lake the stream sinks to the lake's level, so the two waters meet without a step
		local level = math.max(T.water, land(x, z) - S.depth + 1.0)
		return T.water + (level - T.water) * smooth(1.0, 1.8, lakeD(x, z))
	end
	local function height(x, z)
		local h = land(x, z)
		local dist, t = streamAt(x, z)
		if dist < S.width * 1.6 then
			local bed = streamLevel(t) - S.water -- deep enough that 4-stud voxels show the water
			local k = smooth(S.width * 1.6, S.width * 0.45, dist)
			h = h * (1 - k) + math.min(h, bed) * k
		end
		return h
	end
	local function water(x, z)
		if lakeD(x, z) < 1.02 then
			return T.water
		end
		local dist, t = streamAt(x, z)
		if dist < S.width * 0.6 and lakeD(x, z) > 0.9 then
			return streamLevel(t)
		end
		return nil
	end
	local function forestMask(x, z)
		return fbm(x + 900, z - 300, T.forest.scale)
	end
	local function onPath(x, z)
		return (polyline(P.points, x, z)) < P.width / 2
	end
	local function material(x, z, h, slope)
		if slope > 36 then
			return Enum.Material.Rock
		end
		local d = lakeD(x, z)
		if d < 1.18 and h < T.water + 1.8 then
			return Enum.Material.Mud
		end
		if (streamAt(x, z)) < S.width * 0.8 then
			return Enum.Material.Sand
		end
		if onPath(x, z) then
			return Enum.Material.Ground
		end
		if forestMask(x, z) > T.forest.threshold or rimW(x, z) > 0.45 then
			return Enum.Material.LeafyGrass
		end
		return Enum.Material.Grass
	end

	-- where things grow
	local function zoneOk(where, x, z, slope)
		local d = lakeD(x, z)
		local sd = (streamAt(x, z))
		if where == "shore" then
			return d > 0.97 and d < 1.1
		end
		if d < 1.25 or sd < S.width * 1.1 or onPath(x, z) then
			return where == "stream" and sd > S.width * 0.6 and sd < S.width * 1.6 and d > 1.1
		end
		if where == "stream" then
			return false
		end
		local fm, rw = forestMask(x, z), rimW(x, z)
		if where == "forest" then
			return fm > T.forest.threshold and slope < 28
		elseif where == "edge" then
			return (math.abs(fm - T.forest.threshold) < 0.12 or (d > 1.25 and d < 1.7)) and slope < 25
		elseif where == "hills" then
			return rw > 0.35 and slope < 32
		elseif where == "meadow" then
			return fm < T.forest.threshold - 0.05 and rw < 0.3 and slope < 18
		elseif where == "rocky" then
			return slope > 18 or rw > 0.6
		end
		return false
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local function groundAt(x, z)
		local hit = workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -220, 0), params)
		return hit and hit.Position.Y, hit and hit.Normal
	end
	local function slopeAt(normal)
		return math.deg(math.acos(math.clamp(normal.Y, -1, 1)))
	end
	local keepClear = { v3(spec.spawn) }
	for _, p in spec.props do
		table.insert(keepClear, v3(p.p))
	end
	local function clearOfProps(x, z, r)
		for _, c in keepClear do
			if (Vector2.new(c.X, c.Z) - Vector2.new(x, z)).Magnitude < r then
				return false
			end
		end
		return true
	end

	function phases.materials()
		local names = {}
		for _, v in M do
			table.insert(names, v)
		end
		table.sort(names)
		Materials.install(names)
		Materials.override(Enum.Material.Grass, M.grass)
		Materials.override(Enum.Material.LeafyGrass, M.forest)
		Materials.override(Enum.Material.Rock, M.rock)
		Materials.override(Enum.Material.Mud, M.shore)
		Materials.override(Enum.Material.Ground, M.path)
		Materials.override(Enum.Material.Sand, M.pebbles)
		return "installed " .. #names .. " materials, 6 terrain overrides"
	end

	local function modelNames()
		local set, names = {}, {}
		for _, list in { spec.trees, spec.scatter, spec.props } do
			for _, p in list do
				set[p.m] = true
			end
		end
		for n in set do
			table.insert(names, n)
		end
		table.sort(names)
		return names
	end

	function phases.models()
		local names, report = Models.install(modelNames())
		return ("installed %d models (%s)"):format(#names, report)
	end

	function phases.terrain()
		Root.removeTemplate()
		local b = T.box
		-- the field is checked against the cells the claim checked and recorded, not the box as written
		local claimed = Root.claimTerrain(id, CFrame.new(v3(b.center)), v3(b.size))
		local r = K.Terrain.heightfield({
			box = { cf = claimed.CFrame, size = claimed.Size },
			min = Vector2.new(T.field.min[1], T.field.min[2]),
			max = Vector2.new(T.field.max[1], T.field.max[2]),
			bottom = T.field.bottom,
			height = height,
			material = material,
			water = water,
		})
		-- invisible walls keep players on the playable square, short of the outer hills' far edge
		local walls, half = {}, T.play.wall
		for i, side in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local along = side[1] == 0
			table.insert(walls, Build.part({
				Name = "Bound" .. i, Transparency = 1, CastShadow = false, CanQuery = false, CanTouch = false,
				Color = Color3.fromRGB(120, 130, 110),
				Size = along and Vector3.new(half * 2 + 8, 400, 4) or Vector3.new(4, 400, half * 2 + 8),
				CFrame = CFrame.new(side[1] * half, 100, side[2] * half),
			}))
		end
		Build.flush(walls, Root.clear(id, "Ground"))
		local w = spec.water
		local Tr = workspace.Terrain
		Tr.WaterColor = Color3.fromRGB(w.color[1], w.color[2], w.color[3])
		Tr.WaterTransparency, Tr.WaterReflectance = w.transparency, w.reflectance
		Tr.WaterWaveSize, Tr.WaterWaveSpeed = w.waveSize, w.waveSpeed
		-- the colour of Roblox's grass blades (and a tint on the ground texture under them); global, like water
		for mat, c in spec.terrainColors or {} do
			Tr:SetMaterialColor(Enum.Material[mat], Color3.fromRGB(c[1], c[2], c[3]))
		end
		local sp = Instance.new("SpawnLocation")
		sp.Name = "Spawn"
		sp.Anchored, sp.Transparency, sp.CanCollide, sp.Neutral, sp.Duration = true, 1, false, true, 0
		sp.Size = Vector3.new(6, 1, 6)
		local gy = groundAt(spec.spawn[1], spec.spawn[3]) or 4
		sp.CFrame = CFrame.new(spec.spawn[1], gy + 0.1, spec.spawn[3])
		sp.Parent = Root.clear(id, "Spawns")
		return ("terrain: %d columns, top %.0f"):format(r.cells, r.top)
	end

	-- trees stand back from the path and spawn (crown radius ~17), so the path is a clear view down to the lake
	local spawnXZ = Vector2.new(spec.spawn[1], spec.spawn[3])
	local function treeRoom(x, z)
		return (polyline(P.points, x, z)) > P.treeClear and (Vector2.new(x, z) - spawnXZ).Magnitude > P.spawnClear
	end

	local function placeList(list, layer, rng, minGap, room)
		local placed, spots = 0, {}
		for _, s in list do
			local made, tries = 0, 0
			while made < s.count and tries < s.count * 60 do
				tries += 1
				local x = rng:NextNumber(T.play.min[1] + 8, T.play.max[1] - 8)
				local z = rng:NextNumber(T.play.min[2] + 8, T.play.max[2] - 8)
				local y, n = groundAt(x, z)
				if y and n and zoneOk(s.where, x, z, slopeAt(n)) and clearOfProps(x, z, minGap * 1.5) and (not room or room(x, z)) then
					local free = true
					for _, o in spots do
						if (o - Vector2.new(x, z)).Magnitude < minGap then
							free = false
							break
						end
					end
					if free then
						local sc = s.scale and rng:NextNumber(s.scale[1], s.scale[2]) or rng:NextNumber(0.85, 1.2)
						Models.place(s.m, CFrame.new(x, y - 0.25, z) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0), {
							parent = layer, scale = sc, collision = s.collision, tint = s.tint, shadow = s.shadow,
						})
						table.insert(spots, Vector2.new(x, z))
						made += 1
						placed += 1
						if placed % 15 == 0 then
							task.wait()
						end
					end
				end
			end
		end
		return placed
	end

	function phases.trees()
		local layer = Root.clear(id, "Landmarks")
		return placeList(spec.trees, layer, Random.new(spec.seed + 1), 9, treeRoom) .. " trees"
	end

	function phases.scatter()
		local layer = Root.clear(id, "Foliage")
		local list = {}
		for _, s in spec.scatter do
			table.insert(list, { m = s.m, count = s.count, where = s.where, scale = s.scale, tint = s.t, collision = "none" })
		end
		for _, s in list do
			if s.m:find("boulder") or s.m:find("rocks") or s.m:find("log") or s.m:find("stump") then
				s.collision = nil -- big things the player bumps into keep the model's collision
			else
				s.shadow = false -- ground cover: its shadows cost more than they show (phones above all)
			end
		end
		return placeList(list, layer, Random.new(spec.seed + 2), 3) .. " plants, rocks and logs"
	end

	function phases.props()
		local layer = Root.clear(id, "Props")
		for _, p in spec.props do
			local y = p.p[2]
			if p.ground ~= false then
				y = (groundAt(p.p[1], p.p[3]) or 0) - 0.1 + y -- p[2] is an offset from the ground (sink a big rock)
			end
			Models.place(p.m, CFrame.new(p.p[1], y, p.p[3]) * CFrame.Angles(0, math.rad(p.r[2]), 0), { parent = layer, scale = p.s })
		end
		-- the campfire: flames, smoke and warm light on the shore
		local f = spec.fire
		local gy = groundAt(f.pos[1], f.pos[3]) or f.pos[2]
		local holder = Build.decor(Build.part({ Name = "Campfire", CFrame = CFrame.new(f.pos[1], gy + 0.8, f.pos[3]),
			Size = Vector3.new(1, 1, 1), Transparency = 1, Color = Color3.fromRGB(255, 160, 90), Parent = Root.clear(id, "Lights") }))
		local fire = Instance.new("Fire")
		fire.Size, fire.Heat = 4, 9
		fire.Color, fire.SecondaryColor = Color3.fromRGB(255, 140, 60), Color3.fromRGB(255, 70, 20)
		fire.Parent = holder
		local smoke = Instance.new("Smoke")
		smoke.Size, smoke.Opacity, smoke.RiseVelocity = 3, 0.08, 4
		smoke.Color = Color3.fromRGB(90, 85, 80)
		smoke.Parent = holder
		local light = Instance.new("PointLight")
		light.Range, light.Brightness, light.Shadows = f.range, f.brightness, true
		light.Color = Color3.fromRGB(f.color[1], f.color[2], f.color[3])
		light.Parent = holder
		return #spec.props .. " props and a campfire"
	end

	function phases.lighting()
		local failures = K.Lighting.preset(spec.lighting)
		local sun = K.Sky.apply(spec.sky.name)
		local t, lat, err = nil, nil, nil
		if sun then
			t, lat, err = K.Sky.matchSun(sun)
		end
		local out = #failures == 0 and "golden lighting" or table.concat(failures, "; ")
		return t and ("%s, sky %s, sun matched at %.2f h / lat %.1f (%.1f degrees off)"):format(out, spec.sky.name, t, lat, err) or out
	end

	function phases.ambience()
		local manifest = K.Http.json("assets.json")
		local sounds = manifest.sounds or {}
		local missing = {}
		for _, key in { "wind", "water" } do
			local e = sounds[spec.sound[key]]
			if e and e.id then
				K.Sound.ambience(id, key == "wind" and "Wind" or "Water", e.id, { volume = spec.sound.volume })
			else
				table.insert(missing, ("`python kit/tools/run.py %s %s`"):format(key, spec.sound[key]))
			end
		end
		K.Sound.reverb(spec.sound.reverb)
		return #missing == 0 and "wind and water on" or ("missing, run: " .. table.concat(missing, ", "))
	end

	function phases.all()
		local out = {}
		for _, name in { "materials", "models", "terrain", "lighting", "trees", "scatter", "props", "ambience" } do
			table.insert(out, name .. ": " .. tostring(phases[name]()))
			task.wait()
		end
		return table.concat(out, "\n")
	end

	return phases
end
