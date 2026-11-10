-- Backrooms Level 0: an endless half-renovated office floor. Method by fwjelaa (FWJ STUDIOS).
-- Phases: materials, shell, walls, lights, details, ambience, all.   K.run("backrooms-level-0", "<phase>")
return function(K, spec)
	local Build, Geo, Root, Materials = K.Build, K.Geo, K.Root, K.Materials
	local id = spec.id
	local hex = Color3.fromHex
	local G = spec.grid
	local N, C = G.cells, G.cell
	local ox, oz = G.origin[1], G.origin[3]
	local H = spec.ceiling
	local phases = {}

	local function centre(i, j)
		return ox + (i + 0.5) * C, oz + (j + 0.5) * C
	end
	local function inRect(i, j, r)
		return i >= r.from[1] and i <= r.to[1] and j >= r.from[2] and j <= r.to[2]
	end
	local function inHall(i, j)
		return j == spec.hallway.row and i >= spec.hallway.from and i <= spec.hallway.to
	end

	-- Layout: wall[i][j].e = wall between (i,j) and (i+1,j); .s = between (i,j) and (i,j+1). Deterministic per seed.
	local function layout()
		local rng = Random.new(spec.seed)
		local wall = {}
		for i = 0, N - 1 do
			wall[i] = {}
			for j = 0, N - 1 do
				wall[i][j] = { e = i < N - 1, s = j < N - 1 }
			end
		end
		local function open(i, j, di, dj)
			if di == 1 then
				wall[i][j].e = false
			elseif di == -1 then
				wall[i - 1][j].e = false
			elseif dj == 1 then
				wall[i][j].s = false
			else
				wall[i][j - 1].s = false
			end
		end
		local function isOpen(i, j, di, dj)
			if di == 1 then
				return not wall[i][j].e
			elseif di == -1 then
				return not wall[i - 1][j].e
			elseif dj == 1 then
				return not wall[i][j].s
			else
				return not wall[i][j - 1].s
			end
		end
		local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
		local function inside(i, j)
			return i >= 0 and j >= 0 and i < N and j < N
		end
		-- 1. random spanning tree (every cell connected)
		local seen, stack = { [0 .. ":" .. (N - 1)] = true }, { { 0, N - 1 } }
		while #stack > 0 do
			local c = stack[#stack]
			local options = {}
			for _, d in DIRS do
				local ni, nj = c[1] + d[1], c[2] + d[2]
				if inside(ni, nj) and not seen[ni .. ":" .. nj] then
					table.insert(options, d)
				end
			end
			if #options == 0 then
				table.remove(stack)
			else
				local d = options[rng:NextInteger(1, #options)]
				open(c[1], c[2], d[1], d[2])
				seen[(c[1] + d[1]) .. ":" .. (c[2] + d[2])] = true
				table.insert(stack, { c[1] + d[1], c[2] + d[2] })
			end
		end
		-- 2. open extra walls so rooms merge (Level 0 is segmented rooms, not a maze)
		for i = 0, N - 1 do
			for j = 0, N - 1 do
				if wall[i][j].e and rng:NextNumber() < spec.wall.open then
					wall[i][j].e = false
				end
				if wall[i][j].s and rng:NextNumber() < spec.wall.open then
					wall[i][j].s = false
				end
			end
		end
		-- 3. pillar room: no walls inside it
		local pr = spec.pillarRoom
		for i = pr.from[1], pr.to[1] do
			for j = pr.from[2], pr.to[2] do
				if i < pr.to[1] then
					wall[i][j].e = false
				end
				if j < pr.to[2] then
					wall[i][j].s = false
				end
			end
		end
		-- 4. the too-long hallway: walled both sides, open along its length, entered only from its west end
		local h = spec.hallway
		for i = h.from, h.to do
			if i < h.to then
				wall[i][h.row].e = false
			end
			if h.row > 0 then
				wall[i][h.row - 1].s = true
			end
			if h.row < N - 1 then
				wall[i][h.row].s = true
			end
		end
		if h.from > 0 then
			wall[h.from - 1][h.row].e = false
		end
		if h.to < N - 1 then
			wall[h.to][h.row].e = true
		end
		-- 5. connectivity repair: open a wall from reachable to unreachable until every cell is reached
		local function reach()
			local r, q = { ["0:" .. (N - 1)] = true }, { { 0, N - 1 } }
			while #q > 0 do
				local c = table.remove(q)
				for _, d in DIRS do
					local ni, nj = c[1] + d[1], c[2] + d[2]
					if inside(ni, nj) and not r[ni .. ":" .. nj] and isOpen(c[1], c[2], d[1], d[2]) then
						r[ni .. ":" .. nj] = true
						table.insert(q, { ni, nj })
					end
				end
			end
			return r
		end
		for _ = 1, N * N do
			local r = reach()
			local fixed = false
			for i = 0, N - 1 do
				for j = 0, N - 1 do
					if r[i .. ":" .. j] and not fixed then
						for _, d in DIRS do
							local ni, nj = i + d[1], j + d[2]
							if inside(ni, nj) and not r[ni .. ":" .. nj] and not (inHall(i, j) or inHall(ni, nj)) then
								open(i, j, d[1], d[2])
								fixed = true
								break
							end
						end
					end
				end
			end
			if not fixed then
				break
			end
		end
		-- 6. doorless gaps in the walls that remain (never in the hallway's sides)
		local gaps = {}
		for i = 0, N - 1 do
			for j = 0, N - 1 do
				for _, side in { "e", "s" } do
					if wall[i][j][side] and rng:NextNumber() < spec.wall.gap then
						local hallSide = side == "s" and (inHall(i, j) or inHall(i, j + 1))
						if not hallSide then
							gaps[i .. ":" .. j .. side] = rng:NextNumber(spec.wall.gapWidth[1], spec.wall.gapWidth[2])
						end
					end
				end
			end
		end
		return wall, gaps
	end

	function phases.materials()
		local m = spec.materials
		return "installed " .. table.concat(Materials.install({ m.wall, m.floor, m.ceiling }), ", ")
	end

	function phases.shell()
		local shell = Root.clear(id, "Structures")
		Root.removeTemplate()
		local W = N * C
		local items = {}
		local floor = Geo.slab(CFrame.new(0, 0, 0), W, W, 2)
		Materials.apply(floor, spec.materials.floor, spec.colors.floor)
		table.insert(items, floor)
		local ceiling = Geo.slab(CFrame.new(0, H + 1, 0), W, W, 1)
		Materials.apply(ceiling, spec.materials.ceiling, spec.colors.ceiling)
		table.insert(items, ceiling)
		for _, w in {
			{ Vector3.new(ox, 0, oz), Vector3.new(ox + W, 0, oz) },
			{ Vector3.new(ox + W, 0, oz), Vector3.new(ox + W, 0, oz + W) },
			{ Vector3.new(ox + W, 0, oz + W), Vector3.new(ox, 0, oz + W) },
			{ Vector3.new(ox, 0, oz + W), Vector3.new(ox, 0, oz) },
		} do
			local m = Geo.wall(w[1], w[2], H, spec.wall.thickness, nil, nil)
			for _, p in m:GetChildren() do
				Materials.apply(p, spec.materials.wall, spec.colors.wall)
			end
			table.insert(items, m)
		end
		local sp = Instance.new("SpawnLocation")
		sp.Name = "Spawn"
		sp.Anchored = true
		sp.Size = Vector3.new(6, 1, 6)
		sp.CFrame = CFrame.new(spec.spawn[1], -0.4, spec.spawn[3])
		sp.Transparency = 1
		sp.CanCollide = false
		sp.Duration = 0
		sp.Neutral = true
		table.insert(items, sp)
		Build.flush(items, shell)
		return "floor, ceiling, outer walls, spawn"
	end

	function phases.walls()
		local layer = Root.clear(id, "Ground")
		local wall, gaps = layout()
		local t = spec.wall.thickness
		local items = {}
		local base = hex(spec.colors.baseboard)
		local function run(a, b, gapW)
			local len = (b - a).Magnitude
			local openings = gapW and { { at = len / 2, width = gapW, bottom = 0, top = H } } or nil
			local m = Geo.wall(a, b, H, t, openings, nil)
			for _, p in m:GetChildren() do
				Materials.apply(p, spec.materials.wall, spec.colors.wall)
				-- baseboard on both faces of every full-height wall piece
				if p.Size.Y >= H - 0.01 then
					for _, side in { -1, 1 } do
						Build.decor(Build.part({ Size = Vector3.new(p.Size.X, 0.5, 0.12), CFrame = p.CFrame * CFrame.new(0, -H / 2 + 0.25, side * (t / 2 + 0.06)), Color = base, Parent = m }))
					end
				end
			end
			table.insert(items, m)
		end
		for i = 0, N - 1 do
			for j = 0, N - 1 do
				local x0, z0 = ox + i * C, oz + j * C
				if wall[i][j].e then
					run(Vector3.new(x0 + C, 0, z0 - t / 2), Vector3.new(x0 + C, 0, z0 + C + t / 2), gaps[i .. ":" .. j .. "e"])
				end
				if wall[i][j].s then
					run(Vector3.new(x0 - t / 2, 0, z0 + C), Vector3.new(x0 + C + t / 2, 0, z0 + C), gaps[i .. ":" .. j .. "s"])
				end
			end
			task.wait()
		end
		-- pillars at the interior corners of the pillar room
		local pr = spec.pillarRoom
		for i = pr.from[1] + 1, pr.to[1] do
			for j = pr.from[2] + 1, pr.to[2] do
				local p = Geo.box(CFrame.new(ox + i * C, H / 2, oz + j * C), Vector3.new(2.4, H, 2.4))
				Materials.apply(p, spec.materials.wall, spec.colors.wall)
				table.insert(items, p)
			end
		end
		Build.flush(items, layer)
		return ("%d wall runs + pillars"):format(#items)
	end

	function phases.lights()
		local layer = Root.clear(id, "Lights")
		local L = spec.lights
		local items = {}
		local flicker = {}
		for _, c in spec.flicker do
			flicker[c[1] .. ":" .. c[2]] = true
		end
		for i = 0, N - 1 do
			for j = 0, N - 1 do
				local cx, cz = centre(i, j)
				local dead = inRect(i, j, spec.darkWing)
				for k, dz in { -4, 4 } do
					local panel = Build.part({
						Name = "Troffer", Size = Vector3.new(2.2, 0.15, 4.4), CFrame = CFrame.new(cx, H - 0.08, cz + dz),
						Color = hex(dead and spec.colors.panelDead or spec.colors.panel),
						Material = dead and Enum.Material.SmoothPlastic or Enum.Material.Neon,
					})
					Build.decor(panel)
					if not dead and k == 1 then
						local light = Instance.new("SurfaceLight")
						light.Face = Enum.NormalId.Bottom
						light.Range = L.range
						light.Brightness = L.brightness
						light.Color = Color3.fromRGB(L.color[1], L.color[2], L.color[3])
						light.Shadows = false
						light.Angle = L.angle
						light.Parent = panel
					end
					if flicker[i .. ":" .. j] then
						panel:SetAttribute("Flicker", true)
					end
					table.insert(items, panel)
				end
			end
			task.wait()
		end
		-- a server script that makes the tagged troffers flicker now and then
		local s = Instance.new("Script")
		s.Name = "Flicker"
		s.Source = [[
-- Flickering troffers (Backrooms Level 0, MapKit by fwjelaa).
local panels = {}
for _, p in script.Parent:GetChildren() do
	if p:GetAttribute("Flicker") then table.insert(panels, p) end
end
while true do
	task.wait(math.random(20, 60) / 10)
	local p = panels[math.random(1, #panels)]
	if p then
		for _ = 1, math.random(2, 5) do
			p.Material = Enum.Material.SmoothPlastic
			local l = p:FindFirstChildOfClass("SurfaceLight") if l then l.Enabled = false end
			task.wait(math.random(3, 12) / 100)
			p.Material = Enum.Material.Neon
			if l then l.Enabled = true end
			task.wait(math.random(3, 20) / 100)
		end
	end
end
]]
		table.insert(items, s)
		Build.flush(items, layer)
		return ("%d troffers"):format(#items - 1)
	end

	function phases.details()
		local layer = Root.clear(id, "Props")
		local rng = Random.new(spec.seed + 7)
		local items = {}
		local outlet = hex(spec.colors.outlet)
		-- outlets on random wall faces at 1 stud, and one at head height (the anomaly)
		local walls = Root.layer(id, "Ground")
		local faces = {}
		for _, m in walls:GetChildren() do
			if m:IsA("Model") then
				for _, p in m:GetChildren() do
					if p.Size.Y >= H - 0.01 and p.Size.X > 3 then
						table.insert(faces, p)
					end
				end
			end
		end
		for _ = 1, math.min(40, #faces) do
			local p = faces[rng:NextInteger(1, #faces)]
			local side = rng:NextNumber() < 0.5 and -1 or 1
			local x = rng:NextNumber(-p.Size.X / 2 + 1, p.Size.X / 2 - 1)
			table.insert(items, Build.decor(Build.part({ Name = "Outlet", Size = Vector3.new(0.5, 0.8, 0.08), CFrame = p.CFrame * CFrame.new(x, -H / 2 + 1, side * (p.Size.Z / 2 + 0.04)), Color = outlet })))
		end
		local ax, az = centre(spec.anomaly[1], spec.anomaly[2])
		local best, bestD
		for _, p in faces do
			local d = (Vector2.new(p.Position.X, p.Position.Z) - Vector2.new(ax, az)).Magnitude
			if not bestD or d < bestD then
				best, bestD = p, d
			end
		end
		if best then
			table.insert(items, Build.decor(Build.part({ Name = "WrongOutlet", Size = Vector3.new(0.5, 0.8, 0.08), CFrame = best.CFrame * CFrame.new(0, 2, best.Size.Z / 2 + 0.04), Color = outlet })))
		end
		Build.flush(items, layer)
		return ("%d outlets"):format(#items)
	end

	function phases.ambience()
		local failures = K.Lighting.preset(spec.lighting)
		local manifest = K.Http.json("assets.json")
		local hum = manifest.sounds and manifest.sounds[spec.sound.hum]
		if hum and hum.id then -- a fresh pack ships the recipe without the upload id
			K.Sound.ambience(id, "Hum", hum.id, { volume = spec.sound.volume })
		end
		K.Sound.reverb(spec.sound.reverb)
		return ("lighting %s, hum %s"):format(#failures == 0 and "ok" or table.concat(failures, "; "), hum and hum.id and "on" or ("missing: run `python kit/tools/run.py hum %s`, then this phase again"):format(spec.sound.hum))
	end

	function phases.all()
		local out = {}
		for _, name in { "materials", "shell", "walls", "lights", "details", "ambience" } do
			table.insert(out, name .. ": " .. tostring(phases[name]()))
			task.wait()
		end
		return table.concat(out, "\n")
	end

	return phases
end
