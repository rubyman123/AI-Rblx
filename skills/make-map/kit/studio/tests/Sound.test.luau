-- Tests for MapKit.Sound. Method by fwjelaa (FWJ STUDIOS).
local SoundService = game:GetService("SoundService")

return {
	["ambience makes one looping sound and updates it in place"] = function(t, K)
		local a = K.Sound.ambience("snd_test", "Hum", "rbxassetid://1", { volume = 0.3 })
		local b = K.Sound.ambience("snd_test", "Hum", "rbxassetid://2", { volume = 0.5 })
		local root = workspace:FindFirstChild("Map_snd_test")
		local ok, err = pcall(function()
			t.eq(a, b, "same Sound")
			t.ok(b.Looped, "looped")
			t.eq(b.SoundId, "rbxassetid://2")
			t.near(b.Volume, 0.5, 1e-3, "volume")
		end)
		if root then
			root:Destroy()
		end
		if not ok then
			error(err, 0)
		end
	end,
	["reverb sets the ambient reverb"] = function(t, K)
		local before = SoundService.AmbientReverb
		K.Sound.reverb("Hallway")
		local got = SoundService.AmbientReverb
		SoundService.AmbientReverb = before
		t.eq(got, Enum.ReverbType.Hallway)
	end,
}
