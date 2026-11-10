-- Tests for MapKit.Props. Method by fwjelaa (FWJ STUDIOS).
local EXPECT = { -- recipe = {min height, max height} for a 5-stud character world
	tree = { 12, 26 },
	pine = { 12, 30 },
	rock = { 1.5, 8 },
	bush = { 1.5, 6 },
	cloud = { 4, 20 },
	crate = { 2, 5 },
	flower = { 1, 3 },
	cactus = { 5, 14 },
	deadTree = { 8, 22 },
	boulder = { 4, 9 },
}

local function anchored(m)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and not d.Anchored then
			return false
		end
	end
	return true
end

local function params(t)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { t.sandbox }
	return rp
end

local cases = {}

for name, range in EXPECT do
	cases[name .. " builds a sane model"] = function(t, K)
		local m = K.Props[name](CFrame.new(0, 200, 0), { rng = Random.new(3) })
		m.Parent = t.sandbox
		t.ok(m:IsA("Model"), "model")
		t.ok(#m:GetDescendants() > 0, "has parts")
		t.ok(anchored(m), "anchored")
		local cf, size = m:GetBoundingBox()
		t.ok(size.Y >= range[1] and size.Y <= range[2], ("height %.1f outside %d-%d"):format(size.Y, range[1], range[2]))
		if name ~= "cloud" then
			local bottom = cf.Position.Y - size.Y / 2
			t.ok(bottom > 196 and bottom < 201, ("base at %.1f, want about 200"):format(bottom))
		end
	end
	cases[name .. " is deterministic per seed"] = function(t, K)
		local a = K.Props[name](CFrame.new(), { rng = Random.new(9) })
		local b = K.Props[name](CFrame.new(), { rng = Random.new(9) })
		local _, sa = a:GetBoundingBox()
		local _, sb = b:GetBoundingBox()
		t.ok((sa - sb).Magnitude < 1e-4, "same size")
		t.eq(#a:GetDescendants(), #b:GetDescendants(), "same part count")
	end
end

cases["boulder detail 1 has four times the faces"] = function(t, K)
	local plain = K.Props.boulder(CFrame.new(), { rng = Random.new(2), radius = 6 })
	local fine = K.Props.boulder(CFrame.new(), { rng = Random.new(2), radius = 6, detail = 1 })
	t.eq(#plain:GetChildren(), 40, "20 faces x 2 wedges")
	t.eq(#fine:GetChildren(), 160, "80 faces x 2 wedges")
	local _, size = fine:GetBoundingBox()
	t.ok(size.Y > 6 and size.Y < 14, ("detailed boulder height %.1f"):format(size.Y))
end

cases["pad top is 0.8 up and has a neon rim"] = function(t, K)
	local m = K.Props.pad(CFrame.new(0, 200, 0), { radius = 6 })
	m.Parent = t.sandbox
	local r = workspace:Raycast(Vector3.new(0, 300, 0), Vector3.new(0, -200, 0), params(t))
	t.near(r and r.Position.Y, 200.8, 0.02, "pad top")
	local neon = false
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") and p.Material == Enum.Material.Neon then
			neon = true
		end
	end
	t.ok(neon, "neon rim")
end

cases["arrow lies flat and points along LookVector"] = function(t, K)
	local m = K.Props.arrow(CFrame.new(0, 200, 0), { length = 8 })
	local cf, size = m:GetBoundingBox()
	t.ok(size.Y < 0.6, "flat")
	t.near(cf.Position.Z, -4, 0.3, "extends toward -Z")
end

cases["sign carries its text facing the reader"] = function(t, K)
	local m = K.Props.sign(CFrame.new(0, 200, 0), { text = "SHOP" })
	local gui = m:FindFirstChildWhichIsA("SurfaceGui", true)
	t.ok(gui ~= nil, "surface gui")
	t.eq(gui.Face, Enum.NormalId.Front)
	t.eq(gui:FindFirstChildWhichIsA("TextLabel").Text, "SHOP")
end

cases["gate can be walked through but not around the pillars"] = function(t, K)
	local m = K.Props.gate(CFrame.new(0, 200, 0), { width = 16, height = 18, text = "DESERT" })
	m.Parent = t.sandbox
	local function hit(x)
		return workspace:Raycast(Vector3.new(x, 203, 10), Vector3.new(0, 0, -20), params(t)) ~= nil
	end
	t.ok(not hit(0), "opening clear")
	t.ok(not hit(7), "opening clear near the edge")
	t.ok(hit(9.5), "pillar")
end

cases["fence puts a post every spacing studs"] = function(t, K)
	local m = K.Props.fence(Vector3.new(0, 200, 0), Vector3.new(0, 200, -30), { spacing = 6 })
	local posts = 0
	for _, p in m:GetChildren() do
		if p.Size == Vector3.new(1, 4, 1) then
			posts += 1
		end
	end
	t.eq(posts, 6, "posts")
end

cases["fence rejects zero spacing and zero length"] = function(t, K)
	t.errors(function()
		K.Props.fence(Vector3.new(0, 200, 0), Vector3.new(0, 200, -30), { spacing = 0 })
	end, "Props.fence")
	t.errors(function()
		K.Props.fence(Vector3.new(0, 200, 0), Vector3.new(0, 200, 0), {})
	end, "Props.fence")
end

cases["stall has a counter and a sign"] = function(t, K)
	local m = K.Props.stall(CFrame.new(0, 200, 0), { text = "REBIRTH" })
	t.eq(m:FindFirstChildWhichIsA("TextLabel", true).Text, "REBIRTH")
	local _, size = m:GetBoundingBox()
	t.ok(size.Y > 9 and size.Y < 14, "stall height")
end

return cases
