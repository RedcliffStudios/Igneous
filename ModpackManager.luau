local Types = require(script.Parent.Types)

local ModpackManager = {
	_Modpacks = {},
} :: {
	_Modpacks: { Types.Modpack },
	RegisterModpack: (self: any, modpack: ModuleScript) -> (),
	TriggerHook: (self: any, hook: Types.Hooks, ...any) -> (),
}

function ModpackManager:RegisterModpack(modpack: ModuleScript)
	table.insert(self._Modpacks, require(modpack))
end

function ModpackManager:TriggerHook(hook: Types.Hooks, ...)
	for _, modpack: Types.Modpack in ipairs(self._Modpacks) do
		if modpack[hook] then
			modpack[hook](...)
		end
	end
end

return ModpackManager
