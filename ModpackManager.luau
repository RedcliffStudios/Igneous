local Types = require(script.Parent.Types)

--- @class ModpackManager
--- Registers modpacks and dispatches their lifecycle hooks. Supports three dispatch styles:
--- notify (TriggerHook), veto (CheckGate), and accumulate (SumHook).

local ModpackManager = {
	_Modpacks = {},
} :: {
	_Modpacks: { Types.Modpack },
	RegisterModpack: (self: any, modpack: ModuleScript) -> (),
	TriggerHook: (self: any, hook: Types.Hooks, ...any) -> (),
	CheckGate: (self: any, hook: Types.GateHooks, ...any) -> boolean,
	SumHook: (self: any, hook: Types.SumHooks, ...any) -> vector,
}

--[=[
	@method RegisterModpack
	@within ModpackManager
	@param modpack ModuleScript

	Requires and registers a modpack, making its hooks eligible for dispatch.
]=]

function ModpackManager:RegisterModpack(modpack: ModuleScript)
	table.insert(self._Modpacks, require(modpack))
end

--[=[
	@method TriggerHook
	@within ModpackManager
	@param hook Hooks
	@param ... any -- Arguments passed to each modpack's hook handler

	Calls the given hook on every registered modpack that implements it. Return
	values are discarded — use this for fire-and-forget lifecycle notifications.
]=]

function ModpackManager:TriggerHook(hook: Types.Hooks, ...)
	for _, modpack: Types.Modpack in ipairs(self._Modpacks) do
		if modpack[hook] then
			modpack[hook](...)
		end
	end
end

--[=[
	@method CheckGate
	@within ModpackManager
	@param hook GateHooks
	@param ... any -- Arguments passed to each modpack's hook handler
	@return boolean -- False if any modpack vetoed the action

	Calls the given gate hook on every registered modpack that implements it,
	stopping at the first modpack that returns false. Modpacks that return
	nothing (or true) do not block the action.
]=]

function ModpackManager:CheckGate(hook: Types.GateHooks, ...): boolean
	for _, modpack: Types.Modpack in ipairs(self._Modpacks) do
		local Handler = modpack[hook]
		if Handler and Handler(...) == false then
			return false
		end
	end

	return true
end

--[=[
	@method SumHook
	@within ModpackManager
	@param hook SumHooks
	@param ... any -- Arguments passed to each modpack's hook handler
	@return vector -- The sum of every modpack's contribution

	Calls the given hook on every registered modpack that implements it and
	sums their returned vectors. Modpacks that return nothing contribute zero.
]=]

function ModpackManager:SumHook(hook: Types.SumHooks, ...): vector
	local Total = vector.zero

	for _, modpack: Types.Modpack in ipairs(self._Modpacks) do
		local Handler = modpack[hook]
		if Handler then
			local Contribution = Handler(...)
			if Contribution then
				Total += Contribution
			end
		end
	end

	return Total
end

return ModpackManager