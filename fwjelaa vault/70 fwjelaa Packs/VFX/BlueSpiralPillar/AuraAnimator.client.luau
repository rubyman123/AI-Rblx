-- StarterPlayer.StarterPlayerScripts.AuraAnimator (LocalScript)
-- Client-side motion for every model tagged "Aura" (character auras + showcase copies).
-- Each animated part is held by a Weld named "AuraWeld" to the model's AuraRoot; we only rewrite Weld.C0.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local MAX_DISTANCE = 200 -- skip auras the camera can't really see
local TAU = math.pi * 2

local auras = {}

local function phaseOf(name)
	local n = tonumber(string.match(name, "%d+")) or 0
	return n * 1.618
end

local function register(model)
	if auras[model] then
		return
	end
	local root = model:WaitForChild("AuraRoot", 10)
	if not root or not model.Parent then
		return
	end
	local scale = model:GetAttribute("AuraScale") or 1
	local s = { root = root, scale = scale, spin = {}, crystals = {}, orbit = {}, rings = {}, bills = {}, beams = {}, images = {} }
	local crystalParts = {}

	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Weld") and d.Name == "AuraWeld" and d.Part1 then
			local p = d.Part1
			local parentName = p.Parent and p.Parent.Name or ""
			local e = { weld = d, base = d.C0, phase = phaseOf(p.Name) }
			if parentName == "Spiral" then
				e.speed, e.bob = 1.35, 0.3
				table.insert(s.spin, e)
			elseif p.Name == "Claws" or p.Name == "ClawsOuter" then
				e.speed, e.bob = (p.Name == "Claws") and -0.8 or 0.5, 0
				table.insert(s.spin, e)
			elseif parentName == "Halo" then
				e.speed, e.bob = 0.9, 0.25
				table.insert(s.spin, e)
			elseif p.Parent and p.Parent:IsA("Model") and p.Parent.Parent and p.Parent.Parent.Name == "Crystals" then
				crystalParts[p.Parent] = crystalParts[p.Parent] or {}
				table.insert(crystalParts[p.Parent], e)
			elseif parentName == "Claws" then
				e.speed, e.bob, e.kind = 0.55, 0.35, "hook"
				table.insert(s.orbit, e)
			elseif parentName == "Stars" then
				e.speed, e.bob, e.kind = -0.35, 0.2, "star"
				table.insert(s.orbit, e)
			elseif string.match(p.Name, "^GroundRing") then
				e.part, e.baseT = p, p.Transparency
				table.insert(s.rings, e)
			end
		elseif d:IsA("BillboardGui") then
			local img = d:FindFirstChild("Image")
			table.insert(s.bills, { gui = d, base = d.Size, phase = phaseOf(d.Parent.Name) + #s.bills, img = img, rot = img and img.Rotation })
		elseif d:IsA("Beam") and d.Parent and d.Parent.Name == "PillarBase" then
			table.insert(s.beams, { beam = d, w0 = d.Width0, w1 = d.Width1 })
		elseif d:IsA("ImageLabel") and d.Parent and d.Parent:IsA("SurfaceGui") then
			table.insert(s.images, { img = d, baseSize = d.Size, baseT = d.ImageTransparency })
		end
	end

	-- crystals spin around their own centre, so find each crystal's centre in root space
	for crystal, list in pairs(crystalParts) do
		local sum = Vector3.zero
		for _, e in ipairs(list) do
			sum += e.base.Position
		end
		table.insert(s.crystals, { parts = list, center = sum / #list, phase = phaseOf(crystal.Name) })
	end

	auras[model] = s
end

local function unregister(model)
	auras[model] = nil
end

CollectionService:GetInstanceAddedSignal("Aura"):Connect(function(m)
	task.spawn(register, m)
end)
CollectionService:GetInstanceRemovedSignal("Aura"):Connect(unregister)
for _, m in ipairs(CollectionService:GetTagged("Aura")) do
	task.spawn(register, m)
end

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	local camPos = workspace.CurrentCamera.CFrame.Position
	for model, s in pairs(auras) do
		if not model.Parent or not s.root.Parent then
			auras[model] = nil
			continue
		end
		if (s.root.Position - camPos).Magnitude > MAX_DISTANCE then
			continue
		end
		local k = s.scale

		for _, e in ipairs(s.spin) do
			e.weld.C0 = CFrame.new(0, math.sin(t * 1.3 + e.phase) * e.bob * k, 0)
				* CFrame.Angles(0, (t * e.speed) % TAU, 0) * e.base
		end

		for _, c in ipairs(s.crystals) do
			local orbit = CFrame.Angles(0, (t * 0.3) % TAU, 0)
			local bob = CFrame.new(0, math.sin(t * 1.7 + c.phase) * 0.45 * k, 0)
			local spin = CFrame.new(c.center) * CFrame.Angles(0, (t * 1.2 + c.phase) % TAU, 0) * CFrame.new(-c.center)
			for _, e in ipairs(c.parts) do
				e.weld.C0 = orbit * bob * spin * e.base
			end
		end

		for _, e in ipairs(s.orbit) do
			e.weld.C0 = CFrame.Angles(0, (t * e.speed + e.phase * 0.1) % TAU, 0)
				* CFrame.new(0, math.sin(t * 2 + e.phase) * e.bob * k, 0) * e.base
		end

		-- outward pulse wave across the ground rings
		for i, e in ipairs(s.rings) do
			local wave = 0.5 + 0.5 * math.sin(t * 3 - i * 0.9)
			e.part.Transparency = math.clamp(e.baseT - 0.15 + wave * 0.35, 0, 1)
		end

		for _, b in ipairs(s.bills) do
			local tw = 0.75 + 0.25 * math.sin(t * 3.1 + b.phase)
			b.gui.Size = UDim2.new(b.base.X.Scale * tw, 0, b.base.Y.Scale * tw, 0)
			if b.img then
				b.img.Rotation = b.rot + math.sin(t * 2.2 + b.phase) * 14
			end
		end

		local pulse = 1 + 0.15 * math.sin(t * 4)
		for _, b in ipairs(s.beams) do
			b.beam.Width0 = b.w0 * pulse
			b.beam.Width1 = b.w1 * pulse
		end

		for _, im in ipairs(s.images) do
			if im.img.Name == "Swirl" then
				im.img.Rotation = (t * 40) % 360
			elseif im.img.Name == "Ripple1" then
				local g = (t * 0.6) % 1
				im.img.Size = UDim2.fromScale(im.baseSize.X.Scale * (0.6 + g), im.baseSize.Y.Scale * (0.6 + g))
				im.img.ImageTransparency = im.baseT + (1 - im.baseT) * g
			elseif im.img.Name == "Glow" then
				im.img.ImageTransparency = im.baseT + 0.12 * math.sin(t * 2.5)
			end
		end
	end
end)
