--!strict
-- Tiny test runner for pure-module specs. GDD §23.1.
-- Each sibling ModuleScript named "*.spec" returns function(t) using t.it(name, fn) and t.expect(...).
-- Run from Studio (server, in play): require(game.ServerScriptService.Server.Tests.Runner).run()

local Runner = {}

local function fmt(v: any): string
	if type(v) == "number" then
		return string.format("%.4f", v)
	end
	return tostring(v)
end

local function makeExpect()
	return function(actual: any)
		local e = {}
		function e.toBe(expected: any)
			if actual ~= expected then
				error(`expected {fmt(expected)}, got {fmt(actual)}`, 2)
			end
		end
		function e.near(expected: number, eps: number?)
			local tol = eps or 1e-3
			if type(actual) ~= "number" or math.abs(actual - expected) > tol then
				error(`expected ≈{fmt(expected)} (±{tol}), got {fmt(actual)}`, 2)
			end
		end
		function e.truthy()
			if not actual then
				error(`expected truthy, got {fmt(actual)}`, 2)
			end
		end
		function e.falsy()
			if actual then
				error(`expected falsy, got {fmt(actual)}`, 2)
			end
		end
		function e.atLeast(n: number)
			if type(actual) ~= "number" or actual < n then
				error(`expected >= {fmt(n)}, got {fmt(actual)}`, 2)
			end
		end
		function e.atMost(n: number)
			if type(actual) ~= "number" or actual > n then
				error(`expected <= {fmt(n)}, got {fmt(actual)}`, 2)
			end
		end
		return e
	end
end

function Runner.run(): (number, number, string)
	local passed, failed = 0, 0
	local lines = {}
	for _, mod in ipairs(script.Parent:GetChildren()) do
		if mod:IsA("ModuleScript") and string.sub(mod.Name, -5) == ".spec" then
			local ok, specFn = pcall(require, mod)
			if not ok then
				failed += 1
				table.insert(lines, `FAIL {mod.Name} (load): {specFn}`)
				continue
			end
			local t = {
				expect = makeExpect(),
				it = function(name: string, fn: () -> ())
					local ok2, err = pcall(fn)
					if ok2 then
						passed += 1
					else
						failed += 1
						table.insert(lines, `FAIL {mod.Name} :: {name}: {err}`)
					end
				end,
			}
			local ok3, err3 = pcall(specFn :: any, t)
			if not ok3 then
				failed += 1
				table.insert(lines, `FAIL {mod.Name} (run): {err3}`)
			end
		end
	end
	local summary = `[Tests] {passed} passed, {failed} failed`
	table.insert(lines, summary)
	local report = table.concat(lines, "\n")
	if failed > 0 then
		warn(report)
	else
		print(summary)
	end
	return passed, failed, report
end

return Runner
