-- Ambience: looping 2D sounds per map, and the ambient reverb. Method by fwjelaa (FWJ STUDIOS).
local SoundService = game:GetService("SoundService")
local Root = require(script.Parent.Root)

local Sound = {}

function Sound.ambience(mapId, name, soundId, opts)
	opts = opts or {}
	local layer = Root.layer(mapId, "Sounds")
	local s = layer:FindFirstChild(name) or Instance.new("Sound")
	s.Name = name
	s.SoundId = soundId
	s.Looped = true
	s.Volume = opts.volume or 0.4
	s.PlaybackSpeed = opts.speed or 1
	s.Playing = true
	s.Parent = layer
	return s
end

function Sound.reverb(kind)
	SoundService.AmbientReverb = Enum.ReverbType[kind]
end

return Sound
