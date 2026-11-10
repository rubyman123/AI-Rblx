-- MapKit installer: (re)loads every MapKit module into ServerStorage.MapKit. Method by fwjelaa (FWJ STUDIOS).
-- Start `python kit/tools/run.py serve` first, then run this with the Studio MCP's execute_luau
-- (or paste it into View > Command Bar and press Enter).
local BASE = "http://127.0.0.1:8777/kit/studio/MapKit/"
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")

local wasOn = HttpService.HttpEnabled
HttpService.HttpEnabled = true
local ok, result = pcall(function()
	local index = HttpService:JSONDecode(HttpService:GetAsync(BASE .. "_index.json", true))
	local folder = Instance.new("Folder")
	folder.Name = "MapKit"
	folder:SetAttribute("Version", index.version)
	for _, name in index.modules do
		local m = Instance.new("ModuleScript")
		m.Name = name
		m.Source = HttpService:GetAsync(BASE .. name .. ".luau", true)
		m.Parent = folder
	end
	-- fresh instances every install, so require() never returns a stale cached module
	local old = ServerStorage:FindFirstChild("MapKit")
	if old then
		old:Destroy()
	end
	folder.Parent = ServerStorage
	return ("MapKit %s installed (%d modules)"):format(index.version, #index.modules)
end)
HttpService.HttpEnabled = wasOn
if not ok then
	error("MapKit install failed: " .. tostring(result) .. " -- is `python kit/tools/run.py serve` running?", 0)
end
return result
