-- CC0 models (made by `run.py model`) as cached templates you clone into a map. Method by fwjelaa (FWJ STUDIOS).
-- Measured 2026-10-24: InsertService:LoadAsset works from execute_luau for the user's own Model uploads, and a
-- prepped GLB arrives unanchored, unrotated, with the group's bottom-centre at the origin.
local AssetService = game:GetService("AssetService")
local InsertService = game:GetService("InsertService")
local ServerStorage = game:GetService("ServerStorage")
local Http = require(script.Parent.Http)

local Models = {}

Models.loader = function(id) -- a field so tests can stand in for InsertService
	return InsertService:LoadAsset(id)
end

-- Setting MeshPart.CollisionFidelity from execute_luau is silently ignored (measured); a part made by
-- CreateMeshPartAsync with the fidelity, applied with ApplyMesh, sets it and keeps the SurfaceAppearance.
Models.setFidelity = function(part, fidelity) -- a field so tests can stand in for it
	if part.MeshId == "" then
		return -- no mesh, nothing to rebuild collision from
	end
	local made = AssetService:CreateMeshPartAsync(Content.fromUri(part.MeshId), { CollisionFidelity = fidelity })
	part:ApplyMesh(made)
	made:Destroy()
end

local FIDELITY = { Box = Enum.CollisionFidelity.Box, Hull = Enum.CollisionFidelity.Hull, Default = Enum.CollisionFidelity.Default }

-- asset loads can stall while Studio is in the background (measured for PreloadAsync); never let one hang the
-- execute_luau call: run it in its own thread and give up after Models.timeout seconds
Models.timeout = 45

local function within(seconds, fn, ...)
	local args = table.pack(...)
	local done, ok, res = false, nil, nil
	task.spawn(function()
		ok, res = pcall(fn, table.unpack(args, 1, args.n))
		done = true
	end)
	local t0 = os.clock()
	while not done and os.clock() - t0 < seconds do
		task.wait(0.05)
	end
	if not done then
		return false, "timeout"
	end
	return ok, res
end

-- leaf and grass cards (MeshParts named Leaves*, from kit/blender leafy_tree.py/clump.py)
local function isLeaf(part)
	return part:IsA("MeshPart") and part.Name:sub(1, 6) == "Leaves"
end

-- returns how many mesh parts kept Default collision because the rebuild failed or stalled; leaf cards never
-- collide (a pine's Hull leaves were an invisible cone ~38 studs wide)
local function setCollision(model, collision, from)
	local skipped = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and not isLeaf(d) then
			local on = collision ~= "none"
			d.CanCollide, d.CanQuery, d.CanTouch = on, on, on
			if on and d:IsA("MeshPart") and collision ~= from and FIDELITY[collision] then
				local ok = within(Models.timeout, Models.setFidelity, d, FIDELITY[collision])
				if not ok then
					skipped += 1
				end
			end
		end
	end
	return skipped
end

local function cache()
	local c = ServerStorage:FindFirstChild("MapKit_Assets")
	if not c then
		c = Instance.new("Folder")
		c.Name = "MapKit_Assets"
		c.Parent = ServerStorage
	end
	return c
end

local function remake(name, m)
	if m and m.remake then
		return m.remake -- the exact command that made it (run.py records it)
	end
	local cmd = ("python kit/tools/run.py model %s --from %s"):format(name, m and m.source or "polyhaven:<id>")
	if m and m.collision then
		cmd ..= " --collision " .. m.collision
	end
	return cmd
end

local function assetNumber(id)
	return tonumber(tostring(id):match("(%d+)$"))
end

local CORNERS = {
	Vector3.new(-1, -1, -1), Vector3.new(1, 1, 1), Vector3.new(-1, 1, -1), Vector3.new(1, -1, 1),
	Vector3.new(-1, -1, 1), Vector3.new(1, 1, -1), Vector3.new(-1, 1, 1), Vector3.new(1, -1, -1),
}

-- the world-axis bottom-centre of some parts
local function bottomCentre(parts)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, d in parts do
		for _, s in CORNERS do
			local p = d.CFrame:PointToWorldSpace(d.Size / 2 * s)
			lo, hi = lo:Min(p), hi:Max(p)
		end
	end
	return CFrame.new((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2)
end

-- the template's parts from -X to +X: Poly Haven ground-cover files hold several variants side by side
local function sortedParts(tpl)
	local list = {}
	for _, d in tpl:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	table.sort(list, function(a, b)
		if math.abs(a.Position.X - b.Position.X) > 1e-3 then
			return a.Position.X < b.Position.X
		end
		if math.abs(a.Position.Z - b.Position.Z) > 1e-3 then
			return a.Position.Z < b.Position.Z
		end
		return a.Name < b.Name
	end)
	return list
end

-- leaf cards must be see-through (the importer leaves an Overlay SurfaceAppearance or only a TextureID, which
-- draws the cut-outs black, measured) and must not collide. Safe to run again on a treated part. Returns false
-- for a leaf part with no texture at all (it can only draw opaque).
local function seeThrough(part)
	if not isLeaf(part) then
		return true
	end
	part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
	local sa = part:FindFirstChildOfClass("SurfaceAppearance")
	if not sa and part.TextureID ~= "" then
		sa = Instance.new("SurfaceAppearance")
		sa.ColorMap = part.TextureID
		part.TextureID = ""
		sa.Parent = part
	end
	if sa then
		sa.AlphaMode = Enum.AlphaMode.Transparency
	end
	return sa ~= nil
end

-- treats every leaf part of a template; returns the names of those that couldn't be made see-through
local function treatLeaves(tpl, bad)
	for _, d in tpl:GetDescendants() do
		if d:IsA("BasePart") and not seeThrough(d) then
			table.insert(bad, ("%s: %s has no texture (its leaves draw opaque; re-make the model)"):format(tpl.Name, d.Name))
		end
	end
end

-- every part straight under one Model, anchored, pivot at the bottom-centre of the group
local function template(name, asset, entry)
	local tpl = Instance.new("Model")
	tpl.Name = name
	local parts = {}
	for _, d in asset:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.Parent = tpl
			table.insert(parts, d)
		end
	end
	asset:Destroy()
	if #parts == 0 then
		error(("Models.install: asset for %q has no parts"):format(name), 3)
	end
	tpl.WorldPivot = bottomCentre(parts)
	tpl:SetAttribute("Skipped", setCollision(tpl, entry.collision or "Box", "Default"))
	tpl:SetAttribute("Collision", entry.collision or "Box")
	tpl:SetAttribute("AssetId", entry.id)
	tpl:SetAttribute("Source", entry.source or "")
	return tpl
end

function Models.install(names, manifestPath)
	manifestPath = manifestPath or "assets.json"
	local manifest = Http.json(manifestPath)
	local entries = manifest.models or {}
	-- check them all first and list every problem at once (a fresh pack has no ids at all)
	local problems = {}
	for _, name in names do
		local m = entries[name]
		if not m then
			table.insert(problems, ("no model %q in %s: `%s`"):format(name, manifestPath, remake(name, nil)))
		elseif not (m.id and assetNumber(m.id)) then
			table.insert(problems, ("%q has no uploaded id yet: `%s`"):format(name, remake(name, m)))
		end
	end
	if #problems > 0 then
		error(("Models.install: %d model(s) to make first (with a key each command uploads; without one, import the .glb it writes with Studio's File > Import 3D, publish it, then `python kit/tools/run.py record-model <name> rbxassetid://...`):\n%s")
			:format(#problems, table.concat(problems, "\n")), 2)
	end
	local c = cache()
	local skipped, bad = 0, {}
	for _, name in names do
		local entry = entries[name]
		local old = c:FindFirstChild(name)
		if old and old:GetAttribute("AssetId") ~= entry.id then
			old:Destroy() -- remade since (a QA fix): load the new upload
			old = nil
		end
		if not old then
			local ok, asset = within(Models.timeout, Models.loader, assetNumber(entry.id))
			if not ok then
				error(asset == "timeout"
					and ("Models.install: loading %q (%s) did not finish in %ds. New assets only load while Studio is in front and not minimized: bring it forward and run this phase again."):format(name, entry.id, Models.timeout)
					or ("Models.install: loading %q (%s) failed: %s. Is it uploaded by the place's owner (run.py check)?"):format(name, entry.id, tostring(asset)), 2)
			end
			old = template(name, asset, entry)
			skipped += old:GetAttribute("Skipped") or 0
			old.Parent = c
		end
		treatLeaves(old, bad) -- reused templates too: one cached before a kit update may be untreated
	end
	local notes = {}
	if skipped > 0 then
		table.insert(notes, ("%d mesh part(s) kept Default collision (the collision rebuild stalled; is Studio in front?)"):format(skipped))
	end
	for _, line in bad do
		table.insert(notes, line)
	end
	return names, #notes > 0 and table.concat(notes, "; ") or "ok"
end

function Models.variants(name)
	local tpl = cache():FindFirstChild(name)
	assert(tpl, ("Models.variants: %q is not installed; call K.Models.install({%q}) first"):format(name, name))
	return #sortedParts(tpl)
end

function Models.place(name, cframe, opts)
	opts = opts or {}
	local tpl = cache():FindFirstChild(name)
	assert(tpl, ("Models.place: %q is not installed; call K.Models.install({%q}) first"):format(name, name))
	local m
	if opts.variant then
		local list = sortedParts(tpl)
		local part = list[opts.variant]
		assert(part, ("Models.place: %q has %d variants, not %s"):format(name, #list, tostring(opts.variant)))
		m = Instance.new("Model")
		m.Name = name
		local c = part:Clone()
		c.Parent = m
		m.WorldPivot = bottomCentre({ c })
		for k, v in tpl:GetAttributes() do
			m:SetAttribute(k, v)
		end
	else
		m = tpl:Clone()
	end
	if opts.scale and opts.scale ~= 1 then
		m:ScaleTo(opts.scale)
	end
	m:PivotTo(cframe)
	local from = tpl:GetAttribute("Collision") or "Box"
	local collision = opts.collision or from
	if collision ~= from then
		setCollision(m, collision, from) -- stalls are skipped (Default collision), never a hang
	end
	local tint = opts.tint
	if typeof(tint) == "string" then
		tint = Color3.fromHex(tint)
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CastShadow = opts.shadow ~= false
		elseif tint and d:IsA("SurfaceAppearance") then
			d.Color = tint -- darkens/warms a scan that reads too light in the scene
		end
	end
	if opts.name then
		m.Name = opts.name
	end
	m.Parent = opts.parent
	return m
end

return Models
