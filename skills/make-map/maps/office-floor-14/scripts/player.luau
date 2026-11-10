-- Office Floor 14: the player's body: first-person feel, a flashlight, footsteps that match the floor (MapKit by fwjelaa).
-- F (or the on-screen button) toggles the flashlight; hold Shift to hurry.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RS = game:GetService("ReplicatedStorage")

local Config = require(RS:WaitForChild("Office14"):WaitForChild("Config"))
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local WALK, HURRY = 9, 15

local function sfx2D(name, parent, volume, speed)
	local r = Config.regions[name]
	if not r or Config.sfx == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = Config.sfx
	s.PlaybackRegionsEnabled = true
	s.PlaybackRegion = NumberRange.new(r[1], r[2])
	s.Volume = volume
	s.PlaybackSpeed = speed or 1
	s.RollOffMinDistance = 4
	s.RollOffMaxDistance = 30
	s.Parent = parent
	s:Play()
	task.delay(math.min(2.5, (r[2] - r[1]) / (speed or 1)) + 0.2, function()
		s:Destroy()
	end)
end

------------------------------------------------------------------ flashlight
local torch = Instance.new("Part")
torch.Name = "Flashlight"
torch.Size = Vector3.new(0.2, 0.2, 0.2)
torch.Transparency = 1
torch.CanCollide = false
torch.CanQuery = false
torch.CanTouch = false
torch.Anchored = true
torch.CastShadow = false
local beam = Instance.new("SpotLight")
beam.Face = Enum.NormalId.Front
beam.Angle = 46
beam.Range = 44
beam.Brightness = 2.1
beam.Color = Color3.fromRGB(255, 243, 222)
beam.Shadows = true
beam.Enabled = false
beam.Parent = torch
local spill = Instance.new("PointLight")
spill.Range = 5
spill.Brightness = 0.18
spill.Color = beam.Color
spill.Shadows = false
spill.Enabled = false
spill.Parent = torch
torch.Parent = camera

local on = false
local function setTorch(v)
	on = v
	beam.Enabled = v
	spill.Enabled = v
	sfx2D("flash_click", camera, 0.6, math.random(95, 105) / 100)
end
ContextActionService:BindAction("Office14Flashlight", function(_, state)
	if state == Enum.UserInputState.Begin then
		setTorch(not on)
	end
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.F, Enum.KeyCode.ButtonR1)
ContextActionService:SetTitle("Office14Flashlight", "Light")
ContextActionService:SetPosition("Office14Flashlight", UDim2.new(1, -170, 1, -150))

-- the batteries are old: now and then the beam stutters
task.spawn(function()
	while true do
		task.wait(math.random(70, 160))
		if on then
			for _ = 1, math.random(3, 7) do
				beam.Enabled = false
				task.wait(math.random(3, 12) / 100)
				beam.Enabled = on
				beam.Brightness = math.random(10, 21) / 10
				task.wait(math.random(4, 18) / 100)
			end
			beam.Brightness = 2.1
		end
	end
end)

------------------------------------------------------------------ body, bob and steps
local STEP_KIND = {
	ofc_carpet = "carpet", ofc_cubicle = "carpet", ofc_lobby_floor = "hard", ofc_marble = "hard", ofc_terrazzo = "hard",
	ofc_tiles_white = "hard", ofc_concrete = "concrete", ofc_raised_floor = "metal", ofc_steel = "metal", ofc_alu = "metal",
}
local MATERIAL_KIND = {
	[Enum.Material.Carpet] = "carpet", [Enum.Material.Fabric] = "carpet", [Enum.Material.Concrete] = "concrete",
	[Enum.Material.Metal] = "metal", [Enum.Material.DiamondPlate] = "metal",
}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function onCharacter(char)
	local hum = char:WaitForChild("Humanoid")
	local root = char:WaitForChild("HumanoidRootPart")
	hum.WalkSpeed = WALK
	rayParams.FilterDescendantsInstances = { char, camera }
	-- mute the stock running sound: our own steps follow the floor
	task.spawn(function()
		local running = root:WaitForChild("Running", 5)
		if running then
			running.Volume = 0
		end
	end)
	local hurry = false
	ContextActionService:BindAction("Office14Hurry", function(_, state)
		hurry = state == Enum.UserInputState.Begin
		hum.WalkSpeed = hurry and HURRY or WALK
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	ContextActionService:SetTitle("Office14Hurry", "Run")
	ContextActionService:SetPosition("Office14Hurry", UDim2.new(1, -170, 1, -210))

	local walked, t = 0, 0
	local last = root.Position
	local lastStep = 0
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if not char.Parent then
			conn:Disconnect()
			return
		end
		-- the flashlight lags a hair behind the view, like a hand
		local target = camera.CFrame * CFrame.new(0.35, -0.35, -0.2)
		torch.CFrame = torch.CFrame:Lerp(target, math.clamp(dt * 18, 0, 1))
		local pos = root.Position
		local moved = Vector3.new(pos.X - last.X, 0, pos.Z - last.Z).Magnitude
		last = pos
		local grounded = hum.FloorMaterial ~= Enum.Material.Air
		if grounded and moved > 0.001 then
			t += dt * (hurry and 13 or 9)
			walked += moved
			local bob = math.sin(t)
			hum.CameraOffset = Vector3.new(bob * 0.04, math.abs(bob) * 0.09 - 0.05, 0)
		else
			hum.CameraOffset = hum.CameraOffset:Lerp(Vector3.zero, math.clamp(dt * 6, 0, 1))
		end
		local stride = hurry and 3.4 or 2.7
		if grounded and walked >= stride and os.clock() - lastStep > 0.2 then
			walked = 0
			lastStep = os.clock()
			local hit = workspace:Raycast(pos, Vector3.new(0, -5, 0), rayParams)
			local kind = "hard"
			if hit then
				kind = STEP_KIND[hit.Instance.MaterialVariant] or MATERIAL_KIND[hit.Material] or "hard"
			end
			local vol = ({ carpet = 0.55, hard = 0.32, concrete = 0.42, metal = 0.38 })[kind] * (hurry and 1.25 or 1)
			sfx2D(("step_%s_%d"):format(kind, math.random(1, 3)), root, vol, math.random(92, 108) / 100)
		end
	end)
end
if player.Character then
	onCharacter(player.Character)
end
player.CharacterAdded:Connect(onCharacter)
camera.FieldOfView = 72
