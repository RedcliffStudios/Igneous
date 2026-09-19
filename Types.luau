--!strict

local Motus = require(script.Parent.Parent.Motus)

--[=[
	@type LockAxes { X: boolean, Y: boolean, Z: boolean }
	@within Igneous
	Which axes of the viewmodel's rotation should stay frozen relative to the camera.
]=]

export type LockAxes = {
	X: boolean,
	Y: boolean,
	Z: boolean,
}

--[=[
	@type Resource { Amount: number, Max: number }
	@within Igneous
	One named pool on a weapon. Ammo, reserve, mana, stamina, charges and heat are all
	the same shape: a current value and a ceiling. A pool with no meaningful ceiling
	uses `math.huge`.
]=]

export type Resource = {
	Amount: number,
	Max: number,
}

--[=[
	@type ProjectileOrigin { position: vector, direction: vector }
	@within Igneous
	Where a projectile was cast from and the vector it was cast along. `direction`
	already has spread applied and is scaled to the weapon's Range, so a modpack
	continuing the ray (penetration, wallbangs) can reuse it directly.
]=]

export type ProjectileOrigin = {
	position: vector,
	direction: vector,
}

--[=[
	@type CastContext { [any]: any }
	@within Igneous
	An arbitrary table a firemode passes into `Weapon:Cast()`, handed through untouched
	to the spread provider, the projectile resolver and the OnProjectileFire hook. A
	charge firemode puts its charge level here; a shotgun might put a pellet pattern seed.
]=]

export type CastContext = { [any]: any }

--[=[
	@type WeaponData { [string]: any }
	@within Igneous
	The table a weapon's Data module returns.

	The core interprets five keys: `Range`, `Projectiles`, `Lock` and `Offset` for casting
	and viewmodel placement, plus `Resources` for the weapon's pools.
	Everything else is whatever the modpacks you've loaded ask for: the Firing modpack
	reads `Firemode`, `Cooldown` and `CanFire`; the Reloading modpack reads `Reload`;
	the Recoil modpack reads `Recoil`, and so on.

	Every key is copied into the weapon's [RuntimeState] at creation, so all of it is
	mutable at runtime, including fields the core has never heard of, like `Damage`.
]=]

export type WeaponData = {
	Range: number,
	Projectiles: number,

	Resources: { [string]: Resource }?,

	Lock: LockAxes?,
	Offset: vector?,

	Modpacks: { string }?,

	[string]: any,
}

--[=[
	@type RuntimeState { [string]: any }
	@within Igneous
	A mutable copy of the weapon's entire [WeaponData], made when the weapon is created
	and rewritten freely afterwards with `Weapon:SetRuntime()`.

	This is the layer everything reads at runtime, and the layer weapon mods, attachments
	and perks write to. Since it starts as a copy of the whole Data table, *any* field is
	mutable: the core's `Range`, a modpack's `Cooldown`, or your own `Damage` table, with
	the weapon's authored Data underneath left untouched.

	`Lock` is the one special case: set it through SetRuntime as usual, which recaptures
	the locked camera angles as it applies.
]=]

export type RuntimeState = {
	Range: number,
	Projectiles: number,

	Lock: LockAxes?,
	Offset: vector,

	[string]: any,
}

--[=[
	@type RuntimeChanges { [string]: any }
	@within Igneous
	The partial table accepted by `Weapon:SetRuntime()`. Any [RuntimeState] key may be
	supplied.
]=]

export type RuntimeChanges = { [string]: any }

--[=[
	@interface Weapon
	@within Igneous
	.Name string
	.Viewmodel Model
	.Animator MotusAnimator

	The core weapon surface: a viewmodel bound to the camera, a mutable stat layer, named
	resource pools, per-weapon modpack storage, and the ability to cast projectiles.

	Firing, reloading and aiming are not here. The standard modpacks register those onto
	the weapon. Type a weapon as [StandardWeapon] instead if you have those loaded and
	want them autocompleted.
]=]

export type Weapon = {
	Name: string,
	Viewmodel: Model,

	Animator: Motus.MotusAnimator,

	Equip: (self: Weapon) -> (),
	Unequip: (self: Weapon) -> (),
	Destroy: (self: Weapon) -> (),
	IsEquipped: (self: Weapon) -> boolean,

	Cast: (self: Weapon, count: number?, context: CastContext?) -> (),

	GetRuntime: (self: Weapon) -> RuntimeState,
	GetStat: (self: Weapon, name: string, default: any?) -> any,
	SetRuntime: (self: Weapon, changes: RuntimeChanges) -> (),
	GetData: (self: Weapon) -> WeaponData,

	HasResource: (self: Weapon, name: string) -> boolean,
	GetResource: (self: Weapon, name: string) -> Resource,
	SetResource: (self: Weapon, name: string, amount: number, reason: string?) -> (),
	AddResource: (self: Weapon, name: string, delta: number, reason: string?) -> (),
	TransferResource: (self: Weapon, from: string, to: string, amount: number, reason: string?) -> number,

	GetIgnored: (self: Weapon) -> { Instance },
	GetState: (self: Weapon, key: string) -> { [any]: any },
}

--[=[
	@type StagedReloadStage { Name: string, Duration: number, Cancellable: boolean, AmmoTransfer: number?, CanFireAfter: boolean }
	@within Igneous
	A single stage in a Staged reload, read by the Reloading modpack. AmmoTransfer moves
	that many rounds from Reserve to Ammo when the stage completes; omit it for stages
	with no ammo movement (e.g. racking a bolt). CanFireAfter controls whether the weapon
	may fire once this stage completes, or must wait for a later stage.
]=]

export type StagedReloadStage = {
	Name: string,
	Duration: number,
	Cancellable: boolean,
	AmmoTransfer: number?,
	CanFireAfter: boolean,
}

--[=[
	@type SimpleReloadData { Type: "Simple", Duration: number, Cancellable: boolean }
	@within Igneous
	A single wait-then-fill reload with no intermediate stages.
]=]

export type SimpleReloadData = {
	Type: "Simple",
	Duration: number,
	Cancellable: boolean,
}

--[=[
	@type StagedReloadData { Type: "Staged", Stages: {StagedReloadStage} }
	@within Igneous
	A reload made up of ordered stages, each independently cancellable and able to gate
	firing and ammo transfer.
]=]

export type StagedReloadData = {
	Type: "Staged",
	Stages: { StagedReloadStage },
}

--[=[
	@type ProgressiveReloadData { Type: "Progressive", Duration: number, AmountPerCycle: number, Cancellable: boolean }
	@within Igneous
	A reload that repeats a single cycle, adding AmountPerCycle rounds each time, until
	full or out of reserve. Used for pellet-fed or single-load weapons.
]=]

export type ProgressiveReloadData = {
	Type: "Progressive",
	Duration: number,
	AmountPerCycle: number,
	Cancellable: boolean,
}

--[=[
	@type ReloadData SimpleReloadData | StagedReloadData | ProgressiveReloadData
	@within Igneous
	A weapon's reload configuration, set via Data.Reload and read by the Reloading modpack.
]=]

export type ReloadData = SimpleReloadData | StagedReloadData | ProgressiveReloadData

--[=[
	@type RecoilData { Vertical: number, Horizontal: number, SmoothTime: number?, MaxSpeed: number? }
	@within Igneous
	The peak vertical and horizontal kick per shot, in degrees, read by the Recoil modpack.
	SmoothTime is roughly how long recovery takes; MaxSpeed caps how fast the camera may
	be moved by it.
]=]

export type RecoilData = {
	Vertical: number,
	Horizontal: number,
	SmoothTime: number?,
	MaxSpeed: number?,
}

--[=[
	@type AmmoData { Amount: number, Max: number, Reserve: number }
	@within Igneous
	What the Firing modpack's `Weapon:GetAmmo()` convenience returns, composed from the
	`Ammo` and `Reserve` resource pools.
]=]

export type AmmoData = {
	Amount: number,
	Max: number,
	Reserve: number,
}

--[=[
	@interface Trigger
	@within Igneous
	.IsHeld () -> boolean
	.Fire (count: number?, context: CastContext?) -> boolean
	.Wait (seconds: number?) -> number
	.Weapon Weapon

	The controller handed to a firemode handler. `IsHeld` reports whether the player is
	still holding the trigger, `Fire` spends a round and casts (returning false when the
	shot could not happen), and `Wait` yields while remaining cancellable.
]=]

export type Trigger = {
	Weapon: Weapon,
	IsHeld: (self: Trigger) -> boolean,
	Fire: (self: Trigger, count: number?, context: CastContext?) -> boolean,
	Wait: (self: Trigger, seconds: number?) -> number,
}

--[=[
	@type FiremodeHandler (weapon: Weapon, trigger: Trigger) -> ()
	@within Igneous
	One trigger pull, start to finish. Registered with the Firing modpack's
	`RegisterFiremode`, and selected by a weapon's `Firemode` runtime value.
]=]

export type FiremodeHandler = (weapon: Weapon, trigger: Trigger) -> ()

--[=[
	@interface StandardWeapon
	@within Igneous

	A [Weapon] with the methods the standard modpacks register, for typing weapons in a
	project that loads Firing, Reloading and Aiming.
]=]

export type StandardWeapon = Weapon & {
	SetFiring: (self: Weapon, shouldFire: boolean) -> (),
	IsFiring: (self: Weapon) -> boolean,

	GetAmmo: (self: Weapon) -> AmmoData,
	SetAmmo: (self: Weapon, amount: number) -> (),
	SetReserve: (self: Weapon, amount: number) -> (),
	AddReserve: (self: Weapon, amount: number) -> (),

	Reload: (self: Weapon) -> (),
	CancelReload: (self: Weapon) -> (),
	IsReloading: (self: Weapon) -> boolean,

	SetAiming: (self: Weapon, isAiming: boolean) -> (),
	IsAiming: (self: Weapon) -> boolean,
}

--[=[
	@class Modpack

	Modpacks are where nearly everything in Igneous lives. The core gives you a weapon
	bound to the camera with stats, resources and a way to cast projectiles; firing,
	reloading, aiming, recoil and effects are all modpacks on top of it.

	Place modpack modules in `game.ReplicatedStorage.Modpacks` and they'll be registered
	automatically on initialization. Each hook is optional, so only implement the ones
	your modpack needs.

	By default a modpack runs for every weapon. Give a weapon's Data module a `Modpacks`
	array to opt it into a specific set instead, matched against each modpack's `Name`
	(or its ModuleScript name when `Name` is omitted).

	A hook that errors is caught and warned about, so one broken modpack can't take down
	the frame or leave a weapon stuck mid-shot.

	## Dispatch styles

	How a hook behaves depends on how it is dispatched, not on how it is written:

	- **Notify** (`Igneous.Trigger`): every enabled modpack runs, return values discarded.
	- **Veto** (`Igneous.Gate`): every enabled modpack runs until one returns false, which blocks the action.
	- **Accumulate** (`Igneous.Sum`): every enabled modpack's returned vector is summed.
	- **Provide** (`Igneous.Provide`): only the highest-priority modpack implementing the hook runs, and it owns the answer. Implementing a provider hook means claiming it; there is no abstaining.

	Your own modpacks can dispatch their own hook names through those same four functions,
	which is how the standard modpacks talk to each other.
]=]

--[=[
	@prop Name string?
	@within Modpack
	The name weapons opt into this modpack by, via their Data module's `Modpacks` list.
	Defaults to the modpack ModuleScript's name.
]=]

--[=[
	@prop Priority number?
	@within Modpack
	Dispatch order across modpacks, highest first. Defaults to 0. Modpacks sharing a
	priority run in registration order. Priority decides which modpack wins a provider
	hook, and which gets to veto a gate hook first.
]=]

--[=[
	@function OnEquip
	@within Modpack
	@param weapon Weapon

	Called when a weapon is equipped.
]=]

--[=[
	@function OnUnequip
	@within Modpack
	@param weapon Weapon

	Called when a weapon is unequipped. Modpacks holding running state, such as a fire
	loop or a reload sequence, stop themselves here.
]=]

--[=[
	@function OnDestroy
	@within Modpack
	@param weapon Weapon

	Called when a weapon is destroyed, after it is unequipped and before its connections
	and viewmodel are torn down. The per-weapon tables from `Weapon:GetState()` are
	dropped for you.
]=]

--[=[
	@function OnCameraUpdate
	@within Modpack
	@param weapon Weapon
	@param deltaTime number -- Delta time since the last frame
	@return vector? -- A rotational delta in degrees (x = yaw, y = pitch, z = roll)

	Accumulate hook. Called every PreRender frame for equipped weapons, and every
	modpack's returned offset is summed and applied to the camera once.

	The value is a per-frame *delta*, not an absolute angle. Return the change since your
	last frame so the rotation integrates correctly and settles back to zero.
]=]

--[=[
	@function OnProjectileFire
	@within Modpack
	@param weapon Weapon
	@param origin ProjectileOrigin -- Where the projectile was cast from, and along what vector
	@param result RaycastResult? -- Whatever the projectile resolver returned
	@param context CastContext? -- The table the firemode passed to Cast

	Called once per projectile cast by `Weapon:Cast()`. This is where damage, bullet
	holes, tracers and server validation live.
]=]

--[=[
	@function ResolveProjectile
	@within Modpack
	@param weapon Weapon
	@param origin ProjectileOrigin
	@param context CastContext?
	@return RaycastResult?

	**Provider hook.** Decides what a projectile actually hits. The core does no casting of
	its own. Hitscan lives in the bundled Firing modpack, alongside travelling projectiles,
	spherecast melee arcs and hitbox queries as equally valid alternatives.

	A weapon with no resolver still casts geometry and still raises OnProjectileFire, but
	with a nil result, and warns once. Only the highest-priority modpack implementing this
	runs, so a weapon should opt into exactly one resolver through its `Modpacks` list.

	Use `weapon:GetIgnored()` for the filter rather than building your own, so you inherit
	the respawn tracking. Returning a RaycastResult is the common case; a resolver that
	produces something else should cast, and hooks that read it should expect it.
]=]

--[=[
	@function GetSpread
	@within Modpack
	@param weapon Weapon
	@param index number -- Which projectile of this cast, 1-based
	@param count number -- How many projectiles this cast is emitting
	@param context CastContext?
	@return vector -- An offset added to the camera's look vector before normalising

	**Provider hook.** Decides where each projectile of a cast goes. The index and count
	let you build deterministic patterns such as a fixed shotgun ring, a recoil-linked cone, or
	bloom that widens with sustained fire. The core's default is a uniform random cone
	from `Accuracy` and `MaxSpread`, in the camera's own basis.
]=]

--[=[
	@function OnResourceChange
	@within Modpack
	@param weapon Weapon
	@param name string -- Which pool changed, e.g. "Ammo" or "Mana"
	@param previous number
	@param current number
	@param reason string? -- Whatever the caller passed, e.g. "fired", "reload", "set"

	Called whenever any of a weapon's resource pools changes value.
]=]

export type Modpack = {
	Name: string?,
	Priority: number?,

	OnEquip: ((weapon: Weapon) -> ())?,
	OnUnequip: ((weapon: Weapon) -> ())?,
	OnDestroy: ((weapon: Weapon) -> ())?,
	OnCameraUpdate: ((weapon: Weapon, deltaTime: number) -> vector?)?,
	OnProjectileFire: ((
		weapon: Weapon,
		origin: ProjectileOrigin,
		result: RaycastResult?,
		context: CastContext?
	) -> ())?,
	OnResourceChange: ((weapon: Weapon, name: string, previous: number, current: number, reason: string?) -> ())?,

	ResolveProjectile: ((weapon: Weapon, origin: ProjectileOrigin, context: CastContext?) -> RaycastResult?)?,
	GetSpread: ((weapon: Weapon, index: number, count: number, context: CastContext?) -> vector)?,

	-- Hooks dispatched by other modpacks, and any of your own
	[string]: any,
}

return {}
