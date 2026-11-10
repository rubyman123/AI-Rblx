-- Tests for MapKit.Sky (skyboxes from HDRIs, sun matched to the panorama). Method by fwjelaa (FWJ STUDIOS).
local Lighting = game:GetService("Lighting")

local function snapshot()
	local s = { time = Lighting.ClockTime, lat = Lighting.GeographicLatitude, skies = {} }
	for _, c in Lighting:GetChildren() do
		if c:IsA("Sky") then
			table.insert(s.skies, c)
			c.Parent = nil
		end
	end
	return s
end

local function restore(s)
	for _, c in Lighting:GetChildren() do
		if c:IsA("Sky") then
			c:Destroy()
		end
	end
	local removed = game:GetService("ServerStorage"):FindFirstChild("MapKit_Removed")
	local probe = removed and removed:FindFirstChild("UserSky")
	if probe then
		probe:Destroy()
	end
	for _, c in s.skies do
		c.Parent = Lighting
	end
	Lighting.ClockTime, Lighting.GeographicLatitude = s.time, s.lat
end

return {
	["apply sets the six faces and keeps the place's own sky"] = function(t, K)
		local s = snapshot()
		local ok, err = pcall(function()
			local mine = Instance.new("Sky")
			mine.Name = "UserSky"
			mine.Parent = Lighting
			K.Sky.apply("kit_test_sky", "maps/_test/assets.json")
			local sky = Lighting:FindFirstChild("MapKit_Sky")
			t.ok(sky ~= nil, "sky made")
			t.eq(sky.SkyboxFt, "rbxassetid://102", "Ft")
			t.eq(sky.SkyboxUp, "rbxassetid://105", "Up")
			t.eq(sky.CelestialBodiesShown, false, "the panorama has its own sun")
			t.eq(mine.Parent and mine.Parent.Name, "MapKit_Removed", "the user's sky is kept, not deleted")
		end)
		restore(s)
		if not ok then
			error(err, 0)
		end
	end,
	["a sky without ids names the command that makes it"] = function(t, K)
		t.errors(function()
			K.Sky.apply("no_such_sky", "maps/_test/assets.json")
		end, "run.py sky no_such_sky")
	end,
	["a sky without ids names its recorded command, azimuth included"] = function(t, K)
		-- review 2026-10-25: the error rebuilt the command from the source and dropped --azimuth
		t.errors(function()
			K.Sky.apply("kit_test_sky_noid", "maps/_test/assets.json")
		end, "--azimuth -40")
	end,
	["a sky with faces missing changes nothing and names the faces"] = function(t, K)
		local s = snapshot()
		local ok, err = pcall(function()
			t.errors(function()
				K.Sky.apply("kit_test_sky_half", "maps/_test/assets.json")
			end, "Bk, Dn, Lf, Rt")
			t.eq(Lighting:FindFirstChild("MapKit_Sky"), nil, "no half-made sky")
		end)
		restore(s)
		if not ok then
			error(err, 0)
		end
	end,
	["matchSun puts Roblox's sun where the panorama's is"] = function(t, K)
		local s = snapshot()
		local ok, err = pcall(function()
			Lighting.GeographicLatitude, Lighting.ClockTime = 30, 16.5
			local want = Lighting:GetSunDirection()
			Lighting.GeographicLatitude, Lighting.ClockTime = 0, 12
			K.Sky.matchSun(want)
			local got = Lighting:GetSunDirection()
			t.ok(math.deg(math.acos(math.clamp(got:Dot(want), -1, 1))) < 6, ("within 6 degrees: want %s got %s"):format(tostring(want), tostring(got)))
		end)
		restore(s)
		if not ok then
			error(err, 0)
		end
	end,
}
