-- Instance helpers: sane part defaults, decor flags, chunked parenting. Method by fwjelaa (FWJ STUDIOS).
local Build = {}

local DEFAULTS = {
	Anchored = true,
	TopSurface = Enum.SurfaceType.Smooth,
	BottomSurface = Enum.SurfaceType.Smooth,
	Material = Enum.Material.SmoothPlastic,
}

-- Build.part{Size =, CFrame =, Color =, ...} or Build.part(props, "WedgePart"). Parent is applied last.
function Build.part(props, class)
	local p = Instance.new(class or "Part")
	for k, v in DEFAULTS do
		p[k] = v
	end
	for k, v in props do
		if k ~= "Parent" then
			p[k] = v
		end
	end
	if props.Color == nil and props.BrickColor == nil then
		-- QA.validate turns visible untinted kit parts into an error (default grey left by mistake)
		p:SetAttribute("MapKit_NoColor", true)
	end
	p.Parent = props.Parent
	return p
end

-- Scenery the player never touches: no collision, touch or queries; small pieces cast no shadow.
function Build.decor(root, shadowMin)
	shadowMin = shadowMin or 4
	local list = root:IsA("BasePart") and { root } or {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	for _, p in list do
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		local s = p.Size
		if math.max(s.X, s.Y, s.Z) < shadowMin then
			p.CastShadow = false
		end
	end
	return root
end

function Build.model(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Parent instances into the DataModel a chunk at a time so Studio never freezes long enough to drop the MCP.
function Build.flush(items, parent, chunk)
	chunk = chunk or 300
	for i, inst in items do
		inst.Parent = parent
		if i % chunk == 0 then
			task.wait()
		end
	end
end

return Build
