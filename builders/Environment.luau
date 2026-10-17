-- Water, sky clouds, horizon islands and lighting. Shared by every map.

return function(ctx)
	local T = ctx.req("Theme")
	local U = ctx.req("Util").init(T)
	local M = T.Map
	local rng = Random.new(11)

	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end

	local env = U.fresh(workspace, "Environment", "Folder")

	-- Fake water: one huge studded plane plus foam rings around every landmass.
	for gx = -1, 1 do
		for gz = -1, 1 do
			U.block(
				env,
				"Water",
				Vector3.new(2048, 2, 2048),
				Vector3.new(gx * 2048, -1, gz * 2048),
				M.Water,
				{ faces = { Enum.NormalId.Top } }
			)
		end
	end

	-- Horizon islands sitting in the water.
	local horizon = U.folder(env, "HorizonIslands")
	for i = 1, 14 do
		local a = (i / 14) * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		local dist = rng:NextNumber(380, 560)
		local w, d, h = rng:NextNumber(40, 90), rng:NextNumber(30, 70), rng:NextNumber(14, 40)
		local pos = Vector3.new(math.cos(a) * dist, 0, math.sin(a) * dist)
		local yaw = CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		local m = U.model(horizon, "Island")
		U.block(
			m,
			"Rock",
			Vector3.new(w, h, d),
			CFrame.new(pos + Vector3.new(0, h / 2 - 2, 0)) * yaw,
			M.Stone,
			{ stud = 4 }
		)
		U.block(
			m,
			"Top",
			Vector3.new(w + 1, 3, d + 1),
			CFrame.new(pos + Vector3.new(0, h - 1, 0)) * yaw,
			M.Grass,
			{ stud = 4 }
		)
		if rng:NextNumber() < 0.6 then
			local w2, d2, h2 = w * 0.5, d * 0.5, h * rng:NextNumber(0.4, 0.8)
			local off = Vector3.new(rng:NextNumber(-w / 4, w / 4), h, rng:NextNumber(-d / 4, d / 4))
			U.block(
				m,
				"Rock",
				Vector3.new(w2, h2, d2),
				CFrame.new(pos + off + Vector3.new(0, h2 / 2 - 1, 0)) * yaw,
				M.StoneDark,
				{ stud = 4 }
			)
			U.block(
				m,
				"Top",
				Vector3.new(w2 + 1, 3, d2 + 1),
				CFrame.new(pos + off + Vector3.new(0, h2 - 1, 0)) * yaw,
				M.GrassAlt,
				{ stud = 4 }
			)
		end
	end

	-- Brick clouds.
	local clouds = U.folder(env, "Clouds")
	for i = 1, 12 do
		local a = (i / 12) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local dist = rng:NextNumber(220, 520)
		local center = Vector3.new(math.cos(a) * dist, rng:NextNumber(150, 230), math.sin(a) * dist)
		local m = U.model(clouds, "Cloud")
		for _ = 1, rng:NextInteger(3, 6) do
			local s = Vector3.new(rng:NextNumber(18, 40), rng:NextNumber(6, 12), rng:NextNumber(14, 28))
			local off = Vector3.new(rng:NextNumber(-22, 22), rng:NextNumber(-3, 5), rng:NextNumber(-10, 10))
			U.block(
				m,
				"Puff",
				s,
				center + off,
				M.Cloud,
				{ stud = 4, collide = false, shadow = false, transparency = 0.05 }
			)
		end
	end

	-- Bright, slightly warm afternoon.
	local L = game:GetService("Lighting")
	L.ClockTime = 14.2
	L.Brightness = 2.3
	L.EnvironmentDiffuseScale = 0.6
	L.EnvironmentSpecularScale = 0.3
	L.OutdoorAmbient = Color3.fromRGB(118, 116, 140)
	L.ColorShift_Top = Color3.fromRGB(255, 242, 222)
	local atmo = L:FindFirstChildOfClass("Atmosphere")
	if atmo then
		atmo.Density = 0.24
		atmo.Offset = 0.05
		atmo.Color = Color3.fromRGB(200, 226, 255)
		atmo.Decay = Color3.fromRGB(120, 160, 220)
		atmo.Glare = 0
		atmo.Haze = 0.35
	end
	local cc = L:FindFirstChild("Grade") or Instance.new("ColorCorrectionEffect")
	cc.Name = "Grade"
	cc.Saturation = 0.18
	cc.Contrast = 0.06
	cc.Parent = L
	local dof = L:FindFirstChildOfClass("DepthOfFieldEffect")
	if dof then
		dof.Enabled = false
	end

	return "environment built"
end
