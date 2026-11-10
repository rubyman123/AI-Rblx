-- Tests for MapKit.run and MapKit.qa. Method by fwjelaa (FWJ STUDIOS).
local function cleanup()
	local r = workspace:FindFirstChild("Map__test")
	if r then
		r:Destroy()
	end
end

return {
	["running a phase twice keeps three parts"] = function(t, K)
		cleanup()
		local ok, err = pcall(function()
			K.run("_test", "three")
			K.run("_test", "three")
			t.eq(#K.Root.layer("_test", "Props"):GetChildren(), 3, "parts after two runs")
			t.ok(K.Root.get("_test"):GetAttribute("Done_three") ~= nil, "done marker")
		end)
		cleanup()
		if not ok then
			error(err, 0)
		end
	end,
	["a failing phase names the map, the phase and the cause"] = function(t, K)
		cleanup()
		local ok, err = pcall(K.run, "_test", "boom")
		cleanup()
		t.ok(not ok, "should fail")
		err = tostring(err)
		t.ok(string.find(err, "_test", 1, true) and string.find(err, "boom on purpose", 1, true), "message: " .. err)
	end,
	["an unknown phase lists the real ones"] = function(t, K)
		cleanup()
		local ok, err = pcall(K.run, "_test", "nope")
		cleanup()
		t.ok(not ok and string.find(tostring(err), "three", 1, true) ~= nil, "lists phases: " .. tostring(err))
	end,
	["shot parks the real camera at a named view"] = function(t, K)
		local cam = workspace.CurrentCamera
		local before = cam.CFrame
		local ok, err = pcall(function()
			K.shot("_test", "top", 0)
			t.near((cam.CFrame.Position - Vector3.new(0, 320, 40)).Magnitude, 0, 1e-3, "camera position")
			local want = (Vector3.new(0, 300, 0) - Vector3.new(0, 320, 40)).Unit
			t.near((cam.CFrame.LookVector - want).Magnitude, 0, 1e-3, "looks at the target")
		end)
		cam.CFrame = before
		if not ok then
			error(err, 0)
		end
	end,
	["an unknown shot lists the real ones"] = function(t, K)
		t.errors(function()
			K.shot("_test", "nope", 0)
		end, "top")
	end,
	-- realistic maps have 4-stud doors: the walk agent comes from the map (a real avatar is about 2 studs wide)
	["qa walks with the map's agent size"] = function(t, K)
		local real = K.QA.walk
		local seen
		K.QA.walk = function(from, pois, agent)
			seen = agent
			return {}
		end
		local ok, err = pcall(K.qa, "_test")
		K.QA.walk = real
		t.ok(ok, tostring(err))
		t.ok(seen ~= nil, "an agent was passed")
		t.eq(seen and seen.AgentRadius, 1.25, "radius")
		t.eq(seen and seen.AgentHeight, 5.5, "height")
	end,
	["qa reports on the test map"] = function(t, K)
		cleanup()
		local ok, err = pcall(function()
			K.run("_test", "three")
			local text = K.qa("_test")
			t.eq(string.sub(text, 1, 7), "QA PASS", text)
		end)
		cleanup()
		if not ok then
			error(err, 0)
		end
	end,
}
