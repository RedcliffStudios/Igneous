--!strict

-- Trigger state, cooldowns, firemodes, hitscan and the ammo convenience API. Semi, Burst
-- and Auto are registered below through the same RegisterFiremode call any other firemode
-- uses.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Igneous = require(ReplicatedStorage.Packages.Igneous)
local Types = require(ReplicatedStorage.Packages.Igneous.Types)

type Weapon = Types.Weapon

type FiringState = {
	IsFiring: boolean,
	NextFireTime: number,
	Thread: thread?,
	Params: RaycastParams?,
}

local STATE_KEY = "Firing"
local AMMO = "Ammo"
local RESERVE = "Reserve"

local DEFAULT_BURST_COUNT = 3
local DEFAULT_COOLDOWN = 0
local DEFAULT_FIREMODE = "Semi"

local Firemodes: { [string]: Types.FiremodeHandler } = {}

local Modpack = {}

Modpack.Name = "Firing"

-- Lowest priority of the bundled modpacks. Provider hooks go to the highest-priority
-- implementer, so keeping the default hitscan at the bottom lets any resolver added
-- alongside it win without setting a priority. Nothing else here depends on running
-- early: it implements no gate hooks, and its notify hooks don't care about ordering.
Modpack.Priority = -100

local function GetFiringState(weapon: Weapon): FiringState
	local State = weapon:GetState(STATE_KEY) :: any

	if State.NextFireTime == nil then
		State.IsFiring = false
		State.NextFireTime = 0
		State.Thread = nil
	end

	return State
end

local function IsThreadAlive(thread: thread?): boolean
	return thread ~= nil and coroutine.status(thread :: thread) ~= "dead"
end

local function StopThread(state: FiringState): ()
	local Thread = state.Thread
	state.Thread = nil

	if IsThreadAlive(Thread) then
		task.cancel(Thread :: thread)
	end
end

local Trigger = {}
Trigger.__index = Trigger

local function NewTrigger(weapon: Weapon, state: FiringState): Types.Trigger
	return setmetatable({ Weapon = weapon, _State = state }, Trigger) :: any
end

function Trigger.IsHeld(self: any): boolean
	return self._State.IsFiring
end

function Trigger.Wait(self: any, seconds: number?): number
	return task.wait(seconds)
end

--[=[
	Spends a round and casts. Returns false without firing when the weapon is disabled,
	empty, still on cooldown, or vetoed. Every firemode stops on a false return instead of
	looping on a shot that will never happen.
]=]
function Trigger.Fire(self: any, count: number?, context: Types.CastContext?): boolean
	local Weapon = self.Weapon :: Weapon
	local State = self._State :: FiringState

	-- Checked every shot rather than only at the trigger pull, so an Auto weapon put away
	-- or destroyed mid-burst stops even if this modpack's OnUnequip never runs for it.
	if not Weapon:IsEquipped() then
		return false
	end

	if Weapon:GetStat("CanFire", true) == false then
		return false
	end

	-- A weapon with no Ammo pool, such as a melee weapon tracking Stamina instead, fires
	-- without spending anything.
	local TracksAmmo = Weapon:HasResource(AMMO)
	if TracksAmmo and Weapon:GetResource(AMMO).Amount <= 0 then
		return false
	end

	if os.clock() < State.NextFireTime then
		return false
	end

	if not Igneous.Gate(Weapon, "OnBeforeFire", context) then
		return false
	end

	local Cooldown = Weapon:GetStat("Cooldown", DEFAULT_COOLDOWN)
	State.NextFireTime = os.clock() + Cooldown

	if TracksAmmo then
		Weapon:AddResource(AMMO, -1, "fired")
	end

	Igneous.Trigger(Weapon, "OnFire", context)
	Weapon:Cast(count, context)

	task.wait(Cooldown)

	return true
end

--[=[
	Registers a firemode under a name weapons can select with `Data.Firemode`. The handler
	receives the weapon and a Trigger, and returns when the trigger pull is over.

	```lua
	Firing.RegisterFiremode("Charge", function(weapon, trigger)
		local Held = 0
		while trigger:IsHeld() and Held < weapon:GetStat("MaxCharge", 1.5) do
			Held += trigger:Wait()
		end
		trigger:Fire(nil, { Charge = Held })
	end)
	```
]=]
function Modpack.RegisterFiremode(name: string, handler: Types.FiremodeHandler): ()
	if Firemodes[name] then
		warn(`[Igneous] Firemode "{name}" is already registered and was not overwritten`)
		return
	end

	Firemodes[name] = handler
end

Modpack.RegisterFiremode("Semi", function(weapon, trigger)
	trigger:Fire()
end)

Modpack.RegisterFiremode("Burst", function(weapon, trigger)
	for _ = 1, weapon:GetStat("BurstCount", DEFAULT_BURST_COUNT) do
		if not trigger:Fire() then
			break
		end
	end

	local State = GetFiringState(weapon)
	local BurstCooldown = weapon:GetStat("BurstCooldown", weapon:GetStat("Cooldown", DEFAULT_COOLDOWN))
	State.NextFireTime = math.max(State.NextFireTime, os.clock() + BurstCooldown)
end)

Modpack.RegisterFiremode("Auto", function(weapon, trigger)
	while trigger:IsHeld() and trigger:Fire() do
	end
end)

Igneous.RegisterExtension("SetFiring", function(weapon: Weapon, shouldFire: boolean): ()
	local State = GetFiringState(weapon)

	if State.IsFiring == shouldFire then
		return
	end

	-- Stopping always works even when unequipped, so a weapon put away mid-burst is never
	-- left stuck firing.
	if shouldFire and (not weapon:IsEquipped() or not Igneous.Gate(weapon, "OnBeforeFire")) then
		return
	end

	State.IsFiring = shouldFire

	if not shouldFire then
		Igneous.Trigger(weapon, "OnFireEnd")
		StopThread(State)
		return
	end

	Igneous.Trigger(weapon, "OnFireStart")

	if IsThreadAlive(State.Thread) then
		return
	end

	local Name = weapon:GetStat("Firemode", DEFAULT_FIREMODE)
	local Handler = Firemodes[Name]

	if not Handler then
		warn(`[Igneous] Weapon "{weapon.Name}" uses unregistered firemode "{Name}"`)
		return
	end

	State.Thread = task.spawn(function()
		Handler(weapon, NewTrigger(weapon, State))
	end)
end)

Igneous.RegisterExtension("IsFiring", function(weapon: Weapon): boolean
	return GetFiringState(weapon).IsFiring
end)

Igneous.RegisterExtension("GetAmmo", function(weapon: Weapon): Types.AmmoData
	local Ammo = weapon:GetResource(AMMO)

	return { Amount = Ammo.Amount, Max = Ammo.Max, Reserve = weapon:GetResource(RESERVE).Amount }
end)

Igneous.RegisterExtension("SetAmmo", function(weapon: Weapon, amount: number): ()
	weapon:SetResource(AMMO, amount, "set")
end)

Igneous.RegisterExtension("SetReserve", function(weapon: Weapon, amount: number): ()
	weapon:SetResource(RESERVE, amount, "set")
end)

Igneous.RegisterExtension("AddReserve", function(weapon: Weapon, amount: number): ()
	weapon:AddResource(RESERVE, amount, "pickup")
end)

local function GetParams(weapon: Weapon): RaycastParams
	local State = GetFiringState(weapon)

	if not State.Params then
		local Params = RaycastParams.new()
		Params.FilterType = Enum.RaycastFilterType.Exclude
		State.Params = Params
	end

	-- The list is rebuilt on respawn, so reading it every cast avoids filtering against a
	-- destroyed character.
	local Params = State.Params :: RaycastParams
	Params.FilterDescendantsInstances = weapon:GetIgnored()

	return Params
end

--[=[
	Resolves a projectile as an instant raycast, which is what makes a conventional gun
	hit things. Provider hook. A modpack of your own that implements ResolveProjectile
	outranks this one automatically.
]=]
function Modpack.ResolveProjectile(weapon: Weapon, origin: Types.ProjectileOrigin): RaycastResult?
	return Workspace:Raycast(origin.position :: any, origin.direction :: any, GetParams(weapon))
end

function Modpack.OnUnequip(weapon: Weapon)
	local State = GetFiringState(weapon)
	if not State.IsFiring then
		StopThread(State)
		return
	end

	State.IsFiring = false
	Igneous.Trigger(weapon, "OnFireEnd")
	StopThread(State)
end

-- Saves every modpack that only cares about ammo from filtering OnResourceChange by name.
function Modpack.OnResourceChange(weapon: Weapon, name: string, previous: number, current: number, reason: string?)
	if name ~= AMMO then
		return
	end

	Igneous.Trigger(weapon, "OnAmmoChange", previous, current, reason)
end

return Modpack
