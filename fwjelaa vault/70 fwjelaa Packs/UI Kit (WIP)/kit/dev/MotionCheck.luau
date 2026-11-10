--!strict
-- Play-mode checks for Motion. Run with execute_luau on the Client datamodel during a playtest:
--   return require(game.ReplicatedStorage.UIKitDev.MotionCheck).run()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MotionCheck = {}

function MotionCheck.run(): string
	local passed = 0
	local failures: { string } = {}
	local function case(label: string, fn: () -> ())
		local ok, err = pcall(fn)
		if ok then
			passed += 1
		else
			table.insert(failures, label .. ": " .. tostring(err))
		end
	end
	local function report(): string
		local lines = { string.format("MotionCheck: %d passed, %d failed", passed, #failures) }
		for _, failure in failures do
			table.insert(lines, "- " .. failure)
		end
		return table.concat(lines, "\n")
	end

	local kitModule = ReplicatedStorage:FindFirstChild("UIKit")
	local motionModule = kitModule and kitModule:FindFirstChild("Motion")
	case("Motion installed", function()
		assert(motionModule, "ReplicatedStorage.UIKit.Motion not found")
	end)
	if not kitModule or not motionModule then
		return report()
	end
	local UIKit = require(kitModule) :: any
	local Motion = require(motionModule) :: any
	local theme = UIKit.theme("StudSimulator")
	local playerGui = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")

	local panelGui = UIKit.Screen(theme, { Name = "_CheckInventory", Enabled = false })
	local _, grid = UIKit.Panel(theme, { Title = "Inventory", Body = "grid", Columns = 5, Parent = panelGui })
	for i = 1, 60 do
		UIKit.Slot(theme, { Name = string.format("Slot%02d", i), Icon = "💎", LayoutOrder = i, Parent = grid })
	end
	local otherGui = UIKit.Screen(theme, { Name = "_CheckShop", Enabled = false })
	UIKit.Panel(theme, { Title = "Shop", Body = "list", Parent = otherGui })
	local hud = UIKit.Screen(theme, { Name = "_CheckHud" })
	local side = UIKit.Button(theme, { Text = "Shop", Size = UDim2.fromScale(0.1, 0.08), Parent = hud })
	side:AddTag("UIKit.HideWithPanel")
	local toggle = UIKit.Toggle(theme, { On = false, Size = UDim2.fromScale(0.08, 0.06), Position = UDim2.fromScale(0.2, 0.1), Parent = hud })
	local slider = UIKit.Slider(theme, { Value = 0.2, Size = UDim2.fromScale(0.2, 0.05), Position = UDim2.fromScale(0.2, 0.2), Parent = hud })
	local tabs = UIKit.Tabs(theme, { Tabs = { "A", "B" }, Selected = "A", Size = UDim2.fromScale(0.2, 0.06), Position = UDim2.fromScale(0.2, 0.3), Parent = hud })
	local stack = UIKit.ToastStack(theme, { Parent = hud })
	local counter = UIKit.Util.text(theme, { Name = "Counter", Text = "0", Size = UDim2.fromScale(0.1, 0.05), Parent = hud })
	panelGui.Parent = playerGui
	otherGui.Parent = playerGui
	hud.Parent = playerGui
	Motion.start()
	task.wait(0.3)

	case("open shows the panel, blurs the world and hides side HUD", function()
		Motion.open(panelGui)
		task.wait(0.6)
		assert(panelGui.Enabled and Motion.isOpen(panelGui), "panel not open")
		local blur = (workspace.CurrentCamera :: Camera):FindFirstChild("UIKitBlur") :: BlurEffect?
		assert(blur and math.abs(blur.Size - theme.motion.worldBlur) < 0.5, "world blur not applied")
		assert(side.Visible == false, "HideWithPanel element still visible")
	end)

	case("long grid scrolls to the last row", function()
		local layout = grid:FindFirstChildOfClass("UIGridLayout") :: UIGridLayout
		assert(layout.CellSize.X.Scale == 0 and layout.CellSize.Y.Offset > 0, "pixel cells not applied")
		grid.CanvasPosition = Vector2.new(0, 1e6)
		task.wait(0.3)
		local last = grid:FindFirstChild("Slot60") :: GuiObject
		local windowTop = grid.AbsolutePosition.Y
		local windowBottom = windowTop + grid.AbsoluteSize.Y
		assert(last.AbsolutePosition.Y + last.AbsoluteSize.Y <= windowBottom + 2, "the last slot is below the scroll window")
		assert(last.AbsolutePosition.Y >= windowTop - 2, "scrolled past the last slot")
	end)

	case("opening another panel closes the first", function()
		Motion.open(otherGui)
		task.wait(0.3)
		assert(otherGui.Enabled and not panelGui.Enabled and not Motion.isOpen(panelGui), "two panels open at once")
	end)

	case("close restores the world", function()
		Motion.close(otherGui)
		task.wait(0.6)
		assert(not otherGui.Enabled and not Motion.isOpen(otherGui), "panel still open")
		local blur = (workspace.CurrentCamera :: Camera):FindFirstChild("UIKitBlur") :: BlurEffect
		assert(blur.Size < 0.5, "blur not removed")
		assert(side.Visible, "side HUD not restored")
	end)

	case("toggle", function()
		Motion.setToggle(toggle, true)
		task.wait(0.4)
		local knob = toggle:FindFirstChild("Knob") :: GuiObject
		assert(toggle:GetAttribute("On") == true and knob.Position.X.Scale > 0.6, "toggle did not switch on")
	end)

	case("slider moves and clamps", function()
		Motion.setSlider(slider, 0.8)
		local fill = (slider:FindFirstChild("Track") :: Frame):FindFirstChild("Fill") :: Frame
		assert(math.abs(slider:GetAttribute("Value") - 0.8) < 1e-3 and math.abs(fill.Size.X.Scale - 0.8) < 1e-3, "slider did not move")
		Motion.setSlider(slider, 3)
		assert(slider:GetAttribute("Value") == 1, "slider must clamp to 1")
	end)

	case("tabs", function()
		Motion.selectTab(tabs, "B")
		local a = tabs:FindFirstChild("A") :: Instance
		local b = tabs:FindFirstChild("B") :: Instance
		assert(tabs:GetAttribute("Selected") == "B", "Selected attribute not updated")
		assert(b:GetAttribute("Variant") == "primary" and a:GetAttribute("Variant") == "secondary", "tab colours not swapped")
	end)

	case("toast appears then removes itself", function()
		local toast = Motion.toast(stack, "Quest complete!", "success", 0.3)
		assert(toast and toast.Visible, "toast not shown")
		local label = toast:FindFirstChild("Label") :: TextLabel
		assert(label.Text == "Quest complete!", "toast text not set")
		task.wait(0.9)
		assert(toast.Parent == nil, "toast not removed after its time")
	end)

	case("countTo lands on the abbreviated target", function()
		Motion.countTo(counter, 0, 1500, 0.2)
		task.wait(0.5)
		assert(counter.Text == "1.5K", "countTo ended at " .. counter.Text)
	end)

	case("press springs back to full size", function()
		Motion.press(side)
		task.wait(0.5)
		local s = side:FindFirstChild("PressScale") :: UIScale?
		assert(s and math.abs(s.Scale - 1) < 0.01, "button stuck at " .. tostring(s and s.Scale))
	end)

	case("strokes are rescaled for this screen", function()
		local edge = side:FindFirstChild("Edge") :: UIStroke
		local expected = math.max(1, edge:GetAttribute("BaseThickness") * UIKit.Util.strokeFactor((workspace.CurrentCamera :: Camera).ViewportSize.Y))
		assert(math.abs(edge.Thickness - expected) < 0.01, "stroke not rescaled")
	end)

	panelGui:Destroy()
	otherGui:Destroy()
	hud:Destroy()
	return report()
end

return MotionCheck
