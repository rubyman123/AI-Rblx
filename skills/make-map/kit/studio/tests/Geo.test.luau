-- Tests for MapKit.Geo. Method by fwjelaa (FWJ STUDIOS).
local function params(t)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { t.sandbox }
	return rp
end

local function down(t, x, z)
	local r = workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -1000, 0), params(t))
	return r and r.Position.Y
end

local function blocked(t, from, to)
	return workspace:Raycast(from, to - from, params(t)) ~= nil
end

return {
	["wall leaves a door gap and a window gap"] = function(t, K)
		local base = Vector3.new(0, 200, 0)
		K.Geo.wall(base, base + Vector3.new(20, 0, 0), 10, 1, {
			{ at = 5, width = 4, bottom = 0, top = 7 },
			{ at = 14, width = 4, bottom = 3, top = 7 },
		}, nil, t.sandbox)
		local function hits(x, y)
			return blocked(t, Vector3.new(x, 200 + y, 5), Vector3.new(x, 200 + y, -5))
		end
		t.ok(not hits(5, 3), "door open")
		t.ok(hits(5, 8.5), "lintel above the door")
		t.ok(hits(14, 1.5), "sill under the window")
		t.ok(not hits(14, 5), "window open")
		t.ok(hits(10, 5), "solid between the openings")
		t.ok(hits(19, 9), "solid at the end")
	end,
	["wall rejects an opening off the end"] = function(t, K)
		t.errors(function()
			K.Geo.wall(Vector3.new(0, 200, 0), Vector3.new(10, 200, 0), 10, 1, { { at = 9, width = 4 } }, nil, t.sandbox)
		end, "Geo.wall")
	end,
	["wall rejects overlapping openings"] = function(t, K)
		t.errors(function()
			K.Geo.wall(Vector3.new(0, 200, 0), Vector3.new(20, 200, 0), 10, 1, {
				{ at = 5, width = 4 },
				{ at = 7, width = 4 },
			}, nil, t.sandbox)
		end, "Geo.wall")
	end,
	["slab top sits at cf height"] = function(t, K)
		K.Geo.slab(CFrame.new(0, 200, 0), 10, 10, 2, nil, t.sandbox)
		t.near(down(t, 0, 0), 200, 1e-3, "slab top")
	end,
	["stairs reach the full rise"] = function(t, K)
		K.Geo.stairs(CFrame.new(0, 200, 0), 6, 8, 8, 1.5, nil, t.sandbox)
		t.near(down(t, 0, -0.75), 201, 1e-3, "first step")
		t.near(down(t, 0, -(8 - 0.5) * 1.5), 208, 1e-3, "last step")
	end,
	["ramp rises along LookVector"] = function(t, K)
		K.Geo.ramp(CFrame.new(0, 200, 0), 6, 4, 16, nil, t.sandbox)
		t.near(down(t, 0, -1), 200 + 4 * 1 / 16, 0.05, "low end")
		t.near(down(t, 0, -15), 200 + 4 * 15 / 16, 0.05, "high end")
	end,
	["tri top face lies on the triangle"] = function(t, K)
		K.Geo.tri(Vector3.new(0, 200, 0), Vector3.new(12, 200, 0), Vector3.new(0, 200, 9), 1, nil, t.sandbox)
		t.near(down(t, 3, 2), 200, 0.02, "flat triangle top")
		t.ok(down(t, 10, 8) == nil, "nothing outside the triangle")
	end,
	["sloped tri follows its plane"] = function(t, K)
		K.Geo.tri(Vector3.new(0, 200, 0), Vector3.new(10, 205, 0), Vector3.new(0, 200, 10), 1, nil, t.sandbox)
		t.near(down(t, 4, 2), 202, 0.05, "y = 200 + x/2")
	end,
	["tri toward inside keeps the outer face on the triangle"] = function(t, K)
		-- triangle in the plane y = 200 with the solid side above: rays from below hit 200
		K.Geo.tri(Vector3.new(0, 200, 0), Vector3.new(12, 200, 0), Vector3.new(0, 200, 9), 1, nil, t.sandbox, Vector3.new(3, 250, 3))
		local r = workspace:Raycast(Vector3.new(3, 100, 2), Vector3.new(0, 200, 0), params(t))
		t.near(r and r.Position.Y, 200, 0.02, "bottom face at 200")
	end,
	["degenerate tri returns nil"] = function(t, K)
		t.eq(K.Geo.tri(Vector3.zero, Vector3.new(1, 0, 0), Vector3.new(2, 0, 0), 1, nil, t.sandbox), nil)
	end,
}
