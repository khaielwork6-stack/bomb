--!strict
-- Central input bindings (PC / gamepad / touch) -> action signals. GDD §7.7.
-- Controllers subscribe via InputController.on(action, fn). Handlers return true if they consumed the input.

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local InputController = {
	LastInputChanged = Signal.new(),
}

export type Device = "KeyboardMouse" | "Gamepad" | "Touch"
InputController.device = "KeyboardMouse" :: Device

local PRIORITY = Enum.ContextActionPriority.High.Value + 10

local ACTIONS = {
	Primary = { Enum.KeyCode.Space, Enum.KeyCode.ButtonA }, -- Dash (runner) / Dive (catcher)
	HardStop = { Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL1 },
	Slide = { Enum.KeyCode.C, Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB },
	Swing = { Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2 },
	Ability = { Enum.KeyCode.Q, Enum.KeyCode.ButtonX },
	View = { Enum.KeyCode.V, Enum.KeyCode.ButtonY },
}

-- action -> list of handlers (first that returns true sinks the input)
local handlers: { [string]: { (Enum.UserInputState, InputObject) -> boolean } } = {}

function InputController.on(action: string, fn: (Enum.UserInputState, InputObject) -> boolean)
	handlers[action] = handlers[action] or {}
	table.insert(handlers[action], fn)
end

local function dispatch(action: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
	local list = handlers[action]
	if list then
		for _, fn in ipairs(list) do
			local ok, consumed = pcall(fn, state, input)
			if not ok then
				warn("[Input] handler error", action, consumed)
			elseif consumed then
				return Enum.ContextActionResult.Sink
			end
		end
	end
	return Enum.ContextActionResult.Pass
end

local function deviceFor(t: Enum.UserInputType): Device?
	if t == Enum.UserInputType.Touch then
		return "Touch"
	elseif string.find(t.Name, "Gamepad") then
		return "Gamepad"
	elseif t == Enum.UserInputType.Keyboard or string.find(t.Name, "Mouse") then
		return "KeyboardMouse"
	end
	return nil
end

function InputController.init()
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		InputController.device = "Touch"
	elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		InputController.device = "Gamepad"
	end
end

function InputController.start()
	for action, keys in pairs(ACTIONS) do
		ContextActionService:BindActionAtPriority("CG_" .. action, function(_, state, input)
			return dispatch(action, state, input)
		end, false, PRIORITY, table.unpack(keys))
	end
	UserInputService.LastInputTypeChanged:Connect(function(t)
		local d = deviceFor(t)
		if d and d ~= InputController.device then
			InputController.device = d
			InputController.LastInputChanged:Fire(d)
		end
	end)
end

-- Programmatic trigger (mobile UI buttons call this).
function InputController.trigger(action: string, state: Enum.UserInputState?)
	local fake = { UserInputType = Enum.UserInputType.Touch, KeyCode = Enum.KeyCode.None } :: any
	dispatch(action, state or Enum.UserInputState.Begin, fake)
end

return InputController
