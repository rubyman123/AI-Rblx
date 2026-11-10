-- Tests for MapKit.Lighting (restores the place's lighting afterwards). Method by fwjelaa (FWJ STUDIOS).
local KEYS = {
	"LightingStyle", "PrioritizeLightingQuality", "Brightness", "ClockTime", "GeographicLatitude", "Ambient",
	"OutdoorAmbient", "ColorShift_Top", "ColorShift_Bottom", "EnvironmentDiffuseScale", "EnvironmentSpecularScale",
	"GlobalShadows", "ShadowSoftness", "ExposureCompensation",
}

local function snapshot()
	local L = game:GetService("Lighting")
	local s = { props = {}, children = {} }
	for _, k in KEYS do
		s.props[k] = L[k]
	end
	for _, c in L:GetChildren() do
		table.insert(s.children, c:Clone())
	end
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	s.clouds = clouds and clouds:Clone()
	return s
end

local function restore(s)
	local L = game:GetService("Lighting")
	for k, v in s.props do
		L[k] = v
	end
	L:ClearAllChildren()
	for _, c in s.children do
		c.Parent = L
	end
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		clouds:Destroy()
	end
	if s.clouds then
		s.clouds.Parent = workspace.Terrain
	end
end

return {
	["simulator preset applies everything"] = function(t, K)
		local s = snapshot()
		local ok, err = pcall(function()
			local failures = K.Lighting.preset("simulator")
			t.eq(#failures, 0, "failures: " .. table.concat(failures, "; "))
			local L = game:GetService("Lighting")
			t.near(L.Brightness, 2.5, 1e-3, "Brightness")
			t.eq(L.LightingStyle, Enum.LightingStyle.Soft, "LightingStyle")
			t.ok(L:FindFirstChildOfClass("Atmosphere") ~= nil, "atmosphere")
			local dof = L:FindFirstChildOfClass("DepthOfFieldEffect")
			t.ok(dof == nil or not dof.Enabled, "depth of field off")
			t.ok(workspace.Terrain:FindFirstChildOfClass("Clouds") ~= nil, "clouds")
		end)
		restore(s)
		if not ok then
			error(err, 0)
		end
	end,
	["liminal preset applies everything"] = function(t, K)
		local s = snapshot()
		local ok, err = pcall(function()
			local failures = K.Lighting.preset("liminal")
			t.eq(#failures, 0, "failures: " .. table.concat(failures, "; "))
			local L = game:GetService("Lighting")
			t.eq(L.LightingStyle, Enum.LightingStyle.Realistic, "LightingStyle")
			-- tuned on screenshots taken with the camera really there (Backrooms Level 0, 2026-10-24)
			t.near(L.ExposureCompensation, 0.45, 1e-3, "exposure")
			t.eq(L.Ambient, Color3.fromRGB(135, 127, 95), "ambient")
			local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
			t.ok(clouds == nil or not clouds.Enabled, "no clouds indoors")
		end)
		restore(s)
		if not ok then
			error(err, 0)
		end
	end,
	["night preset applies everything"] = function(t, K)
		local s = snapshot()
		local ok, err = pcall(function()
			local failures = K.Lighting.preset("night")
			t.eq(#failures, 0, "failures: " .. table.concat(failures, "; "))
			local L = game:GetService("Lighting")
			t.ok(L.ClockTime >= 20 or L.ClockTime <= 4, "night time, got " .. L.ClockTime)
			t.eq(L.LightingStyle, Enum.LightingStyle.Realistic, "LightingStyle")
			local a = L:FindFirstChildOfClass("Atmosphere")
			t.ok(a ~= nil and a.Density >= 0.35, "fog")
			local amb, out = L.Ambient, L.OutdoorAmbient
			t.ok(amb.R + amb.G + amb.B < out.R + out.G + out.B, "indoors darker than outdoors")
			t.ok(amb.R + amb.G + amb.B > 0, "never pure black (phones fall back to Soft)")
		end)
		restore(s)
		if not ok then
			error(err, 0)
		end
	end,
	["golden preset applies everything"] = function(t, K)
		local s = snapshot()
		local ok, err = pcall(function()
			local failures = K.Lighting.preset("golden")
			t.eq(#failures, 0, "failures: " .. table.concat(failures, "; "))
			local L = game:GetService("Lighting")
			t.ok(L.ClockTime >= 16 and L.ClockTime <= 19.5, "golden hour, got " .. L.ClockTime)
			local rays = L:FindFirstChildOfClass("SunRaysEffect")
			t.ok(rays ~= nil and rays.Enabled, "sun rays on")
			local a = L:FindFirstChildOfClass("Atmosphere")
			t.ok(a ~= nil and a.Density >= 0.25, "haze for depth")
		end)
		restore(s)
		if not ok then
			error(err, 0)
		end
	end,
	["unknown preset lists the real ones"] = function(t, K)
		t.errors(function()
			K.Lighting.preset("nope")
		end, "simulator")
	end,
}
