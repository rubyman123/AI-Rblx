-- ServerScriptService.AuraGiver (Script)
-- Gives every player's character the aura in ServerStorage.Auras on spawn.
-- Change AURA_NAME to swap auras.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local AURA_NAME = "BlueSpiralPillar"

local function playBurst(aura)
	local burst = aura:FindFirstChild("Burst", true)
	if not burst then
		return
	end
	for _, emitter in ipairs(burst:GetChildren()) do
		if emitter:IsA("ParticleEmitter") then
			task.delay(emitter:GetAttribute("EmitDelay") or 0, function()
				if emitter.Parent then
					emitter:Emit(emitter:GetAttribute("EmitCount") or 1)
				end
			end)
		end
	end
end

local function attachAura(character)
	local template = ServerStorage:WaitForChild("Auras"):FindFirstChild(AURA_NAME)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local hrp = character:WaitForChild("HumanoidRootPart", 10)
	if not (template and humanoid and hrp) then
		return
	end
	local existing = character:FindFirstChild("Aura_" .. AURA_NAME)
	if existing then
		existing:Destroy()
	end

	local aura = template:Clone()
	aura.Name = "Aura_" .. AURA_NAME
	-- the aura's pivot is its ground centre, so drop it from the root part to the feet
	local groundOffset = CFrame.new(0, -(humanoid.HipHeight + hrp.Size.Y / 2), 0)
	aura:PivotTo(hrp.CFrame * groundOffset)

	local weld = Instance.new("Weld")
	weld.Name = "AuraAnchor"
	weld.Part0 = hrp
	weld.Part1 = aura.PrimaryPart
	weld.C0 = groundOffset
	weld.Parent = aura.PrimaryPart

	aura.Parent = character
	task.delay(0.2, playBurst, aura)
end

local function onPlayer(player)
	player.CharacterAdded:Connect(attachAura)
	if player.Character then
		task.spawn(attachAura, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayer(player)
end
