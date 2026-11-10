-- Tests for MapKit.QA. Method by fwjelaa (FWJ STUDIOS).
return {
	["validate flags unanchored, grey Plastic and below the floor"] = function(t, K)
		local root = Instance.new("Model")
		root.Parent = t.sandbox
		local a = Instance.new("Part")
		a.Anchored = false
		a.CFrame = CFrame.new(0, 500, 0)
		a.Parent = root
		local b = Instance.new("Part")
		b.Anchored = true
		b.CFrame = CFrame.new(0, -100, 0)
		b.Parent = root
		K.Build.part({ Size = Vector3.one, CFrame = CFrame.new(0, 300, 0), Color = Color3.new(1, 0, 0), Parent = root })
		local r = K.QA.validate(root, { floorY = -30 })
		t.eq(r.errors["unanchored part"].count, 1, "unanchored")
		t.eq(r.errors["part below the floor"].count, 1, "below floor")
		t.eq(r.warnings["default grey Plastic"].count, 2, "grey plastic")
		t.eq(r.stats.parts, 3, "parts")
	end,
	-- Roblox pathfinding sometimes misses freshly built geometry for 4+ s (1 trial in 8, measured 2026-10-24);
	-- rebuilding clears it, so the test builds the scene again once before calling the open spot unreachable
	["walk reaches open ground and not a sealed box"] = function(t, K)
		local walls = {
			{ Vector3.new(22, 12, 1), Vector3.new(40, 406, 29) },
			{ Vector3.new(22, 12, 1), Vector3.new(40, 406, 51) },
			{ Vector3.new(1, 12, 22), Vector3.new(29, 406, 40) },
			{ Vector3.new(1, 12, 22), Vector3.new(51, 406, 40) },
			{ Vector3.new(22, 1, 22), Vector3.new(40, 412.5, 40) },
		}
		local res
		for _ = 1, 2 do
			local scene = Instance.new("Folder")
			scene.Parent = t.sandbox
			K.Build.part({ Size = Vector3.new(160, 2, 160), CFrame = CFrame.new(0, 399, 0), Parent = scene })
			for _, w in walls do
				K.Build.part({ Size = w[1], CFrame = CFrame.new(w[2]), Parent = scene })
			end
			res = K.QA.walk(Vector3.new(-50, 403, -50), {
				{ name = "open", pos = Vector3.new(30, 403, -50) },
				{ name = "boxed", pos = Vector3.new(40, 403, 40) },
			})
			t.ok(not res[2].ok, "boxed spot reachable: " .. res[2].status)
			if res[1].ok then
				break
			end
			scene:Destroy()
			task.wait(0.2)
		end
		t.ok(res[1].ok, "open spot unreachable twice: " .. res[1].status)
	end,
	-- right after a build the navmesh can lag: one NoPath in six full test runs (2026-10-24)
	["walk retries once when pathfinding says NoPath"] = function(t, K)
		local real = K.QA.PathfindingService
		local calls = 0
		K.QA.PathfindingService = {
			CreatePath = function()
				local path = { Status = Enum.PathStatus.NoPath }
				function path:ComputeAsync(_, to)
					calls += 1
					self.Status = calls == 1 and Enum.PathStatus.NoPath or Enum.PathStatus.Success
					self.to = to
				end
				function path:GetWaypoints()
					return self.Status == Enum.PathStatus.Success and { PathWaypoint.new(self.to, Enum.PathWaypointAction.Walk) } or {}
				end
				return path
			end,
		}
		local ok, res = pcall(K.QA.walk, Vector3.zero, { { name = "spot", pos = Vector3.new(0, 0, 50) } })
		K.QA.PathfindingService = real
		t.ok(ok, tostring(res))
		t.ok(res[1].ok, "status " .. tostring(res[1].status))
		t.eq(calls, 2, "computed twice")
	end,
	-- a scanned mesh takes its colour from its SurfaceAppearance; Part.Color does nothing there (measured)
	["validate does not call a textured mesh default grey"] = function(t, K)
		local root = Instance.new("Model")
		root.Parent = t.sandbox
		local mesh = Instance.new("MeshPart")
		mesh.Anchored = true
		mesh.CFrame = CFrame.new(0, 300, 0)
		Instance.new("SurfaceAppearance").Parent = mesh
		mesh.Parent = root
		local plain = Instance.new("Part")
		plain.Anchored = true
		plain.CFrame = CFrame.new(4, 300, 0)
		plain.Parent = root
		local r = K.QA.validate(root)
		local w = r.warnings["default grey Plastic"]
		t.ok(w ~= nil and w.count == 1, "only the plain part: " .. tostring(w and w.count))
	end,
	["validate errors on visible kit parts left without a colour"] = function(t, K)
		local root = Instance.new("Model")
		root.Parent = t.sandbox
		K.Build.part({ Size = Vector3.one, CFrame = CFrame.new(0, 300, 0), Parent = root })
		K.Build.part({ Size = Vector3.one, CFrame = CFrame.new(2, 300, 0), Transparency = 1, Parent = root })
		local r = K.QA.validate(root)
		local e = r.errors["kit part left default grey (no Color)"]
		t.ok(e ~= nil and e.count == 1, "one visible uncoloured part")
	end,
	["a NoPath walk failure tells Claude to re-run before changing the map"] = function(t, K)
		local root = Instance.new("Model")
		root.Parent = t.sandbox
		local text = K.QA.report(K.QA.validate(root), { { name = "far", ok = false, status = "NoPath", length = 0, jumps = 0 } })
		t.ok(string.find(text, "run K.qa again", 1, true) ~= nil, text)
	end,
	["report passes a clean map"] = function(t, K)
		local root = Instance.new("Model")
		root.Parent = t.sandbox
		K.Build.part({ Size = Vector3.one, CFrame = CFrame.new(0, 300, 0), Color = Color3.new(1, 0, 0), Parent = root })
		local text = K.QA.report(K.QA.validate(root), {})
		t.eq(string.sub(text, 1, 7), "QA PASS", text)
	end,
}
