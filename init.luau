--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Trove = require(script.Parent.Trove)
local Motus = require(script.Parent.Motus)

local ModpackManager = require(script.ModpackManager)
local Types = require(script.Types)

assert(RunService:IsClient(), "[Igneous] Igneous is a client-only framework and cannot be required on the server")

type Weapon = Types.Weapon & {
	_Cleanup: Trove.Trove,
	_Ignored: { Instance },
	_Data: Types.WeaponData,
	_Runtime: Types.RuntimeState,
	_Resources: { [string]: Types.Resource },
	_ModpackState: { [string]: { [any]: any } },
	_LockedAngles: vector,

	_IsEquipped: boolean,
	_IsDestroyed: boolean,
	_HasWarnedNoResolver: boolean,

	_Init: (self: Weapon) -> (),
	_OnPreRender: (self: Weapon, deltaTime: number) -> (),
	_RefreshIgnored: (self: Weapon) -> (),
	_DefaultSpread: (self: Weapon) -> vector,
	_UpdateLockedAngles: (self: Weapon) -> (),
	_SetLock: (self: Weapon, lock: Types.LockAxes?) -> (),
}

local MODPACK_FOLDER_NAME = "Modpacks"
local MODPACK_SEARCH_ATTEMPTS = 5
local MODPACK_SEARCH_INTERVAL = 1

local DEFAULT_ACCURACY = 1
local DEFAULT_MAX_SPREAD = 0

local Player = Players.LocalPlayer
local Camera = Workspace.CurrentCamera :: Camera

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	Camera = Workspace.CurrentCamera :: Camera
end)

local function DeepClone(source: { [any]: any }): { [any]: any }
	local Result = table.clone(source)

	for Key, Value in Result do
		if type(Value) == "table" then
			Result[Key] = DeepClone(Value)
		end
	end

	return Result
end

--- @class Igneous
--- A small, modpack-driven FPS core for Roblox.
---
--- The core owns four things: a viewmodel bound to the camera, a mutable stat layer,
--- named resource pools, and the projectile cast. Firing, reloading, aiming, recoil and
--- effects are all modpacks, including the ones Igneous ships with.

local Igneous = {}
Igneous.__index = Igneous

--[=[
	@prop None any
	@within Igneous

	Pass this as a value to `SetRuntime` to clear a runtime key. A table can't carry a nil
	value, so `SetRuntime({ Lock = nil })` is an empty table and does nothing; this is how
	you say "remove it" instead.

	```lua
	Weapon:SetRuntime({ Lock = Igneous.None })
	```
]=]

Igneous.None = table.freeze({})

--[=[
	@prop Name string
	@within IgneousWeapon
	The name of the weapon
]=]

--[=[
	@prop Viewmodel Model
	@within IgneousWeapon
	The cloned viewmodel instance for this weapon
]=]

--[=[
	@prop Animator MotusAnimator
	@within IgneousWeapon
	The Motus animator for controlling weapon animations. See [the specific documentation](https://redcliffstudios.github.io/Motus/api/MotusAnimator) for usage.
]=]

--[=[
	@function RegisterModpack
	@within Igneous
	@param modpack ModuleScript

	Registers a modpack after startup. Everything inside `ReplicatedStorage.Modpacks` is
	registered automatically, so this is only needed for modpacks that live elsewhere or
	are created at runtime. Registering the same ModuleScript twice is a no-op.
]=]

function Igneous.RegisterModpack(modpack: ModuleScript): ()
	ModpackManager:RegisterModpack(modpack)
end

--[=[
	@function RegisterExtension
	@within Igneous
	@param name string -- The method name weapons will expose
	@param handler (weapon: IgneousWeapon, ...any) -> ...any

	Adds a method to every weapon. This is how modpacks extend the weapon API rather than
	just observing it. The Firing modpack registers `SetFiring`, the Reloading modpack
	registers `Reload` and `CancelReload`, which is why `weapon:SetFiring(true)` works
	even though firing isn't part of the core.

	The handler receives the weapon as its first argument, so it is called as a method.
	Registering a name that already exists is refused with a warning, so a modpack can't
	silently clobber the core or another modpack.

	```lua
	Igneous.RegisterExtension("Inspect", function(weapon)
		weapon.Animator:Play("Inspect")
	end)

	Weapon:Inspect()
	```
]=]

function Igneous.RegisterExtension(name: string, handler: (...any) -> ...any): ()
	if rawget(Igneous, name) then
		warn(`[Igneous] Extension "{name}" is already defined and was not overwritten`)
		return
	end

	(Igneous :: any)[name] = handler
end

--[=[
	@function Trigger
	@within Igneous
	@param weapon IgneousWeapon
	@param hook string
	@param ... any

	Notify dispatch: runs the hook on every modpack enabled for this weapon and discards
	return values. Modpacks use this to announce their own events. The Firing modpack
	raises `OnFire` this way.
]=]

function Igneous.Trigger(weapon: Types.Weapon, hook: string, ...: any): ()
	ModpackManager:TriggerHook(weapon, hook, ...)
end

--[=[
	@function Gate
	@within Igneous
	@param weapon IgneousWeapon
	@param hook string
	@param ... any
	@return boolean -- False if any modpack vetoed

	Veto dispatch: runs the hook until a modpack returns false. This is how the Reloading
	modpack blocks firing mid-reload, by vetoing the Firing modpack's `OnBeforeFire`.
]=]

function Igneous.Gate(weapon: Types.Weapon, hook: string, ...: any): boolean
	return ModpackManager:CheckGate(weapon, hook, ...)
end

--[=[
	@function Sum
	@within Igneous
	@param weapon IgneousWeapon
	@param hook string
	@param ... any
	@return vector

	Accumulate dispatch: sums every modpack's returned vector.
]=]

function Igneous.Sum(weapon: Types.Weapon, hook: string, ...: any): vector
	return ModpackManager:SumHook(weapon, hook, ...)
end

--[=[
	@function Provide
	@within Igneous
	@param weapon IgneousWeapon
	@param hook string
	@param ... any
	@return boolean -- Whether a modpack provided an implementation
	@return any -- What it returned

	Provider dispatch: runs only the highest-priority modpack implementing the hook, which
	owns the answer outright. Returns false when nothing implements it, so the caller can
	fall back to its own default.

	The winner is cached per weapon per hook, so this is cheap enough to call per
	projectile.
]=]

function Igneous.Provide(weapon: Types.Weapon, hook: string, ...: any): (boolean, any)
	return ModpackManager:Provide(weapon, hook, ...)
end

local function BuildResources(data: Types.WeaponData): { [string]: Types.Resource }
	if data.Resources then
		return DeepClone(data.Resources) :: any
	end

	-- Ammo, MaxAmmo and Reserve are shorthand for the two pools the standard modpacks read.
	return {
		Ammo = { Amount = math.min(data.Ammo or 0, data.MaxAmmo or 0), Max = data.MaxAmmo or 0 },
		Reserve = { Amount = data.Reserve or 0, Max = math.huge },
	}
end

--[=[
	@function new
	@within Igneous
	@param name string
	@param viewmodel Model -- Refer to the templates page to see an example viewmodel
	@param data ModuleScript -- The weapon's Data module, see the templates page for its schema
	@return IgneousWeapon

	Creates a new weapon. The viewmodel is cloned, so one template can back any number of
	weapons, and the Data module's table is deep-copied into the weapon's runtime state
	without being mutated itself.

	Weapons hold a render connection and a cloned viewmodel, so call `Destroy` when you
	are finished with one.
]=]

function Igneous.new(name: string, viewmodel: Model, data: ModuleScript): IgneousWeapon
	local Data = require(data)() :: Types.WeaponData
	local ViewmodelClone = viewmodel:Clone()

	if not ViewmodelClone.PrimaryPart then
		warn(`[Igneous] Viewmodel for "{name}" has no PrimaryPart, so it will pivot around its bounding box`)
	end

	local Runtime = DeepClone(Data) :: Types.RuntimeState
	Runtime.Offset = Data.Offset or vector.zero
	Runtime.Resources = nil

	local self = setmetatable({
		Name = name,
		Viewmodel = ViewmodelClone,

		Animator = Motus.new(ViewmodelClone),
		_Cleanup = Trove.new(),
		_Ignored = {},
		_Data = Data,
		_Runtime = Runtime,
		_Resources = BuildResources(Data),
		_ModpackState = {},
		_LockedAngles = vector.zero,

		_IsEquipped = false,
		_IsDestroyed = false,
		_HasWarnedNoResolver = false,
	}, Igneous) :: any

	ModpackManager:BindWeapon(self, Data.Modpacks)
	self:_Init()

	return self
end

--[=[
	@private
	@method _Init
	@within IgneousWeapon

	Sets up the weapon: binds it to the render step, seeds the ignore list with the
	player's character and its own viewmodel, and registers everything that `Destroy`
	has to tear down again.
]=]

function Igneous._Init(self: Weapon): ()
	self:_RefreshIgnored()

	-- Trove cleans in insertion order, and the animator drives tracks on the viewmodel, so
	-- it has to go first.
	self._Cleanup:Add(function()
		self.Animator:Destroy()
		ModpackManager:UnbindWeapon(self)
	end)

	self._Cleanup:Add(self.Viewmodel)

	self._Cleanup:Add(Player.CharacterAdded:Connect(function()
		self:_RefreshIgnored()
	end))

	self._Cleanup:Add(RunService.PreRender:Connect(function(deltaTime)
		self:_OnPreRender(deltaTime)
	end))
end

--[=[
	@private
	@method _RefreshIgnored
	@within IgneousWeapon

	Rebuilds the ignore list from the player's current character and this weapon's
	viewmodel. Re-run on every respawn so shots can't hit the new character.
]=]

function Igneous._RefreshIgnored(self: Weapon): ()
	local Character = Player.Character

	table.clear(self._Ignored)
	table.insert(self._Ignored, self.Viewmodel)

	if Character then
		table.insert(self._Ignored, Character)
	end
end

--[=[
	@private
	@method _OnPreRender
	@within IgneousWeapon
	@param deltaTime number

	Applies every modpack's summed camera contribution, then pivots the viewmodel to the
	camera with the weapon's lock and offset applied. Equipped weapons only, since a
	holstered weapon must not move the camera.
]=]

function Igneous._OnPreRender(self: Weapon, deltaTime: number): ()
	if not self._IsEquipped then
		return
	end

	if self.Viewmodel.Parent ~= Camera then
		self.Viewmodel.Parent = Camera
	end

	local Contribution = ModpackManager:SumHook(self, "OnCameraUpdate", deltaTime)
	Camera.CFrame *= CFrame.Angles(math.rad(Contribution.y), math.rad(Contribution.x), math.rad(Contribution.z))

	local FinalCFrame = Camera.CFrame
	local Lock = self._Runtime.Lock

	if Lock then
		local X, Y, Z = FinalCFrame:ToOrientation()
		FinalCFrame = CFrame.new(FinalCFrame.Position)
			* CFrame.fromOrientation(
				if Lock.X then self._LockedAngles.x else X,
				if Lock.Y then self._LockedAngles.y else Y,
				if Lock.Z then self._LockedAngles.z else Z
			)
	end

	self.Viewmodel:PivotTo(FinalCFrame * CFrame.new(self._Runtime.Offset :: any))
end

--[=[
	@method Equip
	@within IgneousWeapon

	Equips the weapon, parenting the viewmodel to the current camera and triggering the
	OnEquip hook for every enabled modpack.
]=]

function Igneous.Equip(self: Weapon): ()
	if self._IsEquipped or self._IsDestroyed then
		return
	end

	self._IsEquipped = true
	self.Viewmodel.Parent = Camera
	self:_UpdateLockedAngles()

	ModpackManager:TriggerHook(self, "OnEquip")
end

--[=[
	@method Unequip
	@within IgneousWeapon

	Unequips the weapon, parking the viewmodel in ReplicatedStorage and triggering the
	OnUnequip hook.

	Modpacks holding running state stop themselves on that hook. The Firing modpack ends
	the trigger pull, and the Reloading modpack interrupts a reload in progress even if
	the current stage is marked non-cancellable.
]=]

function Igneous.Unequip(self: Weapon): ()
	if not self._IsEquipped then
		return
	end

	self._IsEquipped = false
	self.Viewmodel.Parent = ReplicatedStorage

	ModpackManager:TriggerHook(self, "OnUnequip")
end

--[=[
	@method Destroy
	@within IgneousWeapon

	Tears the weapon down for good: unequips it, fires OnDestroy so modpacks can release
	anything keyed to it, disconnects its render binding, and destroys the cloned viewmodel
	and its animator. Safe to call twice.
]=]

function Igneous.Destroy(self: Weapon): ()
	if self._IsDestroyed then
		return
	end

	self:Unequip()
	self._IsDestroyed = true

	ModpackManager:TriggerHook(self, "OnDestroy")

	table.clear(self._ModpackState)
	self._Cleanup:Destroy()
end

--[=[
	@method IsEquipped
	@within IgneousWeapon
	@return boolean

	Whether the weapon is currently equipped.
]=]

function Igneous.IsEquipped(self: Weapon): boolean
	return self._IsEquipped
end

--[=[
	@private
	@method _DefaultSpread
	@within IgneousWeapon
	@return vector

	The core's fallback spread when no modpack provides `GetSpread`: a uniform random cone
	from the runtime Accuracy and MaxSpread, built in the camera's own basis so the cone
	is the same shape whichever way the player is facing. A weapon that sets neither is
	pinpoint accurate.
]=]

function Igneous._DefaultSpread(self: Weapon): vector
	local MaxSpread = self._Runtime.MaxSpread or DEFAULT_MAX_SPREAD
	local Accuracy = self._Runtime.Accuracy or DEFAULT_ACCURACY

	if MaxSpread <= 0 then
		return vector.zero
	end

	local Theta = math.random() * 2 * math.pi
	local Radius = math.tan(math.rad(MaxSpread * (1 - Accuracy))) * math.sqrt(math.random())
	local Offset = Camera.CFrame:VectorToWorldSpace(Vector3.new(Radius * math.cos(Theta), Radius * math.sin(Theta), 0))

	return vector.create(Offset.X, Offset.Y, Offset.Z)
end

--[=[
	@method Cast
	@within IgneousWeapon
	@param count number? -- Projectiles to emit, defaulting to the runtime Projectiles
	@param context CastContext? -- Passed through to the spread provider, the resolver and OnProjectileFire

	Emits projectiles from the camera. This is the core's one piece of weapon behaviour,
	and the primitive every firemode is built out of.

	For each projectile it asks for a spread offset, builds a direction scaled to the
	weapon's Range, asks for the shot to be resolved, and triggers OnProjectileFire.

	Both steps are [provider hooks](/api/Modpack), and the core has no opinion about
	either. `GetSpread` controls the pattern, falling back to a uniform random cone from
	the weapon's Accuracy and MaxSpread. `ResolveProjectile` decides what the shot
	actually hits. The core does no raycasting of its own, so a weapon with no resolver
	modpack casts geometry that resolves to nothing. The bundled Firing modpack supplies
	a hitscan resolver; a projectile, melee or hitbox modpack replaces it.

	`Cast` does not spend resources or respect cooldowns; that is the firemode's job.
]=]

function Igneous.Cast(self: Weapon, count: number?, context: Types.CastContext?): ()
	local Count = count or self._Runtime.Projectiles or 1
	local Range = self._Runtime.Range or 0

	local CameraCFrame = Camera.CFrame
	local Position = CameraCFrame.Position
	local LookVector = CameraCFrame.LookVector
	local Origin = vector.create(Position.X, Position.Y, Position.Z)
	local Forward = vector.create(LookVector.X, LookVector.Y, LookVector.Z)

	for Index = 1, Count do
		local HasSpread, Spread = ModpackManager:Provide(self, "GetSpread", Index, Count, context)
		if not HasSpread then
			Spread = self:_DefaultSpread()
		end

		local Direction = vector.normalize(Forward + (Spread :: vector)) * Range
		local ProjectileOrigin = { position = Origin, direction = Direction }
		local HasResolver, Result = ModpackManager:Provide(self, "ResolveProjectile", ProjectileOrigin, context)

		if not HasResolver and not self._HasWarnedNoResolver then
			self._HasWarnedNoResolver = true
			warn(
				`[Igneous] "{self.Name}" cast a projectile with no ResolveProjectile provider, so nothing will ever be hit. The Firing modpack supplies a default hitscan resolver, or implement ResolveProjectile yourself.`
			)
		end

		ModpackManager:TriggerHook(self, "OnProjectileFire", ProjectileOrigin, Result, context)
	end
end

--[=[
	@private
	@method _UpdateLockedAngles
	@within IgneousWeapon

	Recomputes the weapon's locked rotation angles from the camera's current orientation,
	based on which axes _Runtime.Lock has enabled. No-ops if the weapon isn't locked on any axis.
]=]

function Igneous._UpdateLockedAngles(self: Weapon): ()
	local Lock = self._Runtime.Lock
	if not Lock then
		return
	end

	local X, Y, Z = Camera.CFrame:ToOrientation()
	self._LockedAngles = vector.create(
		if Lock.X then X else 0,
		if Lock.Y then Y else 0,
		if Lock.Z then Z else 0
	)
end

--[=[
	@private
	@method _SetLock
	@within IgneousWeapon
	@param lock LockAxes? -- Which axes to freeze relative to the camera, or nil to unlock

	Freezes the viewmodel's rotation on the given axes, capturing the current camera
	orientation as the locked angle. Called internally by SetRuntime, so use
	`weapon:SetRuntime({ Lock = ... })` instead of calling this directly.
]=]

function Igneous._SetLock(self: Weapon, lock: Types.LockAxes?): ()
	self._Runtime.Lock = lock
	self:_UpdateLockedAngles()
end

--[=[
	@method SetRuntime
	@within IgneousWeapon
	@param changes RuntimeChanges -- Partial fields to overwrite

	Overwrites the weapon's mutable stats. This is how weapon mods, attachments and perks
	change a weapon.

	The runtime layer starts as a copy of the weapon's entire Data table, so *every* field
	is writable here: the core's `Range` and `Projectiles`, whatever the modpacks you've
	loaded read (`Cooldown`, `Firemode`, `Reload`, `Recoil`, ...), and your own fields like
	`Damage`. The weapon's authored Data underneath is never touched, and stays readable
	with `GetData`.

	`Lock` is applied through the viewmodel lock, recapturing the camera angles as it goes.

	A Lua table can't hold a nil value, so a key set to nil simply isn't in `changes` and
	is ignored. Pass `Igneous.None` to clear a key instead.

	```lua
	Weapon:SetRuntime({
		Accuracy = 0.95,
		Firemode = "Auto",
		Damage = { Torso = 40, Head = 95 },
	})
	```
]=]

function Igneous.SetRuntime(self: Weapon, changes: Types.RuntimeChanges): ()
	for Key, Value in changes do
		if Value == Igneous.None then
			Value = nil
		end

		if Key == "Lock" then
			self:_SetLock(Value :: Types.LockAxes?)
		else
			self._Runtime[Key] = Value
		end
	end
end

--[=[
	@method GetRuntime
	@within IgneousWeapon
	@return RuntimeState

	Returns a deep copy of the weapon's current runtime state. A copy, not the live table,
	so mutating the result, including its nested tables, can't bypass SetRuntime and its
	side effects.
]=]

function Igneous.GetRuntime(self: Weapon): Types.RuntimeState
	return DeepClone(self._Runtime) :: any
end

--[=[
	@method GetStat
	@within IgneousWeapon
	@param name string -- The runtime key to read
	@param default any? -- Returned when the weapon doesn't define that key
	@return any

	Reads a single runtime value. Since the runtime layer is a copy of the weapon's whole
	Data table, `GetRuntime()` has to deep-copy all of it; this reads one key directly and
	is what modpacks should use on hot paths like a per-shot cooldown lookup.

	The `default` is what makes the core's stats optional: a melee weapon that never
	defines `Cooldown` still works, because the Firing modpack asks for
	`weapon:GetStat("Cooldown", 0)`.

	Values that are tables come back live, not copied. Treat them as read-only and go
	through SetRuntime to change them.
]=]

function Igneous.GetStat(self: Weapon, name: string, default: any?): any
	local Value = self._Runtime[name]

	if Value == nil then
		return default
	end

	return Value
end

--[=[
	@method GetData
	@within IgneousWeapon
	@return WeaponData

	Returns a deep copy of the weapon's original authored Data, as its Data module
	returned it. Unaffected by anything SetRuntime has done since, which makes it the
	baseline to compute removable attachment modifiers against.
]=]

function Igneous.GetData(self: Weapon): Types.WeaponData
	return DeepClone(self._Data) :: any
end

--[=[
	@method GetResource
	@within IgneousWeapon
	@param name string -- e.g. "Ammo", "Reserve", "Mana"
	@return Resource

	Returns a copy of a named resource pool. Reading a pool the weapon doesn't have gives
	you an empty one rather than erroring, so a HUD can ask for "Ammo" on a melee weapon
	without guarding.
]=]

--[=[
	@method HasResource
	@within IgneousWeapon
	@param name string
	@return boolean

	Whether the weapon defines this pool at all. `GetResource` returns an empty pool for
	anything missing, which makes a weapon that has no ammo look identical to one that is
	out of ammo; this tells the two apart.

	The Firing modpack uses it to spend a round only on weapons that track ammo, so a
	melee weapon with a Stamina pool and no Ammo pool can still swing.
]=]

function Igneous.HasResource(self: Weapon, name: string): boolean
	return self._Resources[name] ~= nil
end

function Igneous.GetResource(self: Weapon, name: string): Types.Resource
	local Pool = self._Resources[name]
	if not Pool then
		return { Amount = 0, Max = 0 }
	end

	return table.clone(Pool)
end

--[=[
	@method SetResource
	@within IgneousWeapon
	@param name string
	@param amount number -- Clamped to the pool's 0..Max
	@param reason string? -- Passed to OnResourceChange, e.g. "fired", "reload", "pickup"

	Writes a resource pool directly, creating it if the weapon didn't have one. Triggers
	OnResourceChange when the value actually moves.
]=]

function Igneous.SetResource(self: Weapon, name: string, amount: number, reason: string?): ()
	local Pool = self._Resources[name]

	if not Pool then
		Pool = { Amount = 0, Max = math.huge }
		self._Resources[name] = Pool
	end

	local Clamped = math.clamp(amount, 0, Pool.Max)
	if Clamped == Pool.Amount then
		return
	end

	local Previous = Pool.Amount
	Pool.Amount = Clamped

	ModpackManager:TriggerHook(self, "OnResourceChange", name, Previous, Clamped, reason)
end

--[=[
	@method AddResource
	@within IgneousWeapon
	@param name string
	@param delta number -- Negative to spend
	@param reason string?

	Adds to a resource pool. What an ammo pickup, a mana regen tick or a round being spent
	all go through.
]=]

function Igneous.AddResource(self: Weapon, name: string, delta: number, reason: string?): ()
	self:SetResource(name, self:GetResource(name).Amount + delta, reason)
end

--[=[
	@method TransferResource
	@within IgneousWeapon
	@param from string -- The pool to draw from
	@param to string -- The pool to fill
	@param amount number -- The most to move
	@param reason string?
	@return number -- How much actually moved

	Moves up to `amount` between two pools, clamped to what the source has and what the
	destination can hold. Reloading is just a transfer from Reserve into Ammo; so is
	converting mana into charges.
]=]

function Igneous.TransferResource(self: Weapon, from: string, to: string, amount: number, reason: string?): number
	local Source = self._Resources[from]
	local Destination = self._Resources[to]

	if not Source or not Destination then
		return 0
	end

	local Moved = math.min(amount, Source.Amount, Destination.Max - Destination.Amount)
	if Moved <= 0 then
		return 0
	end

	self:SetResource(from, Source.Amount - Moved, reason)
	self:SetResource(to, Destination.Amount + Moved, reason)

	return Moved
end

--[=[
	@method GetIgnored
	@within IgneousWeapon
	@return { Instance }

	The instances a shot from this weapon should never hit: the player's character and
	the weapon's own viewmodel. Rebuilt on every respawn, so a resolver that reads it per
	cast can't end up filtering a destroyed character.

	The core does no casting itself, so this is how a resolver modpack gets the filter
	without having to track respawns:

	```lua
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = weapon:GetIgnored()
	```

	The array is live rather than copied, so assigning it straight into RaycastParams or
	OverlapParams costs nothing. Clone it before adding your own exclusions.
]=]

function Igneous.GetIgnored(self: Weapon): { Instance }
	return self._Ignored
end

--[=[
	@method GetState
	@within IgneousWeapon
	@param key string -- Usually the calling modpack's name
	@return { [any]: any }

	Returns a persistent per-weapon table for a modpack to keep its own state in, creating
	it on first use. Since hooks are plain functions shared across every weapon, this is
	where a modpack puts anything that belongs to one weapon, such as a fire thread, a
	recoil spring or a heat value.

	The table is dropped when the weapon is destroyed, so modpacks don't have to keep
	their own registry keyed by weapon.

	```lua
	local State = weapon:GetState("Recoil")
	State.Spring = State.Spring or Spring.new(vector.zero, 0.18)
	```
]=]

function Igneous.GetState(self: Weapon, key: string): { [any]: any }
	local State = self._ModpackState[key]

	if not State then
		State = {}
		self._ModpackState[key] = State
	end

	return State
end

--[=[
	@class IgneousWeapon

	A weapon created by `Igneous.new()`: a viewmodel bound to the camera, a mutable stat
	layer, named resource pools, and `Cast`.

	Firing, reloading and aiming are registered onto weapons by the standard modpacks
	rather than living here. See [Modpack](/api/Modpack) and the
	[Weapon Mods & Recipes](/docs/Runtime) guide.
]=]

export type IgneousWeapon = Types.Weapon

local function RegisterFolder(folder: Instance): ()
	for _, Modpack in folder:GetChildren() do
		ModpackManager:RegisterModpack(Modpack :: ModuleScript)
	end

	folder.ChildAdded:Connect(function(child)
		ModpackManager:RegisterModpack(child :: ModuleScript)
	end)
end

-- Deferred rather than spawned. A spawned thread runs before this module returns, which
-- would make any modpack requiring Igneous at its top level a cyclic require.
task.defer(function()
	for _ = 1, MODPACK_SEARCH_ATTEMPTS do
		local Folder = ReplicatedStorage:FindFirstChild(MODPACK_FOLDER_NAME, true)

		if Folder then
			RegisterFolder(Folder)
			return
		end

		task.wait(MODPACK_SEARCH_INTERVAL)
	end

	warn(
		`[Igneous] No "{MODPACK_FOLDER_NAME}" folder found in ReplicatedStorage after {MODPACK_SEARCH_ATTEMPTS} attempts, so no modpacks were registered. Register them yourself with Igneous.RegisterModpack if they live elsewhere.`
	)
end)

return Igneous
