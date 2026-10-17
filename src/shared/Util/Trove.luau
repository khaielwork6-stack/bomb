--!strict
-- Minimal cleanup container: add Instances, connections, threads or functions; clean() destroys all.

export type Trove = {
	add: <T>(self: Trove, item: T) -> T,
	connect: (self: Trove, signal: RBXScriptSignal, fn: (...any) -> ()) -> RBXScriptConnection,
	spawn: (self: Trove, fn: (...any) -> (), ...any) -> thread,
	delay: (self: Trove, t: number, fn: (...any) -> ()) -> thread,
	extend: (self: Trove) -> Trove,
	clean: (self: Trove) -> (),
	_items: { any },
}

local Trove = {}
Trove.__index = Trove

function Trove.new(): Trove
	return setmetatable({ _items = {} }, Trove) :: any
end

function Trove.add(self: Trove, item)
	table.insert(self._items, item)
	return item
end

function Trove.connect(self: Trove, signal: RBXScriptSignal, fn)
	return self:add(signal:Connect(fn))
end

function Trove.spawn(self: Trove, fn, ...)
	return self:add(task.spawn(fn, ...))
end

function Trove.delay(self: Trove, t: number, fn)
	return self:add(task.delay(t, fn))
end

function Trove.extend(self: Trove): Trove
	return self:add(Trove.new())
end

local function cleanItem(item: any)
	local kind = typeof(item)
	if kind == "Instance" then
		item:Destroy()
	elseif kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "thread" then
		if coroutine.status(item) ~= "dead" and item ~= coroutine.running() then
			pcall(task.cancel, item)
		end
	elseif kind == "function" then
		item()
	elseif kind == "table" then
		if type(item.clean) == "function" then
			item:clean()
		elseif type(item.Destroy) == "function" then
			item:Destroy()
		elseif type(item.Disconnect) == "function" then
			item:Disconnect()
		end
	end
end

function Trove.clean(self: Trove)
	local items = self._items
	self._items = {}
	for i = #items, 1, -1 do
		local ok, err = pcall(cleanItem, items[i])
		if not ok then
			warn("[Trove] cleanup error:", err)
		end
	end
end

return Trove
