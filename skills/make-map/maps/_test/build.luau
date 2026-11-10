-- Test map for Run.test.luau. Method by fwjelaa (FWJ STUDIOS).
return function(K, spec)
	local phases = {}
	function phases.three()
		local f = K.Root.clear(spec.id, "Props")
		for i = 1, 3 do
			K.Build.part({ Size = Vector3.one, CFrame = CFrame.new(i * 2, 300, 0), Color = Color3.new(1, 0, 0), Parent = f })
		end
		return "three parts"
	end
	function phases.boom()
		local f = K.Root.clear(spec.id, "Props")
		K.Build.part({ Size = Vector3.one, CFrame = CFrame.new(0, 300, 0), Parent = f })
		error("boom on purpose")
	end
	return phases
end
