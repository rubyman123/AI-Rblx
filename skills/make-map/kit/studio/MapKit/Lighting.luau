-- Mood presets for Lighting, Atmosphere, Clouds and post effects. Method by fwjelaa (FWJ STUDIOS).
-- Starting values: research/04 section 2.6 (simulator) and research/02 section 1.3 (realistic, Plans 2-4).
local LightingService = game:GetService("Lighting")

local Lighting = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

Lighting.PRESETS = {
	simulator = {
		Lighting = {
			LightingStyle = Enum.LightingStyle.Soft,
			PrioritizeLightingQuality = false,
			Brightness = 2.5,
			ClockTime = 13.5,
			GeographicLatitude = 30,
			Ambient = rgb(140, 140, 150),
			OutdoorAmbient = rgb(150, 150, 160),
			ColorShift_Top = rgb(255, 245, 225),
			ColorShift_Bottom = rgb(0, 0, 0),
			EnvironmentDiffuseScale = 1,
			EnvironmentSpecularScale = 0.2,
			GlobalShadows = true,
			ShadowSoftness = 0.3,
			ExposureCompensation = 0,
		},
		Atmosphere = { Density = 0.25, Offset = 0.1, Color = rgb(175, 221, 255), Decay = rgb(106, 112, 125), Haze = 0, Glare = 0 },
		ColorCorrectionEffect = { Brightness = 0, Contrast = 0.08, Saturation = 0.2, TintColor = rgb(255, 253, 245) },
		BloomEffect = { Intensity = 0.6, Size = 24, Threshold = 1.9 },
		SunRaysEffect = { Intensity = 0.05, Spread = 0.5 },
		DepthOfFieldEffect = false,
		BlurEffect = false,
		Clouds = { Cover = 0.5, Density = 0.6, Color = rgb(255, 255, 255) },
	},
	-- research/02 §1.3 "Liminal fluorescent interior": flat, too-even light; survives the phone Soft fallback best
	liminal = {
		Lighting = {
			LightingStyle = Enum.LightingStyle.Realistic,
			PrioritizeLightingQuality = true,
			Brightness = 1,
			ClockTime = 12,
			GeographicLatitude = 41.7,
			-- tuned on Backrooms Level 0 with the camera really there (screen_capture's own camera shows unlit rooms)
			ExposureCompensation = 0.45,
			Ambient = rgb(135, 127, 95),
			OutdoorAmbient = rgb(135, 127, 95),
			ColorShift_Top = rgb(0, 0, 0),
			ColorShift_Bottom = rgb(0, 0, 0),
			EnvironmentDiffuseScale = 0.4,
			EnvironmentSpecularScale = 0.4,
			GlobalShadows = true,
			ShadowSoftness = 0.6,
		},
		Atmosphere = { Density = 0.22, Offset = 0, Color = rgb(200, 190, 150), Decay = rgb(150, 140, 110), Haze = 0.5, Glare = 0 },
		ColorCorrectionEffect = { Brightness = 0.02, Contrast = -0.05, Saturation = -0.1, TintColor = rgb(255, 248, 225) },
		BloomEffect = { Intensity = 0.8, Size = 40, Threshold = 0.95 },
		DepthOfFieldEffect = { FarIntensity = 0.15, FocusDistance = 30, InFocusRadius = 40, NearIntensity = 0 },
		SunRaysEffect = false,
		BlurEffect = false,
		Clouds = false,
	},
	-- research/02 §1.3 "Horror night interior" + "Foggy horror exterior": moonlit fog outside, near-black rooms
	-- that only local lights (lamps, flicker bulbs) open up; Ambient never 0 so phones' Soft fallback reads.
	-- Brightened on K.shot screenshots of the farmhouse (the table's values were near-black). Latitude -40 at 22:30
	-- hangs the moon 24 degrees up in the north (-Z): a spawn looking north sees it behind the landmark.
	night = {
		Lighting = {
			LightingStyle = Enum.LightingStyle.Realistic,
			PrioritizeLightingQuality = true,
			Brightness = 3,
			ClockTime = 22.5,
			GeographicLatitude = -40,
			ExposureCompensation = 0.5,
			Ambient = rgb(30, 32, 42),
			OutdoorAmbient = rgb(110, 120, 150),
			ColorShift_Top = rgb(0, 0, 0),
			ColorShift_Bottom = rgb(0, 0, 0),
			EnvironmentDiffuseScale = 0.4,
			EnvironmentSpecularScale = 0.8,
			GlobalShadows = true,
			ShadowSoftness = 0.4,
		},
		Atmosphere = { Density = 0.36, Offset = 0.05, Color = rgb(95, 105, 130), Decay = rgb(40, 45, 60), Haze = 1.5, Glare = 0 },
		ColorCorrectionEffect = { Brightness = -0.02, Contrast = 0.06, Saturation = -0.3, TintColor = rgb(225, 232, 255) },
		BloomEffect = { Intensity = 0.5, Size = 28, Threshold = 1.2 },
		DepthOfFieldEffect = false,
		SunRaysEffect = false,
		BlurEffect = false,
		Clouds = false,
	},
	-- research/02 §1.3 "Golden-hour forest": low warm sun, long shadows, rays through the trees, warm haze for depth.
	-- The map's sky phase moves the sun onto the HDRI's (K.Sky.matchSun), so ClockTime here is a starting point.
	golden = {
		Lighting = {
			LightingStyle = Enum.LightingStyle.Realistic,
			PrioritizeLightingQuality = true,
			Brightness = 3,
			ClockTime = 17.4,
			GeographicLatitude = 45,
			ExposureCompensation = 0.35,
			Ambient = rgb(35, 30, 30),
			OutdoorAmbient = rgb(170, 162, 156), -- a low sun leaves valleys in shade: keep shade readable
			ColorShift_Top = rgb(255, 205, 150),
			ColorShift_Bottom = rgb(70, 62, 72),
			EnvironmentDiffuseScale = 1,
			EnvironmentSpecularScale = 1,
			GlobalShadows = true,
			ShadowSoftness = 0.15,
		},
		Atmosphere = { Density = 0.28, Offset = 0.25, Color = rgb(200, 170, 108), Decay = rgb(150, 138, 124), Haze = 0.9, Glare = 0.8 }, -- a grey-warm horizon: water mirrors it
		ColorCorrectionEffect = { Brightness = 0, Contrast = 0.1, Saturation = 0.1, TintColor = rgb(255, 240, 220) },
		BloomEffect = { Intensity = 0.35, Size = 24, Threshold = 1.2 },
		SunRaysEffect = { Intensity = 0.12, Spread = 0.6 },
		DepthOfFieldEffect = { FarIntensity = 0.1, FocusDistance = 60, InFocusRadius = 80, NearIntensity = 0 },
		BlurEffect = false,
		Clouds = false,
	},
}

local function set(inst, props, failures)
	for k, v in props do
		local ok, err = pcall(function()
			inst[k] = v
		end)
		if not ok then
			table.insert(failures, ("%s.%s: %s"):format(inst.ClassName, k, tostring(err)))
		end
	end
end

function Lighting.preset(name)
	local p = Lighting.PRESETS[name]
	if not p then
		local names = {}
		for k in Lighting.PRESETS do
			table.insert(names, k)
		end
		table.sort(names)
		error(("unknown lighting preset %q (have: %s)"):format(tostring(name), table.concat(names, ", ")), 2)
	end
	local failures = {}
	for className, props in p do
		local parent = className == "Clouds" and workspace.Terrain or LightingService
		if className == "Lighting" then
			set(LightingService, props, failures)
		elseif props == false then
			for _, c in parent:GetChildren() do
				if c:IsA(className) then
					pcall(function()
						c.Enabled = false
					end)
				end
			end
		else
			local inst = parent:FindFirstChildOfClass(className)
			if not inst then
				inst = Instance.new(className)
				inst.Parent = parent
			end
			if inst:IsA("PostEffect") or inst:IsA("Clouds") then
				inst.Enabled = true
			end
			set(inst, props, failures)
		end
	end
	return failures
end

return Lighting
