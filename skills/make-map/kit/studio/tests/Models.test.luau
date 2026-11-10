-- Tests for MapKit.Models (a fake loader stands in for InsertService). Method by fwjelaa (FWJ STUDIOS).
local SS = game:GetService("ServerStorage")
local MS = game:GetService("MaterialService")

-- what LoadAsset returns for a prepped GLB: an outer Model > Model > Model > parts, unanchored, the group's
-- bottom-centre at the origin (measured 2026-10-24)
local function fakeAsset()
	local outer = Instance.new("Model")
	local inner = Instance.new("Model")
	inner.Name = "chair (CC0)"
	inner.Parent = outer
	local node = Instance.new("Model")
	node.Name = "Chair_Node"
	node.Parent = inner
	local seat = Instance.new("Part")
	seat.Name = "Seat"
	seat.Size = Vector3.new(2, 2, 2)
	seat.Position = Vector3.new(0, 1, 0)
	seat.Anchored = false
	seat.Parent = node
	local back = Instance.new("Part")
	back.Name = "Back"
	back.Size = Vector3.new(2, 1, 0.5)
	back.Position = Vector3.new(0, 2.5, 1.25) -- sticks out behind: group z -1..1.5
	back.Anchored = false
	back.Parent = node
	local mesh = Instance.new("MeshPart")
	mesh.Name = "Mesh"
	mesh.Size = Vector3.new(1, 1, 1)
	mesh.Position = Vector3.new(0, 0.5, 0)
	Instance.new("SurfaceAppearance").Parent = mesh
	mesh.Parent = node
	return outer
end

local function withLoader(K, fn)
	local real = K.Models.loader
	local calls = 0
	K.Models.loader = function(id)
		calls += 1
		return fakeAsset()
	end
	local cache = SS:FindFirstChild("MapKit_Assets")
	local old = cache and cache:FindFirstChild("kit_test_model")
	if old then
		old:Destroy()
	end
	local ok, err = pcall(fn, function()
		return calls
	end)
	K.Models.loader = real
	cache = SS:FindFirstChild("MapKit_Assets")
	local made = cache and cache:FindFirstChild("kit_test_model")
	if made then
		made:Destroy()
	end
	if not ok then
		error(err, 0)
	end
end

return {
	["install makes an anchored template with its pivot at the bottom-centre"] = function(t, K)
		withLoader(K, function(calls)
			local names = K.Models.install({ "kit_test_model" }, "maps/_test/assets.json")
			t.eq(names[1], "kit_test_model")
			local tpl = SS.MapKit_Assets.kit_test_model
			t.ok(tpl:IsA("Model"), "template is a Model")
			local parts = 0
			for _, d in tpl:GetDescendants() do
				if d:IsA("BasePart") then
					parts += 1
					t.ok(d.Anchored, d.Name .. " anchored")
				end
			end
			t.eq(parts, 3, "every part kept")
			t.near((tpl:GetPivot().Position - Vector3.new(0, 0, 0.25)).Magnitude, 0, 1e-3, "bottom-centre pivot")
			t.eq(tpl:GetAttribute("Collision"), "Hull", "collision from the manifest")
			t.eq(calls(), 1, "loaded once")
		end)
	end,
	-- measured: setting CollisionFidelity from execute_luau is ignored; ApplyMesh of a CreateMeshPartAsync part works
	["install and place set mesh collision through Models.setFidelity"] = function(t, K)
		local real = K.Models.setFidelity
		local seen = {}
		K.Models.setFidelity = function(part, fidelity)
			table.insert(seen, part.Name .. "=" .. fidelity.Name)
		end
		local ok, err = pcall(withLoader, K, function()
			K.Models.install({ "kit_test_model" }, "maps/_test/assets.json")
			t.eq(table.concat(seen, ","), "Mesh=Hull", "template gets the manifest's fidelity")
			table.clear(seen)
			K.Models.place("kit_test_model", CFrame.new(0, 300, 0), { parent = t.sandbox })
			t.eq(#seen, 0, "a clone with the template's collision needs nothing")
			K.Models.place("kit_test_model", CFrame.new(0, 300, 0), { parent = t.sandbox, collision = "Box" })
			t.eq(table.concat(seen, ","), "Mesh=Box", "an override is applied to the clone")
		end)
		K.Models.setFidelity = real
		if not ok then
			error(err, 0)
		end
	end,
	["install twice loads once, and reloads a deleted template"] = function(t, K)
		withLoader(K, function(calls)
			K.Models.install({ "kit_test_model" }, "maps/_test/assets.json")
			K.Models.install({ "kit_test_model" }, "maps/_test/assets.json")
			t.eq(calls(), 1, "cached")
			SS.MapKit_Assets.kit_test_model:Destroy()
			K.Models.install({ "kit_test_model" }, "maps/_test/assets.json")
			t.eq(calls(), 2, "reloaded after delete")
		end)
	end,
	["a model without an id prints the command that makes it"] = function(t, K)
		t.errors(function()
			K.Models.install({ "kit_test_noid" }, "maps/_test/assets.json")
		end, "run.py model kit_test_noid --from polyhaven:Test004")
	end,
	["a generated model without an id prints the command that really remakes it"] = function(t, K)
		t.errors(function()
			K.Models.install({ "kit_test_tree" }, "maps/_test/assets.json")
		end, "run.py tree kit_test_tree --seed 7 --height 46 --bark polyhaven:jolcham_oak_bark_01")
	end,
	-- a QA fix (run.py model ... --tris 9000) uploads a new id: the cached template must not hide it
	["install reloads a template whose asset id changed"] = function(t, K)
		withLoader(K, function(calls)
			K.Models.install({ "kit_test_model" }, "maps/_test/assets.json")
			local tpl = SS.MapKit_Assets.kit_test_model
			t.eq(tpl:GetAttribute("AssetId"), "rbxassetid://123", "id recorded")
			tpl:SetAttribute("AssetId", "rbxassetid://999") -- as if made from an older upload
			K.Models.install({ "kit_test_model" }, "maps/_test/assets.json")
			t.eq(calls(), 2, "reloaded")
			t.eq(SS.MapKit_Assets.kit_test_model:GetAttribute("AssetId"), "rbxassetid://123", "now the manifest's id")
		end)
	end,
	["a load that never finishes stops with a clear message instead of hanging"] = function(t, K)
		local real, realT = K.Models.loader, K.Models.timeout
		K.Models.loader = function()
			task.wait(30)
		end
		K.Models.timeout = 0.3
		local cache = SS:FindFirstChild("MapKit_Assets")
		local old = cache and cache:FindFirstChild("kit_test_model")
		if old then
			old:Destroy()
		end
		local ok, err = pcall(K.Models.install, { "kit_test_model" }, "maps/_test/assets.json")
		K.Models.loader, K.Models.timeout = real, realT
		t.ok(not ok, "should stop")
		t.ok(string.find(tostring(err), "in front", 1, true) ~= nil, tostring(err))
	end,
	["a collision rebuild that never finishes is skipped and reported"] = function(t, K)
		local realF, realT = K.Models.setFidelity, K.Models.timeout
		K.Models.setFidelity = function()
			task.wait(30)
		end
		K.Models.timeout = 0.3
		local ok, err = pcall(withLoader, K, function()
			local names, report = K.Models.install({ "kit_test_model" }, "maps/_test/assets.json")
			t.eq(names[1], "kit_test_model")
			t.ok(SS.MapKit_Assets:FindFirstChild("kit_test_model") ~= nil, "template still made")
			t.ok(string.find(tostring(report), "collision", 1, true) ~= nil, "reported: " .. tostring(report))
		end)
		K.Models.setFidelity, K.Models.timeout = realF, realT
		if not ok then
			error(err, 0)
		end
	end,
	["every missing model is listed in one error"] = function(t, K)
		local ok, err = pcall(K.Models.install, { "kit_test_noid", "no_such_model" }, "maps/_test/assets.json")
		t.ok(not ok, "should stop")
		err = tostring(err)
		t.ok(string.find(err, "kit_test_noid", 1, true) and string.find(err, "no_such_model", 1, true), err)
	end,
	-- measured: leaf cards need AlphaMode Transparency; the importer gives Overlay, or only a TextureID (black cut-outs)
	["leaf parts get see-through textures"] = function(t, K)
		local real = K.Models.loader
		K.Models.loader = function()
			local outer = Instance.new("Model")
			local a = Instance.new("MeshPart")
			a.Name = "Leaves"
			a.Size = Vector3.new(2, 2, 0.1)
			local sa = Instance.new("SurfaceAppearance")
			sa.AlphaMode = Enum.AlphaMode.Overlay
			sa.Parent = a
			a.Parent = outer
			local b = Instance.new("MeshPart")
			b.Name = "Leaves.001"
			b.Size = Vector3.new(2, 2, 0.1)
			b.TextureID = "rbxassetid://5"
			b.Parent = outer
			local trunk = Instance.new("MeshPart")
			trunk.Name = "Tree"
			trunk.Size = Vector3.new(1, 4, 1)
			Instance.new("SurfaceAppearance").Parent = trunk
			trunk.Parent = outer
			return outer
		end
		local cache = SS:FindFirstChild("MapKit_Assets")
		local old = cache and cache:FindFirstChild("kit_test_model")
		if old then
			old:Destroy()
		end
		local ok, err = pcall(function()
			K.Models.install({ "kit_test_model" }, "maps/_test/assets.json")
			local tpl = SS.MapKit_Assets.kit_test_model
			t.eq(tpl.Leaves:FindFirstChildOfClass("SurfaceAppearance").AlphaMode, Enum.AlphaMode.Transparency, "Overlay → Transparency")
			local b = tpl:FindFirstChild("Leaves.001")
			local sb = b:FindFirstChildOfClass("SurfaceAppearance")
			t.ok(sb ~= nil, "a SurfaceAppearance made from the TextureID")
			t.eq(sb and sb.ColorMap, "rbxassetid://5", "same image")
			t.eq(sb and sb.AlphaMode, Enum.AlphaMode.Transparency, "see-through")
			t.eq(b.TextureID, "", "TextureID moved into it")
			t.eq(tpl.Tree:FindFirstChildOfClass("SurfaceAppearance").AlphaMode, Enum.AlphaMode.Overlay, "bark untouched")
		end)
		K.Models.loader = real
		local made = SS.MapKit_Assets:FindFirstChild("kit_test_model")
		if made then
			made:Destroy()
		end
		if not ok then
			error(err, 0)
		end
	end,
	["leaf cards never collide, even on a Hull model or a Hull override"] = function(t, K)
		-- review 2026-10-25: Hull leaves made invisible cones ~38 studs wide around every pine
		local realLoader, realFid = K.Models.loader, K.Models.setFidelity
		local fid = {}
		K.Models.setFidelity = function(part, fidelity)
			table.insert(fid, part.Name)
		end
		K.Models.loader = function()
			local outer = Instance.new("Model")
			local leaves = Instance.new("MeshPart")
			leaves.Name = "Leaves"
			leaves.Size = Vector3.new(8, 8, 8)
			Instance.new("SurfaceAppearance").Parent = leaves
			leaves.Parent = outer
			local trunk = Instance.new("MeshPart")
			trunk.Name = "Tree"
			trunk.Size = Vector3.new(1, 6, 1)
			Instance.new("SurfaceAppearance").Parent = trunk
			trunk.Parent = outer
			return outer
		end
		local old = SS:FindFirstChild("MapKit_Assets") and SS.MapKit_Assets:FindFirstChild("kit_test_model")
		if old then
			old:Destroy()
		end
		local ok, err = pcall(function()
			K.Models.install({ "kit_test_model" }, "maps/_test/assets.json") -- collision Hull in the fixture
			local tpl = SS.MapKit_Assets.kit_test_model
			t.eq(tpl.Leaves.CanCollide, false, "template leaves don't collide")
			t.eq(tpl.Leaves.CanQuery, false, "template leaves aren't queried")
			t.eq(tpl.Leaves.CanTouch, false, "template leaves aren't touched")
			t.eq(tpl.Tree.CanCollide, true, "the trunk still collides")
			t.eq(table.concat(fid, ","), "Tree", "only the trunk's collision is rebuilt")
			table.clear(fid)
			local m = K.Models.place("kit_test_model", CFrame.new(0, 300, 0), { parent = t.sandbox, collision = "Box" })
			t.eq(m.Leaves.CanCollide, false, "an override keeps leaves off")
			t.eq(table.concat(fid, ","), "Tree", "the override rebuilds the trunk only")
		end)
		K.Models.loader, K.Models.setFidelity = realLoader, realFid
		local made = SS.MapKit_Assets:FindFirstChild("kit_test_model")
		if made then
			made:Destroy()
		end
		if not ok then
			error(err, 0)
		end
	end,
	["install treats the leaves of a template it reuses"] = function(t, K)
		-- review 2026-10-25: a template cached before the leaf fix was reused untreated (black, colliding leaves)
		local real = K.Models.loader
		local loads = 0
		K.Models.loader = function()
			loads += 1
			return Instance.new("Model")
		end
		local c = SS:FindFirstChild("MapKit_Assets") or Instance.new("Folder")
		c.Name = "MapKit_Assets"
		c.Parent = SS
		local old = c:FindFirstChild("kit_test_model")
		if old then
			old:Destroy()
		end
		local tpl = Instance.new("Model")
		tpl.Name = "kit_test_model"
		tpl:SetAttribute("AssetId", "rbxassetid://123")
		local leaves = Instance.new("MeshPart")
		leaves.Name = "Leaves"
		leaves.Size = Vector3.new(4, 4, 4)
		leaves.Anchored = true
		local sa = Instance.new("SurfaceAppearance")
		sa.AlphaMode = Enum.AlphaMode.Overlay
		sa.Parent = leaves
		leaves.Parent = tpl
		local bare = Instance.new("MeshPart")
		bare.Name = "Leaves.002" -- no texture at all: can't be made see-through
		bare.Size = Vector3.new(4, 4, 4)
		bare.Anchored = true
		bare.Parent = tpl
		tpl.Parent = c
		local ok, err = pcall(function()
			local _, report = K.Models.install({ "kit_test_model" }, "maps/_test/assets.json")
			t.eq(loads, 0, "the cached template is reused")
			t.eq(tpl.Leaves:FindFirstChildOfClass("SurfaceAppearance").AlphaMode, Enum.AlphaMode.Transparency, "reused leaves see-through")
			t.eq(tpl.Leaves.CanCollide, false, "reused leaves don't collide")
			t.ok(tostring(report):find("kit_test_model") and tostring(report):find("Leaves.002"), "the untexturable leaf part is reported: " .. tostring(report))
		end)
		K.Models.loader = real
		tpl:Destroy()
		if not ok then
			error(err, 0)
		end
	end,
	["an unknown model names the command"] = function(t, K)
		t.errors(function()
			K.Models.install({ "no_such_model" }, "maps/_test/assets.json")
		end, "run.py model no_such_model --from polyhaven:")
	end,
	["place clones at a pivot, anchored, with collision and parent"] = function(t, K)
		withLoader(K, function()
			K.Models.install({ "kit_test_model" }, "maps/_test/assets.json")
			local cf = CFrame.new(10, 5, 20) * CFrame.Angles(0, math.rad(90), 0)
			local m = K.Models.place("kit_test_model", cf, { parent = t.sandbox })
			t.eq(m.Parent, t.sandbox, "parent")
			t.near((m:GetPivot().Position - cf.Position).Magnitude, 0, 1e-3, "pivot position")
			t.near((m:GetPivot().LookVector - cf.LookVector).Magnitude, 0, 1e-3, "pivot rotation")
			local seat = m:FindFirstChild("Seat", true)
			t.near(seat.Position.Y - seat.Size.Y / 2, 5, 1e-3, "sits on the pivot")
			t.ok(seat.Anchored and seat.CanCollide, "anchored, collides")
		end)
	end,
	["place with collision none turns collision off"] = function(t, K)
		withLoader(K, function()
			K.Models.install({ "kit_test_model" }, "maps/_test/assets.json")
			local m = K.Models.place("kit_test_model", CFrame.new(0, 300, 0), { parent = t.sandbox, collision = "none", shadow = false })
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					t.ok(not d.CanCollide and not d.CanQuery and not d.CanTouch, d.Name .. " no collision")
					t.ok(not d.CastShadow, d.Name .. " no shadow")
				end
			end
		end)
	end,
	-- Poly Haven ground-cover files hold several variants side by side; variant = n places the n-th from -X alone
	["place with a variant places just that part, sitting on the pivot"] = function(t, K)
		withLoader(K, function()
			K.Models.install({ "kit_test_model" }, "maps/_test/assets.json")
			t.eq(K.Models.variants("kit_test_model"), 3, "three parts")
			local m = K.Models.place("kit_test_model", CFrame.new(50, 300, 0), { parent = t.sandbox, variant = 1 })
			local parts = {}
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					table.insert(parts, d)
				end
			end
			t.eq(#parts, 1, "one part")
			t.near(parts[1].Position.Y - parts[1].Size.Y / 2, 300, 1e-3, "sits on the pivot")
			t.near(parts[1].Position.X, 50, 1e-3, "centred on the pivot")
		end)
	end,
	-- scanned textures can be too light for a scene: SurfaceAppearance.Color tints them (writable, measured)
	["place with a tint colours the clone's textures, not the template's"] = function(t, K)
		withLoader(K, function()
			K.Models.install({ "kit_test_model" }, "maps/_test/assets.json")
			local m = K.Models.place("kit_test_model", CFrame.new(0, 300, 0), { parent = t.sandbox, tint = "#786C60" })
			local sa = m:FindFirstChildWhichIsA("SurfaceAppearance", true)
			t.eq(sa.Color:ToHex():upper(), "786C60", "clone tinted")
			local tsa = SS.MapKit_Assets.kit_test_model:FindFirstChildWhichIsA("SurfaceAppearance", true)
			t.eq(tsa.Color:ToHex():upper(), "FFFFFF", "template untouched")
		end)
	end,
	["place of a model that is not installed says to install it"] = function(t, K)
		t.errors(function()
			K.Models.place("not_installed_model", CFrame.new(), { parent = t.sandbox })
		end, "K.Models.install")
	end,
	["override sets the base material override"] = function(t, K)
		local before = MS:GetBaseMaterialOverride(Enum.Material.Fabric)
		local ok, err = pcall(function()
			K.Materials.install({ "kit_test_mat" }, "maps/_test/assets.json")
			K.Materials.override(Enum.Material.Fabric, "kit_test_mat")
			t.eq(MS:GetBaseMaterialOverride(Enum.Material.Fabric), "kit_test_mat")
		end)
		MS:SetBaseMaterialOverride(Enum.Material.Fabric, before)
		local v = MS:FindFirstChild("kit_test_mat")
		if v then
			v:Destroy()
		end
		t.ok(before ~= nil, "read the old override")
		if not ok then
			error(err, 0)
		end
	end,
}
