--!strict
-- Tiny synchronous signal for in-process events (server services / client controllers).

export type Connection = { Disconnect: (self: Connection) -> (), Connected: boolean }

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} :: { [any]: (...any) -> () } }, Signal)
end

function Signal:Connect(fn: (...any) -> ())
	local handlers = self._handlers
	local conn = { Connected = true }
	function conn.Disconnect(c)
		c.Connected = false
		handlers[c] = nil
	end
	handlers[conn] = fn
	return conn
end

function Signal:Fire(...)
	for conn, fn in pairs(self._handlers) do
		if conn.Connected then
			task.spawn(fn, ...)
		end
	end
end

function Signal:Once(fn: (...any) -> ())
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end

function Signal:Destroy()
	table.clear(self._handlers)
end

return Signal
