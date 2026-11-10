--!strict
-- Stud Simulator: the bright Roblox stud look. Palette from the Studs style guide in the roblox-ai reference pack
-- (blue #2890FF / #1760C9, yellow #FFD23F, red #FF5A40, navy #1E1B2F strokes); chunky FredokaOne text with navy
-- outlines; tone-on-tone square studs on every surface; full-width studded header bars with the X inside.

local Decor = require(script.Parent.Parent.Decor)
local Util = require(script.Parent.Parent.Util)

local hex = Color3.fromHex
local NAVY = hex("1E1B2F")
local WHITE = Color3.new(1, 1, 1)
-- Uploaded stud tile (tools/make_texture_pack.py). Without it Decor.studs falls back to the built-in dot tile.
local STUD_TILE = "rbxassetid://100994647021017"

local function stops(...: string): { Color3 }
	local list = {}
	for _, h in { ... } do
		table.insert(list, hex(h))
	end
	return list
end

local function variant(fill: { Color3 })
	return { fill = fill, fillTransparency = 0, text = WHITE, edge = NAVY, textStroke = NAVY }
end

local YELLOW = stops("FFE36B", "FFC21F")
local BLUE = stops("5CB8FF", "2890FF")
local GREEN = stops("8BEA5B", "3FC22B")
local RED = stops("FF8068", "FF4A2E")
-- menu tiles in Stud-GUI-2 are deep indigo, so the bright icons pop
local INDIGO = stops("4C5DB5", "2C3A80")

return {
	name = "StudSimulator",
	hudLayout = "simulator",
	color = {
		backdrop = hex("2890FF"),
		base = hex("1760C9"),
		baseTransparency = 0,
		surface = hex("2890FF"),
		surfaceTransparency = 0,
		rim = NAVY,
		barEdge = NAVY,
		text = WHITE,
		textMuted = hex("D6EBFF"),
		textStroke = NAVY,
		track = hex("0E3F8F"),
		header = YELLOW,
		variants = {
			primary = variant(YELLOW),
			secondary = variant(BLUE),
			success = variant(GREEN),
			danger = variant(RED),
			tile = variant(INDIGO),
			ghost = { fill = { NAVY }, fillTransparency = 0.35, text = WHITE, edge = NAVY, textStroke = NAVY },
		},
		bars = { health = RED, energy = BLUE, xp = YELLOW, accent = GREEN },
	},
	font = {
		display = Font.fromEnum(Enum.Font.FredokaOne),
		body = Font.fromEnum(Enum.Font.FredokaOne),
		number = Font.fromEnum(Enum.Font.FredokaOne),
	},
	textStroke = { display = 3, body = 2.2 },
	stroke = { panel = 3.5, control = 3, slot = 2.5 },
	radius = { panel = UDim.new(0, 12), control = UDim.new(0, 10), slot = UDim.new(0, 10), pill = UDim.new(0.5, 0) },
	shape = {
		chamfer = 0, slantButtons = false, tilt = 0, header = "bar", iconFrame = true, gradientText = true,
		barStyle = "single", currencyStyle = "bare", iconScale = 0.84,
	},
	motion = {
		style = "pop", easing = Enum.EasingStyle.Back, fast = 0.15, normal = 0.2, slow = 0.4,
		pressScale = 0.9, openFrom = 0.85, worldBlur = 14,
	},
	assets = { studTile = STUD_TILE },
	decorate = {
		panel = function(main: Frame, theme: any)
			Decor.studs(main, theme, 0.1, 26, theme.radius.panel)
		end,
		header = function(tab: Frame, theme: any)
			Decor.studs(tab, theme, 0.15, 22, theme.radius.panel)
			Decor.gloss(tab, 0.22, theme.radius.panel)
		end,
		button = function(button: GuiObject, theme: any, variantName: string)
			if variantName == "ghost" then
				return
			end
			Decor.studs(button, theme, 0.2, 18, if variantName == "icon" then theme.radius.slot else theme.radius.control)
			if variantName ~= "icon" then
				Decor.shine(button, 0.35, theme.radius.control)
			end
		end,
		slot = function(slot: GuiObject, theme: any)
			Decor.studs(slot, theme, 0.15, 20, theme.radius.slot)
		end,
		bar = function(bar: Frame, theme: any)
			local fill = bar:FindFirstChild("Fill")
			if fill and fill:IsA("GuiObject") then
				Decor.studs(fill, theme, 0.25, 18, theme.radius.control)
				Decor.shine(fill, 0.4, theme.radius.control)
			end
		end,
		screen = function(background: Frame, theme: any, _kind: string)
			background.BackgroundColor3 = WHITE
			Util.gradient(background, { hex("3AA0FF"), hex("2890FF"), hex("1760C9") }, 90)
			Decor.studs(background, theme, 0.05, 40, nil)
			Decor.rays(background, WHITE, 16, 0.85, 1.6)
		end,
	},
}
