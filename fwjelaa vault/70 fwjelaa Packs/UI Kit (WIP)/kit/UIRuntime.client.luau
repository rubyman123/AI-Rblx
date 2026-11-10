-- Gives every kit-built ScreenGui its runtime behaviour: press feedback, panels, toggles, sliders, tabs, grid
-- sizing and stroke scaling. Game code can require the same Motion module for toasts, damage numbers and bars.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Motion = require(ReplicatedStorage:WaitForChild("UIKit"):WaitForChild("Motion"))
Motion.start()
