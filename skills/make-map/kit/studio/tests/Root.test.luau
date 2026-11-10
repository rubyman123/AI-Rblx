-- Tests for MapKit.Root. Method by fwjelaa (FWJ STUDIOS).
return {
	["get creates the layer tree once"] = function(t, K)
		local a = K.Root.get("t1", t.sandbox)
		local b = K.Root.get("t1", t.sandbox)
		t.eq(a, b, "same root")
		t.eq(a.Name, "Map_t1")
		for _, layer in K.Root.LAYERS do
			t.ok(a:FindFirstChild(layer) ~= nil, "layer " .. layer)
		end
	end,
	["layer creates a missing custom layer"] = function(t, K)
		local f = K.Root.layer("t3", "Extra", t.sandbox)
		t.eq(f.Parent, K.Root.get("t3", t.sandbox))
	end,
	["clear empties only that layer"] = function(t, K)
		local props = K.Root.layer("t2", "Props", t.sandbox)
		local lights = K.Root.layer("t2", "Lights", t.sandbox)
		Instance.new("Part").Parent = props
		Instance.new("Part").Parent = lights
		K.Root.clear("t2", "Props", t.sandbox)
		t.eq(#props:GetChildren(), 0, "props cleared")
		t.eq(#lights:GetChildren(), 1, "lights kept")
	end,
	["claimTerrain records its box and clears only that box on a re-run"] = function(t, K)
		local T = workspace.Terrain
		local cf, size = CFrame.new(1000, 640, 1000), Vector3.new(16, 8, 16)
		t.emptyTerrain(cf, size)
		local ok, err = pcall(function()
			K.Root.claimTerrain("tc1", cf, size, t.sandbox)
			T:FillBlock(cf, size, Enum.Material.Water) -- the map writes its own terrain
			K.Root.claimTerrain("tc1", cf, size, t.sandbox) -- a re-run: the box is ours, so it is cleared, not refused
			local ch = T:ReadVoxelChannels(Region3.new(cf.Position - size / 2, cf.Position + size / 2):ExpandToGrid(4), 4, { "LiquidOccupancy" })
			t.eq(ch.LiquidOccupancy[1][1][1], 0, "own water cleared on re-claim")
			t.ok(K.Root.get("tc1", t.sandbox):GetAttribute("TerrainBox") ~= nil, "box recorded")
		end)
		T:FillBlock(cf, size, Enum.Material.Air)
		if not ok then
			error(err, 0)
		end
	end,
	["claimTerrain refuses terrain the map didn't make"] = function(t, K)
		local T = workspace.Terrain
		local cf, size = CFrame.new(1100, 640, 1000), Vector3.new(16, 8, 16)
		t.emptyTerrain(cf, size)
		T:FillBlock(cf, size, Enum.Material.Rock) -- stands in for the user's own terrain
		local ok, err = pcall(K.Root.claimTerrain, "tc2", cf, size, t.sandbox)
		local mats = T:ReadVoxels(Region3.new(cf.Position - size / 2, cf.Position + size / 2):ExpandToGrid(4), 4)
		local untouched = mats[1][1][1] == Enum.Material.Rock
		T:FillBlock(cf, size, Enum.Material.Air)
		t.ok(not ok and string.find(tostring(err), "Root.claimTerrain", 1, true) ~= nil, "error: " .. tostring(err))
		t.ok(untouched, "user terrain left alone")
	end,
	["claimTerrain records the 4-stud cells it checked, not an off-grid box"] = function(t, K)
		-- review 2026-10-25: an off-grid box (forest-lake's ±310) was recorded raw, so clearing it later touched
		-- edge cells only partly inside it
		local cf, size = CFrame.new(1302, 641, 1001), Vector3.new(10, 6, 10)
		t.emptyTerrain(cf, size)
		local region = K.Root.claimTerrain("tg1", cf, size, t.sandbox)
		local b = game:GetService("HttpService"):JSONDecode(K.Root.get("tg1", t.sandbox):GetAttribute("TerrainBox"))
		for axis = 1, 3 do
			t.eq((b.p[axis] - b.s[axis] / 2) % 4, 0, "recorded box starts on the grid")
			t.eq(b.s[axis] % 4, 0, "recorded box is whole cells")
		end
		t.eq(Vector3.new(b.s[1], b.s[2], b.s[3]), region.Size, "the record is the region it returns")
		t.ok(b.s[1] >= 10 and b.s[2] >= 6, "covers the asked box")
	end,
	-- switching maps in one place: the old map hands its terrain back (re-running its base phase rebuilds it)
	["releaseTerrain clears the map's recorded box and forgets it"] = function(t, K)
		local T = workspace.Terrain
		local cf, size = CFrame.new(1200, 640, 1000), Vector3.new(16, 8, 16)
		t.emptyTerrain(cf, size)
		local ok, err = pcall(function()
			K.Root.claimTerrain("tr1", cf, size, t.sandbox)
			T:FillBlock(cf, size, Enum.Material.Water)
			t.eq(K.Root.releaseTerrain("tr1", t.sandbox), true, "released")
			local ch = T:ReadVoxelChannels(Region3.new(cf.Position - size / 2, cf.Position + size / 2):ExpandToGrid(4), 4, { "LiquidOccupancy" })
			t.eq(ch.LiquidOccupancy[1][1][1], 0, "water gone")
			t.eq(K.Root.get("tr1", t.sandbox):GetAttribute("TerrainBox"), nil, "record gone")
			t.eq(K.Root.releaseTerrain("tr1", t.sandbox), false, "nothing left to release")
		end)
		T:FillBlock(cf, size, Enum.Material.Air)
		if not ok then
			error(err, 0)
		end
	end,
	["removeTemplate moves Baseplate and SpawnLocation and never deletes them"] = function(t, K)
		local bp = Instance.new("Part")
		bp.Name = "Baseplate"
		bp.Parent = t.sandbox
		local sp = Instance.new("SpawnLocation")
		sp.Name = "SpawnLocation"
		sp.Parent = t.sandbox
		local moved = K.Root.removeTemplate(t.sandbox)
		local keep = game:GetService("ServerStorage"):FindFirstChild("MapKit_Removed")
		t.eq(moved, 2, "moved count")
		t.ok(keep ~= nil and bp.Parent == keep and sp.Parent == keep, "kept in MapKit_Removed")
		bp:Destroy()
		sp:Destroy()
	end,
}
