-- MapKit: build Roblox maps from code. Method by fwjelaa (FWJ STUDIOS). See CREDITS.md.
--   local K = require(game.ServerStorage.MapKit.MapKit)
--   K.test({"Geo"})                    -- run kit/studio/tests/Geo.test.luau
local MapKit = {}
local folder = script.Parent
MapKit.version = folder:GetAttribute("Version") or "dev"

for _, m in folder:GetChildren() do
	if m:IsA("ModuleScript") and m ~= script then
		MapKit[m.Name] = require(m)
	end
end

function MapKit.test(names)
	return MapKit.Test.run(MapKit, names)
end

local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local function v3(t)
	return Vector3.new(t[1], t[2], t[3])
end

-- Run one phase of maps/<id>/build.luau with that map's spec. Phases clear their own layers first, so
-- running one again (after a fix or a dropped connection) never duplicates anything.
function MapKit.run(id, phase)
	local spec = MapKit.Http.json("maps/" .. id .. "/map.json")
	local holder = ServerStorage:FindFirstChild("MapKitMaps")
	if not holder then
		holder = Instance.new("Folder")
		holder.Name = "MapKitMaps"
		holder.Parent = ServerStorage
	end
	local old = holder:FindFirstChild(id)
	if old then
		old:Destroy()
	end
	local make = MapKit.Http.module("maps/" .. id .. "/build.luau", id, holder)
	local phases = make(MapKit, spec)
	local fn = phases[phase]
	if not fn then
		local names = {}
		for k in phases do
			table.insert(names, k)
		end
		table.sort(names)
		error(("map %s has no phase %q (phases: %s)"):format(id, tostring(phase), table.concat(names, ", ")), 0)
	end
	local okRec, rec = pcall(ChangeHistoryService.TryBeginRecording, ChangeHistoryService, "MapKit " .. id .. " " .. phase)
	local ok, result = pcall(fn)
	if okRec and rec then
		ChangeHistoryService:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
	end
	if not ok then
		error(("map %s phase %s failed: %s"):format(id, phase, tostring(result)), 0)
	end
	MapKit.Root.get(id):SetAttribute("Done_" .. phase, DateTime.now():ToIsoDate())
	return result or (id .. " " .. phase .. " done")
end

-- Park Studio's real camera at one of the map's shots, then call screen_capture with NO camera arguments.
-- screen_capture's own camera grabs the frame before Roblox lights the spot: lit rooms come out dark.
function MapKit.shot(id, name, wait)
	local spec = MapKit.Http.json("maps/" .. id .. "/map.json")
	local names = {}
	for _, s in spec.shots or {} do
		if s.name == name then
			local cam = workspace.CurrentCamera
			cam.CFrame = CFrame.lookAt(v3(s.cam), v3(s.look))
			cam.Focus = CFrame.new(v3(s.look))
			task.wait(wait or 1)
			return ("camera at %s %s: now screen_capture with no camera arguments"):format(id, name)
		end
		table.insert(names, s.name)
	end
	error(("map %s has no shot %q (shots: %s)"):format(id, tostring(name), table.concat(names, ", ")), 0)
end

-- Validator + walk test for a built map, as text.
function MapKit.qa(id)
	local spec = MapKit.Http.json("maps/" .. id .. "/map.json")
	local v = MapKit.QA.validate(MapKit.Root.get(id), { floorY = spec.floorY or -30 })
	local pois = {}
	for _, p in spec.pois or {} do
		table.insert(pois, { name = p.name, pos = v3(p.pos) })
	end
	-- realistic maps size the walker to their doors ("agent": {"radius", "height"}); default fits 8-wide doors
	local agent = spec.agent and {
		AgentRadius = spec.agent.radius or 2,
		AgentHeight = spec.agent.height or 5,
		AgentCanJump = true,
		WaypointSpacing = 4,
	}
	return MapKit.QA.report(v, MapKit.QA.walk(v3(spec.spawn), pois, agent))
end

return MapKit
