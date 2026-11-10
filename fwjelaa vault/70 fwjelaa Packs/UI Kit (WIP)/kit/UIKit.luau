--!strict
-- UIKit: themed Roblox UI builders. Every builder is UIKit.<Component>(theme, props) and returns plain
-- instances, so it works at edit time (bake into StarterGui through MCP) and at runtime.

local UIKit: { [string]: any } = {}

UIKit.Icons = require(script.Icons)
UIKit.Util = require(script.Util)
UIKit.Decor = require(script.Decor)

-- Component modules contribute their exported functions. A module that isn't installed yet adds nothing, so
-- KitCheck reports the missing builders instead of crashing.
for _, part in { "Containers", "Controls", "Readouts", "Feedback", "Screens" } do
	local module = script:FindFirstChild(part)
	if module and module:IsA("ModuleScript") then
		for key, value in require(module) :: any do
			UIKit[key] = value
		end
	end
end

function UIKit.theme(name: string): any
	local themes = script:FindFirstChild("Themes")
	local module = themes and themes:FindFirstChild(name)
	assert(module and module:IsA("ModuleScript"), "UIKit: no theme named " .. name)
	return require(module) :: any
end

function UIKit.themeNames(): { string }
	local names = {}
	local themes = script:FindFirstChild("Themes")
	if themes then
		for _, module in themes:GetChildren() do
			if module:IsA("ModuleScript") then
				table.insert(names, module.Name)
			end
		end
	end
	table.sort(names)
	return names
end

return UIKit
