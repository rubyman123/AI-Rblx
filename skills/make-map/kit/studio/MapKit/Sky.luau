-- Skyboxes made from CC0 HDRIs (`run.py sky`), and Roblox's sun lined up with the panorama's. Method by fwjelaa (FWJ STUDIOS).
local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")
local Http = require(script.Parent.Http)

local Sky = {}

local FACES = { "Bk", "Dn", "Ft", "Lf", "Rt", "Up" }

local function removedFolder()
	local keep = ServerStorage:FindFirstChild("MapKit_Removed")
	if not keep then
		keep = Instance.new("Folder")
		keep.Name = "MapKit_Removed"
		keep.Parent = ServerStorage
	end
	return keep
end

function Sky.apply(name, manifestPath)
	manifestPath = manifestPath or "assets.json"
	local manifest = Http.json(manifestPath)
	local entry = manifest.skies and manifest.skies[name]
	-- the recorded command keeps --azimuth (without it the sun, and so the light, comes from the wrong side)
	local cmd = entry and entry.remake
		or ("python kit/tools/run.py sky %s --from %s"):format(name, entry and entry.source or "polyhaven:<hdri>_puresky")
	local ids = entry and entry.ids or {}
	local missing = {}
	for _, f in FACES do
		if not ids[f] then
			table.insert(missing, f)
		end
	end
	if #missing == #FACES then
		error(("Sky.apply: no uploaded sky %q in %s; make it with `%s`"):format(name, manifestPath, cmd), 2)
	elseif #missing > 0 then
		error(("Sky.apply: sky %q has no %s face ids yet; record the uploads with `python kit/tools/run.py record-sky %s Bk=rbxassetid://.. Dn=.. Ft=.. Lf=.. Rt=.. Up=..`, or re-make it with `%s`")
			:format(name, table.concat(missing, ", "), name, cmd), 2)
	end
	-- one sky only: the place's own one is moved aside (never deleted)
	for _, c in Lighting:GetChildren() do
		if c:IsA("Sky") and c.Name ~= "MapKit_Sky" then
			c.Parent = removedFolder()
		end
	end
	local sky = Lighting:FindFirstChild("MapKit_Sky") or Instance.new("Sky")
	sky.Name = "MapKit_Sky"
	for _, f in FACES do
		sky["Skybox" .. f] = ids[f]
	end
	sky.CelestialBodiesShown = false -- the panorama has its own sun
	sky.StarCount = 0
	sky.Parent = Lighting
	return entry.sun and Vector3.new(entry.sun[1], entry.sun[2], entry.sun[3]) or nil
end

-- Roblox moves the sun with ClockTime and GeographicLatitude; search both for the direction closest to `dir`
function Sky.matchSun(dir)
	dir = dir.Unit
	local best, bt, bl = -2, Lighting.ClockTime, Lighting.GeographicLatitude
	for lat = -80, 80, 4 do
		for t = 4, 20, 0.25 do
			Lighting.GeographicLatitude, Lighting.ClockTime = lat, t
			local d = Lighting:GetSunDirection():Dot(dir)
			if d > best then
				best, bt, bl = d, t, lat
			end
		end
	end
	for lat = bl - 4, bl + 4, 0.5 do -- refine
		for t = bt - 0.25, bt + 0.25, 0.025 do
			Lighting.GeographicLatitude, Lighting.ClockTime = lat, t
			local d = Lighting:GetSunDirection():Dot(dir)
			if d > best then
				best, bt, bl = d, t, lat
			end
		end
	end
	Lighting.GeographicLatitude, Lighting.ClockTime = bl, bt
	return bt, bl, math.deg(math.acos(math.clamp(best, -1, 1)))
end

return Sky
