-- Abandoned Farmhouse at Night (MapKit by fwjelaa, FWJ STUDIOS). Data: map.json. Style: styles/horror-house.md.
-- 1 stud = 0.28 m. Ground floor top y = 2, storeys 10. Walls are two layers (outside / inside material).
return function(K, spec)
	local id = spec.id
	local Root, Build, Geo, Materials, Models = K.Root, K.Build, K.Geo, K.Materials, K.Models
	local H, M = spec.house, spec.materials
	local phases = {}

	local G = H.ground -- ground floor top
	local U = G + H.storey + H.slab -- upper floor top
	local C = U + H.storey -- upper ceiling (bottom)
	local T = math.tan(math.rad(H.pitch))
	local CZ = (H.z0 + H.z1) / 2 -- ridge line
	local HALF = (H.z1 - H.z0) / 2

	local function v3(t)
		return Vector3.new(t[1], t[2], t[3])
	end
	local function hex(s)
		return Color3.fromHex(s)
	end
	local function rot(r)
		r = r or { 0, 0, 0 }
		return CFrame.Angles(0, math.rad(r[2]), 0) * CFrame.Angles(math.rad(r[1]), 0, math.rad(r[3]))
	end

	-- a part in one of the map's materials
	local function box(cf, size, key, parent, extra)
		local props = { CFrame = cf, Size = size, Parent = parent }
		for k, v in extra or {} do
			props[k] = v
		end
		return Materials.apply(Build.part(props), M[key], spec.tints and spec.tints[key])
	end

	-- rect = {x0, z0, x1, z1}: the rectangles that cover it minus axis-aligned holes
	local function minus(rect, holes)
		local xs = { rect[1], rect[3] }
		for _, h in holes do
			for _, x in { h[1], h[3] } do
				if x > rect[1] and x < rect[3] then
					table.insert(xs, x)
				end
			end
		end
		table.sort(xs)
		local out = {}
		for i = 1, #xs - 1 do
			local a, b = xs[i], xs[i + 1]
			if b - a > 1e-3 then
				local cuts = {}
				for _, h in holes do
					if h[1] <= a + 1e-3 and h[3] >= b - 1e-3 then
						table.insert(cuts, { math.max(h[2], rect[2]), math.min(h[4], rect[4]) })
					end
				end
				table.sort(cuts, function(p, q)
					return p[1] < q[1]
				end)
				local cur = rect[2]
				for _, c in cuts do
					if c[1] > cur + 1e-3 then
						table.insert(out, { a, cur, b, c[1] })
					end
					cur = math.max(cur, c[2])
				end
				if rect[4] > cur + 1e-3 then
					table.insert(out, { a, cur, b, rect[4] })
				end
			end
		end
		return out
	end

	local function slab(rect, top, thick, key, parent, holes)
		for _, r in minus(rect, holes or {}) do
			box(CFrame.new((r[1] + r[3]) / 2, top - thick / 2, (r[2] + r[4]) / 2), Vector3.new(r[3] - r[1], thick, r[4] - r[2]), key, parent)
		end
	end

	-- a wall from a to b ({x, z}), with its plus side (dir x up) and minus side in different materials
	local function wallFrame(w)
		local a, b = Vector3.new(w.a[1], 0, w.a[2]), Vector3.new(w.b[1], 0, w.b[2])
		local dir = (b - a).Unit
		return a, b, dir, dir:Cross(Vector3.yAxis)
	end

	local function openings(list)
		local out = {}
		for _, o in list do
			if o[1] == "d" then
				table.insert(out, { at = o[2], width = H.door[1], bottom = 0, top = H.door[2] })
			else
				local W = H.window
				table.insert(out, { at = o[2], width = W.width, bottom = W.sill, top = W.sill + W.height })
			end
		end
		return out
	end

	local function wall(w, base, height, parent)
		local a, b, _, n = wallFrame(w)
		local layers
		if w.kind == "ext" then
			local t = H.ext / 2
			layers = { { t / 2, t, "siding" }, { -t / 2, t, w["in"] } }
		else
			local t = H.int / 2
			layers = { { t / 2, t, w.plus }, { -t / 2, t, w.minus } }
		end
		local up = Vector3.new(0, base, 0)
		for _, l in layers do
			local m = Geo.wall(a + n * l[1] + up, b + n * l[1] + up, height, l[2], openings(w.open), nil, parent)
			for _, p in m:GetChildren() do
				Materials.apply(p, M[l[3]])
			end
		end
	end

	local function eachOpening(fn)
		for floorName, list in { g = spec.walls.ground, u = spec.walls.upper } do
			local base = floorName == "g" and G or U
			for wi, w in list do
				for oi, o in w.open do
					fn(("%s%d-%d"):format(floorName, wi - 1, oi - 1), w, o, base)
				end
			end
		end
	end

	-- the roof surface at the wall planes is y = C + 0.5 (the top of the upper walls)
	local EAVE = C + 0.5
	local function roofPiece(sign, x0, x1, f0, f1, parent, thick, key)
		-- sign 1 = front (south) slope, -1 = back; f = fraction of the slope from the eave
		local run = HALF + H.overhang
		local L = run / math.cos(math.rad(H.pitch))
		local eaveZ = CZ + sign * run
		local eaveY = EAVE - H.overhang * T
		local n = Vector3.new(0, math.cos(math.rad(H.pitch)), sign * math.sin(math.rad(H.pitch)))
		local down = Vector3.new(0, -math.sin(math.rad(H.pitch)), sign * math.cos(math.rad(H.pitch)))
		local eave = Vector3.new(0, eaveY, eaveZ)
		local mid = eave - down * (L * (f0 + f1) / 2) + n * (thick / 2)
		local cf = CFrame.fromMatrix(Vector3.new((x0 + x1) / 2, mid.Y, mid.Z), Vector3.xAxis, n)
		return box(cf, Vector3.new(x1 - x0, thick, L * (f1 - f0)), key, parent)
	end

	-- drop a model so its lowest point sits at y
	local function settle(model, y)
		local low = math.huge
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				for _, sx in { -1, 1 } do
					for _, sy in { -1, 1 } do
						for _, sz in { -1, 1 } do
							low = math.min(low, d.CFrame:PointToWorldSpace(d.Size / 2 * Vector3.new(sx, sy, sz)).Y)
						end
					end
				end
			end
		end
		model:PivotTo(model:GetPivot() + Vector3.new(0, y - low, 0))
	end

	function phases.materials()
		local names = {}
		for _, v in M do
			table.insert(names, v)
		end
		table.sort(names)
		Materials.install(names)
		Materials.override(Enum.Material.Grass, M.grass)
		Materials.override(Enum.Material.Mud, M.mud)
		Materials.override(Enum.Material.LeafyGrass, M.leaves)
		return "installed " .. #names .. " materials; terrain Grass/Mud/LeafyGrass overridden"
	end

	local function modelNames()
		local set, names = {}, {}
		for _, p in spec.props do
			set[p.m] = true
		end
		for _, s in spec.scatter do
			set[s.m] = true
		end
		for n in set do
			table.insert(names, n)
		end
		table.sort(names)
		return names
	end

	function phases.models()
		local names = modelNames()
		Models.install(names)
		return "installed " .. #names .. " models"
	end

	function phases.base()
		local ground = Root.clear(id, "Ground")
		Root.removeTemplate()
		local tb = spec.terrain.box
		Root.claimTerrain(id, CFrame.new(v3(tb.center)), v3(tb.size))
		local Tr = workspace.Terrain
		local size = tb.size[1] - 20
		local g = spec.terrain.ground
		Tr:FillBlock(CFrame.new(0, g.top - g.depth / 2, 0), Vector3.new(size, g.depth, size), Enum.Material.Grass)
		for _, m in spec.terrain.mounds do
			local r = m[3]
			Tr:FillBall(Vector3.new(m[1], 0.14 * r - r, m[2]), r, Enum.Material.Grass)
		end
		local rd = spec.terrain.road
		Tr:FillBlock(CFrame.new(0, -1, (rd.z0 + rd.z1) / 2), Vector3.new(size, 2.2, rd.z1 - rd.z0), Enum.Material.Mud)
		-- the drive: two winding wheel ruts with grass between them, not a ribbon
		local dv = spec.terrain.drive
		local rng = Random.new(spec.seed)
		local cx = (dv.x0 + dv.x1) / 2
		for z = dv.z0, dv.z1 + 2, 1.5 do
			local wob = 1.4 * math.sin(z / 17) + 0.6 * math.sin(z / 5.3)
			for _, side in { -1.9, 1.9 } do
				Tr:FillBall(Vector3.new(cx + side + wob + rng:NextNumber(-0.25, 0.25), -1.75, z), rng:NextNumber(1.7, 2.1), Enum.Material.Mud)
			end
		end
		-- no grass under the house and porch (terrain grass blades grow through floors) and a trodden apron at the steps
		local P0 = spec.porch
		Tr:FillBlock(CFrame.new(0, -1.2, (H.z0 - 4 + P0.z1 + 4) / 2), Vector3.new(H.x1 - H.x0 + 8, 2.6, P0.z1 - H.z0 + 8), Enum.Material.Mud)
		for i = 0, 6 do
			Tr:FillBall(Vector3.new(1 + rng:NextNumber(-4, 4), -2.2, P0.z1 + 3 + i * 1.2), rng:NextNumber(2.5, 3.5), Enum.Material.Mud)
		end
		for _, l in spec.terrain.leaves do
			Tr:FillCylinder(CFrame.new(l[1], -0.6, l[2]), 1.4, l[3], Enum.Material.LeafyGrass)
		end
		-- stone foundation under the house and the porch piers
		box(CFrame.new(0, (G - H.slab - 3) / 2 + 0.0, CZ), Vector3.new(H.x1 - H.x0, G - H.slab + 3, H.z1 - H.z0), "stone", ground)
		local P = spec.porch
		for _, x in { -21.5, -11, 0, 11, 21.5 } do
			box(CFrame.new(x, 0, P.z1 - 0.7), Vector3.new(1.2, 2.2, 1.2), "stone", ground)
		end
		local sp = Instance.new("SpawnLocation")
		sp.Name = "Spawn"
		sp.Anchored = true
		sp.Size = Vector3.new(6, 1, 6)
		sp.CFrame = CFrame.new(spec.spawn[1], 0.1, spec.spawn[3])
		sp.Transparency = 1
		sp.CanCollide = false
		sp.Duration = 0
		sp.Neutral = true
		sp.Parent = Root.clear(id, "Spawns")
		return "terrain, road, drive, foundation, spawn"
	end

	function phases.house()
		local s = Root.clear(id, "Structures")
		local inner = { H.x0 + H.ext, H.z0 + H.ext, H.x1 - H.ext, H.z1 - H.ext }
		local st = H.stairs
		local stairEnd = st.z - st.steps * st.run
		local well = { st.x0, stairEnd, st.x1, st.z }
		local fh, ch = H.floorHole, H.ceilingHole
		-- floors and ceilings
		slab({ H.x0, H.z0, H.x1, H.z1 }, G, H.slab, "floor", s)
		slab(inner, U, H.slab / 2, "floor", s, { well, fh })
		slab(inner, U - H.slab / 2, H.slab / 2, "plaster", s, { well, fh })
		slab(inner, C + 0.5, 0.5, "plaster", s, { ch })
		-- kitchen tiles over the boards
		slab({ 6.25, H.z0 + H.ext, inner[3], -10.25 }, G + 0.05, 0.1, "tiles", s)
		task.wait()
		-- walls: exterior ones run through the floor band so the outside is continuous
		for _, w in spec.walls.ground do
			if w.kind == "ext" then
				wall(w, G, H.storey + H.slab, s)
			else
				wall(w, G, H.storey, s)
			end
		end
		task.wait()
		for _, w in spec.walls.upper do
			if w.kind == "ext" then
				wall(w, U, H.storey + 0.5, s)
			else
				wall(w, U, H.storey, s)
			end
		end
		task.wait()
		-- stairs up the west side of the hall, rising north
		local stairs = Geo.stairs(CFrame.new((st.x0 + st.x1) / 2, G, st.z), st.x1 - st.x0, U - G, st.steps, st.run, nil, s)
		for _, p in stairs:GetChildren() do
			Materials.apply(p, M.floor)
		end
		-- gables
		local apex = EAVE + HALF * T
		for _, x in { H.x0, H.x1 } do
			local tri = Instance.new("Model")
			tri.Name = "Gable"
			local w1, w2 = Geo.tri(Vector3.new(x, EAVE, H.z1), Vector3.new(x, EAVE, H.z0), Vector3.new(x, apex, CZ), H.ext,
				nil, tri, Vector3.new(0, EAVE + 4, CZ))
			for _, p in { w1, w2 } do
				if p then
					Materials.apply(p, M.siding)
				end
			end
			tri.Parent = s
		end
		-- roof: the front slope has a hole over bedroom 2 with rotten rafters showing
		local rh = H.roofHole
		local xo0, xo1 = H.x0 - H.overhang, H.x1 + H.overhang
		roofPiece(-1, xo0, xo1, 0, 1, s, 0.8, "roof")
		roofPiece(1, xo0, rh.x0, 0, 1, s, 0.8, "roof")
		roofPiece(1, rh.x1, xo1, 0, 1, s, 0.8, "roof")
		roofPiece(1, rh.x0, rh.x1, 0, rh.from, s, 0.8, "roof")
		roofPiece(1, rh.x0, rh.x1, rh.to, 1, s, 0.8, "roof")
		for i, x in { rh.x0 + 1, rh.x0 + 3, rh.x0 + 5.2, rh.x0 + 7 } do
			local f1 = i == 3 and 0.55 or 1 -- one rafter rotted through
			local r = roofPiece(1, x - 0.2, x + 0.2, 0, f1, s, 0.6, "boards")
			r.CFrame = r.CFrame * CFrame.new(0, -0.7, 0)
		end
		local ridgeY = EAVE + HALF * T + 0.8 / math.cos(math.rad(H.pitch))
		box(CFrame.new(0, ridgeY, CZ), Vector3.new(xo1 - xo0, 0.5, 1.4), "boards", s)
		-- chimney
		local c = H.chimney
		box(CFrame.new((c[1] + c[3]) / 2, (c[5] - 1) / 2, (c[2] + c[4]) / 2), Vector3.new(c[3] - c[1], c[5] + 1, c[4] - c[2]), "stone", s)
		task.wait()
		-- porch: deck (one board missing), steps, posts, header, shed roof, railings
		local P = spec.porch
		local mb = P.missingBoard
		slab({ H.x0, H.z1, H.x1, P.z1 }, G, H.slab, "porch", s, { mb })
		local steps = Geo.stairs(CFrame.new((P.steps[1] + P.steps[2]) / 2, 0, P.z1 + 3 * 1.2), P.steps[2] - P.steps[1], G, 3, 1.2, nil, s)
		for _, p in steps:GetChildren() do
			Materials.apply(p, M.porch)
		end
		local postZ = P.z1 - 0.4
		for _, x in P.posts do
			box(CFrame.new(x, G + 5, postZ), Vector3.new(0.7, 10, 0.7), "boards", s)
		end
		box(CFrame.new(0, G + 10.3, postZ), Vector3.new(H.x1 - H.x0, 0.8, 0.7), "boards", s)
		local y0, y1, z0, z1 = U + 0.4, G + 10.7, H.z1, P.z1 + 0.8
		local L = Vector3.new(0, y1 - y0, z1 - z0)
		local n = Vector3.xAxis:Cross(L.Unit)
		n = n.Y < 0 and -n or n
		local mid = Vector3.new(0, (y0 + y1) / 2, (z0 + z1) / 2) + n * 0.25
		box(CFrame.fromMatrix(mid, Vector3.xAxis, n), Vector3.new(H.x1 - H.x0 + 1, 0.5, L.Magnitude), "roof", s)
		local rails = Instance.new("Model")
		rails.Name = "Railings"
		local function rail(a, b, broken)
			local d = b - a
			local len = d.Magnitude
			local dir = d.Unit
			local cf = CFrame.lookAt(a, b)
			local topLen = broken and len * 0.45 or len
			box(cf * CFrame.new(0, 3.0, -topLen / 2), Vector3.new(0.3, 0.25, topLen), "boards", rails)
			box(cf * CFrame.new(0, 0.45, -len / 2), Vector3.new(0.3, 0.25, len), "boards", rails)
			local i = 0
			for t = 0.9, len - 0.5, 0.9 do
				i += 1
				if not (broken and i % 3 == 0) then
					local tilt = broken and t > len * 0.45 and math.rad(14) or 0
					box(cf * CFrame.new(0, 1.75, -t) * CFrame.Angles(tilt, 0, 0), Vector3.new(0.22, 2.6, 0.22), "boards", rails)
				end
			end
		end
		local posts = P.posts
		for i = 1, #posts - 1 do
			local x0, x1 = posts[i], posts[i + 1]
			if not (x0 <= P.steps[1] and x1 >= P.steps[2]) then
				rail(Vector3.new(x0 + 0.35, G, postZ), Vector3.new(x1 - 0.35, G, postZ), x0 == P.brokenRail[1])
			end
		end
		for _, x in { posts[1], posts[#posts] } do
			rail(Vector3.new(x, G, postZ - 0.35), Vector3.new(x, G, H.z1 + 0.5), false)
		end
		rails.Parent = s
		return "floors, walls, stairs, roof, chimney, porch"
	end

	function phases.trim()
		local t = Root.clear(id, "Route")
		local rng = Random.new(spec.seed + 1)
		local boarded = {}
		for _, k in spec.boarded do
			boarded[k] = true
		end
		local glassColor = hex(spec.colors.glass)
		eachOpening(function(key, w, o, base)
			if w.kind ~= "ext" then
				return
			end
			local a, _, dir, n = wallFrame(w)
			local isDoor = o[1] == "d"
			local width = isDoor and H.door[1] or H.window.width
			local bottom = isDoor and 0 or H.window.sill
			local top = isDoor and H.door[2] or H.window.sill + H.window.height
			local c = a + dir * o[2]
			local face = H.ext / 2 + 0.12
			local function at(along, y, out)
				return CFrame.fromMatrix(c + dir * along + n * out + Vector3.new(0, base + y, 0), dir, Vector3.yAxis)
			end
			-- trim boards around every outside opening
			for _, s in { -1, 1 } do
				box(at(s * (width / 2 + 0.2), (bottom + top) / 2 + 0.2, face), Vector3.new(0.4, top - bottom + 0.8, 0.24), "boards", t)
			end
			box(at(0, top + 0.42, face), Vector3.new(width + 1.2, 0.45, 0.24), "boards", t)
			if isDoor then
				return
			end
			box(at(0, bottom - 0.12, face + 0.15), Vector3.new(width + 1.0, 0.24, 0.55), "boards", t)
			if boarded[key] then
				for i, y in { bottom + 0.9, (bottom + top) / 2, top - 0.9 } do
					local b = box(at(rng:NextNumber(-0.2, 0.2), y, face + 0.2) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-9, 9))),
						Vector3.new(width + 0.9, 0.6, 0.14), "boards", t)
					b.Name = "Board" .. i
				end
			elseif rng:NextNumber() < 0.75 then
				local g = Build.part({ CFrame = at(0, (bottom + top) / 2, 0), Size = Vector3.new(width, top - bottom, 0.08),
					Material = Enum.Material.Glass, Transparency = 0.72, Color = glassColor, Parent = t })
				g.Name = "Glass"
			end
		end)
		-- the front door hangs open, hinged on the east jamb; the back door lies in the yard
		local front = spec.walls.ground[1]
		local a, _, dir, n = wallFrame(front)
		local hinge = a + dir * (23 + H.door[1] / 2) + Vector3.new(0, G, 0) - n * 0.2
		local open = math.rad(100)
		local leafDir = -(dir * math.cos(open)) - n * math.sin(open)
		local door = box(CFrame.fromMatrix(hinge + leafDir * (H.door[1] / 2) + Vector3.new(0, H.door[2] / 2, 0), leafDir, Vector3.yAxis),
			Vector3.new(H.door[1], H.door[2], 0.25), "boards", t)
		door.Name = "FrontDoor"
		local back = box(CFrame.new(-1, 0.3, H.z0 - 6) * CFrame.Angles(math.rad(90), math.rad(20), 0),
			Vector3.new(H.door[1], H.door[2], 0.25), "boards", t)
		back.Name = "BackDoor"
		-- stairwell railing upstairs and a handrail up the open side of the stairs
		local st = H.stairs
		local stairEnd = st.z - st.steps * st.run
		local rails = Instance.new("Model")
		rails.Name = "StairRails"
		local function rail(p0, p1, posts)
			local len = (p1 - p0).Magnitude
			local cf = CFrame.lookAt(p0, p1)
			box(cf * CFrame.new(0, 0, -len / 2), Vector3.new(0.3, 0.25, len), "boards", rails)
			for i = 0, posts do
				local p = p0:Lerp(p1, posts > 0 and i / posts or 0)
				box(CFrame.new(p.X, p.Y - 1.5, p.Z), Vector3.new(0.2, 3, 0.2), "boards", rails)
			end
		end
		local x = st.x1 + 0.15
		rail(Vector3.new(x, U + 3, st.z), Vector3.new(x, U + 3, stairEnd), 14)
		rail(Vector3.new(st.x0 + 0.1, U + 3, st.z + 0.15), Vector3.new(x, U + 3, st.z + 0.15), 4)
		rail(Vector3.new(x, G + 3.4, st.z + 0.2), Vector3.new(x, U + 3.2, stairEnd + 0.5), 0)
		box(CFrame.new(x, G + 2, st.z + 0.2), Vector3.new(0.5, 4, 0.5), "boards", rails)
		rails.Parent = t
		-- the porch lantern hangs on a chain from the porch roof
		local lantern = spec.lights[1]
		local chain = Build.part({ Name = "Chain", CFrame = CFrame.new(lantern.pos[1], 12.0, lantern.pos[3]), Size = Vector3.new(0.08, 1.9, 0.08),
			Color = hex(spec.colors.dark), Material = Enum.Material.Metal, Parent = t })
		Build.decor(chain)
		return "window trim, glass, boards, doors, stair rails"
	end

	function phases.decay()
		local d = Root.clear(id, "Landmarks")
		local rng = Random.new(spec.seed + 2)
		local fh = H.floorHole
		local cx, cz = (fh[1] + fh[3]) / 2, (fh[2] + fh[4]) / 2
		-- what fell through: planks and plaster on the parlour floor
		for i = 1, 9 do
			local len = rng:NextNumber(2, 5)
			local p = box(CFrame.new(cx + rng:NextNumber(-3, 3), G + 0.2 + i * 0.03, cz + rng:NextNumber(-3, 3))
				* CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), math.rad(rng:NextNumber(0, 180)), math.rad(rng:NextNumber(-6, 6))),
				Vector3.new(0.45, 0.15, len), "boards", d)
			p.Name = "Plank"
		end
		for i = 1, 12 do
			local sz = rng:NextNumber(0.5, 1.4)
			local p = box(CFrame.new(cx + rng:NextNumber(-3.5, 3.5), G + sz * 0.15, cz + rng:NextNumber(-3.5, 3.5))
				* CFrame.Angles(math.rad(rng:NextNumber(-20, 20)), math.rad(rng:NextNumber(0, 180)), 0),
				Vector3.new(sz, sz * 0.3, sz * 0.8), "plaster", d)
			p.Name = "Plaster"
		end
		-- broken boards hanging into the hole upstairs
		for i, e in { { fh[1], cz, 90 }, { fh[3], cz, -90 }, { cx, fh[2], 0 }, { cx - 0.8, fh[4], 180 } } do
			local p = box(CFrame.new(e[1], U - 0.6, e[2]) * CFrame.Angles(0, math.rad(e[3]), 0) * CFrame.Angles(math.rad(-30 - i * 4), 0, 0)
				* CFrame.new(0, 0, -0.9), Vector3.new(0.5, 0.15, 2.2), "floor", d)
			p.Name = "BrokenBoard"
			Build.decor(p)
		end
		-- ragged edges: board ends of uneven length stick into the floor hole, some bent down
		local function stubs(x0, z0, x1, z1, inward, count)
			for i = 1, count do
				local f = (i - 0.5) / count
				local p0 = Vector3.new(x0 + (x1 - x0) * f, U - 0.25, z0 + (z1 - z0) * f)
				local len = rng:NextNumber(0.3, 1.5)
				local bend = rng:NextNumber() < 0.4 and math.rad(rng:NextNumber(15, 40)) or 0
				local cf = CFrame.lookAt(p0, p0 + inward) * CFrame.Angles(-bend, 0, 0) * CFrame.new(0, 0, -len / 2)
				Build.decor(box(cf, Vector3.new(0.45, 0.16, len), "floor", d)).Name = "BoardEnd"
			end
		end
		stubs(fh[1], fh[2], fh[3], fh[2], Vector3.zAxis, 5)
		stubs(fh[1], fh[4], fh[3], fh[4], -Vector3.zAxis, 5)
		stubs(fh[1], fh[2], fh[1], fh[4], Vector3.xAxis, 4)
		stubs(fh[3], fh[2], fh[3], fh[4], -Vector3.xAxis, 4)
		-- lath strips hanging from the broken ceiling break up the square of moonlight
		local chole = H.ceilingHole
		for i = 1, 9 do
			local edge = rng:NextInteger(1, 4)
			local x = edge <= 2 and rng:NextNumber(chole[1], chole[3]) or (edge == 3 and chole[1] or chole[3])
			local z = edge >= 3 and rng:NextNumber(chole[2], chole[4]) or (edge == 1 and chole[2] or chole[4])
			local inward = Vector3.new(edge == 3 and 1 or edge == 4 and -1 or 0, 0, edge == 1 and 1 or edge == 2 and -1 or 0)
			local len = rng:NextNumber(1.2, 3.2)
			local top = Vector3.new(x, C + 0.4, z)
			local cf = CFrame.lookAt(top, top + inward) * CFrame.Angles(math.rad(-rng:NextNumber(35, 75)), 0, 0) * CFrame.new(0, 0, -len / 2)
			local lath = Build.decor(box(cf, Vector3.new(0.18, 0.08, len), "boards", d))
			lath.Name, lath.CastShadow = "Lath", true -- small, but its shadow is the point
		end
		-- sagging plaster flaps at the ceiling hole's corners so the moonlight isn't a clean square
		for _, c in { { chole[1], chole[2], 1, 1 }, { chole[3], chole[2], -1, 1 }, { chole[1], chole[4], 1, -1 }, { chole[3], chole[4], -1, -1 } } do
			local w, l = rng:NextNumber(1.2, 2.2), rng:NextNumber(1.2, 2.4)
			local cf = CFrame.new(c[1] + c[3] * w / 2, C + 0.2, c[2] + c[4] * l / 2)
				* CFrame.Angles(math.rad(c[4] * rng:NextNumber(8, 22)), 0, math.rad(-c[3] * rng:NextNumber(8, 22)))
			local flap = Build.decor(box(cf, Vector3.new(w, 0.3, l), "plaster", d))
			flap.Name, flap.CastShadow = "Flap", true
		end
		-- fallen plaster around the hole upstairs too
		for i = 1, 7 do
			local sz = rng:NextNumber(0.4, 1.1)
			local ang = rng:NextNumber(0, 2 * math.pi)
			local r = rng:NextNumber(2.4, 4.5)
			box(CFrame.new(cx + math.cos(ang) * r, U + sz * 0.15, cz + math.sin(ang) * r) * CFrame.Angles(0, ang, math.rad(rng:NextNumber(-10, 10))),
				Vector3.new(sz, sz * 0.3, sz * 0.8), "plaster", d).Name = "Plaster"
		end
		-- loose porch boards
		for i = 1, 2 do
			local p = box(CFrame.new(16 + i * 1.5, G + 0.1, 11 + i) * CFrame.Angles(0, math.rad(20 + i * 50), math.rad(4)),
				Vector3.new(0.9, 0.12, 5.5), "porch", d)
			p.Name = "LooseBoard"
		end
		return "debris, broken boards, loose porch boards"
	end

	function phases.furnish()
		local layer = Root.clear(id, "Props")
		local n = 0
		for _, p in spec.props do
			-- light sources (lanterns, lamps, bulbs) must not shadow their own light: "s": false
			local m = Models.place(p.m, CFrame.new(v3(p.p)) * rot(p.r), { parent = layer, collision = p.c, shadow = p.s ~= false, tint = p.t })
			if p.settle then
				settle(m, p.p[2])
			end
			n += 1
			if n % 10 == 0 then
				task.wait()
			end
		end
		return n .. " props"
	end

	function phases.yard()
		local f = Root.clear(id, "Foliage")
		local rng = Random.new(spec.seed + 3)
		-- picket fence along the road, with a gate gap, missing and leaning pickets and one fallen run
		local fe = spec.fence
		local fence = Instance.new("Model")
		fence.Name = "Fence"
		local fallen = { fe.x0 + 16, fe.x0 + 24 }
		for x0 = fe.x0, fe.x1 - 8, 8 do
			local x1 = x0 + 8
			if not (x1 > fe.gate[1] and x0 < fe.gate[2]) then
				local down = x0 >= fallen[1] and x1 <= fallen[2]
				for _, px in { x0, x1 } do
					box(CFrame.new(px, 1.8, fe.z), Vector3.new(0.5, 4.6, 0.5), "boards", fence)
				end
				if down then
					local run = Instance.new("Model")
					run.Name = "FallenRun"
					for x = x0 + 0.6, x1 - 0.4, fe.spacing do
						box(CFrame.new(x, 0.15, fe.z + 1.8) * CFrame.Angles(math.rad(90), 0, math.rad(rng:NextNumber(-6, 6))), Vector3.new(0.35, 3.8, 0.12), "boards", run)
					end
					box(CFrame.new((x0 + x1) / 2, 0.2, fe.z + 0.9), Vector3.new(8, 0.25, 0.15), "boards", run)
					run.Parent = fence
				else
					for _, y in { 1.2, 3.0 } do
						box(CFrame.new((x0 + x1) / 2, y, fe.z + 0.3), Vector3.new(8, 0.25, 0.15), "boards", fence)
					end
					for x = x0 + 0.6, x1 - 0.4, fe.spacing do
						local r = rng:NextNumber()
						if r > 0.12 then
							local lean = r < 0.3 and math.rad(rng:NextNumber(-16, 16)) or 0
							box(CFrame.new(x, 1.9, fe.z + 0.45) * CFrame.Angles(0, 0, lean), Vector3.new(0.35, 3.8, 0.12), "boards", fence)
						end
					end
				end
			end
		end
		fence.Parent = f
		-- mailbox, leaning, by the road
		local mb = Instance.new("Model")
		mb.Name = "Mailbox"
		local base = CFrame.new(v3(spec.mailbox)) * CFrame.Angles(0, math.rad(8), math.rad(7))
		box(base * CFrame.new(0, 2.0, 0), Vector3.new(0.4, 4.0, 0.4), "boards", mb)
		box(base * CFrame.new(0, 4.25, 0), Vector3.new(0.9, 0.55, 1.9), "rust", mb)
		local top = box(base * CFrame.new(0, 4.55, 0) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(1.9, 0.9, 0.9), "rust", mb)
		top.Shape = Enum.PartType.Cylinder
		box(base * CFrame.new(0.5, 4.6, 0.3), Vector3.new(0.06, 0.12, 0.9), "rust", mb).Name = "FlagArm"
		box(base * CFrame.new(0.52, 4.95, 0.65), Vector3.new(0.05, 0.5, 0.35), "rust", mb).Name = "Flag"
		mb.Parent = f
		-- scattered brush on the ground, never on the house, porch, drive or road
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { workspace.Terrain }
		local dv, rd = spec.terrain.drive, spec.terrain.road
		local function blocked(x, z)
			return (x > H.x0 - 5 and x < H.x1 + 5 and z > H.z0 - 5 and z < spec.porch.z1 + 6)
				or (x > dv.x0 - 3 and x < dv.x1 + 3 and z > dv.z0 - 4 and z < dv.z1)
				or (z > rd.z0 - 3 and z < rd.z1 + 3)
				or (math.abs(z - fe.z) < 2.5 and x > fe.x0 - 2 and x < fe.x1 + 2)
		end
		local placed = 0
		for _, s in spec.scatter do
			local made, tries = 0, 0
			while made < s.count and tries < s.count * 20 do
				tries += 1
				local near = s.near[rng:NextInteger(1, #s.near)]
				local ang, dist = rng:NextNumber(0, 2 * math.pi), near[3] * math.sqrt(rng:NextNumber())
				local x, z = near[1] + math.cos(ang) * dist, near[2] + math.sin(ang) * dist
				if not blocked(x, z) then
					local hit = workspace:Raycast(Vector3.new(x, 40, z), Vector3.new(0, -80, 0), params)
					if hit then
						Models.place(s.m, CFrame.new(x, hit.Position.Y - 0.15, z) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0), {
							parent = f, collision = "none", shadow = false, scale = rng:NextNumber(0.8, 1.35),
							variant = s.variants and rng:NextInteger(1, s.variants) or nil,
						})
						made += 1
					end
				end
			end
			placed += made
			task.wait()
		end
		return ("fence, mailbox, %d scattered"):format(placed)
	end

	function phases.lighting()
		local layer = Root.clear(id, "Lights")
		local failures = K.Lighting.preset(spec.lighting)
		local glowColor = hex(spec.colors.glow)
		for _, l in spec.lights do
			local holder = Build.decor(Build.part({ Name = l.name, CFrame = CFrame.new(v3(l.pos)), Size = Vector3.new(0.3, 0.3, 0.3),
				Transparency = 1, Color = glowColor, Parent = layer }))
			local light
			if l.spot then
				light = Instance.new("SpotLight")
				light.Angle = l.spot.angle
				light.Face = Enum.NormalId[l.spot.face]
			else
				light = Instance.new("PointLight")
			end
			light.Range, light.Brightness, light.Shadows = l.range, l.brightness, l.shadows
			light.Color = Color3.fromRGB(l.color[1], l.color[2], l.color[3])
			light.Parent = holder
			if l.glow then
				local g = Build.decor(Build.part({ Name = "Glow", Shape = Enum.PartType.Ball, CFrame = holder.CFrame, Size = Vector3.new(0.35, 0.35, 0.35),
					Material = Enum.Material.Neon, Color = glowColor, Parent = holder }))
				g.CastShadow = false
			end
			if l.flicker then
				holder:SetAttribute("Flicker", true)
			end
		end
		local s = Instance.new("Script")
		s.Name = "Flicker"
		s.Source = [[
-- A failing bulb (Abandoned Farmhouse, MapKit by fwjelaa).
local lights = {}
for _, p in script.Parent:GetChildren() do
	if p:GetAttribute("Flicker") then table.insert(lights, p) end
end
while true do
	task.wait(math.random(15, 50) / 10)
	for _, p in lights do
		local l = p:FindFirstChildWhichIsA("Light")
		local g = p:FindFirstChild("Glow")
		for _ = 1, math.random(2, 6) do
			if l then l.Enabled = false end
			if g then g.Transparency = 1 end
			task.wait(math.random(3, 14) / 100)
			if l then l.Enabled = true end
			if g then g.Transparency = 0 end
			task.wait(math.random(3, 25) / 100)
		end
	end
end
]]
		s.Parent = layer
		return #failures == 0 and "night lighting, " .. #spec.lights .. " lights" or table.concat(failures, "; ")
	end

	function phases.ambience()
		local manifest = K.Http.json("assets.json")
		local wind = manifest.sounds and manifest.sounds[spec.sound.wind]
		if wind and wind.id then
			K.Sound.ambience(id, "Wind", wind.id, { volume = spec.sound.volume })
		end
		K.Sound.reverb(spec.sound.reverb)
		return wind and wind.id and "wind on" or ("wind missing: run `python kit/tools/run.py wind %s`, then this phase again"):format(spec.sound.wind)
	end

	function phases.all()
		local out = {}
		for _, name in { "materials", "models", "base", "house", "trim", "decay", "furnish", "yard", "lighting", "ambience" } do
			table.insert(out, name .. ": " .. tostring(phases[name]()))
			task.wait()
		end
		return table.concat(out, "\n")
	end

	return phases
end
