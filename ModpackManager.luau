--!strict

local Types = require(script.Parent.Types)

type Registration = {
	Name: string,
	Priority: number,
	Order: number,
	Module: Types.Modpack,
}

type ProviderCache = {
	Generation: number,
	Hooks: { [string]: Registration | false },
}

--- @class ModpackManager
--- Registers modpacks and dispatches their hooks. Supports four dispatch styles:
--- notify (TriggerHook), veto (CheckGate), accumulate (SumHook) and provide (Provide).
---
--- Modpacks are dispatched highest `Priority` first, and a weapon bound with an allowlist
--- only ever sees the modpacks it named. Every handler runs protected, so a modpack that
--- errors is warned about and skipped instead of aborting the weapon mid-shot.

local ModpackManager = {
	_Modpacks = {} :: { Registration },
	_Filters = (setmetatable({}, { __mode = "k" }) :: any) :: { [Types.Weapon]: { [string]: boolean } },
	_Providers = (setmetatable({}, { __mode = "k" }) :: any) :: { [Types.Weapon]: ProviderCache },
	_Registered = {} :: { [ModuleScript]: boolean },
	_Order = 0,
	_Generation = 0,
}

local function ByPriority(a: Registration, b: Registration): boolean
	if a.Priority == b.Priority then
		return a.Order < b.Order
	end

	return a.Priority > b.Priority
end

--[=[
	@private
	@method _IsEnabled
	@within ModpackManager
	@param weapon Weapon
	@param name string
	@return boolean

	Whether the named modpack is allowed to run for this weapon. Weapons bound without
	an allowlist accept every modpack.
]=]

function ModpackManager._IsEnabled(self: any, weapon: Types.Weapon, name: string): boolean
	local Filter = self._Filters[weapon]
	if Filter then
		return Filter[name] == true
	end

	return true
end

--[=[
	@method BindWeapon
	@within ModpackManager
	@param weapon Weapon
	@param allowed {string}? -- Modpack names this weapon accepts, or nil for all of them

	Records which modpacks a weapon opts into, from its Data module's `Modpacks` field.
	Called for you by `Igneous.new`. The binding is held weakly, so it disappears with
	the weapon.
]=]

function ModpackManager.BindWeapon(self: any, weapon: Types.Weapon, allowed: { string }?): ()
	self._Providers[weapon] = nil

	if not allowed then
		self._Filters[weapon] = nil
		return
	end

	local Filter = {}
	for _, Name in allowed do
		Filter[Name] = true
	end

	self._Filters[weapon] = Filter
end

--[=[
	@method UnbindWeapon
	@within ModpackManager
	@param weapon Weapon

	Drops a weapon's modpack allowlist and cached providers. Called for you when a weapon
	is destroyed.
]=]

function ModpackManager.UnbindWeapon(self: any, weapon: Types.Weapon): ()
	self._Filters[weapon] = nil
	self._Providers[weapon] = nil
end

--[=[
	@method RegisterModpack
	@within ModpackManager
	@param modpack ModuleScript

	Requires and registers a modpack, making its hooks eligible for dispatch. Non-ModuleScript
	instances and modules that were already registered are ignored, so it is safe to call
	twice for the same modpack.

	The modpack is filed under its `Name` field, falling back to the ModuleScript's name, and
	sorted into the dispatch list by its `Priority` field (highest first, default 0).
]=]

function ModpackManager.RegisterModpack(self: any, modpack: ModuleScript): ()
	if not modpack:IsA("ModuleScript") or self._Registered[modpack] then
		return
	end

	local Success, Module = pcall(require, modpack)
	if not Success then
		warn(`[Igneous] Modpack "{modpack.Name}" failed to load: {Module}`)
		return
	end

	self._Registered[modpack] = true
	self._Order += 1
	self._Generation += 1

	table.insert(self._Modpacks, {
		Name = (Module :: Types.Modpack).Name or modpack.Name,
		Priority = (Module :: Types.Modpack).Priority or 0,
		Order = self._Order,
		Module = Module :: Types.Modpack,
	})

	table.sort(self._Modpacks, ByPriority)
end

--[=[
	@method TriggerHook
	@within ModpackManager
	@param weapon Weapon
	@param hook string
	@param ... any -- Further arguments passed to each modpack's hook handler

	Notify dispatch. Calls the hook on every registered modpack that implements it and is
	enabled for this weapon. Return values are discarded.
]=]

function ModpackManager.TriggerHook(self: any, weapon: Types.Weapon, hook: string, ...: any): ()
	for _, Registration in self._Modpacks do
		local Handler = Registration.Module[hook]
		if Handler and self:_IsEnabled(weapon, Registration.Name) then
			local Success, Error = pcall(Handler, weapon, ...)
			if not Success then
				warn(`[Igneous] Modpack "{Registration.Name}" errored in {hook}: {Error}`)
			end
		end
	end
end

--[=[
	@method CheckGate
	@within ModpackManager
	@param weapon Weapon
	@param hook string
	@param ... any -- Further arguments passed to each modpack's hook handler
	@return boolean -- False if any modpack vetoed the action

	Veto dispatch. Calls the hook on every enabled modpack that implements it, stopping at
	the first one that returns false. Modpacks that return nothing (or true) do not block
	the action, and a modpack that errors is treated as abstaining.
]=]

function ModpackManager.CheckGate(self: any, weapon: Types.Weapon, hook: string, ...: any): boolean
	for _, Registration in self._Modpacks do
		local Handler = Registration.Module[hook]
		if Handler and self:_IsEnabled(weapon, Registration.Name) then
			local Success, Vote = pcall(Handler, weapon, ...)
			if not Success then
				warn(`[Igneous] Modpack "{Registration.Name}" errored in {hook}: {Vote}`)
			elseif Vote == false then
				return false
			end
		end
	end

	return true
end

--[=[
	@method SumHook
	@within ModpackManager
	@param weapon Weapon
	@param hook string
	@param ... any -- Further arguments passed to each modpack's hook handler
	@return vector -- The sum of every modpack's contribution

	Accumulate dispatch. Calls the hook on every enabled modpack that implements it and
	sums their returned vectors. Modpacks that return nothing, return something that isn't
	a vector, or error contribute zero.
]=]

function ModpackManager.SumHook(self: any, weapon: Types.Weapon, hook: string, ...: any): vector
	local Total = vector.zero

	for _, Registration in self._Modpacks do
		local Handler = Registration.Module[hook]
		if Handler and self:_IsEnabled(weapon, Registration.Name) then
			local Success, Contribution = pcall(Handler, weapon, ...)
			if not Success then
				warn(`[Igneous] Modpack "{Registration.Name}" errored in {hook}: {Contribution}`)
			elseif typeof(Contribution) == "vector" or typeof(Contribution) == "Vector3" then
				Total += Contribution :: any
			end
		end
	end

	return Total
end

--[=[
	@method Provide
	@within ModpackManager
	@param weapon Weapon
	@param hook string
	@param ... any -- Further arguments passed to the providing modpack's handler
	@return boolean -- Whether any modpack provided an implementation
	@return any -- What it returned

	Provider dispatch. Unlike the other three styles, only *one* modpack runs: the
	highest-priority one that implements the hook and is enabled for this weapon. A
	modpack implementing a provider hook is claiming ownership of it. There is no
	abstaining, so a weapon should opt into exactly one provider per hook through its
	`Modpacks` list.

	The winning modpack is resolved once per weapon per hook and cached, so provider hooks
	are cheap enough to call per projectile. The cache is invalidated whenever a new
	modpack registers.

	Returns false when nothing implements the hook, which is the caller's cue to fall back
	to its own default. A provider that errors is reported the same way.
]=]

function ModpackManager.Provide(self: any, weapon: Types.Weapon, hook: string, ...: any): (boolean, any)
	local Cache = self._Providers[weapon]

	if not Cache or Cache.Generation ~= self._Generation then
		Cache = { Generation = self._Generation, Hooks = {} }
		self._Providers[weapon] = Cache
	end

	local Entry = Cache.Hooks[hook]

	if Entry == nil then
		Entry = false

		for _, Registration in self._Modpacks do
			if Registration.Module[hook] and self:_IsEnabled(weapon, Registration.Name) then
				Entry = Registration
				break
			end
		end

		Cache.Hooks[hook] = Entry
	end

	if not Entry then
		return false, nil
	end

	local Winner = Entry :: Registration
	local Success, Result = pcall(Winner.Module[hook], weapon, ...)

	if not Success then
		warn(`[Igneous] Modpack "{Winner.Name}" errored in {hook}: {Result}`)
		return false, nil
	end

	return true, Result
end

return ModpackManager
