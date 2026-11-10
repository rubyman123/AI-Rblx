-- Tests for MapKit.Http. Method by fwjelaa (FWJ STUDIOS).
local HttpService = game:GetService("HttpService")

return {
	["get returns file text"] = function(t, K)
		local text = K.Http.get("kit/studio/MapKit/_index.json")
		t.ok(string.find(text, "modules", 1, true) ~= nil, "index text")
	end,
	["json decodes"] = function(t, K)
		local index = K.Http.json("kit/studio/MapKit/_index.json")
		t.ok(type(index.modules) == "table" and #index.modules >= 3, "modules list")
	end,
	["missing file error names the server command"] = function(t, K)
		t.errors(function()
			K.Http.get("kit/studio/does-not-exist.txt")
		end, "run.py serve")
	end,
	["HttpEnabled is restored"] = function(t, K)
		local before = HttpService.HttpEnabled
		K.Http.get("kit/studio/MapKit/_index.json")
		t.eq(HttpService.HttpEnabled, before, "HttpEnabled")
	end,
}
