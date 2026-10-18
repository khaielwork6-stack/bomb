--!strict
-- "The Fireworks Yard" props pass (Asset Bible §4.2 Yard, §4.4 props kit; §1 Quality Bar: modelled props replace the
-- part-built ones). Runs AFTER MapYard and MapYardToy, on the built map, and swaps MapYard's part-built props for the
-- modelled ones in ReplicatedStorage.FV_Art.Props (art/props/build_*.py → tools/upload_assets.py →
-- art/props/studio_import_props.luau):
--   • every Crate / HungCrate → FV_Art.Props.FireworkCrate, scaled to the old body's height, bottom on the same ground,
--     same CFrame; a closed crate (no rockets) loses its "Rockets" MeshPart; a cover crate's `Cover` attribute moves to
--     the new invisible "Hit" box (BotService steers round BaseParts with Cover = true);
--   • every HandTruck → FV_Art.Props.HandTruck (Cover kept on "Hit");
--   • every Pallet → FV_Art.Props.Pallet (0.65 tall: the stacks keep their pitch);
--   • every GasBottle → FV_Art.Props.GasBottle, its body tinted with the old body's colour (SurfaceAppearance.Color;
--     if the engine can't tint a SurfaceAppearance, the body drops its maps and takes the colour as plain plastic);
--   • the dock canopies' Floodlight boxes → FV_Art.Props.Floodlight heads aimed where the old lens pointed; the old
--     Lens part stays as an invisible emitter so its SpotLight keeps working unchanged;
--   • each sandbag pile (MapYard's loose "Sandbag" blobs, grouped by touching) → one FV_Art.Props.Sandbags wall,
--     scaled to the pile's height, bottom on the pile's bottom, its front to the yard; decoration, as the blobs were;
--   • each dock door (its "RollBox", with the "Slat"s, "Handle" or rolled-up "Shutter" bar under it) →
--     FV_Art.Props.Shutter, scaled from the floor to the roll box's top. A closed door keeps the old slats' collision
--     (the "Hit" box is fitted to them); the open (middle) door loses its slat panel, its bottom bar lifts up under
--     the hood, and nothing on it collides. The orange door frames stay;
--   • every "Bumper" (and its "BumperStripe") → FV_Art.Props.DockBumper, the same box, still solid.
-- Each swapped model keeps the original's name and parent (the folder structure doesn't change; a door's model is
-- named "Shutter") and is tagged with the attribute FV_Prop. A prop type whose FV_Art model is missing is left
-- exactly as MapYard built it.
-- Re-runnable: already-swapped models are skipped; run MapYard (+ MapYardToy) first for a clean base.

local Props: { [string]: string } = {
	Crate = "FireworkCrate",
	HungCrate = "FireworkCrate",
	HandTruck = "HandTruck",
	Pallet = "Pallet",
	GasBottle = "GasBottle",
	Floodlight = "Floodlight",
}
-- MapYard's dock dressing is loose BaseParts (no Model per prop)
local Loose: { [string]: string } = {
	Sandbag = "Sandbags",
	RollBox = "Shutter",
	Bumper = "DockBumper",
}

-- The bounds of `parts`, measured in the frame `rot` (a rotation-only CFrame): lo, hi.
local function boundsIn(parts: { BasePart }, rot: CFrame): (Vector3, Vector3)
	local lo = Vector3.new(math.huge, math.huge, math.huge)
	local hi = -lo
	for _, d in ipairs(parts) do
		local h = d.Size / 2
		for _, sx in ipairs({ -1, 1 }) do
			for _, sy in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					local p = rot:PointToObjectSpace(d.CFrame:PointToWorldSpace(h * Vector3.new(sx, sy, sz)))
					lo = lo:Min(p)
					hi = hi:Max(p)
				end
			end
		end
	end
	return lo, hi
end

-- The bottom centre of every BasePart in `m`, measured in the frame `rot` (a rotation-only CFrame).
local function bottomCentre(m: Instance, rot: CFrame): CFrame
	local parts = {}
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	local lo, hi = boundsIn(parts, rot)
	local c = (lo + hi) / 2
	return rot * CFrame.new(c.X, lo.Y, c.Z)
end

-- A yaw-only rotation facing (LookVector) along the horizontal axis of `cf` that `size` is thinnest on, turned toward
-- `toward` from `at`: the dock dressing's fronts face the yard.
local function facing(cf: CFrame, size: Vector3, at: Vector3, toward: Vector3): CFrame
	local axis = if size.X <= size.Z then cf.RightVector else cf.LookVector
	axis = Vector3.new(axis.X, 0, axis.Z).Unit
	if axis:Dot(toward - at) < 0 then
		axis = -axis
	end
	return CFrame.lookAt(Vector3.zero, axis)
end

return function(_ctx: any): string
	local maps = workspace:FindFirstChild("Maps")
	local map = maps and maps:FindFirstChild("Yard")
	assert(map, "Build MapYard first (workspace.Maps.Yard)")
	local art = game:GetService("ReplicatedStorage"):FindFirstChild("FV_Art")
	local lib = art and art:FindFirstChild("Props")

	local function proto(name: string): Model?
		local p = lib and lib:FindFirstChild(name)
		return if p and p:IsA("Model") then p else nil
	end

	-- A clone of FV_Art.Props.<kind>, scaled by `s` (relative: the importer leaves the models at scale 0.01) and with
	-- its pivot (bottom centre) on `at`, replacing `old` in its parent.
	local function swap(old: Instance, kind: string, at: CFrame, s: number): Model?
		local p = proto(kind)
		if not p then
			return nil
		end
		local m = p:Clone()
		if math.abs(s - 1) > 1e-3 then
			m:ScaleTo(m:GetScale() * s)
		end
		m:PivotTo(at)
		m.Name = old.Name
		for k, v in pairs(old:GetAttributes()) do
			m:SetAttribute(k, v)
		end
		m:SetAttribute("FV_Prop", kind)
		m.Parent = old.Parent
		old:Destroy()
		return m
	end

	local function hitOf(m: Model): BasePart?
		local h = m:FindFirstChild("Hit")
		return if h and h:IsA("BasePart") then h else nil
	end

	local function part(m: Instance, name: string): BasePart?
		local x = m:FindFirstChild(name)
		return if x and x:IsA("BasePart") then x else nil
	end

	-- Gather first (the swaps change the tree).
	local found: { [string]: { Instance } } = {}
	for _, d in ipairs(map:GetDescendants()) do
		if Loose[d.Name] and d:IsA("BasePart") then
			found[d.Name] = found[d.Name] or {}
			table.insert(found[d.Name], d)
			continue
		end
		local kind = Props[d.Name]
		if not kind or d:GetAttribute("FV_Prop") then
			continue
		end
		if d.Name == "Floodlight" then
			if d:IsA("BasePart") and d.Parent and d.Parent.Name == "Canopy" then
				found.Floodlight = found.Floodlight or {}
				table.insert(found.Floodlight, d)
			end
		elseif d:IsA("Model") and not (d.Parent and d.Parent.Name == "HandTruck") then
			found[d.Name] = found[d.Name] or {}
			table.insert(found[d.Name], d)
		end
	end
	local count: { [string]: number } = {}
	local function tally(kind: string)
		count[kind] = (count[kind] or 0) + 1
	end

	-- ── Crates (the field's cover, the strip, the near side, the crane's hung crate) ─────────────────────────────
	for _, name in ipairs({ "Crate", "HungCrate" }) do
		for _, old in ipairs(found[name] or {}) do
			local body = part(old, "Body")
			local p = proto("FireworkCrate")
			local ph = if p then hitOf(p) else nil
			if not body or not ph then
				continue
			end
			local closed = old:FindFirstChild("Rocket") == nil
			local cover = body:GetAttribute("Cover") == true
			local s = body.Size.Y / ph.Size.Y
			local m = swap(old, "FireworkCrate", body.CFrame * CFrame.new(0, -body.Size.Y / 2, 0), s)
			if m then
				if closed then
					local r = m:FindFirstChild("Rockets")
					if r then
						r:Destroy()
					end
				end
				local hit = hitOf(m)
				if hit and cover then
					hit:SetAttribute("Cover", true)
				end
				tally("FireworkCrate")
			end
		end
	end

	-- ── Hand-trucks (field cover) ────────────────────────────────────────────────────────────────────────────────
	for _, old in ipairs(found.HandTruck or {}) do
		local oh = part(old, "Hit")
		if not oh then
			continue
		end
		local cover = oh:GetAttribute("Cover") == true
		local m = swap(old, "HandTruck", oh.CFrame * CFrame.new(0, -oh.Size.Y / 2, 0), 1)
		if m then
			local hit = hitOf(m)
			if hit and cover then
				hit:SetAttribute("Cover", true)
			end
			tally("HandTruck")
		end
	end

	-- ── Pallets (strip, near side, stacks) ───────────────────────────────────────────────────────────────────────
	for _, old in ipairs(found.Pallet or {}) do
		local block = part(old, "Block")
		if not block then
			continue
		end
		if swap(old, "Pallet", bottomCentre(old, block.CFrame.Rotation), 1) then
			tally("Pallet")
		end
	end

	-- ── Gas bottles (strip), tinted with their old body colour, valve outlet turned to face the yard (+Z) ──────
	for _, old in ipairs(found.GasBottle or {}) do
		local ob = part(old, "Body")
		if not ob then
			continue
		end
		local tint = ob.Color
		local foot = ob.Position - Vector3.new(0, ob.Size.X / 2, 0) -- the body is a vertical cylinder (length on X)
		local m = swap(old, "GasBottle", CFrame.new(foot) * CFrame.Angles(0, math.pi, 0), 1)
		if m then
			local body = part(m, "Body")
			if body then
				body.Color = tint
				local sa = body:FindFirstChildOfClass("SurfaceAppearance")
				if sa then
					local ok = pcall(function()
						(sa :: any).Color = tint
					end)
					if not ok then
						sa:Destroy()
						body.Material = Enum.Material.SmoothPlastic
					end
				end
			end
			tally("GasBottle")
		end
	end

	-- ── Dock canopy floodlights ──────────────────────────────────────────────────────────────────────────────────
	for _, old in ipairs(found.Floodlight or {}) do
		local lamp = old :: BasePart
		local canopy = lamp.Parent :: Instance
		-- its lens: the nearest Lens part in the same canopy
		local lens: BasePart? = nil
		local best = math.huge
		for _, c in ipairs(canopy:GetChildren()) do
			if c.Name == "Lens" and c:IsA("BasePart") then
				local d = (c.Position - lamp.Position).Magnitude
				if d < best then
					lens, best = c, d
				end
			end
		end
		local p = proto("Floodlight")
		local pl = if p then part(p, "Lens") else nil
		if not lens or not p or not pl or best > 2 then
			continue
		end
		local oldLens: BasePart = lens
		local dir = (oldLens.Position - lamp.Position).Unit
		local rot = CFrame.lookAt(Vector3.zero, dir, lamp.CFrame.UpVector)
		local lensOff = p:GetPivot():PointToObjectSpace(pl.Position) -- pivot → lens centre, studs
		local at = CFrame.new(oldLens.Position) * rot * CFrame.new(-lensOff)
		local m = swap(lamp, "Floodlight", at, 1)
		if m then
			local nl = part(m, "Lens")
			if nl then
				nl.Color = oldLens.Color
			end
			local hit = hitOf(m)
			if hit then -- up on the canopy: decoration only
				hit.CanCollide, hit.CanQuery, hit.CanTouch = false, false, false
			end
			-- the old lens stays as an invisible emitter: its SpotLight keeps its face and settings
			oldLens.Name = "FloodEmitter"
			oldLens.Transparency = 1
			tally("Floodlight")
		end
	end

	-- the dock dressing faces the yard: its fronts turn toward the field's centre
	local zones = map:FindFirstChild("Zones", true)
	local fieldZone = zones and zones:FindFirstChild("Field")
	local centre = if fieldZone and fieldZone:IsA("BasePart") then fieldZone.Position else map:GetPivot().Position

	-- the Hit box (the collision) refitted to `parts`' bounds in the frame `rot`, the model's pivot kept
	local function fitHit(m: Model, parts: { BasePart }, rot: CFrame)
		local hit = hitOf(m)
		if not hit then
			return
		end
		local pv = m:GetPivot()
		local lo, hi = boundsIn(parts, rot)
		hit.Size = hi - lo
		hit.CFrame = rot * CFrame.new((lo + hi) / 2)
		hit.PivotOffset = hit.CFrame:ToObjectSpace(pv)
	end

	local function noCollide(m: Model)
		local hit = hitOf(m)
		if hit then
			hit.CanCollide, hit.CanQuery, hit.CanTouch = false, false, false
		end
	end

	-- ── Sandbag walls at the dock ends: one Sandbags model per pile of touching blobs ───────────────────────────
	local bags = (found.Sandbag or {}) :: { any }
	local sp = proto("Sandbags")
	local sh = if sp then hitOf(sp) else nil
	if sh and #bags > 0 then
		-- group the blobs into piles (union-find over blobs closer than a bag's length)
		local root: { number } = {}
		for i = 1, #bags do
			root[i] = i
		end
		local function find(i: number): number
			while root[i] ~= i do
				root[i] = root[root[i]]
				i = root[i]
			end
			return i
		end
		for i = 1, #bags do
			for j = i + 1, #bags do
				local a, b = bags[i] :: BasePart, bags[j] :: BasePart
				if
					a.Parent == b.Parent
					and (a.Position - b.Position).Magnitude < math.max(a.Size.X, a.Size.Z) * 1.2
				then
					root[find(i)] = find(j)
				end
			end
		end
		local piles: { [number]: { BasePart } } = {}
		for i = 1, #bags do
			local r = find(i)
			piles[r] = piles[r] or {}
			table.insert(piles[r], bags[i])
		end
		for _, pile in pairs(piles) do
			local lo, hi = boundsIn(pile, CFrame.identity)
			local mid = (lo + hi) / 2
			local rot = facing(CFrame.identity, hi - lo, mid, centre)
			local plo, phi = boundsIn(pile, rot)
			local c = (plo + phi) / 2
			local m = swap(pile[1], "Sandbags", rot * CFrame.new(c.X, plo.Y, c.Z), (phi.Y - plo.Y) / sh.Size.Y)
			if m then
				for i = 2, #pile do
					pile[i]:Destroy()
				end
				noCollide(m) -- decoration, as the blobs were (the dock's side walls do the blocking)
				tally("Sandbags")
			end
		end
	end

	-- ── Dock doors: each roll box with its slats / handle / rolled-up bar → one Shutter ─────────────────────────
	local shp = proto("Shutter")
	local shh = if shp then hitOf(shp) else nil
	for _, old in ipairs(found.RollBox or {}) do
		if not shh then
			break
		end
		local box = old :: BasePart
		local parent = box.Parent :: Instance
		local longZ = box.Size.Z >= box.Size.X
		local half = (if longZ then box.Size.Z else box.Size.X) / 2
		-- the door's own parts sit under the box, within its length, close to its depth
		local slats, extra, frames = {}, {}, {}
		for _, c in ipairs(parent:GetChildren()) do
			if not c:IsA("BasePart") or c == box then
				continue
			end
			local lp = box.CFrame:PointToObjectSpace(c.Position)
			local along, across = if longZ then lp.Z else lp.X, if longZ then lp.X else lp.Z
			if c.Name == "DoorFrameL" or c.Name == "DoorFrameR" then
				if math.abs(along) < half + 2 and math.abs(across) < 2.5 then
					table.insert(frames, c)
				end
			elseif math.abs(along) < half + 0.5 and math.abs(across) < 2.5 and lp.Y < 0 then
				if c.Name == "Slat" then
					table.insert(slats, c)
				elseif c.Name == "Handle" or c.Name == "Shutter" then
					table.insert(extra, c)
				end
			end
		end
		local floor = math.huge
		for _, p in ipairs(if #slats > 0 then slats else frames) do
			local lo = boundsIn({ p }, CFrame.identity)
			floor = math.min(floor, lo.Y)
		end
		if floor == math.huge then
			continue
		end
		local top = box.Position.Y + box.Size.Y / 2
		local rot = facing(box.CFrame, box.Size, box.Position, centre)
		local m =
			swap(box, "Shutter", rot + Vector3.new(box.Position.X, floor, box.Position.Z), (top - floor) / shh.Size.Y)
		if not m then
			continue
		end
		m.Name = "Shutter"
		if #slats > 0 then
			fitHit(m, slats, rot) -- closed: it blocks exactly where the slats did
		else
			-- the open door: no slat panel, the bottom bar rolled up under the hood, nothing in the way
			local panel = m:FindFirstChild("Panel")
			if panel then
				panel:Destroy()
			end
			local bar = part(m, "BottomBar")
			if bar then
				local hood = top - box.Size.Y
				bar.CFrame += Vector3.new(0, hood - (bar.Position.Y + bar.Size.Y / 2), 0)
			end
			noCollide(m)
		end
		for _, p in ipairs(slats) do
			p:Destroy()
		end
		for _, p in ipairs(extra) do
			p:Destroy()
		end
		tally("Shutter")
	end

	-- ── Dock bumpers either side of the doors ────────────────────────────────────────────────────────────────────
	local bp = proto("DockBumper")
	local bh = if bp then hitOf(bp) else nil
	for _, old in ipairs(found.Bumper or {}) do
		if not bh then
			break
		end
		local b = old :: BasePart
		local parent = b.Parent :: Instance
		local stripe: Instance? = nil
		for _, c in ipairs(parent:GetChildren()) do
			if c.Name == "BumperStripe" and c:IsA("BasePart") and (c.Position - b.Position).Magnitude < b.Size.Y then
				stripe = c
				break
			end
		end
		local rot = facing(b.CFrame, b.Size, b.Position, centre)
		local foot = b.Position - Vector3.new(0, b.Size.Y / 2, 0) -- an upright block
		if swap(b, "DockBumper", rot + foot, b.Size.Y / bh.Size.Y) then
			if stripe then
				stripe:Destroy()
			end
			tally("DockBumper")
		end
	end

	-- the field cover stands ON the yard floor (MapYard's TOP sits 1.3 below the restyled slabs' tops): drop each
	-- cover prop onto whatever is under its centre, ignoring the zone volumes and the cover itself
	local cover = map:FindFirstChild("Cover", true)
	if cover then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { cover, map:FindFirstChild("Zones", true) :: Instance }
		for _, m in ipairs(cover:GetChildren()) do
			if m:IsA("Model") and m:GetAttribute("FV_Prop") then
				local pv = m:GetPivot()
				local hit = workspace:Raycast(pv.Position + Vector3.new(0, 20, 0), Vector3.new(0, -40, 0), params)
				if hit then
					m:PivotTo(pv + Vector3.new(0, hit.Position.Y - pv.Y, 0))
				end
			end
		end
	end

	local parts = {}
	for _, kind in ipairs({
		"FireworkCrate",
		"HandTruck",
		"Pallet",
		"GasBottle",
		"Floodlight",
		"Sandbags",
		"Shutter",
		"DockBumper",
	}) do
		table.insert(parts, ("%s %d%s"):format(kind, count[kind] or 0, if proto(kind) then "" else " (missing)"))
	end
	return "Yard props: " .. table.concat(parts, ", ")
end
