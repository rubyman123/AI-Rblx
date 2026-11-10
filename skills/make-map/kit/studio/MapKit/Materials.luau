-- CC0 materials as MaterialVariants, from assets.json (made by `run.py material`). Method by fwjelaa (FWJ STUDIOS).
local MaterialService = game:GetService("MaterialService")
local Http = require(script.Parent.Http)

local Materials = {}

-- the exact command that prepared this material, so a fresh install (the shipped manifest has no ids) can remake it
local function remake(name, m)
	local cmd = { "python kit/tools/run.py material " .. name, "--from " .. (m.source or "ambientcg:<ID>") }
	for _, f in { { "tint", m.tint }, { "motif", m.motif }, { "studs", m.studsPerTile }, { "base", m.base }, { "pattern", m.pattern } } do
		if f[2] ~= nil then
			local v = tostring(f[2])
			if v:find("#", 1, true) then
				v = '"' .. v .. '"' -- bash and PowerShell read an unquoted #hex as the start of a comment
			end
			table.insert(cmd, ("--%s %s"):format(f[1], v))
		end
	end
	return table.concat(cmd, " ")
end

function Materials.install(names, manifestPath)
	manifestPath = manifestPath or "assets.json"
	local manifest = Http.json(manifestPath)
	-- validate everything first, so a bad name never leaves half the set installed; list every problem at once
	local problems = {}
	for _, name in names do
		local m = manifest.materials and manifest.materials[name]
		if not m then
			table.insert(problems, ("no material %q in %s: `python kit/tools/run.py material %s --from ambientcg:<ID>`"):format(name, manifestPath, name))
		else
			local ids = m.ids or {}
			local need = {}
			for kind in m.files or { color = true, normal = true } do
				if not ids[kind] then
					table.insert(need, kind)
				end
			end
			table.sort(need)
			if #need > 0 then
				table.insert(problems, ("%q has no uploaded %s id yet: `%s`"):format(name, table.concat(need, "/"), remake(name, m)))
			end
		end
	end
	if #problems > 0 then
		error(("Materials.install: %d material(s) to make first (with a key each command uploads; without one, upload the files it prints with upload_image, then `python kit/tools/run.py record <name> kind=rbxassetid://...`):\n%s")
			:format(#problems, table.concat(problems, "\n")), 2)
	end
	local done = {}
	for _, name in names do
		local m = manifest.materials[name]
		local v = MaterialService:FindFirstChild(name)
		if not (v and v:IsA("MaterialVariant")) then
			v = Instance.new("MaterialVariant")
			v.Name = name
		end
		v.BaseMaterial = Enum.Material[m.base or "Plastic"]
		v.ColorMap = m.ids.color
		v.NormalMap = m.ids.normal
		v.RoughnessMap = m.ids.roughness or ""
		v.MetalnessMap = m.ids.metalness or ""
		v.StudsPerTile = m.studsPerTile or 8
		v.MaterialPattern = Enum.MaterialPattern[m.pattern or "Regular"]
		v.Parent = MaterialService
		table.insert(done, name)
	end
	return done
end

-- terrain and every part of that base material use the variant (one map per place, so the override is the map's)
function Materials.override(baseMaterial, name)
	assert(MaterialService:FindFirstChild(name), ("Materials.override: %q is not installed; call K.Materials.install first"):format(name))
	MaterialService:SetBaseMaterialOverride(baseMaterial, name)
end

-- Roblox multiplies the ColorMap by Part.Color, so the part goes white (the texture as made) unless the map
-- passes a tint (hex string or Color3) to darken or warm it.
function Materials.apply(part, name, tint)
	local v = MaterialService:FindFirstChild(name)
	assert(v, ("Materials.apply: %q is not installed; call K.Materials.install first"):format(name))
	part.Material = v.BaseMaterial
	part.MaterialVariant = name
	if typeof(tint) == "string" then
		tint = Color3.fromHex(tint)
	end
	part.Color = tint or Color3.new(1, 1, 1)
	part:SetAttribute("MapKit_NoColor", nil)
	return part
end

return Materials
