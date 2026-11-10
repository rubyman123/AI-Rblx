-- Map checks: validator, walk test (PathfindingService, works in Edit mode), text report. Method by fwjelaa (FWJ STUDIOS).

local QA = {}

local DEFAULT_GREY = Color3.fromRGB(163, 162, 165)

local function close(a, b)
	return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 0.01
end

local function note(bucket, kind, example)
	local e = bucket[kind]
	if not e then
		e = { count = 0, examples = {} }
		bucket[kind] = e
	end
	e.count += 1
	if #e.examples < 3 then
		table.insert(e.examples, example)
	end
end

function QA.validate(root, opts)
	opts = opts or {}
	local floorY = opts.floorY or -30
	local r = { errors = {}, warnings = {}, stats = { parts = 0, meshParts = 0, lights = 0, shadowLights = 0, decalsTextures = 0, surfaceGuis = 0 } }
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			r.stats.parts += 1
			if d:IsA("MeshPart") then
				r.stats.meshParts += 1
			end
			local name = d:GetFullName()
			if not d.Anchored then
				note(r.errors, "unanchored part", name)
			end
			if d.Position.Y < floorY then
				note(r.errors, "part below the floor", name)
			end
			local textured = d:FindFirstChildOfClass("SurfaceAppearance") ~= nil -- its colour comes from the maps
			if d.Material == Enum.Material.Plastic and close(d.Color, DEFAULT_GREY) and d.Transparency < 1 and not textured then
				note(r.warnings, "default grey Plastic", name)
			end
			if d:GetAttribute("MapKit_NoColor") and d.Transparency < 1 then
				note(r.errors, "kit part left default grey (no Color)", name)
			end
			local s = d.Size
			if not d.CanCollide and d.CastShadow and math.max(s.X, s.Y, s.Z) < 4 and d.Transparency < 1 then
				note(r.warnings, "small decor part casts a shadow", name)
			end
		elseif d:IsA("Light") then
			r.stats.lights += 1
			if d.Shadows then
				r.stats.shadowLights += 1
			end
		elseif d:IsA("Decal") or d:IsA("Texture") then
			r.stats.decalsTextures += 1
		elseif d:IsA("SurfaceGui") then
			r.stats.surfaceGuis += 1
		end
	end
	return r
end

QA.PathfindingService = game:GetService("PathfindingService") -- a field so tests can stand in for it

function QA.walk(from, pois, agent)
	local out = {}
	for _, poi in pois do
		local path = QA.PathfindingService:CreatePath(agent or { AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 6 })
		local ok, err = pcall(path.ComputeAsync, path, from, poi.pos)
		if ok and path.Status == Enum.PathStatus.NoPath then
			-- the navmesh can lag right after a build; one retry stops a false WALK FAIL
			task.wait(0.5)
			ok, err = pcall(path.ComputeAsync, path, from, poi.pos)
		end
		local wps = ok and path:GetWaypoints() or {}
		local length, jumps = 0, 0
		for i, w in wps do
			if i > 1 then
				length += (w.Position - wps[i - 1].Position).Magnitude
			end
			if w.Action == Enum.PathWaypointAction.Jump then
				jumps += 1
			end
		end
		local last = wps[#wps]
		local reached = ok and path.Status == Enum.PathStatus.Success and last ~= nil and (last.Position - poi.pos).Magnitude < 8
		table.insert(out, { name = poi.name, ok = reached, status = ok and path.Status.Name or tostring(err), length = math.floor(length), jumps = jumps })
	end
	return out
end

function QA.report(v, walk)
	local lines = {}
	local function section(title, bucket)
		local kinds = {}
		for k in bucket do
			table.insert(kinds, k)
		end
		table.sort(kinds)
		for _, k in kinds do
			table.insert(lines, ("%s %s x%d (e.g. %s)"):format(title, k, bucket[k].count, table.concat(bucket[k].examples, "; ")))
		end
	end
	local s = v.stats
	table.insert(lines, ("parts %d (mesh %d), lights %d (%d with shadows), decals/textures %d, surface guis %d")
		:format(s.parts, s.meshParts, s.lights, s.shadowLights, s.decalsTextures, s.surfaceGuis))
	section("ERROR", v.errors)
	section("WARN", v.warnings)
	local errs, unreachable = 0, 0
	for _, e in v.errors do
		errs += e.count
	end
	for _, w in walk or {} do
		table.insert(lines, ("WALK %s %s (%s, %d studs, %d jumps)"):format(w.ok and "ok  " or "FAIL", w.name, w.status, w.length, w.jumps))
		if not w.ok then
			unreachable += 1
		end
	end
	for _, w in walk or {} do
		if not w.ok and w.status == "NoPath" then
			-- measured: pathfinding sometimes misses a fresh build for seconds, then finds the same path
			table.insert(lines, "NOTE NoPath can be a pathfinding hiccup right after a build: run K.qa again before changing the map")
			break
		end
	end
	table.insert(lines, 1, (errs == 0 and unreachable == 0) and "QA PASS" or ("QA FAIL: %d errors, %d unreachable"):format(errs, unreachable))
	return table.concat(lines, "\n")
end

return QA
