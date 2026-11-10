-- One Model per map with fixed layer folders; re-acquired every call. Method by fwjelaa (FWJ STUDIOS).
local HttpService = game:GetService("HttpService")

local Root = {}

Root.LAYERS = { "Terrain", "Ground", "Structures", "Route", "Landmarks", "Props", "Foliage", "Lights", "Spawns", "QA" }

function Root.get(id, parent)
	parent = parent or workspace
	local name = "Map_" .. id
	local root = parent:FindFirstChild(name)
	if not root then
		root = Instance.new("Model")
		root.Name = name
		for _, layer in Root.LAYERS do
			local f = Instance.new("Folder")
			f.Name = layer
			f.Parent = root
		end
		root.Parent = parent
	end
	return root
end

function Root.layer(id, layer, parent)
	local root = Root.get(id, parent)
	local f = root:FindFirstChild(layer)
	if not f then
		f = Instance.new("Folder")
		f.Name = layer
		f.Parent = root
	end
	return f
end

-- Empty one layer so a phase can rebuild it from scratch (phases stay idempotent).
function Root.clear(id, layer, parent)
	local f = Root.layer(id, layer, parent)
	for _, c in f:GetChildren() do
		c:Destroy()
	end
	return f
end

local function removedFolder()
	local ServerStorage = game:GetService("ServerStorage")
	local keep = ServerStorage:FindFirstChild("MapKit_Removed")
	if not keep then
		keep = Instance.new("Folder")
		keep.Name = "MapKit_Removed"
		keep.Parent = ServerStorage
	end
	return keep
end

-- Move the empty-place template (Baseplate, SpawnLocation) out of the way. Never deletes: it is kept in
-- ServerStorage.MapKit_Removed so the user can drag it back.
function Root.removeTemplate(parent)
	parent = parent or workspace
	local keep, moved = removedFolder(), 0
	for _, name in { "Baseplate", "SpawnLocation" } do
		local inst = parent:FindFirstChild(name)
		if inst then
			inst.Parent = keep
			moved += 1
		end
	end
	return moved
end

-- Terrain is the user's: a map may only write terrain inside a box it claims (axis-aligned; cf's rotation is
-- ignored). A re-run clears the box this map recorded last time; any terrain already in a new box was not made
-- by the map, so claiming refuses instead of overwriting it.
function Root.claimTerrain(id, cf, size, parent)
	local root = Root.get(id, parent)
	local T = workspace.Terrain
	local old = root:GetAttribute("TerrainBox")
	if old then
		local b = HttpService:JSONDecode(old)
		T:FillBlock(CFrame.new(b.p[1], b.p[2], b.p[3]), Vector3.new(b.s[1], b.s[2], b.s[3]), Enum.Material.Air)
	end
	local region = Region3.new(cf.Position - size / 2, cf.Position + size / 2):ExpandToGrid(4)
	local ch = T:ReadVoxelChannels(region, 4, { "SolidMaterial", "LiquidOccupancy" })
	for x = 1, #ch.SolidMaterial do
		for y = 1, #ch.SolidMaterial[x] do
			for z = 1, #ch.SolidMaterial[x][y] do
				if ch.SolidMaterial[x][y][z] ~= Enum.Material.Air or ch.LiquidOccupancy[x][y][z] > 0 then
					error(("Root.claimTerrain: map %s wants the terrain box at %s (size %s), but there is already terrain there that this map didn't make. Build in a fresh Baseplate place, or move the map.")
						:format(id, tostring(cf.Position), tostring(size)), 2)
				end
			end
		end
	end
	-- record the whole cells that were checked: clearing an off-grid box later would touch edge cells only partly in it
	local p, s = region.CFrame.Position, region.Size
	root:SetAttribute("TerrainBox", HttpService:JSONEncode({ p = { p.X, p.Y, p.Z }, s = { s.X, s.Y, s.Z } }))
	return region
end

-- Hand a map's terrain back (one map per place: the next map can then claim the ground). Clears only the box the
-- map recorded; re-running the map's base phase rebuilds it. parent: where the map's model is (e.g. a stash).
function Root.releaseTerrain(id, parent)
	local root = (parent or workspace):FindFirstChild("Map_" .. id)
	local old = root and root:GetAttribute("TerrainBox")
	if not old then
		return false
	end
	local b = HttpService:JSONDecode(old)
	workspace.Terrain:FillBlock(CFrame.new(b.p[1], b.p[2], b.p[3]), Vector3.new(b.s[1], b.s[2], b.s[3]), Enum.Material.Air)
	root:SetAttribute("TerrainBox", nil)
	return true
end

return Root
