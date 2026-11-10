-- The example maps on a fresh pack (the shipped assets.json has recipes, no ids). Method by fwjelaa (FWJ STUDIOS).

-- the manifest as `run.py zip` ships it: every upload id removed
local function shipped(K)
	local m = K.Http.json("assets.json")
	for _, section in { "materials", "skies" } do
		for _, e in m[section] or {} do
			e.ids = nil
		end
	end
	for _, section in { "models", "sounds" } do
		for _, e in m[section] or {} do
			e.id = nil
		end
	end
	return m
end

-- a phase of a map's build.luau run with the shipped manifest; sound and lighting calls are recorded, not made
local function runPhase(t, K, id, phase)
	local manifest = shipped(K)
	local calls = {}
	local fake = setmetatable({
		Http = setmetatable({
			json = function(path)
				return path == "assets.json" and manifest or K.Http.json(path)
			end,
		}, { __index = K.Http }),
		Sound = {
			ambience = function(_, name, soundId)
				table.insert(calls, { name = name, id = soundId })
			end,
			reverb = function() end,
		},
		Lighting = setmetatable({ preset = function()
			return {}
		end }, { __index = K.Lighting }),
	}, { __index = K })
	local spec = K.Http.json("maps/" .. id .. "/map.json")
	local make = K.Http.module("maps/" .. id .. "/build.luau", id .. "_test", t.sandbox)
	local result = make(fake, spec)[phase]()
	return result, calls
end

return {
	["on a fresh pack each ambience phase names the sound command instead of crashing"] = function(t, K)
		-- review 2026-10-25: the backrooms checked that the hum entry existed, not that it had an id
		for _, case in { { "backrooms-level-0", "run.py hum" }, { "farmhouse-night", "run.py wind" }, { "forest-lake", "run.py wind" } } do
			local ok, result, calls = pcall(runPhase, t, K, case[1], "ambience")
			t.ok(ok, case[1] .. " ambience crashed: " .. tostring(result))
			for _, c in calls or {} do
				t.ok(c.id ~= nil, case[1] .. " started sound " .. tostring(c.name) .. " with no id")
			end
			t.ok(tostring(result):find(case[2], 1, true), case[1] .. " should name `" .. case[2] .. "`: " .. tostring(result))
		end
	end,
}
