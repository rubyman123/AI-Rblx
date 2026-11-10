-- Tests for MapKit.Build. Method by fwjelaa (FWJ STUDIOS).
return {
	["part has kit defaults and is parented last"] = function(t, K)
		local p = K.Build.part({ Size = Vector3.new(2, 3, 4), Color = Color3.new(1, 0, 0), Parent = t.sandbox })
		t.ok(p.Anchored, "anchored")
		t.eq(p.Material, Enum.Material.SmoothPlastic)
		t.eq(p.TopSurface, Enum.SurfaceType.Smooth)
		t.eq(p.Parent, t.sandbox)
		t.eq(p.Size, Vector3.new(2, 3, 4))
	end,
	["part takes a class"] = function(t, K)
		t.ok(K.Build.part({}, "WedgePart"):IsA("WedgePart"), "wedge")
	end,
	["a part made without a Color is tagged"] = function(t, K)
		t.eq(K.Build.part({}):GetAttribute("MapKit_NoColor"), true, "untinted part")
		t.eq(K.Build.part({ Color = Color3.new(1, 0, 0) }):GetAttribute("MapKit_NoColor"), nil, "coloured part")
	end,
	["props override defaults"] = function(t, K)
		local p = K.Build.part({ TopSurface = Enum.SurfaceType.Studs, Material = Enum.Material.Neon })
		t.eq(p.TopSurface, Enum.SurfaceType.Studs)
		t.eq(p.Material, Enum.Material.Neon)
	end,
	["decor turns off collision, and shadows on small parts"] = function(t, K)
		local m = Instance.new("Model")
		local small = K.Build.part({ Size = Vector3.new(1, 1, 1), Parent = m })
		local big = K.Build.part({ Size = Vector3.new(10, 1, 1), Parent = m })
		K.Build.decor(m)
		t.ok(not small.CanCollide and not small.CanTouch and not small.CanQuery, "small: no collision")
		t.ok(not small.CastShadow, "small: no shadow")
		t.ok(not big.CanCollide, "big: no collision")
		t.ok(big.CastShadow, "big: keeps its shadow")
	end,
	["flush parents everything"] = function(t, K)
		local items = {}
		for i = 1, 650 do
			items[i] = K.Build.part({ Size = Vector3.one })
		end
		K.Build.flush(items, t.sandbox, 300)
		t.eq(#t.sandbox:GetChildren(), 650)
	end,
}
