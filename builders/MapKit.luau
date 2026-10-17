-- Shared pieces for the arena maps (2026-10-09, after the Ship): the gameplay contract every map needs (lines,
-- green safe strips with SAFE ZONE and checker flags, Zones), tiled studded floors, rods/balls/glows, railings,
-- and the imported-prop loader (group-owned models, coloured by part name, placed by bottom centre, with a
-- grey-box fallback when an asset can't load). A map builder does:
--   local K = ctx.req("MapKit").new(ctx, parent, "Temple", { display = "TEMPLE OF THE JADE JAGUAR", seed = 7 })
-- and builds into K.map. Geometry: the field is 220 (X, the crossing) × 130 (Z), its surface at K.TOP; the lobby
-- side is +Z (keep it open and low); the crowd stands go on the far side (−Z, z −70…−90) at runtime.

local MapKit = {}

MapKit.FIELD_X = 220
MapKit.FIELD_Z = 130
MapKit.LINE_INSET = 12

function MapKit.new(ctx, parent, name: string, opts)
	local T = ctx.req("Theme")
	local U = ctx.req("Util").init(T)
	local K: any = {}
	K.T, K.U, K.M = T, U, T.Map
	K.rng = Random.new(opts.seed or 1)
	K.TOP = opts.top or 10
	K.HALF_X, K.HALF_Z = MapKit.FIELD_X / 2, MapKit.FIELD_Z / 2
	K.LINE_X = K.HALF_X - MapKit.LINE_INSET
	K.map = U.fresh(parent, name)
	K.map:SetAttribute("DisplayName", opts.display or name)
	local tag = "[Map" .. name .. "]"

	function K.block(p, n, size, at, color, o)
		return U.block(p, n, size, at, color, o)
	end
	-- A cylinder between two points (Roblox cylinders run along X).
	function K.rod(p, n, a: Vector3, b: Vector3, d: number, color, o)
		o = table.clone(o or {})
		o.shape = Enum.PartType.Cylinder
		if o.stud == nil then
			o.stud = false
		end
		local dir = b - a
		return U.block(
			p,
			n,
			Vector3.new(dir.Magnitude, d, d),
			CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0),
			color,
			o
		)
	end
	-- An upright cylinder (a column, a drum) standing on `foot`.
	function K.column(p, n, foot: Vector3, h: number, d: number, color, o)
		return K.rod(p, n, foot, foot + Vector3.new(0, h, 0), d, color, o)
	end
	function K.ball(p, n, at, d: number, color, o)
		o = table.clone(o or {})
		o.shape = Enum.PartType.Ball
		if o.stud == nil then
			o.stud = false
		end
		return U.block(p, n, Vector3.one * d, at, color, o)
	end
	function K.wedge(p, n, size: Vector3, cf: CFrame, color, o)
		o = o or {}
		local w = Instance.new("WedgePart")
		w.Name = n
		w.Anchored = true
		w.Size = size
		w.CFrame = cf
		w.Color = color
		w.Material = o.material or Enum.Material.SmoothPlastic
		w.TopSurface = Enum.SurfaceType.Smooth
		w.BottomSurface = Enum.SurfaceType.Smooth
		if o.collide == false then
			w.CanCollide = false
			w.CanQuery = false
			w.CanTouch = false
		end
		if o.stud ~= false then
			U.stud(w, o.stud ~= true and o.stud or nil, { Enum.NormalId.Top, Enum.NormalId.Left, Enum.NormalId.Right })
		end
		w.Parent = p
		return w
	end
	function K.light(part: BasePart, color: Color3, range: number, brightness: number?, kind: string?)
		local l = Instance.new(kind or "PointLight") :: any
		l.Color = color
		l.Range = range
		l.Brightness = brightness or 1.3
		l.Shadows = false
		l.Parent = part
		return l
	end
	-- A neon glow part, optionally lit.
	function K.glow(p, n, size, at, color: Color3?, range: number?, o)
		o = table.clone(o or {})
		o.stud = false
		o.material = Enum.Material.Neon
		o.collide = false
		if o.shadow == nil then
			o.shadow = false
		end
		local c = color or K.M.Lantern
		local g = U.block(p, n, size, at, c, o)
		if range then
			K.light(g, c, range, o.brightness)
		end
		return g
	end
	-- Text painted on a part's face (a SurfaceGui), e.g. a carved name.
	function K.text(part: BasePart, face, s: string, color: Color3, font, pps: number?)
		return U.surfaceText(part, face, s, color, font or Enum.Font.LuckiestGuy, pps or 24)
	end

	-- ── Imported props ─────────────────────────────────────────────────────
	-- ART: key → asset id. LOOK: part role (name without .001) → { color, material, transparency? }. Models are
	-- loaded once (InsertService), scripts stripped, made inert (anchored, no collide/touch/query) and coloured by
	-- name; `fix(key, model)` can patch them further (textures).
	local ART, LOOK, FIX = {}, {}, nil
	local protos: { [string]: any } = {}
	function K.useArt(art, look, fix)
		ART, LOOK, FIX = art, look, fix
	end
	function K.art(key: string): Model?
		if protos[key] == nil then
			protos[key] = false
			local id = ART[key]
			local InsertService = game:GetService("InsertService")
			local ok, got = pcall(InsertService.LoadAsset, InsertService, id or 0)
			if id and ok and got then
				local m = got:FindFirstChildWhichIsA("Model") or got
				m.Name = key
				for _, d in ipairs(m:GetDescendants()) do
					if d:IsA("BasePart") then
						d.Anchored = true
						d.CanCollide = false
						d.CanTouch = false
						d.CanQuery = false
						local look = LOOK[(d.Name:gsub("%.%d+$", ""))]
						if look then
							d.Color = look[1]
							d.Material = look[2] or d.Material
							if look[3] then
								d.Transparency = look[3]
							end
						end
					elseif d:IsA("LuaSourceContainer") then
						d:Destroy()
					end
				end
				if FIX then
					FIX(key, m)
				end
				m.Parent = nil
				protos[key] = m
			else
				warn(tag, "could not load", key, got)
			end
		end
		local p = protos[key]
		return if p then p:Clone() else nil
	end
	-- Place a copy of an imported prop: scaled so its height is `height` (or its longest side is `long`), bottom
	-- centre at `at`'s position, turned by `at`'s rotation. Nil when it couldn't load (build a fallback).
	function K.prop(into, key: string, at: CFrame | Vector3, height: number?, long: number?): Model?
		local m = K.art(key)
		if not m then
			return nil
		end
		local cf = if typeof(at) == "Vector3" then CFrame.new(at) else at
		local _, size = m:GetBoundingBox()
		local k = if long then long / math.max(size.X, size.Y, size.Z) else (height or 1) / size.Y
		m:ScaleTo(m:GetScale() * k)
		local box, s2 = m:GetBoundingBox()
		m.WorldPivot = CFrame.new(box.Position - Vector3.new(0, s2.Y / 2, 0))
		m:PivotTo(cf)
		m.Parent = into
		return m
	end
	-- An inert copy of an imported model sized to a 10 × 6 × 10 rising block, centred on its pivot, for
	-- Templates (HazardController clones it). `fit` = "Y" scales by height only.
	function K.blockTemplate(into, key: string, n: string?, fit: string?): Model?
		local m = K.art(key)
		if not m then
			return nil
		end
		local _, size = m:GetBoundingBox()
		local k = if fit == "Y" then 6 / size.Y else math.min(6 / size.Y, 10 / size.X, 10 / size.Z)
		m:ScaleTo(m:GetScale() * k)
		local box = m:GetBoundingBox()
		m.WorldPivot = CFrame.new(box.Position)
		m:PivotTo(CFrame.new(0, -60, 0))
		m.Name = n or "BlockTemplate"
		m.Parent = into
		return m
	end

	-- An inert copy of an imported model for Templates (Roller, Critter): scaled so its longest side is `long` (or its
	-- height is `height`), pivoted at its centre, parked at the origin. Arena moves Templates out of the map at runtime.
	function K.template(into, key: string, n: string, long: number?, height: number?): Model?
		local m = K.art(key)
		if not m then
			return nil
		end
		local _, size = m:GetBoundingBox()
		local k = if height then height / size.Y else (long or 4) / math.max(size.X, size.Y, size.Z)
		m:ScaleTo(m:GetScale() * k)
		local box = m:GetBoundingBox()
		m.WorldPivot = CFrame.new(box.Position)
		m:PivotTo(CFrame.new(0, -60, 0))
		m.Name = n
		m.Parent = into
		return m
	end

	-- ── Floors ─────────────────────────────────────────────────────────────
	-- Tiles with thin seams over a dark sub-floor (its top 0.25 under the tiles: no z-fighting). opts: x0, x1, z0,
	-- z1, y (the top surface), tx, tz (tile size), seam, sub (sub-floor colour), color(ix, iz, x, z) → Color3,
	-- material, stud, thick, name.
	function K.tiles(p, o)
		local seam = o.seam or 0.16
		local thick = o.thick or 2
		local y = o.y or K.TOP
		local nx = math.max(1, math.floor((o.x1 - o.x0) / o.tx + 0.5))
		local nz = math.max(1, math.floor((o.z1 - o.z0) / o.tz + 0.5))
		local tx, tz = (o.x1 - o.x0) / nx, (o.z1 - o.z0) / nz
		if o.sub then
			K.block(
				p,
				(o.name or "Tile") .. "Bed",
				Vector3.new(o.x1 - o.x0, thick - 0.25, o.z1 - o.z0),
				Vector3.new((o.x0 + o.x1) / 2, y - 0.25 - (thick - 0.25) / 2, (o.z0 + o.z1) / 2),
				o.sub,
				{ stud = false }
			)
		end
		for ix = 0, nx - 1 do
			for iz = 0, nz - 1 do
				local cx, cz = o.x0 + (ix + 0.5) * tx, o.z0 + (iz + 0.5) * tz
				K.block(
					p,
					o.name or "Tile",
					Vector3.new(tx - seam, thick, tz - seam),
					Vector3.new(cx, y - thick / 2, cz),
					o.color(ix, iz, cx, cz),
					{ stud = if o.stud == nil then 2 else o.stud, material = o.material }
				)
			end
		end
	end
	-- Pick a colour from `tones` with a little per-tile variation (a hair lighter or darker).
	function K.vary(c: Color3, amt: number?): Color3
		local a = amt or 0.05
		local v = K.rng:NextNumber(-a, a)
		return if v >= 0 then c:Lerp(Color3.new(1, 1, 1), v) else c:Lerp(Color3.new(0, 0, 0), -v)
	end

	-- ── The gameplay contract ──────────────────────────────────────────────
	-- StartLine / FinishLine, the green safe strips with "SAFE ZONE" upright for a runner heading in and checker
	-- flags either side, and Zones (StartZone / FinishZone / Field). opts: font, textColor, checkDark, green,
	-- greenTransparency, lineColor.
	function K.contract(o)
		o = o or {}
		local M = K.M
		local top = K.TOP
		local lineX = K.LINE_X
		for n, x in pairs({ StartLine = -lineX, FinishLine = lineX }) do
			local p = K.block(
				K.map,
				n,
				Vector3.new(2, 0.4, MapKit.FIELD_Z - 4),
				Vector3.new(x, top + 0.2, 0),
				o.lineColor or M.Line,
				{ stud = 1 }
			)
			p.CanCollide = false
		end
		local paint = U.folder(K.map, "SafePaint")
		local inset = MapKit.LINE_INSET
		for _, s in ipairs({ -1, 1 }) do
			local cx = s * (lineX + (inset - 1) / 2 + 0.5)
			local green = K.block(
				paint,
				"SafeDeck",
				Vector3.new(inset - 1, 0.1, MapKit.FIELD_Z),
				Vector3.new(cx, top + 0.05, 0),
				o.green or M.SafeGreen,
				{ collide = false, shadow = false, transparency = o.greenTransparency }
			)
			green.CanQuery = false
			local text = U.marker(
				paint,
				"SafeText",
				Vector3.new(9, 0.1, 58),
				CFrame.fromMatrix(Vector3.new(cx, top + 0.12, 0), Vector3.new(-s, 0, 0), Vector3.yAxis)
			)
			text.CanTouch = false
			U.surfaceText(
				text,
				Enum.NormalId.Top,
				"SAFE ZONE",
				o.textColor or M.Line,
				o.font or Enum.Font.LuckiestGuy,
				24
			)
			for _, side in ipairs({ -1, 1 }) do
				local fz = side * 39
				for ix = 0, 3 do
					for iz = 0, 3 do
						K.block(
							paint,
							"Checker",
							Vector3.new(1.6, 0.12, 1.6),
							Vector3.new(cx + (ix - 1.5) * 1.6, top + 0.13, fz + (iz - 1.5) * 1.6),
							if (ix + iz) % 2 == 0
								then o.checkLight or M.Line
								else o.checkDark or Color3.fromRGB(40, 40, 46),
							{ stud = false, collide = false, shadow = false }
						)
					end
				end
			end
		end
		local zones = U.folder(K.map, "Zones")
		U.marker(
			zones,
			"StartZone",
			Vector3.new(inset - 1, 12, MapKit.FIELD_Z),
			Vector3.new(-K.HALF_X + (inset - 1) / 2, top + 6, 0)
		)
		U.marker(
			zones,
			"FinishZone",
			Vector3.new(inset - 1, 12, MapKit.FIELD_Z),
			Vector3.new(K.HALF_X - (inset - 1) / 2, top + 6, 0)
		)
		U.marker(zones, "Field", Vector3.new(lineX * 2 - 2, 12, MapKit.FIELD_Z), Vector3.new(0, top + 6, 0))
		return paint
	end

	-- Posts every ~`every` studs from `from` to `to`, with a callback for each post (i, at, n) and each gap
	-- (a, b): railings, fences, swags.
	function K.run(from: Vector3, to: Vector3, every: number, post, gap)
		local len = (to - from).Magnitude
		local n = math.max(1, math.floor(len / every + 0.5))
		local prev
		for i = 0, n do
			local at = from:Lerp(to, i / n)
			if post then
				post(i, at, n)
			end
			if prev and gap then
				gap(prev, at, i)
			end
			prev = at
		end
	end

	-- Parts tagged NightOnly appear only during a night theme (MapNightController); DayOnly the reverse. Lights
	-- inside follow their part.
	function K.nightOnly(inst: Instance)
		inst:SetAttribute("NightOnly", true)
		return inst
	end
	function K.dayOnly(inst: Instance)
		inst:SetAttribute("DayOnly", true)
		return inst
	end

	function K.done()
		-- Night dressing starts hidden (its rest transparency kept in RestT for LightingController to restore).
		for _, tagged in ipairs(K.map:GetDescendants()) do
			if tagged:GetAttribute("NightOnly") then
				local list = tagged:GetDescendants()
				table.insert(list, tagged)
				for _, d in ipairs(list) do
					if d:IsA("BasePart") or d:IsA("Decal") then
						d:SetAttribute("RestT", d.Transparency)
						d.Transparency = 1
					elseif d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Fire") then
						(d :: any).Enabled = false
					elseif d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
						d.Enabled = false
					end
				end
			end
		end
		return ("%s built: %d parts"):format(name, #K.map:GetDescendants())
	end

	return K
end

return MapKit
