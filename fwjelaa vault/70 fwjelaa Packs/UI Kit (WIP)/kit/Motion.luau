--!strict
-- Runtime behaviour for kit-built UI. Builders make instances; this makes them feel alive. Every animation reads
-- the theme's motion profile, so one call is bouncy in Stud Simulator and snappy in Battlegrounds.
-- Start it once from a LocalScript: require(ReplicatedStorage.UIKit.Motion).start()

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UIKit = require(script.Parent) :: any
local Util = UIKit.Util

local Motion = {}

local BLUR_NAME = "UIKitBlur"
local HOVER_SCALE = 1.05
local TOAST_SECONDS = 2.5
local SPLASH_SECONDS = 2
local RAY_SPIN_SECONDS = 6
local FLICKER_STEP = 0.035
local SLAM_FROM = UDim2.fromScale(-0.6, 0)
local SLAM_TILT = 8
local SLIDE_FROM = UDim2.fromScale(0, 0.04)
local DAMAGE_POP = 0.18
local DAMAGE_HOLD = 0.25
local DAMAGE_FADE = 0.7
local DAMAGE_RISE = UDim2.fromScale(0, 0.06)
local HIT_POP_SCALE = 1.3
local CRIT_POP_SCALE = 1.8
local COUNT_SECONDS = 0.6

local themeCache: { [string]: any } = {}
local openPanels: { [ScreenGui]: boolean } = {}
local bound: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local toastCount = 0
local started = false

local function themeOf(inst: Instance): any
	local node: Instance? = inst
	while node do
		local name = node:GetAttribute("UIKitTheme")
		if type(name) == "string" then
			local theme = themeCache[name]
			if not theme then
				theme = UIKit.theme(name)
				themeCache[name] = theme
			end
			return theme
		end
		node = node.Parent
	end
	return UIKit.theme(UIKit.themeNames()[1])
end

local function tweenInfo(theme: any, speed: string, easing: Enum.EasingStyle?, direction: Enum.EasingDirection?): TweenInfo
	return TweenInfo.new(theme.motion[speed], easing or theme.motion.easing, direction or Enum.EasingDirection.Out)
end

local function play(inst: Instance, info: TweenInfo, goal: { [string]: any }): Tween
	local tween = TweenService:Create(inst, info, goal)
	tween:Play()
	return tween
end

local function scaleOf(gui: GuiObject, name: string): UIScale
	local existing = gui:FindFirstChild(name)
	if existing and existing:IsA("UIScale") then
		return existing
	end
	return Util.make("UIScale", { Name = name, Parent = gui })
end

local function playerGui(): PlayerGui
	return (Players.LocalPlayer :: Player):WaitForChild("PlayerGui") :: PlayerGui
end

function Motion.press(button: GuiObject)
	local theme = themeOf(button)
	local s = scaleOf(button, "PressScale")
	s.Scale = theme.motion.pressScale
	play(s, TweenInfo.new(theme.motion.fast, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
end

function Motion.hover(button: GuiObject, on: boolean)
	play(scaleOf(button, "HoverScale"), tweenInfo(themeOf(button), "fast"), { Scale = if on then HOVER_SCALE else 1 })
end

-- Remembers where an element lives so repeated entrances never drift
local function home(gui: GuiObject): (UDim2, number)
	local position = gui:GetAttribute("HomePosition")
	if typeof(position) ~= "UDim2" then
		position = gui.Position
		gui:SetAttribute("HomePosition", position)
	end
	local rotation = gui:GetAttribute("HomeRotation")
	if type(rotation) ~= "number" then
		rotation = gui.Rotation
		gui:SetAttribute("HomeRotation", rotation)
	end
	return position :: UDim2, rotation :: number
end

-- Plays the theme's entrance: pop, stamp, slam, flicker, slide or fade
function Motion.enter(gui: GuiObject)
	local theme = themeOf(gui)
	local m = theme.motion
	local s = scaleOf(gui, "OpenScale")
	local position, rotation = home(gui)
	gui.Position = position
	gui.Rotation = rotation
	-- players with Reduced Motion on get the element in place: no slams, flicker or bounce
	if GuiService.ReducedMotionEnabled then
		s.Scale = 1
		gui.Visible = true
		return
	end
	s.Scale = m.openFrom
	if m.style == "pop" then
		play(s, TweenInfo.new(m.normal, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	elseif m.style == "stamp" then
		play(s, TweenInfo.new(m.fast, Enum.EasingStyle.Linear), { Scale = 1 })
	elseif m.style == "slam" then
		gui.Position = position + SLAM_FROM
		gui.Rotation = rotation - SLAM_TILT
		play(gui, TweenInfo.new(m.normal, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = position, Rotation = rotation })
		play(s, TweenInfo.new(m.slow, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	elseif m.style == "flicker" then
		task.spawn(function()
			for _, visible in { false, true, false, true } do
				gui.Visible = visible
				task.wait(FLICKER_STEP)
			end
			play(s, tweenInfo(theme, "normal"), { Scale = 1 })
		end)
	elseif m.style == "slide" then
		gui.Position = position + SLIDE_FROM
		play(gui, tweenInfo(theme, "normal"), { Position = position })
		play(s, tweenInfo(theme, "normal"), { Scale = 1 })
	else
		play(s, tweenInfo(theme, "slow"), { Scale = 1 })
	end
end

local function updateWorld(theme: any)
	local anyOpen = next(openPanels) ~= nil
	local camera = workspace.CurrentCamera
	if camera then
		local blur = camera:FindFirstChild(BLUR_NAME)
		if not blur then
			blur = Util.make("BlurEffect", { Name = BLUR_NAME, Size = 0, Parent = camera })
		end
		-- Quad, not the theme easing: a Back overshoot would push the blur below zero
		play(blur :: BlurEffect, tweenInfo(theme, "normal", Enum.EasingStyle.Quad), { Size = if anyOpen then theme.motion.worldBlur else 0 })
	end
	for _, d in playerGui():GetDescendants() do
		if d:IsA("GuiObject") and d:HasTag("UIKit.HideWithPanel") then
			d.Visible = not anyOpen
		end
	end
end

function Motion.isOpen(gui: ScreenGui): boolean
	return openPanels[gui] == true
end

-- One panel at a time: opening one closes the rest, blurs the world and hides HUD clutter tagged
-- UIKit.HideWithPanel (the Lift a Rock behaviour)
function Motion.open(gui: ScreenGui)
	for other in openPanels do
		if other ~= gui then
			Motion.close(other)
		end
	end
	gui.Enabled = true
	openPanels[gui] = true
	local main = gui:FindFirstChild("Main")
	if main and main:IsA("GuiObject") then
		Motion.enter(main)
	end
	updateWorld(themeOf(gui))
end

function Motion.close(gui: ScreenGui)
	gui.Enabled = false
	if openPanels[gui] then
		openPanels[gui] = nil
		updateWorld(themeOf(gui))
	end
end

function Motion.toggle(gui: ScreenGui)
	if openPanels[gui] then
		Motion.close(gui)
	else
		Motion.open(gui)
	end
end

function Motion.setToggle(toggle: GuiObject, on: boolean)
	local theme = themeOf(toggle)
	toggle:SetAttribute("On", on)
	local knob = toggle:FindFirstChild("Knob")
	if knob and knob:IsA("GuiObject") then
		play(knob, tweenInfo(theme, "fast"), { Position = UDim2.fromScale(if on then 0.73 else 0.27, 0.5) })
	end
	local fill = toggle:FindFirstChild("Fill")
	if fill and fill:IsA("GuiObject") then
		play(fill, tweenInfo(theme, "fast", Enum.EasingStyle.Quad), { BackgroundTransparency = if on then 0 else 1 })
	end
end

function Motion.setSlider(slider: GuiObject, value: number)
	local v = math.clamp(value, 0, 1)
	slider:SetAttribute("Value", v)
	local track = slider:FindFirstChild("Track")
	local fill = track and track:FindFirstChild("Fill")
	if fill and fill:IsA("GuiObject") then
		fill.Size = UDim2.fromScale(v, 1)
	end
	local knob = slider:FindFirstChild("Knob")
	if knob and knob:IsA("GuiObject") then
		knob.Position = UDim2.fromScale(v, 0.5)
	end
end

function Motion.selectTab(tabs: Instance, id: string)
	local theme = themeOf(tabs)
	for _, child in tabs:GetChildren() do
		if child:IsA("GuiButton") then
			UIKit.setVariant(theme, child, if child.Name == id then "primary" else "secondary")
		end
	end
	tabs:SetAttribute("Selected", id)
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function bindSlider(slider: GuiObject)
	local track = slider:FindFirstChild("Track")
	if not track or not track:IsA("GuiObject") then
		return
	end
	local dragging = false
	local function follow(x: number)
		Motion.setSlider(slider, (x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X))
	end
	local function begin(input: InputObject)
		if isPress(input) then
			dragging = true
			follow(input.Position.X)
		end
	end
	slider.InputBegan:Connect(begin)
	local knob = slider:FindFirstChild("Knob")
	if knob and knob:IsA("GuiObject") then
		-- the knob is a button, so it swallows input before the slider frame sees it
		knob.InputBegan:Connect(begin)
	end
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			follow(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if isPress(input) then
			dragging = false
		end
	end)
end

function Motion.toast(stack: Instance, text: string, kind: string?, seconds: number?): GuiObject?
	local template = stack:FindFirstChild("Template")
	if not template or not template:IsA("GuiObject") then
		return nil
	end
	local theme = themeOf(stack)
	local toast = template:Clone()
	toast.Name = "Toast"
	toastCount += 1
	toast.LayoutOrder = -toastCount -- newest on top
	local label = toast:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
	local stripe = toast:FindFirstChild("Stripe")
	local gradient = stripe and stripe:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Color = Util.sequence(theme.color.bars[kind or "accent"] or theme.color.bars.accent)
	end
	toast.Visible = true
	toast.Parent = stack
	Motion.enter(toast)
	task.delay(seconds or TOAST_SECONDS, function()
		if toast.Parent then
			local info = tweenInfo(theme, "fast", Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			play(scaleOf(toast, "OpenScale"), info, { Scale = 0 }).Completed:Wait()
			toast:Destroy()
		end
	end)
	return toast
end

function Motion.countTo(label: TextLabel, from: number, to: number, seconds: number?, format: ((number) -> string)?)
	local fmt = format or Util.abbreviate
	local duration = seconds or COUNT_SECONDS
	local startedAt = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - startedAt) / duration, 0, 1)
		local eased = 1 - (1 - t) ^ 3
		label.Text = fmt(from + (to - from) * eased)
		if t >= 1 then
			connection:Disconnect()
		end
	end)
end

function Motion.damage(layer: Instance, at: UDim2, amount: number, crit: boolean?): TextLabel
	local theme = themeOf(layer)
	local label = UIKit.DamageNumber(theme, { Amount = Util.abbreviate(amount), Crit = crit, Position = at, Parent = layer })
	local s = scaleOf(label, "OpenScale")
	s.Scale = if crit then CRIT_POP_SCALE else HIT_POP_SCALE
	play(s, TweenInfo.new(DAMAGE_POP, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	local fade = TweenInfo.new(DAMAGE_FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, DAMAGE_HOLD)
	local rise = play(label, fade, { Position = at - DAMAGE_RISE, TextTransparency = 1 })
	local stroke = label:FindFirstChild("TextStroke")
	if stroke then
		play(stroke, fade, { Transparency = 1 })
	end
	rise.Completed:Connect(function()
		label:Destroy()
	end)
	return label
end

function Motion.splash(splash: GuiObject, seconds: number?)
	splash.Visible = true
	Motion.enter(splash)
	local rays = splash:FindFirstChild("Rays")
	local spin: Tween? = nil
	if rays and rays:IsA("GuiObject") then
		rays.Rotation = 0
		spin = play(rays, TweenInfo.new(RAY_SPIN_SECONDS, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Rotation = 360 })
	end
	task.delay(seconds or SPLASH_SECONDS, function()
		if spin then
			spin:Cancel()
		end
		splash.Visible = false
	end)
end

function Motion.setBar(bar: Instance, fraction: number, side: string?)
	local holder = if side then bar:FindFirstChild(side) else bar
	local fill = holder and holder:FindFirstChild("Fill")
	if fill and fill:IsA("GuiObject") then
		play(fill, tweenInfo(themeOf(bar), "normal", Enum.EasingStyle.Quad), { Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1) })
	end
end

function Motion.cooldown(slot: Instance, seconds: number)
	local shade = slot:FindFirstChild("Cooldown")
	if shade and shade:IsA("GuiObject") then
		shade.Size = UDim2.fromScale(1, 1)
		play(shade, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 0) })
	end
end

function Motion.loading(gui: Instance, seconds: number, onDone: (() -> ())?)
	local bar = gui:FindFirstChild("Progress", true)
	local fill = bar and bar:FindFirstChild("Fill")
	local value = bar and bar:FindFirstChild("Value")
	task.spawn(function()
		local startedAt = os.clock()
		while true do
			local t = math.clamp((os.clock() - startedAt) / seconds, 0, 1)
			if fill and fill:IsA("GuiObject") then
				fill.Size = UDim2.fromScale(t, 1)
			end
			if value and value:IsA("TextLabel") then
				value.Text = string.format("%d%%", math.floor(t * 100))
			end
			if t >= 1 then
				break
			end
			task.wait()
		end
		if onDone then
			onDone()
		end
	end)
end

local function bind(inst: Instance)
	if bound[inst] then
		return
	end
	if inst:IsA("GuiButton") and inst:HasTag("UIKit.Button") then
		bound[inst] = true
		inst.Activated:Connect(function()
			Motion.press(inst)
			if inst:HasTag("UIKit.Close") then
				local screen = inst:FindFirstAncestorOfClass("ScreenGui")
				if screen then
					Motion.close(screen)
				end
			end
			local target = inst:GetAttribute("Opens")
			if type(target) == "string" then
				local screen = playerGui():FindFirstChild(target)
				if screen and screen:IsA("ScreenGui") then
					Motion.toggle(screen)
				end
			end
			local parent = inst.Parent
			if parent and parent:HasTag("UIKit.Tabs") then
				Motion.selectTab(parent, inst.Name)
			end
		end)
		-- touch fires MouseEnter without a matching MouseLeave, which leaves buttons stuck big on phones
		if UserInputService.MouseEnabled then
			inst.MouseEnter:Connect(function()
				Motion.hover(inst, true)
			end)
			inst.MouseLeave:Connect(function()
				Motion.hover(inst, false)
			end)
		end
	elseif inst:IsA("GuiButton") and inst:HasTag("UIKit.Toggle") then
		bound[inst] = true
		inst.Activated:Connect(function()
			Motion.setToggle(inst, not inst:GetAttribute("On"))
		end)
	elseif inst:IsA("GuiObject") and inst:HasTag("UIKit.Slider") then
		bound[inst] = true
		bindSlider(inst)
	elseif inst:IsA("UIGridLayout") and inst:GetAttribute("DesignCell") ~= nil then
		bound[inst] = true
		Util.pixelGrid(inst)
	end
end

local function rescaleStroke(inst: Instance)
	local camera = workspace.CurrentCamera
	local base = inst:GetAttribute("BaseThickness")
	if camera and type(base) == "number" and (inst:IsA("UIStroke") or inst:IsA("Path2D")) then
		(inst :: any).Thickness = math.max(1, base * Util.strokeFactor(camera.ViewportSize.Y))
	end
end

function Motion.start()
	if started then
		return
	end
	started = true
	local pg = playerGui()
	for _, d in pg:GetDescendants() do
		bind(d)
		rescaleStroke(d)
	end
	pg.DescendantAdded:Connect(function(d)
		task.defer(bind, d)
		rescaleStroke(d)
	end)
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			Util.scaleStrokes(pg, camera.ViewportSize.Y)
		end)
	end
end

return Motion
