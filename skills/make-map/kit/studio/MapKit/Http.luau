-- Fetch files from the pack served by `run.py serve`. Method by fwjelaa (FWJ STUDIOS).
local HttpService = game:GetService("HttpService")

local Http = { BASE = "http://127.0.0.1:8777/" }

function Http.get(path)
	local wasOn = HttpService.HttpEnabled
	HttpService.HttpEnabled = true
	local ok, body = pcall(HttpService.GetAsync, HttpService, Http.BASE .. path, true)
	HttpService.HttpEnabled = wasOn
	if not ok then
		error(("could not fetch %s (%s). Is `python kit/tools/run.py serve` running?"):format(path, tostring(body)), 2)
	end
	return body
end

function Http.json(path)
	return HttpService:JSONDecode(Http.get(path))
end

-- Load a Luau file from the pack as a fresh ModuleScript and require it (a new instance each time, so the
-- require cache never serves an old version).
function Http.module(path, name, parent)
	local m = Instance.new("ModuleScript")
	m.Name = name
	m.Source = Http.get(path)
	m.Parent = parent
	return require(m)
end

return Http
