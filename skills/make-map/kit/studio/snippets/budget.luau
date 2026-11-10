-- Triangle and draw-call budget at a map's shots. Method by fwjelaa (FWJ STUDIOS).
-- Made by `python kit/tools/run.py budget <map>` (which fills in the views). Run it in Play mode with
-- execute_luau, datamodel "Client" (SceneAnalysisService only reports at runtime).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local sas = game:GetService("SceneAnalysisService")

local VIEWS = HttpService:JSONDecode([==[--[[VIEWS]]]==])

local cam = workspace.CurrentCamera
local oldType = cam.CameraType
cam.CameraType = Enum.CameraType.Scriptable
local rows = {}
for _, v in VIEWS do
	local pos = Vector3.new(v.cam[1], v.cam[2], v.cam[3])
	pcall(function()
		Players.LocalPlayer:RequestStreamAroundAsync(pos, 10)
	end)
	cam.CFrame = CFrame.lookAt(pos, Vector3.new(v.look[1], v.look[2], v.look[3]))
	task.wait(1.5)
	local ok, tri = pcall(function()
		return sas:GetTriangleCompositionAsync()
	end)
	if ok then
		local st, sd = 0, 0
		for _, c in tri.Children do
			if c.Name == "Shadows" then
				st, sd = c.Sizes.Triangles, c.Sizes.Drawcalls
			end
		end
		table.insert(rows, ("%-14s %8d tris %5d draws"):format(v.name, tri.Sizes.Triangles - st, tri.Sizes.Drawcalls - sd))
	else
		table.insert(rows, v.name .. " failed: " .. tostring(tri))
	end
end
cam.CameraType = oldType
return table.concat(rows, "\n") .. "\n(shadows excluded; PC target 800k tris / 600 draws per view, phone 500k / 500)"
