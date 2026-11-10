-- Lift a Boulder: a 2026 "lift a ___" simulator showcase map. Method by fwjelaa (FWJ STUDIOS).
-- Phases: base, route, landmarks, scatter, lighting, all.   K.run("lift-a-boulder", "<phase>")
return function(K, spec)
	local Build, Geo, Props, Scatter, Root = K.Build, K.Geo, K.Props, K.Scatter, K.Root
	local id = spec.id
	local hex = Color3.fromHex
	local W = spec.pathWidth
	local isl = spec.island
	local zones = spec.zones
	local phases = {}

	-- where the path in zone i starts and stops (the spawn plaza comes before the meadow path,
	-- a ramp climbs into each next zone, the volcano path stops at the plateau stairs)
	local function pathSpan(i)
		local z = zones[i]
		local from = (i == 1) and spec.plazaZ[2] or z.z[1]
		local to = zones[i + 1] and (z.z[2] + spec.rampLength) or (spec.boulder.plateauFront + spec.boulder.plateau * 1.6)
		return from, to
	end

	function phases.base()
		local ground = Root.clear(id, "Ground")
		Root.removeTemplate()
		-- Measured: a 2000-stud terrain sea cost ~350 draw calls per view (80 % of the budget). Real terrain water
		-- only near the island, and one flat part (1 draw call) carries the sea to the horizon.
		-- The map only ever writes terrain inside the box it claims (the user's own terrain is never touched).
		local seaCf, seaSize = CFrame.new(0, -8, 0), Vector3.new(spec.water.size, 12, spec.water.size)
		Root.claimTerrain(id, seaCf, seaSize)
		workspace.Terrain:FillBlock(seaCf, seaSize, Enum.Material.Water)
		local items = {}
		table.insert(items, Build.decor(Build.part({ Name = "FarSea", Size = Vector3.new(8000, 1, 8000), CFrame = CFrame.new(0, -2.8, 0), Color = hex(spec.water.farColor), CastShadow = false })))
		-- sand beach ring just above the water, so the island stops reading as a board on the sea
		local beach = spec.beach
		table.insert(items, Build.part({ Name = "Beach", Size = Vector3.new(2 * (isl.halfX + beach.width), 3, isl.maxZ - isl.minZ + 2 * beach.width), CFrame = CFrame.new(0, beach.top - 1.5, (isl.maxZ + isl.minZ) / 2), Color = hex(beach.color) }))
		for _, zone in zones do
			local depth = zone.z[1] - zone.z[2]
			local midZ = (zone.z[1] + zone.z[2]) / 2
			local bodyH = zone.y - 2 + isl.thickness
			table.insert(items, Build.part({ Name = zone.name .. "_Earth", Size = Vector3.new(2 * isl.halfX, bodyH, depth), CFrame = CFrame.new(0, -isl.thickness + bodyH / 2, midZ), Color = hex(spec.earth) }))
			table.insert(items, Build.part({ Name = zone.name .. "_Ground", Size = Vector3.new(2 * isl.halfX, 2, depth), CFrame = CFrame.new(0, zone.y - 1, midZ), Color = hex(zone.ground), TopSurface = Enum.SurfaceType.Studs }))
		end
		local len = isl.maxZ - isl.minZ
		for _, w in {
			{ Vector3.new(2 * isl.halfX + 4, 60, 2), Vector3.new(0, 20, isl.maxZ + 1) },
			{ Vector3.new(2 * isl.halfX + 4, 60, 2), Vector3.new(0, 20, isl.minZ - 1) },
			{ Vector3.new(2, 60, len), Vector3.new(isl.halfX + 1, 20, 0) },
			{ Vector3.new(2, 60, len), Vector3.new(-isl.halfX - 1, 20, 0) },
		} do
			table.insert(items, Build.part({ Name = "Border", Size = w[1], CFrame = CFrame.new(w[2]), Transparency = 1, CastShadow = false }))
		end
		Build.flush(items, ground)
		return ("island %dx%d, %d zones"):format(2 * isl.halfX, len, #zones)
	end

	function phases.route()
		local route = Root.clear(id, "Route")
		local spawns = Root.clear(id, "Spawns")
		local items = {}
		local meadow = zones[1]
		-- spawn plaza
		local plazaDepth = spec.plazaZ[1] - spec.plazaZ[2]
		table.insert(items, Geo.slab(CFrame.new(0, 0.2, (spec.plazaZ[1] + spec.plazaZ[2]) / 2), 56, plazaDepth, 0.4, { Color = hex(meadow.path) }))
		local sp = Instance.new("SpawnLocation")
		sp.Name = "Spawn"
		sp.Anchored = true
		sp.Size = Vector3.new(10, 1, 10)
		sp.CFrame = CFrame.new(spec.spawn[1], 0.7, spec.spawn[3])
		sp.Color = hex(meadow.accent)
		sp.Material = Enum.Material.SmoothPlastic
		sp.TopSurface = Enum.SurfaceType.Smooth
		sp.Duration = 0
		sp.Neutral = true
		sp.Parent = spawns
		-- shop stalls facing the plaza centre, a leaderboard board behind the spawn
		table.insert(items, Props.stall(CFrame.new(-22, 0.2, 120) * CFrame.Angles(0, -math.pi / 2, 0), { text = "SHOP", color = "#FF5959" }))
		table.insert(items, Props.stall(CFrame.new(22, 0.2, 120) * CFrame.Angles(0, math.pi / 2, 0), { text = "REBIRTH", color = "#B480FF", signColor = "#8C5B9F" }))
		table.insert(items, Props.sign(CFrame.new(0, 0.2, 138), { text = "TOP LIFTERS", width = 18, height = 6, postHeight = 2, color = "#0D69AC" }))
		-- paths, ramps, arrows
		for i, zone in zones do
			local from, to = pathSpan(i)
			table.insert(items, Geo.slab(CFrame.new(0, zone.y + 0.2, (from + to) / 2), W, from - to, 0.4, { Color = hex(zone.path) }))
			local nextZone = zones[i + 1]
			if nextZone then
				table.insert(items, Geo.ramp(CFrame.new(0, zone.y, zone.z[2] + spec.rampLength), W, nextZone.y - zone.y + 0.2, spec.rampLength, { Color = hex(zone.path) }))
			end
			local arrowZs = (i == 1) and { 116, 96 } or { zone.z[1] - 12 }
			for _, z in arrowZs do
				-- plaza and paths both have their top 0.2 above the zone ground
				-- accent-coloured so they read on the light path (white vanished on cream)
				table.insert(items, Props.arrow(CFrame.new(0, zone.y + 0.2, z), { length = 8, width = 3.5, color = zone.arrow or zone.accent }))
			end
		end
		-- fences along the meadow path
		local from, to = pathSpan(1)
		for _, x in { -(W / 2 + 1.5), W / 2 + 1.5 } do
			table.insert(items, Props.fence(Vector3.new(x, 0, from - 8), Vector3.new(x, 0, to + 2), { spacing = 6 }))
		end
		Build.flush(items, route)
		return "plaza, spawn, " .. #zones .. " paths"
	end

	-- truncated low-poly cone (volcano) from triangles, with a neon crater
	local function volcano(parent)
		local v = spec.volcano
		local last = zones[#zones]
		local base = CFrame.new(v.pos[1], last.y, v.pos[2])
		local sides = 10
		local ring, top = {}, {}
		local rng = Random.new(spec.seed + 5)
		for i = 0, sides - 1 do
			local a = i / sides * 2 * math.pi
			local rb = v.radius * rng:NextNumber(0.9, 1.08)
			ring[i + 1] = (base * CFrame.new(math.cos(a) * rb, 0, math.sin(a) * rb)).Position
			top[i + 1] = (base * CFrame.new(math.cos(a) * v.topRadius, v.height, math.sin(a) * v.topRadius)).Position
		end
		local inside = (base * CFrame.new(0, v.height * 0.4, 0)).Position
		local m = Build.model("Volcano")
		for i = 1, sides do
			local j = i % sides + 1
			local color = hex(i % 2 == 0 and "#2A2627" or "#4A4749")
			Geo.tri(ring[i], ring[j], top[i], 1, { Color = color }, m, inside)
			Geo.tri(ring[j], top[j], top[i], 1, { Color = color }, m, inside)
		end
		local crater = Build.part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, v.topRadius * 2, v.topRadius * 2), CFrame = base * CFrame.new(0, v.height - 0.8, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = hex(last.neon), Material = Enum.Material.Neon, Parent = m })
		Build.decor(crater)
		m.Parent = parent
		return m
	end

	function phases.landmarks()
		local lm = Root.clear(id, "Landmarks")
		local items = {}
		for i, zone in zones do
			-- a gate right in front of spawn hides the landmark (measured), so a zone can opt out with "gate": false
			if zone.gate ~= false then
				local gateZ = (i == 1) and (spec.plazaZ[2] - 4) or (zone.z[1] - 4)
				table.insert(items, Props.gate(CFrame.new(0, zone.y, gateZ), { width = W + 4, height = spec.gateHeight, text = zone.name, color = zone.rock, trim = zone.trim, signColor = zone.accent }))
			end
			-- upgrade pad with a sign facing the path
			local pad = zone.pad
			table.insert(items, Props.pad(CFrame.new(pad[1], zone.y, pad[2]), { radius = 5, color = zone.accent, rim = zone.neon }))
			table.insert(items, Props.sign(CFrame.new(pad[1] + 8, zone.y, pad[2]) * CFrame.Angles(0, math.pi / 2, 0), { text = "+ STRENGTH", width = 7, height = 2.5, postHeight = 3, color = zone.accent }))
			-- liftable boulders on glowing lift spots, bigger every zone
			for k, r in zone.rocks do
				local cf = CFrame.new(r[2], zone.y, r[3])
				table.insert(items, Props.pad(cf, { radius = r[1] + 2, color = zone.path, rim = zone.neon }))
				table.insert(items, Props.boulder(cf * CFrame.new(0, 0.8, 0), { radius = r[1], color = zone.rock, rng = Random.new(spec.seed * 31 + i * 7 + k) }))
			end
		end
		-- the plateau, its stairs and THE boulder (the landmark you see from spawn)
		local b = spec.boulder
		local last = zones[#zones]
		local top = last.y + b.plateau
		local depth = b.plateauFront - isl.minZ
		local midZ = b.plateauFront - depth / 2
		-- basalt cliff with a dark lip, the path colour on top
		table.insert(items, Geo.box(CFrame.new(0, last.y + b.plateau / 2, midZ), Vector3.new(b.plateauWidth, b.plateau, depth), { Color = hex(last.ground) }))
		table.insert(items, Geo.box(CFrame.new(0, top - 0.5, midZ), Vector3.new(b.plateauWidth + 1, 1, depth + 1), { Color = hex(last.trim) }))
		table.insert(items, Geo.slab(CFrame.new(0, top + 0.2, midZ), b.plateauWidth - 4, depth - 4, 0.4, { Color = hex(last.path) }))
		table.insert(items, Geo.stairs(CFrame.new(0, last.y, b.plateauFront + b.plateau * 1.6), W, b.plateau, b.plateau, 1.6, { Color = hex(last.path) }))
		-- basalt columns along the cliff face (left and right of the stairs) so it isn't one flat wall
		local tones = { hex(last.ground), hex(last.trim), hex("#635F62") }
		local crng = Random.new(spec.seed + 17)
		for _, side in { -1, 1 } do
			local x = W / 2 + 1.5
			while x < b.plateauWidth / 2 do
				local h = b.plateau - crng:NextNumber(0, 2.5)
				table.insert(items, Build.part({ Size = Vector3.new(2.4, h, 1.2), CFrame = CFrame.new(side * x, last.y + h / 2, b.plateauFront + 0.5), Color = tones[crng:NextInteger(1, 3)] }))
				x += 2.5
			end
		end
		-- dark boulders hugging the cliff so the plateau stops reading as a box
		local brng = Random.new(spec.seed + 42)
		for _, p in b.cliffRocks do
			table.insert(items, Props.boulder(CFrame.new(p[1], last.y, p[2]), { radius = brng:NextNumber(4.5, 7), squash = 0.75, color = brng:NextNumber() < 0.5 and last.trim or last.ground, rng = brng }))
		end
		-- THE boulder on a gold lift ring: the biggest liftable, the thing you walk toward the whole map
		local bcf = CFrame.new(b.pos[1], top + 0.2, b.pos[3])
		table.insert(items, Props.pad(bcf, { radius = b.ring, color = last.path, rim = last.accent }))
		table.insert(items, Props.boulder(bcf * CFrame.new(0, 0.8, 0), { radius = b.radius, squash = b.squash, detail = b.detail, color = b.color, rng = Random.new(spec.seed + 99) }))
		table.insert(items, Props.sign(CFrame.new(18, top, b.plateauFront - 3) * CFrame.Angles(0, math.pi, 0), { text = b.title, width = 18, height = 3.5, postHeight = 3, color = last.accent }))
		volcano(lm)
		-- lava streams (Neon strips set into the volcano ground)
		for _, stream in spec.lava do
			for s = 1, #stream - 1 do
				local a = Vector3.new(stream[s][1], last.y + 0.1, stream[s][2])
				local c = Vector3.new(stream[s + 1][1], last.y + 0.1, stream[s + 1][2])
				local len = (c - a).Magnitude
				table.insert(items, Build.decor(Build.part({ Size = Vector3.new(5, 0.25, len + 4), CFrame = CFrame.lookAt((a + c) / 2, c), Color = hex(last.neon), Material = Enum.Material.Neon })))
			end
		end
		Build.flush(items, lm)
		return "gates, pads, liftables, plateau, boulder, volcano"
	end

	function phases.scatter()
		local fol = Root.clear(id, "Foliage")
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { Root.layer(id, "Ground") }
		local keepOut = {
			{ a = Vector2.new(0, isl.maxZ), b = Vector2.new(0, isl.minZ), radius = W / 2 + 6 },
			{ min = Vector2.new(-32, spec.plazaZ[2] - 2), max = Vector2.new(32, isl.maxZ) },
		}
		for _, inst in Root.layer(id, "Landmarks"):GetChildren() do
			local cf, size
			if inst:IsA("Model") then
				cf, size = inst:GetBoundingBox()
			else
				cf, size = inst.CFrame, inst.Size
			end
			if math.max(size.X, size.Z) < 120 then
				table.insert(keepOut, { center = Vector2.new(cf.X, cf.Z), radius = math.max(size.X, size.Z) / 2 + 4 })
			end
		end
		local b = spec.boulder
		table.insert(keepOut, { min = Vector2.new(-b.plateauWidth / 2 - 4, isl.minZ), max = Vector2.new(b.plateauWidth / 2 + 4, b.plateauFront + 14) })
		local count = 0
		for zi, zone in zones do
			local min = Vector2.new(-isl.halfX + 4, zone.z[2] + 3)
			local max = Vector2.new(isl.halfX - 4, zone.z[1] - 3)
			for di, d in zone.decor do
				local maker = Props[d.prop]
				assert(maker, "no prop called " .. d.prop)
				local made = Scatter.run({
					min = min, max = max, seed = spec.seed * 100 + zi * 10 + di,
					spacing = d.spacing,
					clusters = d.clusters and { spacing = d.clusters[1], radius = d.clusters[2], per = { d.clusters[3], d.clusters[4] }, minDist = d.clusters[5] },
					exclude = keepOut, clearance = d.clearance, params = params, maxSlope = 20, parent = fol,
					make = function(cf, rng)
						local opts = table.clone(d.opts or {})
						opts.rng = rng
						return maker(cf, opts)
					end,
				})
				count += #made
				task.wait()
			end
		end
		-- a few rocks on the beach ring
		local made = Scatter.run({
			min = Vector2.new(-isl.halfX - spec.beach.width, isl.minZ - spec.beach.width),
			max = Vector2.new(isl.halfX + spec.beach.width, isl.maxZ + spec.beach.width),
			seed = spec.seed + 11, spacing = 34,
			exclude = { { min = Vector2.new(-isl.halfX - 2, isl.minZ - 2), max = Vector2.new(isl.halfX + 2, isl.maxZ + 2) } },
			params = params, maxSlope = 20, parent = fol,
			make = function(cf, r)
				return Props.rock(cf, { rng = r, scale = r:NextNumber(0.6, 1), color = "#A9A8AB" })
			end,
		})
		count += #made
		-- clouds over and around the island
		local rng = Random.new(spec.seed + 3)
		local clouds = {}
		for _ = 1, 14 do
			local a = rng:NextNumber(0, 2 * math.pi)
			local d = rng:NextNumber(60, 260)
			table.insert(clouds, Props.cloud(CFrame.new(math.cos(a) * d, rng:NextNumber(80, 115), math.sin(a) * d) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), { scale = rng:NextNumber(1.5, 2.6), rng = rng }))
		end
		Build.flush(clouds, fol)
		return ("%d props, %d clouds"):format(count, #clouds)
	end

	function phases.lighting()
		local failures = K.Lighting.preset(spec.lighting)
		local T, w = workspace.Terrain, spec.water
		T.WaterColor = hex(w.color)
		T.WaterTransparency = w.transparency
		T.WaterReflectance = w.reflectance
		T.WaterWaveSize = w.waveSize
		T.WaterWaveSpeed = w.waveSpeed
		return #failures == 0 and "lighting ok" or ("lighting set, could not set: " .. table.concat(failures, "; "))
	end

	function phases.all()
		local out = {}
		for _, name in { "base", "route", "landmarks", "scatter", "lighting" } do
			table.insert(out, name .. ": " .. tostring(phases[name]()))
			task.wait()
		end
		return table.concat(out, "\n")
	end

	return phases
end
