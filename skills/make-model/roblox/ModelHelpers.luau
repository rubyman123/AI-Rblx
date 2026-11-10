--!strict
-- Blender -> Roblox model pipeline. Method by fwjelaa (FWJ STUDIOS). See CREDITS.md.
--
-- ModelHelpers: the in-game side. Put it in ReplicatedStorage as a ModuleScript and use it everywhere you show a
-- model (spawns, plots, pads, carried items), so they all stand on their feet and face the right way.
--
--   local ModelHelpers = require(game.ReplicatedStorage.ModelHelpers)
--   local m = ModelHelpers.copy(game.ReplicatedStorage.Models.BearBuddy)
--   ModelHelpers.standOn(m, workspace.Pedestal)        -- feet on the top face, looking along Facing
--   ModelHelpers.tint(m, Color3.fromRGB(255, 214, 92)) -- a "Golden" variant that keeps the texture
--   m.Parent = workspace

local ModelHelpers = {}

-- Anchored, non-colliding copy whose pivot is the bottom centre (the feet).
-- Gotcha: when a Model has a PrimaryPart, Roblox IGNORES Model.WorldPivot. Set the PrimaryPart's PivotOffset instead,
-- or every PivotTo() puts the model half its height into the floor.
function ModelHelpers.copy(template: Model): Model
	local model = template:Clone()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
		end
	end
	local cf, size = model:GetBoundingBox()
	local bottom = CFrame.new(cf.Position - Vector3.new(0, size.Y / 2, 0))
	if model.PrimaryPart then
		model.PrimaryPart.PivotOffset = model.PrimaryPart.CFrame:ToObjectSpace(bottom)
	else
		model.WorldPivot = bottom
	end
	return model
end

-- Where a model standing on this part should look: the part's "Facing" attribute (a world direction you set on the
-- map so models face the people looking at them), else the part's own front. Always horizontal.
function ModelHelpers.facing(part: BasePart): Vector3
	local attr = part:GetAttribute("Facing")
	local dir = if typeof(attr) == "Vector3" then attr else part.CFrame.LookVector
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 1e-3 then
		dir = Vector3.new(part.CFrame.RightVector.X, 0, part.CFrame.RightVector.Z)
	end
	return dir.Unit
end

-- Stands the model upright on the part's top face. Works for discs too: a Roblox cylinder lies on its side, so the
-- top is found from the part's extent along world up, not from its own Y axis.
function ModelHelpers.standOn(model: Model, part: BasePart, lift: number?)
	local up = part.CFrame:VectorToObjectSpace(Vector3.yAxis)
	local halfHeight = (math.abs(up.X) * part.Size.X + math.abs(up.Y) * part.Size.Y + math.abs(up.Z) * part.Size.Z) / 2
	local top = part.Position + Vector3.new(0, halfHeight + (lift or 0), 0)
	model:PivotTo(CFrame.lookAt(top, top + ModelHelpers.facing(part)))
end

-- Colour variants (Golden, Diamond...) without losing the baked face and details: tint the SurfaceAppearance.
-- Recolouring the MeshPart itself does nothing while the texture is on, and removing the texture loses the face.
function ModelHelpers.tint(model: Model, color: Color3)
	for _, d in model:GetDescendants() do
		if d:IsA("SurfaceAppearance") then
			d.Color = color
		end
	end
end

-- A camera for a ViewportFrame (hotbar, index) that shows the model's FACE: the camera goes in front of the model's
-- LookVector, turned a little for a three-quarter view.
function ModelHelpers.portraitCamera(model: Model, turnDegrees: number?): Camera
	local cf, size = model:GetBoundingBox()
	local distance = math.max(size.X, size.Y, size.Z) * 1.6
	local view = (cf * CFrame.Angles(0, math.rad(turnDegrees or 18), 0)).LookVector
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(cf.Position + view * distance + Vector3.new(0, size.Y * 0.15, 0), cf.Position)
	return camera
end

return ModelHelpers
