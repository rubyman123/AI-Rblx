-- Tests for MapKit.Materials. Method by fwjelaa (FWJ STUDIOS).
local MS = game:GetService("MaterialService")

local function cleanup()
	for _, n in { "kit_test_mat", "kit_test_half", "kit_test_partial" } do
		local v = MS:FindFirstChild(n)
		if v then
			v:Destroy()
		end
	end
end

return {
	["install creates a material variant from the manifest"] = function(t, K)
		cleanup()
		local ok, err = pcall(function()
			local names = K.Materials.install({ "kit_test_mat" }, "maps/_test/assets.json")
			t.eq(names[1], "kit_test_mat")
			local v = MS:FindFirstChild("kit_test_mat")
			t.ok(v and v:IsA("MaterialVariant"), "variant exists")
			t.eq(v.BaseMaterial, Enum.Material.Fabric)
			t.eq(v.StudsPerTile, 6)
			t.eq(v.MaterialPattern, Enum.MaterialPattern.Organic)
			t.eq(v.ColorMap, "rbxassetid://100")
		end)
		cleanup()
		if not ok then
			error(err, 0)
		end
	end,
	["install twice keeps one variant"] = function(t, K)
		cleanup()
		local ok, err = pcall(function()
			K.Materials.install({ "kit_test_mat" }, "maps/_test/assets.json")
			K.Materials.install({ "kit_test_mat" }, "maps/_test/assets.json")
			local n = 0
			for _, c in MS:GetChildren() do
				if c.Name == "kit_test_mat" then
					n += 1
				end
			end
			t.eq(n, 1, "variants named kit_test_mat")
		end)
		cleanup()
		if not ok then
			error(err, 0)
		end
	end,
	["a missing name says how to make it"] = function(t, K)
		t.errors(function()
			K.Materials.install({ "no_such_mat" }, "maps/_test/assets.json")
		end, "run.py material no_such_mat")
	end,
	["a half-uploaded material is refused"] = function(t, K)
		cleanup()
		t.errors(function()
			K.Materials.install({ "kit_test_half" }, "maps/_test/assets.json")
		end, "kit_test_half")
		t.ok(MS:FindFirstChild("kit_test_half") == nil, "nothing half-made")
	end,
	["a material missing the id of one of its maps is refused"] = function(t, K)
		cleanup()
		t.errors(function()
			K.Materials.install({ "kit_test_partial" }, "maps/_test/assets.json")
		end, "roughness")
		t.ok(MS:FindFirstChild("kit_test_partial") == nil, "nothing made")
	end,
	["a material without ids prints the full command that remakes it"] = function(t, K)
		cleanup()
		t.errors(function()
			K.Materials.install({ "kit_test_half" }, "maps/_test/assets.json")
		end, "run.py material kit_test_half --from ambientcg:Test001 --tint \"#123456\" --motif dots:64:0.2 --studs 4")
	end,
	["the printed command survives a shell: the tint's # is quoted"] = function(t, K)
		-- review 2026-10-25: bash and PowerShell read an unquoted #123456 as a comment and dropped the rest
		cleanup()
		local ok, err = pcall(K.Materials.install, { "kit_test_half" }, "maps/_test/assets.json")
		t.eq(ok, false, "stops")
		t.ok(not tostring(err):find(" #", 1, true), "no bare # in: " .. tostring(err))
	end,
	["every missing material is listed in one error"] = function(t, K)
		cleanup()
		local ok, err = pcall(K.Materials.install, { "kit_test_half", "no_such_mat" }, "maps/_test/assets.json")
		t.ok(not ok, "should stop")
		err = tostring(err)
		t.ok(string.find(err, "kit_test_half", 1, true) and string.find(err, "no_such_mat", 1, true), err)
	end,
	["apply sets material, variant and clears the grey tag"] = function(t, K)
		cleanup()
		local ok, err = pcall(function()
			K.Materials.install({ "kit_test_mat" }, "maps/_test/assets.json")
			local p = K.Build.part({ Size = Vector3.one, Parent = t.sandbox })
			K.Materials.apply(p, "kit_test_mat")
			t.eq(p.Material, Enum.Material.Fabric)
			t.eq(p.MaterialVariant, "kit_test_mat")
			t.eq(p:GetAttribute("MapKit_NoColor"), nil)
		end)
		cleanup()
		if not ok then
			error(err, 0)
		end
	end,
	-- Roblox multiplies the ColorMap by Part.Color: the default grey darkened every texture by a third
	["apply shows the texture as made (white) unless given a tint"] = function(t, K)
		cleanup()
		local ok, err = pcall(function()
			K.Materials.install({ "kit_test_mat" }, "maps/_test/assets.json")
			local p = K.Build.part({ Size = Vector3.one, Parent = t.sandbox })
			K.Materials.apply(p, "kit_test_mat")
			t.eq(p.Color, Color3.new(1, 1, 1), "default colour")
			local q = K.Build.part({ Size = Vector3.one, Parent = t.sandbox })
			K.Materials.apply(q, "kit_test_mat", "#A8946A")
			t.eq(q.Color:ToHex():upper(), "A8946A", "tint")
		end)
		cleanup()
		if not ok then
			error(err, 0)
		end
	end,
}
