--!strict
-- Blender -> Roblox model pipeline. Method by fwjelaa (FWJ STUDIOS). See CREDITS.md.
--
-- ModelInstaller: put this in ServerStorage as a ModuleScript named "ModelInstaller". It loads an uploaded model
-- asset and builds a clean game model from it:
--   <TARGET_FOLDER>/<ModelId>    Model
--     Root                       invisible 2x4x2 part whose bottom face sits at the feet (PrimaryPart; the
--                                model's pivot is at the feet)
--     Body                       the textured MeshPart, standing on the Root's bottom, facing -Z
-- The first install of each id backs the old model up to ServerStorage.<BACKUP_FOLDER>, so you can undo it.
--
-- Use the out/install.luau script that kit/upload_all.py writes, or by hand in the command bar (Edit mode):
--   print(require(game.ServerStorage.ModelInstaller:Clone())("BearBuddy", 123456789, {xmin, ymin, zmin}, {xmax, ymax, zmax}))
-- bboxMin/bboxMax are the Blender bounds from out/<ModelId>_export.json.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- Change these to fit your game
local TARGET_FOLDER = { "Models" } -- path under ReplicatedStorage where the models live, e.g. { "Assets", "Pets" }
local ICON_FOLDER = { "ModelIcons" } -- optional: ImageLabels named by ModelId get the new icon
local BACKUP_FOLDER = "ModelBackup"
local ROOT_SIZE = Vector3.new(2, 4, 2)

local function folderAt(path: { string }): Instance
	local node: Instance = ReplicatedStorage
	for _, name in path do
		local child = node:FindFirstChild(name)
		if not child then
			child = Instance.new("Folder")
			child.Name = name
			child.Parent = node
		end
		node = child
	end
	return node
end

local function findAt(path: { string }): Instance?
	local node: Instance? = ReplicatedStorage
	for _, name in path do
		node = if node then node:FindFirstChild(name) else nil
	end
	return node
end

local function backupFolder(): Instance
	local folder = ServerStorage:FindFirstChild(BACKUP_FOLDER)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = BACKUP_FOLDER
		folder.Parent = ServerStorage
	end
	return folder
end

return function(modelId: string, assetId: number, bboxMin: { number }, bboxMax: { number }, icon: string?): string
	local target = folderAt(TARGET_FOLDER)
	local old = target:FindFirstChild(modelId)
	local backup = backupFolder()
	if old and not backup:FindFirstChild(modelId) and not old:GetAttribute("FromPipeline") then
		old:Clone().Parent = backup
	end

	local loaded = InsertService:LoadAsset(assetId)
	local meshes = {}
	for _, d in loaded:GetDescendants() do
		if d:IsA("MeshPart") then
			table.insert(meshes, d)
		end
	end
	if #meshes == 0 then
		loaded:Destroy()
		return `{modelId}: asset {assetId} has no MeshPart`
	end

	local model = Instance.new("Model")
	model.Name = modelId
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = ROOT_SIZE
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.Massless = true
	root.CFrame = CFrame.new()
	-- the model's pivot is its feet, so PivotTo(top of a pedestal) stands it on top (Model.WorldPivot is ignored
	-- once a PrimaryPart is set)
	root.PivotOffset = CFrame.new(0, -ROOT_SIZE.Y / 2, 0)
	root.Parent = model

	-- Blender (x, y, z) arrives in Roblox as (-x, z, y): Blender's front (-Y) becomes Roblox's front (-Z).
	-- The mesh is centred on its bounding box, so move it until its feet touch the Root's bottom face.
	local cx = (bboxMin[1] + bboxMax[1]) / 2
	local cy = (bboxMin[2] + bboxMax[2]) / 2
	local cz = (bboxMin[3] + bboxMax[3]) / 2
	local offset = CFrame.new(-cx, -ROOT_SIZE.Y / 2 + cz, cy)
	for i, mesh in meshes do
		mesh.Name = if #meshes == 1 then "Body" else `Body{i}`
		mesh.Anchored = true
		mesh.CanCollide = false
		mesh.CanTouch = false
		mesh.Massless = true
		mesh.CFrame = root.CFrame * offset
		mesh.Parent = model
	end
	model.PrimaryPart = root
	model:SetAttribute("FromPipeline", true)
	loaded:Destroy()

	if old then
		old:Destroy()
	end
	model.Parent = target

	local iconNote = ""
	local iconFolder = if icon then findAt(ICON_FOLDER) else nil
	local label = if iconFolder then iconFolder:FindFirstChild(modelId) else nil
	if icon and label and label:IsA("ImageLabel") then
		if label:GetAttribute("OldImage") == nil then
			label:SetAttribute("OldImage", label.Image)
		end
		label.Image = icon
		iconNote = " + icon"
	end
	local size = meshes[1].Size
	return string.format("%s: installed %d mesh(es) %.2fx%.2fx%.2f%s", modelId, #meshes, size.X, size.Y, size.Z, iconNote)
end
