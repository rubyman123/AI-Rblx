-- Office Floor 14: the director. Lightning, failing lights, and the things that happen when you are alone on
-- the floor (MapKit by fwjelaa). Runs on each client; only the stair door slam goes through the server.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")

local folder = RS:WaitForChild("Office14")
local Config = require(folder:WaitForChild("Config"))
local Event = folder:WaitForChild("Event")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local map = workspace:WaitForChild(Config.map, 30)
local rng = Random.new()

------------------------------------------------------------------ sound
local function sfx(name, at, volume, speed, maxDist)
	local r = Config.regions[name]
	if not r or Config.sfx == "" then
		return nil
	end
	local parent = at
	local holder
	if typeof(at) == "Vector3" then
		holder = Instance.new("Attachment")
		holder.WorldPosition = at
		holder.Parent = workspace.Terrain
		parent = holder
	end
	local s = Instance.new("Sound")
	s.SoundId = Config.sfx
	s.PlaybackRegionsEnabled = true
	s.PlaybackRegion = NumberRange.new(r[1], r[2])
	s.Volume = volume or 0.8
	s.PlaybackSpeed = speed or 1
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 5
	s.RollOffMaxDistance = maxDist or 80
	s.Parent = parent or game:GetService("SoundService")
	s:Play()
	task.delay((r[2] - r[1]) / (speed or 1) + 0.3, function()
		s:Destroy()
		if holder then
			holder:Destroy()
		end
	end)
	return s
end

local function rootPart()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end
local function inRect(p, x0, z0, x1, z1)
	return p and p.X >= x0 and p.X <= x1 and p.Z >= z0 and p.Z <= z1
end
local function tagged(tag, fn)
	for _, i in CollectionService:GetTagged(tag) do
		task.spawn(fn, i)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(fn)
end

------------------------------------------------------------------ lights that fail
-- a fixture: its Light objects and its glowing parts, switched together
local function fixture(inst)
	local lights, glows = {}, {}
	local list = inst:IsA("BasePart") and { inst } or {}
	for _, d in inst:GetDescendants() do
		table.insert(list, d)
	end
	for _, d in list do
		if d:IsA("Light") then
			table.insert(lights, { l = d, b = d.Brightness })
		elseif d:IsA("BasePart") and d.Material == Enum.Material.Neon then
			table.insert(glows, { p = d, c = d.Color })
		end
	end
	local f = { lights = lights, glows = glows, on = true }
	function f.set(v, level)
		f.on = v
		for _, l in lights do
			l.l.Enabled = v
			l.l.Brightness = l.b * (level or 1)
		end
		for _, g in glows do
			g.p.Material = v and Enum.Material.Neon or Enum.Material.SmoothPlastic
			g.p.Color = v and g.c or Color3.fromRGB(150, 150, 146)
		end
	end
	return f
end
local fixtures = {}
local function getFixture(inst)
	fixtures[inst] = fixtures[inst] or fixture(inst)
	return fixtures[inst]
end

local held = {} -- fixtures a scare has switched off: the flicker loop leaves them alone
tagged("OfcFlicker", function(inst)
	local f = getFixture(inst)
	local pos = inst:IsA("Model") and inst:GetPivot().Position or inst.Position
	while inst.Parent do
		task.wait(rng:NextNumber(1.5, 9))
		if not held[inst] then
			local bursts = rng:NextInteger(2, 9)
			if rng:NextNumber() < 0.35 then
				sfx("light_buzz", pos, 0.22, rng:NextNumber(0.9, 1.1), 26)
			end
			for _ = 1, bursts do
				f.set(false)
				task.wait(rng:NextNumber(0.03, 0.16))
				f.set(true, rng:NextNumber(0.5, 1))
				task.wait(rng:NextNumber(0.03, 0.22))
			end
			f.set(true)
			if rng:NextNumber() < 0.15 then -- dead for a while
				f.set(false)
				sfx("light_click", pos, 0.4, 1, 30)
				task.wait(rng:NextNumber(4, 14))
				f.set(true)
			end
		end
	end
end)
tagged("OfcSoftFlicker", function(inst)
	local f = getFixture(inst)
	while inst.Parent do
		task.wait(rng:NextNumber(12, 35))
		for _ = 1, rng:NextInteger(1, 3) do
			f.set(true, 0.25)
			task.wait(rng:NextNumber(0.05, 0.12))
			f.set(true)
			task.wait(rng:NextNumber(0.1, 0.4))
		end
	end
end)
tagged("OfcBlink", function(p)
	while p.Parent do
		p.Transparency = 0
		task.wait(0.12)
		p.Transparency = 1
		task.wait(rng:NextNumber(2.5, 4))
	end
end)
tagged("OfcBlinkText", function(t)
	while t.Parent do
		t.TextTransparency = 0
		task.wait(0.7)
		t.TextTransparency = 1
		task.wait(0.5)
	end
end)
tagged("OfcBeacon", function(p)
	local phase = rng:NextNumber(0, 2)
	task.wait(phase)
	while p.Parent do
		p.Transparency = 0
		task.wait(0.9)
		p.Transparency = 0.85
		task.wait(1.1)
	end
end)
tagged("OfcVending", function(m)
	local f = getFixture(m)
	while m.Parent do
		task.wait(rng:NextNumber(8, 26))
		for _ = 1, rng:NextInteger(1, 4) do
			f.set(true, 0.55)
			task.wait(0.06)
			f.set(true)
			task.wait(rng:NextNumber(0.05, 0.3))
		end
	end
end)

------------------------------------------------------------------ screens, static, rain on the glass
local statics, rains, bounces, typers = {}, {}, {}, {}
tagged("OfcStatic", function(i)
	i.Size = UDim2.fromScale(1.6, 1.6)
	table.insert(statics, i)
end)
tagged("OfcRainGlass", function(t)
	table.insert(rains, t)
end)
tagged("OfcScreen", function(p)
	local b = p:FindFirstChild("Bounce", true)
	if b then
		table.insert(bounces, { l = b, v = Vector2.new(0.07, 0.05) })
	end
end)
tagged("OfcTyping", function(t)
	table.insert(typers, t)
end)
local acc = 0
RunService.RenderStepped:Connect(function(dt)
	acc += dt
	if acc > 0.05 then
		acc = 0
		for _, i in statics do
			i.Position = UDim2.fromOffset(-rng:NextInteger(0, 64), -rng:NextInteger(0, 64))
		end
	end
	for _, t in rains do
		t.OffsetStudsV = (t.OffsetStudsV + dt * 0.35) % 7
	end
	for _, b in bounces do
		local p = b.l.Position
		local x, y = p.X.Scale + b.v.X * dt, p.Y.Scale + b.v.Y * dt
		if x < 0 or x > 0.6 then
			b.v = Vector2.new(-b.v.X, b.v.Y)
		end
		if y < 0 or y > 0.8 then
			b.v = Vector2.new(b.v.X, -b.v.Y)
		end
		b.l.Position = UDim2.fromScale(math.clamp(x, 0, 0.6), math.clamp(y, 0, 0.8))
	end
end)
-- the unsent email types itself again when you come near
task.spawn(function()
	while true do
		task.wait(0.5)
		local r = rootPart()
		for _, t in typers do
			local part = t:FindFirstAncestorWhichIsA("BasePart")
			if r and part and (part.Position - r.Position).Magnitude < 12 and not t:GetAttribute("Typing") then
				t:SetAttribute("Typing", true)
				task.spawn(function()
					local full = t:GetAttribute("Full") or t.Text
					for i = 1, #full do
						t.Text = full:sub(1, i) .. "|"
						task.wait(full:sub(i, i) == "\n" and 0.6 or rng:NextNumber(0.03, 0.12))
					end
					for _ = 1, 8 do
						t.Text = full .. "|"
						task.wait(0.5)
						t.Text = full
						task.wait(0.5)
					end
					task.wait(20)
					t:SetAttribute("Typing", nil)
				end)
			end
		end
	end
end)

------------------------------------------------------------------ lightning
-- the windows throw the flash into the room; the moon (behind the storm) spikes for a few frames
local flashLights = {}
if map then
	for _, g in map:GetDescendants() do
		if g:IsA("BasePart") and g.Name == "Glass" and g.Parent.Name:sub(1, 7) == "Facade_" then
			local tex = g:FindFirstChildOfClass("Texture")
			local outFace = tex and tex.Face or Enum.NormalId.Front
			local l = Instance.new("SurfaceLight")
			l.Face = outFace == Enum.NormalId.Front and Enum.NormalId.Back or Enum.NormalId.Front
			l.Range = 38
			l.Angle = 100
			l.Brightness = 0
			l.Color = Color3.fromRGB(205, 220, 255)
			l.Shadows = true
			l.Parent = g
			table.insert(flashLights, l)
		end
	end
end
local watcher = map and map:FindFirstChild("Watcher", true)

-- something that only exists while the sky is lit
local shade = Instance.new("Model")
shade.Name = "Shade"
local function sp(cf, size, shape)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, true
	p.Material = Enum.Material.SmoothPlastic
	p.Color = Color3.fromRGB(4, 4, 5)
	p.Size = size
	p.CFrame = cf
	if shape then
		p.Shape = shape
	end
	p.Transparency = 1
	p.Parent = shade
	return p
end
sp(CFrame.new(0, 3.3, 0), Vector3.new(1.7, 3.0, 0.7))
sp(CFrame.new(0, 5.4, 0), Vector3.new(0.95, 1.1, 0.95), Enum.PartType.Ball)
for _, sx in { -1, 1 } do
	sp(CFrame.new(sx * 1.05, 3.1, 0) * CFrame.Angles(0, 0, math.rad(sx * 3)), Vector3.new(0.38, 3.4, 0.38))
	sp(CFrame.new(sx * 0.45, 1.0, 0), Vector3.new(0.5, 2.1, 0.55))
end
shade.WorldPivot = CFrame.new(0, 0, 0)
shade.Parent = workspace
local lastShade = 0
local function showShade(v)
	for _, p in shade:GetChildren() do
		p.Transparency = v and 0 or 1
	end
end
local function placeShade()
	local r = rootPart()
	if not r or os.clock() - lastShade < 100 or rng:NextNumber() > 0.4 then
		return false
	end
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.3 then
		return false
	end
	flat = flat.Unit
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, shade }
	for _ = 1, 12 do
		local ang = math.rad(rng:NextNumber(-22, 22))
		local dir = (CFrame.Angles(0, ang, 0) * flat)
		local dist = rng:NextNumber(26, 55)
		local eye = camera.CFrame.Position
		local target = Vector3.new(r.Position.X, 0, r.Position.Z) + dir * dist
		local seen = workspace:Raycast(eye, (target + Vector3.new(0, 4, 0)) - eye, params)
		local floor = workspace:Raycast(target + Vector3.new(0, 4, 0), Vector3.new(0, -6, 0), params)
		if not seen and floor and floor.Position.Y > -0.5 and floor.Position.Y < 0.5 then
			shade:PivotTo(CFrame.lookAt(target, Vector3.new(r.Position.X, 0, r.Position.Z)))
			lastShade = os.clock()
			return true
		end
	end
	return false
end

local function flash()
	local baseB = Lighting:GetAttribute("OfcBaseBrightness") or Lighting.Brightness
	local baseE = Lighting:GetAttribute("OfcBaseExposure") or Lighting.ExposureCompensation
	local baseO = Lighting:GetAttribute("OfcBaseOutdoor") or Lighting.OutdoorAmbient
	local withShade = placeShade()
	for i = 1, rng:NextInteger(2, 4) do
		local k = rng:NextNumber(0.6, 1)
		Lighting.Brightness = 7 * k
		Lighting.ExposureCompensation = baseE + 0.5 * k
		Lighting.OutdoorAmbient = Color3.fromRGB(170, 180, 210)
		for _, l in flashLights do
			l.Brightness = 3.2 * k
		end
		if withShade and i == 1 then
			showShade(true)
		end
		task.wait(rng:NextNumber(0.04, 0.1))
		Lighting.Brightness = baseB
		Lighting.ExposureCompensation = baseE
		Lighting.OutdoorAmbient = baseO
		for _, l in flashLights do
			l.Brightness = 0
		end
		showShade(false)
		task.wait(rng:NextNumber(0.05, 0.25))
	end
	if watcher and rng:NextNumber() < 0.5 then
		local hide = watcher:GetAttribute("Hidden") ~= true
		for _, p in watcher:GetDescendants() do
			if p:IsA("BasePart") then
				p.Transparency = hide and 1 or 0
			end
		end
		watcher:SetAttribute("Hidden", hide)
	end
end
task.spawn(function()
	task.wait(rng:NextNumber(8, 15))
	while true do
		flash()
		local delay = rng:NextNumber(0.3, 3.5)
		task.wait(delay)
		local kind = delay < 1.0 and "thunder_near" or (delay < 2.2 and "thunder_mid" or "thunder_far")
		sfx(kind, nil, delay < 1.0 and 0.95 or 0.7, rng:NextNumber(0.9, 1.05))
		task.wait(rng:NextNumber(20, 60))
	end
end)

------------------------------------------------------------------ the floor's little events
local function after(cond, fn, rearm)
	task.spawn(function()
		while true do
			task.wait(0.4)
			local r = rootPart()
			if r and cond(r.Position) then
				fn(r)
				if not rearm then
					return
				end
				task.wait(rearm)
			end
		end
	end)
end

-- 1. a desk phone rings across the open plan; it stops the moment you get close
after(function(p)
	return inRect(p, 14, -44, 56, 12)
end, function()
	local phone = CollectionService:GetTagged("OfcRingPhone")[1]
	if not phone then
		return
	end
	task.wait(rng:NextNumber(3, 8))
	local body = phone.PrimaryPart or phone:FindFirstChildWhichIsA("BasePart")
	local display
	for _, d in phone:GetDescendants() do
		if d:IsA("BasePart") and d.Name:sub(1, 7) == "display" then
			display = d
		end
	end
	local pos = phone:GetPivot().Position
	for _ = 1, 7 do
		local r = rootPart()
		if r and (r.Position - pos).Magnitude < 5 then
			sfx("light_click", pos, 0.6, 0.8, 20)
			break
		end
		if display then
			display.Material = Enum.Material.Neon
			display.Color = Color3.fromRGB(120, 255, 140)
		end
		local s = sfx("phone_ring", body or pos, 0.9, 1, 90)
		task.wait(2.0)
		if display then
			display.Material = Enum.Material.SmoothPlastic
			display.Color = Color3.fromRGB(27, 34, 25)
		end
		task.wait(1.9)
		if s then
			s:Stop()
		end
	end
	if display then
		display.Material = Enum.Material.SmoothPlastic
		display.Color = Color3.fromRGB(27, 34, 25)
	end
end, 240)

-- 2. the empty elevator: after you've been away a while, it arrives as you come back
local awaySince
after(function(p)
	if (p - Vector3.new(0, 0, 30)).Magnitude > 45 then
		awaySince = awaySince or os.clock()
		return false
	end
	return awaySince and os.clock() - awaySince > 75 and p.Z > 20 and math.abs(p.X) < 12
end, function()
	awaySince = nil
	local e = map and map:FindFirstChild("Elevator1", true)
	local car = map and map:FindFirstChild("Car1", true)
	if not e then
		return
	end
	local ind = e:FindFirstChild("Indicator1")
	local label = ind and ind:FindFirstChildWhichIsA("TextLabel", true)
	for _, n in { "11", "12", "13" } do
		if label then
			label.Text = "▲ " .. n
		end
		task.wait(1.1)
	end
	if label then
		label.Text = "14"
	end
	sfx("elevator_ding", Vector3.new(-5, 9, 35), 0.9, 1, 70)
	task.wait(0.8)
	local panel = car and car:FindFirstChild("CarLight")
	local carLight = panel and panel:FindFirstChildWhichIsA("Light")
	if panel and carLight then
		panel.Material = Enum.Material.Neon
		panel.Color = Color3.fromRGB(238, 243, 255)
		carLight.Brightness = 1.4
	end
	sfx("elevator_doors", Vector3.new(-5, 4, 35.5), 0.7, 1, 50)
	local leaves = {}
	for _, n in { "LeafL", "LeafR" } do
		local l = e:FindFirstChild(n)
		if l then
			table.insert(leaves, l)
			local closed = l.CFrame
			local dx = n == "LeafL" and -2.1 or 2.1
			TweenService:Create(l, TweenInfo.new(2.4, Enum.EasingStyle.Sine), { CFrame = closed + Vector3.new(dx, 0, 0) }):Play()
			l:SetAttribute("Shut", closed)
		end
	end
	task.wait(8)
	sfx("elevator_doors", Vector3.new(-5, 4, 35.5), 0.6, 0.95, 50)
	for _, l in leaves do
		TweenService:Create(l, TweenInfo.new(2.4, Enum.EasingStyle.Sine), { CFrame = l:GetAttribute("Shut") }):Play()
	end
	task.wait(2.6)
	if panel and carLight then
		panel.Material = Enum.Material.SmoothPlastic
		panel.Color = Color3.fromRGB(154, 156, 158)
		carLight.Brightness = 0
	end
end, 300)

-- 3. the printer wakes up as you walk into the print room
after(function(p)
	return inRect(p, -24, 18, -12, 36)
end, function()
	task.wait(1.4)
	local printer = map and map:FindFirstChild("Printer", true)
	if not printer then
		return
	end
	local pos = printer:GetPivot().Position + Vector3.new(0, 2, 0)
	sfx("printer", pos, 0.85, 1, 40)
	local led
	for _, d in printer:GetDescendants() do
		if d:IsA("BasePart") and d.Name:sub(1, 3) == "led" then
			led = d
		end
	end
	task.spawn(function()
		for _ = 1, 14 do
			if led then
				led.Transparency = led.Transparency == 0 and 0.8 or 0
			end
			task.wait(0.3)
		end
		if led then
			led.Transparency = 0
		end
	end)
	task.wait(5.4)
	-- a page comes out
	local cf = printer:GetPivot()
	local page = Instance.new("Part")
	page.Size = Vector3.new(0.75, 0.01, 1.05)
	page.Color = Color3.fromRGB(236, 234, 227)
	page.Material = Enum.Material.SmoothPlastic
	page.Anchored, page.CanCollide = true, false
	page.CFrame = cf * CFrame.new(0, 2.45, 0.3)
	page.Parent = workspace
	TweenService:Create(page, TweenInfo.new(1.1), { CFrame = cf * CFrame.new(0, 2.43, -0.9) }):Play()
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Top
	g.Parent = page
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.TextScaled = true
	t.Font = Enum.Font.Code
	t.TextColor3 = Color3.fromRGB(30, 30, 30)
	t.Text = "STAIR B\nSTAIR B\nSTAIR B\nSTAIR B\nSTAIR B\nSTAIR B"
	t.Parent = g
	task.delay(240, function()
		page:Destroy()
	end)
end, 200)

-- 4. in the cubicles, the lights behind you go out one by one
after(function(p)
	return inRect(p, -56, -22, -16, 10)
end, function(r)
	local behind = {}
	for _, m in CollectionService:GetTagged("OfcTrofferOn") do
		local pos = m:GetPivot().Position
		if pos.X < -10 and pos.Z < 16 then
			local to = (pos - r.Position)
			local dot = Vector3.new(to.X, 0, to.Z).Unit:Dot(Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z).Unit)
			if to.Magnitude < 40 then
				table.insert(behind, { m = m, d = dot, pos = pos })
			end
		end
	end
	table.sort(behind, function(a, b)
		return a.d < b.d
	end)
	for _, b in behind do
		held[b.m] = true
		getFixture(b.m).set(false)
		sfx("light_click", b.pos, 0.7, rng:NextNumber(0.9, 1.1), 40)
		task.wait(rng:NextNumber(0.7, 1.4))
	end
	task.wait(22)
	for _, b in behind do
		getFixture(b.m).set(true)
		held[b.m] = nil
	end
end, 160)

-- 5. the manager's chair turns from the window to face the door
after(function(p)
	return inRect(p, -56, -44, -36, -28)
end, function()
	local chair = map and map:FindFirstChild("ManagerChair", true)
	if not chair then
		return
	end
	task.wait(1.2)
	local cf = chair:GetPivot()
	local nv = Instance.new("NumberValue")
	nv.Changed:Connect(function(a)
		chair:PivotTo(cf * CFrame.Angles(0, math.rad(a), 0))
	end)
	sfx("chair_creak", cf.Position + Vector3.new(0, 2, 0), 0.8, 0.85, 30)
	TweenService:Create(nv, TweenInfo.new(3.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Value = 172 }):Play()
end)

-- 6. footsteps somewhere you can't see (sometimes in the ceiling, right above you)
task.spawn(function()
	while true do
		task.wait(rng:NextNumber(60, 140))
		local r = rootPart()
		if r then
			local pos
			if rng:NextNumber() < 0.3 then
				pos = r.Position + Vector3.new(rng:NextNumber(-6, 6), 12 - r.Position.Y, rng:NextNumber(-6, 6))
			else
				local a = rng:NextNumber(0, 2 * math.pi)
				pos = r.Position + Vector3.new(math.cos(a) * 32, 2, math.sin(a) * 32)
			end
			sfx("footsteps_far", pos, 0.9, rng:NextNumber(0.9, 1.0), 70)
		end
	end
end)

-- 7. the first time you stand in stair B, something knocks on 13
after(function(p)
	return inRect(p, -56, 18, -44, 36)
end, function()
	task.wait(2.5)
	sfx("knock", Vector3.new(-50, -9, 18.2), 1.2, 0.9, 80)
end, 240)

-- 8. after a few minutes away from it, the stair door slams (for everyone)
task.spawn(function()
	task.wait(rng:NextNumber(240, 360))
	while true do
		local r = rootPart()
		if r and (r.Position - Vector3.new(-50, 0, 18)).Magnitude > 28 then
			Event:FireServer("slam")
			task.wait(rng:NextNumber(300, 480))
		else
			task.wait(10)
		end
	end
end)
