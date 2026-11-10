-- Tiny test runner: tests live in kit/studio/tests/<Name>.test.luau. Method by fwjelaa (FWJ STUDIOS).
local ServerStorage = game:GetService("ServerStorage")
local Http = require(script.Parent.Http)

local Test = {}

local function checker(sandbox)
	local t = { sandbox = sandbox }
	function t.ok(cond, msg)
		if not cond then
			error(msg or "expected true", 2)
		end
	end
	function t.eq(got, want, msg)
		if got ~= want then
			error(("%s: want %s, got %s"):format(msg or "eq", tostring(want), tostring(got)), 2)
		end
	end
	function t.near(got, want, eps, msg)
		if type(got) ~= "number" or math.abs(got - want) > (eps or 1e-3) then
			error(("%s: want %.4f, got %s"):format(msg or "near", want, tostring(got)), 2)
		end
	end
	function t.errors(fn, mustMention, msg)
		local ok, err = pcall(fn)
		if ok then
			error(msg or "expected an error", 2)
		end
		if mustMention and not string.find(tostring(err), mustMention, 1, true) then
			error(("%s: error %q does not mention %q"):format(msg or "errors", tostring(err), mustMention), 2)
		end
	end
	-- call before a test writes terrain: the place's terrain belongs to the user, so a test only uses empty cells
	function t.emptyTerrain(cf, size)
		local region = Region3.new(cf.Position - size / 2, cf.Position + size / 2):ExpandToGrid(4)
		local ch = workspace.Terrain:ReadVoxelChannels(region, 4, { "SolidMaterial", "LiquidOccupancy" })
		for x = 1, #ch.SolidMaterial do
			for y = 1, #ch.SolidMaterial[x] do
				for z = 1, #ch.SolidMaterial[x][y] do
					if ch.SolidMaterial[x][y][z] ~= Enum.Material.Air or ch.LiquidOccupancy[x][y][z] > 0 then
						error(("the test area at %s already holds terrain (the place's own?); the test won't touch it. Run K.test in a fresh Baseplate place.")
							:format(tostring(cf.Position)), 2)
					end
				end
			end
		end
	end
	return t
end

function Test.run(K, names)
	local holder = Instance.new("Folder")
	holder.Name = "MapKitTests"
	holder.Parent = ServerStorage
	local lines, passed, total = {}, 0, 0
	for _, name in names do
		local ok, cases = pcall(Http.module, "kit/studio/tests/" .. name .. ".test.luau", name, holder)
		if not ok then
			total += 1
			table.insert(lines, ("FAIL %s (load): %s"):format(name, tostring(cases)))
			continue
		end
		local order = {}
		for caseName in cases do
			table.insert(order, caseName)
		end
		table.sort(order)
		for _, caseName in order do
			total += 1
			local sandbox = Instance.new("Folder")
			sandbox.Name = "_MapKitTest"
			sandbox.Parent = workspace
			local okCase, err = pcall(cases[caseName], checker(sandbox), K)
			sandbox:Destroy()
			if okCase then
				passed += 1
			else
				table.insert(lines, ("FAIL %s / %s: %s"):format(name, caseName, tostring(err)))
			end
		end
	end
	holder:Destroy()
	table.insert(lines, 1, ("%d/%d passed"):format(passed, total))
	return table.concat(lines, "\n")
end

return Test
