--!strict
-- Every visible button in the game gets the house feel (UI/Motion: hover lift + light + shine, press squish, release
-- bounce), including buttons built later, so no screen is left with dead buttons. Widgets.button, Skin.close and the
-- dock already call Motion.button themselves; this catches the rest.
-- Left alone: invisible click-catchers (a panel's Sink, a modal backdrop), anything nearly full-screen, the touch
-- gameplay controls (FV_Mobile: they have their own press feel tuned for thumbs), a button that already scales
-- itself with its own UIScale (two drivers would fight), and anything tagged with the NoAlive attribute.
-- Implements: F-UI-01 (motion rules), Asset Bible §6.3.

local Players = game:GetService("Players")

local Motion = require(script.Parent.Parent.UI.Motion)
local Screen = require(script.Parent.Parent.UI.Screen)

local UiMotionController = {}

local SKIP_GUIS = { FV_Mobile = true }

local function seen(o: GuiObject): boolean
	if o.BackgroundTransparency < 0.95 or o:FindFirstChild("SkinRoot") then
		return true
	end
	if o:IsA("ImageButton") or o:IsA("ImageLabel") then
		local i = o :: any
		if i.Image ~= "" and i.ImageTransparency < 0.95 then
			return true
		end
	end
	if o:IsA("TextButton") or o:IsA("TextLabel") then
		local t = o :: any
		if t.Text ~= "" and t.TextTransparency < 0.95 then
			return true
		end
	end
	return false
end

local function ownScale(o: GuiObject): boolean
	local own = o:FindFirstChildOfClass("UIScale")
	return own ~= nil and not own:GetAttribute("Motion")
end

-- What should move for `b`: the button itself, or (for an invisible hit box laid over a card) the card under it.
-- nil when it should be left alone.
local function eligible(b: GuiButton): GuiObject?
	if b:GetAttribute("Alive") or b:GetAttribute("NoAlive") then
		return nil
	end
	local gui = b:FindFirstAncestorWhichIsA("ScreenGui")
	if not gui or SKIP_GUIS[gui.Name] then
		return nil
	end
	local v = Screen.size()
	local s = b.AbsoluteSize
	if s.X <= 0 or s.Y <= 0 or (s.X > v.X * 0.6 and s.Y > v.Y * 0.5) then
		return nil
	end
	-- the button itself is drawn, or it carries the visuals it would scale
	local drawn = seen(b)
	if not drawn then
		for _, d in ipairs(b:GetChildren()) do
			if d:IsA("GuiObject") and d.Visible and seen(d) then
				drawn = true
				break
			end
		end
	end
	if drawn then
		return if ownScale(b) then nil else b
	end
	-- an invisible hit box covering its parent card: the card moves
	local parent = b.Parent
	if parent and parent:IsA("GuiObject") and seen(parent) and not ownScale(parent) then
		local ps = parent.AbsoluteSize
		if ps.X > 0 and s.X >= ps.X * 0.8 and s.Y >= ps.Y * 0.8 and ps.X < v.X * 0.6 then
			return parent
		end
	end
	return nil
end

local function attach(b: GuiButton)
	local target = eligible(b)
	if target then
		Motion.button(b, if target ~= b then { visual = target } else nil)
	end
end

local function consider(d: Instance)
	if not d:IsA("GuiButton") then
		return
	end
	local b = d :: GuiButton
	-- skins, labels and sizes arrive just after the button is made: look once it has settled
	task.delay(0.1, function()
		if not b.Parent then
			return
		end
		if b.AbsoluteSize.X <= 0 then
			-- not laid out yet (a hidden page): try again when it gets a size
			local conn: RBXScriptConnection
			conn = b:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				if b.AbsoluteSize.X > 0 then
					conn:Disconnect()
					attach(b)
				end
			end)
			return
		end
		attach(b)
	end)
end

function UiMotionController.start()
	local pg = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	pg.DescendantAdded:Connect(consider)
	for _, d in ipairs(pg:GetDescendants()) do
		consider(d)
	end
end

return UiMotionController
