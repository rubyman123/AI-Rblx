-- Office Floor 14: doors you can open, and the scares that must happen for everyone (MapKit by fwjelaa).
-- Installed by build.luau's `scripts` phase into Map_office-floor-14.Scripts.
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")

local folder = RS:WaitForChild("Office14")
local Config = require(folder:WaitForChild("Config"))
local Event = folder:WaitForChild("Event")

local function sfx(name, parent, volume, speed, maxDist)
	local r = Config.regions[name]
	if not r or Config.sfx == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = Config.sfx
	s.PlaybackRegionsEnabled = true
	s.PlaybackRegion = NumberRange.new(r[1], r[2])
	s.Volume = volume or 0.8
	s.PlaybackSpeed = speed or 1
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 6
	s.RollOffMaxDistance = maxDist or 70
	s.Parent = parent
	s:Play()
	task.delay((r[2] - r[1]) / (speed or 1) + 0.5, function()
		s:Destroy()
	end)
	return s
end

-- a door is a Model whose pivot sits on the hinge; its rotation from shut is the attribute Angle
local function swing(door, target, seconds)
	local hinge = door:GetPivot().Position
	local sign = door:GetAttribute("Sign") or 1
	local nv = Instance.new("NumberValue")
	nv.Value = door:GetAttribute("Angle") or 0
	nv.Changed:Connect(function(a)
		door:PivotTo(CFrame.new(hinge) * CFrame.Angles(0, math.rad(a) * sign, 0))
	end)
	door:SetAttribute("Angle", target)
	local tw = TweenService:Create(nv, TweenInfo.new(seconds or 0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Value = target })
	tw.Completed:Connect(function()
		nv:Destroy()
	end)
	tw:Play()
end

local busy = {}
local function setupDoor(door)
	if not door:IsA("Model") or not door.PrimaryPart then
		return
	end
	local leaf = door.PrimaryPart
	if leaf:FindFirstChild("DoorPrompt") then
		return
	end
	local p = Instance.new("ProximityPrompt")
	p.Name = "DoorPrompt"
	p.ObjectText = "Door"
	p.ActionText = (door:GetAttribute("Angle") or 0) ~= 0 and "Close" or "Open"
	p.HoldDuration = 0
	p.MaxActivationDistance = 7
	p.RequiresLineOfSight = false
	p.Style = Enum.ProximityPromptStyle.Default
	p.Parent = leaf
	p.Triggered:Connect(function()
		if busy[door] then
			return
		end
		busy[door] = true
		local angle = door:GetAttribute("Angle") or 0
		if math.abs(angle) > 1 then
			swing(door, 0, 0.8)
			task.delay(0.7, function()
				sfx("door_slam", leaf, 0.35, 1.25, 40)
			end)
			p.ActionText = "Open"
		else
			local open = door:GetAttribute("OpenAngle") or 90
			if math.abs(open) < 30 then
				open = open < 0 and -85 or 85
			end
			swing(door, open, 1.1)
			sfx("chair_creak", leaf, 0.5, 0.62, 40)
			p.ActionText = "Close"
		end
		task.wait(0.9)
		busy[door] = nil
	end)
end
for _, d in CollectionService:GetTagged("OfcDoor") do
	setupDoor(d)
end
CollectionService:GetInstanceAddedSignal("OfcDoor"):Connect(setupDoor)

-- door 13 is locked; whatever is behind it answers
local lastKnock = 0
local function setup13(leaf)
	local p = Instance.new("ProximityPrompt")
	p.ObjectText = "Floor 13"
	p.ActionText = "Try the door"
	p.HoldDuration = 0.4
	p.MaxActivationDistance = 7
	p.RequiresLineOfSight = false
	p.Parent = leaf
	p.Triggered:Connect(function()
		sfx("light_click", leaf, 0.9, 0.55, 40)
		task.wait(0.15)
		sfx("light_click", leaf, 0.9, 0.5, 40)
		p.ActionText = "Locked"
		if os.clock() - lastKnock > 45 then
			lastKnock = os.clock()
			task.wait(1.8)
			sfx("knock", leaf, 1.2, 0.92, 60)
		end
	end)
end
for _, l in CollectionService:GetTagged("OfcDoor13") do
	setup13(l)
end

-- client director asks for the stair door to slam (once in a while, for everyone)
local lastSlam = 0
Event.OnServerEvent:Connect(function(_, kind)
	if kind == "slam" and os.clock() - lastSlam > 150 then
		local map = workspace:FindFirstChild(Config.map)
		local door = map and map:FindFirstChild("StairDoor", true)
		if door and math.abs(door:GetAttribute("Angle") or 0) > 1 then
			lastSlam = os.clock()
			swing(door, 0, 0.28)
			task.delay(0.26, function()
				sfx("door_slam", door.PrimaryPart, 1.3, 0.95, 90)
			end)
			local p = door.PrimaryPart:FindFirstChild("DoorPrompt")
			if p then
				p.ActionText = "Open"
			end
		end
	end
end)
