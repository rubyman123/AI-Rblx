--!strict
-- Icon registry. Builders accept an icon by name ("coin") and resolve it here: uploaded art first, emoji as the
-- zero-upload fallback. Any other value (an rbxassetid, a glyph) passes straight through.
--
-- Two sources, one look (flat cel shading, thick navy outline):
--  * PACK - the simulator icon set in the vault's 80 Reference Library (visual-refs/icons). Those pictures belong to
--    their creators: check the licence before shipping them in a released game.
--  * KIT - the kit's own renders made to match the pack (tools/render_icons_blender.py, STYLE = "cel").
-- To use your own uploads, upload them (assets.md) and replace the ids below.

local Icons = {}

local PACK = {
	backpack = "rbxassetid://120455393561580",
	basket = "rbxassetid://97567784407654",
	book = "rbxassetid://86815417949538",
	calendar = "rbxassetid://83555040482334",
	candycane = "rbxassetid://123075398607347",
	clock = "rbxassetid://107962447583340",
	codes = "rbxassetid://102664112204533",
	egg = "rbxassetid://86022320048867",
	friends = "rbxassetid://71454376904554",
	gear = "rbxassetid://81246851453118",
	gift = "rbxassetid://85130779510639",
	key = "rbxassetid://79812365129100",
	lock = "rbxassetid://137149351397275",
	pass = "rbxassetid://133582201922552",
	potion = "rbxassetid://130238312711582",
	potion_red = "rbxassetid://102828958251366",
	potion_yellow = "rbxassetid://76691483986956",
	scroll = "rbxassetid://75212955315319",
	shop = "rbxassetid://123445175481069",
	snowflake = "rbxassetid://98071498609128",
	snowman = "rbxassetid://91384112140168",
	stats = "rbxassetid://81136893620544",
	ticket = "rbxassetid://135687963623173",
	tree = "rbxassetid://98949428979553",
	unlock = "rbxassetid://83921027359517",
	upgrade = "rbxassetid://123045872802040",
	video = "rbxassetid://110362796538589",
}

local KIT = {
	bolt = "rbxassetid://72384291957727",
	cash = "rbxassetid://91576810827407",
	clover = "rbxassetid://74306059755487",
	coin = "rbxassetid://106622183853799",
	crown = "rbxassetid://122340739594821",
	dumbbell = "rbxassetid://92536710999046",
	gem = "rbxassetid://112034495093034",
	heart = "rbxassetid://116245998971427",
	rebirth = "rbxassetid://97062839060325",
	shield = "rbxassetid://119124434115913",
	skull = "rbxassetid://139593219177024",
	star = "rbxassetid://109856926764982",
	sword = "rbxassetid://127137810038580",
	trophy = "rbxassetid://109017189741346",
}

Icons.ART = {} :: { [string]: string }
for name, id in PACK do
	Icons.ART[name] = id
end
for name, id in KIT do
	Icons.ART[name] = id
end

Icons.EMOJI = {
	backpack = "🎒", basket = "🧺", bolt = "⚡", book = "📖", calendar = "📅", candycane = "🍬", cash = "💵", clock = "⏰",
	clover = "🍀", codes = "🎟️", coin = "🪙", crown = "👑", dumbbell = "🏋️", egg = "🥚", friends = "👥", gear = "⚙️",
	gem = "💎", gift = "🎁", heart = "❤️", key = "🔑", lock = "🔒", pass = "🎫", potion = "🧪", potion_red = "🧪",
	potion_yellow = "🧪", rebirth = "🔄", scroll = "📜", shield = "🛡️", shop = "🛒", skull = "💀", snowflake = "❄️",
	snowman = "⛄", star = "⭐", stats = "📊", sword = "⚔️", ticket = "🎟️", tree = "🎄", trophy = "🏆", unlock = "🔓",
	upgrade = "⬆️", video = "🎬",
} :: { [string]: string }

-- Robux glyph that ships inside the Roblox client, for prices
Icons.ROBUX = "rbxasset://textures/ui/common/robux@3x.png"

-- Set false to force emoji (e.g. to see what a game looks like without the uploads)
Icons.USE_ART = true

function Icons.get(value: string): string
	if Icons.USE_ART and Icons.ART[value] then
		return Icons.ART[value]
	end
	return Icons.EMOJI[value] or value
end

return Icons
