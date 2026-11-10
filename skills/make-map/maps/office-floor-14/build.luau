-- Office Floor 14 (MapKit by fwjelaa, FWJ STUDIOS). Data: map.json. Style: style.md (nearest family horror-house).
-- 1 stud = 0.28 m. Floor top y = 0, drop ceiling at y = 10, slab above at 13. North = -Z, spawn in the lobby (south).
-- Props from Blender (office_props.py) have parts named `<part>.<mat>`; `dress` gives each mat key its look.
return function(K, spec)
	local id = spec.id
	local Root, Build, Geo, Materials, Models = K.Root, K.Build, K.Geo, K.Materials, K.Models
	local M, T, PL = spec.materials, spec.tints, spec.plate
	local CEIL = PL.ceil
	local CollectionService = game:GetService("CollectionService")
	local phases = {}

	local function v3(t)
		return Vector3.new(t[1], t[2], t[3])
	end
	local function hex(s)
		return typeof(s) == "string" and Color3.fromHex(s) or s
	end
	local function yaw(deg)
		return CFrame.Angles(0, math.rad(deg or 0), 0)
	end
	local count = 0
	local function breathe()
		count += 1
		if count % 150 == 0 then
			task.wait()
		end
	end

	-- a part in one of the map's MaterialVariants (tint from spec.tints unless given)
	local function box(cf, size, key, parent, tint, extra)
		local props = { CFrame = cf, Size = size, Parent = parent }
		for k, v in extra or {} do
			props[k] = v
		end
		breathe()
		return Materials.apply(Build.part(props), M[key], hex(tint) or (T[key] and hex(T[key])))
	end
	-- a part in a plain Roblox material
	local function plain(cf, size, color, material, parent, extra)
		local props = { CFrame = cf, Size = size, Color = hex(color), Material = material or Enum.Material.SmoothPlastic, Parent = parent }
		for k, v in extra or {} do
			props[k] = v
		end
		breathe()
		return Build.part(props)
	end
	local function decor(p, shadow)
		Build.decor(p)
		if shadow ~= nil then
			p.CastShadow = shadow
		end
		return p
	end
	-- a cylinder rod from a to b
	local function rod(a, b, r, color, material, parent, extra)
		local d = b - a
		local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
		local e = { Shape = Enum.PartType.Cylinder }
		for k, v in extra or {} do
			e[k] = v
		end
		return plain(cf, Vector3.new(d.Magnitude, r * 2, r * 2), color, material, parent, e)
	end
	-- a flat disc facing `dir` (cylinders run along local X)
	local function disc(pos, dir, r, thick, color, material, parent, extra)
		local cf = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, math.rad(90), 0)
		local e = { Shape = Enum.PartType.Cylinder }
		for k, v in extra or {} do
			e[k] = v
		end
		return plain(cf, Vector3.new(thick, r * 2, r * 2), color, material, parent, e)
	end

	-- rect = {x0, z0, x1, z1} minus axis-aligned holes (as in the farmhouse)
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
					if h[1] <= a + 1e-3 and h[3] >= b - 1e-3 and h[4] > rect[2] and h[2] < rect[4] then
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

	local function slab(rect, top, thick, key, parent, holes, tint)
		for _, r in minus(rect, holes or {}) do
			box(CFrame.new((r[1] + r[3]) / 2, top - thick / 2, (r[2] + r[4]) / 2), Vector3.new(r[3] - r[1], thick, r[4] - r[2]), key, parent, tint)
		end
	end

	-- text on a thin plate; cf's LookVector is the side the text faces
	local function sign(cf, size, lines, opts, parent)
		opts = opts or {}
		local p = plain(cf, size, opts.bg or "#111111", opts.material or Enum.Material.SmoothPlastic, parent,
			{ Transparency = opts.hidden and 1 or 0, Name = opts.name or "Sign" })
		decor(p, false)
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Front
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = opts.ppu or 80
		g.LightInfluence = opts.light or 1
		g.Brightness = opts.brightness or 1
		g.ClipsDescendants = true
		g.Parent = p
		local y = opts.pad or 0.05
		for _, l in lines do
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.fromScale(1 - 2 * (opts.padX or 0.04), l.h or 0.3)
			t.Position = UDim2.fromScale(opts.padX or 0.04, l.y or y)
			t.Text = l.text
			t.TextScaled = true
			t.TextWrapped = true
			t.TextColor3 = hex(l.color or opts.color or "#FFFFFF")
			t.TextTransparency = l.transparency or 0
			t.Font = l.font or opts.font or Enum.Font.GothamMedium
			t.TextXAlignment = l.align or opts.align or Enum.TextXAlignment.Center
			t.TextYAlignment = Enum.TextYAlignment.Center
			t.Parent = g
			y += (l.h or 0.3) + (l.gap or 0.02)
		end
		return p, g
	end

	------------------------------------------------------------------ prop looks
	local Mat = Enum.Material
	local MUG_COLORS = { "#E9E6DC", "#2C3E57", "#8E2A23", "#3F5B3A", "#D9B23C", "#202124" }
	local LOOK = {
		upholstery = { v = "upholstery", tint = "#4C5058" },
		plastic_black = { v = "plastic_black", tint = "#D0D0D0" },
		plastic_dark = { m = Mat.Plastic, c = "#2A2B2F" },
		plastic_grey = { m = Mat.Plastic, c = "#5F6165" },
		plastic_white = { v = "plastic_white", tint = "#E0DCD2" },
		chrome = { v = "steel", tint = "#F0F0F0" },
		alu = { v = "alu" },
		paint_metal = { v = "paint_metal", tint = "#5A5E64" },
		paint_black = { v = "paint_metal", tint = "#2A2C31" },
		cabinet_grey = { v = "paint_metal", tint = "#D3CEC3" },
		oak = { v = "oak" },
		walnut = { v = "walnut" },
		screen = { m = Mat.SmoothPlastic, c = "#08090B", refl = 0.08 },
		screen_lcd = { m = Mat.SmoothPlastic, c = "#1B2219" },
		led_green = { m = Mat.Neon, c = "#3CFF73" },
		led_amber = { m = Mat.Neon, c = "#FFA62B" },
		led_blue = { m = Mat.Neon, c = "#3D8BFF" },
		led_white = { m = Mat.Neon, c = "#DCE8FF" },
		neon_white = { m = Mat.Neon, c = "#F2EEE2" },
		tube = { m = Mat.SmoothPlastic, c = "#C9C9C2" },
		glass = { m = Mat.Glass, c = "#A8BAC2", tr = 0.7 },
		glass_dark = { m = Mat.Glass, c = "#121417", tr = 0.15 },
		water = { m = Mat.Glass, c = "#8BBDE8", tr = 0.6 },
		paint_red = { m = Mat.SmoothPlastic, c = "#8A1611" },
		rubber = { m = Mat.Rubber, c = "#19191B" },
		paper = { m = Mat.SmoothPlastic, c = "#E4E1D8" },
		ceramic = { m = Mat.SmoothPlastic, c = "#E9E6DC" },
		plastic_red = { m = Mat.Plastic, c = "#A3241D" },
		plastic_blue = { m = Mat.Plastic, c = "#1F4E9C" },
		plastic_yellow = { m = Mat.Plastic, c = "#D7A21F" },
		plastic_green = { m = Mat.Plastic, c = "#2E7D46" },
		plastic_orange = { m = Mat.Plastic, c = "#D2601A" },
		cable = { m = Mat.Plastic, c = "#111113" },
	}
	local function look(part, key)
		local l = LOOK[key]
		if not l then
			return
		end
		local sa = part:FindFirstChildOfClass("SurfaceAppearance")
		if sa then
			sa:Destroy()
		end
		if l.v then
			Materials.apply(part, M[l.v], l.tint and hex(l.tint) or (T[l.v] and hex(T[l.v])))
		else
			part.MaterialVariant = ""
			part.Material = l.m
			part.Color = hex(l.c)
		end
		part.Transparency = l.tr or 0
		part.Reflectance = l.refl or 0
		if l.m == Mat.Neon or l.tr then
			part.CastShadow = false
		end
		if part.Name:sub(1, 10) == "fill.water" then
			part.Color = hex("#4F8FCB")
			part.Transparency = 0.35
		end
	end
	-- give every `<part>.<mat>` mesh of a Blender-made template its material (templates are cached, clones inherit)
	local function dress(model)
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				-- Blender suffixes repeated names (`base.plastic_black.001`): the mat key is the last word before that
				local key = d.Name:gsub("%.%d+$", ""):match("%.([%w_]+)$")
				if key then
					look(d, key)
				end
			end
		end
	end

	local function place(name, cf, opts)
		opts = opts or {}
		breathe()
		local m = Models.place(name, cf, opts)
		if opts.collision == "none" then
			-- desk clutter: tiny shadow casters cost more than they add
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") and math.max(d.Size.X, d.Size.Y, d.Size.Z) < 1 then
					d.CastShadow = false
				end
			end
		end
		return m
	end
	local function part(model, name)
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Name:sub(1, #name) == name then
				return d
			end
		end
	end

	------------------------------------------------------------------ shared layout
	local DOOR_W, DOOR_H = spec.door.width, spec.door.height

	-- every ceiling fitting: troffers (2x4, long side along z), diffusers, and the two missing tiles
	local function fittings()
		local list = {}
		local function add(kind, x, z)
			table.insert(list, { kind = kind, x = x, z = z })
		end
		for x = -52, 52, 8 do
			for _, z in { -22, -14, -6, 2, 10 } do
				local blocked = (z == 2 and x > -9 and x < 9) or (z == 10 and x == 12)
				if not blocked then
					add("troffer", x, z)
				end
			end
			if x >= -10 then
				add("troffer", x, -40)
				add("troffer", x, -32)
			end
		end
		for _, p in { { -50, -36 }, { -42, -36 }, { -29, -36 }, { -21, -36 }, { -36, 22.5 }, { -36, 31 }, { -18, 27 },
			{ 18, 23 }, { 30, 23 }, { 18, 31 }, { 30, 31 } } do
			add("troffer", p[1], p[2])
		end
		for _, x in { -48, -32, -16, 0, 16, 32, 48 } do
			add("diffuser", x, -18)
			add("diffuser", x, 6)
		end
		for _, x in { 0, 16, 32, 48 } do
			add("diffuser", x, -36)
		end
		for _, p in { { -46, -40 }, { -25, -41 }, { 24, 27 }, { -18, 32 }, { -30, 27 } } do
			add("diffuser", p[1], p[2])
		end
		-- the state of each troffer comes from the light pools (everything else is dead)
		for _, f in list do
			f.state = "dead"
			if f.kind == "troffer" then
				for _, pool in spec.lightPools do
					local dx, dz = f.x - pool.at[1], f.z - pool.at[2]
					if dx * dx + dz * dz <= pool.r * pool.r then
						f.state = pool.state
					end
				end
			end
		end
		return list
	end
	local MISSING_TILES = { { 31.6, -10 }, { -40, -18 } }

	------------------------------------------------------------------ phases
	function phases.materials()
		local names = {}
		for _, v in M do
			table.insert(names, v)
		end
		table.sort(names)
		Materials.install(names)
		return "installed " .. #names .. " materials"
	end

	local PROC_MODELS = {
		"ofc_task_chair", "ofc_monitor", "ofc_keyboard", "ofc_mouse", "ofc_pc", "ofc_desk_phone", "ofc_desk", "ofc_pedestal",
		"ofc_troffer", "ofc_diffuser", "ofc_emergency", "ofc_rack_a", "ofc_rack_b", "ofc_meeting_chair", "ofc_photo", "ofc_mug",
		"ofc_cactus", "ofc_notepads", "ofc_binder", "ofc_stapler", "ofc_clipboard", "ofc_box", "ofc_laptop", "ofc_books_b",
		"ofc_bin", "ofc_plant_b", "ofc_stack_chair", "ofc_extinguisher", "ofc_stationery",
	}
	local function modelNames()
		local set, names = {}, {}
		for _, p in spec.props do
			set[p.m] = true
		end
		for _, n in PROC_MODELS do
			set[n] = true
		end
		for n in set do
			table.insert(names, n)
		end
		table.sort(names)
		return names
	end

	-- loads the models a batch at a time (each load and collision rebuild takes a while); run until "0 left"
	function phases.models()
		local cache = game:GetService("ServerStorage"):FindFirstChild("MapKit_Assets")
		local todo = {}
		for _, n in modelNames() do
			if not (cache and cache:FindFirstChild(n)) then
				table.insert(todo, n)
			end
		end
		local batch = {}
		for i = 1, math.min(10, #todo) do
			table.insert(batch, todo[i])
		end
		local note = "ok"
		if #batch > 0 then
			local _, n2 = Models.install(batch)
			note = n2
		end
		cache = game:GetService("ServerStorage"):FindFirstChild("MapKit_Assets")
		for _, n in modelNames() do
			local tpl = cache and cache:FindFirstChild(n)
			if tpl then
				dress(tpl) -- cheap and idempotent: re-dressing picks up any change to LOOK
				tpl:SetAttribute("Dressed", true)
			end
		end
		return ("installed %d (%s); %d left"):format(#batch, note, #todo - #batch)
	end

	function phases.shell()
		local s = Root.clear(id, "Structures")
		Root.removeTemplate()
		local zones = {}
		for _, z in spec.zones do
			zones[z.name] = z
		end
		-- floors: the open office is the plate (south to the core) minus the rooms that have their own floor
		local holes = {}
		for _, z in spec.zones do
			if z.rect[4] <= 18 then
				table.insert(holes, z.rect)
			end
		end
		slab({ PL.x0, PL.z0, PL.x1, 18 }, 0, PL.slab, "carpet", s, holes)
		for _, z in spec.zones do
			if z.floor ~= "none" then
				slab(z.rect, 0, PL.slab, z.floor, s, nil, z.tint and T[z.tint])
			end
		end
		task.wait()
		-- drop ceiling with openings for every recessed fitting and the missing tiles
		local cut = {}
		for _, f in fittings() do
			local hx, hz = f.kind == "troffer" and 1.09 or 1.08, f.kind == "troffer" and 2.18 or 1.08
			table.insert(cut, { f.x - hx, f.z - hz, f.x + hx, f.z + hz })
		end
		for _, t in MISSING_TILES do
			table.insert(cut, { t[1] - 1.15, t[2] - 1.15, t[1] + 1.15, t[2] + 1.15 })
		end
		slab({ PL.x0, PL.z0, PL.x1, 18 }, CEIL + 0.3, 0.3, "ceiling", s, cut)
		local core = {}
		for _, n in { "server", "copy", "break", "storage" } do
			table.insert(core, zones[n].rect)
		end
		for _, r in core do
			slab(r, CEIL + 0.3, 0.3, "ceiling", s, cut)
		end
		slab(zones.lobby.rect, CEIL + 0.3, 0.3, "wall", s, nil, "#D9D5CC") -- plaster ceiling
		-- the floor above: closes the plenum (seen through the missing tiles) and keeps the sky out
		-- (both slabs leave the stair shaft open: it runs from 13 up to 15 through them)
		local shaft = { zones.stair.rect }
		slab({ PL.x0 - 1, PL.z0 - 1, PL.x1 + 1, PL.z1 + 1 }, 14, 1, "concrete", s, shaft, "#55565A")
		slab({ PL.x0 - 1, PL.z0 - 1, PL.x1 + 1, PL.z1 + 1 }, -1, 1, "concrete", s, shaft, "#55565A")
		task.wait()
		-- walls
		for wi, w in spec.walls do
			local a, b = Vector3.new(w.a[1], 0, w.a[2]), Vector3.new(w.b[1], 0, w.b[2])
			local openings = {}
			for _, o in w.open or {} do
				if o[1] == "d" then
					table.insert(openings, { at = o[2], width = DOOR_W, bottom = 0, top = DOOR_H })
				else
					table.insert(openings, { at = o[2], width = o[3], bottom = 0, top = o[4] })
				end
			end
			if w.glass then
				local m = Geo.wall(a, b, CEIL, 0.15, openings, { Material = Mat.SmoothPlastic, Color = hex("#A9BCC3"), Transparency = 0.9, Reflectance = 0.05, CastShadow = false }, s)
				m.Name = "GlassWall" .. wi
				for _, p in m:GetChildren() do
					local cf, sz = p.CFrame, p.Size
					-- steel head and sill channels, and a frosted manifestation band at eye height
					local bottom = cf * CFrame.new(0, -sz.Y / 2, 0)
					if bottom.Position.Y < 0.1 then
						box(bottom * CFrame.new(0, 0.12, 0), Vector3.new(sz.X, 0.24, 0.3), "steel", m)
						if sz.Y > 6 then
							for _, side in { -1, 1 } do
								plain(cf * CFrame.new(0, 4 - cf.Position.Y, side * 0.085), Vector3.new(sz.X, 1.0, 0.02), "#F2F2EE", Mat.SmoothPlastic, m,
									{ Transparency = 0.82, CastShadow = false, Name = "Frost" })
							end
						end
					end
					box(cf * CFrame.new(0, sz.Y / 2 - 0.12, 0), Vector3.new(sz.X, 0.24, 0.3), "steel", m)
				end
				-- vertical joints every 4 studs
				local len = (b - a).Magnitude
				local dir = (b - a).Unit
				for t = 4, len - 2, 4 do
					local inOpening = false
					for _, o in openings do
						if math.abs(t - o.at) < o.width / 2 + 0.3 then
							inOpening = true
						end
					end
					if not inOpening then
						local p0 = a + dir * t
						box(CFrame.fromMatrix(p0 + Vector3.new(0, CEIL / 2, 0), dir, Vector3.yAxis), Vector3.new(0.12, CEIL, 0.22), "steel", m)
					end
				end
			else
				local t = w.t or 0.5
				local key = w.mat or "wall"
				local m = Geo.wall(a, b, CEIL, t, openings, nil, s)
				m.Name = "Wall" .. wi
				for _, p in m:GetChildren() do
					Materials.apply(p, M[key], T[key] and hex(T[key]))
					-- dark rubber cove base on both faces of every piece that reaches the floor
					local bottom = p.CFrame * CFrame.new(0, -p.Size.Y / 2, 0)
					if bottom.Position.Y < 0.05 and key ~= "walnut" then
						for _, side in { -1, 1 } do
							decor(plain(bottom * CFrame.new(0, 0.2, side * (p.Size.Z / 2 + 0.03)), Vector3.new(p.Size.X, 0.4, 0.06), "#2B2B2E", Mat.Rubber, m), false)
						end
					end
				end
				if w.mat2 then
					-- the other face in another material: a skin on the + side
					local dir = (b - a).Unit
					local n = dir:Cross(Vector3.yAxis)
					local skin = Geo.wall(a + n * (t / 2 + 0.03), b + n * (t / 2 + 0.03), CEIL, 0.06, openings, nil, m)
					for _, p in skin:GetChildren() do
						Materials.apply(p, M[w.mat2], T[w.mat2] and hex(T[w.mat2]))
					end
				end
			end
			if wi % 3 == 0 then
				task.wait()
			end
		end
		-- door frames (casings) on both faces of every door opening in solid walls
		for _, w in spec.walls do
			if not w.glass then
				local a, b = Vector3.new(w.a[1], 0, w.a[2]), Vector3.new(w.b[1], 0, w.b[2])
				local dir = (b - a).Unit
				local t = w.t or 0.5
				for _, o in w.open or {} do
					if o[1] == "d" then
						local c = a + dir * o[2]
						local frame = CFrame.fromMatrix(c, dir, Vector3.yAxis)
						local fm = Instance.new("Model")
						fm.Name = "DoorFrame"
						for _, sx in { -1, 1 } do
							box(frame * CFrame.new(sx * (DOOR_W / 2 + 0.12), DOOR_H / 2, 0), Vector3.new(0.24, DOOR_H, t + 0.16), "paint_metal", fm, "#8B8E92")
						end
						box(frame * CFrame.new(0, DOOR_H + 0.12, 0), Vector3.new(DOOR_W + 0.48, 0.24, t + 0.16), "paint_metal", fm, "#8B8E92")
						fm.Parent = s
					end
				end
			end
		end
		-- structural columns, cased in plaster with steel corner guards
		for _, c in spec.columns do
			local col = Instance.new("Model")
			col.Name = "Column"
			box(CFrame.new(c[1], CEIL / 2, c[2]), Vector3.new(2, CEIL, 2), "wall", col)
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					box(CFrame.new(c[1] + sx * 0.98, 2, c[2] + sz * 0.98), Vector3.new(0.1, 4, 0.1), "steel", col)
				end
				decor(plain(CFrame.new(c[1] + sx * 1.03, 0.2, c[2]), Vector3.new(0.06, 0.4, 2.1), "#2B2B2E", Mat.Rubber, col), false)
				decor(plain(CFrame.new(c[1], 0.2, c[2] + sx * 1.03), Vector3.new(2.1, 0.4, 0.06), "#2B2B2E", Mat.Rubber, col), false)
			end
			col.Parent = s
		end
		-- spawn: in the elevator lobby, looking north through the glass doors
		local sp = Instance.new("SpawnLocation")
		sp.Name = "Spawn"
		sp.Anchored = true
		sp.Size = Vector3.new(4, 0.2, 4)
		sp.CFrame = CFrame.new(spec.spawn[1], 0.1, spec.spawn[3])
		sp.Transparency = 1
		sp.CanCollide = false
		sp.Duration = 0
		sp.Neutral = true
		sp.Parent = Root.clear(id, "Spawns")
		return "floors, ceilings, walls, frames, columns, spawn"
	end

	function phases.facade()
		local f = Root.clear(id, "Route")
		local F = spec.facade
		local rng = Random.new(spec.seed + 5)
		local manifest = K.Http.json("assets.json")
		local rainImg = manifest.images and manifest.images.ofc_rain_glass and manifest.images.ofc_rain_glass.id
		for _, side in F.sides do
			local a, b = Vector3.new(side.a[1], 0, side.a[2]), Vector3.new(side.b[1], 0, side.b[2])
			local len = (b - a).Magnitude
			local dir = (b - a).Unit
			local out = Vector3.new(side.out[1], 0, side.out[2])
			local inward = -out
			local function at(t, y, off)
				return CFrame.fromMatrix(a + dir * t + Vector3.new(0, y, 0) + inward * off, dir, Vector3.yAxis)
			end
			local n = math.max(1, math.floor(len / F.bay + 0.5))
			local w = len / n
			local model = Instance.new("Model")
			model.Name = "Facade_" .. side.name
			-- one glass sheet per side (fewer draw calls), rain sliding on its outer face
			local glass = plain(at(len / 2, (F.sill + F.head) / 2, -0.05), Vector3.new(len, F.head - F.sill, 0.12), "#9DB0B8", Mat.SmoothPlastic, model,
				{ Transparency = 0.9, Reflectance = 0.04, CastShadow = false, Name = "Glass" })
			if rainImg then
				local tex = Instance.new("Texture")
				tex.Texture = rainImg
				-- the sheet's -Z is its back... the outward face is the one whose normal is `out`
				local cf = glass.CFrame
				tex.Face = (cf.LookVector:Dot(out) > 0.5) and Enum.NormalId.Front or Enum.NormalId.Back
				tex.StudsPerTileU = 7
				tex.StudsPerTileV = 7
				tex.Transparency = 0.15
				tex.Color3 = Color3.fromRGB(205, 215, 225)
				tex.Name = "Rain"
				tex.Parent = glass
				CollectionService:AddTag(tex, "OfcRainGlass")
			end
			-- spandrels outside: below the sill and above the head (the floors below and above)
			box(at(len / 2, (F.sill - 3) / 2 - 0.0, -0.35), Vector3.new(len + 1, F.sill + 3, 0.3), "paint_metal", model, "#2E3135")
			box(at(len / 2, F.head + 2, -0.35), Vector3.new(len + 1, 4, 0.3), "paint_metal", model, "#2E3135")
			-- mullions and the transom at the sill
			for i = 0, n do
				local t = i * w
				box(at(t, F.head / 2, 0), Vector3.new(0.28, F.head, 0.55), "paint_metal", model, "#3B3E43")
				box(at(t, F.head / 2, -0.5), Vector3.new(0.18, F.head + 0.4, 0.45), "paint_metal", model, "#2C2F33") -- outside fin
			end
			box(at(len / 2, F.sill + 0.12, 0), Vector3.new(len, 0.24, 0.5), "paint_metal", model, "#3B3E43")
			box(at(len / 2, F.head - 0.12, 0), Vector3.new(len, 0.24, 0.5), "paint_metal", model, "#3B3E43")
			-- perimeter convector cabinet along the glass (inset at corners so the sides don't overlap)
			local inset0 = side.name == "north" and 0.3 or 1.6
			local inset1 = side.name == "west" and 1.6 or (side.name == "east" and 0.3 or 0.3)
			if side.name == "west" or side.name == "east" then
				-- the core (stair / storage) has no windows: stop the west and east runs at the core wall
				inset0 = side.name == "west" and 0.3 or 1.6
				inset1 = side.name == "west" and 1.6 or 0.3
			end
			local cl = len - inset0 - inset1
			local cmid = inset0 + cl / 2
			box(at(cmid, F.sill / 2, 0.85), Vector3.new(cl, F.sill - 0.05, 1.1), "paint_metal", model, "#C9C7C0")
			box(at(cmid, F.sill - 0.02, 0.85), Vector3.new(cl + 0.05, 0.08, 1.2), "paint_metal", model, "#D8D6CF")
			decor(plain(at(cmid, F.sill + 0.03, 0.55), Vector3.new(cl - 0.4, 0.02, 0.3), "#1C1D20", Mat.Metal, model), false) -- grille slot
			decor(plain(at(cmid, 0.2, 1.42), Vector3.new(cl, 0.4, 0.06), "#2B2B2E", Mat.Rubber, model), false)
			-- venetian blinds: up, half or down, a few hanging crooked
			for i = 0, n - 1 do
				local t0 = i * w + 0.25
				local bw = w - 0.5
				local tc = t0 + bw / 2
				local blind = Instance.new("Model")
				blind.Name = "Blind"
				local r = rng:NextNumber()
				local drop = r < 0.3 and 0.5 or (r < 0.7 and rng:NextNumber(3, 6.5) or (F.head - F.sill - 0.4))
				local skew = rng:NextNumber() < 0.15 and math.rad(rng:NextNumber(3, 7)) * (rng:NextNumber() < 0.5 and -1 or 1) or 0
				local tilt = math.rad(rng:NextNumber() < 0.7 and rng:NextNumber(35, 60) or rng:NextNumber(0, 10))
				box(at(tc, F.head - 0.3, 0.45), Vector3.new(bw, 0.22, 0.28), "alu", blind)
				local top = F.head - 0.45
				local count2 = math.floor(drop / 0.24)
				for k = 1, count2 do
					local y = top - k * 0.24
					local sk = CFrame.Angles(0, 0, skew * (k / math.max(1, count2)))
					local cf = at(tc, y, 0.45) * sk * CFrame.Angles(tilt, 0, 0)
					decor(box(cf, Vector3.new(bw, 0.02, 0.27), "alu", blind, "#D8D8D2"), true)
				end
				if count2 > 0 then
					local yb = top - count2 * 0.24 - 0.12
					box(at(tc, yb, 0.45) * CFrame.Angles(0, 0, skew), Vector3.new(bw, 0.07, 0.3), "alu", blind)
				else
					-- pulled all the way up: the slats stack under the headrail
					box(at(tc, F.head - 0.62, 0.45), Vector3.new(bw, 0.4, 0.28), "alu", blind, "#D0D0CA")
				end
				decor(plain(at(t0 + 0.3, F.head - 0.45 - drop * 0.6, 0.6), Vector3.new(0.03, drop * 1.2 + 0.4, 0.03), "#D6D3CB", Mat.SmoothPlastic, blind), false) -- cord
				blind.Parent = model
				if i % 4 == 0 then
					task.wait()
				end
			end
			model.Parent = f
		end
		return "curtain walls, convectors, blinds"
	end

	------------------------------------------------------------------ doors
	-- a leaf hinged at one jamb; the server script swings it (attributes say how)
	local function doorLeaf(d, parent)
		local W, H = DOOR_W, DOOR_H
		local axis = d.axis == "x" and Vector3.xAxis or Vector3.zAxis
		local perp = d.axis == "x" and Vector3.zAxis or Vector3.xAxis
		local c = Vector3.new(d.c[1], 0, d.c[2])
		local hinge = c + axis * (d.hinge * W / 2)
		local closed = -axis * d.hinge
		local sgn = closed:Cross(perp).Y
		local m = Instance.new("Model")
		m.Name = d.name
		local frame = CFrame.fromMatrix(hinge + closed * (W / 2) + Vector3.new(0, H / 2, 0), closed, Vector3.yAxis)
		local leaf
		if d.style == "glass" then
			leaf = plain(frame, Vector3.new(W - 0.12, H - 0.08, 0.14), "#A9BCC3", Mat.SmoothPlastic, m, { Transparency = 0.88, Reflectance = 0.05, CastShadow = false, Name = "Leaf" })
			for _, y in { -H / 2 + 0.25, H / 2 - 0.25 } do
				box(frame * CFrame.new(0, y, 0), Vector3.new(W - 0.1, 0.4, 0.2), "steel", m)
			end
			box(frame * CFrame.new(-W / 2 + 0.16, 0, 0), Vector3.new(0.22, H - 0.1, 0.2), "steel", m)
			box(frame * CFrame.new(W / 2 - 0.16, 0, 0), Vector3.new(0.22, H - 0.1, 0.2), "steel", m)
		else
			local key = d.style == "wood" and "walnut" or "paint_metal"
			leaf = box(frame, Vector3.new(W - 0.12, H - 0.08, 0.18), key, m, d.style == "steel" and "#7C8188" or nil, { Name = "Leaf" })
			if d.vision then
				plain(frame * CFrame.new(0.6, 1.3, 0), Vector3.new(0.8, 2.4, 0.2), "#1A1D20", Mat.Glass, m, { Transparency = 0.4 })
			end
			-- kick plate both faces
			for _, side in { -1, 1 } do
				box(frame * CFrame.new(0, -H / 2 + 0.45, side * 0.1), Vector3.new(W - 0.3, 0.8, 0.02), "steel", m)
			end
		end
		-- lever handles on both faces at the latch side, or a push bar on fire doors
		local latch = frame * CFrame.new(W / 2 - 0.5, -H / 2 + 3.4, 0)
		for _, side in { -1, 1 } do
			if d.push and side == 1 then
				box(frame * CFrame.new(0.2, -H / 2 + 3.4, side * 0.22), Vector3.new(W - 1.0, 0.18, 0.18), "steel", m)
			else
				box(latch * CFrame.new(0, 0, side * 0.16), Vector3.new(0.18, 0.5, 0.1), "steel", m)
				box(latch * CFrame.new(-0.28, 0.12, side * 0.25), Vector3.new(0.6, 0.1, 0.1), "steel", m)
			end
		end
		box(frame * CFrame.new(-W / 2 + 0.6, H / 2 - 0.15, 0.25), Vector3.new(1.1, 0.14, 0.2), "steel", m) -- closer arm
		m.PrimaryPart = leaf
		m.WorldPivot = CFrame.new(hinge)
		m:SetAttribute("Sign", sgn)
		m:SetAttribute("OpenAngle", d.open)
		m:SetAttribute("Angle", 0)
		m:SetAttribute("Interactive", d.prompt ~= false)
		CollectionService:AddTag(m, "OfcDoor")
		m:PivotTo(CFrame.new(hinge) * CFrame.Angles(0, math.rad(d.open) * sgn, 0))
		m:SetAttribute("Angle", d.open)
		m.Parent = parent
		return m
	end

	------------------------------------------------------------------ core: lobby, reception, doors
	function phases.core()
		local c = Root.clear(id, "Landmarks")
		local function sub(name)
			local f = Instance.new("Model")
			f.Name = name
			f.Parent = c
			return f
		end
		-- interactive doors
		local doors = sub("Doors")
		for _, d in spec.doors do
			doorLeaf(d, doors)
		end
		task.wait()

		-- elevator wall: marble cladding with steel portals, two cars behind
		local lobby = sub("Lobby")
		local clad = Geo.wall(Vector3.new(-12, 0, 35.45), Vector3.new(12, 0, 35.45), CEIL, 0.1,
			{ { at = 7, width = 4.4, bottom = 0, top = 8 }, { at = 17, width = 4.4, bottom = 0, top = 8 } }, nil, lobby)
		for _, p in clad:GetChildren() do
			Materials.apply(p, M.marble)
		end
		for i, ex in { -5, 5 } do
			local e = sub("Elevator" .. i)
			for _, sx in { -1, 1 } do
				box(CFrame.new(ex + sx * 2.45, 4.25, 35.25), Vector3.new(0.5, 8.5, 0.5), "steel", e)
			end
			box(CFrame.new(ex, 8.25, 35.25), Vector3.new(5.4, 0.5, 0.5), "steel", e)
			box(CFrame.new(ex, 0.03, 35.45), Vector3.new(4.4, 0.06, 0.9), "steel", e) -- sill
			-- doors: car 1 closed; car 2 stuck a hand's width open
			local gap = i == 2 and 0.8 or 0
			for _, sx in { -1, 1 } do
				local leaf = box(CFrame.new(ex + sx * (1.1 + gap), 4, 35.85), Vector3.new(2.2, 8, 0.15), "steel", e)
				leaf.Name = sx < 0 and "LeafL" or "LeafR"
				leaf:SetAttribute("Closed", leaf.CFrame)
			end
			-- nobody walks into the shaft
			plain(CFrame.new(ex, 4, 36.05), Vector3.new(4.4, 8, 0.2), "#000000", Mat.SmoothPlastic, e, { Transparency = 1, Name = "Barrier", CanQuery = false })
			-- the car: steel walls, a stone floor that stopped a little low, a light panel and a handrail
			local car = sub("Car" .. i)
			local floorY = i == 2 and -0.3 or 0
			box(CFrame.new(ex, floorY - 0.25, 39.2), Vector3.new(5.4, 0.5, 5.6), "lobby_floor", car)
			box(CFrame.new(ex, 8.6, 39.2), Vector3.new(5.4, 0.3, 5.6), "steel", car)
			for _, sx in { -1, 1 } do
				box(CFrame.new(ex + sx * 2.65, 4.2, 39.2), Vector3.new(0.2, 8.8, 5.6), "steel", car)
			end
			box(CFrame.new(ex, 4.2, 42.05), Vector3.new(5.4, 8.8, 0.2), "steel", car)
			box(CFrame.new(ex, 4.2, 41.9), Vector3.new(4.6, 7.4, 0.06), "marble", car)
			rod(Vector3.new(ex - 2.2, 3.2, 41.6), Vector3.new(ex + 2.2, 3.2, 41.6), 0.08, "#C8CBCE", Mat.Metal, car)
			local panel = plain(CFrame.new(ex, 8.42, 39.2), Vector3.new(3.4, 0.06, 3.4), i == 2 and "#EEF3FF" or "#9A9C9E",
				i == 2 and Mat.Neon or Mat.SmoothPlastic, car, { Name = "CarLight", CastShadow = false })
			local sl = Instance.new("SurfaceLight")
			sl.Face = Enum.NormalId.Bottom
			sl.Range = 12
			sl.Brightness = i == 2 and 1.4 or 0
			sl.Angle = 120
			sl.Color = Color3.fromRGB(220, 230, 255)
			sl.Parent = panel
			CollectionService:AddTag(panel, i == 2 and "OfcFlicker" or "OfcCarLight")
			box(CFrame.new(ex + 2.5, 4.2, 37.6), Vector3.new(0.06, 2.4, 0.9), "steel", car)
			for k = 0, 7 do
				disc(Vector3.new(ex + 2.46, 3.4 + (k % 4) * 0.45, 37.4 + math.floor(k / 4) * 0.4), -Vector3.xAxis, 0.11, 0.04,
					k == 3 and "#FFB347" or "#3A3C3F", k == 3 and Mat.Neon or Mat.Metal, car)
			end
			-- shaft walls around the car (dark concrete) and its roof
			box(CFrame.new(ex, 4, 43), Vector3.new(7, 20, 1), "concrete", car, "#3A3B3E")
			for _, sx in { -1, 1 } do
				box(CFrame.new(ex + sx * 3.4, 4, 39.5), Vector3.new(0.8, 20, 7), "concrete", car, "#3A3B3E")
			end
			-- floor indicator above the doors
			local _, g = sign(CFrame.lookAt(Vector3.new(ex, 9.15, 35.38), Vector3.new(ex, 9.15, 30)), Vector3.new(1.8, 0.7, 0.06),
				{ { text = i == 2 and "▼ 14" or "14", h = 0.86, y = 0.07, color = "#FFAE34", font = Enum.Font.Arcade } },
				{ bg = "#050505", light = 0, brightness = 1.6, name = "Indicator" .. i }, e)
			g.Name = "Display"
		end
		-- call buttons between the cars: down is lit
		local call = sub("CallPanel")
		box(CFrame.new(0, 3.7, 35.38), Vector3.new(0.7, 1.4, 0.06), "steel", call)
		disc(Vector3.new(0, 4.0, 35.33), -Vector3.zAxis, 0.16, 0.06, "#4A4C50", Mat.Metal, call)
		disc(Vector3.new(0, 3.45, 35.33), -Vector3.zAxis, 0.16, 0.06, "#FFB347", Mat.Neon, call).Name = "DownLit"
		-- side walls: walnut cladding with dark reveals
		for _, sx in { -1, 1 } do
			local x = sx * 11.7
			box(CFrame.new(x, CEIL / 2, 26.9), Vector3.new(0.1, CEIL, 17.1), "walnut", lobby)
			for z = 19.4, 34.6, 2.4 do
				decor(plain(CFrame.new(x - sx * 0.055, CEIL / 2, z), Vector3.new(0.02, CEIL, 0.06), "#120D0A", Mat.SmoothPlastic, lobby), false)
			end
			box(CFrame.new(x - sx * 0.08, 0.2, 26.9), Vector3.new(0.08, 0.4, 17.1), "steel", lobby)
		end
		sign(CFrame.lookAt(Vector3.new(11.6, 5.6, 27), Vector3.new(0, 5.6, 27)), Vector3.new(3.6, 2.6, 0.06), {
			{ text = "14", h = 0.3, color = "#2A2C2F", font = Enum.Font.GothamBold },
			{ text = spec.company, h = 0.14, color = "#2A2C2F", font = Enum.Font.Garamond },
			{ text = "Reception  ↑     Stair B  ←", h = 0.11, color = "#3A3C3F" },
			{ text = "Visitors please sign in", h = 0.09, color = "#3A3C3F" },
		}, { bg = "#B9BDC1", material = Mat.Metal, name = "Directory" }, lobby)
		-- someone's badge on the floor by car 2
		local badge = plain(CFrame.new(4.1, 0.02, 33.2) * yaw(23), Vector3.new(0.62, 0.03, 0.95), "#F2F1EC", Mat.SmoothPlastic, lobby, { Name = "Badge" })
		decor(badge, false)
		local bg = Instance.new("SurfaceGui")
		bg.Face = Enum.NormalId.Top
		bg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		bg.PixelsPerStud = 200
		bg.Parent = badge
		for k, l in { { "HALLOWAY & KANE", 0.06, 0.12, "#1E3A5F" }, { "DANIEL ROSS", 0.62, 0.12, "#111111" }, { "FLOOR 14  ·  ID 4114", 0.78, 0.08, "#444444" } } do
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.fromScale(0.9, l[3])
			t.Position = UDim2.fromScale(0.05, l[2])
			t.Text = l[1]
			t.TextScaled = true
			t.TextColor3 = hex(l[4])
			t.Font = Enum.Font.GothamBold
			t.Parent = bg
		end
		local photo = Instance.new("Frame")
		photo.Size = UDim2.fromScale(0.42, 0.36)
		photo.Position = UDim2.fromScale(0.29, 0.21)
		photo.BackgroundColor3 = hex("#6D7378")
		photo.Parent = bg
		task.wait()

		-- glass entry wall: frosted company name, a pair of frameless glass doors, one hooked open
		local entry = sub("Entry")
		sign(CFrame.lookAt(Vector3.new(-7.75, 5.9, 18.1), Vector3.new(-7.75, 5.9, 30)), Vector3.new(7.2, 1.3, 0.02), {
			{ text = spec.company, h = 0.62, y = 0.05, color = "#F4F4F0", transparency = 0.25, font = Enum.Font.Garamond },
			{ text = "LEGAL  &  ADVISORY", h = 0.26, color = "#F4F4F0", transparency = 0.35, font = Enum.Font.Gotham },
		}, { hidden = true, name = "Manifest" }, entry)
		plain(CFrame.new(-1.75, 4, 18), Vector3.new(3.4, 7.9, 0.12), "#A9BCC3", Mat.SmoothPlastic, entry, { Transparency = 0.88, Reflectance = 0.05, CastShadow = false, Name = "DoorL" })
		plain(CFrame.new(3.5, 4, 19.75) * yaw(90), Vector3.new(3.4, 7.9, 0.12), "#A9BCC3", Mat.SmoothPlastic, entry, { Transparency = 0.88, Reflectance = 0.05, CastShadow = false, Name = "DoorR" })
		for _, d in { { CFrame.new(-1.75, 0, 18), 0 }, { CFrame.new(3.5, 0, 19.75) * yaw(90), 1 } } do -- left shut, right hooked open into the lobby
			for _, y in { 0.25, 7.75 } do
				box(d[1] * CFrame.new(0, y, 0), Vector3.new(3.4, 0.4, 0.2), "steel", entry)
			end
			local off = d[2] == 0 and (d[1].RightVector * 1.3 + Vector3.new(0, 0, 0.25)) or (-d[1].RightVector * 1.3 + Vector3.new(0.25, 0, 0))
			rod(d[1].Position + off + Vector3.new(0, 2.6, 0), d[1].Position + off + Vector3.new(0, 5.6, 0), 0.07, "#C8CBCE", Mat.Metal, entry)
		end
		box(CFrame.new(0, 8.12, 18), Vector3.new(7, 0.24, 0.3), "steel", entry)

		-- reception desk: walnut front, marble transaction ledge, a lamp left on
		local rec = sub("Reception")
		box(CFrame.new(0, 1.95, 11), Vector3.new(10, 3.9, 0.4), "walnut", rec)
		box(CFrame.new(0, 3.97, 10.75), Vector3.new(10.6, 0.14, 1.3), "marble", rec)
		box(CFrame.new(0, 2.6, 9.1), Vector3.new(10, 0.14, 2.6), "oak", rec, "#C9BBA2")
		for _, sx in { -1, 1 } do
			box(CFrame.new(sx * 5, 1.95, 9.5), Vector3.new(0.4, 3.9, 3.4), "walnut", rec)
		end
		box(CFrame.new(0, 0.2, 11.22), Vector3.new(9.6, 0.4, 0.04), "steel", rec)
		decor(plain(CFrame.new(0, 3.86, 11.32), Vector3.new(9.8, 0.05, 0.05), "#CFC8B8", Mat.SmoothPlastic, rec), false)
		place("ofc_monitor", CFrame.new(-0.6, 2.67, 9.7) * yaw(12), { parent = rec, name = "ReceptionMonitor" })
		place("ofc_keyboard", CFrame.new(-0.4, 2.67, 8.4) * yaw(6), { parent = rec })
		place("ofc_mouse", CFrame.new(0.8, 2.67, 8.3), { parent = rec })
		local ph = place("ofc_desk_phone", CFrame.new(1.9, 2.67, 9.3) * yaw(20), { parent = rec, name = "ReceptionPhone" })
		local hs = part(ph, "handset")
		if hs then -- off the hook
			hs.CFrame = CFrame.new(2.4, 2.75, 8.4) * CFrame.Angles(0, math.rad(70), math.rad(80))
		end
		place("ofc_pc", CFrame.new(-3.4, 0, 8.6) * yaw(180), { parent = rec })
		for k = 1, 5 do
			local p = plain(CFrame.new(-1.8 + k * 0.05, 2.68 + k * 0.01, 9) * yaw(k * 7), Vector3.new(0.75, 0.01, 1.05), "#ECEAE3", Mat.SmoothPlastic, rec)
			decor(p, false)
		end
		-- logo wall behind: brushed letters lit from above
		sign(CFrame.lookAt(Vector3.new(0, 6.4, 3.63), Vector3.new(0, 6.4, 30)), Vector3.new(12.5, 2.6, 0.04), {
			{ text = spec.company, h = 0.58, y = 0.04, color = "#AEB3B8", font = Enum.Font.Garamond },
			{ text = "LEGAL  &  ADVISORY  ·  EST. 1987", h = 0.22, color = "#8C9196", font = Enum.Font.Gotham },
		}, { hidden = true, name = "Logo" }, rec)
		return "doors, elevators, lobby, entry, reception"
	end

	------------------------------------------------------------------ stairwell B
	-- one flight: steps rising along `dir` from `base` (bottom nosing line centre), with a sloped soffit under them
	local function flight(base, dir, width, rise, steps, run, parent)
		local h = rise / steps
		local right = dir:Cross(Vector3.yAxis)
		for i = 1, steps do
			local c = base + dir * ((i - 0.5) * run) + Vector3.new(0, h * (i - 0.5), 0)
			box(CFrame.fromMatrix(c, right, Vector3.yAxis), Vector3.new(width, h, run), "concrete", parent)
			-- anti-slip nosing
			box(CFrame.fromMatrix(c + Vector3.new(0, h / 2 + 0.02, 0) - dir * (run / 2 - 0.15), right, Vector3.yAxis), Vector3.new(width - 0.2, 0.04, 0.3), "alu", parent, "#B9A34A")
		end
		local runT = steps * run
		local alpha = math.atan2(rise, runT)
		local n = Vector3.yAxis * math.cos(alpha) - dir * math.sin(alpha)
		local top = base + dir * (runT / 2) + Vector3.new(0, rise / 2 - h, 0)
		local len = math.sqrt(rise * rise + runT * runT) + 1
		local slopeDir = (dir * runT + Vector3.new(0, rise, 0)).Unit
		box(CFrame.fromMatrix(top - n * 0.45, right, n, -slopeDir), Vector3.new(width, 0.9, len), "concrete", parent)
	end

	function phases.stairs()
		local s = Root.clear(id, "Ground")
		local S = spec.stair
		local W = S.spine[1] - S.x0 -- flight width (5.8)
		local xw, xe = (S.x0 + S.spine[1]) / 2, (S.spine[2] + S.x1) / 2
		local run = (S.mid - S.landing) / S.steps
		local landing = function(y, z0, z1)
			box(CFrame.new((S.x0 + S.x1) / 2, y - 0.5, (z0 + z1) / 2), Vector3.new(S.x1 - S.x0, 1, z1 - z0), "concrete", s)
		end
		landing(0, S.z0, S.landing) -- this floor
		landing(-2 * S.rise, S.z0, S.landing) -- 13
		landing(2 * S.rise, S.z0, S.landing) -- 15
		landing(-S.rise, S.mid, S.z1)
		landing(S.rise, S.mid, S.z1)
		box(CFrame.new((S.x0 + S.x1) / 2, S.bottom - 0.5, (S.z0 + S.z1) / 2), Vector3.new(S.x1 - S.x0, 1, S.z1 - S.z0), "concrete", s, "#4A4B4E")
		box(CFrame.new((S.x0 + S.x1) / 2, S.top + 0.5, (S.z0 + S.z1) / 2), Vector3.new(S.x1 - S.x0, 1, S.z1 - S.z0), "concrete", s, "#4A4B4E")
		-- flights: down to 13 (west then east), up to 15 (east then west)
		flight(Vector3.new(xw, -S.rise, S.mid), -Vector3.zAxis, W, S.rise, S.steps, run, s)
		flight(Vector3.new(xe, -2 * S.rise, S.landing), Vector3.zAxis, S.x1 - S.spine[2], S.rise, S.steps, run, s)
		flight(Vector3.new(xe, 0, S.landing), Vector3.zAxis, S.x1 - S.spine[2], S.rise, S.steps, run, s)
		flight(Vector3.new(xw, S.rise, S.mid), -Vector3.zAxis, W, S.rise, S.steps, run, s)
		task.wait()
		-- shaft walls above and below this floor's band, and the spine wall between the flights
		local function wallBand(a, b, y0, y1, t, openings)
			local m = Geo.wall(Vector3.new(a[1], y0, a[2]), Vector3.new(b[1], y0, b[2]), y1 - y0, t, openings, nil, s)
			for _, p in m:GetChildren() do
				Materials.apply(p, M.concrete, hex("#9E9C97"))
			end
		end
		for _, band in { { S.bottom, 0 }, { CEIL, S.top } } do
			local y0 = band[1]
			local doorAt = { at = 6, width = DOOR_W, bottom = (y0 < 0 and (-2 * S.rise - y0) or (2 * S.rise - y0)), top = 0 }
			doorAt.top = doorAt.bottom + DOOR_H
			wallBand({ S.x0, S.z0 }, { S.x1, S.z0 }, band[1], band[2], 0.5, { doorAt })
			wallBand({ S.x0, S.z1 }, { S.x1, S.z1 }, band[1], band[2], 1)
			wallBand({ S.x0, S.z0 }, { S.x0, S.z1 }, band[1], band[2], 1)
			wallBand({ S.x1, S.z0 }, { S.x1, S.z1 }, band[1], band[2], 0.5)
		end
		wallBand({ (S.spine[1] + S.spine[2]) / 2, S.landing }, { (S.spine[1] + S.spine[2]) / 2, S.mid }, S.bottom, S.top, S.spine[2] - S.spine[1])
		-- handrails on the outer walls, following each flight
		local function rail(x, zLow, yLow, zHigh, yHigh)
			local a, b = Vector3.new(x, yLow + 3, zLow), Vector3.new(x, yHigh + 3, zHigh)
			rod(a, b, 0.08, "#B5B8BB", Mat.Metal, s)
			for t = 0.15, 0.85, 0.35 do
				local p = a:Lerp(b, t)
				box(CFrame.new(p.X + (x < -50 and -0.15 or 0.15), p.Y - 0.1, p.Z), Vector3.new(0.3, 0.08, 0.08), "steel", s)
			end
		end
		rail(S.x0 + 0.35, S.mid, -S.rise, S.landing, 0)
		rail(S.x1 - 0.35, S.landing, -2 * S.rise, S.mid, -S.rise)
		rail(S.x1 - 0.35, S.landing, 0, S.mid, S.rise)
		rail(S.x0 + 0.35, S.mid, S.rise, S.landing, 2 * S.rise)
		-- the other floors' doors: 13 (locked, something knocks back) and 15 (blocked by stacked chairs)
		for _, f in { { -2 * S.rise, "13" }, { 2 * S.rise, "15" } } do
			local y = f[1]
			local leaf = box(CFrame.new(-50, y + DOOR_H / 2, S.z0 + 0.05), Vector3.new(DOOR_W - 0.1, DOOR_H - 0.08, 0.2), "paint_metal", s, "#6E7378")
			leaf.Name = "Door" .. f[2]
			box(CFrame.new(-50 + 1.2, y + 3.4, S.z0 + 0.25), Vector3.new(1.6, 0.18, 0.18), "steel", s)
			sign(CFrame.lookAt(Vector3.new(-46.6, y + 5.2, S.z0 + 0.28), Vector3.new(-46.6, y + 5.2, 30)), Vector3.new(1.6, 1.6, 0.05), {
				{ text = f[2], h = 0.62, y = 0.08, color = "#F2F2F2", font = Enum.Font.GothamBlack },
				{ text = "STAIR B", h = 0.18, color = "#F2F2F2", font = Enum.Font.GothamBold },
			}, { bg = "#1F4F8F", name = "Floor" .. f[2] }, s)
			if f[2] == "13" then
				leaf:SetAttribute("Knock", true)
				CollectionService:AddTag(leaf, "OfcDoor13")
			end
		end
		sign(CFrame.lookAt(Vector3.new(-46.6, 5.2, S.z0 + 0.28), Vector3.new(-46.6, 5.2, 30)), Vector3.new(1.6, 1.6, 0.05), {
			{ text = "14", h = 0.62, y = 0.08, color = "#F2F2F2", font = Enum.Font.GothamBlack },
			{ text = "STAIR B", h = 0.18, color = "#F2F2F2", font = Enum.Font.GothamBold },
		}, { bg = "#1F4F8F", name = "Floor14" }, s)
		for k = 0, 3 do
			place("ofc_stack_chair", CFrame.new(-51.5 + (k % 2) * 0.4, 2 * S.rise + k * 0.55, S.z0 + 2.2 + k * 0.12) * yaw(10 + k * 6), { parent = s, collision = "Box" })
		end
		place("ofc_box", CFrame.new(-48.4, 2 * S.rise, S.z0 + 1.6) * yaw(30), { parent = s })
		place("ofc_box", CFrame.new(-48.2, 2 * S.rise + 1.22, S.z0 + 1.7) * yaw(-10), { parent = s })
		-- caution tape across the top of the flight up to 15
		local tapeY = 2 * S.rise + 3
		decor(rod(Vector3.new(S.x0 + 0.2, tapeY, S.landing + 0.3), Vector3.new(S.spine[1] - 0.1, tapeY - 0.3, S.landing + 0.5), 0.05, "#E8C21A", Mat.SmoothPlastic, s), false)
		return "stairwell B: 4 flights, 5 landings, doors 13 and 15"
	end

	------------------------------------------------------------------ screens
	-- what a monitor shows when it is on: a SurfaceGui on the screen mesh (front = -Z) and a little light
	local SCREENS = {}
	local function screenGui(p, bg)
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Front
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 140
		g.LightInfluence = 0
		g.Brightness = 1.15
		g.ClipsDescendants = true
		g.Name = "Screen"
		local f = Instance.new("Frame")
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundColor3 = hex(bg)
		f.BorderSizePixel = 0
		f.Parent = g
		g.Parent = p
		return f, g
	end
	local function label(parent, text, x, y, w, h, color, font, align, size)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromScale(x, y)
		t.Size = UDim2.fromScale(w, h)
		t.Text = text
		t.TextColor3 = hex(color)
		t.Font = font or Enum.Font.Gotham
		t.TextXAlignment = align or Enum.TextXAlignment.Left
		t.TextYAlignment = Enum.TextYAlignment.Top
		if size then
			t.TextSize = size
		else
			t.TextScaled = true
		end
		t.TextWrapped = true
		t.Parent = parent
		return t
	end
	function SCREENS.lock(f)
		f.BackgroundColor3 = hex("#0E2A47")
		local grad = Instance.new("UIGradient")
		grad.Color = ColorSequence.new(hex("#16416B"), hex("#081624"))
		grad.Rotation = 60
		grad.Parent = f
		label(f, "2:14", 0.06, 0.52, 0.5, 0.26, "#FFFFFF", Enum.Font.GothamMedium)
		label(f, "Tuesday, October 27", 0.06, 0.78, 0.6, 0.09, "#E6EEF5", Enum.Font.Gotham)
		label(f, "Locked — " .. spec.company, 0.06, 0.06, 0.6, 0.06, "#B9CCE0", Enum.Font.Gotham)
		return Color3.fromRGB(60, 110, 170)
	end
	function SCREENS.saver(f)
		f.BackgroundColor3 = hex("#000000")
		local t = label(f, "H&K", 0.3, 0.38, 0.4, 0.2, "#3B4652", Enum.Font.Garamond, Enum.TextXAlignment.Center)
		t.Name = "Bounce"
		return Color3.fromRGB(30, 40, 60)
	end
	function SCREENS.email(f)
		f.BackgroundColor3 = hex("#F3F3F3")
		local bar = Instance.new("Frame")
		bar.Size = UDim2.fromScale(1, 0.09)
		bar.BackgroundColor3 = hex("#1E5AA8")
		bar.BorderSizePixel = 0
		bar.Parent = f
		label(bar, "New Message — Draft", 0.02, 0.15, 0.6, 0.7, "#FFFFFF", Enum.Font.GothamMedium)
		label(f, "To:  all-staff@hallowaykane.com", 0.03, 0.12, 0.94, 0.06, "#333333")
		label(f, "Subject:  (no subject)", 0.03, 0.19, 0.94, 0.06, "#333333")
		local body = label(f, "", 0.03, 0.29, 0.94, 0.66, "#111111", Enum.Font.Arial, nil, 22)
		body.Name = "Body"
		body:SetAttribute("Full", "Has anyone else heard the knocking in stair B?\n\nIt comes from 13. Security says 13 has been empty since the renovation.\n\nI stayed late again. The lights keep going off behind me.\n\nIf you read this, don't take the stairs. Don't")
		body.Text = body:GetAttribute("Full")
		CollectionService:AddTag(body, "OfcTyping")
		return Color3.fromRGB(200, 205, 215)
	end
	function SCREENS.visitor(f)
		f.BackgroundColor3 = hex("#FAFAFA")
		label(f, "VISITOR LOG — FLOOR 14", 0.04, 0.05, 0.92, 0.08, "#1E3A5F", Enum.Font.GothamBold)
		local rows = { { "22:05", "Courier (DHL)", "OUT 22:09" }, { "23:40", "Facilities — night", "OUT 00:15" }, { "01:47", "D. Ross", "—" }, { "02:13", "", "—" } }
		for i, r in rows do
			local y = 0.2 + (i - 1) * 0.12
			label(f, r[1], 0.04, y, 0.2, 0.07, "#222222", Enum.Font.Code)
			label(f, r[2], 0.25, y, 0.45, 0.07, "#222222", Enum.Font.Gotham)
			label(f, r[3], 0.74, y, 0.22, 0.07, r[3] == "—" and "#B3261E" or "#222222", Enum.Font.Code)
		end
		return Color3.fromRGB(220, 220, 225)
	end
	function SCREENS.terminal(f)
		f.BackgroundColor3 = hex("#030805")
		local lines = {
			"[02:11:04] srv-14-03  temp OK  41C", "[02:11:52] door B-14  OPEN", "[02:12:30] motion  STAIR B  L13",
			"[02:12:31] motion  STAIR B  L13", "[02:12:33] cam-03  signal lost", "[02:13:10] door B-13  ACCESS DENIED",
			"[02:13:11] door B-13  ACCESS DENIED", "[02:13:12] door B-13  ACCESS DENIED", "[02:13:58] lighting zone W  OFF", "> _",
		}
		local t = label(f, table.concat(lines, "\n"), 0.03, 0.04, 0.94, 0.92, "#41FF7A", Enum.Font.Code, nil, 17)
		t.Name = "Log"
		return Color3.fromRGB(40, 200, 90)
	end
	function SCREENS.sheet(f)
		f.BackgroundColor3 = hex("#FFFFFF")
		local grid = Instance.new("Frame")
		grid.Size = UDim2.fromScale(1, 0.92)
		grid.Position = UDim2.fromScale(0, 0.08)
		grid.BackgroundTransparency = 1
		grid.Parent = f
		for i = 0, 11 do
			local l = Instance.new("Frame")
			l.Size = UDim2.new(1, 0, 0, 1)
			l.Position = UDim2.fromScale(0, i / 12)
			l.BackgroundColor3 = hex("#D4D4D4")
			l.BorderSizePixel = 0
			l.Parent = grid
		end
		local bar = Instance.new("Frame")
		bar.Size = UDim2.fromScale(1, 0.08)
		bar.BackgroundColor3 = hex("#217346")
		bar.BorderSizePixel = 0
		bar.Parent = f
		label(f, "Q3_billing_FINAL_v7.xlsx", 0.02, 0.01, 0.6, 0.06, "#FFFFFF", Enum.Font.Gotham)
		return Color3.fromRGB(210, 230, 215)
	end
	-- turns a monitor on: content + a small SurfaceLight so the screen lights the desk
	local function screenOn(monitor, kind, lightIt)
		local p = part(monitor, "screen")
		if not p then
			return
		end
		local f = screenGui(p, "#000000")
		local col = SCREENS[kind](f)
		p.Material = Mat.SmoothPlastic
		CollectionService:AddTag(p, "OfcScreen")
		p:SetAttribute("Kind", kind)
		if lightIt ~= false then
			local l = Instance.new("SurfaceLight")
			l.Face = Enum.NormalId.Front
			l.Range = 7
			l.Angle = 90
			l.Brightness = 0.9
			l.Color = col
			l.Shadows = false
			l.Parent = p
		end
		return p
	end

	------------------------------------------------------------------ desk clutter
	local DESK_Y = 2.68
	local function clutter(rng, layer, origin, right, fwd, area, top)
		-- origin: centre of a work surface; right/fwd: its axes (fwd toward the person sitting); area: half sizes
		top = top or DESK_Y
		local function at(u, v)
			return origin + right * u + fwd * v + Vector3.new(0, top - origin.Y, 0)
		end
		local function faceUser(pos, extra)
			return CFrame.lookAt(pos, pos + fwd) * yaw(extra or 0)
		end
		local picks = rng:NextInteger(2, 5)
		for _ = 1, picks do
			local r = rng:NextNumber()
			local u, v = rng:NextNumber(-area.X, area.X), rng:NextNumber(-area.Y * 0.2, area.Y)
			local pos = at(u, v)
			if r < 0.2 then
				local m = place("ofc_mug", faceUser(pos, rng:NextNumber(0, 360)), { parent = layer, collision = "none" })
				local mp = part(m, "mug")
				if mp then
					mp.Color = hex(MUG_COLORS[rng:NextInteger(1, #MUG_COLORS)])
				end
			elseif r < 0.4 then
				for k = 1, rng:NextInteger(2, 6) do
					decor(plain(faceUser(pos + Vector3.new(0, 0.006 * k, 0), rng:NextNumber(-12, 12)), Vector3.new(0.75, 0.01, 1.05), "#ECEAE3", Mat.SmoothPlastic, layer), false)
				end
			elseif r < 0.52 then
				place("ofc_photo", faceUser(pos, 90 + rng:NextNumber(-25, 25)), { parent = layer, collision = "none" }) -- the scan's picture faces +X
			elseif r < 0.62 then
				place("ofc_cactus", faceUser(pos, rng:NextNumber(0, 360)), { parent = layer, collision = "none" })
			elseif r < 0.72 then
				place("ofc_binder", faceUser(pos, rng:NextNumber(-20, 20)), { parent = layer, collision = "none" })
			elseif r < 0.8 then
				place("ofc_stapler", faceUser(pos, rng:NextNumber(0, 360)), { parent = layer, collision = "none" })
			elseif r < 0.88 then
				place("ofc_clipboard", faceUser(pos, rng:NextNumber(-30, 30)), { parent = layer, collision = "none" })
			elseif r < 0.94 then
				place("ofc_stationery", faceUser(pos, rng:NextNumber(-30, 30)), { parent = layer, collision = "none" })
			else
				place("ofc_books_b", faceUser(pos, rng:NextNumber(-10, 10)), { parent = layer, collision = "none" })
			end
		end
	end

	-- a task chair near `pos` facing `dir`: pushed back, swivelled, sometimes gone or on its side
	local function chair(rng, layer, pos, dir, opts)
		opts = opts or {}
		local r = rng:NextNumber()
		if r < (opts.missing or 0.12) then
			return nil
		end
		local jitter = Vector3.new(rng:NextNumber(-0.7, 0.7), 0, rng:NextNumber(-0.7, 0.7))
		local cf = CFrame.lookAt(pos + jitter, pos + jitter + dir) * yaw(rng:NextNumber(-40, 40))
		if r > 0.97 or opts.fallen then
			-- knocked over: lying on its back
			cf = CFrame.new(pos + jitter + Vector3.new(0, 1.2, 0)) * yaw(rng:NextNumber(0, 360)) * CFrame.Angles(math.rad(-90), 0, 0)
		end
		return place("ofc_task_chair", cf, { parent = layer })
	end

	------------------------------------------------------------------ office: cubicles and pods
	function phases.office()
		local o = Root.clear(id, "Props")
		local rng = Random.new(spec.seed + 11)
		local PH = spec.panelHeight
		local cubeLayer = Instance.new("Model")
		cubeLayer.Name = "Cubicles"
		cubeLayer.Parent = o
		local special = { ["1-1-2"] = "email", ["2-1-1"] = "lock", ["2-0-3"] = "ransacked", ["1-0-0"] = "saver" }
		for bi, b in spec.cubicles do
			local x0, z0, cell = b.x0, b.z0, b.cell
			local W, D = b.cols * cell, b.rows * cell
			local function panel(a, bb, openings)
				local m = Geo.wall(a, bb, PH, 0.25, openings or {}, nil, cubeLayer)
				for _, p in m:GetChildren() do
					Materials.apply(p, M.cubicle, hex(T.cubicle))
					box(p.CFrame * CFrame.new(0, p.Size.Y / 2 + 0.04, 0), Vector3.new(p.Size.X + 0.02, 0.08, 0.32), "alu", m)
					for _, ex in { -1, 1 } do
						box(p.CFrame * CFrame.new(ex * (p.Size.X / 2 - 0.08), 0, 0), Vector3.new(0.16, p.Size.Y, 0.3), "alu", m)
					end
				end
				return m
			end
			local function aisleOpenings()
				local list = {}
				for r = 0, b.rows - 1 do
					table.insert(list, { at = r * cell + cell / 2 + 0.5, width = 3.8, bottom = 0, top = PH })
				end
				return list
			end
			panel(Vector3.new(x0, 0, z0), Vector3.new(x0 + W, 0, z0))
			panel(Vector3.new(x0, 0, z0 + D), Vector3.new(x0 + W, 0, z0 + D))
			panel(Vector3.new(x0 + cell, 0, z0), Vector3.new(x0 + cell, 0, z0 + D))
			for r = 1, b.rows - 1 do
				panel(Vector3.new(x0, 0, z0 + r * cell), Vector3.new(x0 + W, 0, z0 + r * cell))
			end
			panel(Vector3.new(x0, 0, z0), Vector3.new(x0, 0, z0 + D), aisleOpenings())
			panel(Vector3.new(x0 + W, 0, z0), Vector3.new(x0 + W, 0, z0 + D), aisleOpenings())
			task.wait()
			for col = 0, b.cols - 1 do
				for row = 0, b.rows - 1 do
					local key = ("%d-%d-%d"):format(bi, col, row)
					local kind = special[key]
					local cx, cz = x0 + cell * col + cell / 2, z0 + cell * row + cell / 2
					local side = col == 0 and -1 or 1 -- the aisle side
					local cub = Instance.new("Model")
					cub.Name = "Cubicle_" .. key
					-- L-shaped worksurface: along the shared back panel and along the north panel
					local h = cell / 2
					local backX = cx - side * (h - 1.375)
					box(CFrame.new(backX, DESK_Y - 0.06, cz), Vector3.new(2.5, 0.12, cell - 0.25), "oak", cub, "#CFC6B4")
					local retX0, retX1 = cx - side * (h - 2.625), cx + side * (h - 1.6)
					box(CFrame.new((retX0 + retX1) / 2, DESK_Y - 0.06, cz - h + 1.375), Vector3.new(math.abs(retX1 - retX0), 0.12, 2.5), "oak", cub, "#CFC6B4")
					local toUser = Vector3.new(side, 0, 0)
					local ransacked = kind == "ransacked"
					local mon = place("ofc_monitor", CFrame.lookAt(Vector3.new(cx - side * (h - 0.85), DESK_Y, cz - 0.4), Vector3.new(cx - side * (h - 0.85), DESK_Y, cz - 0.4) + toUser) * yaw(rng:NextNumber(-8, 8)),
						{ parent = cub, name = "Monitor" })
					if ransacked then
						mon:PivotTo(CFrame.new(cx - side * (h - 1.3), DESK_Y + 0.12, cz - 0.6) * CFrame.Angles(math.rad(-90), math.rad(side * 90), 0))
					elseif kind and kind ~= "ransacked" then
						screenOn(mon, kind)
					end
					if rng:NextNumber() < 0.35 and not ransacked then
						place("ofc_monitor", CFrame.lookAt(Vector3.new(cx - side * (h - 0.95), DESK_Y, cz + h - 2.25), Vector3.new(cx, DESK_Y, cz + 0.6)), { parent = cub })
					end
					local kb = Vector3.new(cx - side * (h - 2.05), DESK_Y, cz - 0.3)
					place("ofc_keyboard", CFrame.lookAt(kb, kb + toUser) * yaw(rng:NextNumber(-10, 10)), { parent = cub })
					place("ofc_mouse", CFrame.lookAt(kb + Vector3.new(0, 0, 1.15), kb + Vector3.new(0, 0, 1.15) + toUser), { parent = cub })
					if rng:NextNumber() < 0.75 then
						local pp = Vector3.new(cx + side * 0.2, DESK_Y, cz - h + 1.1)
						place("ofc_desk_phone", CFrame.lookAt(pp, pp + Vector3.new(0, 0, 1)) * yaw(rng:NextNumber(-20, 20)), { parent = cub })
					end
					local pc = Vector3.new(cx - side * (h - 1.1), 0, cz + h - 1.5)
					place("ofc_pc", CFrame.lookAt(pc, pc + toUser), { parent = cub })
					local ped = Vector3.new(cx + side * 0.6, 0, cz - h + 1.25)
					place("ofc_pedestal", CFrame.lookAt(ped, ped + Vector3.new(0, 0, 1)), { parent = cub })
					if rng:NextNumber() < 0.6 then
						place("ofc_bin", CFrame.new(cx - side * 0.8, 0, cz + h - 0.7), { parent = cub })
					end
					clutter(rng, cub, Vector3.new(backX, DESK_Y, cz + 0.5), Vector3.new(0, 0, 1), toUser, Vector2.new(h - 1, 0.9))
					clutter(rng, cub, Vector3.new((retX0 + retX1) / 2, DESK_Y, cz - h + 1.2), Vector3.new(side, 0, 0), Vector3.new(0, 0, 1), Vector2.new(h - 2.4, 0.8))
					chair(rng, cub, Vector3.new(cx + side * 0.3, 0, cz + 0.6), -toUser, { fallen = ransacked, missing = kind and 0 or 0.12 })
					if ransacked then
						for k = 1, 26 do
							local p = Vector3.new(cx + rng:NextNumber(-h, h + 1) * -side, 0.02 + k * 0.002, cz + rng:NextNumber(-h, h))
							decor(plain(CFrame.new(p) * yaw(rng:NextNumber(0, 360)), Vector3.new(0.75, 0.01, 1.05), "#ECEAE3", Mat.SmoothPlastic, cub), false)
						end
						place("ofc_box", CFrame.new(cx + side * 0.6, 0, cz - 1.4) * yaw(35) * CFrame.Angles(0, 0, math.rad(90)) + Vector3.new(0, 0.7, 0), { parent = cub })
					end
					cub.Parent = cubeLayer
					task.wait()
				end
			end
		end

		-- open-plan pods: four desks around a fabric screen
		local podLayer = Instance.new("Model")
		podLayer.Name = "Pods"
		podLayer.Parent = o
		local podSpecial = { ["2-1"] = "ring", ["3-2"] = "saver", ["7-4"] = "sheet", ["5-3"] = "coat" }
		for pi, pc in spec.pods do
			local px, pz = pc[1], pc[2]
			local pod = Instance.new("Model")
			pod.Name = "Pod" .. pi
			box(CFrame.new(px, DESK_Y + 0.8, pz), Vector3.new(11.3, 1.6, 0.12), "cubicle", pod)
			box(CFrame.new(px, DESK_Y + 1.62, pz), Vector3.new(11.34, 0.06, 0.16), "alu", pod)
			local k = 0
			for _, row in { -1, 1 } do
				for _, sx in { -1, 1 } do
					k += 1
					local key = ("%d-%d"):format(pi, k)
					local kind = podSpecial[key]
					local dx = px + sx * 2.857
					local dz = pz + row * 1.4285
					local toUser = Vector3.new(0, 0, row)
					local deskCF = CFrame.lookAt(Vector3.new(dx, 0, dz), Vector3.new(dx, 0, dz) + toUser)
					place("ofc_desk", deskCF, { parent = pod })
					local mpos = Vector3.new(dx + rng:NextNumber(-0.6, 0.6), DESK_Y, pz + row * 0.62)
					local mon = place("ofc_monitor", CFrame.lookAt(mpos, mpos + toUser) * yaw(rng:NextNumber(-10, 10)), { parent = pod, name = "Monitor" })
					if kind == "saver" or kind == "sheet" then
						screenOn(mon, kind)
					end
					if rng:NextNumber() < 0.4 then
						local m2 = mpos + Vector3.new(sx * 1.95, 0, row * 0.15)
						place("ofc_monitor", CFrame.lookAt(m2, m2 + toUser) * yaw(-sx * 18), { parent = pod })
					end
					local kb = Vector3.new(dx + rng:NextNumber(-0.4, 0.4), DESK_Y, pz + row * 1.75)
					place("ofc_keyboard", CFrame.lookAt(kb, kb + toUser) * yaw(rng:NextNumber(-8, 8)), { parent = pod })
					place("ofc_mouse", CFrame.lookAt(kb + Vector3.new(1.15, 0, 0), kb + Vector3.new(1.15, 0, 0) + toUser), { parent = pod })
					if kind == "ring" or rng:NextNumber() < 0.5 then
						local pp = Vector3.new(dx - sx * 2.0, DESK_Y, pz + row * 0.9)
						local ph = place("ofc_desk_phone", CFrame.lookAt(pp, pp + toUser) * yaw(sx * 20), { parent = pod, name = kind == "ring" and "RingingPhone" or nil })
						if kind == "ring" then
							CollectionService:AddTag(ph, "OfcRingPhone")
						end
					end
					local pcv = Vector3.new(dx + sx * 2.1, 0, pz + row * 0.85)
					place("ofc_pc", CFrame.lookAt(pcv, pcv + toUser), { parent = pod })
					if rng:NextNumber() < 0.7 then
						local pv = Vector3.new(dx - sx * 1.85, 0, pz + row * 1.25)
						place("ofc_pedestal", CFrame.lookAt(pv, pv + toUser), { parent = pod })
					end
					clutter(rng, pod, Vector3.new(dx, DESK_Y, pz + row * 1.2), Vector3.new(1, 0, 0), toUser, Vector2.new(2.3, 0.9))
					local ch = chair(rng, pod, Vector3.new(dx, 0, pz + row * 4.1), -toUser, { missing = kind and 0 or 0.15 })
					if kind == "coat" and ch then
						-- a coat over the back of the chair, a bag at its feet
						local back = part(ch, "shell")
						if back then
							box(back.CFrame * CFrame.new(0, 0.6, 0.3) * CFrame.Angles(math.rad(-8), 0, 0), Vector3.new(1.9, 2.6, 0.18), "upholstery", pod, "#3A2E2A")
						end
						box(CFrame.new(dx + 0.9, 0.55, pz + row * 3.4) * yaw(25), Vector3.new(1.2, 1.1, 0.45), "leather", pod)
					end
				end
			end
			pod.Parent = podLayer
			task.wait()
		end
		return ("%d cubicles, %d pods"):format(#spec.cubicles * 8, #spec.pods)
	end

	------------------------------------------------------------------ rooms
	function phases.rooms()
		local r = Root.clear(id, "Foliage") -- (the kit's layer names; this map has no plants outside)
		local rng = Random.new(spec.seed + 21)
		local function sub(name)
			local f = Instance.new("Model")
			f.Name = name
			f.Parent = r
			return f
		end
		-- hero props from map.json
		local heroes = sub("Placed")
		for i, p in spec.props do
			local cf = CFrame.new(v3(p.p)) * yaw(p.r)
			place(p.m, cf, { parent = heroes, collision = p.c, shadow = p.s ~= false, scale = p.sc, tint = p.t, name = p.name })
			if i % 12 == 0 then
				task.wait()
			end
		end
		-- the scanned laptop's screen is an untextured plane: leave it on, a dim blue glow toward the door
		for _, m in heroes:GetChildren() do
			local scr = m.Name == "ofc_laptop" and part(m, "lid_floaters_low2")
			if scr then
				scr.Material = Mat.Neon
				scr.Color = Color3.fromRGB(26, 40, 58)
				scr.CastShadow = false
			end
		end

		-- manager's office: walnut desk facing the door, the chair turned to the window
		local mg = sub("Manager")
		box(CFrame.new(-46, 2.7, -37.6), Vector3.new(8, 0.16, 3.6), "walnut", mg)
		for _, sx in { -1, 1 } do
			box(CFrame.new(-46 + sx * 3.8, 1.31, -37.6), Vector3.new(0.3, 2.62, 3.4), "walnut", mg)
		end
		box(CFrame.new(-46, 1.6, -36.0), Vector3.new(7.3, 2.0, 0.12), "walnut", mg)
		place("ofc_pedestal", CFrame.new(-48.6, 0, -38.2) * yaw(180), { parent = mg })
		plain(CFrame.new(-46, 0.02, -36.4), Vector3.new(11, 0.04, 8), "#3A3430", Mat.Fabric, mg, { Name = "Rug" })
		for k = 1, 6 do
			decor(plain(CFrame.new(-47.6 + k * 0.08, 2.79 + k * 0.006, -37.2) * yaw(k * 9), Vector3.new(0.75, 0.01, 1.05), "#ECEAE3", Mat.SmoothPlastic, mg), false)
		end
		-- books on the steel shelves (the scaled Poly Haven units at x = -36.9)
		for _, z in { -32.2, -38.0 } do
			for lvl, y in { 1.3, 2.9, 4.5 } do
				if (lvl + z) % 2 ~= 0 or lvl ~= 2 then
					place("ofc_books_b", CFrame.new(-37.4, y, z + rng:NextNumber(-0.6, 0.6)) * yaw(90), { parent = mg, collision = "none" })
				end
			end
		end

		-- stock every steel shelf unit. Board tops measured on the scan in Blender: 6, 30, 54, 77 and 100 % of its height
		-- (raycasts can't find them: the unit collides as one box)
		for _, m in heroes:GetChildren() do
			if m.Name == "ofc_shelves" then
				local pv = m:GetPivot()
				local _, size = m:GetBoundingBox()
				local right = pv.RightVector
				local inStorage = pv.Position.X > 36
				for _, f in { 0.063, 0.298, 0.535, 0.772, 0.995 } do
					local by = pv.Position.Y + size.Y * f
					for k = -1, 1 do
						if rng:NextNumber() < 0.8 then
							local pos = pv.Position + right * (k * 1.0 + rng:NextNumber(-0.12, 0.12))
							pos = Vector3.new(pos.X, by, pos.Z)
							local face = CFrame.lookAt(pos, pos + pv.LookVector)
							local r0 = rng:NextNumber()
							if r0 < 0.4 then
								place("ofc_box", face * yaw(90 + rng:NextNumber(-10, 10)), { parent = r, scale = 0.62 })
							elseif r0 < 0.7 and not inStorage then
								place("ofc_books_b", face * yaw(rng:NextNumber(-6, 6)), { parent = r, collision = "none", scale = 0.85 })
							elseif r0 < 0.88 or not inStorage then
								for q = 0, rng:NextInteger(0, 3) do
									local c = pos + Vector3.new(0, 0.16 + q * 0.31, 0)
									box(CFrame.lookAt(c, c + pv.LookVector) * yaw(rng:NextNumber(-4, 4)), Vector3.new(0.82, 0.3, 1.16), "plastic_white", r, "#F1EFE7")
								end
							else
								place("ofc_crate", face * yaw(90), { parent = r, scale = 0.55 })
							end
						end
					end
				end
			end
		end

		-- conference room: whiteboard, a projected last slide, chairs left where people stood up
		local cf = sub("Conference")
		local tz = -37.3
		for i, x in { -30.4, -26.8, -23.2, -19.6 } do
			for _, side in { -1, 1 } do
				local pos = Vector3.new(x + rng:NextNumber(-0.4, 0.4), 0, tz + side * (3.2 + rng:NextNumber(0, 0.8)))
				local cfc = CFrame.lookAt(pos, Vector3.new(x, 0, tz)) * yaw(rng:NextNumber(-20, 20))
				if i == 3 and side == 1 then
					cfc = CFrame.new(pos + Vector3.new(0.6, 0.9, 1.4)) * yaw(70) * CFrame.Angles(math.rad(-90), 0, 0) -- knocked over
				end
				place("ofc_meeting_chair", cfc, { parent = cf })
			end
		end
		place("ofc_meeting_chair", CFrame.lookAt(Vector3.new(-32.9, 0, tz), Vector3.new(-25, 0, tz)), { parent = cf })
		place("ofc_meeting_chair", CFrame.lookAt(Vector3.new(-17.3, 0, tz + 0.6), Vector3.new(-25, 0, tz)) * yaw(25), { parent = cf })
		for _, x in { -29.5, -24.7, -20.8 } do -- water glasses, a jug
			disc(Vector3.new(x, 2.86, tz + rng:NextNumber(-1.2, 1.2)), Vector3.yAxis, 0.16, 0.42, "#C9D6DC", Mat.Glass, cf, { Transparency = 0.6, CanCollide = false })
		end
		-- whiteboard on the shared wall
		local wb = CFrame.lookAt(Vector3.new(-35.68, 5.0, -36.3), Vector3.new(-30, 5.0, -36.3))
		local board = sign(wb, Vector3.new(9, 4.2, 0.08), {
			{ text = "Q3 CLOSE — FLOOR 14", h = 0.13, y = 0.05, color = "#1F3E8C", font = Enum.Font.PermanentMarker, align = Enum.TextXAlignment.Left },
			{ text = "• billing reconciliation  ✓\n• Hargreave file → legal  ✓\n• stair B access cards (Facilities)  ??", h = 0.36, color = "#1D1D1D", font = Enum.Font.PermanentMarker, align = Enum.TextXAlignment.Left },
			{ text = "headcount 23", h = 0.1, color = "#1D1D1D", font = Enum.Font.PermanentMarker, align = Enum.TextXAlignment.Left },
			{ text = "24?", h = 0.16, color = "#B3261E", font = Enum.Font.PermanentMarker, align = Enum.TextXAlignment.Right },
		}, { bg = "#F2F2EF", name = "Whiteboard" }, cf)
		board.Material = Mat.SmoothPlastic
		for _, e in { { 0, 2.15, 9.2, 0.16 }, { 0, -2.15, 9.2, 0.16 } } do
			box(wb * CFrame.new(e[1], e[2], 0.02), Vector3.new(e[3], e[4], 0.12), "alu", cf)
		end
		for _, sx in { -1, 1 } do
			box(wb * CFrame.new(sx * 4.6, 0, 0.02), Vector3.new(0.16, 4.46, 0.12), "alu", cf)
		end
		box(wb * CFrame.new(0, -2.3, -0.25), Vector3.new(4, 0.1, 0.4), "alu", cf)
		for k, col in { "#1F3E8C", "#B3261E", "#111111" } do
			rod(wb * Vector3.new(-1 + k * 0.5, -2.2, -0.28), wb * Vector3.new(-0.6 + k * 0.5, -2.2, -0.3), 0.06, col, Mat.Plastic, cf)
		end
		-- tripod screen at the east end with the last slide still up, lit by a ceiling projector
		local sc = CFrame.lookAt(Vector3.new(-16.6, 4.4, -36.3), Vector3.new(-30, 4.4, -36.3))
		local slide = sign(sc, Vector3.new(6.2, 3.6, 0.06), {
			{ text = "Q3 REVIEW", h = 0.16, y = 0.1, color = "#1E3A5F", font = Enum.Font.GothamBold },
			{ text = "Floor 14 — consolidation", h = 0.09, color = "#4A5A6A", font = Enum.Font.Gotham },
			{ text = "Thank you.\nAny questions?", h = 0.28, y = 0.46, color = "#1E3A5F", font = Enum.Font.GothamMedium },
		}, { bg = "#F4F4F2", light = 0.4, brightness = 0.9, name = "Slide" }, cf)
		slide.Material = Mat.Fabric
		box(sc * CFrame.new(0, 1.95, 0.05), Vector3.new(6.5, 0.3, 0.3), "paint_metal", cf, "#2A2C30")
		for _, a in { -35, 35, 180 } do
			local foot = sc * CFrame.new(0, -4.4, 0.6) * yaw(a) * CFrame.new(0, 0, -1.1)
			rod((sc * CFrame.new(0, -1.6, 0.6)).Position, foot.Position + Vector3.new(0, 0.05, 0), 0.06, "#2A2C30", Mat.Metal, cf)
		end
		rod((sc * CFrame.new(0, -1.6, 0.6)).Position, (sc * CFrame.new(0, 1.9, 0.6)).Position, 0.07, "#2A2C30", Mat.Metal, cf)
		local proj = plain(CFrame.new(-25, 9.45, tz) * yaw(-90), Vector3.new(1.4, 0.45, 1.2), "#E4E2DC", Mat.SmoothPlastic, cf, { Name = "Projector" })
		rod(Vector3.new(-25, 9.65, tz), Vector3.new(-25, 10.1, tz), 0.06, "#B8BBBE", Mat.Metal, cf)
		local lens = disc(Vector3.new(-24.25, 9.42, tz), Vector3.xAxis, 0.16, 0.08, "#D9E6FF", Mat.Neon, cf, { Name = "Lens" })
		decor(lens, false)
		local sp = Instance.new("SpotLight")
		sp.Face = Enum.NormalId.Front
		sp.Angle = 26
		sp.Range = 14
		sp.Brightness = 1.6
		sp.Color = Color3.fromRGB(200, 215, 255)
		sp.Parent = lens
		CollectionService:AddTag(proj, "OfcProjector")

		-- break room: kitchen run on the south wall, tables, a vending machine humming
		local br = sub("BreakRoom")
		local x0, x1, zb = 13, 28.4, 35.45
		box(CFrame.new((x0 + x1) / 2, 0.18, zb - 1.0), Vector3.new(x1 - x0, 0.36, 1.8), "plastic_black", br, "#3A3A3A") -- toe kick
		box(CFrame.new((x0 + x1) / 2, 1.7, zb - 1.12), Vector3.new(x1 - x0, 2.7, 2.2), "plastic_white", br, "#E6E2D8")
		box(CFrame.new((x0 + x1) / 2, 3.12, zb - 1.17), Vector3.new(x1 - x0 + 0.1, 0.16, 2.35), "marble", br)
		for x = x0 + 0.95, x1 - 0.9, 1.92 do
			box(CFrame.new(x, 1.75, zb - 2.24), Vector3.new(1.84, 2.6, 0.06), "plastic_white", br, "#EFEBE1")
			box(CFrame.new(x + 0.6, 2.7, zb - 2.3), Vector3.new(0.08, 0.6, 0.08), "steel", br)
		end
		box(CFrame.new((x0 + x1) / 2, 4.4, zb - 0.03), Vector3.new(x1 - x0, 2.4, 0.06), "tiles_white", br)
		box(CFrame.new((x0 + x1) / 2, 7.1, zb - 0.62), Vector3.new(x1 - x0, 3.0, 1.2), "plastic_white", br, "#E6E2D8")
		for x = x0 + 0.95, x1 - 0.9, 1.92 do
			box(CFrame.new(x, 7.1, zb - 1.24), Vector3.new(1.84, 2.9, 0.05), "plastic_white", br, "#EFEBE1")
			box(CFrame.new(x + 0.6, 6.0, zb - 1.3), Vector3.new(0.08, 0.6, 0.08), "steel", br)
		end
		local strip = plain(CFrame.new((x0 + x1) / 2, 5.57, zb - 1.0), Vector3.new(x1 - x0 - 0.6, 0.05, 0.12), "#FFF3DC", Mat.Neon, br, { Name = "UnderCabinet" })
		decor(strip, false)
		local sl = Instance.new("SurfaceLight")
		sl.Face = Enum.NormalId.Bottom
		sl.Range = 6
		sl.Brightness = 1.2
		sl.Angle = 120
		sl.Color = Color3.fromRGB(255, 225, 185)
		sl.Parent = strip
		CollectionService:AddTag(strip, "OfcFlicker")
		-- sink and faucet
		box(CFrame.new(18.5, 3.21, zb - 1.2), Vector3.new(2.2, 0.03, 1.6), "steel", br)
		plain(CFrame.new(18.5, 3.225, zb - 1.2), Vector3.new(1.9, 0.02, 1.3), "#1E2022", Mat.Metal, br)
		rod(Vector3.new(18.5, 3.2, zb - 0.25), Vector3.new(18.5, 4.3, zb - 0.25), 0.07, "#C8CBCE", Mat.Metal, br)
		rod(Vector3.new(18.5, 4.3, zb - 0.25), Vector3.new(18.5, 4.15, zb - 0.95), 0.06, "#C8CBCE", Mat.Metal, br)
		-- two round tables with stacking chairs
		for ti, t in { { 17.5, 25 }, { 27.5, 27.5 } } do
			local c = Vector3.new(t[1], 0, t[2])
			disc(c + Vector3.new(0, 2.56, 0), Vector3.yAxis, 1.7, 0.12, "#EDEBE5", Mat.SmoothPlastic, br)
			rod(c + Vector3.new(0, 0.1, 0), c + Vector3.new(0, 2.5, 0), 0.14, "#2B2D31", Mat.Metal, br)
			disc(c + Vector3.new(0, 0.04, 0), Vector3.yAxis, 0.9, 0.08, "#2B2D31", Mat.Metal, br)
			for k = 0, (ti == 1 and 3 or 2) do
				local a = math.rad(k * 90 + 20 + ti * 15 + rng:NextNumber(-15, 15))
				local pos = c + Vector3.new(math.cos(a) * 2.6, 0, math.sin(a) * 2.6)
				place("ofc_stack_chair", CFrame.lookAt(pos, c) * yaw(rng:NextNumber(-25, 25)), { parent = br })
			end
			place("ofc_mug", CFrame.new(c + Vector3.new(0.4, 2.62, -0.3)), { parent = br, collision = "none" })
		end
		-- notice board: the usual, and a missing poster
		local nb = CFrame.lookAt(Vector3.new(12.32, 5.0, 26), Vector3.new(20, 5.0, 26))
		box(nb, Vector3.new(5.4, 3.4, 0.1), "upholstery", br, "#8A6A45")
		local notes = {
			{ -1.6, 0.8, 1.4, 1.0, { { text = "PLEASE LABEL YOUR FOOD", h = 0.5, color = "#222222", font = Enum.Font.GothamBold } } },
			{ 0.2, 0.9, 1.2, 0.9, { { text = "Fire drill\nOct 30, 10:00", h = 0.8, color = "#B3261E", font = Enum.Font.GothamMedium } } },
			{ -1.2, -0.6, 1.1, 1.0, { { text = "Cake Friday!\n3rd floor kitchen", h = 0.8, color = "#2E6B3A", font = Enum.Font.PermanentMarker } } },
			{ 1.6, -0.2, 1.6, 2.2, { { text = "MISSING", h = 0.16, y = 0.03, color = "#111111", font = Enum.Font.GothamBlack },
				{ text = "", h = 0.42 },
				{ text = "DANIEL ROSS\nFloor 14 · last seen 10/22\nstair B, after 1 a.m.\nSecurity ext. 4114", h = 0.34, color = "#111111", font = Enum.Font.Gotham } } },
		}
		for _, n in notes do
			local p = sign(nb * CFrame.new(n[1], n[2], -0.07) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-5, 5))), Vector3.new(n[3], n[4], 0.02), n[5],
				{ bg = "#F3F1EA", ppu = 120 }, br)
			if n[3] == 1.6 then
				local ph = Instance.new("Frame")
				ph.BackgroundColor3 = hex("#5E6266")
				ph.Size = UDim2.fromScale(0.6, 0.38)
				ph.Position = UDim2.fromScale(0.2, 0.21)
				ph.Parent = p:FindFirstChildOfClass("SurfaceGui")
			end
			disc((nb * CFrame.new(n[1], n[2] + n[4] / 2 - 0.12, -0.1)).Position, nb.LookVector, 0.06, 0.06, "#C0392B", Mat.Plastic, br)
		end
		-- the TV on its bracket shows snow; the roof leak drips into a bucket
		box(CFrame.new(13.2, 6.5, 19.3), Vector3.new(1.6, 0.12, 1.4), "steel", br)
		disc(Vector3.new(20, 0.45, 22.6), Vector3.yAxis, 0.6, 0.9, "#D3A21F", Mat.Plastic, br, { Name = "Bucket" })
		disc(Vector3.new(20, 0.86, 22.6), Vector3.yAxis, 0.55, 0.04, "#6E7E86", Mat.Glass, br, { Transparency = 0.3, CanCollide = false })

		-- copy room: a worktable and reams by the printer
		local cp = sub("CopyRoom")
		box(CFrame.new(-22.6, 2.88, 26), Vector3.new(2.2, 0.12, 8), "oak", cp, "#CFC6B4")
		for _, z in { 22.3, 29.7 } do
			for _, x in { -23.5, -21.7 } do
				box(CFrame.new(x, 1.41, z), Vector3.new(0.14, 2.82, 0.14), "steel", cp)
			end
		end
		for k = 0, 5 do
			box(CFrame.new(-14.6 + (k % 3) * 0.95, 0.25 + math.floor(k / 3) * 0.5, 31.2) * yaw(k * 3), Vector3.new(0.85, 0.48, 1.2), "plastic_white", cp, "#F1EFE7")
		end
		for k = 1, 30 do -- jammed pages on the floor around the printer
			local p = Vector3.new(-15.5 + rng:NextNumber(-2.4, 1.6), 0.02 + k * 0.002, 27.4 + rng:NextNumber(-2.6, 2.6))
			decor(plain(CFrame.new(p) * yaw(rng:NextNumber(0, 360)), Vector3.new(0.75, 0.01, 1.05), "#ECEAE3", Mat.SmoothPlastic, cp), false)
		end

		-- server room: two rows of racks around a cold aisle, trays overhead, a console still logging
		local sv = sub("ServerRoom")
		for i = 0, 5 do
			local z = 21.2 + i * 2.15
			place(i % 2 == 0 and "ofc_rack_a" or "ofc_rack_b", CFrame.new(-40.2, 0, z) * yaw(-90), { parent = sv, name = "Rack" })
			place(i % 2 == 0 and "ofc_rack_b" or "ofc_rack_a", CFrame.new(-31.8, 0, z) * yaw(90), { parent = sv, name = "Rack" })
		end
		for _, x in { -40.2, -31.8 } do
			for _, sx in { -1, 1 } do
				box(CFrame.new(x + sx * 0.9, 8.6, 27.6), Vector3.new(0.08, 0.3, 14), "steel", sv)
			end
			for z = 21, 34.2, 1.2 do
				box(CFrame.new(x, 8.48, z), Vector3.new(1.8, 0.06, 0.12), "steel", sv)
			end
			for k = 1, 5 do
				rod(Vector3.new(x - 0.6 + k * 0.2, 8.62, 20.8), Vector3.new(x - 0.6 + k * 0.2, 8.62, 34.4), 0.06, "#121214", Mat.Plastic, sv)
			end
		end
		local crac = box(CFrame.new(-25.6, 3.4, 30.5), Vector3.new(2.6, 6.8, 6), "plastic_white", sv, "#BDBBB4")
		crac.Name = "CRAC"
		for y = 1.0, 5.8, 0.25 do
			decor(plain(CFrame.new(-26.92, y, 30.5), Vector3.new(0.04, 0.08, 5.4), "#2A2B2E", Mat.Metal, sv), false)
		end
		decor(plain(CFrame.new(-26.93, 6.3, 29.2), Vector3.new(0.03, 0.3, 0.7), "#3CFF73", Mat.Neon, sv), false)
		box(CFrame.new(-27.4, 2.6, 21.6), Vector3.new(3.2, 0.12, 1.8), "steel", sv)
		for _, x in { -28.8, -26.0 } do
			box(CFrame.new(x, 1.3, 21.6), Vector3.new(0.12, 2.6, 1.6), "steel", sv)
		end
		local con = place("ofc_monitor", CFrame.lookAt(Vector3.new(-27.4, 2.66, 21.1), Vector3.new(-27.4, 2.66, 24)), { parent = sv, name = "Console" })
		screenOn(con, "terminal")
		place("ofc_keyboard", CFrame.lookAt(Vector3.new(-27.4, 2.66, 22.0), Vector3.new(-27.4, 2.66, 25)), { parent = sv })
		place("ofc_task_chair", CFrame.lookAt(Vector3.new(-27.0, 0, 23.6), Vector3.new(-27.4, 0, 21)) * yaw(30), { parent = sv })

		-- storage: a janitor's cart
		local st = sub("Storage")
		local cart = CFrame.new(39.6, 0, 20.8) * yaw(15)
		box(cart * CFrame.new(0, 1.6, 0), Vector3.new(1.4, 0.1, 2.4), "plastic_white", st, "#4A4C50")
		box(cart * CFrame.new(0, 2.95, 0), Vector3.new(1.4, 0.1, 2.4), "plastic_white", st, "#4A4C50")
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				box(cart * CFrame.new(sx * 0.65, 1.5, sz * 1.15), Vector3.new(0.1, 3, 0.1), "plastic_white", st, "#4A4C50")
			end
		end
		disc((cart * CFrame.new(0, 0.6, -1.9)).Position, Vector3.yAxis, 0.75, 1.2, "#D3A21F", Mat.Plastic, st)
		rod((cart * CFrame.new(0, 0.8, -1.9)).Position, (cart * CFrame.new(0.4, 5.2, -1.5)).Position, 0.07, "#7A6040", Mat.Wood, st)
		return "rooms dressed, " .. #spec.props .. " placed props"
	end

	------------------------------------------------------------------ fixtures and every light
	local COOL = Color3.fromRGB(222, 232, 255)
	local WARM = Color3.fromRGB(255, 196, 140)
	local function holder(cf, parent, name)
		local h = plain(cf, Vector3.new(0.2, 0.2, 0.2), "#FFFFFF", Mat.SmoothPlastic, parent, { Transparency = 1, Name = name or "Light" })
		return decor(h, false)
	end
	local function light(class, parent, props)
		local l = Instance.new(class)
		for k, v in props do
			l[k] = v
		end
		l.Parent = parent
		return l
	end
	local function glowText(p, face, text, color, font)
		local g = Instance.new("SurfaceGui")
		g.Face = face or Enum.NormalId.Front
		g.LightInfluence = 0
		g.Brightness = 1.4
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 200
		g.Parent = p
		local t = Instance.new("TextLabel")
		t.BackgroundColor3 = hex("#05070A")
		t.Size = UDim2.fromScale(1, 1)
		t.Text = text
		t.TextScaled = true
		t.TextColor3 = hex(color)
		t.Font = font or Enum.Font.Arcade
		t.Name = "Text"
		t.Parent = g
		return t
	end

	function phases.fixtures()
		local fx = Root.clear(id, "Lights")
		local function sub(name)
			local f = Instance.new("Model")
			f.Name = name
			f.Parent = fx
			return f
		end
		local ceilingF = sub("Ceiling")
		local lit, flick, shadowsLeft = 0, 0, 3
		for i, f in fittings() do
			if f.kind == "troffer" then
				local m = place("ofc_troffer", CFrame.new(f.x, CEIL - 0.04, f.z), { parent = ceilingF, shadow = false, name = "Troffer" })
				m:SetAttribute("State", f.state)
				if f.state ~= "dead" then
					local tubes = part(m, "tubes")
					if tubes then
						tubes.Material = Mat.Neon
						tubes.Color = Color3.fromRGB(226, 236, 255)
					end
					local refl = part(m, "reflector")
					if refl then
						refl.Material = Mat.Neon
						refl.Color = Color3.fromRGB(150, 158, 172)
					end
					local h = holder(CFrame.new(f.x, CEIL - 0.3, f.z), m, "Source")
					light("SurfaceLight", h, { Face = Enum.NormalId.Bottom, Range = 18, Brightness = 1.15, Angle = 115, Color = COOL,
						Shadows = f.state == "lit" and shadowsLeft > 0 })
					if f.state == "lit" then
						shadowsLeft -= 1
						lit += 1
					else
						flick += 1
						CollectionService:AddTag(m, "OfcFlicker")
					end
					CollectionService:AddTag(m, "OfcTrofferOn")
				end
			else
				place("ofc_diffuser", CFrame.new(f.x, CEIL - 0.03, f.z), { parent = ceilingF, shadow = false })
			end
			if i % 20 == 0 then
				task.wait()
			end
		end
		-- sprinkler heads and smoke detectors (their red LED blinks, see the director script)
		for x = -50, 50, 12 do
			for _, z in { -38, -26, -10, 4, 14 } do
				decor(disc(Vector3.new(x + 2, CEIL - 0.06, z + 1), -Vector3.yAxis, 0.12, 0.12, "#C9CBCE", Mat.Metal, ceilingF), false)
			end
		end
		for _, p in { { -46, -32 }, { -25, -32 }, { -40, 0 }, { -20, -16 }, { 6, -20 }, { 30, -30 }, { 44, -8 }, { 28, 8 }, { 24, 30 },
			{ -36, 30 }, { -18, 30 }, { 46, 30 }, { 0, 26 }, { 0, 7 } } do
			decor(disc(Vector3.new(p[1], CEIL - 0.08, p[2]), -Vector3.yAxis, 0.38, 0.16, "#ECEBE6", Mat.SmoothPlastic, ceilingF), false)
			local led = decor(disc(Vector3.new(p[1] + 0.15, CEIL - 0.17, p[2]), -Vector3.yAxis, 0.04, 0.02, "#FF2A1A", Mat.Neon, ceilingF), false)
			CollectionService:AddTag(led, "OfcBlink")
		end
		task.wait()

		-- lobby and reception downlights: one warm and steady over spawn, one failing, the rest dead
		local down = sub("Downlights")
		for _, d in { { 0, 29.5, "lit" }, { -6, 23.5, "flicker" }, { 6, 23.5, "dead" }, { -6, 9.5, "dead" }, { 6, 9.5, "dead" }, { 0, 21, "dead" } } do
			local pos = Vector3.new(d[1], CEIL - 0.03, d[2])
			disc(pos, -Vector3.yAxis, 0.45, 0.06, "#C9CBCE", Mat.Metal, down)
			local lens = disc(pos - Vector3.new(0, 0.02, 0), -Vector3.yAxis, 0.32, 0.04, d[3] == "dead" and "#8E8E8A" or "#FFE7C9",
				d[3] == "dead" and Mat.SmoothPlastic or Mat.Neon, down, { Name = "Downlight" })
			decor(lens, false)
			if d[3] ~= "dead" then
				light("SpotLight", lens, { Face = Enum.NormalId.Right, Angle = 75, Range = 16, Brightness = 1.6, Color = WARM, Shadows = true })
				if d[3] == "flicker" then
					CollectionService:AddTag(lens, "OfcFlicker")
				end
			end
		end
		-- the logo wall washer: the logo is the brightest thing you see from the elevators
		local washer = holder(CFrame.lookAt(Vector3.new(0, CEIL - 0.25, 6.4), Vector3.new(0, 6.2, 3.6)), down, "LogoWasher")
		disc(Vector3.new(0, CEIL - 0.03, 6.4), -Vector3.yAxis, 0.3, 0.06, "#C9CBCE", Mat.Metal, down)
		light("SpotLight", washer, { Face = Enum.NormalId.Front, Angle = 70, Range = 14, Brightness = 2.2, Color = WARM, Shadows = true })
		CollectionService:AddTag(washer, "OfcSoftFlicker")

		-- desk lamps left on (reception, manager): light from the lamp head
		local lamps = workspace:FindFirstChild("Map_" .. id) and Root.layer(id, "Foliage"):FindFirstChild("Placed")
		for _, m in lamps and lamps:GetChildren() or {} do
			if m.Name == "ofc_desk_lamp" then
				local head = (m:GetPivot() * CFrame.new(-0.05, 2.62, 0.67)).Position -- the scan's shade hangs over its +Z side
				local h = holder(CFrame.new(head), m, "LampLight")
				light("PointLight", h, { Range = 13, Brightness = 1.4, Color = WARM, Shadows = true })
				local bulb = plain(CFrame.new(head - Vector3.new(0, 0.12, 0)), Vector3.new(0.22, 0.22, 0.22), "#FFE2B8", Mat.Neon, m, { Shape = Enum.PartType.Ball })
				decor(bulb, false)
			end
		end

		-- red EXIT signs (and the arrows toward stair B)
		local exits = sub("Exits")
		local function exitSign(pos, faceDir, text, hanging)
			local cf = CFrame.lookAt(pos, pos + faceDir)
			local box0 = plain(cf, Vector3.new(2.0, 0.8, 0.3), "#E9E8E3", Mat.SmoothPlastic, exits, { Name = "ExitSign" })
			decor(box0, false)
			for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
				local t = glowText(box0, face, text, "#FF2B22", Enum.Font.GothamBlack)
				t.BackgroundColor3 = hex("#F4F2EC")
			end
			light("PointLight", box0, { Range = 5, Brightness = 0.35, Color = Color3.fromRGB(255, 40, 30) })
			if hanging then
				for _, sx in { -0.7, 0.7 } do
					decor(rod((cf * CFrame.new(sx, 0.4, 0)).Position, (cf * CFrame.new(sx, 0.4, 0)).Position + Vector3.new(0, CEIL - pos.Y - 0.4, 0), 0.03, "#B5B8BB", Mat.Metal, exits), false)
				end
			end
			CollectionService:AddTag(box0, "OfcExit")
		end
		exitSign(Vector3.new(-50, 8.45, 17.6), -Vector3.zAxis, "EXIT")
		exitSign(Vector3.new(-50, 8.45, 18.42), Vector3.zAxis, "EXIT")
		exitSign(Vector3.new(-24, 9.0, 13.5), Vector3.xAxis, "◄ EXIT", true)
		exitSign(Vector3.new(14, 9.0, 13.5), Vector3.xAxis, "◄ EXIT", true)
		exitSign(Vector3.new(-30, 9.0, -25), Vector3.zAxis, "EXIT ►", true)

		-- emergency twin-heads (battery units): a few still on
		for _, e in { { -54, 8.3, 17.5, -1, "lit" }, { -54, 8.3, 18.5, 1, "lit" }, { -54, -4.5, 18.5, 1, "dead" }, { -54, 19.2, 18.5, 1, "flicker" },
			{ 40, 8.3, 17.5, -1, "dead" }, { 12, 8.3, -27.25, -1, "lit" } } do
			local pos = Vector3.new(e[1], e[2], e[3])
			local m = place("ofc_emergency", CFrame.lookAt(pos, pos + Vector3.new(0, 0, e[4])), { parent = exits, shadow = false })
			local lens = part(m, "lens")
			if e[5] == "dead" and lens then
				lens.Material = Mat.SmoothPlastic
				lens.Color = hex("#9A9A94")
			elseif lens then
				local h = holder(CFrame.lookAt(pos + Vector3.new(0, 0, e[4] * 0.3), pos + Vector3.new(0, -4, e[4] * 6)), m, "Beam")
				light("SpotLight", h, { Face = Enum.NormalId.Front, Angle = 80, Range = 24, Brightness = 1.0, Color = COOL, Shadows = e[3] > 18 })
				if e[5] == "flicker" then
					CollectionService:AddTag(m, "OfcFlicker")
				end
			end
		end

		-- appliances and screens that glow
		local placed = Root.layer(id, "Foliage"):FindFirstChild("Placed")
		for _, m in placed and placed:GetChildren() or {} do
			if m.Name == "ofc_vending" then
				local g = part(m, "glass")
				if g then
					light("SurfaceLight", g, { Face = Enum.NormalId.Front, Range = 13, Brightness = 1.3, Angle = 120, Color = Color3.fromRGB(205, 225, 255) })
					CollectionService:AddTag(m, "OfcVending")
				end
				local d = part(m, "display")
				if d then
					glowText(d, Enum.NormalId.Front, "INSERT COINS", "#FF4A3A")
				end
			elseif m.Name == "ofc_microwave" then
				local d = part(m, "display")
				if d then
					CollectionService:AddTag(glowText(d, Enum.NormalId.Front, "12:00", "#38FF7C"), "OfcBlinkText")
				end
			elseif m.Name == "ofc_coffee" then
				local d = part(m, "display")
				if d then
					glowText(d, Enum.NormalId.Front, "DESCALE", "#5AB4FF", Enum.Font.Code)
				end
			elseif m.Name == "Printer" or m.Name == "ofc_printer" then
				local d = part(m, "display")
				if d then
					glowText(d, Enum.NormalId.Front, m.Name == "Printer" and "Sleep" or "Paper jam\nTray 2", "#FFB347", Enum.Font.Code)
				end
			elseif m.Name == "ofc_crt" or m.Name == "BreakTV" then
				local cf, size = m:GetBoundingBox()
				local look = cf.LookVector
				local face = cf.Position + look * (size.Z / 2 + 0.01) + Vector3.new(0, 0.14, 0)
				local scr = plain(CFrame.lookAt(face, face + look), Vector3.new(size.X * 0.66, size.Y * 0.56, 0.02), "#111111", Mat.SmoothPlastic, m,
					{ Name = "Static", CanCollide = false })
				decor(scr, false)
				local g = Instance.new("SurfaceGui")
				g.Face = Enum.NormalId.Front
				g.LightInfluence = 0
				g.Brightness = 0.9
				g.Parent = scr
				local img = Instance.new("ImageLabel")
				img.Size = UDim2.fromScale(1, 1)
				img.BackgroundColor3 = hex("#202020")
				local manifest = K.Http.json("assets.json")
				img.Image = manifest.images and manifest.images.ofc_static and manifest.images.ofc_static.id or ""
				img.ScaleType = Enum.ScaleType.Tile
				img.TileSize = UDim2.fromOffset(64, 64)
				img.Parent = g
				CollectionService:AddTag(img, "OfcStatic")
				light("PointLight", scr, { Range = 6, Brightness = 0.6, Color = Color3.fromRGB(190, 200, 215) })
			elseif m.Name == "StorageLight" then
				local h = holder(m:GetPivot() * CFrame.new(0, -0.3, 0), m, "Source")
				light("PointLight", h, { Range = 16, Brightness = 0.65, Color = COOL, Shadows = true })
				CollectionService:AddTag(m, "OfcFlicker")
			end
		end
		-- the reception monitor shows the visitor log; the server aisle glows blue
		local rec = Root.layer(id, "Landmarks"):FindFirstChild("Reception")
		local rm = rec and rec:FindFirstChild("ReceptionMonitor")
		if rm then
			screenOn(rm, "visitor")
		end
		for _, z in { 23, 31 } do
			local h = holder(CFrame.new(-36, 6.5, z), fx, "ServerGlow")
			light("PointLight", h, { Range = 12, Brightness = 0.28, Color = Color3.fromRGB(80, 140, 255) })
		end
		return ("%d troffers lit, %d flickering"):format(lit, flick)
	end

	------------------------------------------------------------------ details: wear and tear, wall furniture
	function phases.details()
		local d = Root.clear(id, "QA") -- (the kit's spare layer)
		local rng = Random.new(spec.seed + 31)
		local manifest = K.Http.json("assets.json")
		local img = manifest.images or {}
		local function decal(p, face, name, transp)
			local dc = Instance.new("Decal")
			dc.Texture = img[name] and img[name].id or ""
			dc.Face = face
			dc.Transparency = transp or 0
			dc.Parent = p
			return dc
		end
		local function patch(cf, size, name, face, transp)
			local p = plain(cf, size, "#FFFFFF", Mat.SmoothPlastic, d, { Transparency = 1, Name = "Stain" })
			decor(p, false)
			decal(p, face, name, transp)
			return p
		end
		-- water damage under the leak (break room) and where the plenum shows
		patch(CFrame.new(20, CEIL - 0.01, 22.6), Vector3.new(5, 0.02, 5), "ofc_stain_ring", Enum.NormalId.Bottom, 0.1)
		patch(CFrame.new(-40, CEIL - 0.01, -15.5), Vector3.new(4, 0.02, 4), "ofc_stain_ring", Enum.NormalId.Bottom, 0.25)
		patch(CFrame.new(31.6, CEIL - 0.01, -7.6), Vector3.new(3.4, 0.02, 3.4), "ofc_stain_ring", Enum.NormalId.Bottom, 0.3)
		patch(CFrame.lookAt(Vector3.new(55.48, 6.5, 27), Vector3.new(40, 6.5, 27)), Vector3.new(6, 7, 0.02), "ofc_stain_drip", Enum.NormalId.Front, 0.1)
		patch(CFrame.lookAt(Vector3.new(-43.73, 6.8, 30), Vector3.new(-30, 6.8, 30)), Vector3.new(4, 6, 0.02), "ofc_stain_drip", Enum.NormalId.Front, 0.4)
		-- dark patches on the carpet: one by the stair door nobody wants to talk about
		for _, s in { { -50.5, 15.6, 4.2, 0.05 }, { 30, -22, 3, 0.4 }, { -26, -6, 2.4, 0.5 }, { 8, -30, 2.6, 0.45 }, { 21, 22.4, 3.2, 0.3 } } do
			patch(CFrame.new(s[1], 0.012, s[2]) * yaw(rng:NextNumber(0, 360)), Vector3.new(s[3], 0.02, s[3] * 0.8), "ofc_stain_floor", Enum.NormalId.Top, s[4])
		end
		-- the plenum above the missing tiles: a duct, cable runs, a cable hanging down
		for _, t in MISSING_TILES do
			box(CFrame.new(t[1], 12.2, t[2] + 0.3), Vector3.new(6, 1.4, 1.6), "steel", d, "#8D9093")
			for k = 1, 3 do
				rod(Vector3.new(t[1] - 3, 11.0 + k * 0.12, t[2] - 0.8 + k * 0.2), Vector3.new(t[1] + 3, 11.1 + k * 0.1, t[2] - 0.6 + k * 0.2), 0.05, "#141416", Mat.Plastic, d)
			end
			decor(rod(Vector3.new(t[1] + 0.4, 10.6, t[2] - 0.2), Vector3.new(t[1] + 0.7, 7.4, t[2] + 0.1), 0.05, "#141416", Mat.Plastic, d), true)
		end
		-- one tile hanging down by a corner
		box(CFrame.new(-40.4, 9.0, -18.9) * CFrame.Angles(math.rad(55), math.rad(10), 0), Vector3.new(2.2, 0.12, 2.2), "ceiling", d)
		-- a trail of pages from the conference room to the stair door
		local path = { Vector3.new(-19, 0, -26), Vector3.new(-22, 0, -20), Vector3.new(-30, 0, -14), Vector3.new(-34, 0, -2), Vector3.new(-34, 0, 12), Vector3.new(-44, 0, 14.5), Vector3.new(-50, 0, 16.5) }
		for i = 1, #path - 1 do
			for k = 0, 4 do
				local p = path[i]:Lerp(path[i + 1], k / 5) + Vector3.new(rng:NextNumber(-1.2, 1.2), 0.02 + rng:NextNumber(0, 0.01), rng:NextNumber(-1.2, 1.2))
				decor(plain(CFrame.new(p) * yaw(rng:NextNumber(0, 360)) * CFrame.Angles(math.rad(rng:NextNumber(-3, 3)), 0, 0),
					Vector3.new(0.75, 0.01, 1.05), "#ECEAE3", Mat.SmoothPlastic, d), false)
			end
		end
		-- outlets and switches by the doors and along walls
		local function plate(pos, faceDir, h)
			local cf = CFrame.lookAt(pos + Vector3.new(0, h, 0), pos + Vector3.new(0, h, 0) + faceDir)
			decor(plain(cf, Vector3.new(0.3, 0.45, 0.04), "#ECEBE6", Mat.SmoothPlastic, d), false)
		end
		for _, s in { { -47.4, 17.73, -1 }, { -33.4, 17.73, -1 }, { -15.4, 17.73, -1 }, { 48.6, 17.73, -1 }, { -38.4, -27.73, 1 }, { 21, 18.27, 1 } } do
			plate(Vector3.new(s[1], 0, s[2]), Vector3.new(0, 0, s[3]), 4.2)
			plate(Vector3.new(s[1] - 3, 0, s[2]), Vector3.new(0, 0, s[3]), 1.1)
		end
		-- posters and the evacuation plan
		sign(CFrame.lookAt(Vector3.new(-47.0, 5.2, 17.72), Vector3.new(-47.0, 5.2, 0)), Vector3.new(2.2, 3.0, 0.04), {
			{ text = "EVACUATION PLAN — FLOOR 14", h = 0.1, color = "#FFFFFF", font = Enum.Font.GothamBold },
			{ text = "YOU ARE HERE ●\n\nUse STAIR B.\nDo not use the lifts.\nAssemble on Harbour St.", h = 0.6, color = "#E8F0E8", font = Enum.Font.Gotham },
		}, { bg = "#1E6B3A", name = "Evacuation" }, d)
		sign(CFrame.lookAt(Vector3.new(35.72, 5.6, 27.5), Vector3.new(20, 5.6, 27.5)), Vector3.new(0.04 + 2.0, 2.8, 0.04), {
			{ text = "TEAMWORK", h = 0.2, y = 0.58, color = "#F1E9D0", font = Enum.Font.Garamond },
			{ text = "Together, nobody leaves alone.", h = 0.09, color = "#C9C1A8", font = Enum.Font.Garamond },
		}, { bg = "#1B1E24", name = "Poster" }, d)
		for _, rs in { { -36, "SERVER — AUTHORISED ONLY", "#B3261E" }, { -18, "PRINT", "#222222" }, { 46, "STORAGE", "#222222" }, { -50, "STAIR B", "#1F4F8F" } } do
			sign(CFrame.lookAt(Vector3.new(rs[1] + 3.2, 5.6, 17.72), Vector3.new(rs[1] + 3.2, 5.6, 0)), Vector3.new(1.8, 0.6, 0.04), {
				{ text = rs[2], h = 0.8, y = 0.1, color = rs[3], font = Enum.Font.GothamBold },
			}, { bg = "#E5E3DC", name = "DoorSign" }, d)
		end
		-- keypad by the server door
		decor(plain(CFrame.new(-33.0, 4.0, 17.7), Vector3.new(0.35, 0.55, 0.08), "#1E1F22", Mat.SmoothPlastic, d), false)
		local kl = decor(plain(CFrame.new(-33.0, 4.18, 17.65), Vector3.new(0.08, 0.08, 0.02), "#FF2A1A", Mat.Neon, d), false)
		CollectionService:AddTag(kl, "OfcBlink")
		return "stains, plenum, page trail, plates, signs"
	end

	------------------------------------------------------------------ the city 14 floors down, and the rain
	local GROUND = -150
	function phases.city()
		local c = Root.clear(id, "Terrain") -- (no terrain in this map: the layer holds the city)
		local rng = Random.new(spec.seed + 41)
		local manifest = K.Http.json("assets.json")
		local img = manifest.images or {}
		local facades = { img.ofc_facade_office and img.ofc_facade_office.id, img.ofc_facade_glass and img.ofc_facade_glass.id, img.ofc_facade_resi and img.ofc_facade_resi.id }
		plain(CFrame.new(0, GROUND - 1, 0), Vector3.new(4000, 2, 4000), "#0B0C0E", Mat.Asphalt, c, { Name = "Street" })
		-- sodium street lamps along a grid of streets
		for s = -480, 480, 120 do
			for t = -900, 900, 40 do
				for _, pos in { Vector3.new(s + 9, GROUND + 9, t), Vector3.new(t, GROUND + 9, s + 9) } do
					if pos.Magnitude > 90 then
						decor(plain(CFrame.new(pos), Vector3.new(1.6, 0.8, 1.6), "#FF9A45", Mat.Neon, c), false)
					end
				end
			end
			task.wait()
		end
		-- towers: dark blocks with lit-window facades (SurfaceGuis that ignore the scene's light)
		local faces = { { Enum.NormalId.Front, Vector3.new(0, 0, -1) }, { Enum.NormalId.Back, Vector3.new(0, 0, 1) },
			{ Enum.NormalId.Left, Vector3.new(-1, 0, 0) }, { Enum.NormalId.Right, Vector3.new(1, 0, 0) } }
		local made = 0
		local tries = 0
		local placed = {}
		while made < 44 and tries < 400 do
			tries += 1
			local ang = rng:NextNumber(0, 2 * math.pi)
			local dist = rng:NextNumber(115, 700)
			local pos = Vector3.new(math.cos(ang) * dist, 0, math.sin(ang) * dist)
			local w, dd = rng:NextNumber(34, 85), rng:NextNumber(34, 85)
			local ok = pos.Z < 60 or math.abs(pos.X) > 160 -- the core (south) has no windows: build there sparsely
			for _, q in placed do
				if (q - pos).Magnitude < 70 then
					ok = false
				end
			end
			if ok then
				table.insert(placed, pos)
				made += 1
				local top = GROUND + rng:NextNumber(90, dist < 250 and 240 or 360)
				local b = plain(CFrame.new(pos.X, (GROUND + top) / 2, pos.Z), Vector3.new(w, top - GROUND, dd), "#121418", Mat.Concrete, c, { Name = "Tower", CastShadow = false })
				b.CanCollide = false
				local image = facades[rng:NextInteger(1, 3)]
				for _, f in faces do
					if f[2]:Dot(-pos.Unit) > -0.25 and image then
						local g = Instance.new("SurfaceGui")
						g.Face = f[1]
						g.LightInfluence = 0
						g.Brightness = rng:NextNumber(0.55, 0.95)
						g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
						g.PixelsPerStud = 2
						g.Parent = b
						local il = Instance.new("ImageLabel")
						il.Size = UDim2.fromScale(1, 1)
						il.BackgroundTransparency = 1
						il.Image = image
						il.ScaleType = Enum.ScaleType.Tile
						local tile = rng:NextInteger(150, 210)
						il.TileSize = UDim2.fromOffset(tile, tile)
						il.ImageColor3 = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(255, 220, 190), rng:NextNumber(0, 0.4))
						il.Parent = g
					end
				end
				if top > 60 and rng:NextNumber() < 0.6 then
					local beacon = decor(plain(CFrame.new(pos.X, top + 1.5, pos.Z), Vector3.new(1.4, 1.4, 1.4), "#FF1A12", Mat.Neon, c, { Shape = Enum.PartType.Ball, Name = "Beacon" }), false)
					CollectionService:AddTag(beacon, "OfcBeacon")
				end
				if made % 8 == 0 then
					task.wait()
				end
			end
		end
		-- across the street to the east: one floor still lit at our height, and someone standing at the glass
		local nb = plain(CFrame.new(140, (GROUND + 120) / 2, -12), Vector3.new(60, 120 - GROUND, 76), "#14161A", Mat.Concrete, c, { Name = "Neighbour", CastShadow = false })
		nb.CanCollide = false
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Left
		g.LightInfluence = 0
		g.Brightness = 0.7
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 2
		g.Parent = nb
		local il = Instance.new("ImageLabel")
		il.Size = UDim2.fromScale(1, 1)
		il.BackgroundTransparency = 1
		il.Image = facades[1] or ""
		il.ScaleType = Enum.ScaleType.Tile
		il.TileSize = UDim2.fromOffset(180, 180)
		il.Parent = g
		local window = plain(CFrame.new(109.9, 4.6, -16), Vector3.new(0.2, 7.2, 18), "#6E5C46", Mat.Neon, c, { Name = "LitFloor" })
		decor(window, false)
		local fig = Instance.new("Model")
		fig.Name = "Watcher"
		local base = Vector3.new(109.5, 0.5, -14)
		plain(CFrame.new(base + Vector3.new(0, 2.0, 0)), Vector3.new(0.5, 3.2, 1.7), "#020202", Mat.SmoothPlastic, fig)
		plain(CFrame.new(base + Vector3.new(0, 4.25, 0)), Vector3.new(0.9, 1.05, 0.95), "#020202", Mat.SmoothPlastic, fig, { Shape = Enum.PartType.Ball })
		for _, sz in { -1, 1 } do
			plain(CFrame.new(base + Vector3.new(0, 1.75, sz * 1.05)) * CFrame.Angles(math.rad(sz * 4), 0, 0), Vector3.new(0.4, 3.0, 0.4), "#020202", Mat.SmoothPlastic, fig)
			plain(CFrame.new(base + Vector3.new(0, -0.3, sz * 0.45)), Vector3.new(0.45, 2.4, 0.5), "#020202", Mat.SmoothPlastic, fig)
		end
		Build.decor(fig)
		CollectionService:AddTag(fig, "OfcWatcher")
		fig.Parent = c
		-- rain falling past the glass on all three window sides
		local streak = img.ofc_rain_streak and img.ofc_rain_streak.id or ""
		for _, r in { { CFrame.new(0, 28, -52), Vector3.new(140, 1, 14) }, { CFrame.new(64, 28, -14), Vector3.new(14, 1, 80) }, { CFrame.new(-64, 28, -14), Vector3.new(14, 1, 80) } } do
			local p = plain(r[1], r[2], "#FFFFFF", Mat.SmoothPlastic, c, { Transparency = 1, Name = "RainEmitter" })
			decor(p, false)
			local e = Instance.new("ParticleEmitter")
			e.Texture = streak
			e.EmissionDirection = Enum.NormalId.Bottom
			e.Rate = 520
			e.Lifetime = NumberRange.new(0.9, 1.25)
			e.Speed = NumberRange.new(95, 120)
			e.SpreadAngle = Vector2.new(3, 3)
			e.Acceleration = Vector3.new(r[2].X > 20 and 0 or (r[1].X > 0 and -6 or 6), 0, r[2].X > 20 and 6 or 0)
			e.Size = NumberSequence.new(0.14)
			e.Squash = NumberSequence.new(2.4)
			e.Orientation = Enum.ParticleOrientation.VelocityParallel
			e.Transparency = NumberSequence.new(0.35)
			e.Color = ColorSequence.new(Color3.fromRGB(170, 180, 195))
			e.LightInfluence = 0.75
			e.LightEmission = 0.1
			e.Parent = p
		end
		return ("%d towers, street lamps, a lit floor across the street, rain"):format(made)
	end

	------------------------------------------------------------------ night, storm, sky
	function phases.lighting()
		local failures = K.Lighting.preset("night")
		local L = game:GetService("Lighting")
		L.Brightness = 0.9 -- the moon behind storm cloud (lightning spikes it)
		L.Ambient = Color3.fromRGB(30, 32, 40)
		L.OutdoorAmbient = Color3.fromRGB(86, 90, 108)
		L.ExposureCompensation = 0.6
		L.EnvironmentDiffuseScale = 0.35
		L.EnvironmentSpecularScale = 0.7
		L.ShadowSoftness = 0.25
		local atm = L:FindFirstChildOfClass("Atmosphere")
		if atm then
			atm.Density = 0.12 -- thicker swallows the skyline
			atm.Offset = 0
			atm.Color = Color3.fromRGB(110, 92, 80)
			atm.Decay = Color3.fromRGB(60, 52, 50)
			atm.Haze = 0.6
			atm.Glare = 0
		end
		local cc = L:FindFirstChildOfClass("ColorCorrectionEffect")
		if cc then
			cc.Brightness = 0
			cc.Contrast = 0.12
			cc.Saturation = -0.28
			cc.TintColor = Color3.fromRGB(226, 232, 255)
		end
		local bloom = L:FindFirstChildOfClass("BloomEffect")
		if bloom then
			bloom.Intensity = 0.75
			bloom.Size = 30
			bloom.Threshold = 1.05
		end
		local ok, err = pcall(K.Sky.apply, "ofc_sky")
		L:SetAttribute("OfcBaseBrightness", L.Brightness)
		L:SetAttribute("OfcBaseExposure", L.ExposureCompensation)
		L:SetAttribute("OfcBaseOutdoor", L.OutdoorAmbient)
		return ("storm night%s%s"):format(#failures > 0 and (" (" .. table.concat(failures, "; ") .. ")") or "", ok and ", sky ofc_sky" or (", sky failed: " .. tostring(err)))
	end

	------------------------------------------------------------------ sound
	function phases.ambience()
		local manifest = K.Http.json("assets.json")
		local snd = manifest.sounds or {}
		local S = spec.sounds
		local layer = Root.clear(id, "Sounds")
		local function sid(key)
			local e = snd[S[key]]
			return e and e.id
		end
		local missing = {}
		for _, k in { "rain", "hvac", "server", "vending", "hum", "sfx" } do
			if not sid(k) then
				table.insert(missing, S[k])
			end
		end
		if #missing > 0 then
			return "sounds missing: run `python maps/office-floor-14/sounds.py --only " .. table.concat(missing, ",") .. "`"
		end
		K.Sound.ambience(id, "RoomTone", sid("hvac"), { volume = 0.32 })
		K.Sound.ambience(id, "RainBed", sid("rain"), { volume = 0.1 })
		local function emitter(name, pos, key, vol, minD, maxD, speed)
			local p = plain(CFrame.new(pos), Vector3.new(0.4, 0.4, 0.4), "#FFFFFF", Mat.SmoothPlastic, layer, { Transparency = 1, Name = name })
			decor(p, false)
			local s = Instance.new("Sound")
			s.Name = name
			s.SoundId = sid(key)
			s.Looped = true
			s.Volume = vol
			s.PlaybackSpeed = speed or 1
			s.RollOffMode = Enum.RollOffMode.InverseTapered
			s.RollOffMinDistance = minD
			s.RollOffMaxDistance = maxD
			s.Playing = true
			s.Parent = p
			return s
		end
		local rng = Random.new(spec.seed + 51)
		for _, p in { { -42, -43 }, { -14, -43 }, { 14, -43 }, { 42, -43 }, { 55, -30 }, { 55, -2 }, { -55, -30 }, { -55, -2 } } do
			local s = emitter("Rain", Vector3.new(p[1], 6, p[2]), "rain", 0.55, 6, 42, rng:NextNumber(0.94, 1.06))
			s.TimePosition = rng:NextNumber(0, 25)
		end
		emitter("Servers", Vector3.new(-36, 4, 27), "server", 0.9, 7, 46)
		emitter("Vending", Vector3.new(33.4, 3, 22.6), "vending", 0.45, 4, 26)
		emitter("TVStatic", Vector3.new(13.2, 7.2, 19.3), "rain", 0.09, 2, 14, 2.4)
		emitter("TVStatic", Vector3.new(3.4, 3.4, 12.0), "rain", 0.07, 2, 12, 2.4)
		local hums = 0
		for _, m in CollectionService:GetTagged("OfcTrofferOn") do
			if m:IsDescendantOf(workspace) and hums < 10 then
				hums += 1
				local s = emitter("Hum", m:GetPivot().Position - Vector3.new(0, 0.5, 0), "hum", 0.16, 3, 22, rng:NextNumber(0.97, 1.03))
				s.Parent.Parent = m
			end
		end
		K.Sound.reverb(S.reverb)
		game:GetService("SoundService").DistanceFactor = 3.57 -- studs per metre for this map (1 stud = 0.28 m)
		return ("room tone, rain (2D + 8 emitters), servers, vending, %d ballast hums, reverb %s"):format(hums, S.reverb)
	end

	------------------------------------------------------------------ scripts: doors, the player, the director
	function phases.scripts()
		local RS = game:GetService("ReplicatedStorage")
		local SP = game:GetService("StarterPlayer")
		local manifest = K.Http.json("assets.json")
		local snd = manifest.sounds or {}
		local sfx = snd[spec.sounds.sfx]
		-- shared config for the client and server scripts
		local folder = RS:FindFirstChild("Office14") or Instance.new("Folder")
		folder.Name = "Office14"
		folder.Parent = RS
		for _, ch in folder:GetChildren() do
			ch:Destroy()
		end
		local lines = { "-- generated by maps/office-floor-14/build.luau (scripts phase): asset ids for the scripts", "return {" }
		table.insert(lines, ('\tsfx = %q,'):format(sfx and sfx.id or ""))
		table.insert(lines, "\tregions = {")
		for name, r in (sfx and sfx.regions or {}) do
			table.insert(lines, ("\t\t[%q] = { %s, %s },"):format(name, tostring(r[1]), tostring(r[2])))
		end
		table.insert(lines, "\t},")
		table.insert(lines, ('\tmap = %q,'):format("Map_" .. id))
		table.insert(lines, "}")
		local cfg = Instance.new("ModuleScript")
		cfg.Name = "Config"
		cfg.Source = table.concat(lines, "\n")
		cfg.Parent = folder
		local ev = Instance.new("RemoteEvent")
		ev.Name = "Event"
		ev.Parent = folder
		-- the scripts themselves come from maps/office-floor-14/scripts/
		local function install(parent, class, name, file)
			local old = parent:FindFirstChild(name)
			if old then
				old:Destroy()
			end
			local s = Instance.new(class)
			s.Name = name
			s.Source = K.Http.get("maps/" .. id .. "/scripts/" .. file)
			s.Parent = parent
			return s
		end
		local scripts = Root.clear(id, "Scripts")
		install(scripts, "Script", "Office14Server", "server.luau")
		install(SP:FindFirstChildOfClass("StarterPlayerScripts"), "LocalScript", "Office14Player", "player.luau")
		install(SP:FindFirstChildOfClass("StarterPlayerScripts"), "LocalScript", "Office14Director", "director.luau")
		SP.CameraMode = Enum.CameraMode.LockFirstPerson
		SP.CameraMaxZoomDistance = 0.5
		SP.CharacterWalkSpeed = 10
		SP.CharacterJumpHeight = 4
		SP.EnableMouseLockOption = false
		return "config, remote, server script, player + director local scripts, first person"
	end

	function phases.all()
		local out = {}
		for _, name in { "materials", "models", "shell", "facade", "core", "stairs", "office", "rooms", "fixtures", "details", "city", "lighting", "ambience", "scripts" } do
			table.insert(out, name .. ": " .. tostring(phases[name]()))
			task.wait()
		end
		return table.concat(out, "\n")
	end

	return phases
end
